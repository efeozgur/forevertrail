# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Bu nedir?

ForeverTrail, **WoW Forever 1.60.1** istemcisi (Interface `16001`) için yazılmış bir World of Warcraft eklentisidir (Lua): görev rehberi, yön oku, harita/minimap katmanları, görev takip kutusu ve yardımcılar. Eğik çizgi komutu `/ftrail`. Arayüz Türkçedir; ayrıntılı özellik ve komut başvurusu README.md'dedir (Türkçe). Derleme adımı yoktur: depo klasörü eklentinin kendisidir ve `Interface\AddOns\ForeverTrail` olarak kurulur.

Not: Bu çalışma kopyası git deposu değil ve eksik görünüyor — `ForeverTrail.toc` içinde listelenen bazı dosyalar (örn. `Compat.lua`, `LiveSync.lua`, `Available.lua`, `DataXP.lua`) klasörde yok. Bir dosyanın var olduğunu varsaymadan önce kontrol edin.

## Testler

Düz Lua 5.1+ (oyun gerekmez). Testler `loadfile('Engine.lua')` gibi göreli yollar kullandığı için **eklenti kök klasöründen** çalıştırılmalıdır:

```
lua tests/engine.lua
lua tests/owndb.lua
```

Her `tests/*.lua` bir modülü kapsar ve başarılı olunca "passed" satırı yazar; tümünü çalıştıran bir betik yoktur, ilgili dosyaları tek tek çalıştırın. Testler WoW global'lerini (`C_QuestLog`, `CreateFrame` vb.) taklit eder ve modülleri `loadfile(ad)('ForeverTrail', ns)` ile yükler. `tests/ingame_sim.lua` tüm eklentiyi sahte bir oyun ortamında yükler, pencereleri ve komutları çalıştırır. Oyun içi kontroller: `/ftrail test`, `/ftrail debug`, `/ftrail hata`.

## Mimari

- **`require` yoktur.** Yükleme sırasını `ForeverTrail.toc` belirler; her dosya `local _, FT = ...` ile başlar ve bu tek tabloyu paylaşır. Yeni bir dosya, yükleme anında kullandığı her şeyden sonra TOC'ye eklenmelidir. Modüller arası çağrılar çağrı anında aranır ve korunur (`if FT.Foo then ... end`).
- **Core.lua** olay çerçevesini (`QUEST_LOG_UPDATE`, `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, bölge olayları), `/ftrail` komut dağıtıcısını (komuta göre uzun bir `if/elseif` zinciri) ve tuş ataması adlarını barındırır. Olaylar birleştirilerek (`FT.pending`, 0,3 sn) `FT.Evaluate()`'e gider.
- **Rehber motoru:** `Engine.lua` (`FT.ValidateGuide`, `FT.IsStepDone`), `Quest.lua` (görev durumu), `Journal.lua` (görev günlüğünden canlı rehber üretir), `Guides.lua`/`Guide2.lua` (`FT.RegisterGuide` ile sabit rehberler). Adım türleri: `accept`, `objective`, `turnin`, `location`, `manual`. stepId'ler sürümler arasında kararlı kalmalıdır; koordinatlar 0–1 aralığındadır.
- **Veri katmanı:** `Data*.lua` QuestieDB'den dönüştürülmüş üretilmiş tablolardır (görev, NPC, nesne, eşya, bölge, XP…); koordinatlar ×10 tamsayı olarak saklanır. `OwnDB.lua` sorgu katmanıdır (`QK/NK/OK/IK` sütun indeksleri). Birçok modül `FT.DBQ/DBN/DBO/DBI` tablolarını sıra numarasıyla doğrudan dolaşır; bu yüzden satır düzeni `OwnDB.lua` ve `LiveSync.lua`'daki sütun listeleriyle uyumlu kalmalıdır. `LiveSync.lua`, QuestieDB eklentisi kuruluysa canlı veriyi gömülü verinin üzerine yazar.
- **Türetilmiş önbellekler**, canlı veri eşitlemesinden sonra temizlenmeleri için `FT.liveListeners` listesine bir sıfırlama işlevi eklemelidir.
- **Arayüz modülleri** bağımsız özelliklerdir: Panel/Hub (ana pencere), Tracker + Available (görev kutuları; görünüm biçimleri `ViewOptions.lua` ile ayarlanır), Map/MapRoute/Arrow/Minimap, Settings vb.
- **Entegrasyon/uyum:** `Compat.lua` istemci API farklarını gizler (Mainline tarzı API'ler; yetenek ağacı yalnızca `C_Traits` ile okunabildiği için yetenek planı OneForAll'a yönlendirilir). `Questie*`/`Queston*` dosyaları bu eklentilerle entegrasyonu sağlar; bu eklentiler çakışan ForeverTrail özelliklerini kapatır.
- **Güvenlik ilkeleri:** Korumalı/belirsiz API'leri `pcall` ile çağırın; başka eklentilerin harita işaretlerini ya da dosyalarını değiştirmeyin; görev eşyalarını asla satmayın veya atmayın.
- **SavedVariables:** `ForeverTrailSettings`, `ForeverTrailData`, `ForeverTrailBackup` (hesap geneli), `ForeverTrailCharacter` (karakter başına).

## Lisans notu

GPL-3.0-or-later. Questie `.blp` simgeleri bilerek depoya dahil edilmemiştir; `Media/` içinde yalnızca MIT lisanslı pfQuest `.tga` simgeleri bulunur.
