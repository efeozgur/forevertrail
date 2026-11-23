local _, FT = ...

-- Kendi veri sistemimiz: oynadıkça görev başlangıcı, teslim yeri ve hedef noktalarını öğrenir.
-- Hiçbir dış eklentiye ihtiyaç duymaz. Sorgular önce öğrenilen veriye, sonra eklentiyle gelen tohuma bakar.

local MAX_POINTS = 40

local function store()
 ForeverTrailData = ForeverTrailData or {}
 ForeverTrailData.quests = ForeverTrailData.quests or {}
 return ForeverTrailData.quests
end

local function learning() return not ForeverTrailSettings or ForeverTrailSettings.learn ~= false end

local function spot()
 if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
 local ok, map = pcall(C_Map.GetBestMapForUnit, 'player')
 if not ok or not map then return nil end
 local got, pos = pcall(C_Map.GetPlayerMapPosition, map, 'player')
 if not got or not pos then return nil end
 local valid, x, y = pcall(function() return pos:GetXY() end)
 if not valid or type(x) ~= 'number' or (x == 0 and y == 0) then return nil end
 return map, math.floor(x * 10000 + 0.5) / 10000, math.floor(y * 10000 + 0.5) / 10000
end

local function entry(id)
 local q = store()
 q[id] = q[id] or {}
 return q[id]
end

-- Öğrenilen + tohum birleşik kayıt
local function record(id)
 local learned = ForeverTrailData and ForeverTrailData.quests and ForeverTrailData.quests[id]
 local seed = FT.SeedData and FT.SeedData.quests and FT.SeedData.quests[id]
 if not learned then return seed end
 if not seed then return learned end
 return {t=learned.t or seed.t, l=learned.l or seed.l, s=learned.s or seed.s, f=learned.f or seed.f, o=learned.o or seed.o}
end
FT.OwnRecord = record

local function addPoint(list, map, x, y)
 for _, p in ipairs(list) do
  if p[1] == map and math.abs(p[2] - x) < 0.008 and math.abs(p[3] - y) < 0.008 then return end
 end
 list[#list + 1] = {map, x, y}
 while #list > MAX_POINTS do table.remove(list, 1) end
end

----------------------------------------------------------------------
-- Öğrenme
----------------------------------------------------------------------
local function currentQuestId()
 local id = GetQuestID and GetQuestID()
 if type(id) == 'number' and id > 0 then return id end
end

local learnFinish
local function learnStart(id, title, level)
 local map, x, y = spot()
 if not (id and map) then return end
 local e = entry(id)
 e.t = title or e.t
 e.l = level or e.l
 e.s = {map, x, y, UnitName and UnitName('npc') or nil}
end

function FT.OwnLearnDetail()
 if learning() then pcall(learnStart, currentQuestId(), GetTitleText and GetTitleText(), nil) end
end

function FT.OwnLearnComplete()
 if learning() then pcall(function() learnFinish(currentQuestId()) end) end
end

learnFinish = function(id)
 local map, x, y = spot()
 if not (id and map) then return end
 entry(id).f = {map, x, y, UnitName and UnitName('npc') or nil}
end

local counts = {}
local function learnProgress()
 local q = C_QuestLog
 if not (q and q.GetNumQuestLogEntries and q.GetInfo and q.GetQuestObjectives) then return end
 local map, x, y = spot()
 for i = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(i)
  if info and not info.isHeader and info.questID and info.questID > 0 then
   local ok, rows = pcall(q.GetQuestObjectives, info.questID)
   if ok and type(rows) == 'table' then
    for index, row in ipairs(rows) do
     local key = info.questID .. ':' .. index
     local have = row.numFulfilled or 0
     if counts[key] and have > counts[key] and map then
      local e = entry(info.questID)
      e.t = e.t or info.title
      e.l = e.l or info.level
      e.o = e.o or {}
      e.o[index] = e.o[index] or {}
      addPoint(e.o[index], map, x, y)
     end
     counts[key] = have
    end
   end
  end
 end
end

-- Görev verenin sunduğu ama henüz alınmamış görevler
local function learnOffered()
 local G = C_GossipInfo
 if not (G and G.GetAvailableQuests) then return end
 local map, x, y = spot()
 if not map then return end
 for _, q in ipairs(G.GetAvailableQuests() or {}) do
  if q.questID and q.questID > 0 then
   local e = entry(q.questID)
   e.t = e.t or q.title
   e.l = e.l or q.questLevel
   e.s = e.s or {map, x, y, UnitName and UnitName('npc') or nil}
  end
 end
end

----------------------------------------------------------------------
-- Sorgular
----------------------------------------------------------------------
local function nearest(list)
 local map, px, py = spot()
 local best, bestD
 for _, p in ipairs(list or {}) do
  local d = (map and p[1] == map) and ((p[2] - px) ^ 2 + (p[3] - py) ^ 2) or 9 + (p[2] or 0)
  if not bestD or d < bestD then best, bestD = p, d end
 end
 return best
end

-- kind: 'accept' | 'turnin' | 'objective'. Dönüş: map, x, y
function FT.OwnQuestPoint(id, kind, objective)
 local r = id and record(id)
 if not r then return nil end
 local p
 if kind == 'turnin' then p = r.f
 elseif kind == 'objective' then
  local lists = r.o or {}
  p = nearest(lists[objective or 1]) or nearest(lists[1])
  if not p then for _, l in pairs(lists) do p = nearest(l); if p then break end end end
 else p = r.s end
 if p then return p[1], p[2], p[3] end
end

-- Hedef bölgesi noktaları: {map, x, y} listesi (harita halkası ve hedef kartı için)
function FT.OwnObjectivePoints(id, objective)
 local r = id and record(id)
 local out = {}
 if not (r and r.o) then return out end
 for _, p in ipairs(r.o[objective or 1] or r.o[1] or {}) do out[#out + 1] = {map=p[1], x=p[2], y=p[3]} end
 return out
end

function FT.OwnGiverName(id, kind)
 local r = id and record(id)
 local p = r and (kind == 'turnin' and r.f or r.s)
 return p and p[4]
end

-- Alınabilecek görevler: verilen ama günlükte olmayan ve bitmemiş görevler
function FT.OwnAvailable()
 local out, q = {}, C_QuestLog
 local function each(source)
  for id, r in pairs(source or {}) do
   if type(id) == 'number' and r.s and not out[id] then
    local inLog = q and q.GetLogIndexForQuestID and (q.GetLogIndexForQuestID(id) or 0) > 0
    local done = (q and q.IsQuestFlaggedCompleted and q.IsQuestFlaggedCompleted(id)) or (FT.turnedIn and FT.turnedIn[id])
    if not inLog and not done then out[id] = r end
   end
  end
 end
 each(ForeverTrailData and ForeverTrailData.quests)
 each(FT.SeedData and FT.SeedData.quests)
 return out
end

function FT.OwnStats()
 local quests, points = 0, 0
 for _, r in pairs((ForeverTrailData and ForeverTrailData.quests) or {}) do
  quests = quests + 1
  for _, l in pairs(r.o or {}) do points = points + #l end
 end
 local seed = 0
 for _ in pairs((FT.SeedData and FT.SeedData.quests) or {}) do seed = seed + 1 end
 return quests, points, seed
end

----------------------------------------------------------------------
-- Dışa / içe aktarma (Data.lua'ya gömmek veya arkadaşla paylaşmak için)
----------------------------------------------------------------------
local function num(v) return (('%.4f'):format(v):gsub('0+$', ''):gsub('%.$', '')) end
local function point(p)
 local s = ('{%d,%s,%s'):format(p[1], num(p[2]), num(p[3]))
 if p[4] then s = s .. (',%q'):format(p[4]) end
 return s .. '}'
end

function FT.ExportOwnData()
 local parts = {}
 for id, r in pairs((ForeverTrailData and ForeverTrailData.quests) or {}) do
  local fields = {}
  if r.t then fields[#fields + 1] = ('t=%q'):format(r.t) end
  if r.l then fields[#fields + 1] = ('l=%d'):format(r.l) end
  if r.s then fields[#fields + 1] = 's=' .. point(r.s) end
  if r.f then fields[#fields + 1] = 'f=' .. point(r.f) end
  if r.o then
   local objs = {}
   for i, list in pairs(r.o) do
    local pts = {}
    for _, p in ipairs(list) do pts[#pts + 1] = point(p) end
    objs[#objs + 1] = ('[%d]={%s}'):format(i, table.concat(pts, ','))
   end
   fields[#fields + 1] = 'o={' .. table.concat(objs, ',') .. '}'
  end
  parts[#parts + 1] = ('[%d]={%s}'):format(id, table.concat(fields, ','))
 end
 table.sort(parts)
 return 'FTDATA1{' .. table.concat(parts, ',') .. '}'
end

function FT.ImportOwnData(text)
 if type(text) ~= 'string' or not text:match('^%s*FTDATA1{') then return false, 'Geçersiz veri metni.' end
 local body = text:match('^%s*FTDATA1(%b{})')
 if not body or body:find('[^%w%s%{%}%[%]=,%.%-"\'_:%(%)!%?çğıöşüÇĞİÖŞÜ]') then return false, 'Veri metni beklenmeyen karakter içeriyor.' end
 local fn = loadstring and loadstring('return ' .. body)
 if not fn then return false, 'Veri okunamadı.' end
 setfenv(fn, {})
 local ok, data = pcall(fn)
 if not ok or type(data) ~= 'table' then return false, 'Veri okunamadı.' end
 local added = 0
 for id, r in pairs(data) do
  if type(id) == 'number' and type(r) == 'table' then
   local e = entry(id)
   e.t, e.l = e.t or r.t, e.l or r.l
   e.s, e.f = e.s or r.s, e.f or r.f
   if type(r.o) == 'table' then
    e.o = e.o or {}
    for i, list in pairs(r.o) do
     e.o[i] = e.o[i] or {}
     for _, p in ipairs(list) do if type(p) == 'table' and p[1] then addPoint(e.o[i], p[1], p[2], p[3]) end end
    end
   end
   added = added + 1
  end
 end
 return true, ('%d görev verisi eklendi.'):format(added)
end

local transfer
function FT.ToggleDataWindow()
 if not transfer then
  transfer = FT.NewWindow('ForeverTrailDataWindow', UIParent)
  transfer:SetSize(380, 150); transfer:SetPoint('CENTER'); transfer:SetFrameStrata('DIALOG')
  transfer:SetMovable(true); transfer:EnableMouse(true); transfer:RegisterForDrag('LeftButton')
  transfer:SetScript('OnDragStart', function(self) self:StartMoving() end)
  transfer:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
  local title = transfer:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  title:SetPoint('TOP', 0, -7); title:SetText('Görev verisi')
  if FT.StyleTitle then FT.StyleTitle(title) end
  transfer.info = transfer:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  transfer.info:SetPoint('TOPLEFT', 14, -30); transfer.info:SetWidth(352); transfer.info:SetJustifyH('LEFT')
  local box = (FT.Kit and FT.Kit.Input(transfer) or CreateFrame('EditBox', nil, transfer, 'InputBoxTemplate'))
  box:SetSize(340, 22); box:SetPoint('TOP', 0, -70); box:SetAutoFocus(false); box:SetMaxLetters(0)
  box:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
  local function btn(text, x, fn)
   local b = FT.NewButton(transfer, text, 110, 24)
   b:SetPoint('BOTTOMLEFT', x, 14); b:SetScript('OnClick', fn)
  end
  btn('Dışa aktar', 14, function() box:SetText(FT.ExportOwnData()); box:SetFocus(); box:HighlightText(); FT.Print('Ctrl+C ile kopyala.') end)
  btn('İçe aktar', 134, function() local _, msg = FT.ImportOwnData(box:GetText()); FT.Print(msg); transfer:Hide(); transfer:Show() end)
  btn('Kapat', 254, function() transfer:Hide() end)
  transfer:SetScript('OnShow', function()
   local q, p, seed = FT.OwnStats()
   transfer.info:SetText(('Öğrenilen: %d görev, %d hedef noktası. Eklentiyle gelen: %d görev.\nOynadıkça görev verenler, teslim yerleri ve hedef noktaları kaydedilir.'):format(q, p, seed))
  end)
  transfer:Hide()
  if FT.ApplyFont then pcall(FT.ApplyFont) end
 end
 if transfer:IsShown() then transfer:Hide() else transfer:Show() end
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local events = CreateFrame('Frame')
for _, e in ipairs({'QUEST_DETAIL', 'QUEST_COMPLETE', 'GOSSIP_SHOW', 'QUEST_LOG_UPDATE', 'PLAYER_ENTERING_WORLD'}) do
 pcall(events.RegisterEvent, events, e)
end
local pending = false
events:SetScript('OnEvent', function(_, event)
 if not learning() then return end
 local ok, err = pcall(function()
  if event == 'QUEST_DETAIL' then learnStart(currentQuestId(), GetTitleText and GetTitleText(), nil)
  elseif event == 'QUEST_COMPLETE' then learnFinish(currentQuestId())
  elseif event == 'GOSSIP_SHOW' then learnOffered()
  elseif event == 'PLAYER_ENTERING_WORLD' then counts = {}; learnProgress()
  elseif event == 'QUEST_LOG_UPDATE' and not pending then
   pending = true
   local run = function() pending = false; pcall(learnProgress) end
   if C_Timer and C_Timer.After then C_Timer.After(0.3, run) else run() end
  end
 end)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'data: ' .. tostring(err) end
end)
