# ForeverTrail

**World of Warcraft: Forever için kapsamlı görev rehberi, yön oku, harita ve oyun yardımcısı eklentisi.**

ForeverTrail, görev günlüğünü okuyup sana o an *ne yapman gerektiğini* ve *nereye gitmen gerektiğini* gösterir: yön oku, harita işaretleri, mini harita, görev takip kutusu, alınabilir görevler listesi, rota planı, sınıf/yetenek ve meslek yardımcıları, çanta ve satıcı otomasyonu ve daha fazlası. Görev veritabanı eklentinin içine gömülüdür; Questie gibi başka bir eklenti kurulu olmasa da çalışır, kuruluysa onlarla uyumlu çalışır.

| | |
|---|---|
| Hedef istemci | WoW Forever 1.60.1 (Interface `16001`) |
| Sürüm | 0.1.0 (prototip) |
| Dil | Türkçe arayüz (WoWTR kuruluysa görev adları ve açıklamaları da Türkçe) |
| Lisans | GPL-3.0-or-later (bkz. [Lisans](#lisans-ve-teşekkürler)) |
| Komut | `/ftrail` |

> **Durum notu.** Bu belge kodu ve geliştirme geçmişini temel alır. Kod Lua testleriyle ve sahte (taklit) bir oyun ortamıyla sınanmıştır; her özellik gerçek Forever istemcisinde ayrıntılı doğrulanmış değildir. Bilinen sınırlar için [Bilinen sınırlar](#bilinen-sınırlar-ve-doğrulama-durumu) bölümüne bakın.

---

## İçindekiler

1. [Öne çıkanlar](#öne-çıkanlar)
2. [Kurulum](#kurulum)
3. [Hızlı başlangıç](#hızlı-başlangıç)
4. [Özellikler](#özellikler)
   - [Rehber paneli ve görev günlüğü](#1-rehber-paneli-ve-görev-günlüğü)
   - [Yön oku, hedef kartı ve özel hedefler](#2-yön-oku-hedef-kartı-ve-özel-hedefler)
   - [Harita ve mini harita](#3-harita-ve-mini-harita)
   - [Haritada "Yol sor" paneli](#4-haritada-yol-sor-paneli)
   - [Görevler (görev takip kutusu)](#5-görevler-görev-takip-kutusu)
   - [Alınabilir görevler kutusu](#6-alınabilir-görevler-kutusu)
   - [Görev ansiklopedisi, görev bilgisi ve XP](#7-görev-ansiklopedisi-görev-bilgisi-ve-xp)
   - [Rotalama](#8-rotalama)
   - [Sınıf, yetenek ve meslekler](#9-sınıf-yetenek-ve-meslekler)
   - [Çanta, satıcı ve ekipman](#10-çanta-satıcı-ve-ekipman)
   - [Uyarılar ve yardımcılar](#11-uyarılar-ve-yardımcılar)
   - [Otomatik işler](#12-otomatik-işler)
   - [Yerler, uçuş noktaları ve meslek düğümleri](#13-yerler-uçuş-noktaları-ve-meslek-düğümleri)
   - [Görünüm, düzen ve temalar](#14-görünüm-düzen-ve-temalar)
   - [Ayarlar, profiller ve yedekler](#15-ayarlar-profiller-ve-yedekler)
   - [Janti](#16-janti)
5. [Komutlar](#komutlar)
6. [Tuş atamaları](#tuş-atamaları)
7. [Ayarlar sekmeleri](#ayarlar-sekmeleri)
8. [Veri kaynakları](#veri-kaynakları)
9. [Diğer eklentilerle uyum](#diğer-eklentilerle-uyum)
10. [Kayıtlı veriler](#kayıtlı-veriler-savedvariables)
11. [Mimari (geliştiriciler için)](#mimari-geliştiriciler-için)
12. [Rehber yazma](#rehber-yazma)
13. [Testler](#testler)
14. [Bilinen sınırlar ve doğrulama durumu](#bilinen-sınırlar-ve-doğrulama-durumu)
15. [Lisans ve teşekkürler](#lisans-ve-teşekkürler)

---

## Öne çıkanlar

- **Gömülü görev veritabanı:** WoW Forever'ın 6.078 görevi, 8.157 NPC'si, 1.652 nesnesi ve 6.302 eşyası eklentinin içindedir (QuestieDB verisinden dönüştürülmüştür). Forever'a özel 1.834 yeni görev "Yeni" etiketiyle işaretlenir. Dış eklenti gerekmez.
- **Yön oku:** TomTom benzeri sürüklenebilir ok; hedefe döner, mesafe ve tahmini varış süresini gösterir, bakış yönüne göre renk değiştirir (doğru yönde yeşil, ters yönde kırmızı).
- **Akıllı görev takibi:** Takip kutusu (Ayrıntılı / Liste / Tablo), "Alınabilir" kutusu (Kart / Liste / Tablo), her ikisinde ayar düğmesi.
- **Harita katmanı:** görev veren `!` ve teslim `?` işaretleri, hedef alanları, nadir yaratıklar, zindan girişleri, meslek düğümleri, kasaba hizmetleri, güzergah çizgileri.
- **"Yol sor" paneli:** Tamirci, han, uçuş ustası, banka, eğitmen vb. en yakın yeri bul, tek tıkla ok oraya yönelsin.
- **Rotalama:** Aktif görevleri en kısa sırayla numaralar; sürekli rota ile ok kendiliğinden sıradaki göreve geçer.
- **Görev bilgisi:** Ne yapılacağı, kim verir, XP ödülü (kesin ya da tahmini), eşya ödülü, görev zinciri.
- **Çanta ve satıcı otomasyonu:** gri eşyaları sat, otomatik tamir, çanta sıralama, daha iyi eşya önerisi.
- **Sınıf rehberi:** 9 sınıf için 27 seviye yetenek planı (kami-labs kaynaklı), seviye atlama kartı, meslek rehberi.
- **Canlı veri (isteğe bağlı):** QuestieDB eklentisi kuruluysa güncel veri ondan okunur; böylece oyun/Questie güncellemeleriyle ForeverTrail da güncel kalır.
- **Türkçe:** Arayüz Türkçe; WoWTR kuruluysa görev başlıkları ve açıklamaları da Türkçe.

---

## Kurulum

1. Bu klasörü oyunun eklenti dizinine `ForeverTrail` adıyla koyun:
   `World of Warcraft\_forever_\Interface\AddOns\ForeverTrail`
2. Yeni TOC dosyasının algılanması için oyunu **tamamen yeniden başlatın**.
3. Karakter seçim ekranında **AddOns** düğmesinden ForeverTrail'i etkinleştirin.
4. Oyuna girince ilk girişte kurulum sihirbazı açılır (Araçlar > Kurulum sihirbazı ile tekrar açılır).
5. Sorun olursa `/ftrail test` (uyumluluk testi) ve `/ftrail hata` (hata kaydı) çıktılarına bakın.

### İsteğe bağlı eklentiler

| Eklenti | Ne sağlar |
|---|---|
| **WoWTR** | Görev başlıklarını, hedef ve açıklama metinlerini Türkçe gösterir. Türkçe harflerin doğru görünmesi için WoWTR yazı tipi de kullanılır. |
| **QuestieDB** | Kuruluysa görev/NPC/nesne/eşya verisi oyunda ondan okunur (canlı veri). Yoksa gömülü kopya kullanılır. |
| **Questie** | Kuruluysa bölge ve XP verisi önce onun modüllerinden sorulur; çakışan özellikler (görev takibi, simgeler vb.) tekrar etmez. |
| **Queston Forever** | Kuruluysa ForeverTrail onun yaptığı işleri kapatır ve ayarlarını Queston'un ayar penceresine ekler. |
| **OneForAll** | Bu istemcide yetenek ağacı yalnızca `C_Traits` ile okunabildiği için, yetenek planı OneForAll'ın "Yetenek Ağaçları" sekmesine yönlendirilir. |

### Simge dosyaları hakkında (önemli)

Bu depo, lisansı belirsiz/"tüm hakları saklı" olan Questie simgelerini (`Media/Questie/`) **içermez**. Kendi bilgisayarınızda Questie simgelerini kullanmak isterseniz bu klasörü Questie'nin `Icons` klasöründeki `.blp` dosyalarından oluşturabilirsiniz (yalnızca kişisel kullanım). Klasör yoksa **Ayarlar > Simgeler > Simgeler** bölümünden **"Sade"** stilini seçin; eklenti bu durumda kendi (MIT lisanslı pfQuest) simgeleriyle çalışır.

---

## Hızlı başlangıç

- `/ftrail` ana pencereyi açar (Rehber, Görevler, Ansiklopedi, Sınıf, Meslekler, Yerler, Araçlar, Ayarlar sayfaları).
- **Ekranda kalıcı olanlar:** yön oku, sağda *Görevler* kutusu, solda *Alınabilir* kutusu, ikon şeridi (düğme çubuğu) ve minimap düğmesi.
- **Minimap düğmesi:** sol tık Rehber, sağ tık Araçlar, Shift + sağ tık Ayarlar.
- **Hedef seçmek için:** takip kutusunda bir göreve tıklayın, "Alınabilir" kutusunda bir göreve tıklayın, haritada **Ctrl + sol tık** yapın ya da `/ftrail git 45.2 60.1` yazın.
- **Haritayı açın (M)** ve alttaki/yandaki **"Yol sor"** düğmesiyle en yakın tamirci, han, uçuş ustası gibi yerleri bulun.
- Hiç komut yazmadan: ikon şeridi ve ana pencere her işlevi açar.
- Ayarlar: `/ftrail ayar` ya da ikon şeridinden.

---

## Özellikler

### 1. Rehber paneli ve görev günlüğü

- **Karakterimin görevleri:** Varsayılan canlı rehber, giriş yapılan karakterin görev günlüğünü okur. Eksik hedefleri ve teslim edilebilen görevleri günlük sırasıyla adımlara çevirir (kabul → hedef → teslim). Henüz alınmamış devam görevleri listeye girmez.
- **Adım türleri:** `accept` (al), `objective` (hedef), `turnin` (teslim), `location` (konum), `manual` (elle onay).
- **Gezinme:** Önceki/Sonraki ile adımları incelersiniz. *Aktif adım* ile *görüntülenen adım* ayrıdır: "Aktif yap" düğmesi görüntülenen adımı kaydeder; "Buradan sürdür" incelenen adımı aktif yaparak terk edilmiş göreve geri dönmenizi sağlar.
- **Rehber sayfasının düzeni:** Üstte açık rehber ve "Rehber seç"; altında adım türü ve ilerleme çubuğu; büyük kartta şimdi ne yapılacağı; onun altında durum satırı. Düğmeler üç grupta: **Adımlar** (Önceki, Sonraki, Aktif yap, Buradan sürdür), **Yol ve görevler** (Haritada göster, En yakın, Rota oluştur, Öneriler), **Diğer** (Ayarlar, Otomatik ilerle). Her düğmenin üzerine gelince ne yaptığı yazar. "Küçük panel" yalnızca üst bölümü bırakır.
- **Otomatik ilerle:** Açıkken tamamlanmış adımları atlar ve güncel hedefi gösterir. Kapatılabilir.
- **Ayrı rehberler:** Sabit rehberler (örn. demo) ve özel rehberler arasında geçiş yapılabilir; rehberler `FT.RegisterGuide` ile kaydedilir ([Rehber yazma](#rehber-yazma)).
- **Kalıcılık:** Hesap genelinde panel konumu ve ayarlar; karakter başına rehber ve adım (`stepId`) kaydedilir.
- **Hedef adımı konuma göre güncelleme:** Otomatik çözülen adımlarda hedef, 3 saniyede bir oyuncuya en yakın noktaya yeniden seçilir (elle yazılmış rehber koordinatları sabittir). Ayarlardan kapatılabilir.
- **Olay işleme:** `QUEST_LOG_UPDATE` ve bölge olayları 0,3 sn birleştirilir; görev günlüğü kare başına taranmaz. Görevin koordinatı yalnızca görüntülenen adım için ve 2 sn aralıkla çözülür.

### 2. Yön oku, hedef kartı ve özel hedefler

**Yön oku**
- Sürüklenebilir, hedefe dönen ok; yanında hedef adı, koordinat, mesafe (yd) ve tahmini süre.
- Renk bakış yönüne göre değişir (doğru yön yeşil, ters yön kırmızı); renk modu ayarlanabilir (yöne göre / tema / adım türü).
- Hedefin 15 yd yakınında "Vardın!" yazar, ses çalar ve (görev bölgesi için) bir kez uyarır.
- **Etkileşim:** Sol tık haritayı açar; sağ tık en yakın adıma geçer; `/ftrail kilit` okun taşınmasını kilitler.
- **Başka bölge:** Hedef başka haritadaysa ok önce uygun ara hedefe yönlendirir: bir giriş (zindan, bina), uçuş ustası, zeplin ustası ya da yol tarifi; mümkün değilse "Başka bölgede: …" yazar.
- **Giriş noktası:** Hedef bir zindan/binanın içindeyse ok önce girişe götürür, girince asıl hedefe yönlendirir.
- **Ara noktalar (yol çizme):** Haritada **Alt + sol tık** ara nokta ekler/siler (kapı, merdiven, geçit), **Ctrl + sol tık** son hedeftir. `/ftrail geri` son noktayı geri alır, `/ftrail ara` yolu temizler. Yol karaktere kaydedilir; ok noktaları sırayla izler ("Ara nokta 2/5 geçildi"). Haritada numaralı noktalar (geçilen gri, kalan mavi), mini haritada çizgi görünür.
- **Görev eşyası düğmesi:** Kullanılacak görev eşyası varsa okun altında tıklanabilir düğme çıkar (bekleme süresiyle birlikte).
- **Ölünce:** Ok ve harita cesede yönlenir; dirilince kalkar. Ölüm danışmanı ceset mi ruh iyileştirici mi diye öneri verir.

**Hedef kartı**
- Ana pencerenin Rehber sayfasında açılır. Seçili hedefin eşya ikonu ya da NPC/yaratık 3B modeli, adı, türü (Yaratık/Nesne/Eşya/Görevi veren/Teslim NPC'si), seviye aralığı, göründüğü bölgeler ve nokta sayısı.
- Görevin tüm hedefleri için "3/7" sayacı ve ilerleme çubuğu; hedef ilerleyince kart parlar ve ses çalar.
- Görev durumuna göre açıklama: alınmamışsa hikâye, aktifse hedef metni, hazırsa teslim metni.
- Eşya toplama hedeflerinde eşyayı düşüren yaratığın modeli gösterilir.

**Özel hedef**
- Haritada **Ctrl + sol tık** ya da `/ftrail git 45.2 60.1` (bulunduğunuz haritada, yüzde koordinat).
- Özel hedef görev hedefinin yerini alır (ok, harita işareti, mini harita). Varınca ya da `/ftrail iptal` ile kalkar; karakter başına saklanır.
- Başka birinin harita işaretini değiştirmez/silmez; kullanıcı waypoint'ine dokunulmaz.

### 3. Harita ve mini harita

**Dünya haritası katmanı**
- **Görev veren `!` / teslim `?` işaretleri:** alınabilir görevler sarı `!`, teslime hazır görevler `?`; seviyenin altındakiler gri `!`. Aynı noktadaki tüm görevler tek ipucunda.
- **Hedef bölgeleri:** Günlükteki görevlerin yaratık/nesne/eşya düşüren yaratık noktaları gömülü veriden bulunur ve görev renginde yumuşak alanlar ve türe göre simgelerle (öldür, topla, nesne, konuş) çizilir. Üzerine gelince görev adı ve ilerleme görünür. Yoğun yaratık bölgeleri daha koyu çizilir.
- **Görünüm modu** (haritadaki "Görünüm" düğmesi): Tüm görevler / Takip edilen / Yalnızca odak / Bölgeler kapalı.
- **Rota çizgisi ve numaralar:** Ardışık adımlar ince çizgiyle birleşir; akıllı rotada görevler numaralanır.
- **Güzergah noktaları:** Oyuncudan hedefe akan güzergah noktaları çizilir.
- **Kasaba işaretleri:** tamirci, han, uçuş ustası, banka, müzayede, ahır, posta, sınıf eğitmeni (meslek eğitmenleri isteğe bağlı).
- **Zindan girişleri**, **nadir yaratıklar** (üzerine gelince 3B görsel, isteğe bağlı), **meslek istasyonları** (örs, ocak, simya masası), **bitki/maden düğümleri**.
- **Grup:** Grubunuzda da ForeverTrail varsa grup üyelerinin görev hedefleri haritada mavi noktalarla görünür.
- **Odak:** Görev kutusunda sağ tık bir göreve odaklanır; diğer görev işaretleri soluklaşır. Odak aynı zamanda oku o göreve yöneltir.
- **Gezgin NPC yolları:** Yürüyen görev NPC'lerinin yolu mavi çizgiyle.
- **Taşıma:** Dünya haritası üst kenarından sürüklenerek taşınır (yeri kaydedilir); sağ tık varsayılan yer. Kıta haritasında simgeleri gizleme seçeneği vardır.
- **Performans:** Sabit katmanlar yalnızca veri/ayar/harita değişince çizilir; oyuncu, ok ve güzergah akıcı güncellenir.

**Mini harita**
- Hedef işareti, kenara yakın uzak hedeflerde kenarda soluk gösterilir; mini harita dönüşü ve yakınlaştırma düzeyi hesaba katılır.
- Yakındaki hedef kümeleri, nadir yaratık yıldızları, uzak simgelerin soldurulması, kenarda uzak hedefe ok, yol çizgisi.

### 4. Haritada "Yol sor" paneli

Dünya haritasını açınca haritanın **sağında** (yer yoksa solunda, tam ekranda harita içinde) dikey bir panel açılır; panelin üstündeki düğmeyle sağa/sola taşınır. Harita üstündeki **"Yol sor"** düğmesiyle açılıp kapanır.

1. Bir **tür** seçin ya da **arama** kutusuna yazın.
2. Listeden bir yere **tıklayın**.
3. Ok, harita ve mini harita sizi oraya götürür.

- **Türler (18):** Hepsi, Görev al, Teslim, Tamirci, Satıcı, Han, Banka, Uçuş, Eğitmen, Sınıfım, Meslek, Müzayede, Ahır, Evcil, Zindan, Nadir, Posta, Kayıtlarım. Her düğmenin üzerine gelince ne işe yaradığını anlatan bir açıklama çıkar.
- **Satırlar:** Her satırda renkli tür şeridi, ad, alt başlık ve uzaklık (yd). Üzerine gelince yer haritada parlar ve ayrıntı kutusunda görünür; tıklayınca oka hedef olur ve sohbete "Yol: … (mesafe)" yazılır.
- **Ayrıntı kutusu:** Ad, tür, bölge ve koordinat, uzaklık, en yakın uçuş ustası, görev durumu. Düğmeler: **Yol göster**, **Haritada gör**, **Kaydet** (Kayıtlarım'a ekler).
- **Her yer:** Açıkken arama tüm haritalarda NPC ve zindanlar için yapılır (en az 3 harf).
- **Hedef satırı:** Okun şu an neye yöneldiğini ve "Hedefi kaldır" düğmesini gösterir.
- **Rota planı** düğmesi hedefe adım adım planı verir.
- Panel, harita genişliğine ve yüksekliğine göre sayfa başına satır sayısını ayarlar.

### 5. Görevler (görev takip kutusu)

Ekranın sağ kenarında, görev günlüğündeki tüm görevleri gösteren kutu. Başlıkta görev sayısı; altında seviye ve dinlenmiş XP özeti, ince XP çubuğu (mavi = dinlenmiş).

**Gösterim biçimleri** (kutudaki **Ayar** düğmesinden ya da Ayarlar > Takip'ten):
- **Ayrıntılı** *(varsayılan)*: bölge başlıkları, görevler, her hedef için `3/5` sayacı; Questie benzeri ya da kutulu görünüm.
- **Liste:** Görev başına tek satır, sağda toplam ilerleme (`5/12` ya da *Teslim*).
- **Tablo:** Başlıklı sütunlar — Sv | Görev | İlerleme | Mesafe (mesafe sütunu kapatılabilir).

**Ayar penceresindeki seçenekler:** gösterim biçimi, görev sayısı (6/8/12/20), sıralama (Durum, Bölge, Yakınlık, Seviye, % bitmiş), satır sıklığı (Sıkışık/Normal/Ferah), bölge başlıkları, seviye ve zorluk rengi, tamamlanan görevleri göster, tamamlanan hedefleri gizle, mesafe sütunu. Ayarlar > Takip sayfasında ayrıca görünüm (Questie/Kutulu/Şeffaf), hedef rengi, oturum hedefi, boyut ve yazı boyutu vardır.

**Satır etkileşimi**
- **Sol tık:** Görevi seçer, oku o göreve yöneltir (eski özel hedefi ve yol noktalarını kaldırır) ve haritayı açar.
- **Sağ tık:** Odak (◆).
- **Shift + tık:** Görevi daralt/genişlet. **Ctrl + tık:** Sabitle (•). **Alt + tık:** Bir sıra yukarı taşı.
- Üzerine gelince: hedef, XP (kesin ya da tahmini), teslim yeri ve uzaklık.

**Diğer davranışlar:** Biten görevde "Teslim: NPC" satırı; bölge başlığına tıklayınca bölge daralır; yeni Forever görevleri "Yeni" etiketi taşır; ortak görevler `+n ortak`, grup görevleri `Grup N` etiketi alır; görev eşyası düğmeleri; "+1" efekti; yüzde halkası; savaşta ve zindanda otomatik daraltma (isteğe bağlı). Rota numaraları ve tahmini süre görev kutusunda gösterilir. "Görev tamamlandı" afişi çıkar.

### 6. Alınabilir görevler kutusu

Ekranın solunda, **bulunduğunuz bölgede alabileceğiniz** görevler; seviye, ırk/sınıf ve ön koşula göre süzülür.

**Gösterim biçimleri:** **Kart** *(varsayılan, iki satır: görev + veren)*, **Liste** (tek satır), **Tablo** (Sv | Görev | Veren | Mesafe).

**Ayar penceresi:** gösterim biçimi, görev sayısı (5/7/10/15), sıralama (Yakınlık/Seviye/Ad), görev vereni göster (Kart), düşük seviyeli (gri) görevleri gizle, kutuyu göster/gizle.

**Ayrıntılı ipucu** (üzerine gelince): başlık ve zorluk rengi, "Forever'a özel yeni görev" etiketi, görev türü (tekrarlanabilir, zindan, baskın, PvP, etkinlik), **ne yapılacağı** (hedef metni; WoWTR varsa Türkçe), görev veren + bölge + koordinat, farklı teslim yeri, uzaklık, gerekli ve görev seviyesi, **XP ödülü** (seviyenin yüzde kaçı olduğuyla birlikte), eşya ödülleri, zincirde önceki ve sonraki görev. Tıklayınca ok o göreve yönlenir.

### 7. Görev ansiklopedisi, görev bilgisi ve XP

- **Ansiklopedi** (`/ftrail ansiklopedi`): 6.078 görevde arama; süzgeçler *Tümü / Alınabilir / Günlükte / Bitti / Forever yeni / Bu bölge*; görev durumu, veren, XP ve eşya ödülü; "Yol göster" (gerekirse önce ön koşul görevine).
- **Ön koşul bulucu:** Alınamayan görev için nedeni söyler (seviye, ırk/sınıf, eksik ön koşul, alternatif görev).
- **XP verisi:** Kesin XP, Questie XP modülünden ya da gömülü `DataXP.lua` kayıtlarından (QuestieDB oyuncu kayıtlarından derlenmiş) gelir. Kaydı olmayan görevlerde aynı seviyedeki görevlerin ortancası **"~620 XP (tahmini)"** olarak işaretlenir. Gömülü veride yaklaşık 4.660 görevin XP'si kesin, 1.400 kadarı tahminidir.
- **Görev bağlantısı:** Sohbette görev linkine tıklayınca seviye, veren NPC ve ilerleme görünür.
- **Görev yardımcısı** (`/ftrail gorev`): seçili görev için adım adım ipuçları.
- **Görev okuma penceresi:** Görev alırken büyük yazılı Türkçe okuma penceresi (otomatik alma açıkken görünmez).

### 8. Rotalama

- **Otomatik rota** (`/ftrail rota`): Günlükteki görevleri bulunduğunuz yerden başlayıp en yakın komşu sırasıyla tek rehberde dizer; aynı hedefi isteyen görevler arka arkaya gelir.
- **Akıllı rota:** Aktif görevleri en kısa sırayla numaralar (haritada numara + çizgi, görev kutusunda halkanın içinde) ve toplam yürüme süresini hesaplar; grupla ortak görevler öne alınır.
- **Sürekli rota** (`/ftrail surekli`, varsayılan kapalı): Görev alınınca/teslim edilince, hedef tamamlanınca ya da hedefe varılınca ok kendiliğinden sıradaki en verimli göreve geçer.
- **Sıradaki görev** (`/ftrail sonraki`): Yakındaki görevleri XP ve mesafeye göre puanlayıp en iyisine yol gösterir.
- **En yakın adım** (`/ftrail yakin`): Bulunduğunuz haritada konumu bilinen en yakın adımı seçer.
- **Rota planı** (`/ftrail planla`): Hedefe adım adım plan: dışarı çık, uçuş/zeplin/gemi, giriş, varış.
- **Uçuş ve zeplin:** Hedef uzaksa uçuş önerisi; Horde için zeplin ustası, Alliance için yazılı gemi tarifi (gemi iskelesi verisi yoktur). Uçuş süreleri uçtukça öğrenilir; uçarken kalan süre çubuğu çıkar.
- **Kaçırılan görevler:** Bulunduğunuz bölgede alınmamış görevler. **Günlük temizliği:** gri görevler; günlük 18/20 olunca uyarı; dolunca en az verimli görevi bırakma önerisi.
- **Zindan rehberi** (`/ftrail zindan`): en yakın/içinde olduğunuz zindan, giriş (oku gösterir), görevler ve görev boss'ları.

### 9. Sınıf, yetenek ve meslekler

- **Sınıf sayfası** (`/ftrail sinif`): sınıfa özel uzmanlık kartları, **seviye atlama kartı** (yeni büyüler, sınıf görevi, evcil/form/totem/binek, avcı için evcilleştirilebilir hayvanlar), sınıf görevleri listesi (ırk/sınıf süzgeçli; tıklayınca ön koşul dahil yol gösterir).
- **Yetenek planı verisi:** 9 sınıf için 27 seviye yetenek dizisi (seviye 10–60, 51 puan; kaynak kami-labs.fr).
- **Not — yetenek ağacı:** Forever'da klasik yetenek API'si yoktur (ağaçlar `C_Traits` ile çalışır). Bu yüzden ForeverTrail yetenek planını kendisi uygulayamaz; **OneForAll** kuruluysa plan paneli onun "Yetenek Ağaçları" sekmesini açar (`/ftrail yetenek`). `/ftrail yetenekdebug` yetenek API'lerinin durumunu yazar.
- **Eğitmen hatırlatıcısı:** Seviye atlayınca yeni yetenek sayısı/maliyeti ve en yakın sınıf eğitmenine yol. Silah ustaları (`/ftrail silah`): hangi usta hangi silahı öğretir.
- **Meslekler** (`/ftrail meslek`): sınıfa göre meslek önerisi, meslek rütbeleri, en yakın meslek eğitmenine yol, yan meslekler; meslek penceresinin yanında "Puan için ne yapmalı?" (turuncu/sarı/yeşil tarifler, yapılabilir sayı, eksik malzeme); beceri sınırına gelince eğitmen uyarısı.
- **Bitki/maden:** Topladıkça düğüm yerleri kaydedilir; mesleğinize göre haritada renkli noktalar (yeşil bitki, mavi maden); artık puan vermeyen düğümler soluk.

### 10. Çanta, satıcı ve ekipman

- **Çöp (gri) eşya satışı:** Satıcı açılınca gri eşyalar satılır (satış değeri olmayanlar ve **görev eşyaları asla** satılmaz); satılacak eşyaların üzerinde altın işareti görünür. `/ftrail sat` elle satar ve satılacak bir şey yoksa nedenini söyler. Malzeme çantası da taranır.
- **Görev eşyalarını koruma:** Türü "Görev" olan eşyalar, günlükteki görevlerin hedef/kaynak eşyaları (gri bir "Kurt Eti" gibi) ve elle kilitlediğiniz eşyalar otomatik satılmaz; yine de satıcıya satılırsa satıcının geri alım listesinden **otomatik geri alınır**. `/ftrail gorevesya` çantadaki bu eşyaları ayrı bir pencerede listeler (üzerine gelince ipucu; **Shift + tık** eşyayı elle kilitler/açar). Ayar: Otomatik > "Görev eşyalarını koru". Çanta içinde ayrı bölüm oluşturmak oyunun çantalarını yeniden düzenlemeyi gerektirir, bunu eklenti yapamaz; liste pencerede tutulur.
- **Otomatik tamir:** Satıcıda, yeterli altın varsa tüm ekipman tamir edilir.
- **Otomatik toplama:** Ganimeti otomatik toplar.
- **Çanta ve banka düzeni:** `/ftrail duzen` çantayı, `/ftrail banka` bankayı sıralar (bankada "Düzenle" düğmesi; banka açılınca otomatik sıralama isteğe bağlı).
- **Daha iyi eşya** (`/ftrail esya`): Sınıfa göre stat puanı (Güç, Çeviklik, Zekâ, hasar/sn, zırh…) hesaplanır; yükseltme çıkınca yeni ve takılı eşya yan yana, yüzde ve stat farklarıyla gösterilir (Tak / Şimdi değil / Bir daha sorma). İsteğe bağlı: sormadan tak (kuşanınca bağlananlar yine sorulur). Eşya ipucunda takılı olanla ilvl farkı (yeşil ▲ / kırmızı ▼) görünür.
- **Çanta doluyken:** Yerdeki en değerli eşya için çantadaki en ucuz 3 eşya önerilir; seçileni atılır ve yerdeki alınır.
- **Görev ödülü danışmanı:** Birden fazla ödüllü görevde en iyi ödül yeşil parlar (isteğe bağlı otomatik seçilir ve sohbete yazılır). **Ekipman bulucu:** alınabilir/günlük görev ödüllerinde size yükseltme olanlar.
- **Eşya ipuçları:** "Görev için gerekli (0/1)", "Bu eşya bir görev başlatır", "Görev ödülü".

### 11. Uyarılar ve yardımcılar

- **Nadir yaratıklar:** Doğdukları yerler minimapte yıldızla görünür; 120 yd yakınlaşınca 3B görselli kart ve uyarı (yaratık başına bir kez; tekrar aralığı ayarlanabilir).
- **Görev yaratığı:** Hedeflenince/üzerine gelince ipucu satırı, isim plakasında simge ve `3/8` sayacı, hedef çerçevesi altında görev bandı. Görev yaratığının can barı görev renginde. **Eşya toplama görevlerinde** (ör. "8 Kurt Eti topla"), eşyayı düşüren yaratığın isim plakasında, hedef bandında ve ipucunda simge yerine **istenen eşyanın kendi resmi** yuvarlak, renkli halkalı çerçevede görünür. Ayar: Uyarılar > "Eşya görevlerinde yaratığın üstünde istenen eşyanın resmi".
- **Güvenli mod / tehlike uyarısı:** Elit ya da seviyenizin 3+ üstündeki hedefte kırmızı uyarı ve kafatası.
- **Dayanıklılık:** %25 altına inince uyarı ve kayıtlı tamirciye yol. **Avcı:** ok/mermi 200 altına inince uyarı. **Çanta:** 2 boş yere düşünce uyarı; kayıtlı satıcıya yol.
- **Ocak taşı danışmanı:** Tüm görevler teslime hazırken ocak taşının yerini ve bekleme süresini söyler.
- **Grup:** Grup ilerlemesi ("Grup: Ali 3/5"), mevcut adımı gruba yazma (`/ftrail paylas`), ilerlemeyi gruba duyurma (isteğe bağlı).
- **Oturum:** Oturum özeti (süre, görev, XP/saat, altın; `/ftrail ozet`, `/ftrail oturum`), oturum hedefi çubuğu (yarım/1/2 seviye), seviye süreleri, bilgi çubuğunda saatlik XP, kalan süre, dinlenmiş XP, dayanıklılık ve çanta boşluğu.
- **Görev geçmişi** (`/ftrail gecmisim`): gün gün alınan/teslim edilen görevler ve seviye atlamaları; `/ftrail gecmis` bugünün özeti; `/ftrail plan` XP/saat planı; `/ftrail seviye` seviye özeti.
- **Çeviri raporu** (`/ftrail ceviri`): Günlükte WoWTR Türkçe başlığı olmayan görevler.
- **Bölge değerlendirmesi:** Bölgeye girince "bana uygun mu?" ve daha uygun bölgeler.
- **Kolaylıklar (hepsi kapalı başlar):** Çağrı ve dirilmeyi otomatik kabul, lonca dışı düello engeli, uzak kamera, ekran parlamasını kapatma.

### 12. Otomatik işler

(Ayarlar > Otomatik)

- **Görevleri otomatik al/teslim et** (Shift basılıyken kapalı), **önerilen ödülü otomatik seç**, **yol açan görevleri otomatik bırak**.
- **Otomatik toplama**, **satıcıda çöp sat**, **satıcıda otomatik tamir**, banka açılınca otomatik düzenleme, çanta doluluk uyarısı.
- **Yetenek puanı hatırlatıcısı** ve isteğe bağlı otomatik puan verme (yetenek planı OneForAll'a bırakıldığı için bu istemcide sınırlıdır).

### 13. Yerler, uçuş noktaları ve meslek düğümleri

- **Yerler** (`/ftrail yerler`): *Uçuş, Hizmetler, Meslek, Kayıtlarım* sekmeleri; satıra tıklayınca ok oraya döner.
- **Otomatik öğrenme:** Satıcı, tamirci, banka, posta, müzayede, han, uçuş ustası ve eğitmenlerle konuştukça konumları kaydedilir; muhafıza yol sorduğunuzda gösterdiği yer hedef olur.
- **Uçuş noktaları:** Şehre girince uçuş noktası önerisi, keşfedilmemiş noktanın yakınından geçerken uyarı; veri oyunun taksi haritasından okunur.
- `/ftrail kaydet <ad>` bulunduğunuz yeri kaydeder. Yerler > Ara: günlük, rehber adımları, kayıtlı yerler ve düğümlerde arama.

### 14. Görünüm, düzen ve temalar

- **Tek pencere düzeni (Hub):** Rehber, Görevler, Ansiklopedi, Sınıf, Meslekler, Yerler, Araçlar ve Ayarlar tek ana pencerede; Esc ile kapanır, başlıktan sürüklenir.
- **İkon şeridi:** Rehber, Harita, Yakın, Yerler, Çanta, Ayarlar, Araçlar, Kilit düğmeleri (`/ftrail cubuk`).
- **Renk şemaları:** Sabit bir görünüm vardır; renkler 4 şemadan seçilir: **Gece** (varsayılan, koyu mürekkep + kehribar), **Grafit** (nötr gri + buz mavisi), **Orman** (koyu yeşil + yaprak yeşili), **Erik** (koyu mor + gül pembesi). Ayrıca **Sınıf rengi** ve renk seçicili **kendi temanız** vardır. Eski temalar (Aurora, Kozmik vb.) kodda durur ama menüde görünmez; kayıtlı eski tema ilk açılışta Gece'ye çevrilir.
- **Questie görünümü (varsayılan):** Harita ve minimapte Questie tarzı simgeler, zeminsiz görev kutusu, sade isim plakası simgesi, Questie düzeninde ayar penceresi. Eski görünümler Ayarlar'dan seçilir (Sade/Renkli simge, Kutulu/Şeffaf kutu).
- **Düzen modu** (`/ftrail yerlesim`): ızgara, sürükle-bırak; hazır düzenler (Varsayılan, Sade, Geniş ekran, HUD); `Konumları sıfırla`.
- **Sade görünüm**, **sessiz mod** (`/ftrail sessiz`), **küçük mod** (`/ftrail kucuk`), arayüz ölçeği, yazı boyutu, görev kutusu saydamlığı, yazı tipi (`/ftrail font`: WoWTR / Arial; Türkçe harfler için).
- **Savaş/zindan:** Gereksiz kutular otomatik gizlenir; zindana girince rehber önerilir.
- **Kurulum sihirbazı:** İlk girişte açılır (`/ftrail kurulum` ile yeniden). İlk adımda tek tıkla **Sade / Standart / Tam** kullanım düzeyi seçilir (Sade: yalnızca ok ve görev kutusu, daha az uyarı; Standart: eklentinin varsayılanları; Tam: tüm kutular ve uyarılar açık). Sonraki adımlar ok, yetenek, eşya, tema ve çanta ayrıntılarıdır; "Atla" ile bırakılabilir. Son adım "Nereden ne yapılır?" özetidir. Aynı düzey seçimi Ayarlar > Profil ve gelişmiş sayfasında da vardır.

### 15. Ayarlar, profiller ve yedekler

- **Ayarlar** (`/ftrail ayar`): soldaki kategori listesi ve sağda bölümlü içerik. [Ayarlar sekmeleri](#ayarlar-sekmeleri) bölümüne bakın.
- **Profiller** (`/ftrail profil`): ayarları adıyla kaydet/yükle/sil; yüklenen profil karakter için hatırlanır.
- **Ayar aktarma** (`/ftrail aktar`): ayarları metin olarak dışa/içe aktar.
- **Yedekler** (`/ftrail yedek`): günlük otomatik yedek, en son 5 tanesi saklanır.
- **Veri penceresi** (`/ftrail veri`): oynarken toplanan görev verisini dışa/içe aktarma.

### 16. Janti

Giriş, çöp satma, ölüm ve eşya giymede ekranın ortasında kısa bir şaka mesajı. `/janti on` ve `/janti off` ile açılıp kapanır.

---

## Komutlar

Ana komut `/ftrail` (argümansız: ana pencereyi açar/kapatır). `/ftrail yardim` komut listesini yazar.

| Komut | Ne yapar |
|---|---|
| `/ftrail` | Ana pencereyi aç/kapat |
| `/ftrail ayar` | Ayarlar |
| `/ftrail hizli` | Hızlı ayarlar penceresi |
| `/ftrail yardim` | Komut listesi |
| `/ftrail resetui` | Panel konumunu varsayılana döndür |
| `/ftrail debug` | İstemci sürümü ve aktif durumu yaz |
| `/ftrail test` | Uyumluluk testi ([VAR]/[YOK] listesi) |
| `/ftrail hata` | Kayıtlı hata listesi |
| `/ftrail arrow` · `card` · `track` | Yön okunu / hedef kartını / takip penceresini aç-kapat |
| `/ftrail yakin` | En yakın görev adımını seç |
| `/ftrail rota` | Otomatik rota oluştur |
| `/ftrail surekli` | Sürekli rotayı aç/kapat |
| `/ftrail sonraki` | Sıradaki en verimli görev |
| `/ftrail planla` | Rota planı |
| `/ftrail git 45.2 60.1` | Bulunduğun haritada özel hedef |
| `/ftrail iptal` | Özel hedefi kaldır |
| `/ftrail geri` · `ara` | Son yol noktasını geri al · yolu temizle |
| `/ftrail kilit` | Yön okunu kilitle |
| `/ftrail cubuk` | İkon şeridini aç/kapat |
| `/ftrail kucuk` | Küçük mod |
| `/ftrail sessiz` | Sessiz mod |
| `/ftrail yerlesim` | Düzen modu |
| `/ftrail yerler` | Yerler penceresi |
| `/ftrail kaydet <ad>` | Bulunduğun yeri kaydet |
| `/ftrail ansiklopedi` | Görev ansiklopedisi |
| `/ftrail gorev` (`yardimci`) | Görev yardımcısı |
| `/ftrail zindan` | Zindan rehberi |
| `/ftrail ekipman` · `esya` | Ekipman bulucu · daha iyi eşya ara |
| `/ftrail silah` | Silah ustaları |
| `/ftrail sinif` | Sınıf sayfası |
| `/ftrail yetenek` | Yetenek planı (OneForAll'a yönlendirir) / öneri |
| `/ftrail yetenekdebug` | Yetenek API tanısı |
| `/ftrail meslek` | Meslek rehberi |
| `/ftrail duzen` · `banka` · `sat` | Çantayı sırala · bankayı sırala · çöpleri sat |
| `/ftrail ozet` · `oturum` | Oturum özeti |
| `/ftrail seviye` · `plan` | Seviye özeti · XP/saat planı |
| `/ftrail gecmis` · `gecmisim` | Bugünün özeti · görev geçmişi |
| `/ftrail ceviri` | Türkçe başlığı eksik görevler |
| `/ftrail paylas` | Mevcut adımı gruba yaz |
| `/ftrail profil` · `yedek` · `aktar` · `veri` | Profiller · yedekler · ayar aktarma · veri penceresi |
| `/ftrail font` | Yazı tipini değiştir |
| `/ftrail kurulum` | Kurulum sihirbazı |
| `/ftrail canli` | Canlı veri (QuestieDB) durumu |
| `/ftrail kayit baslat <başlık>` · `adim …` · `kayit yaz` · `kayitpencere` | Rehber kaydedici |
| `/janti on` · `off` | Janti şakaları |

## Tuş atamaları

**Oyun menüsü > Tuş Atamaları > Eklentiler > ForeverTrail:** Paneli aç/kapat, En yakın hedef, Otomatik rota, Yön okunu aç/kapat, Ayarlar, Sıradaki görev, Sürekli rota, Ana pencere, Haritada yol sor, Özel hedefi kaldır, Görev eşyasını kullan.

## Ayarlar sekmeleri

Ayarlar 6 kategoriye ayrılmıştır; birden fazla sayfası olan kategorilerde başlığın altında alt sekmeler görünür. Penceredeki **arama kutusu** tüm ayarlarda arar (Türkçe harf yazmadan da bulur: "gorev" → "Görev") ve sonuca tıklayınca ayarın sayfasını açar. Oyun sırasında en sık değişenler için `/ftrail hizli` (ya da düğme çubuğunda **Daha fazla > Hızlı ayarlar**) küçük bir pencere açar.

| Kategori | Alt sekmeler | İçerik |
|---|---|---|
| **Genel** | Genel, Görev kutuları | Sesler, grup, rehber ve ok; görev takip ve alınabilir görev kutuları |
| **Harita** | Simgeler, Rota ve yolculuk, İsim plakası | Haritada/minimapte hangi simgeler, stil, boyut; rota, yol noktaları, uçuş; görev yaratığı simgesi |
| **Otomatik ve uyarılar** | Otomatik, Uyarılar | Otomatik görev, ödül, toplama, çöp satma, tamir, kolaylıklar; uyarılar ve olay sesleri |
| **Sınıf ve meslek** | | Yetenek, seviye kartı, sınıf görevi, eşya ve meslek yardımcıları |
| **Görünüm** | Pencereler ve tema, Özelleştir | Pencereler, tema, saydamlık, ölçek; görev renkleri, rozet konumu, canlı önizleme |
| **Profil ve gelişmiş** | Profiller, Gelişmiş | Profiller, ayar aktarma, yedekler; yazı tipleri, testler ve araçlar |

---|---|
| **Genel** | Genel ayarlar, sesler, grup, rehber |
| **Simgeler** | Haritada/minimapte hangi simgeler, stil (Questie/Sade/Renkli), tür başına boyut, minimap soldurma |
| **Takip** | Görev takip kutusu ve alınabilir görevler: gösterim biçimi, sıralama, görev sayısı, görünüm, hedef rengi, boyut |
| **Harita** | Rota numaraları, yol noktaları, gezgin NPC yolları, "Yol sor" paneli, harita taşıma, yolculuk |
| **İsim plakası** | Görev yaratığı isim plakası simgesi: aç/kapa, boyut, konum |
| **Otomatik** | Otomatik görev, ödül, toplama, çöp satma, tamir, banka düzeni, kolaylıklar |
| **Sınıf / Meslek** | Yetenek, seviye kartı, sınıf görevi, eşya ve meslek yardımcıları |
| **Uyarılar** | Uyarılar ve olay sesleri (varış, ilerleme, tamamlama, uyarı; "Dinle" düğmesi) |
| **Görünüm** | Pencereler, tema, saydamlık, ölçek, yazı tipi |
| **Özelleştir** | Görev renkleri, rozet konumu, canlı önizleme |
| **Profiller** | Profil, ayar aktarma ve yedekler |
| **Gelişmiş** | Yazı tipleri, ayar penceresi, testler ve araçlar |

---

## Veri kaynakları

- **Gömülü veritabanı** (`DataQuests.lua`, `DataNpcs.lua`, `DataObjects.lua`, `DataItems.lua`, `DataZones.lua`): WoW Forever için QuestieDB verisinden, düzeltmeler uygulanmış halde dönüştürülmüştür. Koordinatlar ×10 tamsayı olarak saklanır. Sorgular `OwnDB.lua` üzerinden yapılır.
- **`DataXP.lua`:** QuestieDB'nin oyuncu oturumlarından derlenmiş XP kayıtları (yaklaşık 3.560 görev); gömülü XP tablosunun üstüne yazar.
- **Kendi eklemeler:** `DataNewQuests.lua` (Forever'a özel 1.834 görevin işareti), `DataStations.lua`, `DataDungeons.lua`, `DataTalents.lua` (27 yetenek planı), `Data.lua` (oyunda toplanıp dışa aktarılmış tohum veri).
- **Oynarken öğrenme (`OwnData.lua`):** Aldığınız/teslim ettiğiniz görevlerin yeri ve hedef noktaları kaydedilir; eksik kalan yerleri tamamlar. Ayarlar > Görev'den kapatılır.
- **Canlı veri (`LiveSync.lua`):** QuestieDB eklentisi (`LibQuestieDB`, sözleşme sürümü 4) kuruluysa, oyuna girişte görev/NPC/nesne/eşya satırları gömülü tabloların üzerine alan adlarıyla okunup yazılır. İş kare başına 250 kayıt olarak bölünür (oyun donmaz). QuestieDB'de olmayan satırlar (kendi eklemeleriniz) korunur; yoksa ya da sürüm uyuşmazsa gömülü veri kullanılır. `/ftrail canli` durum gösterir; `ForeverTrailSettings.noLive = true` özelliği kapatır. Adı olmayan kayıtlar bilerek atlanır.
- **Bölge ve XP (Questie):** Questie kuruluysa `ZoneDB` ve `QuestXP` modüllerine önce sorulur (korumalı çağrı); yanıt yoksa gömülü veri kullanılır.
- **WoWTR:** Görev başlığı ve metinleri `QTR_QuestData` tablosundan okunur (görev kimliğiyle); çeviri yoksa gömülü İngilizce metin kullanılır.
- **Önbellek yenileme:** Canlı veri eşitlemesi bitince veriden türetilen önbellekler (alınabilir görevler, sınıf görevleri, nadir yaratıklar, uçuş noktaları vb.) `FT.liveListeners` ile sıfırlanır.

## Diğer eklentilerle uyum

- **Queston Forever:** Kuruluysa ForeverTrail'in aynı işi yapan özellikleri (takipçi, `!`/`?` simgeleri, otomatik görev, isim plakası simgesi, uçuş sayacı vb.) ilk açılışta kapatılır ve ayarlardan kalkar; Türkçe çeviri Queston'un `RegisterLocale` API'siyle yüklenir, ForeverTrail ayarları Queston'un ayar penceresine "ForeverTrail" grubu olarak eklenir.
- **Questie:** Kuruluysa çakışan katmanlar kapatılabilir; ForeverTrail ayarları Questie ayar penceresine sekme olarak (ve ESC > Seçenekler > AddOns altına) eklenir.
- **OneForAll:** Yetenek planı için yönlendirme (bkz. [Sınıf, yetenek ve meslekler](#9-sınıf-yetenek-ve-meslekler)).
- Diğer eklentilerin dosyalarına dokunulmaz; yalnızca açık API'leri kullanılır.

## Kayıtlı veriler (SavedVariables)

| Değişken | Kapsam | İçerik |
|---|---|---|
| `ForeverTrailSettings` | Hesap | Ayarlar, pencere konumları, profiller, kayıtlı yerler |
| `ForeverTrailData` | Hesap | Oynarken toplanan görev verisi |
| `ForeverTrailBackup` | Hesap | Ayar yedekleri |
| `ForeverTrailCharacter` | Karakter | Seçili rehber ve adım, özel hedef, yol, görev geçmişi |

---

## Mimari (geliştiriciler için)

- **Ad alanı ve yükleme sırası:** `require` yoktur. `ForeverTrail.toc` yükleme sırasını belirler; her dosya `local _, FT = ...` ile tek ortak tabloyu paylaşır. Yeni dosya eklerken TOC'ye de ekleyin (yükleme anında kullandığı şeylerden sonra). İşlevler çoğunlukla çağrı anında aranır ve korunur (`if FT.Foo then …`).
- **Olaylar:** `Core.lua` olay çerçevesini (`QUEST_LOG_UPDATE`, `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, bölge olayları) ve `/ftrail` komut dağıtıcısını barındırır; olaylar `FT.Evaluate()`'e birleştirilir.
- **Rehber motoru:** `Engine.lua` rehberleri doğrular (`FT.ValidateGuide`) ve adım tamamlanmasını belirler (`FT.IsStepDone`); `Quest.lua` görev durumunu okur; `Journal.lua` canlı görev günlüğü rehberini üretir.
- **Veri katmanı:** `Data*.lua` tabloları ve `OwnDB.lua` sorgu katmanı (`FT.Module('QuestieDB')`, `ZoneDB`, `QuestXP`, `AvailableQuests`). Çoğu modül `FT.DBQ/DBN/DBO/DBI` tablolarını sıra numarasıyla doğrudan dolaşır; satır düzeni `OwnDB.lua`'daki `QK/NK/OK/IK` ve `LiveSync.lua`'daki sütun listeleriyle aynı kalmalıdır.
- **Arayüz katmanları:** Panel, Tracker, Available, Map/MapRoute/Arrow/Minimap, Hub, Settings, Journal/Journey, Atlas, Layout/Design/Style/Polish, Wizard… bağımsız özellik modülleridir.
- **Önbellekler:** Veriden türetilen her önbellek `FT.liveListeners` listesine bir sıfırlama işlevi eklemelidir.
- **Uyum katmanları:** `Compat.lua` Forever'ın Mainline altyapısı için API farklarını gizler (çanta, yetenek, harita çağrıları korumalı yapılır); `QuestieMerge.lua`, `QuestieBridge.lua`, `QuestonBridge.lua` ve ilgili dosyalar diğer eklentilerle entegrasyondur.
- **Görünüm biçimleri:** `Tracker.lua` (`c_trackerView`: detay/liste/tablo, `c_trackerMax`) ve `Available.lua` (`c_availView`: kart/liste/tablo, `c_availSort`, `c_availMax`, `availShowGiver`, `availHideLow`); `ViewOptions.lua` iki pencereye "Ayar" düğmesini ve ayar penceresini ekler.
- **Görev bilgisi:** `QuestInfo.lua` (`FT.QuestXPInfo`, `FT.QuestXPText`, `FT.QuestInfoTip`).
- **Güvenlik ilkesi:** Korumalı API'ler `pcall` ile çağrılır; başka eklentinin harita işareti değiştirilmez; görev eşyaları asla satılmaz/atılmaz.

### Dosya haritası (özet)

> Dosyalar klasörlere ayrılmıştır: `Core/`, `Data/`, `Guide/`, `Map/`, `UI/`, `Helpers/`, `Integration/` (yükleme sırası `ForeverTrail.toc`'tadır). Aşağıdaki tablo dosyaları alana göre gösterir.

| Alan | Dosyalar |
|---|---|
| Çekirdek | `Core.lua`, `Compat.lua`, `Engine.lua`, `Quest.lua`, `Diagnostics.lua`, `Style.lua`, `Design.lua`, `Polish.lua`, `Layout.lua` |
| Veri | `DataZones/Quests/Npcs/Objects/Items/NewQuests/XP/Stations/Dungeons/Talents.lua`, `OwnDB.lua`, `Data.lua`, `OwnData.lua`, `LiveSync.lua` |
| Rehber | `Guides.lua`, `Guide2.lua`, `Journal.lua`, `Recommendations.lua`, `Recorder.lua`, `Flow.lua`, `Journey.lua` |
| Harita | `Map.lua`, `MapRoute.lua`, `Minimap.lua`, `MinimapTips.lua`, `Atlas.lua`, `Discovery.lua`, `Objectives.lua`, `Places.lua`, `Rares.lua` |
| Arayüz | `Panel.lua`, `Hub.lua`, `Tracker.lua`, `Available.lua`, `ViewOptions.lua`, `Target.lua`, `Arrow.lua`, `Settings.lua`, `Features.lua`, `Toolbox.lua`, `Extras.lua`, `Wizard.lua`, `QuestInfo.lua` |
| Oyun yardımcıları | `Assist.lua`, `Advisor.lua`, `Focus.lua`, `Helpers.lua`, `Gear.lua`, `Upgrade.lua`, `Class.lua`, `Professions.lua`, `QuestHelper.lua`, `Janti.lua` |
| Entegrasyon | `QuestieMerge.lua`, `QuestieBridge.lua`, `QuestieUI.lua`, `QuestonBridge.lua`, `QuestonTR1.lua`, `QuestonTR2.lua` |
| Medya | `Media/` (pfQuest `.tga` simgeleri, MIT) |

## Rehber yazma

Rehberler `FT.RegisterGuide` ile kaydedilir (örnek: `Guides.lua`). Sabit stepId'ler sürümler arasında kararlı kalmalıdır; doğrulanmamış içeriği "DEMO" diye adlandırın.

```lua
FT.RegisterGuide({guideId='example', version=1, title='DEMO', zone='Mulgore', steps={
  {stepId='accept', type='accept', questId=747, text='Görevi al.'},
  {stepId='goal', type='objective', questId=747, objectiveIndex=1, text='İlk hedefi tamamla.'},
  {stepId='turnin', type='turnin', questId=747, text='Görevi teslim et.'},
  {stepId='confirm', type='manual', text='Bu adımı onayla.'},
}})
```

- Türler: `accept`, `objective`, `turnin`, `location`, `manual`.
- `questId` görev adımlarında kullanılır; `objectiveIndex` yalnızca belirli bir hedef içindir.
- `uiMapID`, `x`, `y` birlikte verilir; koordinatlar 0–1 aralığındadır.
- `location` adımında isteğe bağlı `radius` (varsayılan 0,01) kullanılır (normalize mesafe, dünya mesafesi değildir).
- **Rehber kaydedici:** `/ftrail kayit baslat <başlık>`, ardından bulunduğunuz yerde `/ftrail adim [al|hedef|teslim|elle|konum] [görevNo] metin`; konum otomatik alınır. `/ftrail kayit yaz` `Guides.lua`'ya yapıştırılacak Lua kodunu gösterir; `kayit sil` kaydı temizler.
- **Demo:** `Guides.lua` içindeki Mulgore demosu görev 747 için kabul/teslim noktası 44,5 / 77,5, av alanı 42,2 / 77,7 (Plainstrider 2955).

## Testler

Testler düz Lua 5.1+ ile, eklenti klasöründen çalıştırılır (oyun gerekmez):

```
lua tests/engine.lua
lua tests/owndb.lua
```

Her `tests/*.lua` bir modüle karşılık gelir; tümünü çalıştıran bir betik yoktur. Testler WoW global'lerini (`C_QuestLog`, `CreateFrame` vb.) taklit eder. Örnekler:

| Test | Kapsam |
|---|---|
| `engine`, `waypoint`, `chain` | Rehber motoru, koordinat çözümleme, görev zincirleri |
| `owndb`, `livesync`, `livezone`, `questinfo` | Gömülü veri, canlı veri, bölge/XP köprüsü, XP ve ipucu bilgisi |
| `arrow`, `map`, `minimap`, `target`, `objectives` | Yön hesabı, harita ve minimap katmanları, hedef kartı |
| `maproute`, `maproute_ui` | "Yol sor" verisi ve arayüz duman testi |
| `views`, `viewoptions` | Takip ve alınabilir kutuların Ayrıntılı/Liste/Tablo biçimleri, ayar penceresi |
| `selljunk` | Çöp satışı (Mainline API'siyle) |
| `ingame_sim` | Eklentiyi sahte bir oyun ortamında baştan yükler, tüm pencere ve komutları çalıştırır |

Oyun içi doğrulama için: `/ftrail test` (uyumluluk testi), `/ftrail debug`, `/ftrail hata`.

---

## Bilinen sınırlar ve doğrulama durumu

- Eklenti gerçek WoW Forever istemcisinde sürekli oynanarak geliştirilmiştir, ancak testlerin büyük bölümü sahte ortamdadır; yeni özellikler (görünüm biçimleri, "Yol sor" paneli yerleşimi, canlı veri eşitlemesi) oyunda gözle doğrulanmalıdır.
- **Yetenek planı:** Forever'da klasik yetenek API'si yoktur; ForeverTrail yetenek ağacını okuyamaz ve OneForAll'a yönlendirir. Yetenek planı verileri (kami-labs sıralaması) Forever düğüm sıralamasıyla doğrulanmamıştır.
- **XP tahminleri:** Kaydı olmayan görevlerin XP'si aynı seviyedeki görevlerin ortancasından tahmin edilir; yaklaşık bir değerdir.
- **Gemi yolculuğu:** Alliance için gemi iskelesi verisi yoktur; yalnızca yazılı tarif verilir.
- **Uçuş verisi:** Oyunun taksi haritasından okunur; istemci vermezse liste boş kalır.
- **Simgeler:** Questie simgeleri depoda yoktur; bkz. [Kurulum](#simge-dosyaları-hakkında-önemli).
- **Harita/minimap kenar hesabı** kare mini haritalarda yaklaşıktır.
- Oyunun `GetBuildInfo()` çıktısı için `/ftrail debug` kullanın (1.60.1 / Interface 16001 hedeflenmiştir).

### Oyun içi doğrulama listesi

1. Eklentiyi karakter seçiminden açın; `/ftrail debug` çıktısını kaydedin ve Lua hatalarını kontrol edin.
2. Uygun karakterde 747 numaralı görevi kabul → iki hedef → teslim döngüsünde ilerleme ve hedef metinlerini karşılaştırın.
3. Daha önce teslim etmiş karakterde adımların atlandığını; görevi terk edince teslim sayılmadığını; "Buradan sürdür" ile kabul adımına dönüldüğünü sınayın.
4. İncelemede otomatik ilerlemenin görüntüyü sıçratmadığını; yeniden yükleme/girişte adım, panel konumu ve ayarın korunduğunu sınayın.
5. Haritada hedef işaretlerini, "Yol sor" panelini ve görünüm biçimlerini kontrol edin.

---

## Lisans ve teşekkürler

- **ForeverTrail**, GNU Genel Kamu Lisansı sürüm 3 veya sonrası (GPL-3.0-or-later) ile lisanslıdır; bkz. [`LICENSE`](LICENSE) ve [`LICENSE-GPL-3.0.md`](LICENSE-GPL-3.0.md).
- **Veri:** `DataQuests.lua`, `DataNpcs.lua`, `DataObjects.lua`, `DataItems.lua`, `DataZones.lua` ve `DataXP.lua`, [QuestieDB](https://github.com/Questie/QuestieDB) projesinin WoW Forever verisinden dönüştürülmüştür; QuestieDB bakımcıları bu verinin GPLv3 altında kopyalanmasına izin verir (bazı geçmiş katkıların lisans kaydı yoktur; QuestieDB'nin `LICENSE.md` dosyasına bakın). Bu eklenti Questie projesiyle bağlantılı değildir ve onaylanmamıştır.
- **Simgeler:** `Media/*.tga` dosyaları [pfQuest](https://github.com/shagu/pfQuest) projesindendir ve MIT lisansı altındadır (`Media/LICENSE-MIT.txt`). Questie `.blp` simgeleri lisansı belirsiz olduğu için bu depoya dahil **edilmemiştir**.
- **Yetenek planları:** kami-labs.fr "WoW Forever Leveling Builds".
- **Zygor** kılavuzu yalnızca görev al/hedef/teslim iş akışını anlamak için incelenmiştir; kod, düzen, grafik, metin veya rota alınmamıştır.
- Görev XP verisi, harita ve görev altyapısı için [Questie](https://github.com/Questie/Questie) ve QuestieDB ekibine; yetenek sekmesi entegrasyonu için OneForAll'a; Türkçe çeviri için WoWTR'ye teşekkürler.
