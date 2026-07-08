"""Hunyuan3D 2.1 geometry route for the OMNI 3D pipeline.

Local, zero-credit image->mesh via the ComfyUI-Hunyuan3d-2-1 custom node running
inside the SwarmUI ComfyUI backend (D:\\AI\\SwarmUI\\dlbackend\\comfy\\ComfyUI).
This is the preferred geometry route for organic/hybrid heroes where a concept
image beats box-modelling and Hunyuan3D 2.1 outclasses TripoSR (brief §10: local
Hunyuan3D/TripoSR cover proxies; only pay Magnific for a benchmarked win).

Contract (same as tripo.py): produces a raw GEOMETRY CANDIDATE, never a final
game asset. Blender still owns retopo/UV/PBR/LOD/collision; Godot owns runtime.

The adapter loads a UI-format workflow JSON (the node's own
`workflow_examples/Mesh_Generation.json`), converts it to the ComfyUI /prompt
API graph, injects the job's reference image + per-job generation options, POSTs
it, polls until the export node writes a GLB, then copies that GLB into the job's
immutable stage dir. No raw output is modified in place.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import time
import urllib.request
import urllib.error
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .core import AssetJob, stage_output_dir


@dataclass(frozen=True)
class HunyuanConfig:
    comfy_url: str          # ComfyUI HTTP endpoint, e.g. http://127.0.0.1:8188
    comfy_root: Path        # ComfyUI install root (for input/ + output/ dirs)
    workflow: Path          # UI-format workflow JSON to drive


def hunyuan_config_from_env() -> HunyuanConfig:
    comfy_root = Path(os.environ.get(
        "OMNI_COMFY_ROOT",
        r"D:\AI\SwarmUI\dlbackend\comfy\ComfyUI",
    ))
    default_wf = comfy_root / "custom_nodes" / "ComfyUI-Hunyuan3d-2-1" / "workflow_examples" / "Mesh_Generation.json"
    return HunyuanConfig(
        comfy_url=os.environ.get("OMNI_COMFY_URL", "http://127.0.0.1:8188"),
        comfy_root=comfy_root,
        workflow=Path(os.environ.get("OMNI_HUNYUAN_WORKFLOW", str(default_wf))),
    )


def _fetch_object_info(comfy_url: str) -> dict[str, Any]:
    """Fetch ComfyUI /object_info — the authoritative INPUT_TYPES per node class."""
    try:
        with urllib.request.urlopen(f"{comfy_url}/object_info", timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError):
        return {}


def _widget_input_order(object_info: dict[str, Any], class_type: str) -> list[str]:
    """Return a node class's input names in declaration order (from /object_info)."""
    info = object_info.get(class_type, {})
    order = info.get("input_order", {})
    names: list[str] = []
    for group in ("required", "optional"):
        names.extend(order.get(group, []))
    return names


def _ui_to_api_graph(ui: dict[str, Any], object_info: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Convert a ComfyUI UI-format workflow (nodes + links) to the /prompt API graph.

    API graph is { node_id: { "class_type": T, "inputs": { name: value | [src_id, slot] } } }.
    Links fill connected inputs by name; widget values fill the remaining inputs. The UI JSON's
    per-node `inputs` list only enumerates SOCKET inputs (links), NOT widget inputs, so we take the
    node class's real input order from /object_info and assign widgets_values to the input names
    that are NOT link-connected, in that order (ComfyUI's own positional widget contract). Using
    generic `_wN` names fails: nodes like Hy3DMeshGenerator require inputs by their real names.
    """
    nodes = {str(n["id"]): n for n in ui["nodes"]}
    link_src: dict[int, tuple[str, int]] = {}
    for link in ui.get("links", []):
        # link = [link_id, src_node, src_slot, dst_node, dst_slot, type]
        link_src[link[0]] = (str(link[1]), int(link[2]))

    graph: dict[str, dict[str, Any]] = {}
    for nid, node in nodes.items():
        class_type = node["type"]
        inputs: dict[str, Any] = {}

        # Connected (socket) inputs from links, keyed by their declared socket name.
        connected_names: set[str] = set()
        for inp in node.get("inputs", []):
            link_id = inp.get("link")
            if link_id is not None and link_id in link_src:
                src_id, src_slot = link_src[link_id]
                inputs[inp["name"]] = [src_id, src_slot]
                connected_names.add(inp["name"])

        # Widget values → the class's real input names (from object_info) that aren't link-fed.
        widget_vals = list(node.get("widgets_values", []) or [])
        all_names = _widget_input_order(object_info, class_type)
        widget_names = [n for n in all_names if n not in connected_names]
        for i, val in enumerate(widget_vals):
            if i < len(widget_names):
                inputs[widget_names[i]] = val
            # extra widget values (e.g. a seed's control_after_generate) have no input slot — drop.

        graph[nid] = {"class_type": class_type, "inputs": inputs}
    return graph


def _find_node_by_type(graph: dict[str, dict[str, Any]], class_type: str) -> str | None:
    for nid, node in graph.items():
        if node.get("class_type") == class_type:
            return nid
    return None


def _name_tokens(name: str) -> list[str]:
    """Lowercase a ckpt/model name and split into comparable tokens, dropping the extension and
    precision suffixes so 'Hunyuan3D-vae-v2-1-fp16.ckpt' ≈ 'hunyuan3d-vae-v2-1.ckpt'."""
    stem = str(name).lower().rsplit(".", 1)[0]
    for drop in ("fp16", "fp8", "bf16", "nvfp4"):
        stem = stem.replace(drop, "")
    return [t for t in re.split(r"[\\/_.\- ]+", stem) if t]


def _snap_combo_widgets(graph: dict[str, dict[str, Any]], object_info: dict[str, Any]) -> None:
    """For each node input that object_info declares as a choice list (a dropdown/combo — model or
    vae ckpt names, attention modes, etc.), if the workflow's value isn't among this install's
    choices, snap it to the best available one: prefer a choice sharing a stem keyword with the
    stale value (so a missing '...-vae-v2-1-fp16.ckpt' picks the real 'hunyuan3d-vae-v2-1.ckpt'),
    else the first choice. Only touches literal (non-linked) string inputs."""
    for node in graph.values():
        info = object_info.get(node.get("class_type", ""), {})
        spec = info.get("input", {})
        choices_by_name: dict[str, list[str]] = {}
        for group in ("required", "optional"):
            for name, decl in spec.get(group, {}).items():
                if isinstance(decl, list) and decl and isinstance(decl[0], list):
                    choices_by_name[name] = decl[0]
        for name, value in list(node["inputs"].items()):
            if isinstance(value, list):
                continue  # a link, not a widget value
            choices = choices_by_name.get(name)
            if not choices or value in choices:
                continue
            # Snap to the choice sharing the MOST name tokens with the stale value (e.g. a missing
            # 'Hunyuan3D-vae-v2-1-fp16.ckpt' → 'hunyuan3d-vae-v2-1.ckpt', NOT a random other VAE).
            # A single "vae" keyword is too coarse — it matched QwenImage's VAE. Token overlap keeps
            # the model family (hunyuan3d), variant (v2-1) and role (vae/dit) aligned.
            want = set(_name_tokens(value))
            best = max(choices, key=lambda c: len(want & set(_name_tokens(c))))
            best_score = len(want & set(_name_tokens(best)))
            node["inputs"][name] = best if best_score > 0 else choices[0]


def build_hunyuan_prompt(job: AssetJob, project_root: Path, config: HunyuanConfig) -> tuple[dict[str, Any], Path, str]:
    """Return (api_prompt_graph, stage_output_dir, expected_glb_stub).

    Injects the job's reference image into the LoadImage node and applies per-job
    generation options (steps, guidance, decimate target) onto the matching nodes.
    """
    ui = json.loads(config.workflow.read_text(encoding="utf-8"))
    object_info = _fetch_object_info(config.comfy_url)
    graph = _ui_to_api_graph(ui, object_info)

    options = _stage_options(job, "hunyuan3d")

    # 1) Reference image → copy into ComfyUI input/ and point the loader at it.
    ref = job.reference_paths[0]
    input_dir = config.comfy_root / "input"
    input_dir.mkdir(parents=True, exist_ok=True)
    staged_name = f"{job.job_id}_{job.version}{ref.suffix}"
    shutil.copyfile(ref, input_dir / staged_name)

    load_id = _find_node_by_type(graph, "Hy3D21LoadImageWithTransparency")
    if load_id is None:
        raise RuntimeError("workflow has no Hy3D21LoadImageWithTransparency node")
    graph[load_id]["inputs"]["image"] = staged_name

    # 2a) Snap every combo/dropdown widget (model/vae ckpt names) to a value THIS install offers.
    # The example workflow ships fp16 ckpt names that may not exist here (VAELoader wanted
    # 'Hunyuan3D-vae-v2-1-fp16.ckpt' → load_torch_file got None). For each node input whose
    # object_info type is a list of choices, if the current value isn't in the list, snap it to the
    # closest available choice sharing a stem keyword (dit / vae), else the first choice.
    _snap_combo_widgets(graph, object_info)

    # 2b) Mesh generator: apply per-job steps/guidance by real input name.
    gen_id = _find_node_by_type(graph, "Hy3DMeshGenerator")
    if gen_id is not None:
        gi = graph[gen_id]["inputs"]
        if "steps" in options:
            gi["steps"] = int(options["steps"])
        if "guidance" in options:
            gi["guidance_scale"] = float(options["guidance"])

    # 2c) VAE decode: the example workflow's dual-marching-cubes ('dmc') returned an EMPTY mesh here
    # (VAEDecode raised "'NoneType' has no attribute 'mesh_f'"). Standard marching cubes ('mc') is
    # the robust default. Overridable per job via generation.hunyuan3d.mc_algo.
    dec_id = _find_node_by_type(graph, "Hy3D21VAEDecode")
    if dec_id is not None:
        di = graph[dec_id]["inputs"]
        di["mc_algo"] = str(options.get("mc_algo", "mc"))
        if "octree_resolution" in options:
            di["octree_resolution"] = int(options["octree_resolution"])

    # 3) Export node → set the output filename stub so we can locate the GLB (real input name).
    export_id = _find_node_by_type(graph, "Hy3D21ExportMesh")
    stub = f"{job.job_id}_{job.version}"
    if export_id is not None:
        ei = graph[export_id]["inputs"]
        name_key = next((k for k in ("filename_prefix", "filename", "output_path", "name") if k in ei), None)
        if name_key:
            ei[name_key] = stub

    # 4) Drop UI-only nodes that crash headless. Preview3D renders a viewport preview and needs a
    # bg_image the API run never provides ("string index out of range" on an empty bg_image) — the
    # GLB is already written by ExportMesh, so the preview is dead weight. Remove it and any node
    # that feeds only it.
    _strip_ui_only_nodes(graph, {"Preview3D"})

    output_dir = stage_output_dir(project_root, job, "hunyuan3d")
    return graph, output_dir, stub


def _strip_ui_only_nodes(graph: dict[str, dict[str, Any]], class_types: set[str]) -> None:
    """Remove nodes of the given UI-only class types (and leave their upstream intact — ComfyUI
    prunes any node whose only consumer is removed only if unreferenced; ExportMesh is a terminal
    output so the geometry chain still executes)."""
    to_remove = [nid for nid, node in graph.items() if node.get("class_type") in class_types]
    for nid in to_remove:
        del graph[nid]


def run_hunyuan(job: AssetJob, project_root: Path, config: HunyuanConfig, timeout_s: int = 1200) -> dict[str, Any]:
    """POST the prompt to ComfyUI, poll history until done, copy the GLB into the stage dir."""
    graph, output_dir, stub = build_hunyuan_prompt(job, project_root, config)
    output_dir.mkdir(parents=True, exist_ok=True)

    prompt_id = _post_prompt(config.comfy_url, graph)
    _wait_history(config.comfy_url, prompt_id, timeout_s)

    # Hunyuan's ExportMesh writes into ComfyUI/output/<stub>_*.glb (or output/3D/).
    glb = _locate_glb(config.comfy_root, stub)
    if glb is None:
        return {"ok": False, "error": f"no GLB found for stub {stub}", "prompt_id": prompt_id}

    dest = output_dir / f"{stub}.glb"
    shutil.copyfile(glb, dest)
    return {"ok": True, "prompt_id": prompt_id, "glb": str(dest), "source_glb": str(glb)}


def _post_prompt(comfy_url: str, graph: dict[str, Any]) -> str:
    body = json.dumps({"prompt": graph}).encode("utf-8")
    req = urllib.request.Request(f"{comfy_url}/prompt", data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    pid = data.get("prompt_id")
    if not pid:
        raise RuntimeError(f"ComfyUI rejected prompt: {data}")
    return pid


def _wait_history(comfy_url: str, prompt_id: str, timeout_s: int) -> None:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(f"{comfy_url}/history/{prompt_id}", timeout=15) as resp:
                hist = json.loads(resp.read().decode("utf-8"))
        except urllib.error.URLError:
            hist = {}
        if prompt_id in hist:
            status = hist[prompt_id].get("status", {})
            if status.get("completed") or status.get("status_str") == "success":
                return
            if status.get("status_str") == "error":
                raise RuntimeError(f"ComfyUI run errored: {status}")
        time.sleep(3)
    raise TimeoutError(f"Hunyuan3D run timed out after {timeout_s}s")


def _locate_glb(comfy_root: Path, stub: str) -> Path | None:
    candidates: list[Path] = []
    for out in (comfy_root / "output", comfy_root / "output" / "3D"):
        if out.is_dir():
            candidates.extend(out.glob(f"{stub}*.glb"))
    if not candidates:
        return None
    return max(candidates, key=lambda p: p.stat().st_mtime)


def _stage_options(job: AssetJob, stage: str) -> dict[str, Any]:
    generation = job.data.get("generation", {})
    if not isinstance(generation, dict):
        return {}
    options = generation.get(stage, {})
    return dict(options) if isinstance(options, dict) else {}
