# TASK-00X — <short title>

**Status:** QUEUED
**Created:** <date> by Claude
**Delegation hint:** Gemini may sub-delegate mechanical/vision parts to Codex? <yes/no>

## Goal
<one sentence — what "done" means>

## Context
- <link file:line, not walls of text>
- <relevant prior slice / decision>

## Scope guardrails
- Do NOT touch: <list>
- Respect: CLAUDE.md minimal-footprint, brief §12 gates, IP §2.

## Steps
1. <concrete, names exact paths>
2. ...

## Verify
```sh
GODOT="D:/Godot/Godot_v4.7-stable_win64.exe"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s tests/unit/<test>.gd   # exit 0 = pass
```
<state the expected passing signal>

## Deliverable
- Files changed: <list>
- Write report to: `docs/tasks/gemini/done/TASK-00X-report.md`
