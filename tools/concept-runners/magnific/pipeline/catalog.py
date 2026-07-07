"""By-Magnific reference catalog — recon 2026-07-01. Two addressing mechanisms:

  1. MENTION-ADDRESSABLE (@name → prompt chip via autocomplete):
     Locations + Character + Element (By-Magnific + your own library assets).
     Add these by putting @name in the prompt; the popup makes a positional chip.

  2. MODAL-SELECT (NO @mention — you MUST open the ref modal + click):
     * Effects / Camera → a fixed-name button `<name>-item` (id-free, name is stable)
     * Style / Color    → a library thumbnail addressed by numeric id
                          (`library-style-thumbnail-<id>` / color-palette-thumbnail-<id>)

  Effects/Camera are PRESETS (lighting/mood/lens), not references — they do not
  consume a ref slot; they tag the generation. Style/Color are library assets.
"""

# =============================================================================
# YOUR OWN LIBRARY (source: mine). Runner resolves an @name in a brief to its
# numeric library id from these maps, so briefs can say
# {"type":"element","ref":"@some-saved-asset"} instead of a raw id.
#
# Black Meridian has no saved Magnific library assets yet — populate these as
# district/character library models are created (see
# pipeline.image_browser.create_library_model / create_element / create_character).
# =============================================================================

# Your Elements (props/vehicles/set-pieces). name(lower) -> {id, kind}.
MY_ELEMENTS: dict = {}

# Your Characters. name(lower) -> {id, ip} where ip=True means clean Black
# Meridian IP (Aiko Velora + other original cast only — see CLAUDE.md IP §2).
MY_CHARACTERS: dict = {}

# You have NO saved Styles / Locations / Color in your library yet —
# those come only from the By-Magnific built-in catalog below.


def resolve_library(kind: str, name: str) -> str | None:
    """Resolve an @name to its numeric library id from YOUR library, or None.
    Enforces the IP rule on characters (returns None for a disputed name)."""
    n = name.lstrip("@").lower()
    if kind in ("element", "product"):
        e = MY_ELEMENTS.get(n)
        return e["id"] if e else None
    if kind == "character":
        c = MY_CHARACTERS.get(n)
        return c["id"] if (c and c["ip"]) else None
    return None


# --- LOCATIONS: By-Magnific, mention-addressable via @name -------------------
LOCATIONS = [
    "beach", "bridge", "cafe", "castle", "countryside", "desert", "forest",
    "garden", "interior", "jungle", "laboratory", "library", "mars", "mountain",
    "rooftop", "ruins", "snow-field", "stadium", "temple", "underwater",
]

# --- ELEMENTS: By-Magnific stock props, mention-addressable via @name ---------
# (your OWN elements are library ids, resolved via MY_ELEMENTS above)
ELEMENTS_BY_MAGNIFIC = [
    "bluetoaster", "bottle", "ecclipsecoffeetable", "glassbottle", "lamp",
    "leatherjacket", "metalmug", "nebulahandbag", "notebook", "orangemoka",
    "perfum", "redheels", "redlipstick", "serum", "silvercream", "smartwatch",
    "teddybag", "totebag",
]

# --- CAMERA presets: modal-select, tab 'camera', button '<name>-item' ---------
CAMERA_PRESETS = [
    "360", "aerial", "cinematic", "close-up", "drone", "first-person",
    "fish-eye", "full-body", "high-angle", "layered", "low-angle", "mid-shot",
    "panoramic", "portrait", "symmetry", "tilt-shift", "tilt-shot", "wide-shot",
]

# --- EFFECTS presets: modal-select, tab 'effects', button '<name>-item' -------
# grouped by the in-UI filter (advanced-effects-tab-{color,lighting,mood,action})
EFFECTS_PRESETS = [
    "Icy-blue", "b&w", "back-light", "blurring", "burgundy-&-blue", "chaotic",
    "chiaroscuro", "cold", "deep-teal", "dramatic", "duotone", "earthy",
    "ethereal", "fading", "falling", "flash", "flying", "glitching", "gold-glow",
    "golden-hour", "hardlight", "high-flash", "indoor-light", "iridescent", "joy",
    "jumping", "long-exposure", "melting", "morphing", "muted-green", "nostalgic",
    "playful", "redscale", "romantic", "sepia", "softhue", "spinning", "studio",
    "tension", "terracote-&-teal", "vibrant", "volumetric", "walking", "zen",
]

# Sidebar tab cy per ref type (UI label -> real data-cy). 'Element' UI == cy 'product'.
SIDEBAR_TAB_CY = {
    "location": "reference-sidebar-locations",
    "element": "reference-sidebar-product",
    "product": "reference-sidebar-product",
    "character": "reference-sidebar-character",
    "style": "reference-sidebar-style",
    "effects": "reference-sidebar-effects",
    "camera": "reference-sidebar-camera",
    "color": "reference-sidebar-colorPalette",
}

# Which types are addressable purely by an @name mention in the prompt.
MENTION_TYPES = {"location", "element", "product", "character"}


def is_builtin_location(name: str) -> bool:
    return name.lstrip("@").lower() in {n.lower() for n in LOCATIONS}


def is_builtin_element(name: str) -> bool:
    return name.lstrip("@").lower() in {n.lower() for n in ELEMENTS_BY_MAGNIFIC}


def normalize_preset(kind: str, name: str) -> str | None:
    """Return the exact `<name>-item` cy target for a camera/effects preset, or
    None if the name isn't in the catalog (so the runner can warn)."""
    n = name.lstrip("#@").strip()
    pool = CAMERA_PRESETS if kind == "camera" else EFFECTS_PRESETS
    for p in pool:
        if p.lower() == n.lower():
            return p
    return None
