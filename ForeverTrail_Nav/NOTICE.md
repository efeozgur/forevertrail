# ForeverTrail Nav: kaynak ve lisans bildirimi / origin and licence notice

**Türkçe.** Bu klasör (`ForeverTrail_Nav`) ile `ForeverTrail_Nav_EK` ve `ForeverTrail_Nav_Kalimdor` klasörleri,
**Polestar_Nav 0.4.2.2** eklentisinin değiştirilmiş bir kopyasıdır. Orijinal eklenti
<https://github.com/fitzforge/polestar> adresindeki Polestar projesinin parçasıdır ve **GPL-3.0-or-later** ile lisanslıdır.
Bu kopya da aynı lisansla dağıtılır (`LICENSE`); ForeverTrail'in geri kalanının (MIT) lisansını **değiştirmez**,
yalnızca bu üç klasör GPL-3.0-or-later'dır.

**English.** The three folders `ForeverTrail_Nav`, `ForeverTrail_Nav_EK` and `ForeverTrail_Nav_Kalimdor` are a
**modified copy of Polestar_Nav 0.4.2.2**, part of the Polestar project (<https://github.com/fitzforge/polestar>),
licensed **GPL-3.0-or-later**. This copy is distributed under the same licence (`LICENSE`). It does not change the
licence of the rest of ForeverTrail (MIT); only these three folders are GPL-3.0-or-later.

## Kimden geldi / Where it comes from

- **Yönlendirici / router** (`Routing/`): Polestar'ın yürüme yönlendiricisi; **Shortest Path Forever v1.16.0**
  (Cillian Berragan, GPL-3.0-or-later, <https://github.com/cjber/shortest-path-forever>) kodundan başlamıştır.
  Telif ve lisans başlıkları dosyalarda olduğu gibi korunmuştur. Ayrıntı: `CREDITS.md`.
- **Yürüme haritaları / walking maps** (`Nav/`, `ForeverTrail_Nav_EK/`, `ForeverTrail_Nav_Kalimdor/`): **Leffe'nin
  navigasyon haritaları**ndan, Polestar tarafından (`forge nav pack`) oyun için sıkıştırılmıştır; Polestar bu haritaları
  Leffe'nin izniyle kullandığını belirtir (`CREDITS.md`). Haritalar aynı Forever istemcisinden üretilmiştir.
- **Bu kopyayı yapan / this copy:** ForeverTrail. Telif sahipleri, orijinal dosyalardaki başlıklarda yazdığı gibidir
  (Cillian Berragan; The Polestar authors). ForeverTrail yazarı bu kopyayı kendi sorumluluğunda dağıtır.

## Değişiklikler / Changes made for ForeverTrail

GPL-3.0 madde 5'e göre değişiklikler belirtilir:

1. **Yeniden adlandırma / renaming:** eklenti klasörleri ve TOC dosyaları `Polestar_Nav*` → `ForeverTrail_Nav*`;
   global adlar `PolestarPathData` → `ForeverTrailPathData`, `PolestarNavChokepoints` → `ForeverTrailNavChokepoints`,
   `Polestar_NavEngine` → `ForeverTrail_NavEngine`, `Polestar_NavCosts` → `ForeverTrail_NavCosts`; parça eklenti adları
   (`part = "..."`) ve yorumlardaki eklenti adları aynı şekilde.
2. **Bağımlılık kaldırıldı / dependency removed:** `## Dependencies: Polestar` silindi. `Routing/Path.lua` içindeki
   `Polestar.Nav.danger` ve `Polestar.Nav.travel` başvuruları `nil` yapıldı (ForeverTrail `walkLevel` göndermez, bu yüzden
   sıkı politika işi çalışmaz; yönlendirici düz rota arar, maliyetler fraksiyona göre yine uygulanır).
3. **TOC üst bilgileri:** yerelleştirilmiş Polestar başlıkları çıkarıldı, kaynak ve lisans notu eklendi.
4. `PACK.json` yalnızca kaynak kaydı olarak korunmuştur; içindeki özet değerleri (SHA-256) bu değişikliklerden sonra
   artık dosyalarla eşleşmez ve oyun içinde kullanılmaz.

Orijinal başlıklar (`Copyright (C) 2026 Cillian Berragan`, `Copyright (c) 2026 The Polestar authors`) ve
GPL notları **hiçbir dosyada silinmemiştir**.

## Kurulum / Installing

Bu üç klasör oyunun `Interface\AddOns` klasöründe **üst düzey** klasörler olarak durmalıdır (oyun iç içe klasörlerdeki
eklentileri yüklemez). Depodan kurarken `tools/link_nav_addons.ps1` bunları depo klasöründen AddOns'a bağlar (junction);
elle kuruyorsan üç klasörü AddOns'a kopyala. Eklenti gerektiğinde yüklenir (`LoadOnDemand`); ForeverTrail ilk rotada yükler.
