# Oturum özeti (ForeverTrail, `v0.2-dev`)

Bu dosya, çalışmaya kaldığımız yerden devam etmek için yazıldı. Önce **"Hızlı başlangıç"** ve **"Yarın yapılacaklar"** bölümlerini oku.
Ayrıntılı mimari için `CLAUDE.md`, kullanıcıya dönük anlatım için `README.md` var; burada tekrar etmiyorum.

## Hızlı başlangıç

- **Proje:** ForeverTrail, WoW Forever (1.60.1, Interface 16001) için Lua görev rehberi. Arayüz ve README Türkçe; yeni arayüz metinleri de Türkçe olmalı.
- **Dal:** geliştirme `v0.2-dev` (GitHub: `efeozgur/forevertrail`). `main` eski sürümde ve dokunulmadı.
- **Kullanıcı:** Türkçe konuşuyor, **acele ettirmiyor**, "hatasız teslim" istiyor, anlaşılmayan yerde **soru sorulmasını** istiyor. Polestar'a benzeyen, ferah, modern bir arayüz istiyor. Ekran görüntüsü paylaşıyor (`C:\Users\ahmet\Desktop\PoleFoto`).
- **Testler (oyun gerekmez):** `pip install lupa`, sonra `python tools/run_tests.py` (tek test: `python tools/run_tests.py roads map`). Şu an **31 test, hepsi geçiyor**. `tests/ingame_sim.lua` oyunu taklit eder.
- **Çalışma düzeni:** uygula, lupa ile test et, **mutasyon kontrolü yap** (düzeltmeyi bozunca test düşmeli; birkaç kez testler hiçbir şey sınamıyordu), commit + push, kullanıcıya oyunda kontrol listesi ver, ekran görüntüsü iste.
- **Yeni bilgisayar kurulumu:** README'deki "Yeni bir bilgisayara kurulum" bölümü. Oyun **yeni dosyaları yalnızca tamamen kapanıp açılınca yükler, `/reload` yetmez** (oyun içinde `/ftrail debug` "Parçalar: hepsi yüklü." demeli, eksik varsa kendisi uyarır).

## Araç tuzakları (zaman kaybettirdi, tekrar yaşama)

1. **Bash heredoc ters eğik çizgileri yutar.** `Interface\\X` yolları ve `'\n'` içeren kodu heredoc ile yazma; **Write aracıyla betik dosyası yaz** (içinde `chr(92)` kullan ya da doğrudan yaz), sonra çalıştır. Kontrol: tek ters eğik çizgili `'Interface\X` yolu **0** olmalı:
   `grep -rnE "'Interface.[A-Za-z]" --include=*.lua UI Map Guide Core Helpers | grep -v "Interface\\\\\\\\"`
2. Dosyalar **CRLF**; betikler normalize edip geri yazar. Edit aracı Türkçe karakterle güvenilir.
3. Windows'ta Bash'in `/tmp` yolu Python'unkiyle aynı değil; Python'a dosyayı Windows yoluyla ver.
4. `Helpers/Upgrade.lua` `GetItemInfo`'yu yükleme anında yakalar; sim'de sonradan değiştirmek işe yaramaz (sim `ITEMINFO` dağıtıcısı kullanır).
5. Test düzeneğinde `C_Map.GetMapInfo`, `CreateVector2D`, `GetQuestID` gibi API'ler taklit edilmeli; unutulursa gerçek oyunda olan bir şey testte hata verir.

## Bu oturumda yapılanlar (en yeniden eskiye)

**Rota ve harita**
- **Şehir içi / komşu harita hedefleri:** oyuncu şehir dışındayken (Durotar 1411) hedef şehir haritasındaysa (Orgrimmar 1454) ok, minimap ve harita susuyordu. Artık dünya koordinatlarıyla çevriliyor: `FT.ToWorld/FromWorld/ProjectToMap/ProjectStep` (`Map/Roads.lua`). Ok önce uçuş/giriş ipucunu dener, olmazsa projeksiyon, olmazsa "Başka bölge". Dünya haritası oyuncuyu hedef haritasına çevirir (0-1 dışı olabilir, simge gizlenir), çizgi tuvale kırpılır (`clipToCanvas`). Farklı kıtalar yine nil.
- **Harita hedef adımın haritasına geçer:** adım değişince (rehber seçilince, ilerleyince) açık harita bir kez o haritaya geçer (`switchedKey`). Eskiden yalnızca koordinatsız adımlarda geçiyordu.
- **`FT.SelectNearest`** (ok sağ tık, "En yakın" düğmeleri) artık seçili bölge rehberinde kalır, yapılmış/atlanmış adımları saymaz; eskiden günlük rehberine geçip rehberi siliyordu.
- **Kıvrımlı rota (`Map/Roads.lua`, `FT.CurrentRoute`):** kaynak sırası 1) `ForeverTrail_Nav` yürüme yönlendiricisi, 2) yürüdüğün yollardan öğrenilen ağ (`ForeverTrailData.roads`, A*), 3) düz çizgi. Çizim: `Map/Minimap.lua` (`drawRoute`, **üst çerçevede**: Minimap'in kendi katmanına konan çizgiler oyunda görünmüyordu) ve `Map/Map.lua` (çok parçalı, parıltılı çizgi + akan ışıklar). `/ftrail yolbilgi` aktif kaynağı gösterir.
- **`ForeverTrail_Nav`, `_Nav_EK`, `_Nav_Kalimdor`** (repo kökünde, ~70 MB): **Polestar_Nav 0.4.2.2'nin değiştirilmiş GPL-3.0 kopyası**, yeniden adlandırıldı, Polestar bağımlılığı kaldırıldı (`ForeverTrail_NavEngine` global'i, `walkLevel` **asla gönderilmez** çünkü sıkı iş Polestar'ın tehlike tablosunu ister). Telif başlıkları, `LICENSE`, `CREDITS.md`, `NOTICE.md` **silinmemeli** (`tests/navpack.lua` kontrol eder). Oyun yalnızca üst düzey klasörleri yüklediği için `tools/link_nav_addons.ps1` bunları AddOns'a junction olarak bağlar (bu bilgisayarda bağlı; **işyerinde yeniden bağlanmalı**). Harita verisi Leffe'nin çalışmasından; Polestar "izniyle" diyor, üçüncü kişilere dağıtım izni belgede yazmıyor: **hukuki belirsizlik kullanıcıda**, kendisi sorumluluğu kabul etti.
- **Yolculuk kartı (`UI/RouteCard.lua`):** `FT.customTarget` başka haritadaysa simgeli (`Media/route_*.tga`, `tools/make_route_icons.py` üretir), animasyonlu adım kartı; sohbete yazmaz.

**Rehber ve otomasyon**
- **Otopilot (`Guide/AutoPilot.lua`):** bölgeye girince bölge rehberi **önerir** (`FT.SuggestGuide`, `FT.ShowChoice` penceresi; oturumda ret + iki ret = kalıcı), rehber sırasını izler ama hedeften >400 yd uzaklaşıp 160 yd içinde yapılabilir adım varsa oraya **atlar**, atlanan adımlar rehber bitmeden geri gelir (`FT.NextPendingStep`; elle "Atla" dediklerin gelmez, `ForeverTrailCharacter.skipped`), NPC'de **yalnızca rehber görevleri** otomatik alınır/teslim edilir (`FT.GuideAllows`, `Helpers/Assist.lua`), ödülde sınıfa göre en iyisi seçilir. Ayarlar: `guideSuggest`, `autopilot`, `autoquestAll`. Bunlar kullanıcının verdiği cevaplardır (öner ve sor / rehber sırası + yakına atla / yalnızca rehber görevleri / en iyi ödül).
- **Rehber sekmesi (`UI/GuideTab.lua`):** görev penceresinde ilk sekme: NPC adı, bölge, "Görevi al “ad”", açıklama, durum/XP, yolculuk (süre, mesafe, simgeli adımlar), "Sonra: NPC", "Yapılacaklar", tempo (XP/sa, seviyeye kalan süre), ilerleme çubuğu, Atla/Harita. Karta tıklayınca harita açılır. Hub'daki Rehber paneli de aynı bilgiyi kullanır (`Guide/StepInfo.lua`: `FT.StepInfo/StepNpc/NextStop/PendingTurnIns/Pace`).
- **Bölge rehberleri (`Guide/AutoGuide.lua`, `UI/GuidePicker.lua`):** görev veritabanından, ırk/sınıf/seviyeye göre otomatik üretilen 10 seviyelik pencereler; `/ftrail bolge`. Adım kimlikleri sabit (`a/o/t<questId>`).
- **Hub sayfaları** Görevler (`UI/Suggestions.lua`) ve Yerler (`Map/Places.lua`): Kit sekmeleri, kaydırılabilir iki satırlı liste.
- **Daha iyi eşya "Tak" hatası düzeltildi** (`FT.EquipFromBag`: sonucu doğrular, ikinci yöntemi dener, bağlanma onayını kabul eder, başarısızsa tekrar önermez).
- **Hub sürüklenebilir:** Hub'a alınan sayfalar fareyi yutuyordu.
- **Yüklenmeyen parça uyarısı** (`FT.CheckModules`, `Core/Diagnostics.lua`).

**Daha önceki oturumlardan (özet):** klasör düzeni, Kit bileşen katmanı, Hub, görev penceresi (Görevlerim/Alınabilir), yeni listeler, modern araç ipuçları, Rehber paneli yeniden tasarımı, renk şemaları, kurulum sihirbazı.

## Oyunda henüz doğrulanmayanlar (gerçek istemci)

Bunların hepsi lupa testleriyle sınandı ama **oyunda görülmedi**; kullanıcıdan geri bildirim bekliyoruz:
- `ForeverTrail_Nav` gerçek harita verisiyle yol arıyor mu (LoadAddOn, parça yükleme, `Find` sonucu). Testte veri açma API'si (`C_EncodingUtil`) yok.
- `C_Map.GetMapPosFromWorldPos` harita dışı noktaları 0-1 dışı değerle döndürüyor mu (projeksiyon buna dayanıyor).
- Minimap'te sarı rota çizgisi görünüyor mu (üst çerçeve düzeltmesinden sonra).
- Rehber sekmesinin yerleşimi, yolculuk kartı, öneri penceresi, `route_*.tga` simgeleri.
- Kullanıcının son gerçek durumu: Orgrimmar rehberi seçili, zeplin kulesinde (Durotar 1411); beklenen: ok Thatog'a döner, harita Orgrimmar'a geçer, çizgi şehir kenarından girer. **İlk iş: sonucu sor, `/ftrail debug`, `/ftrail yolbilgi`, `/ftrail hata` çıktılarını iste.**

## Yarın yapılacaklar

1. Kullanıcıdan yukarıdaki doğrulamaların sonucunu al; sorun varsa `/ftrail debug` + `/ftrail yolbilgi` çıktısından ilerle.
2. **Kalan Polestar tarzı arayüz sayfaları:** Ansiklopedi, Sınıf, Meslekler, Araçlar, Ayarlar iç düzeni; pop-up ve bildirimler; Hedef kartı iç düzeni.
3. Ayarlar sayfasına düğme eksikleri: `roadsNav`, `roadsLearn`, `minimapRoute`, `routeCard` (şu an yalnızca `ForeverTrailSettings` anahtarı olarak var).
4. "Rota oluştur" düğmesi hâlâ günlük görevlerinden rota çıkarıyor; bölge rehberi seçiliyken rehbere göre çalışması önerildi (kullanıcıya soruldu, cevap yok).
5. Yolculuk başlığındaki "~N dk" yazısını "uçuş ~N dk" yapma önerisi (RouteCard'da yapıldı, Panel/GuideTab başlığında değil; onay bekliyor).
6. Temizlik: Settings.lua'da ölü `items` listesi, eski Tracker satır çizimi, kullanılmayan Questie seçenek penceresi.
7. README tazele; sürümü 0.2.0 yapıp `v0.2-dev`'i `main`'e birleştir (kullanıcı onayıyla).

## Bilinen sınırlar

- Rota, `ForeverTrail_Nav` yoksa ya da yol bulamazsa öğrenilmiş yola, o da yoksa düz çizgiye düşer (bilerek, hata vermez).
- Farklı kıtalardaki hedefler hâlâ "Başka bölge" (zeplin/gemi/uçuş gerekir); yalnızca yolculuk kartı adımları gösterir.
- Otopilot "yapılabilir" adımı günlük durumu ve ön koşullardan çıkarır; seviyesi yetmeyen ya da ön koşulu bitmemiş görevin alma adımı geri çağrılmaz.
- `Questie/` ve `QuestieDB/` `.gitignore`'da (lisans), bu klasörlerde yok; ayrı yüklenen eklentiler.
- GitHub'da olmayanlar: oyun ayarları ve öğrenilen yollar (`WTF\...\SavedVariables\ForeverTrail.lua`), ayrı eklentiler.

## Önemli dosyalar (hızlı harita)

| Alan | Dosya |
|---|---|
| Rota çekirdeği, dünya çevirisi, Nav motoru bağlantısı | `Map/Roads.lua` |
| Dünya haritası çizgisi/animasyonu, harita geçişi | `Map/Map.lua` |
| Minimap rotası ve işareti | `Map/Minimap.lua` |
| Ok | `UI/Arrow.lua` |
| Otopilot, rehber önerisi, görev kısıtı | `Guide/AutoPilot.lua`, `Helpers/Assist.lua` |
| Bölge rehberi üretimi ve seçici | `Guide/AutoGuide.lua`, `UI/GuidePicker.lua` |
| Adım bilgisi, tempo | `Guide/StepInfo.lua` |
| Rehber sekmesi, görev penceresi | `UI/GuideTab.lua`, `UI/QuestDock.lua` |
| Yolculuk kartı | `UI/RouteCard.lua` |
| Motor (adım ilerletme, atlama) | `Core/Engine.lua` (`FT.Advance(auto)`) |
| Testler | `tests/*.lua`, çalıştırıcı `tools/run_tests.py` |
| Nav GPL kopyası | `ForeverTrail_Nav*/`, bildirim `ForeverTrail_Nav/NOTICE.md` |
