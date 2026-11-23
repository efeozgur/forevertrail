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
print('StepInfo tests passed')
