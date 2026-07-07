"""Google Flow browser primitives (Playwright, persistent authed profile).

Recon-verified DOM (2026-06-29):
  - project url      : labs.google/fx/tools/flow/project/<uuid>
  - composer         : div[role=textbox][contenteditable=true]  ("What do you want to create?")
  - send             : the composer's trailing arrow_forward / "Create" affordance
  - add media (refs) : the leading '+' (add_2) → input[type=file]
  - Agent toggle      : an "Agent" pill. ON hides the manual model picker (agent picks
                        the model itself); OFF shows the model button.
  - model picker      : the "Nano Banana 2 ... x2" button → panel with
                          Image | Video modality toggle,
                          aspect (16:9 4:3 1:1 3:4 9:16),
                          quality (1x x2 x3 x4),
                          model dropdown (Nano Banana 2 / Nano Banana Pro / ...video models),
                          a live "Generating will use N credits" readout.
  - result grid       : finished tiles; videos carry a play_circle overlay.

Two runner modes map 1:1 onto the two composer states:
  - mode="agent"  : Agent ON, just write the natural-language brief and send.
  - mode="direct" : Agent OFF, set modality/aspect/quality/model explicitly, then send.

Hard cost guard: read_pending_credits() lets the runner refuse to send when the
quoted credit cost exceeds a cap (Pro = 1000 cr pool; cheapest-model rule).
"""
from __future__ import annotations

import re
import time
from pathlib import Path
from typing import Optional

from playwright.sync_api import Page, sync_playwright

FLOW_BASE = "https://labs.google/fx/tools/flow"
COMPOSER = "div[role='textbox'][contenteditable='true']"
# the composer model button's label varies by selection. Recon-verified forms:
#   image mode : 'Nano Banana 2 ... x2'
#   video mode : 'Video\ncrop_16_9\nx2'  (icon-stacked: modality + aspect-icon + quality)
#              : or a model name once picked ('Omni Flash', 'Veo 3.1 - Lite', …)
# Present only when Agent is OFF. Match any of these but NOT the bare 'Agent' pill.
_MODEL_BTN_RE = r"nano banana|omni flash|veo|seedance|hailuo|kling|crop_\d|video\b"


# ---------- context ----------

def launch(profile_dir: Path, headless: bool = False):
    pw = sync_playwright().start()
    ctx = pw.chromium.launch_persistent_context(
        user_data_dir=str(profile_dir),
        headless=headless,
        # full-size window — never open at a cramped low resolution (Flow's grid +
        # composer panels need the room).
        no_viewport=True,
        accept_downloads=True,
        args=[
            "--disable-blink-features=AutomationControlled",
            "--disable-features=IsolateOrigins,site-per-process",
            "--start-maximized",
            "--window-size=1920,1080",
        ],
    )
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    return pw, ctx, page


def open_project(page: Page, project_url: str) -> None:
    page.goto(project_url, wait_until="domcontentloaded", timeout=60_000)
    page.wait_for_timeout(7000)
    if "accounts.google" in page.url or "/signin" in page.url.lower():
        raise RuntimeError("Flow bounced to login — re-run login.py to refresh the session.")
    # dismiss any first-run popover
    try:
        page.keyboard.press("Escape")
        page.wait_for_timeout(500)
    except Exception:
        pass


# ---------- composer ----------

def _composer(page: Page):
    return page.locator(COMPOSER).last


def clear_composer(page: Page) -> None:
    c = _composer(page)
    c.click()
    page.keyboard.press("Control+A")
    page.keyboard.press("Delete")
    page.wait_for_timeout(150)


def type_brief(page: Page, text: str) -> None:
    """Idempotent: always clear first, then type. (Mirror of the ChatGPT runner's
    paste-idempotence rule — a send no-op + retry must never double the prompt.)"""
    clear_composer(page)
    c = _composer(page)
    c.click()
    # contenteditable: type so Flow's editor registers input events
    page.keyboard.insert_text(text)
    page.wait_for_timeout(300)
    got = (c.inner_text() or "").strip()
    if not got:
        # fallback: char-typed
        page.keyboard.type(text, delay=4)
        page.wait_for_timeout(300)


def composer_text(page: Page) -> str:
    try:
        return (_composer(page).inner_text() or "").strip()
    except Exception:
        return ""


# ---------- agent toggle ----------
#
# Recon-verified 2026-06-29: the composer's 'Agent' control is a real
# <button aria-pressed="true|false">. aria-pressed is the AUTHORITATIVE state —
# "true"=Agent ON. When ON, the composer bar trailing slot shows the
# Agent-Instructions + Settings icons and HIDES the model button. When OFF, those
# icons are replaced by the model button ('Video crop_16_9 x2' / a model name).
# The only reliable toggle is a Playwright LOCATOR click on the exact-text
# 'Agent' element (a JS el.click() and even a mouse-coord click on the pill were
# unreliable; the locator click flips it every time). State PERSISTS across runs.

def agent_pressed(page: Page) -> Optional[bool]:
    """Read the Agent button's aria-pressed. True=Agent ON, False=OFF, None if the
    button isn't found."""
    val = page.evaluate(r"""() => {
      for (const b of document.querySelectorAll('button')) {
        if ((b.innerText||'').trim()==='Agent') return b.getAttribute('aria-pressed');
      }
      return null;
    }""")
    if val is None:
        return None
    return val == "true"


def is_model_picker_visible(page: Page) -> bool:
    """Model picker is shown only when Agent is OFF. Authoritative read = Agent
    aria-pressed is False."""
    p = agent_pressed(page)
    return p is False


def set_agent(page: Page, on: bool) -> None:
    """Toggle the Agent pill to the requested state and VERIFY via aria-pressed.
    Uses a Playwright locator click on the exact-text 'Agent' element (the only
    click that reliably flips it). Retries once."""
    for _ in range(3):
        cur = agent_pressed(page)
        if cur is None:
            # composer not ready yet; give it a beat then re-read
            page.wait_for_timeout(800)
            cur = agent_pressed(page)
            if cur is None:
                return
        if cur == on:
            return
        try:
            page.get_by_text("Agent", exact=True).last.click(timeout=3000)
        except Exception:
            return
        page.wait_for_timeout(1500)


# ---------- model picker (direct mode) ----------

def open_model_panel(page: Page) -> bool:
    """Open the composer model panel. The model button's label depends on the
    current selection (Nano Banana 2 in image mode, Omni Flash / Veo in video mode),
    so match any of them and mouse-click the composer-bar model button. Returns True
    if the panel opened (the 'Generating will use' readout appears)."""
    rect = page.evaluate(
        r"""(re) => {
          const rx = new RegExp(re, 'i');
          let best=null, area=1e9;
          for (const b of document.querySelectorAll('button')) {
            const t=(b.innerText||'').trim();
            if (t==='Agent') continue;              // never the Agent pill
            if (rx.test(t) && t.length<60) {
              const r=b.getBoundingClientRect();
              // the composer model button sits low on the page (bottom bar)
              if (r.width>0 && r.height>0 && r.y>500) {
                const a=r.width*r.height; if(a<area){area=a; best={x:r.x+r.width/2,y:r.y+r.height/2};}
              }
            }
          }
          return best;
        }""",
        _MODEL_BTN_RE,
    )
    if rect:
        page.mouse.click(rect["x"], rect["y"])
        page.wait_for_timeout(1400)
        # confirm the panel actually opened (the credit readout or modality toggle appears)
        ok = page.evaluate(r"""() => {
          for (const s of document.querySelectorAll('[data-radix-popper-content-wrapper]')) {
            if (/Generating will use|Ingredients|Frames/i.test(s.innerText||'')) return true;
          }
          return false;
        }""")
        return bool(ok)
    return False


def set_modality(page: Page, modality: str) -> None:
    """modality: 'image' or 'video'. Panel must be open. The Image|Video toggle
    lives INSIDE the open model popper (data-radix-popper-content-wrapper). We scope
    the click to that popper so the sidebar's 'Videos'/'View videos' never match.
    Verifies the switch took (the model dropdown flips to video models)."""
    label = "Video" if modality.lower().startswith("v") else "Image"
    # React/radix ignores a JS el.click() (no synthetic pointer event), so we locate
    # the toggle <button>'s center via DOM and fire a REAL Playwright mouse click.
    rect = page.evaluate(
        r"""(label) => {
          const scopes = [...document.querySelectorAll('[data-radix-popper-content-wrapper]')];
          if (!scopes.length) scopes.push(document.body);
          const other = label==='Video' ? 'Image' : 'Video';
          for (const scope of scopes) {
            for (const b of scope.querySelectorAll('button')) {
              const t=(b.innerText||'').trim();
              if ((t===label || t.endsWith('\n'+label)) && !t.includes(other)) {
                const r=b.getBoundingClientRect();
                if (r.width>0 && r.height>0) return {x:r.x+r.width/2, y:r.y+r.height/2};
              }
            }
          }
          return null;
        }""",
        label,
    )
    if rect:
        page.mouse.click(rect["x"], rect["y"])
    page.wait_for_timeout(1100)
    return bool(rect)


def _click_panel_chip(page: Page, label: str) -> bool:
    """Fire a REAL Playwright mouse click on the smallest visible panel chip whose
    trimmed text equals `label` or ends with '\\n'+label (icon+label chips). React/
    radix ignores a JS el.click(), so we resolve the chip's center and mouse-click it.
    Scoped to the open popper when present. Returns True if found+clicked."""
    rect = page.evaluate(
        r"""(label) => {
            const scopes = [...document.querySelectorAll('[data-radix-popper-content-wrapper]')];
            const roots = scopes.length ? scopes : [document.body];
            let best=null, area=1e9;
            for (const root of roots) {
              for (const e of root.querySelectorAll('button,div,span')) {
                const t=(e.innerText||'').trim();
                if (t===label || t.endsWith('\n'+label)) {
                  const r=e.getBoundingClientRect();
                  if (r.width>0 && r.height>0){ const a=r.width*r.height;
                    if(a<area){area=a; best={x:r.x+r.width/2, y:r.y+r.height/2};} }
                }
              }
            }
            return best;
        }""",
        label,
    )
    if rect:
        page.mouse.click(rect["x"], rect["y"])
        return True
    return False


def set_video_submode(page: Page, submode: str) -> None:
    """Video modality has two sub-modes (panel + composer change accordingly):
      'frames'      -> Start/End keyframe interpolation (FLF2V). Composer shows
                       Start ⇄ End slots.
      'ingredients' -> multi-reference identity lock (the 4-ref formula). Refs are
                       fed as 'ingredients' so the model holds the subject's identity
                       from every angle as the camera moves.
    Panel must be open (Video already selected)."""
    label = "Ingredients" if submode.lower().startswith("i") else "Frames"
    _click_panel_chip(page, label)
    page.wait_for_timeout(800)


def set_aspect(page: Page, aspect: str) -> None:
    """aspect like '16:9','9:16','1:1','4:3','3:4'. Panel must be open."""
    _click_panel_chip(page, aspect)
    page.wait_for_timeout(500)


def set_quality(page: Page, q: str) -> None:
    """q in {'1x','x2','x3','x4'}. Panel must be open."""
    _click_panel_chip(page, q)
    page.wait_for_timeout(500)


def set_duration(page: Page, seconds: str) -> None:
    """Video duration chip: '4s','6s','8s','10s'. Panel must be open (video)."""
    _click_panel_chip(page, str(seconds))
    page.wait_for_timeout(500)


def choose_model(page: Page, name: str) -> bool:
    """Open the model dropdown and select the option matching `name`. Recon-verified
    video options: 'Omni Flash', 'Veo 3.1 - Lite', 'Veo 3.1 - Fast', 'Veo 3.1 - Quality'
    (each rendered as 'volume_up\\n<name>'). To disambiguate the three Veo variants,
    pass the FULL name (e.g. 'Veo 3.1 - Lite'); a bare 'Veo' is rejected as ambiguous.
    Panel must be open. Returns True if the option was clicked + selection confirmed."""
    target = name.strip()
    if target.lower() in ("veo", "veo 3.1"):
        # ambiguous across Lite/Fast/Quality — default to the cheapest (Lite)
        target = "Veo 3.1 - Lite"

    def _norm(t: str) -> str:
        # strip a leading icon line ('volume_up\nVeo 3.1 - Lite' -> 'Veo 3.1 - Lite')
        # and the trailing 'arrow_drop_down' on the current-selection row.
        lines = [l.strip() for l in t.split("\n") if l.strip()]
        lines = [l for l in lines if l not in ("volume_up", "arrow_drop_down")]
        return lines[-1] if lines else t.strip()

    # 1. open the dropdown by clicking the current model-name row (it ends with
    #    'arrow_drop_down'). Find it inside the open panel popper.
    row = page.evaluate(r"""() => {
      for (const s of document.querySelectorAll('[data-radix-popper-content-wrapper]')) {
        let best=null, area=1e9;
        for (const e of s.querySelectorAll('button,div,[role=combobox]')) {
          const t=(e.innerText||'').trim();
          const r=e.getBoundingClientRect();
          if (/arrow_drop_down/i.test(t) && r.width>120 && r.height>0 && r.height<70) {
            const a=r.width*r.height; if(a<area){area=a; best={x:r.x+r.width/2,y:r.y+r.height/2};}
          }
        }
        if (best) return best;
      }
      return null;
    }""")
    if row:
        page.mouse.click(row["x"], row["y"])
        page.wait_for_timeout(1100)

    # 2. click the option whose normalized text == target (exact), else endsWith.
    opt = page.evaluate(
        r"""(target) => {
          const norm = (t) => {
            let lines=(t||'').split('\n').map(s=>s.trim()).filter(Boolean);
            lines=lines.filter(l=>l!=='volume_up' && l!=='arrow_drop_down');
            return lines.length ? lines[lines.length-1] : (t||'').trim();
          };
          const want = target.toLowerCase();
          let exact=null, ends=null;
          for (const sc of document.querySelectorAll('[data-radix-popper-content-wrapper],[role=listbox],[role=menu]')) {
            for (const e of sc.querySelectorAll('button,div,[role=option],[role=menuitem],li')) {
              const t=(e.innerText||'').trim();
              if (!t || t.length>50 || e.children.length>2) continue;
              const n=norm(t).toLowerCase();
              const r=e.getBoundingClientRect();
              if (r.width<=0 || r.height<=0) continue;
              const c={x:r.x+r.width/2, y:r.y+r.height/2};
              if (n===want && !exact) exact=c;
              else if (n.endsWith(want) && !ends) ends=c;
            }
          }
          return exact || ends;
        }""",
        target,
    )
    if opt:
        page.mouse.click(opt["x"], opt["y"])
        page.wait_for_timeout(900)
        return True
    return False


def read_pending_credits(page: Page) -> Optional[int]:
    """Read the live 'Generating will use N credits' readout. Panel must be open.
    Returns int credits, or None if not shown."""
    try:
        txt = page.evaluate(r"""() => {
          for (const e of document.querySelectorAll('*')) {
            const t=(e.innerText||'').trim();
            if (/Generating will use/i.test(t) && t.length<60 && e.children.length<=3) return t;
          } return null;
        }""")
        if not txt:
            return None
        m = re.search(r"(\d+)\s*credit", txt, re.I)
        return int(m.group(1)) if m else None
    except Exception:
        return None


def close_panel(page: Page) -> None:
    try:
        page.keyboard.press("Escape")
        page.wait_for_timeout(400)
    except Exception:
        pass


# ---------- references ----------

def count_attached_refs(page: Page) -> int:
    """How many reference/ingredient thumbnails are currently attached to the
    composer (small chips with a remove 'x' / close affordance, low on the page)."""
    return page.evaluate(r"""() => {
      let n=0;
      // attached refs render as small thumbs near the composer with a remove button
      for (const b of document.querySelectorAll('button[aria-label*="Remove" i],button[aria-label*="remove" i]')) {
        const r=b.getBoundingClientRect();
        if (r.width>0 && r.height>0 && r.y>480) n++;
      }
      return n;
    }""")


def reset_composer(page: Page, project_url: str) -> None:
    """Hard-reset the composer to a clean state before a job. Re-navigating the
    project drops any leftover prompt text AND any refs attached by a prior
    (possibly aborted) job — Flow does not persist composer attachments across a
    reload, so this guarantees N refs in == N refs the model sees. State that DOES
    persist (Agent on/off, modality, model) is fine; the caller re-sets it."""
    page.goto(project_url, wait_until="domcontentloaded", timeout=60_000)
    page.wait_for_timeout(5000)
    try:
        page.keyboard.press("Escape")
        page.wait_for_timeout(300)
    except Exception:
        pass


def upload_references(page: Page, paths: list[Path]) -> int:
    """Attach reference images via the composer '+' file input (Ingredients mode).
    Returns count set."""
    if not paths:
        return 0
    fi = page.locator("input[type=file]").first
    fi.set_input_files([str(p) for p in paths])
    page.wait_for_timeout(2500)
    return len(paths)


def _click_frame_slot(page: Page, which: str) -> bool:
    """Click the composer's Start or End keyframe slot so the next file upload binds
    to it. Recon-verified: in Frames mode the composer shows small 'Start' and 'End'
    slots at y~813. Real mouse click (React)."""
    label = "Start" if which.lower().startswith("s") else "End"
    rect = page.evaluate(
        r"""(label) => {
          let best=null, area=1e9;
          for (const e of document.querySelectorAll('button,div,span')) {
            if ((e.innerText||'').trim()===label) {
              const r=e.getBoundingClientRect();
              if (r.width>0 && r.height>0 && r.y>480) { const a=r.width*r.height;
                if(a<area){area=a; best={x:r.x+r.width/2, y:r.y+r.height/2};} }
            }
          }
          return best;
        }""",
        label,
    )
    if rect:
        page.mouse.click(rect["x"], rect["y"])
        page.wait_for_timeout(700)
        return True
    return False


def set_start_end_frames(page: Page, start_path: Path, end_path: Optional[Path] = None) -> int:
    """Frames (FLF2V) mode: bind a Start keyframe (and optional End) by clicking the
    slot then setting the file input. Returns the number of frames set. Frames mode +
    submode must already be selected. Verifies each slot's preview changed."""
    n = 0
    fi = page.locator("input[type=file]").first
    if start_path is not None:
        if _click_frame_slot(page, "start"):
            fi.set_input_files(str(start_path))
            page.wait_for_timeout(2200)
            n += 1
    if end_path is not None:
        # re-resolve the file input (DOM may have re-rendered after the first set)
        fi = page.locator("input[type=file]").first
        if _click_frame_slot(page, "end"):
            fi.set_input_files(str(end_path))
            page.wait_for_timeout(2200)
            n += 1
    return n


# ---------- send + harvest ----------

def count_result_tiles(page: Page) -> int:
    """Approximate count of result tiles in the grid (img + video tiles)."""
    return page.evaluate(r"""() => {
      // grid media tiles tend to be large images / video thumbs in the main area
      let n=0;
      for (const im of document.querySelectorAll('img')) {
        const r=im.getBoundingClientRect();
        if (r.width>200 && r.height>140 && r.y>60) n++;
      }
      return n;
    }""")


def send(page: Page) -> None:
    """Trigger generation. The composer's trailing arrow_forward / 'Create' is the
    send affordance; Enter also submits in most builds. We click the arrow if found,
    else press Enter."""
    clicked = False
    try:
        # the trailing send control reads 'arrow_forward' / 'Create'
        btn = page.get_by_text("arrow_forward", exact=False).last
        if btn and btn.is_visible():
            btn.click(timeout=3000)
            clicked = True
    except Exception:
        pass
    if not clicked:
        _composer(page).click()
        page.keyboard.press("Enter")


def wait_for_new_result(page: Page, baseline: int, timeout_s: int = 600) -> bool:
    """Poll the grid until the tile count exceeds baseline (a new result landed).
    For IMAGES only — a tile bump is reliable. For video use wait_for_new_videos,
    because a loading/placeholder tile bumps the count long before the mp4 exists."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if count_result_tiles(page) > baseline:
            page.wait_for_timeout(1500)
            return True
        page.wait_for_timeout(4000)
    return False


def _media_name(url: str) -> Optional[str]:
    m = re.search(r"name=([0-9a-fA-F-]{8,})", url or "")
    return m.group(1) if m else None


def video_names(page: Page) -> list:
    """Set of media-name UUIDs for the videos currently present (finished OR still
    rendering). A video is identified by a <video> element OR an <img> tile whose
    media URL carries mediaUrlType=...THUMBNAIL (Flow renders a video poster as a
    thumbnail <img> while/after rendering)."""
    return page.evaluate(r"""() => {
      const names=new Set();
      const grab=(s)=>{ const m=(s||'').match(/name=([0-9a-fA-F-]{8,})/); if(m) names.add(m[1]); };
      for (const v of document.querySelectorAll('video')) grab(v.src||v.currentSrc);
      for (const im of document.querySelectorAll('img')) {
        const s=im.src||'';
        if (/MEDIA_URL_TYPE_THUMBNAIL/i.test(s)) grab(s);   // video poster thumbnails
      }
      return [...names];
    }""")


def wait_for_new_videos(page: Page, pre_names: list, want: int = 1,
                        timeout_s: int = 600) -> list:
    """Wait until `want` NEW video media-names (not in pre_names) appear AND are
    finished. 'Finished' = the new name resolves to a <video> with a real duration,
    or a stable THUMBNAIL poster that persists across two polls (rendering done).
    Returns the list of new names (newest-first by grid position), [] on timeout."""
    pre = set(pre_names)
    deadline = time.time() + timeout_s
    stable_seen = {}
    while time.time() < deadline:
        cur = page.evaluate(r"""() => {
          const out=[];
          const push=(name,y,kind,dur)=>{ if(name) out.push({name,y,kind,dur}); };
          for (const v of document.querySelectorAll('video')) {
            const s=v.src||v.currentSrc||''; const m=s.match(/name=([0-9a-fA-F-]{8,})/);
            const r=v.getBoundingClientRect();
            if (m) push(m[1], Math.round(r.y), 'video', v.duration||0);
          }
          for (const im of document.querySelectorAll('img')) {
            const s=im.src||''; if(!/MEDIA_URL_TYPE_THUMBNAIL/i.test(s)) continue;
            const m=s.match(/name=([0-9a-fA-F-]{8,})/); const r=im.getBoundingClientRect();
            if (m) push(m[1], Math.round(r.y), 'thumb', 0);
          }
          return out;
        }""")
        new = [c for c in cur if c["name"] not in pre]
        # finished = a <video> with duration>0, or a thumb seen stable for 2 polls
        finished = []
        for c in new:
            if c["kind"] == "video" and c["dur"] and c["dur"] > 0:
                finished.append(c)
            elif c["kind"] == "thumb":
                stable_seen[c["name"]] = stable_seen.get(c["name"], 0) + 1
                if stable_seen[c["name"]] >= 2:
                    finished.append(c)
        # de-dup by name, keep newest-first (smallest y = top of grid)
        seen, ordered = set(), []
        for c in sorted(finished, key=lambda c: c["y"]):
            if c["name"] not in seen:
                seen.add(c["name"]); ordered.append(c["name"])
        if len(ordered) >= want:
            page.wait_for_timeout(1500)
            return ordered
        page.wait_for_timeout(5000)
    return []


def video_url_for(name: str) -> str:
    """Build the session-authed media URL for a video media-name (page.request.get
    follows the redirect to the mp4)."""
    return f"{FLOW_BASE.replace('/tools/flow','')}/api/trpc/media.getMediaUrlRedirect?name={name}"


# ---------- download ----------
#
# Every Flow result media (img + video) carries a direct, session-authed media URL:
#   https://labs.google/fx/api/trpc/media.getMediaUrlRedirect?name=<uuid>
# There is no visible Download button on the tile/detail, so we harvest these URLs
# from the grid and fetch them in-page (the Flow session cookies authorize the
# redirect → CDN).

_MEDIA_RE = "media.getMediaUrlRedirect"


def collect_media_urls(page: Page) -> dict:
    """Return {'images': [url,...], 'videos': [url,...]} for the CURRENT grid,
    newest-first (top of grid). Video <video> elements are the i2v results; <img>
    tiles are images (and video posters share the same media endpoint)."""
    return page.evaluate(
        r"""(re) => {
          const isMedia = (s) => s && s.includes(re);
          const imgs = [];
          for (const im of document.querySelectorAll('img')) {
            const r = im.getBoundingClientRect();
            if (r.width > 160 && r.height > 100 && r.y > 60 && isMedia(im.src)) {
              imgs.push({y: Math.round(r.y), url: im.src});
            }
          }
          imgs.sort((a,b)=>a.y-b.y);
          const vids = [];
          for (const v of document.querySelectorAll('video')) {
            if (isMedia(v.src)) vids.push(v.src);
          }
          // de-dup preserving order
          const dedup = (arr) => [...new Set(arr)];
          return { images: dedup(imgs.map(i=>i.url)), videos: dedup(vids) };
        }""",
        _MEDIA_RE,
    )


def fetch_media_b64(page: Page, url: str) -> dict:
    """Download a media URL's bytes. Flow's getMediaUrlRedirect 302-redirects
    cross-origin to a CDN, so a plain fetch() is CORS-blocked ('Failed to fetch',
    opaqueredirect). But the media is already loaded in the DOM (<img> naturalW>0),
    so we draw the loaded <img> to a canvas and read its bytes. Returns
    {ok, b64, content_type, bytes}. (Images only — videos use download_video.)"""
    return page.evaluate(
        r"""async (url) => {
          // 1. try a plain authed fetch first (works for same-origin / non-redirect)
          try {
            const r = await fetch(url, { credentials: 'include' });
            if (r.ok) {
              const ct = r.headers.get('content-type') || '';
              const buf = await r.arrayBuffer();
              const bytes = new Uint8Array(buf);
              let bin=''; const CH=0x8000;
              for (let i=0;i<bytes.length;i+=CH) bin += String.fromCharCode.apply(null, bytes.subarray(i,i+CH));
              return { ok:true, b64: btoa(bin), content_type: ct, bytes: bytes.length, via:'fetch' };
            }
          } catch (e) { /* fall through to canvas */ }

          // 2. canvas path: find the loaded <img> for this url and snapshot it
          const im = [...document.querySelectorAll('img')].find(i => i.src === url || i.currentSrc === url);
          if (!im || !im.complete || !im.naturalWidth) return { ok:false, error:'img not loaded for canvas' };
          try {
            const c = document.createElement('canvas');
            c.width = im.naturalWidth; c.height = im.naturalHeight;
            const ctx = c.getContext('2d');
            ctx.drawImage(im, 0, 0);
            const dataUrl = c.toDataURL('image/png');   // may throw if tainted
            const b64 = dataUrl.split(',')[1];
            const bytes = Math.floor(b64.length * 3 / 4);
            return { ok:true, b64, content_type:'image/png', bytes, via:'canvas' };
          } catch (e) { return { ok:false, error:'canvas: '+String(e) }; }
        }""",
        url,
    )


def download_video(page: Page, url: str, out_path: Path, timeout_ms: int = 120_000) -> dict:
    """Videos can't be canvas-snapshotted. Use Playwright's APIRequestContext
    (page.request) — it carries the session cookies and follows the 302 redirect
    server-side (no CORS), so it fetches the CDN bytes directly. Returns
    {ok, bytes} or {ok:False, error}."""
    try:
        resp = page.request.get(url, timeout=timeout_ms)
        if not resp.ok:
            return {"ok": False, "error": f"status {resp.status}"}
        body = resp.body()
        out_path.write_bytes(body)
        return {"ok": True, "bytes": len(body), "ct": resp.headers.get("content-type")}
    except Exception as e:
        return {"ok": False, "error": str(e)}


def ext_for(content_type: str) -> str:
    ct = (content_type or "").lower()
    if "png" in ct:
        return ".png"
    if "jpeg" in ct or "jpg" in ct:
        return ".jpg"
    if "webp" in ct:
        return ".webp"
    if "mp4" in ct:
        return ".mp4"
    if "webm" in ct:
        return ".webm"
    if "gif" in ct:
        return ".gif"
    return ".bin"
