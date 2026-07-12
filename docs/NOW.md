# ŞU AN — Black Meridian canlı durum

> **Bu dosya her yeni chat/session'ın İLK okuduğu yerdir.** CLAUDE.md kalıcı kuralları tutar;
> bu dosya "şu an neredeyiz, sıradaki adım ne, hangi kararlar açık" durumunu tutar. Claude her
> slice/commit sonunda bunu günceller — Cem elle yazmaz. Eski durum "Geçmiş" bölümüne düşer.

**Son güncelleme:** 2026-07-12 (gece) · **Aktif faz:** 🚢 **ANAHTAR TESLİM PUSH** (onaylı plan:
`~/.claude/plans/reis-ben-bu-projeden-breezy-badger.md` — sprint sırası + locked kararlar orada).
**S1 (Month-3 kapanışı) ✅ + S2.1 (P16) ✅ BİTTİ** — şu an **S2.2 P17-lite mesh cinematic** ortasında.

## 🔒 Push'un locked kararları (2026-07-12, Cem — yeniden tartışılmaz)

1. **"Oyun bitsin, sonra her şeyi değiştiririz."** Her kararda en hızlı kabul-edilebilir yol;
   polish defteri AÇILMAZ; her asset/ekran/ses swappable placeholder. Deferred backlog (P05b,
   P07b/c-artıkları, P10b-artıkları) sadece oynanışta delik açarsa girer.
2. **P17 cinematic dünya = mesh interior, $0** (Marble YOK, splat YOK); `CinematicWorldProvider`
   interface'i ile splat'a sonradan swap edilebilir kalır.
3. **Karakterler = 2D portre roster** (3D model/rig/anim YOK).
4. **Teslim = Windows build + paket (P22+P24); P23 (Steam store/trailer) ERTELENDİ.**
5. **Playtest = Cem + 1-2 kişi.** Deterministik sim disiplini + IP boundary taviz görmez.

## ✅ Bu push'ta bitenler (hepsi commit + verify'lı)

- **S1a — P13e trafik illüzyonu** (2395880): `TrafficProxy` tek MultiMesh, 24 araç, 2 zıt şerit
  (z=10.5/12.5 koridoru), akış tamamen GPU (vertex shader sawtooth, TIME+hash-faz, RNG yok).
  Shader-taşınan span için custom AABB şart (yoksa pan kenarında cull) — bilinen tuzak.
- **S1b — P14b-lite roster** (bee3089): `RosterPanel` (R toggle) — portre, PUBLIC motive network
  (gizli motiveler ASLA render edilmez, o asimetri tasarımın kendisi), ilişki edge'leri, betrayal
  tell. Read-only, state sahibi değil. R guard: transition layer'ı gizlediğinde input yutulur
  (cinematic'lerin R'siyle çakışma).
- **S1b — portre seti** (f316c1b): 4 principal noir portresi `assets/characters/portraits/`
  (ChatGPT runner Instant, $0; Codex triage set-coherence 9/10). Placeholder statüsü: world-bible
  kimlik kilidi (brief §20) gelince yeniden üretilebilir; roster portresizken monograma düşer.
- **S1c — Month-3 gate NOTU + README** (5d6022e): gate PASSED — "1 char anim" maddesi ship-first
  kararıyla kapsam dışı (3D karakter yok ki anime edilsin), "1 vehicle" TrafficProxy + üç kez
  kanıtlanmış GLB pipeline ile karşılandı. `docs/prompts/notes/P14b-month3-gate.md`.
- **S2.1 — P16 NarrativeDirector** (3ca1e80): authored omurga — Intercepted Shipment →
  **Inspector's Ledger** (authored evidence beat; loud yol GERÇEK case eker → P06b zinciri) →
  **Lieutenant's Debt** (ilk loyalty krizi: beat fire'da leverage kurulur, YAKLAŞIM barı geçip
  geçmeyeceğine karar verir — pay_it/buy_marker altında tutar, bait/expiry üstüne iter, hepsi
  ≥0.05 float marjla; iki-kapılı telegraph + reassure-defuse aynen) → **Meridian Accord**
  (stance truce/leverage/war → P19 ending'lerinin tohumu). Mimari: bootstrap-wired
  `NarrativeDirector` + pure `NarrativeBeats` + `NarrativeJobs` (code-as-data, JobTemplates
  registry; **data/jobs .tres migrasyonu ship-first ile CUT** — "UI'ya gömme" kuralı korunuyor).
  Beat state `GameState.narrative_flags` (SaveService meta, additive). Kanıt: unit test +
  `narrative_probe.tscn` verdict **NARRATIVE CHAIN CLOSES** (telegraph/defuse/mid-chain +
  final save-load byte-identical) + 23 test süiti yeşil + roundtrip + boot smoke.

## ⏭️ Şu anki iş: S2.2 P17-lite (yarıda — dosyalar yazıldı, wiring kaldı)

`CinematicWorldProvider` seam'i yazıldı (P01'in deferred borcu): `cinematic_world_provider.gd`
(USE_SPLAT flag'li selector) + `splat_world_provider.gd` (GDGS yolu, P17b kodundan taşındı) +
`mesh_world_provider.gd` ($0 depo back-room: 8×6 m kabuk, pallet_pack×2 + fishing_supplies
prop'ları, sarkan sodyum lamba + petrol fill + kapı altı ışık sızıntısı). **KALAN:**
1. `reveal_scene.gd` + `crime_scene.gd` `_build_splat()` → provider çağrısına geçir
   (BOUNDS_HALF const → provider'dan gelen değer).
2. Görsel doğrula (godot-ai screenshot, cinematic'e gir).
3. S2.3 P18: `CinematicTransition.enter/enter_crime_scene`'e **checkpoint save** ekle +
   Month-4 gate integration probe'u (consequence persist + save/load'dan sağ çıkma — P17b/c
   persistence testleri ZATEN var, probe onları round-trip'le birleştirir).
4. 🎮 **CEM GATE #1**: cinematic feel seansı (10-15 dk) — S2 bitince dur, Cem'e haber ver.

**Kritik keşif (S2 scope'unu küçülten):** P17b/P17c ZATEN tam round-trip'i kuruyor
(pause → node swap → FP walk (WASD+mouse) → E incele / R verb / Q çık → consequence MEVCUT
verb'lerle (reassure / remove_case) → restore). Eksik SADECE: dünya (splat bench → mesh interior),
checkpoint save, gate probe'u.

## ⚠️ Açık kararlar / bilinen durumlar

- `test_territory_loss_p08b` **SceneTree-tabanlı** → `-s` ile koşulur; `.tscn`'i olarak koşarsan
  instance edilemez ve süreç ASILI kalır (suite loop tuzağı). SceneTree testleri: economy,
  job_lifecycle, kit_assembler, territory_loss.
- Boot smoke baseline: 5 "leaked at exit" satırı + 1 PagedAllocator hatası **pre-existing**
  (HEAD'de doğrulandı) — yeni satır yoksa temiz.
- Portre yedekleri scratchpad'de (ephemeral) — sadece seçilen 4'ü repoda.
- Codex kotası geri geldi (triage çalıştı). Magnific bakiye ~40K (bu push'ta harcama YOK).

## 🔑 Kilit dosyalar (bu faz)

| Dosya | Ne |
|---|---|
| `src/narrative/` | P16 omurga (director + beats + jobs) |
| `src/presentation/cinematic_world_provider.gd` (+mesh/splat) | S2.2 dünya seam'i |
| `src/presentation/cinematic_transition.gd` | round-trip; S2.3 checkpoint buraya |
| `scenes/cinematic/reveal_scene.gd`, `crime_scene.gd` | FP sahneler; provider'a geçecek |
| `tools/validation/narrative_probe.tscn` | P16 kanıtı; P18 probe'una şablon |
| `tests/unit/test_narrative_p16.tscn` | P16 unit süiti |

---

## Geçmiş (özet — detay git log + claude-mem'de)

- **Month 3 KAPANDI** (2026-07-10→12): P12 kit (10 GLB, 8/8 validator, KitAssembler canlı) ·
  P13b/c/d/e VFX katmanları (yağmur/steam/ripple/crowd/trafik — hepsi presentation-only kardeş
  node) · P14b-lite roster+portreler · Glass Wharf buildout (4 dokulu landmark + DockProps 5 prop,
  CC-BY loglu; PolyHaven gece HDRI ambient+reflection; neon vitrin bandı; alien hero kule —
  Hunyuan3D lokal, `PROVEN 2026-07-10` doktrini 4 agent dosyasında; kule polish defteri KAPALI,
  Cem kararı). Zemin tam-mirror ıslaklık = işaretli mimari sınır, kovalanmıyor. Gate notu:
  `docs/prompts/notes/P14b-month3-gate.md`.
- **P08b TERRITORY_LOSS origin** (2026-07-10): rival toprak kazanınca "Contested Ground" job'ı;
  probe TERRITORY LOSS CLOSES. Seed'e nötr yem venue (`gw_saltworks`) eklendi.
- **P17b/P17c cinematic reveal'ler** (2026-07-06/07): confront + crime-scene FP sahneleri,
  round-trip + persistence testli — Month-4'ün yarısı o zamandan hazırmış.
- **Month 2 COMPLETE + gate PASSED** (2026-07-04): P05–P11 tam Night-Cycle loop, deterministik/
  zero-RNG/save-safe. Feel verdict "fun, stress, very good". Month 3 authorized.
- **Month 1** (2026-07-02): data model, GameState, TimeService, Economy, WorldSeed, greybox,
  save/load (var_to_str, byte-identical), P03 job skeleton.
- **Splat: SPLAT_OK** (2026-07-02): 542k splat @ 483 fps 1080p (GDGS + push-constant patch);
  provider interface borcu S2.2'de ödendi.
