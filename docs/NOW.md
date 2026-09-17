# ŞU AN — Black Meridian canlı durum

> **Bu dosya her yeni chat/session'ın İLK okuduğu yerdir.** CLAUDE.md kalıcı kuralları tutar;
> bu dosya "şu an neredeyiz, sıradaki adım ne, hangi kararlar açık" durumunu tutar. Claude her
> slice/commit sonunda bunu günceller — Cem elle yazmaz. Eski durum "Geçmiş" bölümüne düşer.

**Son güncelleme:** 2026-09-18 · **Aktif faz:** 🔁 **UNREAL REBOOT — S0 BİTTİ, S1 BEKLİYOR**

> UYARI: **Bu dosya ARŞİV repo'sunun durumudur.** Aktif geliştirmenin canlı durumu
> **`D:\black-meridian-ue\NOW.md`**'dir — slice ilerlemesi, S1+ notları ve günlük durum ORADA güncellenir.
> Burası sadece "bu repo artık ne işe yarıyor" sorusunu cevaplar ve nadiren değişir.
> İkisi çelişirse **UE repo'sundaki NOW.md kazanır**.

---

## 🚨 EN ÖNEMLİ: motor değişti — Godot ARTIK GELİŞTİRİLMİYOR

Proje **Godot 4.7'den Unreal Engine 5.8.2'ye** taşındı (onaylı reboot, 2026-09-18).

| | |
|---|---|
| **Aktif geliştirme repo'su** | **`D:\black-meridian-ue`** → `EsimOmni/black-meridian-ue` (private) |
| **Bu repo (`D:\black-meridian`)** | **ARŞİV + behavioral oracle.** Silinmez, yeniden yazılmaz, çalışır kalır. Yeni oyun kodu BURAYA YAZILMAZ. |
| **Godot son durumu** | `godot-final` tag'i → `aff9e43`. Headless exit 0 ile çalıştığı doğrulandı. |

**Bu repo'nun tek işlevi artık:** golden vector çıkarımı (S1'de Unreal'in doğruluğunu ölçen oracle)
ve Gate B'de Unreal cinematic'iyle yan yana oynanacak referans. Godot tarafında feature/slice
geliştirmesi YOK.

> ⚠️ **"S1" adı çakışıyor — dikkat.** Bu dosyanın eski sürümündeki "S1" *Godot push'unun Month-3
> kapanışıydı ve BİTTİ*. Şu an sıradaki **S1 = Unreal reboot'un Determinism Core** slice'ı. Biri
> diğerinin devamı değil. Aşağıdaki S1 her zaman Unreal olanıdır.

---

## ✅ S0 TAMAM (2026-09-18) — gate PASSED, 11/11

Kanıt: **`D:\black-meridian-ue\Docs\gates\S0.md`** (okumadan S1'e başlama).

- Unreal repo kuruldu, **LFS ilk commit'te** (`1da360f`), asset'ten önce — R-07 kapalı.
- 5 modül: `BMCore` (Engine bağımlılığı YOK — determinizm duvarı) · `BMSim` · `BMGame` · `BMUI` · `BMEditor`.
- `BlackMeridianEditor Win64 Development` → **Succeeded, 0 uyarı**, 5 non-zero DLL.
- `BM.Smoke` → **Result={Success}**, exit 0, log'da 0 `Error:`.
- Shipping paketleme → **BUILD SUCCESSFUL**, `Builds/Windows/BlackMeridian.exe` + pak/utoc.
- `ATTRIBUTIONS.md` + `lessons.md` Unreal repo'ya göç etti (devam, sıfırlama değil).

**S0, planlama paketinde 4 hata buldu; hepsi düzeltildi** (`6fb3c97`) — detay `Docs/gates/S0.md`:
D-01'in premisi yanlıştı (NetFx SDK S0 için de zorunluymuş) · `.gitattributes` glob'ları LFS'i
sessizce bozuyordu · glTF Importer plugin'i UE 5.8'de yok · `UnrealBuildTool.exe` .NET 10 istiyor
(`Build.bat`'tan git).

---

## ⏭️ Sıradaki iş: **S1 — Determinism Core** (BAŞLANMADI)

Spec: `docs/unreal-reboot/07_IMPLEMENTATION_ROADMAP.md` → S1 · mimari:
`04_UNREAL_ARCHITECTURE.md` · test: `08_TEST_STRATEGY.md`.
(Aynı paketin kopyası Unreal repo'da: `Docs/plan/`.)

**Gate koşulu:** *her hash golden vector'ü birebir eşleşecek.* Otomatik, tavizsiz.

Başlamadan önce iki ön koşul:
1. **Golden vector çıkarımı** — bu Godot repo'sunu oracle olarak çalıştırıp JSON vektörleri üret,
   `black-meridian-ue/Tests/Golden/` altına koy. S1'in ilk işi budur.
2. **D-01'in IDE yarısı** — VS 2022 Community. Determinizm hatası *sessiz* (R-03); breakpoint'siz
   1260 tick'lik hash uyuşmazlığı kovalamak kötü takas. SDK yarısı S0'da halledildi.

---

## ⚠️ Açık kararlar

- **D-01 (yarım)** — NetFx SDK ✅ kuruldu; **VS 2022 Community IDE hâlâ yok.** S1 öncesi önerilir.
- **D-02 / D-10 (AÇIK)** — karakter kimliği + prodüksiyon rotası. **S12'ye kadar çözülecek.**
  ⚠️ `OMNI_CERT_AIKO_2026_0001_v1.0.0`'ın oyun karakteri Aiko Velora'yı temsil ettiği
  **varsayılmayacak** — Cem'in açık talimatı.
- **D-07** — Gaussian splat vertical slice'tan ÇIKARILDI; ancak Gate B'den sonra yeniden değerlendirilebilir.

---

## 🔑 Kilit dosyalar

**Unreal (aktif geliştirme):**
- `D:\black-meridian-ue\Docs\gates\S0.md` — S0 kanıtı + 4 bulgu
- `D:\black-meridian-ue\Source\BMCore\` — saf logic, Engine YOK
- `D:\black-meridian-ue\Docs\plan\` — düzeltilmiş planlama paketi aynası
- `D:\black-meridian-ue\Docs\lessons.md` — Godot'dan devralınan dersler

**Bu repo (arşiv/oracle):**
- `docs/unreal-reboot/` — planlama paketinin **authoring** evi (düzeltmeler buraya işlenir)
- `docs/archive/astra-recovery-2026-09/` — tarihsel kanıt, **authoritative DEĞİL** (D-09 modified)
- `src/` + `tests/unit/` — golden vector'lerin çıkarılacağı oracle (24/24 test geçiyor)

---

## Geçmiş (özet — detay git log + claude-mem'de)

- **UNREAL REBOOT S0** (2026-09-18): repo bootstrap, 5 modül, build+smoke+paketleme yeşil,
  `godot-final` tag'i, astra-recovery arşivlendi, planlama paketine 4 düzeltme işlendi.
- **P20 — Godot hattının son feature'ı** (`de05ef9`): settings paneli, rebindable input,
  audio cues, onboarding nudges. 24/24 test, import temiz, boot smoke exit 0. Godot'da son commit bu.
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
