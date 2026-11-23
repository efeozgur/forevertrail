-- Otomatik bölge rehberleri: gerçek görev verisiyle her bölge/pencere ve üç karakter için sıralama değişmezleri
QuestieLoader = nil
local player = {level = 12, race = {'Night Elf', 'NightElf', 4}, class = {'Druid', 'DRUID', 11}, faction = 'Alliance'}
UnitLevel = function() return player.level end
UnitRace = function() return player.race[1], player.race[2], player.race[3] end
UnitClass = function() return player.class[1], player.class[2], player.class[3] end
UnitFactionGroup = function() return player.faction end
GetTime = function() return 100 end
C_Map = {GetBestMapForUnit = function() return 1439 end}
C_QuestLog = {GetNumQuestLogEntries = function() return 0 end, GetLogIndexForQuestID = function() return nil end, IsQuestFlaggedCompleted = function() return false end}
ForeverTrailSettings = {}; ForeverTrailCharacter = {}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
local selected
local ft = {RegisterGuide = function() end, SaveStep = function() end, MapName = function(m) return 'Harita ' .. m end, Print = function() end,
 guides = {}, turnedIn = {}, validGuides = {}}
for _, f in ipairs({'Data/DataZones.lua', 'Data/DataQuests.lua', 'Data/DataNpcs.lua', 'Data/DataObjects.lua', 'Data/DataItems.lua', 'Data/DataDungeons.lua',
 'Data/DataXP.lua', 'Data/OwnDB.lua', 'Core/Engine.lua', 'Map/Discovery.lua', 'UI/QuestInfo.lua', 'Guide/AutoGuide.lua'}) do
 assert(loadfile(f))('ForeverTrail', ft)
end
ft.SelectGuide = function(i) selected = ft.validGuides[i] end -- Engine.lua yüklendikten sonra: gerçek SelectGuide görev durumunu okur, bu testte gerekmez
local AG = ft.AutoGuide
assert(AG and AG.Build and AG.Zones and AG.Select and AG.Restore, 'AutoGuide arayüzü')

local function idsOf(guide)
 local out = {}
 for i, s in ipairs(guide.steps) do out[i] = s.stepId end
 return table.concat(out, ',')
end

-- bir rehberin değişmezlerini denetler; dönüş: görev sayısı
local function check(guide, label)
 local ok, err = ft.ValidateGuide(guide)
 assert(ok, label .. ': rehber geçersiz: ' .. tostring(err))
 local pos = {}
 for i, s in ipairs(guide.steps) do
  assert(s.questId, label .. ': adımda görev yok')
  assert(s.type == 'accept' or s.type == 'objective' or s.type == 'turnin', label .. ': adım türü ' .. tostring(s.type))
  local p = pos[s.questId]
  if not p then p = {}; pos[s.questId] = p end
  assert(p[s.type] == nil, label .. ': ' .. s.questId .. ' için ' .. s.type .. ' iki kez')
  p[s.type] = i
  if s.x then
   assert(s.x >= 0 and s.x <= 1 and s.y >= 0 and s.y <= 1 and s.uiMapID == guide.steps[1].uiMapID, label .. ': koordinat/harita')
  else assert(s.type == 'objective', label .. ': yalnızca hedef adımı konumsuz olabilir (' .. s.type .. ')') end
 end
 local quests = 0
 for id, p in pairs(pos) do
  quests = quests + 1
  assert(p.accept and p.turnin, label .. ': ' .. id .. ' alma ya da teslim adımı eksik')
  assert(p.accept < p.turnin, label .. ': ' .. id .. ' teslim, almadan önce')
  if p.objective then assert(p.accept < p.objective and p.objective < p.turnin, label .. ': ' .. id .. ' hedef sırası') end
  -- ön koşul sırası: rehberdeki ön koşul görevleri bu görevden önce teslim edilmeli
  local q = ft.DBQ[id]
  for _, pre in ipairs(type(q[10]) == 'table' and q[10] or {}) do
   if pos[pre] then assert(pos[pre].turnin < p.accept, label .. ': ' .. id .. ' ön koşulu ' .. pre .. ' teslim edilmeden alınıyor') end
  end
  local single = type(q[11]) == 'table' and q[11] or {}
  local inGuide, satisfied = false, false
  for _, pre in ipairs(single) do
   if pos[pre] then inGuide = true; if pos[pre].turnin < p.accept then satisfied = true end else satisfied = true end
  end
  if #single > 0 and inGuide then assert(satisfied, label .. ': ' .. id .. ' ön koşullarından hiçbiri teslim edilmeden alınıyor') end
 end
 -- görev günlüğü kapasitesi (oyunda 20)
 local log, peak = 0, 0
 for _, s in ipairs(guide.steps) do
  if s.type == 'accept' then log = log + 1; peak = math.max(peak, log) elseif s.type == 'turnin' then log = log - 1 end
 end
 assert(peak <= 20, label .. ': görev günlüğü kapasitesi aşıldı: ' .. peak)
 assert(guide.stats.quests == quests and guide.stats.steps == #guide.steps, label .. ': istatistik')
 assert(#guide.unreachable == 0, label .. ': ulaşılamayan görev var: ' .. table.concat(guide.unreachable, ','))
 for _, id in ipairs(guide.alternatives) do
  -- alternatif görev, rehbere giren bir görevin dışladığı görev olmalı
  local excluded = false
  for other in pairs(pos) do for _, x in ipairs(type(ft.DBQ[other][12]) == 'table' and ft.DBQ[other][12] or {}) do if x == id then excluded = true end end end
  assert(excluded, label .. ': ' .. id .. ' alternatif ama hiçbir rehber görevi onu dışlamıyor')
 end
 return quests, peak
end

local characters = {
 {name = 'Gece Elfi Druid (İttifak)', race = {'Night Elf', 'NightElf', 4}, class = {'Druid', 'DRUID', 11}, faction = 'Alliance', level = 12},
 {name = 'İnsan Savaşçı (İttifak)', race = {'Human', 'Human', 1}, class = {'Warrior', 'WARRIOR', 1}, faction = 'Alliance', level = 3},
 {name = 'Orc Savaşçı (Horde)', race = {'Orc', 'Orc', 2}, class = {'Warrior', 'WARRIOR', 1}, faction = 'Horde', level = 25},
}
local t0 = os.clock()
local built, totalQuests, maxPeak, widest = 0, 0, 0, 0
for _, ch in ipairs(characters) do
 player = ch
 local zones = AG.Zones()
 assert(#zones >= 25, ch.name .. ': yeterli bölge penceresi yok: ' .. #zones)
 local recommended = 0
 local lastLo = 0
 for _, z in ipairs(zones) do
  assert(z.lo <= z.hi and z.count >= 10 and z.key and z.name, ch.name .. ': pencere alanları')
  assert(z.lo >= lastLo, ch.name .. ': pencereler seviyeye göre sıralı olmalı')
  lastLo = z.lo
  assert(z.hi - z.lo + 1 <= 20, ch.name .. ': pencere en çok 20 seviye: ' .. z.key)
  if z.recommended then recommended = recommended + 1; assert(ch.level >= z.lo - 1 and ch.level <= z.hi, 'önerilen pencere seviyeye uymalı') end
  local guide = AG.Build(z.map, z.lo, z.hi)
  assert(guide, ch.name .. ': pencere rehber üretmeli: ' .. z.key)
  local quests, peak = check(guide, ch.name .. ' ' .. z.key)
  assert(quests == z.count, ch.name .. ' ' .. z.key .. ': listedeki görev sayısı rehberdekiyle aynı olmalı (' .. z.count .. ' / ' .. quests .. ')')
  built = built + 1; totalQuests = totalQuests + quests; maxPeak = math.max(maxPeak, peak)
  widest = math.max(widest, z.hi - z.lo + 1)
 end
 assert(recommended >= 1, ch.name .. ': seviyeye uygun en az bir pencere önerilmeli')
end
assert(built > 100, 'yeterince rehber üretilmeli: ' .. built)
local elapsed = os.clock() - t0
assert(elapsed < 20, 'üretim çok yavaş: ' .. elapsed .. ' sn')

-- kararlılık: aynı girdi aynı rehberi vermeli (adım kimlikleri kayıtlı ilerleme için sabit olmalı)
player = characters[1]
assert(idsOf(AG.Build(1439, 11, 20)) == idsOf(AG.Build(1439, 11, 20)), 'üretim kararlı olmalı')

-- taraf uygunluğu: bölge listesinde karşı tarafın bölgesi çıkmamalı (tarafsız görevler tek tek alınabilir ama liste anlamlı olmalı)
local function hasMap(zones, map) for _, z in ipairs(zones) do if z.map == map then return true end end return false end
player = characters[3] -- Horde
assert(hasMap(AG.Zones(), 1411) and not hasMap(AG.Zones(), 1439), 'Horde listesinde Durotar olmalı, Darkshore olmamalı')
player = characters[1] -- İttifak
assert(hasMap(AG.Zones(), 1439) and not hasMap(AG.Zones(), 1411), 'İttifak listesinde Darkshore olmalı, Durotar olmamalı')

-- seçme ve geri yükleme
player = characters[1]
ft.validGuides = {{guideId = 'x', version = 1, title = 'x', zone = 'x', steps = {{stepId = 'a', type = 'manual', text = 'x'}}}}
local ok, guide = AG.Select(1439, 11, 20)
assert(ok and selected == guide and guide.auto and #ft.validGuides == 2, 'Select rehberi listeye ekleyip seçmeli')
assert(ForeverTrailCharacter.autoGuide.map == 1439 and ForeverTrailCharacter.autoGuide.lo == 11, 'seçim karakter kaydına yazılmalı')
local ok2 = AG.Select(1439, 11, 20)
assert(ok2 and #ft.validGuides == 2, 'aynı rehber yeniden seçilince çoğalmamalı')
ft.validGuides = {ft.validGuides[1]}
assert(AG.Restore() and #ft.validGuides == 2 and ft.validGuides[2].guideId == guide.guideId, 'Restore rehberi yeniden üretmeli')
local bad, msg = AG.Select(1439, 55, 60)
assert(bad == false and type(msg) == 'string', 'uygun görev yoksa anlaşılır bir ileti dönmeli')

print(('AutoGuide tests passed (%d rehber, %d görev, günlük zirvesi %d, en geniş pencere %d seviye, %.1f sn)'):format(built, totalQuests, maxPeak, widest, elapsed))
