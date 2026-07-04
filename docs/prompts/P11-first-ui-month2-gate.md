# P11 — First-pass UI theme + Month-2 cycle-integrity re-confirmation

**Month:** 2 (gate close) · **Brief:** §19 (first-pass UI is a Month-2 deliverable), §9.1 (noir palette), §9.3 (2D = UI layer)

## Why

Two jobs, kept separate:

1. **First-pass UI theme.** Brief §19 lists "first-pass UI" as a **Month-2** deliverable (NOT Month 5 —
   correct the stale `hud.gd:4` / `job_panel.gd:3` comments that say "Month 5"; final polish is P19).
   The UIs are pure greybox: only two scripts (`hud.gd`, `job_panel.gd`), each `CanvasLayer` →
   `PanelContainer` → `VBox` → `Label`/`Button`, every color/font inline. A shared theme lifts them all
   at once **without rewriting them**.
2. **Cycle-integrity re-confirmation.** The Month-2 feel gate already passed (short session, commit
   `f700fe6`: "fun, stress, very good") — but that was **before P09 phases + P10 betrayal**. Cem is not
   playing again. So the gate re-confirmation for the *full* cycle is **mechanical, not a play verdict**:
   Claude runs a full-Night-Cycle probe proving the chain money→heat→inspection→rival→job→phase→betrayal
   actually flows and feeds itself across one episode. Fable's job here is the theme; Claude produces the
   integrity proof and writes the note.

## Scope — a pure presentation layer, zero sim/save risk

### A. First-pass theme (the main build)

Create a single shared `Theme` resource (`.tres` under `assets/ui/` or `data/`) + a small palette module
(e.g. `src/core/palette.gd` or a `theme.gd` constants file) encoding the brief §9.1 palette **verbatim**:
*restrained charcoal, petrol blue, oxidized metal, sodium amber, selective faction color — explicitly
avoid generic purple cyberpunk.* No hex is given in the brief, so choose tasteful noir values matching
those names; back both the Theme and the remaining semantic `.modulate` colors (overflow-red,
telegraph-amber) from the palette module so nothing is a magic literal.

Apply via Godot 4.7 **theme inheritance**: set `theme` on the single root `PanelContainer` of each
CanvasLayer (`hud.gd:33`, `job_panel.gd:11`) — it propagates default `Label`/`Button`/`PanelContainer`/
`RichTextLabel` styling to every child with **no structural change**. Give panels a real `StyleBox`
(charcoal fill, subtle petrol/oxidized border), a consistent font + sizes (fold the 4 existing
`add_theme_font_size_override` calls into named theme sizes), and readable contrast at 1080p **and**
1440p. Keep the semantic inline colors (overflow, rival telegraph, betrayal tell, faction accent) as
intentional exceptions, but source them from the palette module.

The result: the same greybox panels, now coherent and on-brand noir — not final art, but no longer raw
default-gray boxes. The job_panel's deferred "job list/switcher" (`job_panel.gd:87`) stays deferred to
P19 — do NOT build it here (scope creep).

### B. Cycle-integrity note (Claude produces the proof; the slice records it)

`docs/prompts/notes/P11-month2-gate.md` records the re-confirmation: the full-cycle mechanical probe
result (systems interacting across one Night Cycle, not independent meters) + the standing `f700fe6`
feel verdict. This closes the Month-2 gate on mechanical integrity + the prior feel read.

## Deferred (do NOT build here)

- Full themed/final UI, portraits, operation cards as real art, evidence diagrams → **P19 / Month 5**.
- Job list/switcher UI (`job_panel.gd:87`), character/relationship *panel* as a new surface → P19.
- Any restructuring of the greybox panels (this is a theme, not a rebuild).
- All prior deferrals (P05b/P06b/P06c/P07b/P07c/P08b/P10b) stay deferred.

## Out of scope (hard)

- Do NOT rewrite `hud.gd`/`job_panel.gd` structure — theme + palette only, panels unchanged.
- Do NOT touch `src/` sim services, save, or determinism — a theme is presentation-only (§13.2:
  presentation reads, never owns; both UI scripts already honor this — keep it).
- Do NOT introduce new sim state or a new UI surface; theme the ones that exist.
- Do NOT enter real asset production — this is still 2D greybox-grade (brief §9.3), the gate GATES art.

## Verify (headless is truth)

- **No regression:** every existing test still green — theme touches no `src/` logic. Run the full
  suite (P04b/P05/P06/P07/P08/P09/P10 + economy/lifecycle) + boot smoke; all PASS, no new SCRIPT ERROR.
- **Boot clean with theme applied:** `--quit-after 120` shows no theme-load or missing-resource errors.
- **UI still reads live state:** launch (MCP or F5) and confirm the HUD/job panel render with the theme
  and still update (cash ticks, phase clock advances, overflow shows) — the read-only contract intact.
- **Claude's cycle-integrity probe** (separate, Claude-run): drive a full cycle and assert the chain
  fires — heat rises from overflow, inspection latches, rival telegraphs+lands on a weakened venue, a
  job generates from the sabotage, phases advance COUNCIL→…→RECKONING, and a betrayal can telegraph.
  Recorded in the note.

```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64_console.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --quit-after 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:|missing"   # empty = clean
# then the full unit suite as .tscn scenes (see any prior slice's Verify block)
```

## Done when

- A shared Theme + palette module lifts both greybox panels to coherent noir, no structural rewrite.
- Stale "Month 5" UI comments corrected to "first-pass Month 2 (P11) / final polish P19".
- Full test suite + boot green; UI still live and read-only; zero sim/save touch.
- The Month-2 gate note records PROCEED on cycle-integrity + the standing feel verdict. Commit to
  `master` (no PR).
