# ŞU AN — Black Meridian canlı durum

> **Bu dosya her yeni chat/session'ın İLK okuduğu yerdir.** CLAUDE.md kalıcı kuralları tutar;
> bu dosya "şu an neredeyiz, sıradaki adım ne, hangi kararlar açık" durumunu tutar. Claude her
> slice/commit sonunda bunu günceller — Cem elle yazmaz. Eski durum "Geçmiş" bölümüne düşer.

**Son güncelleme:** 2026-09-18 · **Aktif faz:** 🔁 **UNREAL REBOOT — S2 GEÇTİ**, sıra S3'te

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

## ✅ S1 GEÇTİ (2026-09-18) — bu repo oracle olarak görevini yaptı

`tools/export_golden_vectors.gd` yazıldı ve çalıştırıldı (`970f5c0`) — salt-okunur, iki koşuda
bayt-aynı çıktı. Vektörler `D:\black-meridian-ue\Tests\Golden\hash_vectors.json` altında
(1719 hash · 1408 tie_jitter · 240 variant_index satırı, şema 2). Kanıt:
`black-meridian-ue\Docs\gates\S1.md`. **Gate exit 0, üç test de Success.**

```sh
D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path . \
    -s tools/export_golden_vectors.gd -- --out=<mutlak yol>.json
```

Bu repo'da öğrenilen ve gelecekteki her oracle script'ini ilgilendiren iki şey:
**`-s` SceneTree script'inde autoload YOKTUR** (`WorldSeed.build()` `GameState`'e yazdığı için
kullanılamaz — id'ler `world_seed.gd` kaynağından parse edilir) ve **stdout güvenli kanal değildir**
(`_mcp_game_helper` autoload'ı script bittikten *sonra* banner basıyor, yönlendirilen belgeyi bozuyor
— script dosyayı kendisi yazar).

Planlama paketinin hash'le ilgili **üç** iddiası da yanlış çıktı; düzeltmeler
`docs/unreal-reboot/`'a işlendi ve UE repo'suna yeniden aynalandı. Üçüncüsü — `_avalanche`'ın
"splitmix64" diye adlandırılması, oysa **MurmurHash3 fmix64** olması — C++ portunu bir kez
gate'ten geçirmedi (hash 1719/1719 tuttu, avalanche 1719/1719 tutmadı). Bu repo'daki iki GDScript
kopyasına da uyarı notu düşüldü. **SC-2 tetiklenmedi.**

---

## ✅ S2 GEÇTİ (2026-09-18) — bu repo İKİ fixture daha üretti

> Not: bu bölümün eski hali "bu repo'nun S2'de bir görevi yok" diyordu. **Yanlış çıktı** — S2 bu
> repo'dan iki yeni oracle çıkarımı istedi. Aynı varsayımı S3 için de yapma.

| script | üretti | nasıl koşar |
|---|---|---|
| `tools/export_sim_vectors.gd` | `sim_vectors.json` — 2526 satır (econ/heat/evidence/pressure/operatives) | `-s` ile (saf matematik) |
| `tools/export_trajectory.gd` + `.tscn` | `trajectory.json` — 1800 tick, 120'de bir örnek | **`.tscn` ile** (autoload gerekiyor) |

İkisi de koşular arası bayt-aynı. Unreal tarafı: **23/23 test, exit 0**.

**Neden biri `-s` biri `.tscn`:** vektörler *saf matematiği* ölçüyor (autoload'suz `RefCounted`
static'leri), o yüzden sabitleri kaynaktan regex'le parse edip autoload adı anmaktan kaçınabiliyor.
Trajectory ise *servis katmanının zaman içindeki bileşimini* ölçüyor — yani ölçülen şeyin kendisi
autoload kompozisyonu. Kaçamak yapısal olarak mümkün değil, sahne olarak koşuyor (repo konvansiyonu:
`tools/validation/*.tscn`).

**Trajectory politikası PASİF** — oyuncu hiçbir şey yapmıyor. `full_cycle_probe.gd` iş çözüyor, ki o
bir *sağlık* aleti için doğru ama golden vector için yanlış: eğri narrative *içeriğinin* fonksiyonu
olurdu, bir job template'indeki tek sayıyı değiştirmek referansı kaydırırdı.

⚠️ **Trajectory karşılaştırması tick 240'a kadar geçiyor, sonrası S5'e ertelendi** — ölçümle
kanıtlanarak, tercihle değil. Oracle gerçek autoload zincirini (`RivalDirector` dahil) sürüyor;
Unreal'in S2'si sadece ekonomi/heat/pressure. Eğriler tick 240'a kadar birebir, 360'ta ayrışıyor —
tam olarak oracle'ın kendi `phase` alanının COUNCIL→OPERATIONS döndüğü ve rakibin ilk kez
davranmasına izin verilen yer. Kesin kanıt: tick 240–360 arası oracle'ın ima ettiği exposure
(0.018664) bu dünyanın **sıfır-disruption tavanını** (0.016845) aşıyor; ekonomi içi hiçbir hata
kendi tavanını aşamaz.

---

## ⚠️ Açık kararlar

- ~~**D-01**~~ — **KAPANDI** (2026-09-18): VS 2022 Community 17.14 kuruldu ve doğrulandı.
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
- `src/` + `tests/unit/` — golden vector'lerin çıkarıldığı oracle. ⚠️ 24 unit test'in **20'si
  `-s` ile koşmuyor** (autoload gerektiriyorlar); import temiz. CLAUDE.md'deki "24/24" iddiası bayat.
- **Üç oracle çıkarıcı** (hepsi salt-okunur, hepsi koşular arası bayt-aynı):
  - `tools/export_golden_vectors.gd` — hash katmanları (S1), `-s`
  - `tools/export_sim_vectors.gd` — econ/heat/evidence/pressure/operatives (S2), `-s`
  - `tools/export_trajectory.gd` + `.tscn` — 1800 tick eğrisi (S2), **sahne olarak**
- `tools/validation/full_cycle_probe.gd` — *sağlık* aleti, golden vector DEĞİL (iş çözer, yani
  eğrisi narrative içeriğine bağlıdır). Referans üretmek için kullanma.

---

## Geçmiş (özet — detay git log + claude-mem'de)

- **UNREAL REBOOT S2 GEÇTİ** (2026-09-18): bu repo iki fixture daha üretti (`sim_vectors.json`
  2526 satır, `trajectory.json` 1800 tick), ikisi de bayt-aynı. Unreal 23/23, exit 0. Taşınacak iki
  ders: **gate'in ilk koşuda yeşil yanması kanıt değil** — mutasyon testi üç boşluk buldu, ikisi
  derlenen-deterministik-yanlış oyun gönderecekti; ve **bir gate tam geçemiyorsa toleransı gevşetmek
  değil NEDENİNİ ölçmek doğrusu** (oracle'ın exposure'ı sıfır-disruption tavanını aşıyordu → fazlalık
  rakipten geliyor, o da S5). Plana altı düzeltme daha işlendi.
- **UNREAL REBOOT S1 GEÇTİ** (2026-09-18): bu repo oracle olarak çalıştı; vektörler çıkarıldı, hash
  sözleşmesi ampirik olarak çivilendi, planın **üç** hash iddiası da yanlış çıktı ve düzeltildi.
  Taşınacak ders: **ondalık literal, algoritma adını yener** — "splitmix64" yazısına güvenmek
  derlenen, deterministik ve YANLIŞ bir oyun üretti; gate yakaladı. D-01 kapandı.
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
