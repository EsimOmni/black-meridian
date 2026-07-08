from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .core import AssetJob, stage_output_dir


@dataclass(frozen=True)
class TripoConfig:
    python: Path
    triposr_root: Path
    triposplat_root: Path


def tripo_config_from_env() -> TripoConfig:
    return TripoConfig(
        python=Path(os.environ.get("OMNI_TRIPO_PYTHON", r"D:\AI\tripo-env\Scripts\python.exe")),
        triposr_root=Path(os.environ.get("OMNI_TRIPOSR_ROOT", r"D:\AI\TripoSR")),
        triposplat_root=Path(os.environ.get("OMNI_TRIPOSPLAT_ROOT", r"D:\AI\TripoSplat")),
    )


def build_triposr_command(job: AssetJob, project_root: Path, config: TripoConfig) -> tuple[list[str], Path]:
    options = _stage_options(job, "triposr")
    output_dir = stage_output_dir(project_root, job, "triposr")
    command = [
        str(config.python),
        str(config.triposr_root / "run.py"),
        str(job.reference_paths[0]),
        "--pretrained-model-name-or-path",
        str(config.triposr_root / "ckpts"),
        "--mc-resolution",
        str(options.get("mc_resolution", 256)),
        "--output-dir",
        str(output_dir),
        "--model-save-format",
        str(options.get("model_save_format", "glb")),
    ]
    if options.get("no_remove_bg", False):
        command.append("--no-remove-bg")
    if options.get("bake_texture", False):
        command.append("--bake-texture")
        command.extend(["--texture-resolution", str(options.get("texture_resolution", 2048))])
    if options.get("render", False):
        command.append("--render")
    return command, output_dir


def build_triposplat_command(job: AssetJob, project_root: Path, config: TripoConfig) -> tuple[list[str], Path]:
    options = _stage_options(job, "triposplat")
    output_dir = stage_output_dir(project_root, job, "triposplat")
    runner = Path(__file__).resolve().with_name("triposplat_runner.py")
    command = [
        str(config.python),
        str(runner),
        "--triposplat-root",
        str(config.triposplat_root),
        "--image",
        str(job.reference_paths[0]),
        "--output-dir",
        str(output_dir),
        "--num-gaussians",
        str(options.get("num_gaussians", 262144)),
        "--device",
        str(options.get("device", "cuda")),
    ]
    return command, output_dir


def run_command(command: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=str(cwd) if cwd else None, text=True, capture_output=True, check=False)


def _stage_options(job: AssetJob, stage: str) -> dict[str, Any]:
    generation = job.data.get("generation", {})
    if not isinstance(generation, dict):
        return {}
    options = generation.get(stage, {})
    return dict(options) if isinstance(options, dict) else {}

