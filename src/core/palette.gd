class_name Palette
extends RefCounted
## The brief §9.1 noir palette: restrained charcoal, petrol blue, oxidized metal,
## sodium amber, selective faction color — explicitly no generic purple cyberpunk.
## Single source of truth for every UI color: the shared theme (assets/ui/theme.tres)
## is GENERATED from these values by tools/build_theme.gd — edit here, re-run the tool,
## never hand-edit the .tres. The semantic block is the set of intentional inline
## exceptions the greybox panels read directly (overflow, telegraphs, tells).

# --- Base surfaces / structure ---
const CHARCOAL := Color("14161a")          # panel ground
const CHARCOAL_RAISED := Color("1f232b")   # raised interactive surfaces (buttons)
const PETROL := Color("2e4b58")            # petrol blue — borders, hover accent
const OXIDIZED := Color("6f695a")          # oxidized metal — separators, muted edges
const SODIUM_AMBER := Color("e5a54e")      # sodium amber — pressed/attention accent

# --- Text ---
const TEXT := Color("d6dae0")
const TEXT_BRIGHT := Color("edf0f4")
const TEXT_MUTED := Color("8d949e")

# --- Semantic exceptions (intentional inline colors on the panels) ---
const DANGER := Color("f27359")            # unlaundered overflow, inspection
const RIVAL_ACCENT := Color("7fa8bd")      # rival telegraph — petrol family, not lavender
const LEDGER_AMBER := Color("d9c78c")      # the Reckoning tally
const BETRAYAL_CRIMSON := Color("e07a94")  # bruised crimson — the betrayal tells
