local _, FT = ...

-- Canlı veri: QuestieDB eklentisi (LibQuestieDB) kuruluysa, gömülü FT.DBQ/DBN/DBO/DBI satırlarının
-- üzerine onun güncel verisi yazılır. Gömülü veri yedek olarak kalır; QuestieDB'de olmayan satırlar
-- (ForeverTrail'in kendi eklemeleri) olduğu gibi korunur. Satır düzeni OwnDB.lua'daki QK/NK/OK/IK ile aynıdır,
-- bu yüzden Atlas/Journey/Class gibi tabloyu doğrudan dolaşan modüller değişmeden çalışır.
-- Yükleme sırası: QuestieDB, ForeverTrail'den sonra yüklenir; bu yüzden eşitleme PLAYER_LOGIN'de başlar.

local PER_FRAME = 250 -- kare başına işlenen kayıt (oyun donmasın)

local function flatten(spawns)
 if type(spawns) ~= 'table' then return nil end
 local out
 for area, pts in pairs(spawns) do
  local flat = {}
  for _, p in ipairs(pts) do
   if type(p[1]) == 'number' and type(p[2]) == 'number' then
    flat[#flat + 1] = math.floor(p[1] * 10 + 0.5)
    flat[#flat + 1] = math.floor(p[2] * 10 + 0.5)
   end
  end
  if #flat > 0 then out = out or {}; out[area] = flat end
 end
 return out
end
local function flattenPaths(paths)
 if type(paths) ~= 'table' then return nil end
 local out
 for area, routes in pairs(paths) do
  local rs = {}
  for _, route in ipairs(routes) do
   local flat = {}
   for _, p in ipairs(route) do
    if type(p[1]) == 'number' and type(p[2]) == 'number' then
     flat[#flat + 1] = math.floor(p[1] * 10 + 0.5)
     flat[#flat + 1] = math.floor(p[2] * 10 + 0.5)
    end
   end
   if #flat > 0 then rs[#rs + 1] = flat end
  end
  if #rs > 0 then out = out or {}; out[area] = rs end
 end
 return out
end

-- Sütun adı listesi = gömülü satırdaki sıra (OwnDB.lua ile aynı)
local QUEST = {'name','startedBy','finishedBy','requiredLevel','questLevel','requiredRaces','requiredClasses','objectivesText','objectives',
 'preQuestGroup','preQuestSingle','exclusiveTo','zoneOrSort','requiredSkill','nextQuestInChain','specialFlags','breadcrumbForQuestId','breadcrumbs','sourceItemId'}
local NPC = {'name','minLevel','maxLevel','rank','spawns','waypoints','zoneID','questStarts','questEnds','friendlyToFaction','subName','npcFlags'}
local OBJECT = {'name','questStarts','questEnds','spawns','zoneID'}
local ITEM = {'name','npcDrops','objectDrops','startQuest','questRewards','itemLevel','requiredLevel','class','subClass'}

local function build(entity, cols, id)
 local row = {}
 for i, key in ipairs(cols) do
  local v = entity.Get(id, key)
  if key == 'spawns' then v = flatten(v)
  elseif key == 'waypoints' then v = flattenPaths(v)
  elseif key == 'objectivesText' then
   if type(v) == 'table' then v = table.concat(v, ' ') end
   if v == '' then v = nil end
  end
  row[i] = v
 end
 return row
end

-- Tablo, QuestieDB varlığı, sütunlar
local JOBS = {
 {name = 'quests', target = 'DBQ', lib = 'Quest', cols = QUEST},
 {name = 'npcs', target = 'DBN', lib = 'Npc', cols = NPC},
 {name = 'objects', target = 'DBO', lib = 'Object', cols = OBJECT},
 {name = 'items', target = 'DBI', lib = 'Item', cols = ITEM},
}

FT.live = {state = 'idle', counts = {}, errors = 0}
FT.liveListeners = FT.liveListeners or {}

local function finish(ok, reason)
 FT.live.state = ok and 'done' or 'failed'
 FT.live.reason = reason
 for _, fn in ipairs(FT.liveListeners) do pcall(fn, FT.live) end
end

function FT.StartLiveSync()
 if FT.live.state == 'running' then return end
 if ForeverTrailSettings and ForeverTrailSettings.noLive then FT.live.state = 'disabled'; return end
 local lib = _G.LibQuestieDB
 if type(lib) ~= 'table' then FT.live.state = 'absent'; return end
 if lib.RequireContract then
  local ok, msg = lib.RequireContract(4)
  if not ok then finish(false, msg); return end
 end
 FT.live.state = 'running'
 FT.live.version = lib.contractVersion
 local job, ids, pos = 1, nil, 1
 local frame = FT.liveFrame or CreateFrame('Frame')
 FT.liveFrame = frame
 frame:SetScript('OnUpdate', function(self)
  local ok, err = pcall(function()
   local j = JOBS[job]
   if not j then self:SetScript('OnUpdate', nil); finish(true); return end
   local entity = lib[j.lib]
   if not entity then job = job + 1; return end
   if not ids then ids = entity.GetAllIds(); pos = 1; FT[j.target] = FT[j.target] or {}; FT.live.counts[j.name] = 0 end
   local target, last = FT[j.target], math.min(pos + PER_FRAME - 1, #ids)
   for i = pos, last do
    local id = ids[i]
    -- Çözülemeyen kayıt gömülü satırı bozmasın
    local rowOk, row = pcall(build, entity, j.cols, id)
    if rowOk and row[1] ~= nil then target[id] = row; FT.live.counts[j.name] = FT.live.counts[j.name] + 1
    else
     FT.live.errors = FT.live.errors + 1
     local bad = FT.live.bad or {}; FT.live.bad = bad
     if #bad < 12 then bad[#bad + 1] = j.name .. ':' .. tostring(id) .. (rowOk and ' (ad yok)' or ' (' .. tostring(row):sub(1, 90) .. ')') end
    end
   end
   pos = last + 1
   if pos > #ids then job = job + 1; ids = nil end
  end)
  if not ok then self:SetScript('OnUpdate', nil); finish(false, tostring(err)) end
 end)
end

function FT.LiveStatus()
 local l = FT.live
 local c = l.counts
 FT.Print(('canlı veri: %s%s | görev %s npc %s nesne %s eşya %s | hata %d'):format(l.state, l.reason and (' (' .. tostring(l.reason) .. ')') or '',
  tostring(c.quests or 0), tostring(c.npcs or 0), tostring(c.objects or 0), tostring(c.items or 0), l.errors))
 for _, b in ipairs(l.bad or {}) do FT.Print('  atlandı: ' .. b) end
end

if CreateFrame then
 local f = CreateFrame('Frame')
 f:RegisterEvent('PLAYER_LOGIN')
 f:SetScript('OnEvent', function() FT.StartLiveSync() end)
end
