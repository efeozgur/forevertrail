local _, FT = ...

-- Görev işaretleme ve yönlendirme 2:
-- akıllı rota (numaralı, en kısa sıra, süre), nesne ipucu, grup ilerlemesi, uçuş önerisi, yaklaşma sesi,
-- ölüm danışmanı, oturum hedefi, görev bırakma danışmanı, "bu bölge bana uygun mu?"

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function optedIn(key) return ForeverTrailSettings and ForeverTrailSettings[key] == true end
local function db() return FT.Module and FT.Module('QuestieDB') end
local function after(s, fn) if C_Timer and C_Timer.After then C_Timer.After(s, fn) else fn() end end
local BLOB = 'Interface\\CHARACTERFRAME\\TempPortraitAlphaMask'
local RUN = 7 -- yd/sn yürüyüş

local function here()
 if not (C_Map and C_Map.GetBestMapForUnit) then return end
 local map = C_Map.GetBestMapForUnit('player')
 local pos = map and C_Map.GetPlayerMapPosition(map, 'player')
 if not pos then return end
 local x, y = pos:GetXY()
 local ok, ww, wh = pcall(C_Map.GetMapWorldSize, map)
 if not ok or not ww or ww <= 0 then return end
 return map, x, y, ww, wh
end

----------------------------------------------------------------------
-- 1) Akıllı rota: aktif görevleri en kısa sırayla gez
----------------------------------------------------------------------
local routeCache, routeTime, routeMap = nil, -100, nil
FT.RouteNumber = {}
function FT.RouteOrder()
 local map, px, py, ww, wh = here()
 if not map then return {}, 0 end
 if routeCache and routeMap == map and GetTime() - routeTime < 3 then return routeCache, routeCache.total end
 local q = C_QuestLog
 local pts = {}
 local partySet = {}
 for _, quests in pairs(FT.PartyQuests and FT.PartyQuests() or {}) do for qid in pairs(quests) do partySet[qid] = true end end
 if q and q.GetNumQuestLogEntries then
  local okA, areas = pcall(FT.ObjectiveAreas, map)
  local byQuest = {}
  for _, a in ipairs(okA and areas or {}) do byQuest[a.o.questId] = byQuest[a.o.questId] or {}; for _, g in ipairs(a.groups) do table.insert(byQuest[a.o.questId], g) end end
  for i = 1, q.GetNumQuestLogEntries() do
   local info = q.GetInfo(i)
   local id = info and not info.isHeader and info.questID
   if id and id > 0 then
    local best, bd
    if q.IsComplete and q.IsComplete(id) and FT.GiverPoints then
     for _, p in ipairs(FT.GiverPoints(id, map, true)) do
      local d = ((p.x - px) * ww) ^ 2 + ((p.y - py) * wh) ^ 2
      if not bd or d < bd then best, bd = {x = p.x, y = p.y, kind = '?'}, d end
     end
    else
     for _, g in ipairs(byQuest[id] or {}) do
      local d = ((g.x - px) * ww) ^ 2 + ((g.y - py) * wh) ^ 2
      if not bd or d < bd then best, bd = {x = g.x, y = g.y, kind = '!'}, d end
     end
    end
    if best then
     best.questId = id
     best.shared = partySet[id] and 1 or 0
     pts[#pts + 1] = best
    end
   end
  end
 end
 -- en yakın komşu; grupla ortak görevler biraz öne
 local out, cx, cy, total = {}, px, py, 0
 local left = pts
 while #left > 0 do
  local bi, bd
  for i, p in ipairs(left) do
   local d = math.sqrt(((p.x - cx) * ww) ^ 2 + ((p.y - cy) * wh) ^ 2)
   local w = d * (((p.shared or 0) > 0 and on('partyfirst')) and 0.7 or 1)
   if not bd or w < bd then bi, bd = i, w end
  end
  local p = table.remove(left, bi)
  p.leg = math.sqrt(((p.x - cx) * ww) ^ 2 + ((p.y - cy) * wh) ^ 2)
  total = total + p.leg
  p.map = map
  out[#out + 1] = p
  cx, cy = p.x, p.y
 end
 FT.RouteNumber = {}
 for i, p in ipairs(out) do FT.RouteNumber[p.questId] = i end
 out.total = total
 routeCache, routeTime, routeMap = out, GetTime(), map
 return out, total
end

function FT.RouteSummary()
 local list, total = FT.RouteOrder()
 if #list == 0 then return nil end
 local min = math.floor(total / RUN / 60 + 0.5)
 return ('Rota: %d durak · %d yd · ~%d dk yürüme'):format(#list, total, math.max(1, min))
end

local nums, numLines = {}, {}
function FT.DrawRouteNumbers(mapID)
 for _, n in ipairs(nums) do n:Hide() end
 for _, l in ipairs(numLines) do l:Hide() end
 local overlay = FT.mapParts and FT.mapParts.overlay
 if not (overlay and on('routenums')) then return end
 local list = FT.RouteOrder()
 if #list == 0 or list[1].map ~= mapID then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local prev
 for i, p in ipairs(list) do
  if i > 15 then break end
  local n = nums[i]
  if not n then
   n = CreateFrame('Frame', nil, overlay); n:SetSize(18, 18)
   n.bg = n:CreateTexture(nil, 'ARTWORK'); n.bg:SetTexture(BLOB); n.bg:SetAllPoints()
   n.t = n:CreateFontString(nil, 'OVERLAY'); n.t:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', 11, 'OUTLINE'); n.t:SetPoint('CENTER', 0, 0)
   nums[i] = n
  end
  local c = FT.QuestColor and FT.QuestColor(i) or {1, 0.8, 0.2}
  n.bg:SetVertexColor(0, 0, 0, 0.85)
  n.t:SetText(i); n.t:SetTextColor(p.kind == '?' and 0.4 or 1, p.kind == '?' and 1 or 0.9, p.kind == '?' and 0.4 or 0.4)
  n:SetFrameLevel(overlay:GetFrameLevel() + 8)
  n:ClearAllPoints(); n:SetPoint('CENTER', overlay, 'TOPLEFT', p.x * w + 12, -p.y * h + 12)
  n:Show()
  if prev and overlay.CreateLine then
   local l = numLines[i]
   if not l then l = overlay:CreateLine(nil, 'ARTWORK'); l:SetThickness(1.5); numLines[i] = l end
   l:SetColorTexture(1, 1, 1, 0.35)
   l:SetStartPoint('TOPLEFT', overlay, prev.x * w, -prev.y * h)
   l:SetEndPoint('TOPLEFT', overlay, p.x * w, -p.y * h)
   l:Show()
  end
  prev = p
 end
end

----------------------------------------------------------------------
-- 2) Nesne ipucu (sandık, bitki, kutu) ve grup ilerlemesi
----------------------------------------------------------------------
local function objectLines(tip)
 if not on('objtips') or (tip.GetUnit and tip:GetUnit()) or (tip.GetItem and tip:GetItem()) then return end
 local line = _G[tip:GetName() .. 'TextLeft1']
 local name = line and line:GetText()
 if not name or name == '' then return end
 for _, o in ipairs(FT.ActiveObjectives and FT.ActiveObjectives() or {}) do
  if o.name == name and not o.done then
   local done = o.need and o.need > 0 and o.have >= o.need
   local r, g, b = 1, 0.82, 0
   if FT.ProgressColor then r, g, b = FT.ProgressColor(o.have, o.need, done) end
   tip:AddLine(('Görev: %s'):format(FT.QuestTitle and FT.QuestTitle(o.questId) or o.title or ''), 1, 0.82, 0.3)
   if o.need and o.need > 0 then tip:AddLine(('  %d/%d'):format(o.have or 0, o.need), r, g, b) end
   tip:Show()
   return
  end
 end
end
if GameTooltip then pcall(GameTooltip.HookScript, GameTooltip, 'OnShow', function(tip) pcall(objectLines, tip) end) end

local function partyLine(tip)
 local _, unit = tip:GetUnit()
 if not unit or not FT.QuestCreatureInfo or not FT.PartyText then return end
 local o = FT.QuestCreatureInfo(unit)
 local text = o and o.questId and FT.PartyText(o.questId)
 if text then tip:AddLine(text, 0.55, 0.8, 1) end
end
if GameTooltip then pcall(GameTooltip.HookScript, GameTooltip, 'OnTooltipSetUnit', function(tip) pcall(partyLine, tip) end) end

----------------------------------------------------------------------
-- 3) Uçuş önerisi: hedef uzaksa en yakın uçuş ustasından hedefe en yakın olana
----------------------------------------------------------------------
local function worldPos(map, x, y)
 if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
 local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
 if not ok or not pos then return nil end
 local wx, wy = pos:GetXY()
 return cont, wx, wy
end

local flightCache
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() flightCache = nil end
local function flightMasters()
 if flightCache then return flightCache end
 flightCache = {}
 local z = FT.Module and FT.Module('ZoneDB')
 local fac = (UnitFactionGroup and UnitFactionGroup('player') == 'Horde') and 'H' or 'A'
 for _, n in pairs(FT.DBN or {}) do
  if type(n[12]) == 'number' and math.floor(n[12] / 8) % 2 == 1 and n[10] and n[10]:find(fac, 1, true) and type(n[5]) == 'table' and z then
   for area, list in pairs(n[5]) do
    local ui = z:GetUiMapIdByAreaId(area)
    if ui and list[1] then
     local cont, wx, wy = worldPos(ui, list[1] / 1000, list[2] / 1000)
     if cont then flightCache[#flightCache + 1] = {name = n[1], map = ui, x = list[1] / 1000, y = list[2] / 1000, cont = cont, wx = wx, wy = wy} end
     break
    end
   end
  end
 end
 return flightCache
end

function FT.FlightSuggestion(map, x, y)
 local pm, px, py = here()
 if not (pm and map) then return nil end
 local c1, ax, ay = worldPos(pm, px, py)
 local c2, bx, by = worldPos(map, x, y)
 if not (c1 and c2) or c1 ~= c2 then return nil end
 local direct = math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
 if direct < 900 then return nil end
 local f1, d1, f2, d2
 for _, f in ipairs(flightMasters()) do
  if f.cont == c1 then
   local da = math.sqrt((f.wx - ax) ^ 2 + (f.wy - ay) ^ 2)
   local db2 = math.sqrt((f.wx - bx) ^ 2 + (f.wy - by) ^ 2)
   if not d1 or da < d1 then f1, d1 = f, da end
   if not d2 or db2 < d2 then f2, d2 = f, db2 end
  end
 end
 if not (f1 and f2) or f1 == f2 or d1 + d2 > direct * 0.6 then return nil end
 return ('Uçuş öner: %s (%d yd) → %s, sonra %d yd'):format(f1.name, d1, f2.name, d2), f1
end

local origSet = FT.SetCustomTarget
if origSet then
 FT.SetCustomTarget = function(map, x, y, name, ...)
  local r = origSet(map, x, y, name, ...)
  if on('flightadvice') then
   local ok, text = pcall(FT.FlightSuggestion, map, x, y)
   if ok and text then FT.Print(text); if FT.Flash then FT.Flash(text, 0.55, 0.85, 1) end end
  end
  return r
 end
end

----------------------------------------------------------------------
-- 4) Yaklaşma sesi
----------------------------------------------------------------------
local beepAcc, beepWait = 0, 0
local function beep(dt)
 if not optedIn('beep') then return end
 beepAcc = beepAcc + dt
 if beepAcc < beepWait then return end
 local step = FT.TargetStep and FT.TargetStep()
 local map, px, py, ww, wh = here()
 if not (step and map and step.uiMapID == map and step.x) then beepWait = 1; beepAcc = 0; return end
 local d = math.sqrt(((step.x - px) * ww) ^ 2 + ((step.y - py) * wh) ^ 2)
 beepAcc = 0
 if d > 90 or d < 6 then beepWait = 1; return end
 beepWait = math.max(0.2, d / 90 * 1.6)
 if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON) or 1115) end
end

----------------------------------------------------------------------
-- 5) Ölüm danışmanı: cesede koşmak mı, ruh iyileştirici mi?
----------------------------------------------------------------------
local function deathAdvice()
 if not on('deathadvice') or not (UnitIsGhost and UnitIsGhost('player')) then return end
 if not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition) then return end
 local map, px, py, ww, wh = here()
 if not map then return end
 local ok, pos = pcall(C_DeathInfo.GetCorpseMapPosition, map)
 if not ok or not pos then return end
 local cx, cy = pos:GetXY()
 if not cx or cx == 0 then return end
 local d = math.sqrt(((cx - px) * ww) ^ 2 + ((cy - py) * wh) ^ 2)
 local secs = d / 10
 local level = UnitLevel('player') or 1
 local healer = level <= 10 and 'Ruh iyileştirici: seviye 10 ve altında cezasız.' or 'Ruh iyileştirici: %25 dayanıklılık kaybı ve diriliş hastalığı.'
 local advise = (secs < 150 or level > 10) and 'Öneri: cesede koş.' or 'Öneri: ruh iyileştiriciden diril.'
 local text = ('Cesedin %d yd uzakta (~%d sn).\n%s\n%s'):format(d, secs, healer, advise)
 if FT.ShowChoice and FT.ShowChoice('Öldün', 'Interface\\Icons\\Spell_Holy_Resurrection', text, 'Cesede yol',
  function() FT.SetCustomTarget(map, cx, cy, 'Cesedin') end) then return end
 FT.Print(text)
end

----------------------------------------------------------------------
-- 6) Oturum hedefi
----------------------------------------------------------------------
local session = {xp = 0, start = nil, startLevel = nil, quests = 0, zones = {}, money = 0}
local lastXP, lastMax
FT.Session = session
local bar
local GOALS = {yarim = 0.5, bir = 1, iki = 2}

local function ensureBar()
 if bar then return bar end
 bar = CreateFrame('Frame', 'ForeverTrailSessionBar', UIParent)
 bar:SetSize(260, 16)
 bar:SetPoint('TOP', UIParent, 'TOP', 0, -24)
 bar.bg = bar:CreateTexture(nil, 'BACKGROUND'); bar.bg:SetAllPoints(); bar.bg:SetColorTexture(0, 0, 0, 0.55)
 bar.fill = bar:CreateTexture(nil, 'ARTWORK'); bar.fill:SetPoint('TOPLEFT'); bar.fill:SetPoint('BOTTOMLEFT'); bar.fill:SetWidth(1)
 bar.text = bar:CreateFontString(nil, 'OVERLAY'); bar.text:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', 11, 'OUTLINE'); bar.text:SetPoint('CENTER')
 bar:EnableMouse(true)
 bar:SetScript('OnMouseUp', function() if FT.Plan then pcall(FT.Plan) end end)
 bar:SetScript('OnEnter', function(self)
  GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
  GameTooltip:SetText('Oturum hedefi', 1, 0.85, 0.5)
  GameTooltip:AddLine('Hedefi Ayarlar > Görev kutusu > Oturum hedefi\'nden seç. Tıkla: XP planı.', 1, 1, 1, true)
  if FT.ShowTip then FT.ShowTip(GameTooltip) else GameTooltip:Show() end
 end)
 bar:SetScript('OnLeave', function() GameTooltip:Hide() end)
 return bar
end

local function avgQuestXP()
 local xp = FT.Module and FT.Module('QuestXP')
 local q = C_QuestLog
 local sum, n = 0, 0
 if xp and q and q.GetNumQuestLogEntries then
  for i = 1, q.GetNumQuestLogEntries() do
   local info = q.GetInfo(i)
   if info and not info.isHeader and info.questID and info.questID > 0 then
    local ok, v = pcall(xp.GetQuestLogRewardXP, xp, info.questID)
    if ok and type(v) == 'number' and v > 0 then sum, n = sum + v, n + 1 end
   end
  end
 end
 return n > 0 and sum / n or nil
end

function FT.UpdateSessionBar()
 local goal = GOALS[ForeverTrailSettings and ForeverTrailSettings.c_sessionGoal or 'yok']
 if not goal or (ForeverTrailSettings and ForeverTrailSettings.simple == true) then if bar then bar:Hide() end return end
 local b = ensureBar()
 local max = UnitXPMax and UnitXPMax('player') or 1
 local need = goal * max
 local frac = math.min(1, session.xp / math.max(1, need))
 local a = FT.Style.accent
 b.fill:SetColorTexture(a[1], a[2], a[3], 0.8); b.fill:SetWidth(math.max(1, 260 * frac))
 local mins = session.start and (GetTime() - session.start) / 60 or 0
 local rate = mins > 3 and session.xp / mins or nil
 local leftXP = math.max(0, need - session.xp)
 local eta = rate and rate > 0 and math.floor(leftXP / rate + 0.5)
 local avg = avgQuestXP()
 local qn = avg and math.ceil(leftXP / avg)
 if frac >= 1 then b.text:SetText('|cff55ff55Oturum hedefi tamam!|r')
 else b.text:SetText(('Hedef %s sv · %%%d%s%s'):format(goal == 0.5 and 'yarım' or goal, frac * 100, eta and (' · ~' .. eta .. ' dk') or '', qn and (' · ~' .. qn .. ' görev') or '')) end
 b:Show()
end

----------------------------------------------------------------------
-- 7) Görev bırakma danışmanı (günlük dolunca)
----------------------------------------------------------------------
local function worstQuest()
 local q = C_QuestLog
 local level = UnitLevel('player') or 1
 local xp = FT.Module and FT.Module('QuestXP')
 local green = GetQuestGreenRange and GetQuestGreenRange() or 8
 local worst, ws, wi
 for i = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(i)
  if info and not info.isHeader and info.questID and info.questID > 0 and not (q.IsComplete and q.IsComplete(info.questID)) then
   local ok, v = pcall(function() return xp and xp:GetQuestLogRewardXP(info.questID) end)
   v = ok and v or 0
   local dist = FT.QuestDistance and FT.QuestDistance(info.questID) or 3000
   local score = (v + 10) / (dist + 300)
   if info.level and info.level < level - green then score = score * 0.2 end
   if (info.suggestedGroup or 0) > 1 then score = score * 0.5 end
   if not ws or score < ws then worst, ws, wi = info, score, i end
  end
 end
 return worst, wi
end

local function abandon(info, index)
 local id = info.questID
 local ok = pcall(function()
  if C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(id) elseif SelectQuestLogEntry then SelectQuestLogEntry(index) end
  if C_QuestLog.SetAbandonQuest then C_QuestLog.SetAbandonQuest() elseif SetAbandonQuest then SetAbandonQuest() end
  if C_QuestLog.AbandonQuest then C_QuestLog.AbandonQuest() elseif AbandonQuest then AbandonQuest() end
 end)
 FT.Print(ok and ('Bırakıldı: ' .. (info.title or id)) or 'Görev bırakılamadı; görev günlüğünden elle bırak.')
end

local function dropCheck()
 if not on('dropadvisor') then return end
 local q = C_QuestLog
 if not (q and q.GetNumQuestLogEntries) then return end
 local count = 0
 for i = 1, q.GetNumQuestLogEntries() do local info = q.GetInfo(i); if info and not info.isHeader then count = count + 1 end end
 local cap = MAX_QUESTLOG_QUESTS or (C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()) or 20
 if count < cap - 1 then return end
 local info, index = worstQuest()
 if not info then return end
 FT.ShowChoice('Görev günlüğü dolu', 'Interface\\Icons\\INV_Misc_Note_01',
  ('%d/%d görev. En az verimli olan:\n[%s] %s\nBırakılsın mı?'):format(count, cap, info.level or '?', info.title or ''), 'Bırak',
  function() abandon(info, index) end)
end
FT.QuestDropCheck = dropCheck

----------------------------------------------------------------------
-- 8) Bu bölge bana uygun mu?
----------------------------------------------------------------------
local zoneLevels
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() zoneLevels = nil end
local function buildZoneLevels()
 zoneLevels = {}
 local z = FT.Module and FT.Module('ZoneDB')
 local raceId = select(3, UnitRace('player')) or 0
 local function hasBit(mask, bit) if type(mask) ~= 'number' or mask == 0 then return true end return math.floor(mask / 2 ^ bit) % 2 == 1 end
 for _, q in pairs(FT.DBQ or {}) do
  local area, ql = q[13], q[5] or q[4]
  if type(area) == 'number' and area > 0 and type(ql) == 'number' and ql > 0 and hasBit(q[6], raceId - 1) and z then
   local ui = z:GetUiMapIdByAreaId(area)
   if ui then zoneLevels[ui] = zoneLevels[ui] or {}; table.insert(zoneLevels[ui], ql) end
  end
 end
 for ui, list in pairs(zoneLevels) do
  table.sort(list)
  if #list < 5 then zoneLevels[ui] = nil else
   zoneLevels[ui] = {lo = list[math.max(1, math.floor(#list * 0.15))], hi = list[math.ceil(#list * 0.85)], mid = list[math.ceil(#list / 2)], n = #list}
  end
 end
end

function FT.ZoneFit(map)
 if not zoneLevels then buildZoneLevels() end
 local zl = map and zoneLevels[map]
 if not zl then return nil end
 local level = UnitLevel('player') or 1
 local verdict, color
 if level < zl.lo - 2 then verdict, color = 'çok zor', '|cffff4040'
 elseif level < zl.lo then verdict, color = 'biraz zor', '|cffffa040'
 elseif level > zl.hi + 3 then verdict, color = 'çok kolay', '|cff9aa0a6'
 else verdict, color = 'sana uygun', '|cff55ff55' end
 return verdict, color, zl
end

function FT.BetterZones(limit)
 if not zoneLevels then buildZoneLevels() end
 local level = UnitLevel('player') or 1
 local here1 = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
 local cont1
 if here1 and C_Map.GetMapInfo then
  local info = C_Map.GetMapInfo(here1)
  cont1 = info and info.parentMapID
 end
 local list = {}
 for ui, zl in pairs(zoneLevels) do
  if level >= zl.lo - 1 and level <= zl.hi and ui ~= here1 then
   local same = 0
   if cont1 and C_Map.GetMapInfo then local i = C_Map.GetMapInfo(ui); same = i and i.parentMapID == cont1 and 0 or 1 end
   list[#list + 1] = {ui = ui, zl = zl, score = same * 10 + math.abs(zl.mid - level)}
  end
 end
 table.sort(list, function(a, b) return a.score < b.score end)
 local out, seen = {}, {}
 for _, e in ipairs(list) do
  local name = FT.MapName and FT.MapName(e.ui) or tostring(e.ui)
  if not seen[name] then seen[name] = true; out[#out + 1] = name .. (' (%d-%d)'):format(e.zl.lo, e.zl.hi) end
  if #out >= (limit or 3) then break end
 end
 return out
end

local lastZone
local function zoneCheck()
 if not on('zonefit') then return end
 local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
 if not map or map == lastZone then return end
 lastZone = map
 local verdict, color, zl = FT.ZoneFit(map)
 if not verdict then return end
 local name = FT.MapName and FT.MapName(map) or ''
 local msg = ('%s: seviye %d-%d · %s%s|r'):format(name, zl.lo, zl.hi, color, verdict)
 if FT.Flash then FT.Flash(msg) end
 if verdict ~= 'sana uygun' then
  local better = FT.BetterZones(3)
  if #better > 0 then FT.Print(msg .. ' — daha uygun: ' .. table.concat(better, ', ')) end
 end
end

----------------------------------------------------------------------
-- 9) Oturum özeti kartı
----------------------------------------------------------------------
local function snapshot()
 local best, bx
 for z, x in pairs(session.zones) do if not bx or x > bx then best, bx = z, x end end
 local max = UnitXPMax and UnitXPMax('player') or 1
 return {dur = session.start and (GetTime() - session.start) or 0, levels = session.xp / math.max(1, max), xp = session.xp,
  quests = session.quests, gold = (GetMoney and GetMoney() or 0) - (session.money0 or 0), zone = best, t = time and time() or 0}
end

local sumWin
function FT.ShowSessionCard(useLast)
 local d = useLast and ForeverTrailCharacter and ForeverTrailCharacter.lastSession or snapshot()
 if not d then return end
 if not sumWin then
  sumWin = FT.NewWindow('ForeverTrailSessionCard', UIParent)
  sumWin:SetSize(320, 190); sumWin:SetPoint('CENTER', 0, 80); sumWin:SetFrameStrata('DIALOG')
  sumWin:SetMovable(true); sumWin:EnableMouse(true); sumWin:RegisterForDrag('LeftButton')
  sumWin:SetScript('OnDragStart', sumWin.StartMoving); sumWin:SetScript('OnDragStop', sumWin.StopMovingOrSizing)
  sumWin.title = sumWin:CreateFontString(nil, 'OVERLAY'); sumWin.title:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', 15, 'OUTLINE'); sumWin.title:SetPoint('TOP', 0, -10)
  if FT.StyleTitle then FT.StyleTitle(sumWin.title) end
  sumWin.text = sumWin:CreateFontString(nil, 'OVERLAY'); sumWin.text:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', 13, ''); sumWin.text:SetPoint('TOPLEFT', 18, -38); sumWin.text:SetWidth(284); sumWin.text:SetJustifyH('LEFT')
  local close = FT.NewButton(sumWin, 'Kapat', 80, 22); close:SetPoint('BOTTOM', 0, 12)
  close:SetScript('OnClick', function() sumWin:Hide() end)
 end
 local h = math.floor(d.dur / 3600); local m = math.floor(d.dur % 3600 / 60)
 local rate = d.dur > 60 and d.xp / d.dur * 3600 or 0
 sumWin.title:SetText(useLast and 'Son oturumun' or 'Bu oturum')
 sumWin.text:SetText(('Süre: %s%d dk\nKazanılan: %.2f seviye (%d XP, saatte %d)\nTeslim edilen görev: %d\nAltın: %s\nEn verimli bölge: %s'):format(
  h > 0 and (h .. ' sa ') or '', m, d.levels, d.xp, rate, d.quests, FT.MoneyText and FT.MoneyText(math.max(0, d.gold)) or d.gold, d.zone or '-'))
 sumWin:Show()
 if FT.FixFonts then pcall(FT.FixFonts, sumWin) end
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local ev = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_LOGOUT', 'PLAYER_LOGIN', 'PLAYER_XP_UPDATE', 'PLAYER_LEVEL_UP', 'QUEST_TURNED_IN', 'QUEST_ACCEPTED', 'PLAYER_ALIVE', 'ZONE_CHANGED_NEW_AREA', 'QUEST_LOG_UPDATE', 'PLAYER_MONEY'}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript('OnEvent', function(_, event)
 local ok, err = pcall(function()
  if event == 'PLAYER_LOGIN' then
   session.start, session.startLevel = GetTime(), UnitLevel('player')
   lastXP, lastMax = UnitXP('player'), UnitXPMax('player')
   session.money0 = GetMoney and GetMoney() or 0
   after(5, zoneCheck)
   FT.UpdateSessionBar()
   local last = ForeverTrailCharacter and ForeverTrailCharacter.lastSession
   if on('sessionsummary') and last and not last.shown and last.dur > 900 then
    last.shown = true
    after(12, function() FT.ShowSessionCard(true) end)
   end
  elseif event == 'PLAYER_LOGOUT' then
   local snap = snapshot()
   if snap.dur > 300 then ForeverTrailCharacter = ForeverTrailCharacter or {}; ForeverTrailCharacter.lastSession = snap end
  elseif event == 'PLAYER_XP_UPDATE' or event == 'PLAYER_LEVEL_UP' then
   local xp, max = UnitXP('player'), UnitXPMax('player')
   if lastXP then
    local gain = xp - lastXP
    if gain < 0 then gain = (lastMax or max) - lastXP + xp end
    if gain > 0 then
     session.xp = session.xp + gain
     local zone = GetZoneText and GetZoneText() or '?'
     session.zones[zone] = (session.zones[zone] or 0) + gain
    end
   end
   lastXP, lastMax = xp, max
   FT.UpdateSessionBar()
  elseif event == 'QUEST_TURNED_IN' then session.quests = session.quests + 1; routeTime = -100
  elseif event == 'QUEST_ACCEPTED' then routeTime = -100; after(1, dropCheck)
  elseif event == 'PLAYER_ALIVE' then after(1, deathAdvice)
  elseif event == 'ZONE_CHANGED_NEW_AREA' then routeTime = -100; after(2, zoneCheck)
  end
 end)
 if not ok and FT.errors and #FT.errors < 20 then FT.errors[#FT.errors + 1] = 'guide2: ' .. tostring(err) end
end)
local acc = 0
ev:SetScript('OnUpdate', function(_, dt)
 pcall(beep, dt)
 acc = acc + dt
 if acc >= 10 then acc = 0; pcall(FT.UpdateSessionBar) end
end)
