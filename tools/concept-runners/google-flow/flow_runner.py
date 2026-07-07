"""Google Flow runner — drive the Flow web UI to generate image/video from a
brief JSON. Two modes that map onto Flow's two composer states:

  mode="agent"   Agent ON. Write the natural-language brief, attach refs, send.
                 Flow's own agent picks the model + generates. Fewest selectors,
                 most robust.
  mode="direct"  Agent OFF. Set modality/aspect/quality/model explicitly, attach
                 refs, send. Deterministic model, more selectors.

HARD COST GUARD (Pro = 1000 cr): the runner reads Flow's live
"Generating will use N credits" before every send and ABORTS the job if N exceeds
the brief's `max_credits` (default 0 for image smoke, set per video job). Cheapest
model is the default — image=Nano Banana 2 (0 cr), video=cheapest available.

Brief schema (briefs/<name>.json):
{
  "project_url": "https://labs.google/fx/tools/flow/project/<uuid>",
  "defaults": { "mode": "agent", "modality": "image", "aspect": "16:9",
                "quality": "x2", "model": "Nano Banana 2", "max_credits": 0 },
  "jobs": [
    { "name": "smoke_img", "brief": "A single matte-silver concept car...",
      "refs": ["path/to/ref1.png"], "mode": "direct", "modality": "image",
      "model": "Nano Banana 2", "max_credits": 0 }
  ]
}

Run (from this dir, concept-runners venv):
  ../.venv/Scripts/python.exe -u flow_runner.py briefs/smoke.json
  ../.venv/Scripts/python.exe -u flow_runner.py briefs/smoke.json --jobs smoke_img --keep-open
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
from pipeline import flow_browser as fb  # noqa: E402

PROFILE_DIR = HERE / "flow-profile"
OUT_DIR = HERE / "outputs"


def _resolve(p: str) -> Path:
    pp = Path(p)
    if pp.is_absolute() and pp.exists():
        return pp
    for base in (HERE, REPO, Path.cwd()):
        c = (base / p).resolve()
        if c.exists():
            return c
    return (HERE / p).resolve()


def run_job(page, job: dict, defaults: dict, project_url: str) -> dict:
    name = job["name"]
    mode = job.get("mode", defaults.get("mode", "agent"))
    brief = job["brief"]
    refs = [_resolve(r) for r in job.get("refs", [])]
    max_credits = job.get("max_credits", defaults.get("max_credits", 0))
    modality = job.get("modality", defaults.get("modality", "image"))
    aspect = job.get("aspect", defaults.get("aspect", "16:9"))
    quality = job.get("quality", defaults.get("quality", "x2"))
    model = job.get("model", defaults.get("model"))

    is_video = modality.startswith("v")
    submode = job.get("video_submode", defaults.get("video_submode", "ingredients"))
    print(f"\n=== JOB '{name}' (mode={mode}, modality={modality}"
          + (f"/{submode}" if is_video else "") + f", max_credits={max_credits}) ===")

    if refs:
        missing = [str(r) for r in refs if not r.exists()]
        if missing:
            print(f"[!] missing refs, skipping job: {missing}")
            return {"name": name, "status": "skipped", "reason": "missing_refs"}

    # Hard-reset the composer first so a prior (possibly aborted) job's leftover
    # prompt/refs never bleed into this one. Flow does not persist composer
    # attachments across a reload, so this guarantees a clean N-refs-in == N-seen.
    fb.reset_composer(page, project_url)

    is_frames = is_video and submode.lower().startswith("f")
    start_frame = job.get("start_frame")
    end_frame = job.get("end_frame")

    quoted = None
    if mode == "direct":
        # 1. Select modality/sub-mode FIRST so the right keyframe/ingredient slots exist.
        fb.set_agent(page, on=False)
        fb.open_model_panel(page)
        fb.set_modality(page, modality)
        if is_video:
            try: fb.set_video_submode(page, submode)
            except Exception as e: print("[!] video submode:", e)
        fb.close_panel(page)

        # 2. Attach inputs. Frames (FLF2V) -> Start/End keyframes; Ingredients -> refs.
        if is_frames:
            sp = _resolve(start_frame) if start_frame else (refs[0] if refs else None)
            ep = _resolve(end_frame) if end_frame else (refs[1] if len(refs) > 1 else None)
            if sp is None:
                print("[!] frames mode needs a start_frame — skipping job")
                return {"name": name, "status": "skipped", "reason": "no_start_frame"}
            n = fb.set_start_end_frames(page, sp, ep)
            print(f"[*] set {n} keyframe(s): start={sp.name}"
                  + (f", end={ep.name}" if ep else ""))
        elif refs:
            n = fb.upload_references(page, refs)
            print(f"[*] attached {n} reference image(s)")

        # 3. Re-open the panel, set the remaining knobs, and read the quote WHILE the
        #    panel is open (the 'Generating will use N credits' readout only exists
        #    inside the open panel). Do NOT close before reading.
        fb.open_model_panel(page)
        if is_video:
            try: fb.set_aspect(page, aspect)
            except Exception as e: print("[!] aspect:", e)
            dur = job.get("duration", defaults.get("duration"))
            if dur:
                try: fb.set_duration(page, dur)
                except Exception as e: print("[!] duration:", e)
            # video quality chip (1x is cheapest — e.g. Omni Flash 4s 1x = 7 cr)
            vq = job.get("quality", defaults.get("video_quality"))
            if vq:
                try: fb.set_quality(page, vq)
                except Exception as e: print("[!] video quality:", e)
        else:
            try: fb.set_aspect(page, aspect)
            except Exception as e: print("[!] aspect:", e)
            try: fb.set_quality(page, quality)
            except Exception as e: print("[!] quality:", e)
        if model:
            try: fb.choose_model(page, model)
            except Exception as e: print("[!] model:", e)
        quoted = fb.read_pending_credits(page)
        print(f"[*] Flow quoted credits: {quoted}")
        fb.close_panel(page)
    else:
        if refs:
            n = fb.upload_references(page, refs)
            print(f"[*] attached {n} reference image(s)")
        fb.set_agent(page, on=True)
        # agent mode: cost is decided after the agent plans; we can't pre-read it
        # reliably, so the agent-side guard is the brief wording + Flow's own
        # Approve dialog. We still log that no pre-quote was available.
        print("[*] agent mode: no pre-send credit quote (agent decides model).")

    # COST GUARD (direct mode). Fail-CLOSED: if we could not read a credit quote and
    # this job can cost credits (video always does; image>0 only if max_credits>0),
    # ABORT rather than risk an un-capped spend. "If unknown, don't burn."
    if mode == "direct":
        if quoted is None:
            if is_video or max_credits > 0:
                print(f"[ABORT] no credit quote could be read for '{name}' "
                      f"(video={is_video}, max_credits={max_credits}). "
                      f"Refusing to send to avoid un-capped spend.")
                return {"name": name, "status": "aborted_no_quote", "max_credits": max_credits}
            # image + max_credits==0: known-free (Nano Banana 2), safe to proceed
        elif quoted > max_credits:
            print(f"[ABORT] quoted {quoted} cr > max_credits {max_credits}. Not sending '{name}'.")
            return {"name": name, "status": "aborted_cost", "quoted": quoted, "max_credits": max_credits}

    fb.type_brief(page, brief)
    if not fb.composer_text(page):
        print("[!] composer empty after type — retrying once")
        fb.type_brief(page, brief)

    job_dir = OUT_DIR / name
    saved = []

    if is_video:
        # Video: a loading placeholder bumps the tile count instantly, so we snapshot
        # the existing video media-names and wait for NEW, FINISHED ones (Veo renders
        # 2 variations per x2 submit). Each new name -> mp4 via page.request.get.
        pre_names = fb.video_names(page)
        fb.send(page)
        want = job.get("expect_videos", 2)  # x2 => 2 variations
        print(f"[*] sent (video). pre-existing videos={len(pre_names)}. "
              f"waiting for {want} new finished video(s)…")
        new_names = fb.wait_for_new_videos(page, pre_names, want=want,
                                           timeout_s=job.get("timeout_s", 600))
        if not new_names:
            print(f"[!] job '{name}': timeout — no new finished video appeared")
            return {"name": name, "status": "timeout", "quoted": quoted, "saved": []}
        status = "done"
        print(f"[ok] job '{name}': {len(new_names)} new video(s) -> {new_names}")
        if job.get("download", True):
            job_dir.mkdir(parents=True, exist_ok=True)
            for i, nm in enumerate(new_names, 1):
                url = fb.video_url_for(nm)
                out = job_dir / f"{name}_{i:02d}.mp4"
                res = fb.download_video(page, url, out)
                if res.get("ok") and res["bytes"] > 100_000:
                    saved.append(str(out))
                    print(f"[ok] saved {out.name} ({res['bytes']} bytes, {res.get('ct')})")
                else:
                    print(f"[!] video download {i} ({nm}) failed/too-small: {res}")
        return {"name": name, "status": status, "quoted": quoted, "saved": saved}

    # IMAGE path: a tile-count bump is a reliable 'new result' signal.
    pre = fb.collect_media_urls(page)
    pre_set = set(pre["images"]) | set(pre["videos"])
    baseline = fb.count_result_tiles(page)
    fb.send(page)
    print(f"[*] sent (image). baseline tiles={baseline}. waiting for a new result…")
    ok = fb.wait_for_new_result(page, baseline, timeout_s=job.get("timeout_s", 600))
    status = "done" if ok else "timeout"
    print(f"[{'ok' if ok else '!'}] job '{name}': {status}")
    if ok and job.get("download", True):
        page.wait_for_timeout(2500)
        post = fb.collect_media_urls(page)
        new_imgs = [u for u in post["images"] if u not in pre_set]
        job_dir.mkdir(parents=True, exist_ok=True)
        import base64
        for i, url in enumerate(new_imgs, 1):
            res = fb.fetch_media_b64(page, url)
            if not res.get("ok"):
                print(f"[!] image download {i} failed: {res}")
                continue
            ext = fb.ext_for(res.get("content_type", ""))
            out = job_dir / f"{name}_{i:02d}{ext}"
            out.write_bytes(base64.b64decode(res["b64"]))
            saved.append(str(out))
            print(f"[ok] saved {out.name} ({res['bytes']} bytes, {res.get('content_type')} via {res.get('via')})")
        if not new_imgs:
            print("[!] no NEW image urls detected to download (check grid).")

    return {"name": name, "status": status, "quoted": quoted, "saved": saved}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("brief_path")
    ap.add_argument("--jobs", help="comma-separated job names to run (default: all)")
    ap.add_argument("--keep-open", action="store_true", help="leave the window open at the end")
    ap.add_argument("--headless", action="store_true")
    args = ap.parse_args()

    brief = json.loads(_resolve(args.brief_path).read_text(encoding="utf-8"))
    defaults = brief.get("defaults", {})
    project_url = brief["project_url"]
    jobs = brief["jobs"]
    if args.jobs:
        want = {j.strip() for j in args.jobs.split(",")}
        jobs = [j for j in jobs if j["name"] in want]
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    pw, ctx, page = fb.launch(PROFILE_DIR, headless=args.headless)
    results = []
    try:
        fb.open_project(page, project_url)
        print(f"[*] project open: {page.url}")
        for job in jobs:
            try:
                results.append(run_job(page, job, defaults, project_url))
            except Exception as e:
                print(f"[!] job '{job.get('name')}' crashed: {e}")
                results.append({"name": job.get("name"), "status": "crash", "error": str(e)})
        print("\n=== SUMMARY ===")
        for r in results:
            extra = ""
            if r.get("quoted") is not None:
                extra += f" (quoted {r['quoted']})"
            if r.get("saved"):
                extra += f" -> {len(r['saved'])} file(s) saved"
            print(f"  {r['name']}: {r['status']}{extra}")
        if args.keep_open:
            print("[*] --keep-open: window stays up 120s for inspection.")
            page.wait_for_timeout(120_000)
        return 0
    finally:
        try: ctx.close()
        except Exception: pass
        try: pw.stop()
        except Exception: pass


if __name__ == "__main__":
    sys.exit(main())
