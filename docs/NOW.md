# ŞU AN — Black Meridian canlı durum

> **Bu dosya her yeni chat/session'ın İLK okuduğu yerdir.** CLAUDE.md kalıcı kuralları tutar;
> bu dosya "şu an neredeyiz, sıradaki adım ne, hangi kararlar açık" durumunu tutar. Claude her
> slice/commit sonunda bunu günceller — Cem elle yazmaz. Eski durum "Geçmiş" bölümüne düşer.

**Son güncelleme:** 2026-07-08 · **Aktif faz:** Month 3 — Glass Wharf asset üretimi

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
- **Repo self-consistent:** landmark texture'ları (170 dosya) commit'lendi — fresh clone gri açılmaz.

## ⏭️ Sıradaki adım

1. **Prop batch (Grup B):** container/paslı container/fishing boat/street lamp/vintage lamp/dumpster/
   crane — UID'ler + hedef boyutlar `docs/glass-wharf-buildout-plan.md`'de. Başka chate verilen
   prompt hazır (Sketchfab→Blender→Godot, aynı pipeline). GLB'ler `assets/city/glasswharf_dock/`'a gelecek.
2. **`DockProps` scatter placer yaz** — `DistrictLandmarks`'ı aynala ama scatter list + prop spec,
   patina shader YOK (prop'lar kendi material'ını korur). Sabit authored dizi (RNG YOK).
3. **Kompozisyon (insan %10):** landmark'lar şu an merkeze kümeli + venue kutularına göre küçük.
   Master'ın pier dizilimine göre yay + ölçeği büyüt.
4. **Neon polish:** master'ın sıcak neon vitrinleri eksik (emissive pencereler) + ıslak/yağmur grade.

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
