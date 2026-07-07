# Glass Wharf — Sketchfab + Poly Haven Asset Research

Research pass for the **Glass Wharf** noir waterfront district (former freight depots
converted into neon nightlife — wet wood/metal facades, warm neon shopfronts, low/tilted
warehouse silhouettes, dock/pier structures, teal-petrol + amber palette; Blade-Runner-noir,
not clean sci-fi). Reference: approved master keyframe
(`assets/concept/glass_wharf/glasswharf_master.png`).

**Scope of this pass: research + list only. Nothing downloaded yet.** UIDs/IDs below are for
the later Blender MCP download step (`download_sketchfab_model`, `download_polyhaven_asset`).

## Elimination rules applied

- License: **CC0 or CC-BY (Attribution) only**. CC-BY-NC (non-commercial) and CC-BY-SA
  (ShareAlike) rejected outright — Black Meridian ships commercially on Steam.
- **IP-clean only**: any real brand/logo, readable real-world trademarked text, or third-party
  franchise reference (e.g. "Flynn's Arcade" = *Tron*) is disqualifying. Generic/abstract/fictional
  signage is fine.
- Downloadable flag must be set on Sketchfab.
- Reasonable face count for real-time use (roughly 500–150k; a few useful outliers noted).
- Every Sketchfab candidate below was visually verified via thumbnail preview (not just the
  search-result license field) before inclusion — WebFetch cannot render Sketchfab's JS pages,
  so verification was done through the Blender-Sketchfab MCP bridge's real API + rendered
  thumbnails.
- Per project CLAUDE.md: Sketchfab/Poly Haven assets here are for **proxy/greybox enrichment
  only**, not hero assets, and don't bypass the Month-2+ production gates. Raw geometry is
  provisional pending Blender cleanup + Godot validation. Log actually-used assets in
  `assets/ATTRIBUTIONS.md` (create on first real download) with URL + license + required
  attribution.

---

## Part 1 — Sketchfab (geometry): 20 candidates

Search method: `search_sketchfab_models` (Blender MCP → real Sketchfab API, not scraped HTML),
narrow multi-word queries returned near-zero hits so queries were kept short/broad; each
candidate confirmed via `get_sketchfab_model_preview` thumbnail render.

| # | Model adı | UID | Yazar | Lisans | Face | Neden uyuyor (1 satır) | IP-temiz mi (marka/yazı var mı?) |
|---|---|---|---|---|---|---|---|
| 1 | Old Warehouse | `17f9bd6278014857947798ea47db40e3` | AlanTinka | CC Attribution | 95,353 | Weathered brick + corrugated roof freight warehouse — hero silhouette match | Evet — sadece aşınmış doku, yazı yok |
| 2 | Old Industrial Building | `0dafa7aaadfd4666bb4a32776c84b14e` | gazdahrco | CC Attribution | 67,127 | Multi-story red-brick industrial block, broken windows — mid-ground filler | Evet — marka/yazı görünmüyor |
| 3 | Warehouse Building (compact) | `0c37b0f92cb54e07a1e1c6c3df9f8439` | OmegaRedZA | CC Attribution | 946 | Ultra-lightweight warehouse box — grid-tile kitbash background fill | Evet — düz doku |
| 4 | Dock Pier | `9528bbe1ecb04ea8bae283c773e1fcb5` | pixol3d | CC Attribution | 123,942 | Dedicated dock/pier structure — direct hit on pier priority | Evet |
| 5 | Trihuslab Pier | `9dc3ddd22e2d4b729ec4b1abac9fa649` | trihuslab | CC Attribution | 8,504 | Lightweight wooden pier — foreground detail near water | Evet (ambiguous "Troll Island" arch sign flagged in an earlier preview batch — re-verify solo before use) |
| 6 | Dock House – Stylized Wooden Pier | `4f0df975625a432c91f2685963d12500` | voyoo | Free Standard | 15,576 | Stilt-style dock house on pier — matches waterfront pier/stilt-house ask | Evet |
| 7 | Gotham Underworld Slum / Low-Poly Tenement House | `0c63358da0594960afc797e3cc5dc95b` | INGSOC1984 | CC Attribution | 69,854 | Grimy multi-unit tenement silhouette — nightlife-strip backdrop density | Evet — "Gotham" is just the listing title, no in-model graffiti/logo confirmed in thumbnail |
| 8 | Dirty Plaster Wall with Rusty Door | `06b7fb820376456699ee6224b80a6f0c` | orphanrtg | CC Attribution | 24,984 | Weathered warehouse entry façade, wet-plaster look | Evet — sadece kir/pas dokusu |
| 9 | Dock Crane | `5b620e1a1c8b47d6aee6a989dd72365c` | PolyGodPRO | CC Attribution | 10,728 | Waterfront harbor crane | Evet (name/thumbnail mismatch flagged earlier — re-verify solo before download) |
| 10 | Industrial Crane (compact) | `647872b89d084f7cb50329a6f7e35721` | chris.berghs | CC Attribution | 4,772 | Clean tower-style crane, low face count, easy to scatter | Evet |
| 11 | Rusty Industrial Crane Beam & Pulley System | `222560774f6f4ab9b0d5cbbe87c84e10` | murattd3v | CC Attribution | 2,326 | Small rusted beam+pulley detail — foreground grime accent | Evet |
| 12 | Classic Shipping Container (Free/Gameready) | `772f4be391a245f699c54e6cf157c58d` | Sebastian.Hamish.Webster | CC Attribution | 17,110 | Clean gameready container, no visible markings — generic crate stacking | Evet |
| 13 | Freight Shipping Container – Rusted | `2b787d1a02174d0bbca9eac34eb3a486` | sousinho | CC Attribution | 11,098 | Rust-weathered container matching wet/decayed waterfront palette | Evet |
| 14 | Dumpster | `23f0a1c5875b435fa2933e7ea8157fdf` | ob1style | CC Attribution | 1,126 | Lightweight street-level clutter prop | Evet |
| 15 | Astro Gents Neon Light (abstract star squiggle) | `810cf16f1dd04fe88b936a493d744880` | dayruke | CC Attribution | 6,168 | Pure abstract glowing shape — generic nightlife neon accent, zero text | Evet — tamamen soyut şekil, yazı yok |
| 16 | Street Lamp (low poly) | `152055979ddd48669529f5d4f5f3543c` | yni-viar | CC Attribution | 800 | Minimalist bent street lamp — cheap background scatter prop | Evet |
| 17 | Vintage Lamp Post | `56f6dcb3865144cd84e049ca6a736fae` | dasmodal | CC Attribution | 8,170 | Double-globe ornate lamp post — period noir street lighting | Evet |
| 18 | FishingBoat | `cc4200e4018843f28ddca72adc61e887` | Godot2000 | CC Attribution | 10,518 | Weathered wooden rowboat w/ lifebuoy — waterfront set dressing | Evet |
| 19 | Row Boat with Lantern and Paddles | `8c20b2b69ee64d59abadfed49d721873` | ShadyTex4u | CC Attribution | 203,966 | Atmospheric lantern-lit rowboat — strong noir mood prop (face count high, use as hero-only) | Evet |
| 20 | Steel Stair (fire-escape style) | `3a664dcd8baa499d8b4bbad8fbba3b33` | bighlerm8888 | CC Attribution | 16,866 | Multi-landing exterior steel stair — classic noir-alley silhouette element | Evet |

**Not listed (checked and rejected):**
- Cyberpunk Shopfront #PBR# (`f51dddbfb45d4553829ec3e4e5c7f000`) — readable Korean/CJK shop
  signage text.
- Warehouse with "WOOD BROS LIMITED" painted roof text — real-looking painted brand name.
- hqassests "Cyberpunk Building" (`0b12a1eb1fc143ce875bfae633b9c4cc`) — dense readable
  multi-language signage.
- Several Thailand/Vietnam heritage stilt-houses — CC-BY-NC-NoDerivs, commercial use forbidden.
- "Apartment Houses" pack by MRowa — CC-BY-SA (ShareAlike risk).
- "Flynn's Arcade Neon Sign" (`c670472f09a6424c9c27909c73aba2c0`) — direct *Tron* movie
  reference, third-party IP echo.
- Chinese "游戏厅" (game arcade) neon sign (`9d16af5964d241b089a3790fb890f7d7`) — readable
  real-world language text.
- "Astro Gents" arcade cabinet (`df33ff6aa315456f83b3f0fa12a3591c`) — fabricated but fully
  designed brand/logo/tagline, too product-specific.
- Dumpster with "CAUTION DO NOT PLAY..." sticker (`da3f439610fc4a2083fa4db92188e8f0`) —
  readable English safety text, excluded to stay conservative even though generic/non-branded.
- Coiled Rope options (`e6fe8fedd3d04b1dac3e32e0dd515cbb`, `f771d9bbc8384f44aeb63f100b3a16a4`) —
  clean and usable but redundant with higher-priority picks above; drop if the list needs to
  stay tight, promote back in if more dock-detail props are needed.
- Alien creature busts (various) — off-scope for buildings/props, and most had wrong license or
  absurd 500k–2M face counts.

**Open verification items before actual download:**
- Trihuslab Pier (`9dc3ddd22e2d4b729ec4b1abac9fa649`) — re-check solo for a possible "Troll
  Island" branded arch sign spotted in an earlier batched preview (batch order may have been
  mismatched).
- Dock Crane (`5b620e1a1c8b47d6aee6a989dd72365c`) — thumbnail once looked like a small wooden
  dock/barrel scene rather than a crane; re-check solo to confirm actual model content matches
  the listing name.

---

## Part 2 — Poly Haven (materials, HDRIs, generic props): 20 assets

Poly Haven has **no architecture/building models** — its catalog is HDRIs, PBR materials, and a
small generic-prop set. Everything is **CC0 (public domain)** — no license screening or
attribution needed. This list re-skins/lights the Sketchfab geometry above rather than adding
new structures.

| # | Asset adı | Poly Haven ID | Tip | Neden uyuyor |
|---|---|---|---|---|
| 1 | Rusty Metal 02 | `rusty_metal_02` | PBR Texture | Wet-rust hero material for warehouse facades/containers |
| 2 | Rusty Corrugated Iron | `rusty_corrugated_iron` | PBR Texture | Corrugated warehouse roof — direct visual match to keyframe |
| 3 | Corrugated Iron | `corrugated_iron` | PBR Texture | Clean variant for less-decayed roofing/wall sections |
| 4 | Container Side | `container_side` | PBR Texture | Re-skin shipping containers for palette consistency across all Sketchfab crates |
| 5 | Metal Grate Rusty | `metal_grate_rusty` | PBR Texture | Dock grating / walkway surfaces |
| 6 | Painted Metal Shutter | `painted_metal_shutter` | PBR Texture | Roll-down shopfront shutters for neon storefronts |
| 7 | Concrete Floor Worn 001 | `concrete_floor_worn_001` | PBR Texture | Wet-look worn concrete for streets/dock floor |
| 8 | Asphalt Floor | `asphalt_floor` | PBR Texture | Rain-slick street base, reflects neon well |
| 9 | Concrete Debris | `concrete_debris` | PBR Texture | Crumbling pavement/foundation detail |
| 10 | Concrete Moss | `concrete_moss` | PBR Texture | Damp waterfront concrete with growth — pier/seawall base |
| 11 | Dark Wooden Planks | `dark_wooden_planks` | PBR Texture | Wet dock/pier decking |
| 12 | Green Rough Planks | `green_rough_planks` | PBR Texture | Weathered stilt-house wall siding |
| 13 | Blue Painted Planks | `blue_painted_planks` | PBR Texture | Peeling-paint dockside shack accent walls |
| 14 | Coral Fort Wall 01 | `coral_fort_wall_01` | PBR Texture | Aged plaster/rock seawall texture |
| 15 | Cobblestone Street Night | `cobblestone_street_night` | HDRI | Ready-made rainy-feel night street lighting rig |
| 16 | Hansaplatz | `hansaplatz` | HDRI | Urban night HDRI, high-contrast artificial light — neon/noir mood match |
| 17 | Blaubeuren Church Square | `blaubeuren_church_square` | HDRI | Overcast urban night — "post-rain" ambient lighting variant |
| 18 | Barrel_01 | `Barrel_01` | Model (props) | Generic industrial barrel — dock/warehouse clutter |
| 19 | Metal Trash Can | `metal_trash_can` | Model ("Hidden Alley" collection) | Unbranded alley clutter — collection built for this exact aesthetic |
| 20 | Barrel Stove | `barrel_stove` | Model ("Hidden Alley" collection) | Improvised heater prop — informal nightlife-corner detail |

---

## Recommendation

- **Hero warehouse:** Sketchfab #1 `17f9bd6278014857947798ea47db40e3` (Old Warehouse), re-skinned
  with Poly Haven `rusty_metal_02` + `rusty_corrugated_iron` for palette consistency.
- **Dock:** Sketchfab #4 `9528bbe1ecb04ea8bae283c773e1fcb5` (Dock Pier).
- **Lighting test:** drop Poly Haven `cobblestone_street_night` HDRI into the scene first — fastest
  free path to a "rainy noir night" lighting reference before any custom lighting rig work.

## Next steps

1. Re-verify the two flagged Sketchfab UIDs solo (Trihuslab Pier, Dock Crane) before downloading.
2. Download via Blender MCP (`download_sketchfab_model` / `download_polyhaven_asset`).
3. Run every downloaded GLB through the standard pipeline: Blender cleanup (retopo, base-center
   pivot, trim-sheet UV, LOD0/LOD1, collider) → `GLBValidator` → Godot import test — per
   `docs/asset-standard.md` and the Month-2+ production gates in the root `CLAUDE.md`.
4. Log every asset actually used in `assets/ATTRIBUTIONS.md` (create on first use) with URL,
   license, and required attribution text.
