local _, FT = ...

-- Questie tarzı görünüm: tek renk hedef simgeleri (görev renginde), zorluk renkleri,
-- haritada aynı noktadaki tüm görevleri gruplayan ipucu, uzak minimap simgelerini soldurma,
-- görev kutusu için uzaklık / teslim NPC'si yardımcıları.
-- Media/*.tga: pfQuest simgeleri (MIT lisansı, Media/LICENSE-MIT.txt).

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function db() return FT.Module and FT.Module('QuestieDB') end

local M = 'Interface\\AddOns\\ForeverTrail\\Media\\'
FT.Media = M
FT.MonoIcons = {kill = M .. 'slay_mono', loot = M .. 'loot_mono', object = M .. 'object_mono'}
local Q = M .. 'Questie\\'
FT.QuestieMedia = Q
FT.QuestieIcons = {kill = Q .. 'slay', loot = Q .. 'loot', object = Q .. 'object', talk = Q .. 'chatbubblegossipicon', event = Q .. 'event', interact = Q .. 'interact'}
local BLOBTEX = 'Interface\\CHARACTERFRAME\\TempPortraitAlphaMask'
FT.ColorIcons = {}
for k, v in pairs(FT.ObjectiveIcons or {}) do FT.ColorIcons[k] = v end

local KIND_KEY = {kill = 'iconKill', loot = 'iconLoot', object = 'iconObject'}
function FT.KindScale(kind)
 return KIND_KEY[kind] and FT.Scale(KIND_KEY[kind]) or 1
end

function FT.TrackerStyle()
 local s = ForeverTrailSettings or {}
 return s.c_trackerStyle or 'questie'
end

function FT.IconStyle()
 return ForeverTrailSettings and ForeverTrailSettings.c_iconStyle or 'questie'
end

-- Hedef simgesini seçilen stile göre boya. icon: simge dokusu, bg: arka disk
function FT.SetObjectiveIcon(icon, bg, kind, c, alpha)
 alpha = alpha or 1
 local style, glow = FT.IconStyle(), on('iconglow')
 if icon.ftKind == kind and icon.ftColor == c and icon.ftAlpha == alpha and icon.ftStyle == style and icon.ftGlow == glow then return end
 icon.ftKind, icon.ftColor, icon.ftAlpha, icon.ftStyle, icon.ftGlow = kind, c, alpha, style, glow
 if style == 'questie' then
  -- Questie görünümü: renkli Questie simgesi, arkasında görev renginde yumuşak parıltı
  icon:SetTexture(FT.QuestieIcons[kind] or FT.QuestieIcons.kill); icon:SetTexCoord(0, 1, 0, 1)
  icon:SetVertexColor(1, 1, 1, alpha)
  if bg then bg:SetTexture(Q .. 'glow'); bg:SetVertexColor(c[1], c[2], c[3], (glow and 0.9 or 0) * alpha) end
  return
 end
 if bg then bg:SetTexture(BLOBTEX) end
 local mono = style == 'sade' and FT.MonoIcons[kind]
 if mono then
  icon:SetTexture(mono); icon:SetTexCoord(0, 1, 0, 1)
  icon:SetVertexColor(c[1], c[2], c[3], alpha)
  if bg then bg:SetVertexColor(0, 0, 0, (glow and 0.55 or 0) * alpha) end
 else
  icon:SetTexture(FT.ColorIcons[kind] or FT.ColorIcons.kill or 'Interface\\GossipFrame\\IncompleteQuestIcon')
  icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
  icon:SetVertexColor(1, 1, 1, alpha)
  if bg then bg:SetVertexColor(c[1], c[2], c[3], 0.9 * alpha) end
 end
end

----------------------------------------------------------------------
-- Zorluk renkleri (kırmızı / turuncu / sarı / yeşil / gri)
----------------------------------------------------------------------
function FT.DiffColor(level)
 level = tonumber(level)
 if not level or level <= 0 then return 1, 0.82, 0 end
 if GetQuestDifficultyColor then
  local ok, c = pcall(GetQuestDifficultyColor, level)
  if ok and type(c) == 'table' and c.r then return c.r, c.g, c.b end
 end
 local pl = UnitLevel and UnitLevel('player') or level
 local d = level - pl
 if d >= 5 then return 1, 0.1, 0.1 end
 if d >= 3 then return 1, 0.5, 0.25 end
 if d >= -2 then return 1, 1, 0 end
 local green = GetQuestGreenRange and GetQuestGreenRange() or 8
 if -d <= green then return 0.25, 0.75, 0.25 end
 return 0.55, 0.55, 0.55
end

function FT.DiffHex(level)
 local r, g, b = FT.DiffColor(level)
 return ('|cff%02x%02x%02x'):format(r * 255, g * 255, b * 255)
end

-- Kırmızı -> sarı -> yeşil ilerleme rengi
function FT.ProgressColor(have, need, done)
 local mode = ForeverTrailSettings and ForeverTrailSettings.c_objColor or 'beyaz'
 if done then return 0.4, 1, 0.4 end
 if mode == 'sade' or not need or need <= 0 then return 0.92, 0.9, 0.85 end
 local t = math.max(0, math.min(1, (have or 0) / need))
 if mode == 'beyaz' then return 1 - 0.6 * t, 1, 1 - 0.6 * t end
 local r, g = (t < 0.5) and 1 or (2 - 2 * t), (t < 0.5) and (2 * t) or 1
 return 0.25 + 0.75 * r, 0.25 + 0.75 * g, 0.25
end

function FT.QuestLevel(questId)
 local d = db()
 return d and (d.QueryQuestSingle(questId, 'questLevel') or d.QueryQuestSingle(questId, 'requiredLevel'))
end

----------------------------------------------------------------------
-- Teslim NPC'si ve görev uzaklığı
----------------------------------------------------------------------
local function enders(questId)
 local d = db()
 local f = d and d.QueryQuestSingle(questId, 'finishedBy')
 return type(f) == 'table' and f or nil
end

function FT.TurnInName(questId)
 local d, f = db(), enders(questId)
 if not (d and f) then return nil end
 local npc = f[1] and f[1][1]
 if npc then return d.QueryNPCSingle(npc, 'name') end
 local obj = f[2] and f[2][1]
 if obj then return d.QueryObjectSingle(obj, 'name') end
end

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

local distCache, distTime = {}, -100
local function spawnsOn(kind, id, map)
 local d, zone = db(), FT.Module and FT.Module('ZoneDB')
 local spawns = d and (kind == 'object' and d.QueryObjectSingle(id, 'spawns') or d.QueryNPCSingle(id, 'spawns'))
 if type(spawns) ~= 'table' then return nil end
 for area, list in pairs(spawns) do
  local m = zone and zone.GetUiMapIdByAreaId and zone:GetUiMapIdByAreaId(area) or area
  if m == map then return list end
 end
end

function FT.QuestDistance(questId)
 local now = GetTime and GetTime() or 0
 if now - distTime > 2 then distCache, distTime = {}, now end
 local cached = distCache[questId]
 if cached ~= nil then return cached or nil end
 local map, px, py, ww, wh = here()
 local best
 local function try(x, y)
  local dx, dy = (x - px) * ww, (y - py) * wh
  local dist = math.sqrt(dx * dx + dy * dy)
  if not best or dist < best then best = dist end
 end
 if map then
  local done = C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(questId)
  if done then
   local f = enders(questId)
   for k, kind in ipairs({'npc', 'object'}) do
    for _, id in ipairs(f and f[k] or {}) do
     local list = spawnsOn(kind, id, map)
     for _, p in ipairs(list or {}) do
      if type(p) == 'table' and p[1] and p[1] >= 0 then try(p[1] / 100, p[2] / 100) end
     end
    end
   end
  elseif FT.ObjectiveAreas then
   local ok, areas = pcall(FT.ObjectiveAreas, map)
   for _, a in ipairs(ok and areas or {}) do
    if a.o and a.o.questId == questId then
     for _, g in ipairs(a.groups or {}) do try(g.x, g.y) end
    end
   end
  end
 end
 distCache[questId] = best or false
 return best
end

----------------------------------------------------------------------
-- Haritada gruplu ipucu: imlecin altındaki tüm görevler, başlık zorluk renginde, hedefler ilerlemeyle
----------------------------------------------------------------------
local KIND = {kill = 'Öldür', loot = 'Topla', object = 'Kullan', talk = 'Konuş'}
function FT.MapTooltip(found, describe)
 if not (found and #found > 0) then return false end
 local groups, order = {}, {}
 for _, f in ipairs(found) do
  local s = f.step
  local key = s.questId or (s.questTitle or '') .. '|' .. (s.text or '')
  local g = groups[key]
  if not g then g = {step = s, steps = {}}; groups[key] = g; order[#order + 1] = g end
  g.steps[#g.steps + 1] = s
 end
 local tip = GameTooltip
 tip:SetOwner(WorldMapFrame, 'ANCHOR_CURSOR')
 local first = true
 local objectives = FT.ActiveObjectives and FT.ActiveObjectives() or {}
 for i, g in ipairs(order) do
  if i > 6 then tip:AddLine(('+%d görev daha'):format(#order - 6), 0.7, 0.7, 0.7); break end
  local s, id = g.step, g.step.questId
  if id then
   local lvl = FT.QuestLevel(id)
   local title = FT.QuestTitle and FT.QuestTitle(id) or s.questTitle or ('Görev ' .. id)
   local r, gg, b = FT.DiffColor(lvl)
   local head = (lvl and ('[' .. lvl .. '] ') or '') .. title
   if first then tip:SetText(head, r, gg, b) else tip:AddLine(' '); tip:AddLine(head, r, gg, b) end
   local any = false
   for _, o in ipairs(objectives) do
    if o.questId == id then
     any = true
     local done = o.need and o.need > 0 and o.have >= o.need
     local pr, pg, pb = FT.ProgressColor(o.have, o.need, done)
     local text = FT.ParseObjective and FT.ParseObjective(o.text or '') or (o.text or '')
     tip:AddDoubleLine('  ' .. (KIND[o.kind] and (KIND[o.kind] .. ': ') or '') .. text,
      (o.need and o.need > 0) and ('%d/%d'):format(o.have or 0, o.need) or '', 0.9, 0.9, 0.9, pr, pg, pb)
    end
   end
   if not any and s.text then tip:AddLine('  ' .. s.text, 1, 1, 1, true) end
  else
   local lines = describe and describe(s) or {s.questTitle or '', s.text or ''}
   if first then tip:SetText(lines[1] or '', 1, 0.85, 0.5) else tip:AddLine(' '); tip:AddLine(lines[1] or '', 1, 0.85, 0.5) end
   if lines[2] and lines[2] ~= '' then tip:AddLine(lines[2], 1, 1, 1, true) end
  end
  first = false
 end
 tip:AddLine('Ctrl+tık: özel hedef', 0.55, 0.55, 0.55)
 if FT.ShowTip then FT.ShowTip(tip) else tip:Show() end
 return true
end

----------------------------------------------------------------------
-- Görev kutusu satırı ipucu
----------------------------------------------------------------------
function FT.QuestRowTip(owner, questId)
 if not questId then return end
 if FT.Kit then
  -- Modern ipucu: başlık, ne yapılacak, ilerleme çubuklu hedefler, ödül/teslim/uzaklık ve kısayollar
  local tip = FT.Kit.Tooltip()
  tip:SetOwner(owner, 'ANCHOR_LEFT')
  local lvl = FT.QuestLevel(questId)
  local r, g, b = FT.DiffColor(lvl)
  tip:SetText((lvl and ('[' .. lvl .. '] ') or '') .. (FT.QuestTitle and FT.QuestTitle(questId) or ('Görev ' .. questId)), r, g, b)
  local tr = QTR_QuestData and QTR_QuestData[tostring(questId)]
  local d = db()
  local obj = tr and tr.Objectives or (d and d.QueryQuestSingle(questId, 'objectivesText'))
  if type(obj) == 'table' then obj = table.concat(obj, ' ') end
  if obj and obj ~= '' then tip:AddLine(obj, 0.67, 0.7, 0.76) end
  local q = C_QuestLog
  local listed = false
  if q and q.GetLogIndexForQuestID and q.GetQuestObjectives and (q.GetLogIndexForQuestID(questId) or 0) > 0 then
   local ok, list = pcall(q.GetQuestObjectives, questId)
   if ok and type(list) == 'table' then
    for _, o in ipairs(list) do
     if not listed then tip:AddRule(); listed = true end
     local need, have = o.numRequired or 0, o.numFulfilled or 0
     local done = o.finished or (need > 0 and have >= need)
     local pr, pg, pb = FT.ProgressColor(have, need, done)
     local text = FT.ParseObjective and FT.ParseObjective(o.text or '') or (o.text or '')
     tip:AddBar(text, have, need, pr, pg, pb)
    end
   end
  end
  tip:AddRule()
  local xpText = FT.QuestXPText and FT.QuestXPText(questId)
  if xpText then tip:AddDoubleLine('Ödül', xpText, 0.67, 0.7, 0.76, 0.6, 0.8, 1) end
  local ender = FT.TurnInName(questId)
  if ender then tip:AddDoubleLine('Teslim', ender, 0.67, 0.7, 0.76, 0.55, 1, 0.55) end
  local dist = FT.QuestDistance(questId)
  if dist then tip:AddDoubleLine('Uzaklık', ('%d m'):format(dist), 0.67, 0.7, 0.76, 1, 1, 1) end
  tip:AddLine(' ')
  tip:AddLine('Sol tık: yol göster  ·  Sağ tık: odak', 0.55, 0.57, 0.62)
  tip:AddLine('Shift: daralt  ·  Ctrl: sabitle  ·  Alt: yukarı taşı', 0.55, 0.57, 0.62)
  tip:Show()
  return
 end
 if not GameTooltip then return end
 local tip = GameTooltip
 tip:SetOwner(owner, 'ANCHOR_LEFT')
 local lvl = FT.QuestLevel(questId)
 local r, g, b = FT.DiffColor(lvl)
 tip:SetText((lvl and ('[' .. lvl .. '] ') or '') .. (FT.QuestTitle and FT.QuestTitle(questId) or ('Görev ' .. questId)), r, g, b)
 local tr = QTR_QuestData and QTR_QuestData[tostring(questId)]
 local d = db()
 local obj = tr and tr.Objectives or (d and d.QueryQuestSingle(questId, 'objectivesText'))
 if type(obj) == 'table' then obj = table.concat(obj, ' ') end
 if obj and obj ~= '' then tip:AddLine(obj, 1, 1, 1, true) end
 local xpText = FT.QuestXPText and FT.QuestXPText(questId)
 if xpText then tip:AddLine('Ödül: ' .. xpText, 0.6, 0.8, 1) end
 local ender = FT.TurnInName(questId)
 if ender then tip:AddLine('Teslim: ' .. ender, 0.55, 1, 0.55) end
 local dist = FT.QuestDistance(questId)
 if dist then tip:AddLine(('Uzaklık: %d m'):format(dist), 0.8, 0.8, 0.8) end
 tip:AddLine('Görev yardımcısı: /ftrail gorev', 0.55, 0.8, 1)
 tip:AddLine('Sol tık: yol göster · Sağ tık: odak · Shift+tık: daralt · Ctrl+tık: sabitle · Alt+tık: yukarı taşı', 0.55, 0.55, 0.55, true)
 if FT.ShowTip then FT.ShowTip(tip) else tip:Show() end
end

----------------------------------------------------------------------
-- Minimap: uzak simgeleri soldur (Questie gibi)
----------------------------------------------------------------------
function FT.MinimapFade(nx, ny)
 if not on('mmfade') then return 1 end
 local r = math.sqrt((nx or 0) ^ 2 + (ny or 0) ^ 2)
 local start = FT.Scale('mmFadeStart')
 if r <= start then return 1 end
 return math.max(0.3, 1 - (r - start) / math.max(0.1, 1 - start) * 0.7)
end
