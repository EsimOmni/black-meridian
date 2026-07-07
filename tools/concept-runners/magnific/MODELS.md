# Magnific model catalog — routing guide

Scraped live from the Magnific web-UI model pickers. Source of truth: `recon_out/image_models_clean.json` (51 models) and `recon_out/video_models_clean.json` (53 models) — machine-readable dumps with `cy` selector, `slug`, `name`, `unlimited`, `credit`, `creditRange`, `refs`, `res`, `dur` per model. This file is the human-readable digest + routing guidance; re-scrape the JSON after any Magnific UI redeploy (see "Refreshing this catalog" below).

⚠️ **The unlimited signal is a web-UI-only concept.** `unlimited: true` here means free in the web UI (Premium+ subscription tier). The SAME model via MCP always burns credits — MCP has no unlimited mode (`unlimitedAppliesHere: false`). This catalog exists to route the Playwright runners (`image_runner.py`, and `google-flow/flow_runner.py` for the separate Google Flow surface) onto the free rail. Never use this to justify an MCP call.

## IMAGE — 36 of 51 models are unlimited (∞)

Image gen on Magnific is a near-free paradise via the web UI.

**4K unlimited + Refs (the heroes):**
- **Seedream 5 Lite** (`seedream-5-lite`, provider `seedream`) — 2K-4K, ∞, Refs, ~57s. ⭐ Flagship: 4K identity-locked stills for $0. This is `image_runner.py`'s current default.
- Seedream 4.5 (`seedream-4-5`) — 2K-4K, ∞, Refs, ~42s.
- Seedream 4 (`seedream-4` / `seedream-4-4k`) — up to 4K, ∞, Refs, ~30-43s.
- Google Nano Banana 2 (`imagen-nano-banana-2-flash`, provider `imagen`) — 2K-4K, ∞, Refs, ~36s. ⚠️ **Slug trap**: this is the FLASH variant. The bare `imagen-nano-banana-2` slug is "Nano Banana Pro" — 75-150 CREDIT, not unlimited. Always use the `-flash` suffix.

**Other unlimited (∞), no 4K but useful:**
- Recraft V4 / V4.1, Flux.2 Pro (2K, Refs), Flux.2 Klein (2K, Refs, ~7s), Flux.1 Kontext Max/Pro (Refs), Flux.1 / 1.1 / Realism / Fast, Mystic 2.5 (Training/Flexible/Fluid), Mystic 1.0 Training, Ideogram Negative, Runway (deprecated, Refs), Classic Fast Negative / Classic Negative, Z-Image, Qwen (Refs), Grok (Refs), Google Imagen 3/4/4-Fast/4-Ultra (deprecated), Google Nano Banana (v1, Refs), Google Nano Banana 2 Lite (Refs, no 4K).

**CREDIT models — avoid unless uniquely needed:**
- Cinematic (75-150), GPT 2 (15-1050), Google Nano Banana Pro (75-150 — see slug trap above), Flux.2 Max (130-715), Flux.2 Flex (80-280), Ideogram 4 (120-200), Luma Uni-1.1 (140-430), Krea 2 (80-160), MAI Image 2.5 (120-200), GPT/GPT 1.5 variants (no listed credit range but not unlimited).

**Default routing:** Seedream 5 Lite for 4K district master keyframes. If results look off on a given prompt, try Google Nano Banana 2 (`imagen-nano-banana-2-flash`, provider `imagen`) as the alternate 4K-unlimited-with-refs option — both are ∞ + Refs + 4K.

## VIDEO — only 7 of 53 models are unlimited (opposite of image)

Video is selective; most models cost credits even at modest resolutions.

**The unlimited set:**
- **Kling 2.5** (`kling-25`) — Start/End, 1080p, 5-10s, ∞. ⭐ THE unlimited-video rail: ∞ AND 1080p AND start+end keyframe support. Often no upscale needed.
- Seedance 1.5 Pro (`bytedance-seedance-pro-1.5`) — Multi Start/End, custom seed, 1080p, 4-12s, ∞.
- Wan 2.2 (`wan-2-2`) — Start, custom seed, 720p, 5-10s, ∞.
- MiniMax Hailuo 2.3 Start / Hailuo 2.3 Fast Start (`minimax-video-2_3` / `-fast`) — 1080p, 6-10s, ∞.

**Near-free credit (great value, not unlimited):**
- Seedance 2.0 / 2.0 Fast / 2.0 Mini — 4-15 cr, 4K Refs (full Seedance 2.0), 720p (Fast/Mini variants).
- Kling 2.6 — 5-10 cr, Start/End 1080p, Audio.
- Veo 3.1 / 3.1 Lite / 3.1 Fast — 4-8 cr, some 4K (`google-veo3_1` full + `-fast` are 4K; `-lite` is not).
- Grok Imagine / Grok — 1-15 cr, 720p Start.

**Expensive hero (credit-heavy, use only when the model is uniquely needed):**
- Kling 3.0 / 3.0 Omni / 3.0 Turbo (210-6000+), Wan 2.7 (260-3000), Happy Horse / Happy Horse 1.1 / Edit (165-4200), Sora 2 / Sora 2 Pro (600-22k), LTX 2 Fast/Pro (480-6400, up to 2160p), Runway Gen-4.5/Gen4/Act Two (300-3000), Veed Fabric 1.0 (420-105k), PixVerse 5.5/6 (100-3000), Wan 2.5/2.6/Animate (500-48k), Omni Human 1.5 (540-5400), Kling Motion Control variants (150-2250).

**Routing:**
- Unlimited-video batch → Kling 2.5 (`kling-25`), 1080p, start/end.
- Cheap 4K → Seedance 2.0 (~4-15 cr).
- Premium hero, cost matters → Veo 3.1 (cheap end of its range) or Kling 3.0 (pricey but 4K + Audio).
- Motion-control/recast → Kling Motion Control / Runway Act-Two (credit, no unlimited option exists).
- Identity multi-angle / camera-orbit → route to `google-flow/` instead (Nano Banana 2 in Flow's "Ingredients" mode is the 4-ref identity-lock formula; separate from this Magnific catalog).

## Selector reference (for extending `pipeline/image_browser.py` / a future `video_browser.py`)

**Image:** panel/form `image-generator-form`; model trigger has NO dedicated `data-cy` — it's the button next to the "MODEL" label (find the `MODEL` text node, click the nearest button); prompt `image-prompt-input` (contenteditable, `@` for refs); `smart-prompt-toggle` (AI-prompt enhance); refs `reference-{style,character}-placeholder` + `reference-add-button`; `image-aspect-ratio-input`; count stepper; `generate-button`. Reference modal has 10 sidebar tabs: `reference-sidebar-{stockImages,style,character,product,locations,color,effects,camera,sketch,upload,history}`. Model rows: FEATURED = `tti-model-selector-popover-model-<slug>`; inside a provider group = `tti-model-selector-popover-provider-model-<slug>` (expand the group first via `…-provider-<providerSlug>`). Unlimited signal = `∞` SVG icon `<use xlink:href="#cdn-infinity">` inside the row — NOT text; scrape the icon, not innerText.

**Video** (not yet wired into a Black Meridian runner — Magnific video is not ported, only image + Google Flow): panel `video-generator-panel`; model `video-model-selector-trigger`; keyframes `video-start-frame-input` / `video-end-frame-input`; refs `video-add-reference-{image,video,audio,character,product,sketch}` + `video-advanced-references-add`; multi-shot `video-add-shot-button`; prompt `video-prompt-input`; `video-duration-config-option` / `video-aspect-ratio-option`; audio `video-generator-soundfx-switch-new`; `generate-button`. Model rows follow the same FEATURED/provider-group pattern as image, `video-`-prefixed.

## Refreshing this catalog

The source repo (personax) re-scrapes both matrices via a `recon_generators.py [image|video]` script that walks the live model picker DOM and writes `recon_out/{image,video}_models_clean.json` — zero credits, never clicks Generate. That script is personax-specific tooling (not ported here, since it isn't part of the runtime path — only its *output* is). If this catalog goes stale (new models ship, an unlimited badge is added/removed), re-run recon in personax and copy the two `_clean.json` files over, or write an equivalent recon script directly against `pipeline/image_browser.py`'s `_open_model_picker` primitive.
