"""Magnific IMAGE Generator runner — JSON-brief driven, WEB-UI (unlimited tier),
$0 on ∞ models. Defaults to Seedream 5 Lite (2K-4K, ∞, Refs) — the flagship
4K-unlimited-with-references model.

Usage:
  cd tools/concept-runners/magnific
  ../../../.venv/Scripts/python.exe image_runner.py briefs/<name>.json
  ... image_runner.py briefs/<name>.json --jobs slot_1,slot_2   # subset
  ... image_runner.py --smoke                                   # 1 test shot

Brief schema (briefs/example_image.json):
{
  "defaults": {"model_slug":"seedream-5-lite","provider_slug":"seedream",
               "resolution":"4k","aspect":"3:4","require_unlimited":true},
  "jobs": [
    {"name":"glasswharf_master","prompt":"...","refs":["<path or character:@name>"],
     "aspect":"3:4","resolution":"4k","model_slug":"seedream-5-lite"}
  ]
}

Refs: a filesystem path, or "character:@name" / "element:@name" which resolves to
a saved Magnific library asset — ONLY assets whitelisted in ALLOWED_CHARACTER_IDS
below (CLAUDE.md IP boundary §2: Black Meridian original cast only, no other
series' characters/imagery). Black Meridian has no saved library characters yet;
populate ALLOWED_CHARACTER_IDS as they're created (see
pipeline.image_browser.create_character).
"""
from __future__ import annotations

import argparse
import base64
import json
import sys
import time
from pathlib import Path

# Windows cp1254 console crashes on the ∞ (∞) we print for unlimited models.
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

from pipeline.image_browser import (
    launch_context, open_image_generator, select_model, set_aspect,
    set_resolution, set_count, add_library_reference, upload_reference, set_prompt,
    set_nano_controls, select_preset, click_generate, wait_for_image, count_feed,
)
from pipeline.catalog import (
    LOCATIONS as CATALOG_LOCATIONS, ELEMENTS_BY_MAGNIFIC as CATALOG_ELEMENTS,
    MY_ELEMENTS, resolve_library,
)

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
PROFILE = HERE / "magnific-profile"
OUTROOT = HERE / "outputs"

# IP WHITELIST — saved Magnific Character library ids that are clean Black
# Meridian IP (CLAUDE.md IP boundary §2: original cast only, e.g. Aiko Velora).
# Empty until a character is saved to the Magnific library via
# pipeline.image_browser.create_character(). Add entries as
# {"name-lower": "<numeric library id>"}.
ALLOWED_CHARACTER_IDS: dict[str, str] = {}

# Whitelisted @-mention display names usable positionally in a prompt.
# token(lower) -> the display name the autocomplete popup shows.
ALLOWED_MENTIONS: dict[str, str] = {}

# Pacing: Magnific web UI can throttle rapid back-to-back submits (same lesson as
# the ChatGPT/video runners). Serialize + gap between jobs.
INTER_JOB_GAP_S = 20


def normalize_refs(refs: list) -> list[dict]:
    """Normalize brief refs into typed descriptors:
      {"kind":"library","type":"character","id":"<id>","label":"@name"}
      {"kind":"upload","type":"element","path":Path(...)}
    Accepts:
      - "character:@name"  -> whitelist-checked library character
      - "element:1234567"  -> library element by id
      - "style:<path>" / "element:<path>" / "<path>"  -> local upload
      - a dict {type, ref} where ref is "@name" | id | path
    Enforces the IP whitelist on any Character @-mention / library id.
    """
    out: list[dict] = []
    for r in refs or []:
        mention = None
        if isinstance(r, dict):
            rtype = (r.get("type") or "element").lower()
            ref = str(r.get("ref", "")).strip()
            mention = r.get("mention")  # positional @name for a library asset
        else:
            s = str(r).strip()
            if ":" in s and s.split(":", 1)[0].lower() in (
                    "character", "style", "element", "product"):
                rtype, ref = s.split(":", 1)
                rtype = rtype.lower()
                ref = ref.strip()
            else:
                rtype, ref = "element", s
        # library @-mention (Character / Element saved asset) — resolve to id
        # from the full library dump (pipeline/catalog.py), enforcing the IP rule.
        if ref.startswith("@"):
            name = ref[1:].lower()
            if rtype == "character":
                if name not in ALLOWED_CHARACTER_IDS:
                    raise SystemExit(
                        f"REFUSED: Character '@{name}' is not clean IP. "
                        f"Allowed: {sorted(ALLOWED_CHARACTER_IDS)}")
                out.append({"kind": "library", "type": "character",
                            "id": ALLOWED_CHARACTER_IDS[name], "label": ref,
                            "mention": ref})
            elif rtype in ("element", "product"):
                lid = resolve_library("element", name)
                if not lid:
                    raise SystemExit(
                        f"Element '@{name}' not in your library. Known: "
                        f"{sorted(MY_ELEMENTS)}")
                out.append({"kind": "library", "type": "element", "id": lid,
                            "label": ref, "mention": ref})
            else:
                raise SystemExit(f"@-mention for type '{rtype}' needs a numeric id; "
                                 f"pass '{rtype}:<id>' instead of '{ref}'.")
            continue
        # library numeric id
        if ref.isdigit():
            if rtype == "character" and ref not in ALLOWED_CHARACTER_IDS.values():
                raise SystemExit(f"REFUSED: character id {ref} is not whitelisted.")
            out.append({"kind": "library", "type": rtype, "id": ref,
                        "label": ref, "mention": mention})
            continue
        # local upload path
        p = Path(ref) if Path(ref).is_absolute() else (HERE / ref)
        if not p.exists():
            p = REPO / ref
        if not p.exists():
            raise SystemExit(f"Ref path not found: {ref}")
        out.append({"kind": "upload", "type": rtype, "path": p})
    return out[:8]


def download_url(page, url: str, out_path: Path) -> bool:
    """Download a specific image URL via in-page session-authed fetch → base64."""
    b64 = page.evaluate(r"""
    async (u) => {
      try{ const r=await fetch(u); const b=await r.blob(); if(b.size<5000) return null;
        return await new Promise(res=>{const fr=new FileReader();fr.onload=()=>res(fr.result);fr.readAsDataURL(b);});
      }catch(e){ return 'ERR:'+e.message; }
    }""", url)
    if not b64 or not b64.startswith("data:"):
        if b64:
            print(f"    [download_url] {str(b64)[:80]}")
        return False
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(base64.b64decode(b64.split(",", 1)[1]))
    return out_path.stat().st_size > 5000


def download_latest(page, out_path: Path) -> bool:
    """Fallback: download the image with the HIGHEST pikaso creation-id currently
    on the page (= the newest render). Same url model as wait_for_image; the url is
    fetched verbatim (never transformed — the token has literal =/~)."""
    url = page.evaluate(r"""() => {
      let best=null, bestId=-1;
      for(const i of document.querySelectorAll('img')){
        const m=(i.src||'').match(/\/production\/(\d+)\/render\.(?:png|jpg)/i);
        if(m && Number(m[1])>bestId){ bestId=Number(m[1]); best=i.src; }
      }
      return best;
    }""")
    if not url:
        return False
    return download_url(page, url, out_path)


def run(brief_path: Path, only: set[str] | None, smoke: bool):
    if smoke:
        brief = {
            "defaults": {"model_slug": "seedream-5-lite", "provider_slug": "seedream",
                         "resolution": "4k", "aspect": "3:4", "require_unlimited": True},
            "jobs": [{
                "name": "black_meridian_smoke",
                "prompt": ("Neo-noir concept keyframe of a rain-soaked interspecies "
                           "metropolis district at night, wet asphalt reflecting neon "
                           "signage, elevated transit line overhead, dense vertical "
                           "architecture, cinematic wide shot, moody teal-and-amber "
                           "lighting, high-fidelity production concept art."),
                "refs": [],
            }],
        }
        campaign = "smoke"
    else:
        brief = json.loads(brief_path.read_text(encoding="utf-8"))
        campaign = brief_path.stem
    d = brief.get("defaults", {})
    jobs = brief["jobs"]
    if only:
        jobs = [j for j in jobs if j["name"] in only]
    out_dir = OUTROOT / campaign
    out_dir.mkdir(parents=True, exist_ok=True)

    pw, ctx = launch_context(PROFILE, headless=False)
    try:
        page = open_image_generator(ctx)
        for i, job in enumerate(jobs):
            name = job["name"]
            out_path = out_dir / f"{name}.png"
            if out_path.exists():
                print(f"[skip] {name} already exists")
                continue
            model = job.get("model_slug", d.get("model_slug", "seedream-5-lite"))
            provider = job.get("provider_slug", d.get("provider_slug"))
            req_unl = job.get("require_unlimited", d.get("require_unlimited", True))
            aspect = job.get("aspect", d.get("aspect", "3:4"))
            resolution = job.get("resolution", d.get("resolution", "4k"))
            refs = normalize_refs(job.get("refs", []))

            print(f"\n=== [{i+1}/{len(jobs)}] {name} — {model} {resolution} {aspect} "
                  f"({len(refs)} refs) ===")
            select_model(page, model, provider_slug=provider, require_unlimited=req_unl)
            # Nano-Banana-only controls (Thinking level + Google Search) — no-op on
            # other models. High + Search on = best identity/product fidelity.
            set_nano_controls(page,
                              thinking=job.get("thinking", d.get("thinking", "high")),
                              google_search=job.get("google_search", d.get("google_search", True)))
            # Attach refs FIRST (uploads must precede the prompt so their @imgN
            # mention names exist). Each UPLOAD becomes @img1, @img2, ... in upload
            # order (verified live); library characters keep their @name. Build the
            # per-job mention whitelist so the prompt can position each as a chip.
            job_mentions = dict(ALLOWED_MENTIONS)
            # By-Magnific built-ins are mention-addressable by their fixed @name
            # (Locations + stock Elements) — no library id needed. Whitelist them
            # so the prompt can chip '@rooftop', '@totebag', etc. positionally.
            for _loc in CATALOG_LOCATIONS:
                job_mentions[_loc.lower()] = _loc.lower()
            for _el in CATALOG_ELEMENTS:
                job_mentions[_el.lower()] = _el.lower()
            # MY OWN saved library Elements are also positionally mention-addressable
            # by @name — whitelist them so a prompt can chip '@some-asset' WITHOUT a
            # refs entry (picking the mention auto-attaches the element).
            for _en in MY_ELEMENTS:
                job_mentions[_en.lower()] = _en.lower()
            upload_idx = 0
            for rf in refs:
                if rf["kind"] == "library":
                    add_library_reference(page, rf["type"], rf["id"])
                    # Any attached library asset (Character/Element/Style) becomes a
                    # positional @mention by its library NAME. 'add' opens the
                    # picker; once attached, the prompt must reference it via
                    # @name. Register that name.
                    mn = rf.get("mention")
                    if mn:
                        mn = mn.lstrip("@").lower()
                        job_mentions[mn] = mn
                        print(f"    -> library {rf['type']} {rf['id']} is @{mn}")
                    elif rf["type"] == "character" and rf.get("label", "").startswith("@"):
                        nm = rf["label"][1:].lower()
                        job_mentions[nm] = nm
                else:
                    upload_reference(page, rf["path"], ref_type=rf["type"])
                    upload_idx += 1
                    tok = f"img{upload_idx}"
                    job_mentions[tok] = tok  # @img1, @img2, ...
                    print(f"    -> upload #{upload_idx} is @{tok}")
            # Camera / Effects PRESETS (modal-select, NOT @mentions). Accept a
            # single string or a list per job/default. Presets tag the generation
            # (lens/lighting/mood) — they don't consume a ref slot.
            for kind in ("camera", "effects"):
                val = job.get(kind, d.get(kind))
                if not val:
                    continue
                for nm in (val if isinstance(val, list) else [val]):
                    select_preset(page, kind, nm)
            set_prompt(page, job["prompt"], allowed_mentions=job_mentions)
            # count FIRST (before aspect/resolution open popovers that can eat the
            # stepper click / make the value read stale — the real 'stuck at 2' cause)
            set_count(page, job.get("count", d.get("count", 1)))  # default 1, not stale panel N
            set_aspect(page, aspect)
            set_resolution(page, resolution.upper())

            # NOTE: Magnific's count stepper is capped at 1 (one image per Generate).
            # For identity-lottery variations, RE-RUN the same brief (a fresh seed
            # each run) rather than asking for count>1 — the UI won't produce more
            # than one. So we always download the single newest render.
            baseline = click_generate(page, require_unlimited=req_unl)
            ts = job.get("timeout_s", 300)
            new_url = wait_for_image(page, baseline, timeout_s=ts)
            if new_url and download_url(page, new_url, out_path):
                print(f"[ok] saved {out_path}")
            elif download_latest(page, out_path):
                print(f"[ok] saved {out_path} (via fallback)")
            else:
                print(f"[!] generated but download failed for {name} — grab it from the feed")
            if i < len(jobs) - 1:
                time.sleep(INTER_JOB_GAP_S)
        print(f"\n[done] outputs in {out_dir}")
    finally:
        ctx.close()
        pw.stop()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("brief", nargs="?", help="path to brief JSON")
    ap.add_argument("--jobs", help="comma-separated job names to run")
    ap.add_argument("--smoke", action="store_true", help="run one Black Meridian test shot")
    a = ap.parse_args()
    if not a.smoke and not a.brief:
        ap.error("provide a brief path or --smoke")
    only = set(a.jobs.split(",")) if a.jobs else None
    run(Path(a.brief) if a.brief else Path("smoke"), only, a.smoke)


if __name__ == "__main__":
    main()
