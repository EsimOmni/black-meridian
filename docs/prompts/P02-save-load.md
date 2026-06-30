# P02 — SaveService: save/load the full GameState

**Month:** 1 · **Brief:** §13.2 (SaveService), §18 (save/load survives all transitions)

## Scope

A `SaveService` (autoload, `src/save/save_service.gd`) that serializes and restores the **entire
authoritative GameState** — factions, districts, venues, characters, campaign clock — to a save file
under `user://saves/`. Presentation rebuilds itself from the restored state (it owns nothing).

1. `save_game(slot: String)` — write GameState to `user://saves/<slot>.bmsave` (JSON or Godot Resource).
2. `load_game(slot: String)` — clear GameState, rebuild it from file, emit `districts_changed` /
   `factions_changed` so the city + HUD repopulate.
3. A monotonic save **version** field; refuse to load mismatched versions cleanly (no crash).
4. Autosave hook at phase boundaries later — for now expose manual `F5`-style quick-save / quick-load
   bound to dev keys in bootstrap (e.g. F9 save, F10 load) — distinct from the play hotkeys.

## Determinism note

Because the sim is deterministic (brief §13.2), a load must reproduce identical subsequent ticks given
identical input. Don't store derived/cached values that the sim recomputes; store the source of truth.

## Verify

- Headless integration test under `tests/integration/`: build world → run N ticks → save → mutate →
  load → assert restored state equals the saved snapshot (cash, control states, heat, clock).
- Test passes headless (exit 0).
- Manual: in-editor, accrue some cash, F9 save, let it run / change, F10 load → state restored, HUD updates.
