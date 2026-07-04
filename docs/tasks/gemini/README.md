# Claude ↔ Gemini delegation loop — protocol

This folder is the **shared task queue** between Claude Code (the architect) and Gemini
(the operator, running inside Antigravity). It is asynchronous and file-based: no live chat
channel is needed, and every hand-off leaves a durable trace.

## Why file-based (the hard constraint)

Gemini spawns `claude` as a **child process** — it sends a prompt, Claude writes to stdout, the
process exits, Gemini reads the output. Claude **cannot** push an unsolicited message to Gemini
"from zero." So the queue lives on disk; Claude answers *when Gemini asks*, and both sides read the
same files. `claude -c` (continue) means Gemini's query lands in Claude's **current live session**,
with full context — not a fresh empty chat.

## Folder layout

```
docs/tasks/gemini/
  QUEUE.md                  ← the ledger: one row per task, status, links, active pointer
  README.md                 ← this file (the protocol)
  inbox/TASK-00X.md         ← Claude writes the brief here (the task spec Gemini executes)
  done/TASK-00X-report.md   ← Gemini writes the outcome summary here when finished
```

## The loop (canonical)

1. **Claude** creates `inbox/TASK-00X.md`, adds a `QUEUED` row to `QUEUE.md`, sets the **Active pointer**.
2. **Cem** (in Gemini): `claude -c "@gemini: taskım ne?"` → Claude reads the active brief aloud.
3. **Gemini** flips the row to `IN_PROGRESS`, does the work per the brief's verify steps.
4. **Gemini** writes `done/TASK-00X-report.md` (schema below), flips the row to `DONE`.
5. **Cem**: `claude -c "@gemini: TASK-00X bitti, sıradaki?"` → Claude reads the report, **verifies it
   independently** (headless run / diff), then queues the next brief. If the report doesn't hold up,
   Claude re-opens the task (`IN_PROGRESS`) with a correction note instead of advancing.

## Brief schema (`inbox/TASK-00X.md`) — Claude writes

- **Goal** — one sentence, what "done" means.
- **Context** — the minimum Gemini needs; link files, don't paste walls.
- **Scope guardrails** — what NOT to touch (respect CLAUDE.md minimal-footprint + brief §12 gates).
- **Steps** — ordered, concrete. Name exact files/paths.
- **Verify** — the exact headless command(s) whose exit-0 / empty-grep proves it works.
- **Deliverable** — files changed + the report path to write.
- **Delegation hint** — may Gemini sub-delegate to Codex (mechanical/vision) per GEMINI.md? yes/no.

## Report schema (`done/TASK-00X-report.md`) — Gemini writes

- **Task** — ID + title.
- **Outcome** — DONE / PARTIAL / BLOCKED, one line.
- **What changed** — bullet list of files + what/why.
- **Verify result** — the command run + its actual output (exit code, grep result). Evidence, not claims.
- **Deviations** — anything done differently from the brief, and why.
- **Follow-ups** — anything left for Claude/Cem.

## Rules

- **Claude verifies before advancing.** A `DONE` report is a claim; headless is the truth (CLAUDE.md).
- **Gemini stays in scope.** No refactors/features beyond the brief. Brief §12 gates still govern.
- **IP-boundary / splat-kill / architectural calls are NOT delegated** — those stay with Claude/Cem.
- **One active task at a time** unless a brief explicitly parallelizes.
