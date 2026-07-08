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


def _ui_to_api_graph(ui: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Convert a ComfyUI UI-format workflow (nodes + links) to the /prompt API graph.

    API graph is { node_id: { "class_type": T, "inputs": { name: value | [src_id, slot] } } }.
    Widget values fill scalar inputs in declaration order; links fill connected inputs.
    """
    nodes = {str(n["id"]): n for n in ui["nodes"]}
    # link_id -> (src_node_id, src_slot)
    link_src: dict[int, tuple[str, int]] = {}
    for link in ui.get("links", []):
        # link = [link_id, src_node, src_slot, dst_node, dst_slot, type]
        link_src[link[0]] = (str(link[1]), int(link[2]))

    graph: dict[str, dict[str, Any]] = {}
    for nid, node in nodes.items():
        class_type = node["type"]
        inputs: dict[str, Any] = {}

        # Connected inputs (from links) — keyed by the input's declared name.
        connected_names: set[str] = set()
        for inp in node.get("inputs", []):
            link_id = inp.get("link")
            if link_id is not None and link_id in link_src:
                src_id, src_slot = link_src[link_id]
                inputs[inp["name"]] = [src_id, src_slot]
                connected_names.add(inp["name"])

        # Widget values fill the remaining (non-linked) widget inputs in order. The node's
        # input list interleaves linked inputs and widgets; widgets are the entries WITHOUT a
        # link that carry a value. ComfyUI matches widgets_values positionally to widget inputs,
        # so we map them onto the input slots that are not link-connected, in declared order.
        widget_vals = list(node.get("widgets_values", []) or [])
        widget_slots = [inp["name"] for inp in node.get("inputs", []) if inp["name"] not in connected_names]
        # Some nodes declare widgets only in widgets_values with no matching `inputs` entry;
        # ComfyUI's API still expects them by the class's INPUT_TYPES order. When the input list
        # doesn't enumerate them, fall back to positional generic names the node ignores-safe:
        for i, val in enumerate(widget_vals):
            name = widget_slots[i] if i < len(widget_slots) else f"_w{i}"
            inputs[name] = val

        graph[nid] = {"class_type": class_type, "inputs": inputs}
    return graph


def _find_node_by_type(graph: dict[str, dict[str, Any]], class_type: str) -> str | None:
    for nid, node in graph.items():
        if node.get("class_type") == class_type:
            return nid
    return None


def build_hunyuan_prompt(job: AssetJob, project_root: Path, config: HunyuanConfig) -> tuple[dict[str, Any], Path, str]:
    """Return (api_prompt_graph, stage_output_dir, expected_glb_stub).

    Injects the job's reference image into the LoadImage node and applies per-job
    generation options (steps, guidance, decimate target) onto the matching nodes.
    """
    ui = json.loads(config.workflow.read_text(encoding="utf-8"))
    graph = _ui_to_api_graph(ui)

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
    # first widget slot on the loader is the image filename
    graph[load_id]["inputs"]["image"] = staged_name

    # 2) Mesh generator options (steps / guidance) if the node exposes them by name.
    gen_id = _find_node_by_type(graph, "Hy3DMeshGenerator")
    if gen_id is not None:
        gi = graph[gen_id]["inputs"]
        if "steps" in options and "_w1" in gi:
            gi["_w1"] = int(options["steps"])
        if "guidance" in options and "_w2" in gi:
            gi["_w2"] = float(options["guidance"])

    # 3) Export node → set the output stub so we can locate the GLB.
    export_id = _find_node_by_type(graph, "Hy3D21ExportMesh")
    stub = f"{job.job_id}_{job.version}"
    if export_id is not None:
        graph[export_id]["inputs"]["_w0"] = stub  # filename stub widget

    output_dir = stage_output_dir(project_root, job, "hunyuan3d")
    return graph, output_dir, stub


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
