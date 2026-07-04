---
name: claude-bridge
description: >
  Use when Cem wants to send a task/query to Claude Code for the black-meridian project — triggers on
  "var", "claude'a görev", "claude'a sor", "send to claude", "ask claude", "bir task var", or any intent
  to hand work to Claude. Lists the open Claude sessions for THIS repo, lets Cem pick which chat to
  address, then sends the message (auto-prefixed with "@gemini:") to that exact session via `claude -r`.
---

# claude-bridge — hand a task to Claude Code (black-meridian)

You (Gemini) are the operator. Claude Code is the architect running in one or more chat sessions for
the `d:\black-meridian` project. This skill lets Cem route a message to a **specific** Claude chat
without touching CLI mechanics — Cem just says "var" and picks a chat.

## When this triggers

Cem says something like "var", "claude'a görev / sor", "send to claude", "ask claude", "bir task var".
He will NOT type `@gemini` or session IDs — you add those.

## Steps

### 1. List the open Claude sessions for this repo

Session logs live at:

```
C:\Users\User\.claude\projects\d--black-meridian\<session-id>.jsonl
```

The **filename (without `.jsonl`) is the session ID.** For each file, read the first user message
(intent) and the last message (where it left off), and note the **last-modified time**. Sort by
last-modified **descending** — the top row is the most recently active chat.

PowerShell to gather them (adapt as needed):

```powershell
$dir = "C:\Users\User\.claude\projects\d--black-meridian"
Get-ChildItem "$dir\*.jsonl" | Sort-Object LastWriteTime -Descending | ForEach-Object {
  $id = $_.BaseName
  $first = (Get-Content $_.FullName -TotalCount 1)
  $last  = (Get-Content $_.FullName -Tail 1)
  [PSCustomObject]@{ Id = $id; Updated = $_.LastWriteTime; First = $first; Last = $last }
}
```

Present a numbered table to Cem: **#, short ID (first 8 chars), last-updated, one-line summary of
first & last message.** Mark the top (most recent) row as `← most recent`. Do NOT assume which chat
Cem wants — he chooses.

### 2. Cem picks a chat

He replies with a number (or the short ID). Resolve it to the full session ID.

### 3. Ask what to send — two modes

- **Shortcut (default):** if Cem didn't give a message, or says "sıradaki / next task", send the
  default query: `@gemini: bir sonraki taskım ne?`
- **Free text:** if Cem gave a message, use it verbatim. Always **prefix with `@gemini: `** if it's
  not already there — this tells Claude the query comes from you (the Gemini operator).

### 4. Send to that exact session

```powershell
claude -r <full-session-id> "@gemini: <message>"
```

- Use `-r <id>` (resume specific session), NOT `-c` — `-c` grabs "the last session" and drifts if
  another Claude window was touched. `-r` hits the chat Cem picked, guaranteed.
- `claude -p`/`-r` does not need stdin closed; it waits ~3s then proceeds (harmless warning).
- Print Claude's stdout back to Cem — that's the task/answer.

### 5. The shared queue (context)

Claude coordinates tasks through `docs/tasks/gemini/QUEUE.md` (read `docs/tasks/gemini/README.md` once
for the full protocol). When you ask "bir sonraki taskım ne?", Claude reads that queue and points you
at the active brief in `inbox/`. You execute it and file a report in `done/`. This skill only handles
the **routing** (which chat, prefixed message); the queue handles the **work**.

## Rules

- Never invent a session ID — always list from disk first and let Cem pick.
- Always `@gemini:`-prefix the outgoing message.
- Never kill a running `claude` process mid-flight; let it finish and read its stdout.
- If only one session exists, still show it and confirm before sending.
