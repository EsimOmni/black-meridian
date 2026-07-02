# FABLE.md — Running BLACK MERIDIAN with Claude Fable 5

This project is built with **Claude Fable 5** as the primary model. This file is the Fable-specific
operating layer; `CLAUDE.md` remains the repo doctrine (what the game is, architecture, IP rules, gates).
Read both. `AGENTS.md` / `CODEX.md` still apply to Codex / other agents.

Source: Anthropic's "Prompting Claude Fable 5" guide. This file adapts it to THIS repo.

## Why Fable 5 fits this project

Black Meridian is a long-horizon, well-specified, multi-system build — exactly Fable 5's strong zone:

- **Long-horizon autonomy** → the 24-slice, 6-month roadmap (`docs/prompts/`) is one sustained goal.
- **First-shot correctness on well-specified problems** → the brief + prompt series are heavily specified;
  that's the input Fable rewards. Point it at a whole slice, not a keystroke.
- **Parallel subagents** → economy / rival AI / jobs / narrative are independent workstreams; delegate.
- **Vision** → Godot editor screenshots, splat QA, art review, dense technical images.
- **Code review & debugging with repo-history search** → deterministic GDScript sim bug-hunting.
- **Navigating ambiguity** → "start P05" and let it scope + execute.

## THE HARD RULE — never echo reasoning into responses

Do NOT instruct the model (in skills, prompts, or system text) to "show your thinking", "explain your
reasoning", "think out loud in the response", or transcribe its internal reasoning as output. On Fable 5
this triggers the **`reasoning_extraction` refusal** → elevated fallbacks to Opus 4.8 → you lose Fable's
edge. If you need reasoning visibility, read the structured `thinking` blocks (adaptive thinking), not
response text. (Audited 2026-07-01: the repo docs are clean of this; keep them clean.)

## Fallback to Opus 4.8

Fable 5 runs safety classifiers for offensive cybersecurity + biology/life-sciences + reasoning-extraction.
**None of these apply to building a management game** — but if a request ever returns
`stop_reason: "refusal"`, route it to **Claude Opus 4.8** (client-side or server-side fallback). Don't
fight a refusal; switch models for that call. (Opus 4.8 built the Month-1 skeleton; it's a fine fallback.)

## Effort

`high` is the default for slice work. Use `xhigh` for the capability-sensitive slices — the rival utility
AI (P07), the loyalty/betrayal system (P10), the cinematic persistence gate (P18). Use `medium`/`low` for
routine mechanical work (data seeding, asset naming, doc edits). Lower Fable effort still beats prior
models. Drop effort if a task completes but takes longer than needed.

## Prompting patterns for this repo

**Act when you can act.** Fable can overplan on ambiguous tasks. When a slice is specified (and ours are),
act — don't re-survey options or re-litigate decided things in user-facing messages.

**Don't over-tidy at high effort.** The repo already forbids scope creep (CLAUDE.md minimal-footprint). At
`xhigh` Fable especially wants to refactor/abstract; hold it to the slice. A bug fix needs no surrounding
cleanup; a one-shot needs no helper.

**Give the reason, not just the request.** Fable connects better with intent. Frame slices as: "We're
building [system] so the player can [do X]; the Month-N gate needs [Y]. With that: implement P0N."

**Ground progress claims.** On long runs, audit each status claim against a real tool result this session.
Say what's verified vs not. This repo's "Verify before done" (headless import + unit test + boot smoke) is
the evidence — cite it, don't assert green without it.

**Stop only where it matters.** Pause for the user on: a destructive/irreversible action, a real scope
change, a gate decision (esp. the P01 splat kill-criterion, the P11 "fun with cubes" gate, the P18
persistence gate), or input only the user can give (canonical character names/art masters — brief §20).
Otherwise proceed to the end of the slice.

**Delegate.** For a slice touching multiple systems, dispatch subagents per system and keep working; a
fresh-context verifier subagent beats self-critique for checking a finished system against its prompt spec.

## Self-verification on long runs

For a multi-day slice, establish a checking method up front and run it at intervals: verify against the
slice's "Verify" section with a subagent. For deterministic systems (economy, rival scoring, betrayal),
that means the headless unit tests must stay green — a verifier subagent runs them and reports evidence.

## Memory

Record lessons in **`tasks/lessons.md`** — one lesson per entry, one-line summary first, then why it
mattered. Record both corrections and confirmed approaches. Don't duplicate what git history or the brief
already says; update an existing note instead of adding a duplicate; delete notes that turn out wrong.
Reference it at the start of each slice. (This is the Fable memory-system pattern; it compounds across the
6-month build.)

## Skills note

Skills written for prior (Opus-era) models are often too prescriptive for Fable and can degrade output.
`CLAUDE.md` here is intentionally kept — its constraints are the user's deliberate working style and the
brief's non-negotiables (IP boundary, scope gates), not stylistic over-specification. If a specific
instruction ever visibly degrades Fable output, flag it and propose relaxing it; don't silently strip the
brief's guardrails.

## Autonomous-run reminder (for headless / scheduled slice runs)

When running a slice autonomously (user not watching): proceed on reversible actions that follow from the
slice; don't ask "shall I…?" mid-task. Before ending a turn, if the last paragraph is a plan / question /
promise ("I'll…", "next I'll…"), do that work now with tool calls. End only when the slice is complete or
you're blocked on a genuine gate decision. Have ample context — don't stop or suggest a new session over
context limits.
