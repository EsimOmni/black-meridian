# P10 — RelationshipService: motive network + telegraphed betrayal

**Month:** 2 · **Brief:** §6 pillar 3, §7.6 (Loyalty and Betrayal)

## Why

Loyalty is a **network of motives**, not one number (brief pillar 3). Betrayal must be deterministic and
**telegraphed** — never an untelegraphed random roll (brief §7.6). This is a signature system.

## Scope

`src/simulation/relationship_service.gd` operating over `CharacterData` (which already carries the motive
fields + `betrayal_pressure()`):

1. **Public info** the player sees: current trust, recent grievances, known relationships, stated
   ambition, current responsibilities.
2. **Hidden info** the player must infer: concealed secret, true ideological loyalty, willingness to kill
   another character, external leverage, private succession plan.
3. **BetrayalPressure** (brief §7.6 formula, already in CharacterData): Ambition + AccumulatedGrievance +
   RivalLeverage + SurvivalPressure + Opportunity − Trust − SharedSuccess − FearOfConsequences.
4. **Betrayal requires BOTH**: pressure above the character's threshold **AND** a viable opportunity.
   This makes it *preventable*.
5. **Telegraphing**: as pressure nears the threshold, surface tells — delayed responses, unexplained
   absence, operational mistakes, private meetings, unusual requests, conflict between two lieutenants.
6. Cross-loyalty: a lieutenant can stay loyal to Aiko while betraying the Regent (brief §7.6).

## Verify

- Unit test: betrayal fires only when pressure > threshold AND opportunity present; raising trust or
  shared-success below threshold prevents it; tells appear before the threshold is crossed.
- Manual: the slice's loyalty crisis (Bengal lieutenant) is causally understandable and preventable.
