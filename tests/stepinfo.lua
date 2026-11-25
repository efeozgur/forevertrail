-- Rehber adım bilgisi ve tempo: NPC/açıklama/XP, sıradaki durak, bekleyen teslimler, saatlik XP ve seviyeye kalan süre
local clock, xp, xpMax = 0, 100, 1000
GetTime = function() return clock end
UnitXP = function() return xp end
UnitXPMax = function() return xpMax end
CreateFrame = function() return {SetScript = function() end, RegisterEvent = function() end} end
C_QuestLog = {GetNumQuestLogEntries = function() return 3 end,
 GetInfo = function(i) return ({{questID = 11}, {questID = 12}, {isHeader = true}})[i] end,
 IsComplete = function(id) return id == 11 or id == 12 end}
local ft = {DBN = {[5] = {'Eleanor'}, [6] = {'Johaan'}}, DBQ = {[1] = {'Camping 101', 1, 1, 1, 1, 1, 1, 'Carolai Anise takes it.'}},
 MapName = function(m) return 'Tirisfal Glades' end, QuestXPInfo = function(id) return id * 10 end}
assert(loadfile('Guide/StepInfo.lua'))('ForeverTrail', ft)

-- adım bilgisi
local accept = {type = 'accept', questId = 1, questTitle = 'Camping 101', npc = 'Eleanor', uiMapID = 1, x = 0.5, y = 0.5}
local info = ft.StepInfo(accept)
assert(info.verb == 'Görevi al' and info.title == 'Camping 101' and info.npc == 'Eleanor' and info.zone == 'Tirisfal Glades', 'accept bilgisi')
assert(info.detail == 'Carolai Anise takes it.' and info.xp == 10 and info.hasPlace, 'accept açıklaması, XP ve konum: ' .. tostring(info.detail))
assert(ft.StepInfo({type = 'objective', questId = 1, questTitle = 'Camping 101', text = 'Kill 5 boars'}).detail == 'Kill 5 boars', 'hedef açıklaması adım metni olmalı')
assert(ft.StepInfo({type = 'turnin', questId = 1, questTitle = 'X', text = 'Teslim et'}).detail == nil, 'teslimde açıklama olmamalı')
assert(ft.StepInfo(nil).type == 'manual', 'adımsız çağrı kırılmamalı')

-- çeviri varsa başlık ve hedef Türkçe olur
QTR_QuestData = {['1'] = {Title = 'Kamp 101', Objectives = 'Carolai alır.'}}
info = ft.StepInfo(accept)
assert(info.title == 'Kamp 101' and info.detail == 'Carolai alır.', 'WoWTR çevirisi kullanılmalı')
QTR_QuestData = nil

-- sıradaki durak: farklı NPC'li ilk alma/teslim adımı
local guide = {steps = {accept, {type = 'objective', questId = 1, text = 'x'}, {type = 'accept', questId = 2, npc = 'Eleanor', questTitle = 'Aynı NPC'},
 {type = 'turnin', questId = 1, npc = 'Johaan', questTitle = 'Camping 101'}}}
local stop = ft.NextStop(guide, 1)
assert(stop and stop.npc == 'Johaan' and stop.index == 4 and stop.verb == 'Teslim et', 'sıradaki durak farklı NPC olmalı')
assert(ft.NextStop(guide, 4) == nil, 'son adımdan sonra durak yok')

-- bekleyen teslimler (başlık satırı ve istisna sayılmaz)
local n, total = ft.PendingTurnIns()
assert(n == 2 and total == 230, 'bekleyen teslimler: ' .. n .. '/' .. total)
n, total = ft.PendingTurnIns(11)
assert(n == 1 and total == 120, 'istisna görev sayılmamalı: ' .. n .. '/' .. total)

-- tempo
ft.PaceReset()
local perHour, minutes, text = ft.Pace()
assert(perHour == nil and text:find('ölçülüyor'), 'ölçüm başlamadan tempo yok')
ft.PaceEvent('PLAYER_ENTERING_WORLD')
clock = 3600; xp = 600; ft.PaceEvent('PLAYER_XP_UPDATE')
perHour, minutes, text = ft.Pace()
assert(math.abs(perHour - 500) < 1e-6 and math.abs(minutes - 48) < 1e-6, 'saatlik 500 XP, seviyeye 48 dk: ' .. tostring(perHour) .. '/' .. tostring(minutes))
assert(text == '500 XP/sa  ·  seviyeye ~48 dk', 'tempo metni: ' .. text)
-- seviye atlama: sayaç başa dönse de kazanç doğru toplanır (900'den 1000'e 100 + yeni seviyede 50)
xp = 900; ft.PaceEvent('PLAYER_XP_UPDATE')
xp = 50; xpMax = 1200; clock = 7200; ft.PaceEvent('PLAYER_XP_UPDATE')
perHour = ft.Pace()
assert(math.abs(perHour - (500 + 300 + 100 + 50) / 2) < 1e-6, 'seviye atlayınca kazanç: ' .. tostring(perHour))

-- XP tahmini ve Yapılacaklar özeti (xp=50, eşik 1200, seviye 10)
UnitLevel = function() return 10 end
ft.QuestState = function() return {status = 'not_taken'} end
C_QuestLog.IsComplete = function(id) return id == 11 end
local todoGuide = {steps = {{type = 'turnin', questId = 11}, {type = 'turnin', questId = 14}, {type = 'turnin', questId = 14}}}
local sum = ft.TodoSummary(todoGuide, 1)
assert(sum.readyCount == 1 and sum.readyXP == 110 and sum.activeCount == 1 and sum.activeXP == 120, 'günlük görevleri: ' .. sum.readyXP .. '/' .. sum.activeXP)
assert(sum.futureCount == 1 and sum.futureXP == 140, 'rehberde kalan (günlükte olmayan, tekrarsız): ' .. sum.futureCount .. '/' .. sum.futureXP)
assert(sum.totalXP == 370 and sum.thisXP == 110, 'toplam ve bu görev: ' .. sum.totalXP)
assert(sum.rows[1].questId == 11 and sum.rows[1].status == 'ready' and sum.rows[2].status == 'active', 'hazır görev önce')
assert(sum.ready[1] == 10 and math.abs(sum.ready[2] - (50 + 110) / 1200) < 1e-9, 'teslim sonrası oran')
assert(sum.all[1] == 10 and math.abs(sum.all[2] - (50 + 370) / 1200) < 1e-9 and not sum.all[3], 'hepsi bitince oran')
local lv, frac, jumped = ft.ProjectXP(3000)
assert(lv == 12 and jumped and frac > 0 and frac < 1, 'çok seviye atlama: ' .. tostring(lv))
lv = ft.ProjectXP(0); assert(lv == 10, 'kazanç yoksa seviye değişmez')
-- görevin altındaki adım adım yapılacaklar (FT.QuestSteps / FT.PlaceOf)
do
 local mapId, px, py = 1, 0.78, 0.22
 C_Map = {GetBestMapForUnit = function() return mapId end, GetPlayerMapPosition = function() return {GetXY = function() return px, py end} end}
 local spawns = {[100] = {[1] = {{40, 50}, {80, 20}}}, [300] = {[2] = {{10, 10}, {12, 12}, {14, 10}}, [1] = {{90, 90}}}}
 ft.Module = function(name)
  if name == 'QuestieDB' then return {QueryNPCSingle = function(id, key) return key == 'spawns' and spawns[id] or nil end, QueryObjectSingle = function() return nil end} end
  if name == 'ZoneDB' then return {GetUiMapIdByAreaId = function(_, area) return area end} end
 end
 ft.ParseObjective = function(t) return (t:gsub('%s*:?%s*%d+%s*/%s*%d+%s*$', '')) end
 ft.TurnInName = function(id) return id == 20 and 'Johaan' or nil end
 ft.SpawnPoints = function(step) return step.type == 'turnin' and {{map = 1, x = 0.2, y = 0.3}} or {} end
 ft.MapName = function(m) return m == 1 and 'Tirisfal Glades' or 'Durotar' end

 -- yer seçimi: oyuncunun haritasındaki en yakın nokta
 local place = ft.PlaceOf({{map = 1, x = 0.4, y = 0.5}, {map = 1, x = 0.8, y = 0.2}})
 assert(place and place.text == 'Tirisfal Glades · 80, 20', 'en yakın nokta: ' .. tostring(place and place.text))
 -- oyuncu başka haritada: en çok nokta olan harita, ağırlık merkezine en yakın nokta
 mapId = 9
 place = ft.PlaceOf({{map = 1, x = 0.9, y = 0.9}, {map = 2, x = 0.10, y = 0.10}, {map = 2, x = 0.12, y = 0.12}, {map = 2, x = 0.14, y = 0.10}})
 assert(place and place.map == 2 and place.text == 'Durotar · 12, 12', 'çoğunluk haritası: ' .. tostring(place and place.text))
 assert(ft.PlaceOf({}) == nil and ft.PlaceOf(nil) == nil, 'noktasız yer yok')
 mapId = 1

 -- yarım kalmış görev: biri sürüyor, biri bitmiş
 local rows = {{text = 'Kobold slain: 3/8', numFulfilled = 3, numRequired = 8, finished = false}, {text = 'Candle: 2/2', numFulfilled = 2, numRequired = 2, finished = true}}
 C_QuestLog.GetQuestObjectives = function() return rows end
 ft.ActiveObjectives = function() return {
  {questId = 20, index = 1, kind = 'kill', name = 'Kobold', npcs = {100}, objs = {}},
  {questId = 20, index = 2, kind = 'loot', name = 'Candle', npcs = {}, objs = {}},
  {questId = 99, index = 1, kind = 'kill', name = 'Başka görev', npcs = {}, objs = {}}} end
 clock = clock + 100
 local steps = ft.QuestSteps(20)
 assert(#steps == 3, 'iki hedef + teslim = 3 adım: ' .. #steps)
 assert(steps[1].text == 'Öldür: Kobold' and steps[1].have == 3 and steps[1].need == 8 and steps[1].current and not steps[1].done, 'ilk adım')
 assert(steps[1].place and steps[1].place.text == 'Tirisfal Glades · 80, 20', 'ilk adım yeri: ' .. tostring(steps[1].place and steps[1].place.text))
 assert(steps[2].text == 'Topla: Candle' and steps[2].done and not steps[2].current and steps[2].place == nil, 'biten adım yersiz ve sırada değil')
 assert(steps[3].kind == 'turnin' and steps[3].text == 'Teslim et: Johaan' and not steps[3].current, 'teslim adımı sırada değil')
 assert(steps[3].place and steps[3].place.text == 'Tirisfal Glades · 20, 30', 'teslim yeri: ' .. tostring(steps[3].place and steps[3].place.text))
 -- sayaç her çağrıda günlükten okunur (yer önbellekte olsa da)
 rows[1].numFulfilled = 5
 assert(ft.QuestSteps(20)[1].have == 5, 'sayaç önbellekten gelmemeli')
 -- hepsi bitince sıradaki adım teslim
 rows[1].numFulfilled, rows[1].finished = 8, true
 steps = ft.QuestSteps(20)
 assert(steps[1].done and steps[2].done and steps[3].current and steps[1].place == nil, 'hepsi bitince teslim sırada')
 -- veritabanında eşleşmeyen hedef: oyunun hedef metni kullanılır, çökmez
 ft.ActiveObjectives = function() return {} end
 rows = {{text = 'Gizemli şey: 0/1', numFulfilled = 0, numRequired = 1, finished = false}}
 clock = clock + 100
 steps = ft.QuestSteps(21)
 assert(#steps == 2 and steps[1].text == 'Gizemli şey' and steps[1].place == nil and steps[1].current, 'eşleşmeyen hedef')
 assert(steps[2].text == 'Görevi teslim et', 'teslim NPC adı bilinmiyorsa genel metin: ' .. steps[2].text)
 -- hedefsiz görev (yalnızca konuş): tek adım teslim
 rows = {}
 steps = ft.QuestSteps(22)
 assert(#steps == 1 and steps[1].kind == 'turnin' and steps[1].current, 'hedefsiz görev')
 assert(#ft.QuestSteps(nil) == 0, 'görev kimliği yoksa boş liste')

 -- QuestPlan: günlükteyse gerçek adımlar, değilse "Görevi al" ile başlayan önizleme, teslim edilmişse boş
 local inLog, flagged = {[30] = true}, {}
 C_QuestLog.GetLogIndexForQuestID = function(id) return inLog[id] and 1 or 0 end
 C_QuestLog.IsQuestFlaggedCompleted = function(id) return flagged[id] or false end
 ft.StepNpc = function(step) return step.type == 'accept' and 'Eleanor' or nil end
 ft.QuestObjectiveList = function(id) return {{kind = 'kill', name = 'Boar', npcs = {100}, objs = {}}, {kind = 'loot', name = 'Tusk', npcs = {}, objs = {}}} end
 ft.TurnInName = function(id) return 'Johaan' end
 ft.SpawnPoints = function(step) return {{map = 1, x = 0.25, y = 0.35}} end
 mapId = 1; clock = clock + 100
 local plan = ft.QuestPlan(40)
 assert(#plan == 4, 'önizleme: al + iki hedef + teslim: ' .. #plan)
 assert(plan[1].kind == 'accept' and plan[1].text == 'Görevi al: Eleanor' and plan[1].current, 'ilk adım görevi almak ve sırada')
 assert(plan[1].place and plan[1].place.text == 'Tirisfal Glades · 25, 35', 'veren yeri: ' .. tostring(plan[1].place and plan[1].place.text))
 assert(plan[2].text == 'Öldür: Boar' and plan[2].place and plan[2].place.text == 'Tirisfal Glades · 80, 20', 'hedef adımı ve yeri')
 assert(plan[3].text == 'Topla: Tusk' and plan[3].place == nil, 'yeri bilinmeyen hedef yersiz')
 assert(plan[4].kind == 'turnin' and plan[4].text == 'Teslim et: Johaan' and not plan[4].current, 'teslim adımı')
 rows = {{text = 'Boar: 1/2', numFulfilled = 1, numRequired = 2, finished = false}}
 ft.ActiveObjectives = function() return {} end
 assert(ft.QuestPlan(30)[1].kind ~= 'accept' and ft.QuestPlan(30)[1].need == 2, 'günlükteki görevde "Görevi al" olmamalı, gerçek sayaç kullanılmalı')
 flagged[50] = true
 assert(#ft.QuestPlan(50) == 0, 'teslim edilmiş görevde plan boş')
 assert(#ft.QuestPlan(nil) == 0, 'kimliksiz çağrı boş')

 -- nesneyle (ilan tahtası, kitap) ve eşyayla (yaratıktan düşer) başlayan görevler de yer bulur; SpawnPoints yalnızca NPC'ye bakar
 local objSpawns = {[500] = {[1] = {{42, 67}}}}
 ft.Module = function(name)
  if name == 'QuestieDB' then return {
   QueryNPCSingle = function(id, key) return key == 'spawns' and spawns[id] or nil end,
   QueryObjectSingle = function(id, key) return key == 'spawns' and objSpawns[id] or nil end} end
  if name == 'ZoneDB' then return {GetUiMapIdByAreaId = function(_, area) return area end} end
 end
 ft.SpawnPoints = function() return {} end
 ft.DBO = {[500] = {'Old Footlocker'}}
 ft.DBN[100] = {'Kurt'}
 ft.DBI = {[800] = {'Pençe', {100}, nil}}
 ft.DBQ[60] = {'Tahta görevi', {nil, {500}}, {{7}}}                     -- nesneyle başlar
 ft.DBQ[61] = {'Eşya görevi', {nil, nil, {800}}, {{7}}}                  -- eşyayla başlar (800: 100 numaralı yaratıktan düşer)
 ft.DBQ[62] = {'Nesneye teslim', {{5}}, {nil, {500}}}                    -- nesneye teslim edilir
 ft.DBQ[63] = {'NPC görevi', {{5}}, {{7}}}
 ft.DBQ[64] = {'Bölge görevi'}; ft.DBQ[64][13] = 1
 clock = clock + 100; mapId = 1; px, py = 0.78, 0.22
 local p60 = ft.QuestSpot(60, 'accept')
 assert(p60 and p60.text == 'Tirisfal Glades · 42, 67', 'nesneyle başlayan görevin yeri: ' .. tostring(p60 and p60.text))
 local p61 = ft.QuestSpot(61, 'accept')
 assert(p61 and p61.text == 'Tirisfal Glades · 80, 20', 'eşyayla başlayan görevin yeri eşyanın düştüğü en yakın nokta: ' .. tostring(p61 and p61.text))
 local p62 = ft.QuestSpot(62, 'turnin')
 assert(p62 and p62.text == 'Tirisfal Glades · 42, 67', 'nesneye teslim yeri: ' .. tostring(p62 and p62.text))
 assert(ft.QuestSpot(63, 'accept') == nil, 'verisi olmayan NPC için yer yok (uydurma yok)')
 assert(ft.QuestGiverName(60) == 'Old Footlocker' and ft.QuestGiverName(63) == 'Eleanor' and ft.QuestGiverName(61) == nil, 'veren adı: nesne, NPC, eşyayla başlayanda yok')
 local item = ft.QuestStartItem(61)
 assert(item and item.itemId == 800 and item.name == 'Pençe' and #item.points == 2, 'başlatan eşya ve düştüğü noktalar')
 assert(ft.QuestStartItem(60) == nil and ft.QuestStartItem(63) == nil, 'eşyayla başlamayan görevde başlatan eşya yok')
 assert(ft.QuestZoneName(64) == 'Tirisfal Glades' and ft.QuestZoneName(63) == nil and ft.QuestZoneName(nil) == nil, 'görevin bölgesi')
 -- yer aranırken hedef noktaları (OwnObjectivePoints) giverin yerine geçmemeli
 ft.OwnObjectivePoints = function() return {{map = 1, x = 0.99, y = 0.99}} end
 clock = clock + 100
 assert(ft.QuestSpot(63, 'accept') == nil, 'veren yeri aranırken görev HEDEFİ noktaları kullanılmamalı')
 ft.OwnObjectivePoints = nil
end
print('StepInfo tests passed')
