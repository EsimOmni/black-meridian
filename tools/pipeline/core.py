from __future__ import annotations

import hashlib
import json
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


JOB_ID_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{2,80}$")


class ManifestError(ValueError):
    """Raised when an asset job manifest violates the pipeline contract."""


@dataclass(frozen=True)
class AssetJob:
    job_id: str
    path: Path
    version: str
    data: dict[str, Any]
    reference_paths: list[Path]

    @property
    def routing(self) -> dict[str, Any]:
        return dict(self.data.get("routing", {}))


def project_root_from_here() -> Path:
    return Path(__file__).resolve().parents[2]


def safe_resolve(project_root: Path, relative_path: str | os.PathLike[str]) -> Path:
    root = project_root.resolve()
    candidate = Path(relative_path)
    if candidate.is_absolute():
        resolved = candidate.resolve()
    else:
        resolved = (root / candidate).resolve()
    if resolved != root and root not in resolved.parents:
        raise ManifestError(f"path escapes project root: {relative_path}")
    return resolved


def load_job(job_path: str | os.PathLike[str], project_root: Path | None = None) -> AssetJob:
    root = (project_root or project_root_from_here()).resolve()
    manifest_path = safe_resolve(root, job_path)
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ManifestError(f"invalid JSON in {manifest_path}: {exc}") from exc

    job_id = _required_str(data, "job_id")
    if not JOB_ID_RE.match(job_id):
        raise ManifestError("job_id must be lowercase slug, 3-81 chars")

    references = data.get("references")
    if not isinstance(references, list) or not references:
        raise ManifestError("references must be a non-empty list")
    reference_paths = [safe_resolve(root, item) for item in references if isinstance(item, str)]
    if len(reference_paths) != len(references):
        raise ManifestError("references must contain only string paths")

    routing = data.get("routing")
    if not isinstance(routing, dict):
        raise ManifestError("routing must be an object")
    for key in ("geometry", "production", "runtime"):
        if not isinstance(routing.get(key), str):
            raise ManifestError(f"routing.{key} must be set")

    version = data.get("version", "v001")
    if not isinstance(version, str) or not re.match(r"^v[0-9]{3}$", version):
        raise ManifestError("version must look like v001")

    return AssetJob(job_id=job_id, path=manifest_path, version=version, data=data, reference_paths=reference_paths)


def stage_output_dir(project_root: Path, job: AssetJob, stage: str) -> Path:
    return project_root.resolve() / "assets" / "_generated" / stage / job.job_id / job.version


def export_output_dir(project_root: Path, job: AssetJob) -> Path:
    return project_root.resolve() / "assets" / "_exports" / job.job_id / job.version


def report_dir(project_root: Path, job: AssetJob) -> Path:
    return project_root.resolve() / "jobs" / "reports" / job.job_id


def write_report(project_root: Path, job: AssetJob, stage: str, payload: dict[str, Any]) -> Path:
    destination = report_dir(project_root, job) / f"{stage}.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    return destination


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _required_str(data: dict[str, Any], key: str) -> str:
    value = data.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ManifestError(f"{key} must be a non-empty string")
    return value

