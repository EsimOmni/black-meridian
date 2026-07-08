from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .core import ManifestError, load_job, project_root_from_here, write_report
from .tripo import build_triposplat_command, build_triposr_command, run_command, tripo_config_from_env
from .hunyuan import build_hunyuan_prompt, hunyuan_config_from_env, run_hunyuan


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m tools.pipeline")
    parser.add_argument("--project-root", default=None)
    sub = parser.add_subparsers(dest="command", required=True)

    validate = sub.add_parser("validate-job")
    validate.add_argument("job")

    run = sub.add_parser("run-job")
    run.add_argument("job")
    run.add_argument("--stage", choices=["hunyuan3d", "triposr", "triposplat", "all"], default="all")
    run.add_argument("--dry-run", action="store_true")

    args = parser.parse_args(argv)
    root = Path(args.project_root).resolve() if args.project_root else project_root_from_here()

    try:
        job = load_job(args.job, project_root=root)
    except ManifestError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2), file=sys.stderr)
        return 2

    if args.command == "validate-job":
        print(json.dumps({"ok": True, "job_id": job.job_id, "version": job.version, "references": [str(p) for p in job.reference_paths]}, indent=2))
        return 0

    tripo_config = tripo_config_from_env()
    # "all" runs the geometry route declared by the job (hunyuan3d or triposr), then triposplat
    # for an appearance reference. A single --stage runs just that stage.
    if args.stage == "all":
        geometry = job.routing.get("geometry", "triposr")
        stages = [geometry, "triposplat"]
    else:
        stages = [args.stage]

    reports: list[dict[str, object]] = []
    for stage in stages:
        if stage == "hunyuan3d":
            hy_config = hunyuan_config_from_env()
            graph, output_dir, stub = build_hunyuan_prompt(job, root, hy_config)
            output_dir.mkdir(parents=True, exist_ok=True)
            report = {
                "ok": True,
                "dry_run": bool(args.dry_run),
                "job_id": job.job_id,
                "stage": stage,
                "output_dir": str(output_dir),
                "comfy_url": hy_config.comfy_url,
                "workflow": str(hy_config.workflow),
                "export_stub": stub,
                "node_count": len(graph),
            }
            if not args.dry_run:
                report.update(run_hunyuan(job, root, hy_config))
            write_report(root, job, stage, report)
            reports.append(report)
            if not report["ok"]:
                break
            continue

        if stage == "triposr":
            command, output_dir = build_triposr_command(job, root, tripo_config)
        else:
            command, output_dir = build_triposplat_command(job, root, tripo_config)
        output_dir.mkdir(parents=True, exist_ok=True)
        report = {
            "ok": True,
            "dry_run": bool(args.dry_run),
            "job_id": job.job_id,
            "stage": stage,
            "output_dir": str(output_dir),
            "command": command,
        }
        if not args.dry_run:
            result = run_command(command)
            report.update(
                {
                    "ok": result.returncode == 0,
                    "returncode": result.returncode,
                    "stdout_tail": result.stdout[-4000:],
                    "stderr_tail": result.stderr[-4000:],
                }
            )
        write_report(root, job, stage, report)
        reports.append(report)
        if not report["ok"]:
            break

    print(json.dumps({"ok": all(bool(r["ok"]) for r in reports), "reports": reports}, indent=2))
    return 0 if all(bool(r["ok"]) for r in reports) else 1


if __name__ == "__main__":
    raise SystemExit(main())
