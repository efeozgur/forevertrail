# Eve gidince yapılacaklar

ForeverTrail'in son hâli GitHub'da, `v0.2-dev` dalında (son commit: `fad2bc2`).
`main` dalı eski sürümdür, onu indirme.

## 1) Kurulum (yeni bilgisayar)

1. Depoyu klonla (klasörü oyunun AddOns klasörünün DIŞINDA, örneğin `C:\Dev\forevertrail`):

   ```
   git clone -b v0.2-dev https://github.com/efeozgur/forevertrail.git C:\Dev\forevertrail
   ```

2. Klonu oyunun `Interface\AddOns` klasörüne `ForeverTrail` adıyla bağla (PowerShell, yönetici gerekmez):

   ```
   New-Item -ItemType Junction -Path "<oyun>\Interface\AddOns\ForeverTrail" -Target "C:\Dev\forevertrail"
   ```

   `<oyun>` = `World of Warcraft\_forever_` klasörü. AddOns içinde eski bir `ForeverTrail` klasörü varsa önce adını değiştir (örn. `ForeverTrail.bak`).

3. Yürüme haritası eklentilerini bağla. Oyun yalnızca üst düzey klasörleri yüklediği için bu adım gerekli:

   ```
   powershell -ExecutionPolicy Bypass -File "C:\Dev\forevertrail\tools\link_nav_addons.ps1" -AddOns "<oyun>\Interface\AddOns"
   ```

4. Oyunu TAMAMEN kapatıp aç. `/reload` yeni dosyaları yüklemez (bu sürümde iki yeni dosya var:
   `UI/TargetList.lua`, `Guide/RouteOpt.lua`).

5. Oyunda `/ftrail debug` yaz. "Parçalar: hepsi yüklü." görmelisin. Eksik parça varsa kendisi uyarır.

## 2) İstersen: ayarları taşı

Ayarların ve öğrenilen yollar depoda YOK. İş bilgisayarından elle kopyala:

```
<oyun>\WTF\Account\<hesap>\SavedVariables\ForeverTrail.lua
```

Oyun kapalıyken, evdeki aynı yola koy.

## 3) Oyunda bakılacaklar (henüz gerçek istemcide görülmedi)

- Rehber sekmesi: açılır Yolculuk, onay kutusu, Yapılacaklar kartı (XP çubuğu, seviye tahmini). Seviye tahmini `~` işaretliyse tahminidir.
- Hedef listesi penceresi (`/ftrail hedefler`): portreler sabit mi duruyor (animasyon donuyor mu)? Hâlâ oynuyorsa söyle.
- Rota oluştur: 6-8 görevle dene, sıra mantıklı mı, bildirimde "Günlük sırasından %N kısa" yazıyor mu?
- Haritada Yol sor paneli: çipler, kaydırma, "En yakın" düğmeleri, favori yıldızı, harita işaretleri.
- Önceki oturumdan kalanlar: Nav yürüme rotası, minimap sarı çizgisi, Rehber sekmesi yerleşimi.
  Sorun olursa `/ftrail debug`, `/ftrail yolbilgi`, `/ftrail hata` çıktılarını iste.

## 4) Evde çalışırken

- Klon artık gerçek bir git deposu, doğrudan commit + push yapabilirsin (`v0.2-dev` dalındasın).
- Testler (oyun gerekmez): `pip install lupa`, sonra `python tools/run_tests.py`.
- Bu dosya (`eve-gidince.md`) depoda değil, yalnızca iş bilgisayarındaki kopyada. Gerekirse not al.
