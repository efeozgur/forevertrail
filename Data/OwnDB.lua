local _, FT = ...

-- ForeverTrail'in gömülü görev veritabanı için sorgu katmanı.
-- Veri DataQuests/DataNpcs/DataObjects/DataItems/DataZones dosyalarındadır (koordinatlar x10 tamsayı).
-- Dış eklentiye ihtiyaç duymaz; arayüzü eski kodla uyumlu olsun diye aynı sorgu adlarını kullanır.

local QK = {name=1, startedBy=2, finishedBy=3, requiredLevel=4, questLevel=5, requiredRaces=6, requiredClasses=7,
 objectivesText=8, objectives=9, preQuestGroup=10, preQuestSingle=11, exclusiveTo=12, zoneOrSort=13, requiredSkill=14,
 nextQuestInChain=15, specialFlags=16, breadcrumbForQuestId=17, breadcrumbs=18, sourceItemId=19}
local NK = {name=1, minLevel=2, maxLevel=3, rank=4, spawns=5, waypoints=6, zoneID=7, questStarts=8, questEnds=9,
 friendlyToFaction=10, subName=11, npcFlags=12, boss=13}
local OK = {name=1, questStarts=2, questEnds=3, spawns=4, zoneID=5}
local IK = {name=1, npcDrops=2, objectDrops=3, startQuest=4, questRewards=5, itemLevel=6, requiredLevel=7, class=8, subClass=9}

-- {[area]={x10,y10,...}} -> {[area]={{x,y},...}} (önbellekli)
local spawnCache = setmetatable({}, {__mode='k'})
local function expandSpawns(flat)
 if type(flat) ~= 'table' then return nil end
 local cached = spawnCache[flat]
 if cached then return cached end
 local out = {}
 for area, list in pairs(flat) do
  local pts = {}
  for i = 1, #list - 1, 2 do pts[#pts + 1] = {list[i] / 10, list[i + 1] / 10} end
  out[area] = pts
 end
 spawnCache[flat] = out
 return out
end
local function expandPaths(flat)
 if type(flat) ~= 'table' then return nil end
 local cached = spawnCache[flat]
 if cached then return cached end
 local out = {}
 for area, routes in pairs(flat) do
  local rs = {}
  for _, route in ipairs(routes) do
   local pts = {}
   for i = 1, #route - 1, 2 do pts[#pts + 1] = {route[i] / 10, route[i + 1] / 10} end
   rs[#rs + 1] = pts
  end
  out[area] = rs
 end
 spawnCache[flat] = out
 return out
end

local DB = {}
function DB.QueryQuestSingle(id, key)
 local q = FT.DBQ and FT.DBQ[id]
 local i = QK[key]
 if not (q and i) then return nil end
 local v = q[i]
 if key == 'objectivesText' then return v and {v} or nil end
 if key == 'name' and v == '' then return nil end
 return v
end
function DB.QueryNPCSingle(id, key)
 local n = FT.DBN and FT.DBN[id]
 local i = NK[key]
 if not (n and i) then return nil end
 if key == 'spawns' then return expandSpawns(n[5]) end
 if key == 'waypoints' then return expandPaths(n[6]) end
 return n[i]
end
function DB.QueryObjectSingle(id, key)
 local o = FT.DBO and FT.DBO[id]
 local i = OK[key]
 if not (o and i) then return nil end
 if key == 'spawns' then return expandSpawns(o[4]) end
 return o[i]
end
function DB.QueryItemSingle(id, key)
 local it = FT.DBI and FT.DBI[id]
 local i = IK[key]
 if not (it and i) then return nil end
 return it[i]
end
FT.DB = DB

-- Questie kuruluysa onun güncel modülleri (ZoneDB, QuestXP) önce sorulur; yanıt yoksa gömülü veri kullanılır.
-- Questie'nin başlatması oyun girişinden sonra bitebilir; o zamana kadar çağrılar hata verir ve gömülüye düşer.
local function questieModule(name)
 if ForeverTrailSettings and ForeverTrailSettings.noLive then return nil end
 local loader = _G.QuestieLoader
 if type(loader) ~= 'table' or not loader.ImportModule then return nil end
 local ok, m = pcall(loader.ImportModule, loader, name)
 return ok and type(m) == 'table' and m or nil
end
FT.QuestieModule = questieModule

local Zone = {}
function Zone:GetUiMapIdByAreaId(area)
 local live = questieModule('ZoneDB')
 local guard = 0
 while area and guard < 6 do
  local o = FT.DBAreaOverride and FT.DBAreaOverride[area]
  if o ~= nil then return o ~= 0 and o or nil end
  if live and live.GetUiMapIdByAreaId then
   local ok, lm = pcall(live.GetUiMapIdByAreaId, live, area)
   if ok and type(lm) == 'number' and lm ~= 0 then return lm end
  end
  local m = FT.DBArea and FT.DBArea[area]
  if m and m ~= 0 then return m end
  area = FT.DBSubZone and FT.DBSubZone[area]
  guard = guard + 1
 end
end

-- Görev XP'si: seviye farkına göre azalır (Classic kuralı)
local XP = {db = FT.DBXP or {}}
function XP:GetQuestLogRewardXP(id)
 local live = questieModule('QuestXP')
 if live and live.GetQuestLogRewardXP and type(live.db) == 'table' and live.db[id] then
  local ok, v = pcall(live.GetQuestLogRewardXP, live, id, false)
  if ok and type(v) == 'number' and v > 0 then return v end
 end
 local e = self.db[id]
 if not e then return nil end
 local diff = (UnitLevel('player') or 1) - (e[1] or 0)
 local mult = diff <= 5 and 1 or (diff == 6 and 0.8 or (diff == 7 and 0.6 or (diff == 8 and 0.4 or (diff == 9 and 0.2 or 0.1))))
 return math.floor(e[2] * mult / 5 + 0.5) * 5
end

-- Alınabilecek görevler: seviye, ırk/sınıf, ön koşul ve bitmişlik kontrolüyle
local function hasBit(mask, bitIndex)
 if type(mask) ~= 'number' or mask == 0 then return true end
 return math.floor(mask / 2 ^ bitIndex) % 2 == 1
end
-- Bitirilen ve günlükteki görevler: oyundan bir kez okunur, olaylarla güncellenir (6.000 ayrı API çağrısı yerine)
local doneSet, logSet, availDirty, availCache, availTime = nil, nil, true, nil, -100
local function buildDone()
 doneSet = {}
 if GetQuestsCompleted then
  local ok, t = pcall(GetQuestsCompleted)
  if ok and type(t) == 'table' then for id, v in pairs(t) do if v then doneSet[id] = true end end end
 end
 doneSet.__api = next(doneSet) == nil
end
local function completed(id)
 if FT.turnedIn and FT.turnedIn[id] then return true end
 if not doneSet then buildDone() end
 if doneSet[id] then return true end
 if doneSet.__api then
  local q = C_QuestLog
  if q and q.IsQuestFlaggedCompleted then return q.IsQuestFlaggedCompleted(id) == true end
  return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(id) == true
 end
 return false
end
local function inLog(id)
 if not logSet then
  logSet = {}
  local q = C_QuestLog
  for i = 1, (q and q.GetNumQuestLogEntries and q.GetNumQuestLogEntries() or 0) do
   local info = q.GetInfo(i)
   if info and info.questID and info.questID > 0 then logSet[info.questID] = true end
  end
 end
 return logSet[id] == true
end

local function computeAvailable()
 -- Yalnızca bir olay sonrasında ve en sık 2 saniyede bir yeniden hesapla
 if availCache and (not availDirty or GetTime() - availTime < 2) and GetTime() - availTime < 60 then return availCache end
 availDirty = false
 local out = {}
 local level = UnitLevel('player') or 1
 local raceId = select(3, UnitRace('player')) or 0
 local classId = select(3, UnitClass('player')) or 0
 for id, q in pairs(FT.DBQ or {}) do
  local req = q[4] or 1
  if req <= level and hasBit(q[6], raceId - 1) and hasBit(q[7], classId - 1) and q[2] and not inLog(id) and not completed(id) then
   local ok = true
   if type(q[11]) == 'table' and #q[11] > 0 then
    ok = false
    for _, p in ipairs(q[11]) do if completed(p) then ok = true; break end end
   end
   if ok and type(q[10]) == 'table' then for _, p in ipairs(q[10]) do if not completed(p) then ok = false; break end end end
   if ok and type(q[12]) == 'table' then for _, p in ipairs(q[12]) do if completed(p) or inLog(p) then ok = false; break end end end
   if ok and type(q[15]) == 'number' and q[15] > 0 and (completed(q[15]) or inLog(q[15])) then ok = false end
   if ok and type(q[14]) == 'table' then ok = false end -- meslek gerektirenleri listelemiyoruz
   if ok then out[id] = true end
  end
 end
 availCache, availTime = out, GetTime()
 return out
end

local stateEvents = CreateFrame and CreateFrame('Frame')
if stateEvents then for _, e in ipairs({'QUEST_LOG_UPDATE', 'QUEST_ACCEPTED', 'QUEST_TURNED_IN', 'QUEST_REMOVED', 'PLAYER_LEVEL_UP', 'PLAYER_LOGIN'}) do pcall(stateEvents.RegisterEvent, stateEvents, e) end end
if stateEvents then stateEvents:SetScript('OnEvent', function(_, event, a)
 if event == 'QUEST_TURNED_IN' then
  if doneSet and type(a) == 'number' then doneSet[a] = true end
 elseif event == 'PLAYER_LOGIN' then doneSet = nil end
 logSet = nil
 availDirty = true
end) end
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() availDirty = true; availCache = nil end
local Available = setmetatable({}, {__index = function(_, k) if k == '__availableQuests' then return computeAvailable() end end})

local modules = {QuestieDB = DB, ZoneDB = Zone, QuestXP = XP, AvailableQuests = Available}
function FT.Module(name)
 if not FT.DBQ then return nil end
 return modules[name]
end

function FT.DBStats()
 local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
 return count(FT.DBQ), count(FT.DBN), count(FT.DBO), count(FT.DBI)
end
