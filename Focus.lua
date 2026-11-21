local _, FT = ...

-- Odak görevi, NPC yürüyüş yolları, grup ipucu ve haritası, ilerleme duyurusu,
-- yol açan görevleri bırakma, arama. Tamamı ForeverTrail kodu.

local function on(key) return ForeverTrailSettings and ForeverTrailSettings[key] ~= false end
local function optIn(key) return ForeverTrailSettings and ForeverTrailSettings[key] == true end

local function module(name)
 if FT.Module then local own = FT.Module(name) if own then return own end end
 if not (QuestieLoader and QuestieLoader.ImportModule) then return nil end
 local ok, result = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
 if ok then return result end
end

local function query(kind, id, key)
 local db = module('QuestieDB')
 local fn = db and (kind == 'npc' and db.QueryNPCSingle or db.QueryQuestSingle)
 if not fn then return nil end
 local ok, value = pcall(fn, id, key)
 if ok then return value end
end

----------------------------------------------------------------------
-- 1) Odak görevi: diğer görev işaretleri soluklaşır
----------------------------------------------------------------------
function FT.ToggleFocus(questId)
 if FT.focusQuest == questId then FT.focusQuest = nil; FT.Print('Odak kaldırıldı.')
 else
  FT.focusQuest = questId
  FT.Print('Odak görevi seçildi; diğer görev işaretleri soluklaştı. Kaldırmak için tekrar sağ tıkla.')
  if FT.SelectQuestTarget then pcall(FT.SelectQuestTarget, questId, true) end -- ok da bu göreve yönelsin
 end
 if FT.RefreshTracker then FT.RefreshTracker() end
 if FT.RefreshMap then pcall(FT.RefreshMap) end
end

function FT.FocusAlpha(questId, normal)
 if FT.focusQuest and questId ~= FT.focusQuest then return 0.18 end
 return normal
end

----------------------------------------------------------------------
-- 2) NPC yürüyüş yolları (gezgin görev NPC'leri)
----------------------------------------------------------------------
local pathLines, pathCache = {}, {}
local function pathsFor(npcId)
 if pathCache[npcId] ~= nil then return pathCache[npcId] or nil end
 local result = false
 local raw = query('npc', npcId, 'waypoints')
 local zoneDB = module('ZoneDB')
 if type(raw) == 'table' and zoneDB then
  result = {}
  for areaId, routes in pairs(raw) do
   local ok, uiMap = pcall(zoneDB.GetUiMapIdByAreaId, zoneDB, areaId)
   if ok and uiMap and type(routes) == 'table' then
    for _, route in ipairs(routes) do
     if type(route) == 'table' and #route > 1 then result[#result + 1] = {map=uiMap, points=route} end
    end
   end
  end
 end
 pathCache[npcId] = result
 return result or nil
end

function FT.DrawPaths(mapID, step)
 for _, l in ipairs(pathLines) do l:Hide() end
 if not on('npcpaths') then return end
 local parts = FT.mapParts
 local overlay = parts and parts.overlay
 if not (overlay and step and FT.TargetsFor) then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local used = 0
 for _, t in ipairs(FT.TargetsFor(step)) do
  if t.kind == 'npc' then
   for _, route in ipairs(pathsFor(t.id) or {}) do
    if route.map == mapID then
     for i = 1, #route.points - 1 do
      local a, b = route.points[i], route.points[i + 1]
      if type(a) == 'table' and type(b) == 'table' and used < 300 then
       used = used + 1
       local line = pathLines[used]
       if not line then line = overlay:CreateLine(nil, 'ARTWORK'); line:SetThickness(2); pathLines[used] = line end
       line:SetColorTexture(0.6, 0.9, 1, 0.75)
       line:SetStartPoint('TOPLEFT', overlay, a[1] / 100 * w, -a[2] / 100 * h)
       line:SetEndPoint('TOPLEFT', overlay, b[1] / 100 * w, -b[2] / 100 * h)
       line:Show()
      end
     end
    end
   end
  end
 end
end

----------------------------------------------------------------------
-- 4) Grubun görevleri haritada (gruptakilerde ForeverTrail olmalı)
----------------------------------------------------------------------
local partyDots = {}
function FT.DrawPartyQuests(mapID)
 for _, d in ipairs(partyDots) do d:Hide() end
 if not on('partymap') or not FT.PartyQuests then return end
 local parts = FT.mapParts
 local overlay = parts and parts.overlay
 if not (overlay and FT.ResolveQuestWaypoint) then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local used = 0
 for name, quests in pairs(FT.PartyQuests()) do
  for questId, state in pairs(quests) do
   if state ~= 'T' and used < 40 then
    local ok, map, x, y = pcall(FT.ResolveQuestWaypoint, questId, 'objective', 1)
    if ok and map == mapID and x and y then
     used = used + 1
     local d = partyDots[used]
     if not d then
      d = overlay:CreateTexture(nil, 'ARTWORK')
      d:SetTexture('Interface\\Cooldown\\star4'); d:SetSize(14, 14)
      partyDots[used] = d
     end
     d:SetVertexColor(0.45, 0.75, 1, 0.95)
     d:ClearAllPoints(); d:SetPoint('CENTER', overlay, 'TOPLEFT', x * w, -y * h)
     local title = query('quest', questId, 'name') or ('Görev ' .. questId)
     d.step = {x=x, y=y, uiMapID=map, questTitle=title, text=name .. ': ' .. state, type='manual'}
     d:Show()
    end
   end
  end
 end
end
FT.partyDots = partyDots

----------------------------------------------------------------------
-- 5) İlerlemeyi gruba duyur
----------------------------------------------------------------------
function FT.AnnounceProgress(text, have, need, done)
 if not optIn('announce') then return end
 local channel = (IsInRaid and IsInRaid()) and 'RAID' or ((IsInGroup and IsInGroup()) and 'PARTY' or nil)
 if not channel then return end
 local msg = done and ('[ForeverTrail] Tamamlandı: %s'):format(text) or ('[ForeverTrail] %s %d/%d'):format(text, have, need)
 pcall(SendChatMessage, msg:sub(1, 250), channel)
end

----------------------------------------------------------------------
-- 6) Yol açan (breadcrumb) görevleri bırak — varsayılan kapalı
----------------------------------------------------------------------
local function abandonBreadcrumbs(acceptedId)
 if not optIn('breadcrumbs') then return end
 local list = query('quest', acceptedId, 'breadcrumbs')
 if type(list) ~= 'table' then return end
 local q = C_QuestLog
 for _, id in ipairs(list) do
  local index = q and q.GetLogIndexForQuestID and q.GetLogIndexForQuestID(id)
  if index and index > 0 and SelectQuestLogEntry and SetAbandonQuest and AbandonQuest then
   local title = query('quest', id, 'name') or id
   SelectQuestLogEntry(index); SetAbandonQuest(); AbandonQuest()
   FT.Print(('Yol açan görev bırakıldı: %s (asıl görevi aldın).'):format(title))
  end
 end
end

----------------------------------------------------------------------
-- 7) Arama: günlük, rehber adımları ve kayıtlı yerler
----------------------------------------------------------------------
function FT.Search(text)
 local results = {}
 text = (text or ''):lower()
 if #text < 2 then return results end
 local seen = {}
 local function match(name) return type(name) == 'string' and name:lower():find(text, 1, true) end
 local q = C_QuestLog
 if q and q.GetNumQuestLogEntries then
  for i = 1, q.GetNumQuestLogEntries() do
   local info = q.GetInfo(i)
   if info and not info.isHeader and info.questID and info.questID > 0 then
    local tr = QTR_QuestData and QTR_QuestData[tostring(info.questID)]
    local title = tr and tr.Title or info.title
    if match(title) or match(info.title) then
     local ok, map, x, y = pcall(FT.ResolveQuestWaypoint, info.questID, 'objective', 1)
     if ok and map and x then results[#results + 1] = {name=title, cat='Günlük görevi', map=map, x=x, y=y}; seen[info.questID] = true end
    end
   end
  end
 end
 for _, guide in ipairs(FT.validGuides or {}) do
  for _, s in ipairs(guide.steps or {}) do
   if #results < 40 and s.uiMapID and s.x and (match(s.questTitle) or match(s.text)) and not (s.questId and seen[s.questId]) then
    if s.questId then seen[s.questId] = true end
    results[#results + 1] = {name=s.questTitle or s.text, cat='Rehber adımı', map=s.uiMapID, x=s.x, y=s.y}
   end
  end
 end
 for _, p in ipairs(ForeverTrailSettings.places or {}) do
  if #results < 60 and match(p.name) then results[#results + 1] = {name=p.name, cat=p.cat, map=p.map, x=p.x, y=p.y} end
 end
 for _, n in ipairs(ForeverTrailSettings.gatherNodes or {}) do
  if #results < 60 and match(n.name) then results[#results + 1] = {name=n.name, cat=n.kind == 'herb' and 'Bitki' or 'Maden', map=n.map, x=n.x, y=n.y} end
 end
 return results
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local events = CreateFrame('Frame')
pcall(events.RegisterEvent, events, 'QUEST_ACCEPTED')
events:SetScript('OnEvent', function(_, _, a, b)
 local id = (type(b) == 'number' and b > 0) and b or a
 if type(id) == 'number' and id > 0 then pcall(abandonBreadcrumbs, id) end
end)
