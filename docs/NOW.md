# ŞU AN — Black Meridian canlı durum

> **Bu dosya her yeni chat/session'ın İLK okuduğu yerdir.** CLAUDE.md kalıcı kuralları tutar;
> bu dosya "şu an neredeyiz, sıradaki adım ne, hangi kararlar açık" durumunu tutar. Claude her
> slice/commit sonunda bunu günceller — Cem elle yazmaz. Eski durum "Geçmiş" bölümüne düşer.

**Son güncelleme:** 2026-07-08 (öğle) · **Aktif faz:** Month 3 — Glass Wharf asset üretimi
· **Kazanım:** hero kule uçtan uca LOKAL üretildi (Hunyuan geometri + texture, sıfır kredi, 16GB'da OOM'suz)

---

## 🎯 Şu an ne yapıyoruz

Glass Wharf district'ini onaylı master keyframe'e
(`assets/concept/glass_wharf/glasswharf_master.png` — yağmurlu, neon, alacakaranlık rıhtım noir)
uyacak şekilde **hazır asset'lerle** (Sketchfab CC0/CC-BY → Blender temizlik → Godot) donatıyoruz.
Doktrin: concept→asset-split (master ONAYLI, şimdi ona göre 3D üretiyoruz). AI ~90 / insan ~10.

## ✅ Bitti (bu üretim kolunda)

- **3 landmark yerinde ve dokulu:** warehouse_hero, industrial_block_a, dock_house_pier —
  `src/presentation/district_landmarks.gd` → `PLACEMENTS`. Hepsi CC-BY, attribution loglu.
- **Grey-wash fix:** Sketchfab GLB'leri kendi texture'ını korur; `textured:true` flag'i
  `_apply_noir_detail` shader'ını atlatır (flat-color P12b landmark'ları hâlâ weathering alır).
- **Asset pipeline kanıtlandı** (~1 dk/asset): download → Blender join+base-center-pivot+1K-texture
  → GLB export (**Draco OFF** — Godot 4.7 okuyamaz) → `--import` doğrula.
- **Repo self-consistent:** landmark texture'ları commit'lendi — fresh clone gri açılmaz.
- **`DockProps` prop scatter placer** (`src/presentation/dock_props.gd`, `city_view.gd`'de wire):
  5 Faz-1 prop yerinde, dokulu, master'a göre yayılmış + ölçekli — dock_crane, bollard_rope×2,
  fishing_supplies, market_stall×2, pallet_pack×2. Hepsi **CC-BY, UID+attribution loglu**
  (`ATTRIBUTIONS.md`). DistrictLandmarks'ı aynalar ama scatter list + prop, patina shader YOK.
- **PolyHaven Faz 2 — gece HDRI atmosferi** (CC0, attribution gerekmez): `cobblestone_street_night_4k.hdr`
  → `bootstrap.gd` WorldEnvironment'a **ambient + reflection source** olarak bağlandı (background düz
  noir renk KALIR — diorama gökyüzü göstermez; yüzeyler gerçek gece cadde ışığı alır, düz renk ambient
  değil). Kutular/prop'lar "kuru mat"tan "gece ışığında yıkanmış"a geçti. Ground ıslaklığı artırıldı
  (roughness 0.08, metallic 0.45). `assets/city/glasswharf_dock/env/`'de HDRI. Pas/ahşap PBR
  texture'lar HDRI-only yettiği için KULLANILMADI (haul'da duruyor, footprint eklemedim).
- **Neon vitrin (master imzası):** venue kutularının ZEMIN bandına sıcak sodyum emissive
  (`city_view.gd` `_tint_building`/`_tint_meshes`) — env glow onu vitrin gibi bloom'lar; üst katlar
  mat kalır (bina blok gibi parlamaz). Band ayrımı **root'un doğrudan child'ının** y'sinden okunur
  (leaf mesh'ler GLB-içi local y≈0 → ilk denemede tüm stack parladı, band-y'ye çevirdim, düzeldi).

## ⏭️ Sıradaki adım

1. **Bekleyen prop'ları kurtar:** container×2, dumpster, fishing_boat, street_lamp, lamp_post_vintage
   — bir kısmı **yatık/havada pivot'la** export olmuş (base_y≠0, Y-Z ekseni dönük), üstelik
   **download UID/lisansı kayıtlı değil**. Blender'da doğru pivot/rotasyonla YENİDEN export + Sketchfab
   UID'den lisans doğrula, sonra `DockProps`'a ekle. Ham dosyalar `D:\bm-asset-haul\pending-props\`'ta.
2. **Kompozisyon ince-ayar (insan %10):** prop'lar yayıldı+büyüdü ama hâlâ %70 master; skyline
   kamerasından (oyun-içi C) bak, master'ın derin pier'ine göre son rötuş. Diminishing returns —
   sonsuz kovalama.
3. **Neon polish:** master'ın sıcak neon vitrinleri (emissive pencereler). market_stall'da
   `_plus_emissive` texture'ı var — neon aksan için değerlendirilebilir.
4. **Zemin tam-mirror ıslaklık — MİMARİ SINIR, KOVALAMA.** HDRI reflection + SSR + roughness/metallic
   denendi (3+ ayar), hepsi marjinal. Kök neden ayar değil: zemin düz koyu (albedo 0.05) + kutuların
   ALTINDA bitiyor, önlerine uzanmıyor — master'da ıslak cadde kutuların ÖNÜNE serilir. Gerçek
   ıslak-neon-ayna için ya kompozisyon (zemini öne getir) ya cobblestone texture+normal — ikisi de
   büyük iş, düşük getiri. SSR eklendi (metal prop/kule yüzeyinde gerçekçi katkı, skyline'da okur),
   ama tam mirror bırakıldı. Skyline'dan bakınca sahne zaten master ruhunu taşıyor.

## 💳 Hero geometri — Magnific image→3D (AKTİF: alien kule)

**Hedef seçildi (2026-07-08):** master'ın imza öğesi = **alien hero kule**, dil = **hibrit** (yapısal
brutalist taban + organik/biyomorfik biyolüminesan taç). Mevcut basit `alien_diplomatic_tower`'ı
yükseltecek focal landmark.

- **Adım 1 — concept görseli ✅ YAPILDI (bedava, kredi yok):** ChatGPT (OMNI Labs Studio projesi,
  Instant modda) ile üretildi — `assets/concept/glass_wharf/alien_tower_hero.png` (1024×1536, hibrit
  brutalist taban + organik biyolüminesan taç, tam isabet). Playwright ile açıldı, Cem login oldu,
  Claude prompt'ladı + görseli sayfa-fetch ile repoya indirdi. **Onaylandı.**
- **Adım 2 — image→3D: PLAN DEĞİŞTİ → LOKAL BEDAVA.** Magnific kredisi YAKMIYORUZ. Lokal
  **Hunyuan3D 2.1** var (`D:\AI\SwarmUI\dlbackend\comfy\ComfyUI` backend, model ağırlıkları inmiş) —
  TripoSR'den kaliteli, organik taca uygun, sıfır kredi (brief §10: local cover, only pay for a win).
  PersonaX'in **OMNI 3D pipeline'ı bu repoya taşındı** (`tools/pipeline/` + `manifests/` + `jobs/`),
  yeni **`hunyuan.py` adapter'ı** eklendi (ComfyUI UI-workflow → /prompt API, image enjekte, POST,
  poll, GLB çıkar). Job: `jobs/active/alien_tower_hero_001.json` (geometry→hunyuan3d, metre,
  floor-center, 22×60×22 landmark, building budget). **validate + dry-run GEÇTİ** (commit ec8f884).
- **Adım 3 — Hunyuan GLB ÜRETİLDİ ✅ (71a9a23):** `python -m tools.pipeline run-job
  jobs/active/alien_tower_hero_001.json --stage hunyuan3d` (env `OMNI_COMFY_URL=http://127.0.0.1:7821`
  — SwarmUI ComfyUI backend portu **7821**, 8188 DEĞİL). Çıktı: **100k vertex / 200k tri geçerli GLB**,
  texture'sız (geometry candidate), `assets/_generated/hunyuan3d/alien_tower_hero_001/v001/`. Adapter
  5 bug'dan geçti (object_info-driven widget map, token-overlap ckpt snap, dmc→mc, Preview3D strip).
- **Adım 4 — Hunyuan TEXTURE ÜRETİLDİ ✅ (2026-07-08, uçtan uca lokal kanıtlandı):** `Mesh_Texturing`
  workflow'u 16GB'da OOM'suz çalıştı (~2 dk, exit 0). Prova script'i adapter helper'larını yeniden
  kullandı: `Hy3D21LoadMesh.glb_path`←v002 GLB, `LoadImageWithTransparency`←cutout, Preview3D strip.
  Çıktı: **`alien_tower_hero_001_v002_tex.glb` (6.8 MB)** — baseColor 1024² + metallicRoughness 1024²
  PBR gömülü, her vertex UV'li. Blender render doğrulandı: **hibrit dil birebir konseptte** (patina
  brutalist taban → örülü cyan-yeşil biyolüminesan taç), hero-kalite, çamur yok. **KRİTİK BULGU:
  16GB texture'ı kaldırıyor → yüksek-VRAM (5090) bu iş için GEREKMİYOR.** Tek zayıflık: view-projection
  texturing "elle boyanmış" his + tepe tendrillerde hafif smear (uzak skyline landmark'ı için sorun değil).
  Prova script'i `scratchpad/texture_prova.py` (tek seferlik — adapter'a branch OLARAK EKLENMEDİ henüz).
- **Adım 5 — SIRADAKI: Blender temizlik.** Textured GLB'yi Blender'a al → cutout'tan kalan zemin plakasını
  sil → decimate (200k→≤30k landmark budget), base-center pivot (y=0), grid ölçek (22×60×22), collider,
  Draco OFF → `assets/_exports/` → GLBValidator → DistrictLandmarks'ta `alien_diplomatic_tower` yerine
  koy → skyline'dan bak. Ham Hunyuan çıktısı game-ready DEĞİL (arka yüz belirsiz).
- **Adım 6 — texturing'i adapter'a branch yap** (Blender+skyline testinden SONRA): `hunyuan.py`'ye
  `Mesh_Texturing` route ekle → gelecekteki her hero `--stage texture` tek komut. Şimdi değil, önce
  ilk hero'yu oyunda gör.
- **YEDEK PLAN — Trellis A/B** (lokalde SwarmUI'da mevcut, henüz DENENMEDİ): Trellis native-3D-latent'ten
  üretir, texture mesh'e daha yapışık gelebilir. Denemenin DOĞRU zamanı = Hunyuan kule skyline'da texture
  smear'i rahatsız ederse, aynı cutout'la Trellis çalıştır + A/B. Şimdi denemek erken (oyun-içi bağlam
  olmadan kıyas anlamsız). Trellis organik formda bazen Hunyuan'dan yumuşak/az detaylı çıkar — garanti değil.

## 💳 Hero geometri — kredi doktrini (referans)

Krediyi SADECE **kimlik taşıyan hero geometriye** harca (master'ın focal landmark'ları + 2-3 imza
prop). Çevre/dolgu/materyal = Sketchfab+PolyHaven bedava, oraya kredi YAKMA.

- **Bakiye: ~40K kredi** (45K havuz). MCP'de `unlimitedAppliesHere:false` → her generate kredi yakar.
  Kredi bol; darboğaz Blender temizlik emeği, o yüzden az sayıda gerçek hero'ya odaklan.
- **Model fiyatları (MCP/UI, kesin):** Trellis 2 @512=610 (ucuz ama UV kötü/baked → sadece uzak landmark
  veya PROVA) · Tripo P1=775 · Tripo v3.1 detailed=1160 (PBR'a yakın) · Meshy 6=1160 (en temiz topoloji/UV,
  hero için en güvenli, en az Blender emeği).
- **Doktrin:** önce ucuz **Trellis 610 prova** (silüet/kompozisyon master'a oturuyor mu Godot'ta gör) →
  onaylıysa o pozisyona **Meshy 6 / Tripo v3.1 detailed @1160 hero** bas. 1160'ı yanlış objeye yakma.
- Her çıktı **provisional**: Blender (retopo, base-center pivot, trim UV, LOD, collider) → GLBValidator → Godot testi.
- **Paralı generate ÖNCESİ Cem'e gerçek maliyet + belirsizlik sun, onay al.** Model seçimi Cem'in kararı.
- **ZAMANLAMA:** diğer asset'ler (haul + prop pipeline) master'a oturduktan SONRA bas. Şu an sıra değil.

## ⚠️ Açık kararlar / bilinen sorunlar

- Kompozisyon henüz master'a uymuyor (kümeli, küçük) — prop'lardan sonra tek geçişte düzeltilecek.
- Codex kotası **10 Temmuz'a kadar yok** (3 gün) — Blender'ı Claude kendi MCP'siyle sürüyor.
- Subagent'lar Blender MCP'ye erişemez (client Claude session'ında kayıtlı) — Blender işi ana thread veya ayrı chat.
- Prop UID'lerinin bir kısmı re-verify istiyor (crane thumbnail, boat isim/görsel uyumu).

## 🔑 Kilit dosyalar (bu faz)

| Dosya | Ne |
|---|---|
| `src/presentation/district_landmarks.gd` | landmark yerleştirme (`PLACEMENTS`) — `textured` flag burada |
| `docs/glass-wharf-buildout-plan.md` | prop UID'leri + hedef boyutlar + yerleştirme niyeti |
| `docs/glass-wharf-asset-research.md` | Sonnet'in tam asset araştırması (20 geo + 20 material) |
| `assets/ATTRIBUTIONS.md` | CC-BY attribution logu (Steam ticari şart) |
| `docs/asset-standard.md` | GLBValidator spec (per-category bütçe, base-center pivot) |
| `assets/city/glasswharf_dock/` | tüm kit + landmark GLB'leri buraya |

---

## Geçmiş (özet — detay git log + claude-mem'de)

- **Month 2 COMPLETE + gate PASSED** (2026-07-04): tam Night-Cycle loop, P05–P11, deterministik/zero-RNG/save-safe.
  Feel verdict "fun, stress, very good". Month 3 (asset üretimi) AUTHORIZED.
- **Month 1** (2026-07-04): data model, GameState, TimeService, Economy, WorldSeed, greybox, save/load.
- **Splat: SPLAT_OK** (2026-07-02): 542k splat @ 483 fps 1080p, kill criterion çözüldü.
