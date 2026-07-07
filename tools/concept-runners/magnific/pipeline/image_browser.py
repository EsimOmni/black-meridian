"""Playwright primitives for driving Magnific's IMAGE Generator
(`/app/ai-image-generator`). Selectors LIVE-VERIFIED via recon_generators.py on
2026-07-01. All generation here runs on the WEB UI (unlimited tier) — never MCP.

Key recon facts encoded below:
  * Panel/form = `image-generator-form`. Prompt = contenteditable
    `image-prompt-input` (type `@` to mention refs). Aspect = `image-aspect-ratio-input`
    (opens `popover-option-<val>`). Generate = `generate-button`.
  * The MODEL trigger has NO dedicated data-cy — it's the button next to the
    "MODEL" label. We open it by locating the MODEL text then clicking the
    nearest button, then click the model row
    `tti-model-selector-popover-model-<slug>` (FEATURED) or
    `tti-model-selector-popover-provider-model-<slug>` (inside a provider group,
    which must be expanded first via `…-provider-<providerSlug>`).
  * UNLIMITED models carry an `∞` icon `<use xlink:href="…/sprite/<hash>.svg#infinity">`
    (credit models use `…#infinity`→`…#credits`); NOT text. We assert the chosen
    model is unlimited before generating unless the brief opts into credits.
  * REFERENCES: `reference-add-button` opens the ref modal; a real file upload
    goes through `advanced-selection-upload-file-input` (type=file). We upload
    from disk (IP-clean) rather than picking library `library-character-*`
    thumbnails (which include IP-disputed talents).
"""
from __future__ import annotations

import time
from pathlib import Path
from typing import Optional

from playwright.sync_api import sync_playwright, BrowserContext, Page

IMAGE_URL = "https://www.magnific.com/app/ai-image-generator"

CY_FORM = "image-generator-form"
CY_PROMPT = "image-prompt-input"
CY_GENERATE = "generate-button"
CY_ASPECT = "image-aspect-ratio-input"
CY_UPLOAD_INPUT = "advanced-selection-upload-file-input"


def launch_context(profile_dir: Path, headless: bool = False):
    pw = sync_playwright().start()
    ctx = pw.chromium.launch_persistent_context(
        user_data_dir=str(profile_dir),
        headless=headless,
        viewport={"width": 1440, "height": 900},
        accept_downloads=True,
        args=["--disable-blink-features=AutomationControlled"],
    )
    return pw, ctx


def _panel_ready(page: Page) -> bool:
    try:
        return page.locator(f'[data-cy="{CY_FORM}"]').first.is_visible(timeout=2500)
    except Exception:
        return False


def open_image_generator(ctx: BrowserContext, login_timeout_ms: int = 300_000) -> Page:
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    page.goto(IMAGE_URL, wait_until="domcontentloaded", timeout=60_000)
    page.wait_for_timeout(4000)
    anon = page.locator('button:has-text("Log in"), a:has-text("Log in"), button:has-text("Continue with Google")')
    if anon.count() > 0 and not _panel_ready(page):
        print(f"[!] Log in to Magnific by hand within {login_timeout_ms//1000}s.")
        deadline = time.time() + login_timeout_ms / 1000
        while time.time() < deadline:
            if _panel_ready(page):
                break
            page.wait_for_timeout(2500)
        else:
            raise RuntimeError("Login not completed in time.")
    # panel can be slow on a cold start — poll up to ~30s, and re-navigate once
    for attempt in range(2):
        for _ in range(12):
            if _panel_ready(page):
                print(f"[ok] Image generator ready: {page.url[:80]}")
                return page
            page.wait_for_timeout(2500)
        if attempt == 0:
            page.goto(IMAGE_URL, wait_until="domcontentloaded", timeout=60_000)
            page.wait_for_timeout(4000)
    raise RuntimeError("Image panel did not load — DOM may have changed.")


def _open_model_picker(page: Page) -> bool:
    """Open the model popover by clicking the button next to the MODEL label."""
    ok = page.evaluate(r"""
    () => {
      const f=document.querySelector('[data-cy="image-generator-form"]')||document;
      const labels=[...f.querySelectorAll('*')].filter(el=>/^MODEL$/i.test((el.innerText||'').trim())&&el.children.length===0);
      for(const lab of labels){let row=lab.parentElement;
        for(let i=0;i<4&&row;i++){const c=row.querySelector('button,[role="button"]');if(c){c.click();return true;}row=row.parentElement;}}
      return false;
    }""")
    if ok:
        page.wait_for_timeout(1200)
    return bool(ok)


def select_model(page: Page, slug: str, provider_slug: Optional[str] = None,
                 require_unlimited: bool = True) -> None:
    """Pick a model by slug. Expands the provider group first if given. Asserts
    the model row carries the ∞ (sprite `#infinity`) icon when require_unlimited."""
    if not _open_model_picker(page):
        raise RuntimeError("Could not open the model picker.")
    # expand provider group if the model lives inside one
    if provider_slug:
        try:
            page.locator(f'[data-cy$="model-selector-popover-provider-{provider_slug}"]').first.click(force=True, timeout=4000)
            page.wait_for_timeout(700)
        except Exception:
            pass
    # find the row: FEATURED cy or provider-model cy
    row = None
    for cy in (f'tti-model-selector-popover-model-{slug}',
               f'tti-model-selector-popover-provider-model-{slug}'):
        loc = page.locator(f'[data-cy="{cy}"]').first
        if loc.count():
            row = loc
            break
    if row is None:
        # last resort: match by visible name text inside the popover
        row = page.get_by_text(slug.replace("-", " "), exact=False).first
    if not row or not row.count():
        raise RuntimeError(f"Model row not found for slug={slug!r}")
    # read the row's ∞ state with a short retry (the icon SVG can mount a beat
    # after the row does; a single snapshot is flaky — this caused a false
    # 'not unlimited' on an already-selected model).
    # The row carries an svg sprite ref: `…/sprite/<hash>.svg#infinity` for
    # unlimited, `…#credits` for credit-costing (LIVE-VERIFIED 2026-07-07 — Magnific
    # renamed the fragment from the old `#cdn-infinity`). Match `#infinity` and treat
    # an explicit `#credits` as authoritative NOT-unlimited.
    has_inf = False
    for _ in range(4):
        try:
            h = row.inner_html() or ""
            if "#credits" in h:
                has_inf = False
                break
            if "#infinity" in h:
                has_inf = True
                break
        except Exception:
            pass
        page.wait_for_timeout(400)
    row.click(force=True, timeout=5000)
    page.wait_for_timeout(1200)
    if require_unlimited and not has_inf:
        # secondary check: the panel's own unlimited indicator ('Unlimited
        # generations' text / the ∞ ON pill next to Generate) is authoritative
        # for the CURRENTLY selected model. If it says unlimited, trust it.
        panel_unlimited = page.evaluate(r"""()=>{
          const t=document.body.innerText||'';
          const gen=document.querySelector('[data-cy="generate-button"]');
          const near=gen?(gen.closest('div')?.innerText||''):'';
          return /Unlimited generations/i.test(t) || /Unlimited/i.test(near);
        }""")
        if not panel_unlimited:
            raise RuntimeError(
                f"Model {slug!r} is NOT unlimited (no ∞ icon, panel not unlimited) — "
                f"it would burn credits. Set require_unlimited=False to allow it.")
        print(f"[ok] model = {slug} (∞ unlimited — via panel indicator)")
        return
    print(f"[ok] model = {slug} ({'∞ unlimited' if has_inf else 'credit-ok'})")


def set_nano_controls(page: Page, thinking: str = "high", google_search: bool = True) -> None:
    """Nano-Banana-only controls behind the model gear (`model-settings-button`):
    Thinking level (Fast=`thinking-level-minimal-button` / High=`thinking-level-high-button`)
    and Google Search (`image-generator-use-google-search-tool`). High + Search on
    = the best identity/product fidelity. No-op for models without these controls."""
    gear = page.locator('[data-cy="model-settings-button"]').first
    if not gear.count():
        return  # not a Nano model / no settings gear
    try:
        gear.click(force=True, timeout=3000)
        page.wait_for_timeout(700)
    except Exception:
        return
    # thinking level
    want = (thinking or "high").lower()
    tcy = "thinking-level-high-button" if want in ("high", "quality") else "thinking-level-minimal-button"
    tb = page.locator(f'[data-cy="{tcy}"]').first
    if tb.count():
        try:
            tb.click(force=True, timeout=2500)
            print(f"[ok] Nano thinking = {want}")
        except Exception:
            pass
    # google search toggle — read its current on/off then flip only if needed
    gs = page.locator('[data-cy="image-generator-use-google-search-tool"]').first
    if gs.count():
        is_on = page.evaluate(r"""()=>{const w=document.querySelector('[data-cy="image-generator-use-google-search-tool"]');
          if(!w) return null; const sw=w.querySelector('[role="switch"],button,input[type=checkbox]');
          const a=(sw&&(sw.getAttribute('aria-checked')||sw.getAttribute('aria-pressed')));
          if(a!=null) return a==='true';
          // fallback: an 'on' switch usually has an accent bg class
          return /bg-(primary|accent|blue|green)|data-state="checked"/i.test((sw&&sw.outerHTML)||'');
        }""")
        if bool(is_on) != bool(google_search):
            try:
                gs.click(force=True, timeout=2500)
                print(f"[ok] Nano Google Search -> {google_search}")
            except Exception:
                pass
        else:
            print(f"[ok] Nano Google Search already {google_search}")
    # close the settings popover so it doesn't cover the stepper/generate
    try:
        page.keyboard.press("Escape")
        page.wait_for_timeout(300)
    except Exception:
        pass


def _read_count(page: Page) -> int:
    try:
        return int((page.locator('[data-cy="number-images-value"]').first.inner_text() or "1").strip())
    except Exception:
        return -1


def set_count(page: Page, count: int) -> None:
    """Set the number-of-images stepper to `count`. The runner passes 1 by default
    so a job never silently produces whatever N the panel was left on (a stale
    panel value of 2 made 4 images across two runs). Clicks decrease/increase
    until the displayed value actually reaches the target (verified: one click
    moves it by 1)."""
    count = max(1, min(int(count), 8))
    # Close any open popover (aspect/resolution) first — an overlay left open can
    # eat the click / make _read_count read a stale value (that was the real
    # 'stuck at 2' cause, not a broken stepper — recon proved the click works).
    try:
        page.keyboard.press("Escape")
        page.wait_for_timeout(250)
    except Exception:
        pass

    def _settled_count(tries: int = 5) -> int:
        # read a few times ~120ms apart; return the value once it's stable
        last, same = None, 0
        for _ in range(tries):
            v = _read_count(page)
            if v == last:
                same += 1
                if same >= 1:
                    return v
            else:
                last, same = v, 0
            page.wait_for_timeout(120)
        return last if last is not None else -1

    guard = 0
    cur = _settled_count()
    while cur != count and guard < 14:
        btn = "increase-number-images-button" if cur < count else "decrease-number-images-button"
        try:
            page.locator(f'[data-cy="{btn}"]').first.click(force=True, timeout=2500)
        except Exception:
            print(f"[!] count stepper '{btn}' click failed at {cur}")
            break
        page.wait_for_timeout(500)
        new = _settled_count()
        if new == cur:            # value truly didn't move after settling
            # one more real mouse click at the button center before giving up
            box = page.locator(f'[data-cy="{btn}"]').first.bounding_box()
            if box:
                page.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
                page.wait_for_timeout(500)
                new = _settled_count()
            if new == cur:
                print(f"[!] count stepper stuck at {cur} (target {count})")
                break
        cur = new
        guard += 1
    print(f"[ok] image count = {cur} (target {count})")


def set_aspect(page: Page, ratio: str) -> None:
    """Open the aspect popover and pick `popover-option-<ratio>`. Uses NATIVE DOM
    clicks (same quirk as set_resolution — Playwright force-click did NOT open/commit
    the popover reliably here). The option text is e.g. '16:9 Widescreen', so we
    target it by its exact cy, never by exact text."""
    try:
        opened = page.evaluate(r"""()=>{const b=document.querySelector('[data-cy="image-aspect-ratio-input"]');
          if(!b) return false; b.click(); return true;}""")
        if not opened:
            print(f"[!] aspect input pill not found")
            return
        page.wait_for_timeout(700)
        picked = page.evaluate(r"""(r)=>{const o=document.querySelector('[data-cy="popover-option-'+r+'"]');
          if(o){ o.click(); return true; } return false;}""", ratio)
        if not picked:
            print(f"[!] aspect option 'popover-option-{ratio}' not found")
            return
        page.wait_for_timeout(500)
        print(f"[ok] aspect = {ratio}")
    except Exception as e:
        print(f"[!] aspect {ratio} not set: {e}")


def set_resolution(page: Page, res: str) -> None:
    """Resolution control is a button ('1K'/'2K'/'4K') → popover options. The UI
    labels are UPPERCASE ('1K'), so normalize the incoming res (brief may say '1k').
    If we can't confirm the target is selected, RAISE — a silently-kept model default
    (often 2K/4K) leaves the unlimited tier and the credit-guard would then abort."""
    target = res.strip().upper()  # '1k' -> '1K'
    if not target.endswith("K"):
        target += "K"
    # Some models bake resolution into the slug (e.g. `seedream-4-4k`) and expose NO
    # resolution pill at all. That's a legitimate fixed-resolution model, not a
    # credit risk — the pre-Generate is_generate_unlimited() guard is the real
    # safety net before spend. So a MISSING pill is a clean no-op, not a RAISE.
    has_pill = page.evaluate(r"""()=>!!document.querySelector('[data-cy="image-resolution-input"]')""")
    if not has_pill:
        print(f"[ok] no resolution pill — model has a fixed resolution (target {target} implied)")
        return
    try:
        # If the pill already shows the target, done.
        shown0 = page.evaluate(r"""()=>{const b=document.querySelector('[data-cy="image-resolution-input"]');
          return b?(b.innerText||'').trim().toUpperCase():null;}""")
        if shown0 and target in shown0:
            print(f"[ok] resolution already {target}")
            return
        # OPEN the pill via a real DOM click (Playwright force-click did NOT open the
        # popover here; probe proved a native .click() does) — cy `image-resolution-input`.
        opened = page.evaluate(r"""()=>{const b=document.querySelector('[data-cy="image-resolution-input"]');
          if(!b) return false; b.click(); return true;}""")
        if not opened:
            raise RuntimeError("no image-resolution-input pill")
        page.wait_for_timeout(700)
        # CLICK the popover-option BUTTON whose exact text is the target (feed badges
        # share the same 1K/4K text but a DIFFERENT cy, so scope to popover-option).
        picked = page.evaluate(r"""(t)=>{
          const opts=[...document.querySelectorAll('[data-cy="popover-option"]')];
          const hit=opts.find(o=>(o.innerText||'').trim().toUpperCase()===t);
          if(hit){ hit.click(); return true; } return false;
        }""", target)
        if not picked:
            raise RuntimeError(f"popover-option {target} not found (popover may not have opened)")
        page.wait_for_timeout(600)
        shown = page.evaluate(r"""()=>{const b=document.querySelector('[data-cy="image-resolution-input"]');
          return b?(b.innerText||'').trim().toUpperCase():null;}""")
        if shown and target not in shown:
            raise RuntimeError(f"resolution pill shows {shown!r}, wanted {target}")
        print(f"[ok] resolution = {target}")
    except Exception as e:
        raise RuntimeError(
            f"resolution {target} NOT set (would keep model default, likely a "
            f"credit-costing 2K/4K tier): {e}")


def _ref_counter(page: Page) -> str:
    """Return the 'N/8' references counter text (empty if not found)."""
    return page.evaluate(r"""()=>{const ri=document.querySelector('[data-cy="image-references-input"]');
      return ri?(ri.innerText.match(/(\d)\/8/)||[''])[0]:'';}""")


# ref modal slot openers by ref type
_SLOT_OPENER = {
    "character": '[data-cy="reference-character-placeholder"]',
    "style": '[data-cy="reference-style-placeholder"]',
    "element": '[data-cy="reference-add-button"]',   # Element/generic uses Add
    "product": '[data-cy="reference-add-button"]',
}

# confirm-selection button labels (verified: 'Add' is the one that commits;
# 'Confirm My Choices' / 'Apply' also appear — try in order)
_CONFIRM_LABELS = ["Add", "Confirm My Choices", "Apply", "Use selection", "Done"]


def _close_ref_modal(page: Page) -> None:
    """Close the reference / advanced-selection modal if it's open. Leaving it open
    makes it intercept pointer events on the next job (prompt-box click hangs 30s)."""
    for _ in range(3):
        modal = page.locator('[data-cy="advanced-selection-modal"]').first
        if not (modal.count() and modal.is_visible()):
            return
        closed = False
        for sel in ('[data-cy="advanced-selection-modal"] [data-cy*="close" i]',
                    '[data-cy="video-modal-close-button-desktop"]',
                    '[data-cy*="modal-close" i]'):
            b = page.locator(sel).first
            if b.count() and b.is_visible():
                try:
                    b.click(force=True, timeout=2000); closed = True; break
                except Exception:
                    pass
        if not closed:
            try:
                page.keyboard.press("Escape")
            except Exception:
                pass
        page.wait_for_timeout(500)


def select_preset(page: Page, kind: str, name: str) -> bool:
    """Select a CAMERA or EFFECTS preset (recon 2026-07-01). These are NOT
    @mentions and NOT library ids — they're fixed-name buttons `<name>-item` under
    the Camera/Effects sidebar tab. `kind` in {'camera','effects'}, `name` the
    preset (e.g. 'close-up', 'golden-hour'). Returns True if selected.

    Camera/Effects presets tag the generation (lens/lighting/mood); they don't
    consume a ref slot. Open modal → tab → click the item → commit."""
    from .catalog import SIDEBAR_TAB_CY, normalize_preset
    exact = normalize_preset(kind, name)
    if not exact:
        print(f"[!] {kind} preset '{name}' not in catalog — skipped.")
        return False
    # open the ref modal (generic Add) then the right tab
    add = page.locator('[data-cy="reference-add-button"]').first
    if add.count():
        add.click(force=True, timeout=4000)
        page.wait_for_timeout(1200)
    tab = page.locator(f'[data-cy="{SIDEBAR_TAB_CY[kind]}"]').first
    if tab.count():
        tab.click(force=True, timeout=3000)
        page.wait_for_timeout(1000)
    # effects has sub-filters (all/color/lighting/mood/action) — 'all' shows every item
    allbtn = page.locator('[data-cy="advanced-effects-tab-all-button"]').first
    if kind == "effects" and allbtn.count():
        try:
            allbtn.click(force=True, timeout=2000)
            page.wait_for_timeout(500)
        except Exception:
            pass
    item = page.locator(f'[data-cy="{exact}-item"]').first
    if not item.count():
        # scroll to load, then retry
        for _ in range(6):
            page.mouse.wheel(0, 1400)
            page.wait_for_timeout(300)
            if page.locator(f'[data-cy="{exact}-item"]').first.count():
                break
        item = page.locator(f'[data-cy="{exact}-item"]').first
    if not item.count():
        print(f"[!] {kind} preset item '{exact}-item' not found.")
        _close_ref_modal(page)  # don't leave the modal open for the next job
        return False
    item.click(force=True, timeout=3000)
    page.wait_for_timeout(700)
    # commit if a confirm button exists (some presets apply on click, some need Add)
    for label in _CONFIRM_LABELS:
        b = page.get_by_role("button", name=label, exact=False)
        if b.count():
            try:
                b.first.click(force=True, timeout=2500)
                break
            except Exception:
                continue
    page.wait_for_timeout(600)
    _close_ref_modal(page)  # ensure the modal is closed before we move on
    print(f"[ok] {kind} preset = {exact}")
    return True


def create_library_model(page: Page, kind: str, name: str, image_paths: list,
                         product_type: str = "", description: str = "",
                         gender: str = None, commit: bool = True) -> bool:
    """Create a NEW library **Element** OR **Character** from up to 9 uploaded local
    images (recon 2026-07-01). Only path that (a) takes LOCAL files and (b) allows 9
    (MCP `library_create` caps at 6 + needs public URLs). Element + Character share
    the SAME modal cy prefix `library-create-custom-model-*`; they differ only in:
      - which sidebar tab you open first (product vs character), and
      - the trigger is the shared `library-create-button` ("Create") in that panel;
      - character adds a `-gender` button (default Female) + a `-base` voice picker
        (we NEVER touch voice — the user sets it later).
    Flow: ref modal → <tab> → 'Create' → modal → set files → wait uploads → fill
    name/(type)/description → 'Create your <kind>'. `commit=False` = dry run.
    `kind` ∈ {'element','character'}. `product_type` only applies to elements.
    `gender` (character only) ∈ {'Female','Male','Non-binary'}; None keeps default."""
    kind = kind.lower()
    if kind not in ("element", "character"):
        raise ValueError(f"kind must be element|character, got {kind!r}")
    tab_cy = "reference-sidebar-product" if kind == "element" else "reference-sidebar-character"
    paths = [str(p) for p in image_paths][:9]
    if not paths:
        raise RuntimeError("create_library_model: no images given.")
    # open ref modal + the right tab
    add = page.locator('[data-cy="reference-add-button"]').first
    if add.count():
        add.click(force=True, timeout=5000)
        page.wait_for_timeout(1400)
    tab = page.locator(f'[data-cy="{tab_cy}"]').first
    if tab.count():
        tab.click(force=True, timeout=3000)
        page.wait_for_timeout(1000)
    # click Create — shared trigger `library-create-button` (opens the modal for the
    # ACTIVE tab), with the element-only `new-product-button` as a fallback.
    trig = None
    for sel in ('[data-cy="library-create-button"]', '[data-cy="new-product-button"]'):
        loc = page.locator(sel).first
        if loc.count():
            trig = loc; break
    if trig is None:
        raise RuntimeError("create trigger not found (library-create-button).")
    trig.click(force=True, timeout=4000)
    page.wait_for_timeout(1500)
    modal = page.locator('[data-cy="library-create-custom-model-modal"]').first
    if not modal.count():
        raise RuntimeError("create-element modal did not open.")
    # set the multiple-file input INSIDE the create modal (accept incl. avif,
    # multiple:true, no cy) — pick the one scoped to this modal.
    file_inp = modal.locator('input[type=file][multiple]').first
    if not file_inp.count():
        file_inp = page.locator('input[type=file][accept*="avif"]').first
    file_inp.set_input_files(paths, timeout=30000)
    print(f"[ok] set {len(paths)} images on the create-element file input")
    page.wait_for_timeout(2500)
    # click 'Upload' if the dropzone stages files before adding them
    up = page.locator('[data-cy="library-create-custom-model-upload"]').first
    if up.count() and up.is_visible():
        try:
            up.click(force=True, timeout=3000)
            page.wait_for_timeout(2500)
        except Exception:
            pass
    # WAIT FOR UPLOADS TO FINISH (bug: Create was clicked before thumbs settled).
    # Each staged image renders as `library-create-custom-model-reference-<n>`;
    # poll until the count is stable at len(paths) across two reads (or timeout).
    want = len(paths)
    stable = 0
    last = -1
    for _ in range(60):  # up to ~60s
        n = modal.locator('[data-cy^="library-create-custom-model-reference-"]').count()
        if n >= want and n == last:
            stable += 1
            if stable >= 2:
                break
        else:
            stable = 0
        last = n
        page.wait_for_timeout(1000)
    print(f"[ok] {last}/{want} reference thumbnails staged")
    # name / type / description. The 'Create your element' button stays DISABLED
    # until the NAME is filled (recon: 9/9 thumbs but create disabled + name empty).
    # A JS value-set does NOT flip React's controlled state — must TYPE via the
    # keyboard (click the input, select-all, type char-by-char) so input events
    # fire. An overlay may eat a normal click, so click(force=True) first.
    def _type(cy: str, value: str):
        loc = page.locator(f'[data-cy="{cy}"]').first
        if not loc.count():
            return
        # PROVEN (probe 2026-07-01): Playwright fill() DOES flip React's tracker
        # here — after a single fill() on the name field the 'Create your element'
        # button enabled. The earlier keyboard-dance (click+Ctrl-A+press_sequentially
        # +Tab) was what BROKE it: a post-fill overlay/toast intercepted the click
        # and the extra focus churn reset the field → button re-disabled. So: just
        # fill(). No click, no keyboard, no blur — nothing to disturb React state.
        loc.fill("")
        loc.fill(value)
        page.wait_for_timeout(250)
    # gender (character only) — a button that opens a small menu; default is Female,
    # so only touch it if a non-default gender is asked. NEVER touch the voice picker
    # (`-base`) — the user sets voice manually later.
    if kind == "character" and gender:
        gbtn = page.locator('[data-cy="library-create-custom-model-gender"]').first
        if gbtn.count() and gender.lower() != (gbtn.inner_text() or "").strip().lower():
            try:
                gbtn.click(force=True, timeout=3000)
                page.wait_for_timeout(500)
                opt = page.get_by_text(gender, exact=True).first
                if opt.count():
                    opt.click(force=True, timeout=3000)
                    page.wait_for_timeout(400)
            except Exception as e:
                print(f"[!] gender set skipped: {e}")
    _type("library-create-custom-model-name", name)
    if kind == "element" and product_type:
        _type("library-create-custom-model-type", product_type)
    if description:
        _type("library-create-custom-model-description", description)
    page.wait_for_timeout(600)
    # verify the name actually landed in the DOM value (proves keyboard entry worked)
    try:
        nval = page.locator('[data-cy="library-create-custom-model-name"]').first.input_value()
        print(f"[ok] name field value = {nval!r}")
    except Exception:
        pass
    if not commit:
        print(f"[dry] create-{kind} filled but NOT committed (commit=False).")
        return False
    create_btn = page.locator('[data-cy="library-create-custom-model-create"]').first
    # poll until ENABLED — require it stable across 2 reads (an early false-positive
    # made an earlier run click while still disabled).
    en = 0
    for _ in range(30):
        try:
            en = en + 1 if create_btn.is_enabled() else 0
        except Exception:
            en = 0
        if en >= 2:
            break
        page.wait_for_timeout(1000)
    else:
        raise RuntimeError(f"'Create your {kind}' never enabled — name/upload issue.")
    # NORMAL click first; if a toast/overlay intercepts pointer events (seen in
    # probe), fall back to a JS .click() which ignores the overlay. Then CONFIRM
    # success by the modal CLOSING; retry via keyboard Enter on the button if not.
    create_btn.scroll_into_view_if_needed(timeout=3000)
    try:
        create_btn.click(timeout=5000)
    except Exception:
        page.evaluate("""() => {
          const b = document.querySelector('[data-cy="library-create-custom-model-create"]');
          if (b && !b.disabled) b.click();
        }""")
    closed = False
    for _ in range(20):
        page.wait_for_timeout(1000)
        if page.locator('[data-cy="library-create-custom-model-modal"]').count() == 0:
            closed = True
            break
    if not closed:
        # second attempt: focus the button and press Enter/Space
        try:
            create_btn.focus()
            page.keyboard.press("Enter")
        except Exception:
            pass
        for _ in range(15):
            page.wait_for_timeout(1000)
            if page.locator('[data-cy="library-create-custom-model-modal"]').count() == 0:
                closed = True
                break
    if not closed:
        raise RuntimeError(f"Clicked 'Create your {kind}' but the modal did not close "
                           "— submit did not register. Run with --hold and click by hand.")
    print(f"[ok] created {kind} '{name}' from {len(paths)} images (modal closed).")
    return True


def create_element(page: Page, name: str, image_paths: list, product_type: str = "",
                   description: str = "", commit: bool = True) -> bool:
    """Thin wrapper — create a library ELEMENT. See create_library_model()."""
    return create_library_model(page, "element", name, image_paths,
                                product_type=product_type, description=description,
                                commit=commit)


def create_character(page: Page, name: str, image_paths: list, description: str = "",
                     gender: str = None, commit: bool = True) -> bool:
    """Thin wrapper — create a library CHARACTER (identity-lock from up to 9 face/
    body refs). Voice is NEVER set here (the `-base` picker is left untouched — set
    it manually in the UI later). `gender` None keeps the modal default (Female)."""
    return create_library_model(page, "character", name, image_paths,
                                description=description, gender=gender, commit=commit)


def add_library_reference(page: Page, ref_type: str, library_id: str) -> None:
    """Attach a SAVED library asset (Character/Style/Element) as a reference by
    its numeric library id. This is the correct identity-lock path (verified: it
    increments the N/8 counter). `library_id` = the numeric id from the
    `library-<type>-thumbnail-<ID>` cy. NEVER pass an IP-disputed id — the runner
    enforces the whitelist upstream."""
    before = _ref_counter(page)
    opener = _SLOT_OPENER.get(ref_type, '[data-cy="reference-add-button"]')
    loc = page.locator(opener).first
    if not (loc.count() and loc.is_visible()):
        loc = page.locator('[data-cy="reference-add-button"]').first
    loc.click(force=True, timeout=4000)
    page.wait_for_timeout(1400)
    # Sidebar tab cy — NOTE Magnific labels it "Element" but the cy is
    # 'reference-sidebar-product' (recon 2026-07-01). Map UI type -> real cy.
    tab_cy = {"character": "reference-sidebar-character", "style": "reference-sidebar-style",
              "element": "reference-sidebar-product", "product": "reference-sidebar-product",
              "location": "reference-sidebar-locations"}.get(ref_type)
    if tab_cy:
        t = page.locator(f'[data-cy="{tab_cy}"]').first
        if t.count():
            t.click(force=True, timeout=3000)
            page.wait_for_timeout(1200)
    # make sure we're on the Library sub-tab (not Suggested/By-Magnific)
    lib_tab = page.locator('[data-cy="tab-library"]').first
    if lib_tab.count() and lib_tab.is_visible():
        try:
            lib_tab.click(force=True, timeout=2000)
            page.wait_for_timeout(800)
        except Exception:
            pass
    # Select the asset. Elements/products expose NO '-select-button' — the CARD
    # itself is clickable: `library-<noun>-thumbnail-<id>`. Character may use a
    # select-button. Try select-button first, then fall back to the card/media.
    # The noun in the cy is singular per type: element|character|style|location.
    noun = {"element": "element", "product": "element", "character": "character",
            "style": "style", "location": "location"}.get(ref_type, ref_type)
    cands = [
        f'[data-cy="library-{noun}-thumbnail-{library_id}-select-button"]',
        f'[data-cy$="thumbnail-{library_id}-select-button"]',
        f'[data-cy="library-{noun}-thumbnail-{library_id}-media"]',
        f'[data-cy="library-{noun}-thumbnail-{library_id}"]',
        f'[data-cy$="thumbnail-{library_id}"]',
    ]
    sel = None
    for c in cands:
        l = page.locator(c).first
        if l.count():
            sel = l
            break
    if sel is None:
        raise RuntimeError(f"Library asset {ref_type}:{library_id} not found in the picker "
                           f"(tried {cands}).")
    sel.click(force=True, timeout=4000)
    page.wait_for_timeout(1200)
    # confirm/commit the selection
    for label in _CONFIRM_LABELS:
        b = page.get_by_role("button", name=label, exact=False)
        if b.count():
            try:
                b.first.click(force=True, timeout=3000)
                break
            except Exception:
                continue
    page.wait_for_timeout(1500)
    after = _ref_counter(page)
    if after == before:
        raise RuntimeError(f"Reference {ref_type}:{library_id} did NOT attach "
                           f"(counter stayed {before!r}). The generation would ignore it.")
    print(f"[ok] {ref_type} ref {library_id} attached ({before} -> {after})")


def upload_reference(page: Page, image_path: Path, ref_type: str = "element") -> None:
    """Upload a LOCAL image as a reference and COMMIT it (the missing commit step
    was why the first smoke test's refs never attached — counter stayed 0/8).
    Prefer add_library_reference for a saved Character; use this only for one-off
    product/style images not in the library."""
    before = _ref_counter(page)
    opener = _SLOT_OPENER.get(ref_type, '[data-cy="reference-add-button"]')
    loc = page.locator(opener).first
    if not (loc.count() and loc.is_visible()):
        loc = page.locator('[data-cy="reference-add-button"]').first
    loc.click(force=True, timeout=4000)
    page.wait_for_timeout(1200)
    inp = page.locator(f'input[type=file][data-cy="{CY_UPLOAD_INPUT}"]')
    try:
        inp.first.wait_for(state="attached", timeout=6000)
        target = inp.first
    except Exception:
        target = page.locator('input[type=file][accept*="image"]').last
    target.set_input_files(str(image_path), timeout=15000)
    page.wait_for_timeout(3000)  # let the upload render as a selectable tile
    # commit — the uploaded image must be confirmed into the refs (the fix)
    for label in _CONFIRM_LABELS:
        b = page.get_by_role("button", name=label, exact=False)
        if b.count():
            try:
                b.first.click(force=True, timeout=3000)
                break
            except Exception:
                continue
    page.wait_for_timeout(1500)
    after = _ref_counter(page)
    if after == before:
        raise RuntimeError(f"Uploaded {image_path.name} did NOT attach "
                           f"(counter stayed {before!r}).")
    print(f"[ok] uploaded+attached reference: {image_path.name} ({before} -> {after})")


def _mention_count(page: Page) -> int:
    return page.evaluate(r"""()=>{const b=document.querySelector('[data-cy="image-prompt-input"]');
      if(!b) return 0;
      const chips=[...b.querySelectorAll('button,[data-cy*="mention"],[class*="mention"]')]
        .filter(e=>/@/i.test(e.innerText||''));
      return chips.length;}""")


def _popup_option_visible(page: Page, name: str) -> bool:
    return page.evaluate(
        r"""(n)=>[...document.querySelectorAll('button')]
              .some(b=>((b.innerText||'').trim()===n) && b.getBoundingClientRect().width>0)""",
        name)


def _pick_mention(page: Page, name: str, timeout_ms: int = 4000) -> bool:
    """Accept the autocomplete suggestion for `name` as a SINGLE clean chip.

    Verified behavior: typing '@name' shows exactly one matching option, and
    pressing Enter inserts ONE chip. Clicking the option (+ typing the full
    token) caused DOUBLE insertion. So: ensure the desired option is the sole/top
    suggestion, then press Enter. If several options show (e.g. img1/img10 both
    match a partial), we narrow by typing more chars until only the exact one
    remains, THEN Enter."""
    # wait for the popup to offer the exact option
    deadline = time.time() + timeout_ms / 1000
    while time.time() < deadline:
        if _popup_option_visible(page, name):
            break
        page.wait_for_timeout(250)
    else:
        return False
    # count how many options are visible; if >1, the top may be wrong → click the
    # exact one instead of Enter. If exactly the one we want is top, Enter is clean.
    n_opts = page.evaluate(
        r"""()=>[...document.querySelectorAll('button')]
              .filter(b=>b.getBoundingClientRect().width>0 &&
                /^(img\d+|[\w-]{2,20})$/.test((b.innerText||'').trim()) &&
                b.closest('[class*="mention"],[data-tippy-root],[role="listbox"],[class*="popover"],[class*="suggestion"]'))
              .length""")
    if n_opts <= 1:
        page.keyboard.press("Enter")
    else:
        # multiple: click the exact-text option (avoids Enter picking the wrong top)
        clicked = page.evaluate(
            r"""(n)=>{const b=[...document.querySelectorAll('button')]
                  .find(x=>((x.innerText||'').trim()===n)&&x.getBoundingClientRect().width>0);
                  if(b){b.click();return true;}return false;}""", name)
        if not clicked:
            page.keyboard.press("Enter")
    page.wait_for_timeout(700)
    return True


def set_prompt(page: Page, text: str, allowed_mentions: dict | None = None) -> None:
    """Type the prompt, converting any `@token` in the text into a REAL,
    POSITIONAL mention chip via the autocomplete popup (the healthy path is
    USING the mention in-place, not avoiding it — positional mentions are
    required for multi-ref scenes like '@aiko-velora holding @product in @cafe').

    `allowed_mentions`: {token_lower: display_name} whitelist. A `@token` not in
    it is REFUSED (IP guard). If None, no `@` is allowed and any is stripped.

    We clear the box first (Ctrl+A→Delete) then type segment-by-segment: literal
    text is typed; at each `@token`, we type '@'+token slowly to trigger the
    popup and click the matching option, yielding exactly ONE positional chip
    (no double-mention, no stray text)."""
    import re
    _close_ref_modal(page)  # a leftover ref/preset modal would intercept the click
    box = page.locator(f'[data-cy="{CY_PROMPT}"]').first
    box.click()
    page.keyboard.press("Control+A")
    page.keyboard.press("Delete")
    page.wait_for_timeout(300)

    parts = re.split(r'(@[\w-]+)', text)
    inserted = 0
    for seg in parts:
        if not seg:
            continue
        if seg.startswith("@"):
            token = seg[1:].lower()
            if allowed_mentions is None or token not in allowed_mentions:
                # not whitelisted → drop the mention silently (IP guard) but keep flow
                print(f"[!] prompt @{token} not in allowed mentions — dropped.")
                continue
            display = allowed_mentions[token]
            # Type '@' + a SHORT partial so the popup surfaces the option WITHOUT
            # the editor auto-accepting the full literal token (full-token typing
            # caused a DOUBLE 'img1 img1'). For 'img1' -> '@img' (then _pick_mention
            # narrows img1 vs img10 and Enters exactly once). Cap the partial so it
            # never equals the full token.
            base = display.rstrip("0123456789")            # 'img' from 'img1'
            partial = base[:5] if len(base) >= 3 else display[:max(3, len(display) - 1)]
            if partial == display:                          # never type the full token
                partial = display[:-1]
            box.type("@" + partial, delay=70)
            if _pick_mention(page, display):
                inserted += 1
                box.type(" ", delay=5)  # separator after the chip
            else:
                print(f"[!] mention popup did not offer '{display}' — clearing stray text.")
                for _ in range(len("@" + partial)):
                    page.keyboard.press("Backspace")
        else:
            box.type(seg, delay=3)
    page.wait_for_timeout(400)
    chips = _mention_count(page)
    print(f"[ok] prompt set ({len(text)} chars, {inserted} positional mention(s), "
          f"{chips} chip(s) in box)")


def count_feed(page: Page) -> int:
    return page.locator('[data-cy="generated-image-group"], [data-cy^="feed-item"]').count()


# DOWNLOAD MODEL (recon 2026-07-01): every rendered image is a pikaso CDN url
#   https://pikaso.cdnpk.net/private/production/<CREATION_ID>/render.(png|jpg)?token=…~hmac=…&preview=1
# The <CREATION_ID> is UNIQUE per image and MONOTONIC (larger = newer). So the
# reliable "a new image landed" signal is a creation-id LARGER than the pre-gen
# max — NOT a url-set diff (feed re-renders swap query tokens and reorder, which
# made the old set-diff grab a wrong/older frame). ⚠️ Never URL()-transform the
# url — the token carries literal `=`/`~` that URL-encoding corrupts. Fetch as-is.
_PIKASO_RE = r"""
() => {
  const out = [];
  for (const i of document.querySelectorAll('img')) {
    const u = i.src || '';
    const m = u.match(/\/production\/(\d+)\/render\.(?:png|jpg)/i);
    if (m) out.push({id: Number(m[1]), url: u});
  }
  return out;
}
"""


def _pikaso_imgs(page: Page) -> list[dict]:
    try:
        return page.evaluate(_PIKASO_RE) or []
    except Exception:
        return []


def _max_creation_id(page: Page) -> int:
    imgs = _pikaso_imgs(page)
    return max((i["id"] for i in imgs), default=0)


def snapshot_cdn_images(page: Page) -> int:
    """Baseline for wait_for_image: the current MAX pikaso creation-id on the page.
    A newly generated image will have a strictly larger id."""
    return _max_creation_id(page)


def is_generate_unlimited(page: Page) -> bool:
    """Read whether the CURRENT config (model × resolution × count) is unlimited.
    The Generate button/subtitle reads 'Unlimited generations' when ∞, or shows a
    credit cost otherwise. This is the AUTHORITATIVE per-config check right before
    spend — the model-row ∞ icon only reflects the model, not the resolution tier
    (e.g. Nano Banana 2 may be ∞ at 1K but cost credits at 2K/4K)."""
    return bool(page.evaluate(r"""()=>{
      const gen=document.querySelector('[data-cy="generate-button"]');
      const near=gen?(gen.closest('div')?.innerText||gen.innerText||''):'';
      const body=document.body.innerText||'';
      // credit-cost hint near generate = NOT unlimited
      if(/\bcredit/i.test(near) && !/unlimited/i.test(near)) return false;
      return /Unlimited generations/i.test(body) || /Unlimited/i.test(near);
    }"""))


def click_generate(page: Page, require_unlimited: bool = True) -> set:
    """Click Generate; return the pre-generation set of CDN image URLs as the
    baseline for wait_for_image. Generate can be momentarily disabled right after
    prompt/ref edits while the app re-validates — poll up to ~8s before failing.

    If `require_unlimited`, ABORT before clicking when the current config is not
    unlimited (fail-closed — never silently burn credits, e.g. Nano at 2K/4K)."""
    btn = page.locator(f'[data-cy="{CY_GENERATE}"]').first
    for _ in range(16):
        try:
            if btn.is_enabled():
                break
        except Exception:
            pass
        page.wait_for_timeout(500)
    else:
        raise RuntimeError("Generate button stayed disabled — a required input is "
                           "missing (empty prompt / no valid ref / broken chip).")
    if require_unlimited and not is_generate_unlimited(page):
        raise RuntimeError(
            "ABORT: current config is NOT unlimited (Generate shows a credit cost, "
            "not 'Unlimited generations'). This would burn credits — likely a "
            "resolution tier (2K/4K) that leaves the ∞ tier. Lower the resolution "
            "or set require_unlimited=false in the brief to allow it.")
    baseline = snapshot_cdn_images(page)
    btn.click(timeout=8000)
    print(f"[ok] Generate clicked; waiting for a new image (baseline max-id {baseline})…")
    return baseline


def wait_for_image(page: Page, baseline: int, timeout_s: int = 240) -> str | None:
    """Wait until a pikaso image with a creation-id LARGER than `baseline` appears
    (a new render), and return its EXACT url (verbatim — never transform it, the
    token has literal =/~ that URL-encoding breaks). We require the winning id to
    be stable across two polls so we catch the final, not a transient placeholder.

    A render can take ~1 min. Returns the url of the newest image with id>baseline."""
    deadline = time.time() + timeout_s
    last_id = None
    stable = 0
    while time.time() < deadline:
        imgs = [i for i in _pikaso_imgs(page) if i["id"] > baseline]
        if imgs:
            top = max(imgs, key=lambda i: i["id"])   # newest new image
            if top["id"] == last_id:
                stable += 1
            else:
                last_id, stable = top["id"], 0
            if stable >= 1:  # seen twice → settled
                page.wait_for_timeout(1200)
                # re-read the url for this id in case the token refreshed
                cur = [i for i in _pikaso_imgs(page) if i["id"] == top["id"]]
                return (cur[0] if cur else top)["url"]
        page.wait_for_timeout(2500)
    raise TimeoutError(f"No new image (id>{baseline}) within {timeout_s}s.")
