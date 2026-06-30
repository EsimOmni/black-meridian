# P07 — RivalDirector: utility AI

**Month:** 2 · **Brief:** §7.4 (Rival-Family AI)

## Why

The Corvine Assembly must feel like a thinking adversary, not a number that ticks up. Use **utility AI**
— NOT a machine-learning agent or expensive planner (brief §7.4 is explicit).

## Scope

`src/ai/rival_director.gd`, driven by `TimeService.rival_tick` (~10s). Each rival tick, for each rival
faction:

1. **Evaluate a limited action set** (brief §7.4): expand, probe, sabotage, recruit, bribe, retaliate,
   negotiate, frame, reduce_heat, defend, exploit_grievance.
2. **Score each action** from: faction objectives, available resources, known player weakness, emotional
   memory, current heat, expected retaliation, leader personality (FactionData aggression/caution/cunning),
   confidence in intelligence.
3. **Choose one high-value action with controlled noise** (don't always pick the argmax).
4. **Imperfect information**: rivals act on what they can plausibly know, not full GameState. Higher
   difficulty improves planning horizon / risk eval / indirect actions / coordination — NOT invisible
   income multipliers (fairness rule, brief §7.4).
5. **Rival memory** (`src/ai/rival_memory.gd`): records promises kept, humiliations, disproportionate
   retaliation, spared characters, accepted deals, repeatedly-contested territories. Memory alters future
   action scores + later dialogue.

## Verify

- Unit test: scoring is deterministic given fixed inputs; an aggressive leader skews toward
  sabotage/retaliate, a cunning one toward frame/bribe/negotiate; memory of a humiliation raises the
  score of retaliation next evaluation.
- Manual: over a Night Cycle the rival visibly probes/sabotages a contested venue and the player can
  see the consequence.
