-- Questie gömülü sürüm: Questie'nin yaptığı işleri ForeverTrail iki kez yapmasın
local _, FT = ...

FT.QuestieEmbedded = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata('ForeverTrail', 'X-ForeverTrail-Embedded') == '1') or (QuestieLoader ~= nil)

-- Questie'nin karşılığı olan ForeverTrail katmanları
FT.QuestieOverlaps = {
 {key = 'tracker', label = 'ForeverTrail görev kutusu (Questie takipçisi varken kapalı)'},
 {key = 'givers', label = 'ForeverTrail ! / ? simgeleri (Questie simgeleri varken kapalı)'},
 {key = 'objareas', label = 'ForeverTrail hedef simgeleri ve alanları'},
 {key = 'plateicons', label = 'ForeverTrail isim plakası simgesi (Questie plakası varken kapalı)'},
 {key = 'autoquest', label = 'ForeverTrail otomatik görev al / teslim et (Questie\'de de var)'},
}

-- Queston Forever ana eklenti olarak açıksa: onun işaretleri, takipçisi ve temaları kalır, bizimkiler kapanır
local function loaded(name)
 if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
 return IsAddOnLoaded and IsAddOnLoaded(name)
end
FT.QuestonOverlaps = {
 {key = 'tracker', label = 'ForeverTrail görev kutusu (Queston takipçisi var)'},
 {key = 'givers', label = 'ForeverTrail ! / ? simgeleri (Queston harita işaretleri var)'},
 {key = 'objareas', label = 'ForeverTrail hedef simgeleri ve alanları (Queston görev alanları var)'},
 {key = 'plateicons', label = 'ForeverTrail isim plakası simgesi (Queston plaka işaretleri var)'},
 {key = 'platecolor', label = 'Görev yaratığı can barı rengi'},
 {key = 'autoquest', label = 'ForeverTrail otomatik görev (Queston QuestAuto var)'},
 {key = 'flighttimes', label = 'ForeverTrail uçuş süresi çubuğu (Queston uçuş sayacı var)'},
 {key = 'townsfolk', label = 'ForeverTrail kasaba işaretleri (Queston yakındaki hizmetler var)'},
 {key = 'townprof', label = 'Kasaba işaretlerinde meslek eğitmenleri'},
 {key = 'dungeonicons', label = 'ForeverTrail zindan girişleri (Queston zindan haritaları var)'},
 {key = 'card', label = 'ForeverTrail hedef kartı (Queston hedef kartı var)'},
 {key = 'partymap', label = 'Grubun görevleri haritada (Queston grup ilerlemesi var)'},
 {key = 'goldmark', label = 'Satılacak eşyalara altın işareti (Queston çanta işaretleri var)'},
}

-- Queston'un zaten yaptığı işler: ayarlardan da kalkar, ilk açılışta kapatılır
FT.QuestonDup = {}
for _, k in ipairs({
 'tracker', 'givers', 'objareas', 'giversDone', 'qRepeat', 'qEvent', 'qPvP', 'qDungeon', 'qRaid', 'iconglow', 'hideContinent', 'focusbig', 'qareas', 'heatmap', 'mmfade', 'mmedge',
 'mapIcons', 'mmIcons', 'iconGiver', 'iconKill', 'iconLoot', 'iconObject', 'mmFadeStart', 'c_iconStyle',
 'availbox', 'c_trackerStyle', 'c_trackerSort', 'trkdiff', 'trkShowDone', 'trkAutoMin', 'trkzones', 'trkitems', 'questitem', 'trkHideDoneObj', 'c_objColor', 'trkfx', 'trkring',
 'trkCombat', 'trkInstance', 'c_trackerDensity', 'c_sessionGoal', 'trackerScale', 'trackerFont',
 'plateicons', 'platecolor', 'creaturewarn', 'creaturenear', 'raidmarks', 'plate', 'plateX', 'plateY',
 'autoquest', 'autoreward', 'rewardadvisor', 'autosell', 'autorepair', 'goldmark', 'bagwarn', 'itemquests', 'mobloot', 'objtips',
 'upgrades', 'swap', 'autoequip',
 'flighttimes', 'flightalert', 'flightplan', 'flightadvice', 'card', 'partymap', 'townsfolk', 'townprof', 'dungeonicons', 'routenums', 'zonefit', 'infobar',
}) do FT.QuestonDup[k] = true end
-- sayı ya da seçim olan anahtarlar kapatılmaz, sadece ayarlardan kalkar
local VALUE_KEYS = {mapIcons = true, mmIcons = true, iconGiver = true, iconKill = true, iconLoot = true, iconObject = true, mmFadeStart = true, c_iconStyle = true,
 c_trackerStyle = true, c_trackerSort = true, c_objColor = true, c_trackerDensity = true, c_sessionGoal = true, trackerScale = true, trackerFont = true, plate = true, plateX = true, plateY = true}

local f = CreateFrame('Frame')
f:RegisterEvent('ADDON_LOADED')
f:SetScript('OnEvent', function(self, _, name)
 if name ~= 'ForeverTrail' then return end
 self:UnregisterAllEvents()
 ForeverTrailSettings = ForeverTrailSettings or {}
 local s = ForeverTrailSettings
 FT.QuestonActive = loaded('QuestonForever') or (FT.AddOnEnabled and FT.AddOnEnabled('QuestonForever')) or false
 if FT.QuestonActive then
  FT.ActiveOverlaps = FT.QuestonOverlaps
  if (s.questonVersion or 0) < 1 then
   for _, o in ipairs(FT.QuestonOverlaps) do s[o.key] = false end
   s.questonVersion = 1
  end
  if (s.questonVersion or 0) < 2 then
   for k in pairs(FT.QuestonDup) do if not VALUE_KEYS[k] then s[k] = false end end
   s.questonVersion = 2
  end
  return
 end
 if not FT.QuestieEmbedded then return end
 FT.ActiveOverlaps = FT.QuestieOverlaps
 if (s.mergeVersion or 0) < 1 then
  for _, o in ipairs(FT.QuestieOverlaps) do s[o.key] = false end
  s.c_optionsStyle = 'questie'
  s.mergeVersion = 1
 end
end)
