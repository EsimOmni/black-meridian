# TASK-001 — bridge smoke test (repo-independent)

**Status:** QUEUED
**Created:** 2026-07-04 by Claude
**Delegation hint:** no (do it yourself, no Codex needed)

## Goal
Prove the Claude ↔ Gemini file-queue loop works end-to-end. Trivial, touches nothing in the game.

## Context
- This is the first task through the new queue at `docs/tasks/gemini/`.
- Pure plumbing check — no game code, no headless run.

## Scope guardrails
- Do NOT touch anything under `src/`, `scenes/`, `data/`, or `tests/`.
- Only write the one report file named below.

## Steps
1. Read this brief (you're doing it).
2. Confirm you can write to `docs/tasks/gemini/done/`.
3. In your report, include the current UTC-ish timestamp (your best guess is fine) and one line
   confirming which shell you're running in (PowerShell 5.1) and that both `codex` and `claude` are on PATH.

## Verify
No headless run. Success = the report file exists and reads cleanly.

## Deliverable
- Files changed: `docs/tasks/gemini/done/TASK-001-report.md` (create it)
- Then flip the `QUEUE.md` row for TASK-001 to `DONE`.
