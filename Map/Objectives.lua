local _, FT = ...

-- Görev hedefleri (gömülü veriyle): yaratık/nesne/eşya kimliğinden doğru eşleştirme,
-- haritada her görevin kendi renginde bölgesi (yumuşak alan + kenar + simgeler), minimapte hedef simgeleri.

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function db() return FT.Module and FT.Module('QuestieDB') end
local function zone() return FT.Module and FT.Module('ZoneDB') end

local PALETTE = {
 {1, 0.78, 0.25}, {0.35, 0.85, 1}, {0.55, 1, 0.45}, {1, 0.45, 0.6},
 {0.75, 0.55, 1}, {1, 0.6, 0.3}, {0.4, 1, 0.85}, {0.95, 0.95, 0.5},
}
FT.ObjectiveIcons = {
 kill = 'Interface\\Icons\\INV_Sword_04',
 loot = 'Interface\\Icons\\INV_Misc_Bag_08',
 object = 'Interface\\Icons\\INV_Misc_Gear_01',
 talk = 'Interface\\GossipFrame\\AvailableQuestIcon',
}
local KIND_LABEL = {kill='Öldür', loot='Topla', object='Kullan', talk='Konuş'}

----------------------------------------------------------------------
-- Günlükteki görevlerin hedefleri: {questId, title, index, kind, ids={npc/obj}, objIds, have, need, text, color}
----------------------------------------------------------------------
local cache, cacheTime, byNpc, byObject = nil, -100, {}, {}

local function nameOf(kind, id)
 local d = db()
 if not d then return nil end
 local fn = kind == 'object' and d.QueryObjectSingle or (kind == 'item' and d.QueryItemSingle or d.QueryNPCSingle)
 return fn(id, 'name')
end

local function flatten(questId)
 local d = db()
 local raw = d and d.QueryQuestSingle(questId, 'objectives')
 local list = {}
 if type(raw) ~= 'table' then return list end
 for _, r in ipairs(raw[1] or {}) do if type(r) == 'table' then list[#list + 1] = {kind='kill', npcs={r[1]}, objs={}, name=nameOf('npc', r[1])} end end
 for _, r in ipairs(raw[2] or {}) do if type(r) == 'table' then list[#list + 1] = {kind='object', npcs={}, objs={r[1]}, name=nameOf('object', r[1])} end end
 for _, r in ipairs(raw[3] or {}) do
  if type(r) == 'table' then
   local npcs, objs = {}, {}
   for i, n in ipairs(d.QueryItemSingle(r[1], 'npcDrops') or {}) do if i <= 12 then npcs[#npcs + 1] = n end end
   for i, o in ipairs(d.QueryItemSingle(r[1], 'objectDrops') or {}) do if i <= 12 then objs[#objs + 1] = o end end
   list[#list + 1] = {kind=#npcs == 0 and #objs > 0 and 'object' or 'loot', npcs=npcs, objs=objs, name=nameOf('item', r[1]), itemId=r[1]}
  end
 end
 for _, r in ipairs(raw[5] or {}) do
  if type(r) == 'table' and type(r[1]) == 'table' then
   list[#list + 1] = {kind='kill', npcs=r[1], objs={}, name=type(r[2]) == 'number' and nameOf('npc', r[2]) or nil}
  end
 end
 return list
end

function FT.ActiveObjectives()
 if cache and GetTime() - cacheTime < 2 then return cache end
 local out, q = {}, C_QuestLog
 byNpc, byObject = {}, {}
 if not (q and q.GetNumQuestLogEntries and db()) then cache, cacheTime = out, GetTime(); return out end
 local colorIndex = 0
 for i = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(i)
  if info and not info.isHeader and info.questID and info.questID > 0 then
   colorIndex = colorIndex + 1
   local color = FT.QuestColor and FT.QuestColor(colorIndex) or PALETTE[(colorIndex - 1) % #PALETTE + 1]
   local ok, rows = pcall(q.GetQuestObjectives, info.questID)
   rows = ok and type(rows) == 'table' and rows or {}
   local flat = flatten(info.questID)
   local used = {}
   for index, row in ipairs(rows) do
    -- Önce isme göre eşleştir (günlük sırası veriden farklı olabilir), olmazsa sıraya göre
    local match
    for j, e in ipairs(flat) do
     if not used[j] and e.name and type(row.text) == 'string' and row.text:find(e.name, 1, true) then match = j; break end
    end
    if not match and flat[index] and not used[index] then match = index end
    if match then
     used[match] = true
     local e = flat[match]
     local need, have = row.numRequired or 0, row.numFulfilled or 0
     local done = row.finished or (need > 0 and have >= need)
     local o = {questId=info.questID, title=FT.QuestTitle and FT.QuestTitle(info.questID, info.title) or info.title, index=index,
      kind=e.kind, npcs=e.npcs, objs=e.objs, itemId=e.itemId, have=have, need=need, done=done, text=row.text, color=color}
     out[#out + 1] = o
     if not done then
      for _, n in ipairs(e.npcs) do byNpc[n] = byNpc[n] or o end
      for _, ob in ipairs(e.objs) do byObject[ob] = byObject[ob] or o end
     end
    end
   end
  end
 end
 cache, cacheTime = out, GetTime()
 return out
end

local function invalidate() cacheTime = -100 end

-- Yaratık kimliğinden hedef (isim eşleştirmesinden doğru)
local oldInfo = FT.QuestCreatureInfo
FT.QuestCreatureInfo = function(unit)
 if ForeverTrailSettings and ForeverTrailSettings.creaturewarn == false then return nil end
 if not (unit and UnitExists(unit)) or UnitIsPlayer(unit) or UnitIsDead(unit) then return nil end
 local guid = UnitGUID and UnitGUID(unit)
 local npcId = guid and tonumber((select(6, strsplit('-', guid))))
 if npcId then
  FT.ActiveObjectives()
  local o = byNpc[npcId]
  if o then return o end
 end
 if oldInfo then return oldInfo(unit) end
end

----------------------------------------------------------------------
-- Noktalar ve kümeler
----------------------------------------------------------------------
local pointCache = {}
local function objectivePoints(o, mapID)
 local key = o.questId .. ':' .. o.index .. ':' .. mapID
 if pointCache[key] then return pointCache[key] end
 local d, z = db(), zone()
 local pts = {}
 if d and z then
  local function add(spawns)
   if type(spawns) ~= 'table' then return end
   for area, list in pairs(spawns) do
    if z:GetUiMapIdByAreaId(area) == mapID then
     for _, p in ipairs(list) do pts[#pts + 1] = {p[1] / 100, p[2] / 100} end
    end
   end
  end
  for _, n in ipairs(o.npcs) do add(d.QueryNPCSingle(n, 'spawns')) end
  for _, ob in ipairs(o.objs) do add(d.QueryObjectSingle(ob, 'spawns')) end
 end
 pointCache[key] = pts
 return pts
end

-- Ince ızgara kümeleri, sonra yakın kümeleri bölgelere birleştir
local function clusters(pts, cell)
 local grid, out = {}, {}
 for _, p in ipairs(pts) do
  local k = math.floor(p[1] / cell) .. ':' .. math.floor(p[2] / cell)
  local c = grid[k]
  if not c then c = {x=0, y=0, n=0}; grid[k] = c; out[#out + 1] = c end
  c.x, c.y, c.n = c.x + p[1], c.y + p[2], c.n + 1
 end
 for _, c in ipairs(out) do c.x, c.y = c.x / c.n, c.y / c.n end
 return out
end

local function groups(list, reach)
 local parent = {}
 local function find(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
 for i = 1, #list do parent[i] = i end
 for i = 1, #list do
  for j = i + 1, #list do
   local dx, dy = list[i].x - list[j].x, list[i].y - list[j].y
   if dx * dx + dy * dy < reach * reach then parent[find(i)] = find(j) end
  end
 end
 local map, out = {}, {}
 for i = 1, #list do
  local r = find(i)
  if not map[r] then map[r] = {}; out[#out + 1] = map[r] end
  table.insert(map[r], list[i])
 end
 return out
end

-- Dışbükey zarf (monoton zincir)
local function hull(points)
 local p = {}
 for _, c in ipairs(points) do p[#p + 1] = {c.x, c.y} end
 table.sort(p, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
 if #p < 3 then return p end
 local function cross(o, a, b) return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1]) end
 local lower, upper = {}, {}
 for _, pt in ipairs(p) do
  while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], pt) <= 0 do lower[#lower] = nil end
  lower[#lower + 1] = pt
 end
 for i = #p, 1, -1 do
  local pt = p[i]
  while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], pt) <= 0 do upper[#upper] = nil end
  upper[#upper + 1] = pt
 end
 lower[#lower] = nil; upper[#upper] = nil
 for _, pt in ipairs(upper) do lower[#lower + 1] = pt end
 return lower
end

-- Haritada çizilecek bölgeler: {o, groups={{cells, hull, center}}}
local areaCache, areaTimes, areaTime = {}, {}, -100
function FT.ObjectiveAreas(mapID)
 local age = areaTimes[mapID] and (GetTime() - areaTimes[mapID])
 if areaCache[mapID] and age < 3 and (areaTimes[mapID] > areaTime or age < 1) then return areaCache[mapID] end
 local out = {}
 for _, o in ipairs(FT.ActiveObjectives()) do
  if not o.done and (not FT.ShowObjectiveOnMap or FT.ShowObjectiveOnMap(o.questId)) then
   local pts = objectivePoints(o, mapID)
   if #pts > 0 then
    local cells = clusters(pts, 0.02)
    local gs = {}
    for _, g in ipairs(groups(cells, 0.07)) do
     local cx, cy, n = 0, 0, 0
     for _, c in ipairs(g) do cx, cy, n = cx + c.x * c.n, cy + c.y * c.n, n + c.n end
     gs[#gs + 1] = {cells=g, hull=hull(g), x=cx / n, y=cy / n, n=n}
    end
    out[#out + 1] = {o=o, groups=gs}
   end
  end
 end
 areaCache[mapID], areaTimes[mapID] = out, GetTime()
 return out
end

----------------------------------------------------------------------
-- Dünya haritası çizimi
----------------------------------------------------------------------
local blobs, lines, icons = {}, {}, {}
FT.objectiveIcons = icons
local BLOB = 'Interface\\CHARACTERFRAME\\TempPortraitAlphaMask'

function FT.DrawObjectiveAreas(mapID)
 for _, t in ipairs(blobs) do t:Hide() end
 for _, l in ipairs(lines) do l:Hide() end
 for _, i in ipairs(icons) do i:Hide() end
 local parts = FT.mapParts
 local overlay = parts and parts.overlay
 if not (overlay and mapID and on('objareas')) then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local nb, nl, ni = 0, 0, 0
 local focus = FT.focusQuest
 -- Questie görünümü: bölge alanı yok, kümelerin hepsinde simge (isteğe bağlı alan çizimi)
 local qs = FT.IconStyle and FT.IconStyle() == 'questie'
 local drawAreas = not qs or (ForeverTrailSettings and ForeverTrailSettings.qareas == true)
 for _, a in ipairs(FT.ObjectiveAreas(mapID)) do
  local c = a.o.color
  local dim = focus and focus ~= a.o.questId
  local alpha = dim and 0.25 or 1
  local maxN = 1
  for _, g in ipairs(a.groups) do for _, cell in ipairs(g.cells) do if cell.n > maxN then maxN = cell.n end end end
  for _, g in ipairs(a.groups) do
   -- yumuşak alan: her kümede yarı saydam daire (kalabalık yerler daha koyu)
   for _, cell in ipairs(drawAreas and g.cells or {}) do
    if nb < 400 then
     nb = nb + 1
     local t = blobs[nb]
     if not t then t = overlay:CreateTexture(nil, 'BACKGROUND'); t:SetTexture(BLOB); blobs[nb] = t end
     local size = math.max(18, math.min(60, w * 0.035)) * (1 + math.min(cell.n, 6) * 0.08)
     t:SetSize(size, size)
     local heat = (ForeverTrailSettings and ForeverTrailSettings.heatmap == false) and 1 or (0.55 + 0.9 * cell.n / maxN)
     t:SetVertexColor(c[1], c[2], c[3], math.min(0.7, 0.16 * alpha * FT.Scale('areaAlpha') * heat))
     t:ClearAllPoints(); t:SetPoint('CENTER', overlay, 'TOPLEFT', cell.x * w, -cell.y * h)
     t:Show()
    end
   end
   -- kenar çizgisi: zarfı merkezden biraz dışarı büyüt
   local hpts = g.hull
   if drawAreas and #hpts >= 3 then
    for i = 1, #hpts do
     if nl < 600 then
      local p1, p2 = hpts[i], hpts[i % #hpts + 1]
      local function grow(p) local dx, dy = p[1] - g.x, p[2] - g.y local len = math.sqrt(dx * dx + dy * dy) if len == 0 then return p end local k = (len + 0.012) / len return {g.x + dx * k, g.y + dy * k} end
      local a1, a2 = grow(p1), grow(p2)
      nl = nl + 1
      local l = lines[nl]
      if not l then l = overlay:CreateLine(nil, 'ARTWORK'); l:SetThickness(2); lines[nl] = l end
      l:SetColorTexture(c[1], c[2], c[3], math.min(1, 0.75 * alpha * FT.Scale('areaAlpha')))
      l:SetStartPoint('TOPLEFT', overlay, a1[1] * w, -a1[2] * h)
      l:SetEndPoint('TOPLEFT', overlay, a2[1] * w, -a2[2] * h)
      l:Show()
     end
    end
   end
   -- simge: bölgenin en kalabalık 4 kümesi
   table.sort(g.cells, function(x, y) return x.n > y.n end)
   for k = 1, math.min(qs and 30 or 4, #g.cells) do
    if ni < 160 then
     ni = ni + 1
     local cell = g.cells[k]
     local f = icons[ni]
     if not f then
      f = CreateFrame('Frame', nil, overlay)
      f.bg = f:CreateTexture(nil, 'BACKGROUND'); f.bg:SetTexture(BLOB); f.bg:SetPoint('CENTER')
      f.icon = f:CreateTexture(nil, 'ARTWORK'); f.icon:SetAllPoints(); f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
      icons[ni] = f
     end
     local sc = FT.Scale('mapIcons')
     local ks = sc * (FT.KindScale and FT.KindScale(a.o.kind) or 1)
     if focus and focus == a.o.questId and on('focusbig') then ks = ks * 1.35 end
     f:SetSize(18 * ks, 18 * ks); f.bg:SetSize(24 * ks, 24 * ks)
     f:SetFrameLevel(overlay:GetFrameLevel() + 3)
     if FT.SetObjectiveIcon then FT.SetObjectiveIcon(f.icon, f.bg, a.o.kind, c, alpha) else
      f.bg:SetVertexColor(c[1], c[2], c[3], 0.9 * alpha)
      f.icon:SetTexture(FT.ObjectiveIcons[a.o.kind] or FT.ObjectiveIcons.kill)
      f.icon:SetAlpha(alpha)
     end
     f:ClearAllPoints(); f:SetPoint('CENTER', overlay, 'TOPLEFT', cell.x * w, -cell.y * h)
     f.step = {x=cell.x, y=cell.y, uiMapID=mapID, questId=a.o.questId, questTitle=a.o.title,
      text=('%s: %s (%d/%d)'):format(KIND_LABEL[a.o.kind] or 'Hedef', FT.ParseObjective and FT.ParseObjective(a.o.text or '') or (a.o.text or ''), a.o.have, a.o.need), type='objective'}
     f:Show()
    end
   end
  end
 end
end

----------------------------------------------------------------------
-- Minimap: yakındaki hedef kümeleri
----------------------------------------------------------------------
local OUTDOOR = {[0]=233.33, 200, 166.67, 133.33, 100, 66.67}
local INDOOR = {[0]=150, 125, 100, 75, 50, 37.5}
local mm = {}
local function updateMinimap()
 for _, p in ipairs(mm) do p:Hide() end
 if not (on('objareas') and Minimap and Minimap:IsVisible() and C_Map and C_Map.GetBestMapForUnit) then return end
 local map = C_Map.GetBestMapForUnit('player')
 local pos = map and C_Map.GetPlayerMapPosition(map, 'player')
 if not pos then return end
 local px, py = pos:GetXY()
 local ok, ww, wh = pcall(C_Map.GetMapWorldSize, map)
 if not ok or not ww or ww <= 0 then return end
 local radius = FT.MinimapRadius and FT.MinimapRadius() or ((IsIndoors and IsIndoors()) and INDOOR or OUTDOOR)[Minimap:GetZoom() or 0] or 150
 local rotate = GetCVar and GetCVar('rotateMinimap') == '1'
 local facing = GetPlayerFacing and GetPlayerFacing()
 local half = Minimap:GetWidth() / 2
 local used = 0
 for _, a in ipairs(FT.ObjectiveAreas(map)) do
  for _, g in ipairs(a.groups) do
   for _, cell in ipairs(g.cells) do
    local dx, dy = (cell.x - px) * ww, (cell.y - py) * wh
    if dx * dx + dy * dy < radius * radius * 0.8 and used < 24 then
     used = used + 1
     local pin = mm[used]
     if not pin then
      pin = CreateFrame('Frame', nil, Minimap); pin:SetFrameStrata('MEDIUM'); pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
      pin.bg = pin:CreateTexture(nil, 'BACKGROUND'); pin.bg:SetTexture(BLOB); pin.bg:SetPoint('CENTER')
      pin.icon = pin:CreateTexture(nil, 'ARTWORK'); pin.icon:SetAllPoints(); pin.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
      mm[used] = pin
     end
     local nx, ny = FT.MinimapOffset(dx, dy, facing, rotate, radius)
     local c = a.o.color
     local ms = FT.Scale('mmIcons')
     ms = ms * (FT.KindScale and FT.KindScale(a.o.kind) or 1)
     pin:SetSize(13 * ms, 13 * ms); pin.bg:SetSize(17 * ms, 17 * ms)
     if FT.SetObjectiveIcon then FT.SetObjectiveIcon(pin.icon, pin.bg, a.o.kind, c, 1) else
      pin.bg:SetVertexColor(c[1], c[2], c[3], 0.9)
      pin.icon:SetTexture(FT.ObjectiveIcons[a.o.kind] or FT.ObjectiveIcons.kill)
     end
     pin:SetAlpha(FT.MinimapFade and FT.MinimapFade(nx, ny) or 1)
     pin.ftAlpha, pin.ftOut = 1, nil
     pin.ftInfo = {kind = 'objective', o = a.o}
     if FT.MinimapTrack then FT.MinimapTrack(pin, map, cell.x, cell.y) end
     pin:ClearAllPoints(); pin:SetPoint('CENTER', Minimap, 'CENTER', nx * half, ny * half)
     pin:Show()
    end
   end
  end
 end
end

local events = CreateFrame('Frame')
for _, e in ipairs({'QUEST_LOG_UPDATE', 'QUEST_ACCEPTED', 'QUEST_TURNED_IN', 'ZONE_CHANGED_NEW_AREA'}) do pcall(events.RegisterEvent, events, e) end
events:SetScript('OnEvent', function() invalidate(); areaTime = GetTime(); if FT.BumpLayers then FT.BumpLayers() end end)
local acc = 0
events:SetScript('OnUpdate', function(_, dt)
 acc = acc + dt
 if acc < 0.5 then return end
 acc = 0
 local ok, err = pcall(updateMinimap)
 if not ok and FT.errors and #FT.errors < 20 then FT.errors[#FT.errors + 1] = 'objectives: ' .. tostring(err) end
end)
