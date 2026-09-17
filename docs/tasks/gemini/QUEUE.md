# Gemini Task Queue — Black Meridian

Single source of truth for the Claude ↔ Gemini delegation loop. Both agents read/write this file.
Claude writes the briefs; Gemini executes them and files reports. This table is the "what's next / what's done" at a glance.

**Status legend:** `QUEUED` (brief ready, not started) · `IN_PROGRESS` (Gemini working) · `DONE` (report filed) · `BLOCKED` (needs Cem/Claude) · `CANCELLED`

**Coordinator session (Gemini: address THIS one):** `f151bdaf-a028-4e19-8f5c-71d5302df88e`
→ Gemini uses `claude -r f151bdaf-a028-4e19-8f5c-71d5302df88e "@gemini: ..."` so the query always
lands in the chat that owns this queue — not "the last session" (`-c`), which drifts if another
Claude window is used. If this ID goes stale, Cem/Claude updates it here.

> ## ENGINE REBOOT — this queue's repo is now an ARCHIVE (2026-09-18)
>
> The game moved to **Unreal Engine 5.8.2**; active development is **`D:\black-meridian-ue`**
> (`EsimOmni/black-meridian-ue`). This Godot repo is the **behavioral oracle**, kept runnable and
> never rewritten. Read the banner at the top of `GEMINI.md` and then `docs/NOW.md` before acting on
> anything here.
>
> **No Godot feature briefs will be issued.** Work that still belongs in this repo is limited to
> golden-vector extraction (running the oracle) and the Gate B cinematic comparison. New briefs
> target the Unreal repo.
>
> WARNING — **the coordinator session ID below is stale** (it predates the reboot). Do not address it.
> Ask Cem for the current session, or have Claude update this line, before using the `@gemini:` bridge.


**Active pointer:** **TASK-001** — bridge smoke test.

| ID | Title | Status | Brief | Report | Owner |
|----|-------|--------|-------|--------|-------|
| TASK-001 | bridge smoke test (repo-independent) | DONE | `inbox/TASK-001.md` | `done/TASK-001-report.md` | Gemini |

---

## Loop mechanics (short)

1. **Claude** writes `inbox/TASK-00X.md` (brief) and adds a row here as `QUEUED`, sets the Active pointer.
2. **Cem** in Gemini: `claude -c "@gemini: taskım ne?"` → Claude points at the current `QUEUED` brief and reads it out.
3. **Gemini** does the work, flips the row to `IN_PROGRESS`, then on finish writes `done/TASK-00X-report.md` and flips the row to `DONE`.
4. **Cem**: `claude -c "@gemini: TASK-00X bitti, sıradaki?"` → Claude reads the report, verifies, then queues the next brief.

See `README.md` in this folder for the full protocol + report schema.
