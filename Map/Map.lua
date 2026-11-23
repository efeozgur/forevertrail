local _, FT = ...
function FT.AtLocation(s)
 if not (s.uiMapID and s.x and s.y and C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return false end
 local ok,map=pcall(C_Map.GetBestMapForUnit,'player'); if not ok or map~=s.uiMapID then return false end
 local good,pos=pcall(C_Map.GetPlayerMapPosition,map,'player'); if not good or not pos then return false end
 local valid,x,y=pcall(function() return pos:GetXY() end)
 if not valid or type(x)~='number' or type(y)~='number' or (x==0 and y==0) then return false end
 return (x-s.x)^2+(y-s.y)^2 <= (s.radius or 0.01)^2
end
FT.TypeColor = FT.TypeColor or {accept={0.55,0.82,0.5}, objective={0.98,0.8,0.4}, turnin={0.55,0.72,0.95}, location={0.75,0.62,0.95}, manual={0.78,0.74,0.68}}
local typeColor = FT.TypeColor
local overlay, marker, glow, label, player, route, routeGlow, caption
local dots, pulse = {}, 0
local trail, trailPts = {}, nil
local segGlow, segCore = {}, {}
local mapRing = {}

-- Güzergah: oyuncudan hedefe giden, tema renginde parıltılı çizgi; üzerinde ince bir nokta izi ve hedefe doğru akan kuyruklu ışıklar.
-- Işıkların sayısı mesafeyle artar; hedefe yaklaştıkça hepsi belirginleşir.
local comets, tails = {}, {}
local TAIL = 5
local function trailColor()
 local c = FT.Kit and FT.Kit.Color and FT.Kit.Color('accent')
 if c then return c[1], c[2], c[3] end
 return 1, 0.82, 0.4
end
FT.MapTrailColor = trailColor

local function dotTexture(list, i, size, blend)
 local d = list[i]
 if not d then
  d = overlay:CreateTexture(nil, 'ARTWORK')
  d:SetTexture(blend and 'Interface\\Cooldown\\star4' or 'Interface\\Buttons\\WHITE8X8')
  if blend then d:SetBlendMode('ADD') end
  list[i] = d
 end
 d:SetSize(size, size)
 return d
end

local function updateTrail()
 local base, head, tail = 0, 0, 0
 if overlay and trailPts and #trailPts >= 2 then
  -- birikimli uzunluklar; yol boyunca d uzaklığındaki nokta
  local cum, total = {0}, 0
  for i = 2, #trailPts do
   total = total + math.sqrt((trailPts[i][1] - trailPts[i - 1][1]) ^ 2 + (trailPts[i][2] - trailPts[i - 1][2]) ^ 2)
   cum[i] = total
  end
  if total > 24 then
   local function at(d)
    local i = 2
    while i < #trailPts and cum[i] < d do i = i + 1 end
    local a, b2 = trailPts[i - 1], trailPts[i]
    local seg = cum[i] - cum[i - 1]
    local t = seg > 0 and (d - cum[i - 1]) / seg or 0
    return a[1] + (b2[1] - a[1]) * t, a[2] + (b2[2] - a[2]) * t
   end
   local r, g, b = trailColor()
   -- ince nokta izi (sabit)
   local spacing = 15
   local n = math.min(120, math.floor(total / spacing))
   for i = 1, n do
    base = base + 1
    local d = dotTexture(trail, base, 4, false)
    local x, y = at(i * spacing)
    d:ClearAllPoints(); d:SetPoint('CENTER', overlay, 'TOPLEFT', x, y)
    d:SetVertexColor(r, g, b, 0.18 + 0.32 * (i * spacing / total))
    d:Show()
   end
   -- akan ışıklar: baş + kuyruk
   local count = math.max(1, math.min(4, math.floor(total / 260) + 1))
   local speed = 120 + math.min(160, total * 0.25)
   for c = 1, count do
    local pos = (pulse * speed + (c - 1) * total / count) % total
    for k = 0, TAIL do
     local dist = pos - k * 9
     if dist > 0 then
      local t = dist / total
      local x, y = at(dist)
      local strength = (0.35 + 0.65 * t) * (1 - k / (TAIL + 1))
      if k == 0 then
       head = head + 1
       local h = dotTexture(comets, head, 17 + 4 * math.sin(pulse * 7 + c), true)
       h:ClearAllPoints(); h:SetPoint('CENTER', overlay, 'TOPLEFT', x, y)
       h:SetVertexColor(1, 1, 1, 0.55 + 0.4 * t)
       h:Show()
      else
       tail = tail + 1
       local d = dotTexture(tails, tail, math.max(3, 9 - k), false)
       d:ClearAllPoints(); d:SetPoint('CENTER', overlay, 'TOPLEFT', x, y)
       d:SetVertexColor(r, g, b, strength)
       d:Show()
      end
     end
    end
   end
  end
 end
 for i = base + 1, #trail do trail[i]:Hide() end
 for i = head + 1, #comets do comets[i]:Hide() end
 for i = tail + 1, #tails do tails[i]:Hide() end
end
FT.mapDots = dots
-- Çizilen rota parçası sayısı (test ve tanı için): düz çizgide 1, kıvrımlı yolda parça sayısı
FT.MapRouteSegments = function()
 local n = (route and route:IsShown()) and 1 or 0
 for i = 1, #segCore do if segCore[i]:IsShown() then n = n + 1 end end
 return n
end
FT.UpdateMapTrail = function(advance) pulse = pulse + (advance or 0); updateTrail() end -- test ve tanı için

function FT.MapDebug()
 local step = FT.TargetStep() or {}
 local function shown(region)
  if not region then return 'nil' end
  local ok, value = pcall(region.IsShown, region)
  return ok and tostring(value) or 'error'
 end
 local function read(fn, ...)
  if type(fn) ~= 'function' then return nil end
  local ok, value = pcall(fn, ...)
  if ok then return value end
 end
 local current = WorldMapFrame and read(WorldMapFrame.GetMapID, WorldMapFrame)
 local best = C_Map and read(C_Map.GetBestMapForUnit, 'player')
 local width = overlay and read(overlay.GetWidth, overlay)
 local height = overlay and read(overlay.GetHeight, overlay)
 local text = caption and read(caption.GetText, caption)
 return ('quest=%s type=%s map=%s playerMap=%s target=%s,%s,%s canvas=%sx%s player=%s marker=%s route=%s message=%s error=%s'):format(
  tostring(step.questId),tostring(step.type),tostring(current),tostring(best),
  tostring(step.uiMapID),tostring(step.x),tostring(step.y),tostring(width),tostring(height),
  shown(player),shown(marker),shown(route),tostring(text),tostring(FT.mapError))
end

local function playerPosition(mapID)
 local best = C_Map.GetBestMapForUnit('player')
 if not best then return nil, nil, 'Karakter konumu okunamıyor.' end
 local pos = C_Map.GetPlayerMapPosition(mapID, 'player')
 if pos then
  local x, y = pos:GetXY()
  if x >= 0 and x <= 1 and y >= 0 and y <= 1 and (x ~= 0 or y ~= 0) then return x, y end
 end
 if best ~= mapID then
  local info = C_Map.GetMapInfo(best)
  return nil, nil, 'Bulunduğun bölge: ' .. (info and info.name or tostring(best))
 end
 return nil, nil, 'Karakter konumu okunamıyor.'
end

local function distanceYards(step, x, y)
 local width, height = C_Map.GetMapWorldSize(step.uiMapID)
 if width and height and width > 0 and height > 0 then
  local dx, dy = (step.x-x)*width, (step.y-y)*height
  return math.sqrt(dx*dx + dy*dy)
 end
end

function FT.TargetStep()
 return FT.customTarget or FT.CurrentStep()
end

function FT.MapName(uiMapID)
 if not (C_Map and C_Map.GetMapInfo and uiMapID) then return nil end
 local ok, info = pcall(C_Map.GetMapInfo, uiMapID)
 return ok and info and info.name or nil
end

local function customStep(map, x, y, name)
 name = (type(name) == 'string' and name ~= '') and name or 'Seçtiğin nokta'
 return {stepId='custom-target', type='location', text=name, questTitle=name, uiMapID=map, x=x, y=y, fixed=true}
end

function FT.SetCustomTarget(map, x, y, name, silent)
 FT.customTarget = customStep(map, x, y, name)
 if ForeverTrailCharacter then ForeverTrailCharacter.customTarget = {map=map, x=x, y=y, name=name} end
 if not silent then FT.Print(('Hedef: %s (%.1f, %.1f). Kaldırmak için /ftrail iptal'):format(name or 'Seçtiğin nokta', x * 100, y * 100)) end
 FT.RefreshMap()
 if FT.Refresh then FT.Refresh() end
 if FT.RefreshRouteCard then FT.RefreshRouteCard(true) end
end

function FT.ClearCustomTarget()
 if not FT.customTarget then FT.Print('Özel hedef yok.'); return end
 FT.customTarget = nil
 if ForeverTrailCharacter then ForeverTrailCharacter.customTarget = nil end
 FT.Print('Özel hedef kaldırıldı.')
 FT.RefreshMap()
 if FT.Refresh then FT.Refresh() end
 if FT.RefreshRouteCard then FT.RefreshRouteCard() end
end

function FT.RestoreCustomTarget()
 local c = ForeverTrailCharacter and ForeverTrailCharacter.customTarget
 if type(c) == 'table' and type(c.map) == 'number' and type(c.x) == 'number' and type(c.y) == 'number' then
  FT.customTarget = customStep(c.map, c.x, c.y, c.name)
 end
end

-- Haritada Ctrl + sol tık: özel hedef noktası
local ensureOverlay
local clickInstalled
function FT.InstallMapClick()
 if clickInstalled or not (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.HookScript) then return end
 clickInstalled = true
 WorldMapFrame.ScrollContainer:HookScript('OnMouseUp', function(container, button)
  if button ~= 'LeftButton' or not container.GetNormalizedCursorPosition then return end
  local alt = IsAltKeyDown and IsAltKeyDown()
  if not alt and not IsControlKeyDown() then return end
  local ok, x, y = pcall(container.GetNormalizedCursorPosition, container)
  if not ok or type(x) ~= 'number' or type(y) ~= 'number' or x < 0 or x > 1 or y < 0 or y > 1 then return end
  local map = WorldMapFrame:GetMapID()
  if map and alt then FT.AddVia(map, x, y) elseif map then FT.SetCustomTarget(map, x, y) end
 end)
 -- Harita nasıl açılırsa açılsın (M tuşu dahil) çizim katmanını oluştur
 WorldMapFrame:HookScript('OnShow', function()
  local ok, err = pcall(ensureOverlay)
  if not ok then
   if FT.errors then FT.errors[#FT.errors + 1] = 'harita katmanı: ' .. tostring(err) end
   if FT.Print then FT.Print('Harita katmanı oluşturulamadı: ' .. tostring(err)) end
   return
  end
  pcall(FT.RefreshMap)
 end)
 if WorldMapFrame:IsShown() then pcall(ensureOverlay) end
end

-- Oyuncu hareket ettikçe otomatik çözülmüş hedefi en yakın noktaya günceller
function FT.Retarget()
 local step = FT.CurrentStep()
 if FT.customTarget or FT.complete or not step or not step.questId or not step.auto or not FT.ResolveQuestWaypoint then return end
 if ForeverTrailSettings and ForeverTrailSettings.retarget == false then return end
 local ok, map, x, y = pcall(FT.ResolveQuestWaypoint, step.questId, step.type, step.objectiveIndex)
 if not (ok and map and x and y) then return end
 if step.uiMapID ~= map or math.abs((step.x or 0) - x) > 0.003 or math.abs((step.y or 0) - y) > 0.003 then
  step.uiMapID, step.x, step.y = map, x, y
 end
end

FT.DistanceYards = distanceYards
FT.PlayerPosition = playerPosition

-- Returns resolved, attempted.
function FT.EnsureWaypoint(step, force)
 if not step or not step.questId or (step.x and step.y) or not FT.ResolveQuestWaypoint then return false, false end
 local now = GetTime and GetTime() or 0
 if not force and step.nextResolve and now < step.nextResolve then return false, false end
 step.nextResolve = now + 2
 local ok, map, x, y = pcall(FT.ResolveQuestWaypoint, step.questId, step.type, step.objectiveIndex)
 if ok and map and x and y then
  step.uiMapID, step.x, step.y = map, x, y
  step.auto = true
  return true, true
 end
 return false, true
end

local routeLines = {}
local function drawRouteLines(mapID)
 for _, line in ipairs(routeLines) do line:Hide() end
 local g = FT.guide
 if not (g and not g.live and mapID and overlay and overlay.CreateLine) then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local used = 0
 for i = 1, #g.steps - 1 do
  local a, b = g.steps[i], g.steps[i + 1]
  if a.x and a.y and b.x and b.y and a.uiMapID == mapID and b.uiMapID == mapID and (a.x ~= b.x or a.y ~= b.y) then
   used = used + 1
   local line = routeLines[used]
   if not line then
    line = overlay:CreateLine(nil, 'BACKGROUND')
    line:SetThickness(2)
    line:SetColorTexture(0.95, 0.72, 0.35, 0.45)
    routeLines[used] = line
   end
   line:SetStartPoint('TOPLEFT', overlay, a.x * w, -a.y * h)
   line:SetEndPoint('TOPLEFT', overlay, b.x * w, -b.y * h)
   line:Show()
  end
 end
end

local spawnDots = {}
local function drawSpawns(mapID, step)
 for _, d in ipairs(spawnDots) do d:Hide() end
 if ForeverTrailSettings and ForeverTrailSettings.spawns == false then return end
 if not (FT.SpawnPoints and step and mapID and overlay) then return end
 local ok, points = pcall(FT.SpawnPoints, step)
 if not ok or type(points) ~= 'table' then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local c = typeColor[step.type] or typeColor.manual
 local used = 0
 for _, p in ipairs(points) do
  if p.map == mapID then
   used = used + 1
   local d = spawnDots[used]
   if not d then
    d = overlay:CreateTexture(nil, 'BACKGROUND')
    d:SetTexture('Interface\\Cooldown\\star4')
    d:SetBlendMode('ADD')
    d:SetSize(16, 16)
    spawnDots[used] = d
   end
   d:SetVertexColor(c[1], c[2], c[3], 0.6)
   d:ClearAllPoints()
   d:SetPoint('CENTER', overlay, 'TOPLEFT', p.x * w, -p.y * h)
   d:Show()
  end
 end
end

local function drawDots(mapID, active)
 for _, d in ipairs(dots) do d:Hide() end
 local g = FT.guide
 if not (g and g.live and mapID and overlay) then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local used, attempts = 0, 0
 for _, s in ipairs(g.steps) do
  if s ~= active and s.questId then
   if not (s.x and s.y) and attempts < 2 then
    local _, tried = FT.EnsureWaypoint(s)
    if tried then attempts = attempts + 1 end
   end
   if s.uiMapID == mapID and s.x and s.y then
    used = used + 1
    local d = dots[used]
    if not d then
     d = overlay:CreateTexture(nil, 'ARTWORK')
     d:SetSize(10, 10)
     d:SetTexture('Interface\\Buttons\\WHITE8X8')
     dots[used] = d
    end
    d.step = s
    local c = typeColor[s.type] or typeColor.manual
    d:SetVertexColor(c[1], c[2], c[3], FT.FocusAlpha and FT.FocusAlpha(s.questId, 0.9) or 0.9)
    d:ClearAllPoints()
    d:SetPoint('CENTER', overlay, 'TOPLEFT', s.x * w, -s.y * h)
    d:Show()
   end
  end
 end
end

local lastLayerKey, lastLayerTime = nil, -100
-- Harita katmanlarını yeniden çizmeye zorla (veri ya da ayar değişince)
function FT.BumpLayers() FT.layerVersion = (FT.layerVersion or 0) + 1 end

local switchedKey -- açık haritanın en son hangi hedef için çevrildiği
function FT.RefreshMap()
 if not caption then return end
 local step = FT.TargetStep()
 local show = (FT.nav and FT.nav.step and FT.nav.step.hint) and FT.nav.step or step
 if FT.EnsureWaypoint(step) and not FT.chainPreview and show.uiMapID and WorldMapFrame:GetMapID() ~= show.uiMapID then WorldMapFrame:SetMapID(show.uiMapID) end
 -- Hedef adım değişince (rehber seçildi, adım ilerledi) açık harita o adımın haritasına geçer; rota yalnızca açık harita hedefin
 -- haritasıysa çizilir. Koordinatı hazır adımlar (bölge rehberleri) için yukarıdaki koşul hiç tetiklenmez. Sonra kullanıcı serbestçe gezinebilir.
 if show and WorldMapFrame:IsShown() then
  local key = tostring(FT.guide and FT.guide.guideId) .. ':' .. tostring(step and step.stepId) .. ':' .. tostring(show.uiMapID)
  if key ~= switchedKey then
   switchedKey = key
   if show.uiMapID and not FT.chainPreview and WorldMapFrame:GetMapID() ~= show.uiMapID then WorldMapFrame:SetMapID(show.uiMapID) end
  end
 end
 if FT.DrawChain then pcall(FT.DrawChain, WorldMapFrame:GetMapID()) end
 player:Hide()
 route:Hide()
 if routeGlow then routeGlow:Hide() end
 trailPts = nil
 for i = 1, #segCore do segCore[i]:Hide(); segGlow[i]:Hide() end
 if FT.HideRing then FT.HideRing(mapRing) end
 glow:Hide()
 label:Hide()
 if FT.DrawVia then pcall(FT.DrawVia, WorldMapFrame:GetMapID()) end
 -- Sabit katmanlar (görev bölgeleri, !/?, istasyonlar, noktalar) yalnızca bir şey değişince yeniden çizilir
 local mapID = WorldMapFrame:GetMapID()
 local layerKey = table.concat({tostring(mapID), math.floor(overlay:GetWidth()), math.floor(overlay:GetHeight()), FT.layerVersion or 0, tostring(step), tostring(FT.focusQuest)}, ':')
 if layerKey ~= lastLayerKey or GetTime() - lastLayerTime > 4 then
  lastLayerKey, lastLayerTime = layerKey, GetTime()
  -- Questie'deki "Kıta haritasında simgeleri gizle"
  local iconMap = mapID
  if ForeverTrailSettings and ForeverTrailSettings.hideContinent == true and C_Map and C_Map.GetMapInfo then
   local okInfo, info = pcall(C_Map.GetMapInfo, mapID)
   if okInfo and type(info) == 'table' and type(info.mapType) == 'number' and info.mapType <= 2 then iconMap = nil end
  end
  if FT.DrawNodes then pcall(FT.DrawNodes, iconMap) end
  if FT.DrawGivers then pcall(FT.DrawGivers, iconMap) end
  if FT.DrawStations then pcall(FT.DrawStations, iconMap) end
  if FT.DrawDungeons then pcall(FT.DrawDungeons, iconMap) end
  if FT.DrawTownsfolk then pcall(FT.DrawTownsfolk, iconMap) end
  if FT.DrawRares then pcall(FT.DrawRares, iconMap) end
  if FT.DrawPaths then pcall(FT.DrawPaths, mapID, step) end
  if FT.DrawPartyQuests then pcall(FT.DrawPartyQuests, iconMap) end
  drawDots(mapID, step)
  if FT.DrawObjectiveAreas and not (ForeverTrailSettings and ForeverTrailSettings.objareas == false) then
   pcall(FT.DrawObjectiveAreas, iconMap)
   drawSpawns(nil, step)
  else
   if FT.DrawObjectiveAreas then pcall(FT.DrawObjectiveAreas, nil) end
   drawSpawns(mapID, step)
  end
  drawRouteLines(mapID)
  if FT.DrawRouteNumbers then pcall(FT.DrawRouteNumbers, iconMap) end
 end
 if (FT.complete and not FT.customTarget) or not step or WorldMapFrame:GetMapID() ~= step.uiMapID then
  marker:Hide()
  caption:Hide()
  return
 end
 local color = typeColor[step.type] or typeColor.manual
 glow:SetVertexColor(color[1], color[2], color[3], 1)
 label:SetTextColor(color[1], color[2], color[3])
 local title = step.questTitle or (FT.guide and FT.guide.title) or ''
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local tx, ty
 if step.x and step.y then
  tx, ty = step.x*w, -step.y*h
  marker:ClearAllPoints()
  marker:SetPoint('CENTER', overlay, 'TOPLEFT', tx, ty)
  marker:Show()
  if FT.DrawRing and FT.AreaRadiusYards and C_Map and C_Map.GetMapWorldSize then
   local sized, worldWidth = pcall(C_Map.GetMapWorldSize, step.uiMapID)
   if sized and worldWidth and worldWidth > 0 then
    local radius = math.max(12, FT.AreaRadiusYards(step) / worldWidth * w)
    FT.DrawRing(mapRing, overlay, overlay, 'TOPLEFT', tx, ty, radius, 1, 0.85, 0.4, 0.9)
   end
  end
  glow:Show()
 else
  marker:Hide()
 end
 caption:Show()
 local ok, x, y, reason = pcall(playerPosition, step.uiMapID)
 if not ok or not x then
  caption:SetText('ForeverTrail  |  ' .. (ok and reason or 'Karakter konumu okunamıyor.'))
  return
 end
 local px, py = x*w, -y*h
 player:ClearAllPoints()
 player:SetPoint('CENTER', overlay, 'TOPLEFT', px, py)
 player:Show()
 if not tx then
  caption:SetText(('ForeverTrail  |  Sen: %.1f, %.1f  |  Görev hedefi bulunamadı'):format(x*100,y*100))
  return
 end
 if px ~= tx or py ~= ty then
  local r, g, b = 1, 0.82, 0.4
  if FT.MapTrailColor then r, g, b = FT.MapTrailColor() end
  local gx, gy = tx, ty
  local nav = FT.nav
  local viaHint = nav and nav.hint and nav.step and nav.step.uiMapID == step.uiMapID
  if viaHint then gx, gy = nav.step.x * w, -nav.step.y * h end
  -- yol verisi varsa (Polestar_Nav ya da öğrenilmiş yollar) rota kıvrımlıdır; yoksa düz çizgi
  local pts
  if not viaHint and FT.CurrentRoute and step.x and C_Map and C_Map.GetBestMapForUnit then
   local okMap, pm = pcall(C_Map.GetBestMapForUnit, 'player')
   if okMap and pm == step.uiMapID then
    local okSize, ww, wh = pcall(C_Map.GetMapWorldSize, step.uiMapID)
    local list = okSize and ww and FT.CurrentRoute(step.uiMapID, x, y, step.x, step.y, ww, wh)
    if list and #list >= 2 then
     pts = {}
     for i, p in ipairs(list) do pts[i] = {p[1] * w, -p[2] * h} end
    end
   end
  end
  pts = pts or {{px, py}, {tx, ty}}
  route:SetStartPoint('TOPLEFT', overlay, pts[1][1], pts[1][2])
  route:SetEndPoint('TOPLEFT', overlay, pts[2][1], pts[2][2])
  route:SetColorTexture(r, g, b, 0.5)
  route:Show()
  routeGlow:SetStartPoint('TOPLEFT', overlay, pts[1][1], pts[1][2])
  routeGlow:SetEndPoint('TOPLEFT', overlay, pts[2][1], pts[2][2])
  routeGlow:SetColorTexture(r, g, b, 0.10)
  routeGlow:Show()
  for i = 3, #pts do
   local k = i - 2
   if not segCore[k] then
    segGlow[k] = overlay:CreateLine(nil, 'ARTWORK'); segGlow[k]:SetThickness(9)
    segCore[k] = overlay:CreateLine(nil, 'ARTWORK'); segCore[k]:SetThickness(3)
   end
   segGlow[k]:SetColorTexture(r, g, b, 0.10); segCore[k]:SetColorTexture(r, g, b, 0.5)
   segGlow[k]:SetStartPoint('TOPLEFT', overlay, pts[i - 1][1], pts[i - 1][2]); segGlow[k]:SetEndPoint('TOPLEFT', overlay, pts[i][1], pts[i][2]); segGlow[k]:Show()
   segCore[k]:SetStartPoint('TOPLEFT', overlay, pts[i - 1][1], pts[i - 1][2]); segCore[k]:SetEndPoint('TOPLEFT', overlay, pts[i][1], pts[i][2]); segCore[k]:Show()
  end
  trailPts = viaHint and {{px, py}, {gx, gy}} or pts
 end
 local measured, yards = pcall(distanceYards, step, x, y)
 local distance = measured and yards and ('%.0f yd'):format(yards) or 'Mesafe okunamıyor'
 label:SetText(title .. '\n|cffffffff' .. distance .. '|r')
 label:Show()
 caption:SetText(('ForeverTrail  |  Sen: %.1f, %.1f  |  Hedef: %s'):format(x*100,y*100,distance))
end

ensureOverlay = function()
if not overlay then
 local canvas = WorldMapFrame:GetCanvas()
 overlay = CreateFrame('Frame', nil, canvas)
 overlay:SetAllPoints(canvas)
 local manager = WorldMapFrame.pinFrameLevelsManager
 local definitions = manager and manager.definitions
 local level = definitions and definitions.PIN_FRAME_LEVEL_DIG_SITE
 if level and level.overrideType then level = definitions[level.overrideType] end
 overlay:SetFrameLevel((level and level.startLevel) or (canvas:GetFrameLevel() + 2100))
 marker = overlay:CreateTexture(nil, 'OVERLAY')
 marker:SetSize(26, 26)
 local atlas = 'Waypoint-MapPin-Tracked'
 local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
 if info then marker:SetAtlas(atlas); marker:SetSize(32, 32)
 else marker:SetTexture('Interface\\TargetingFrame\\UI-RaidTargetingIcon_4') end
 glow = overlay:CreateTexture(nil, 'ARTWORK')
 glow:SetTexture('Interface\\Cooldown\\star4')
 glow:SetBlendMode('ADD')
 glow:SetSize(44, 44)
 glow:SetPoint('CENTER', marker, 'CENTER')
 label = overlay:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 label:SetPoint('BOTTOM', marker, 'TOP', 0, 8)
 label:SetWidth(240)
 label:SetJustifyH('CENTER')
 label:SetShadowOffset(1, -1)
 do
  local path, size = label:GetFont()
  if path and size then label:SetFont(WOWTR_Font2 or path, size + 1, 'OUTLINE') end
 end
 player = overlay:CreateTexture(nil, 'OVERLAY')
 player:SetSize(16, 16)
 player:SetTexture('Interface\\TargetingFrame\\UI-RaidTargetingIcon_6')
 routeGlow = overlay:CreateLine(nil, 'ARTWORK')
 routeGlow:SetThickness(9)
 routeGlow:SetColorTexture(1, 0.82, 0.4, 0.10)
 route = overlay:CreateLine(nil, 'ARTWORK')
 route:SetThickness(3)
 route:SetColorTexture(1, 0.82, 0.4, 0.5)
 caption = WorldMapFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 caption:SetPoint('BOTTOM', WorldMapFrame, 'BOTTOM', 0, 12)
 caption:SetShadowOffset(1, -1)
 caption:SetTextColor(1, 0.93, 0.8)
 if WOWTR_Font2 then
  local _, size, flags = caption:GetFont()
  caption:SetFont(WOWTR_Font2, size, flags)
 end
 local elapsed = 0
 FT.mapParts = {overlay=overlay, marker=marker, glow=glow, label=label, player=player, route=route, routeGlow=routeGlow, caption=caption}
 overlay:SetScript('OnUpdate', function(_, dt)
  pulse = pulse + dt
  updateTrail()
  if glow and glow:IsShown() then
   local wave = math.sin(pulse * 4)
   local size = 44 + 8 * wave
   glow:SetSize(size, size)
   glow:SetAlpha(0.7 + 0.25 * wave)
  end
  elapsed = elapsed + dt
  if elapsed >= 0.2 then
   elapsed = 0
   FT.RefreshMap()
  end
 end)
 if FT.GuardFrame then FT.GuardFrame(overlay, 'OnUpdate', 'harita') end
 overlay:HookScript('OnShow', FT.RefreshMap)
 overlay:SetScript('OnSizeChanged', FT.RefreshMap)
 hooksecurefunc(WorldMapFrame, 'SetMapID', FT.RefreshMap)
end
 if FT.ApplyFont then pcall(FT.ApplyFont) end
end

function FT.OpenMap()
 local step = FT.TargetStep()
 if FT.complete and not FT.customTarget then FT.Print('Rehber tamamlandı.'); return end
 FT.EnsureWaypoint(step, true)
 if not step or not step.uiMapID then
  FT.Print('Bu adım için harita konumu kayıtlı değil.')
  return
 end
 local hasCoordinates = step.x and step.y
 local ok, err = pcall(function()
  ShowUIPanel(WorldMapFrame)
  WorldMapFrame:SetMapID(step.uiMapID)
  ensureOverlay()
  FT.RefreshMap()
 end)
 if ok then
  FT.mapError = nil
  if not hasCoordinates and not step.x then
   FT.Print('Görev haritası açıldı, ancak istemci hedef koordinatı vermedi.')
  end
 else
  FT.mapError = tostring(err)
  if step.x and step.y then FT.Print(('Hedef: %.1f, %.1f (harita %d)'):format(step.x*100, step.y*100, step.uiMapID))
  else FT.Print('Harita açılamadı: ' .. tostring(err)) end
 end
end



----------------------------------------------------------------------
-- Zincir güzergahı: zincirdeki görevleri sırayla numaralayıp haritada çizer
----------------------------------------------------------------------
local chainMarks, chainLines = {}, {}
local chainColors = {done={0.55, 0.88, 0.5}, current={1, 0.82, 0.3}, active={0.98, 0.8, 0.4}, open={0.75, 0.85, 1}, locked={0.62, 0.6, 0.58}}

function FT.SetChainPreview(rows)
 if type(rows) ~= 'table' or #rows == 0 or not FT.ResolveQuestWaypoint then FT.chainPreview = nil; return end
 local list = {}
 for n, r in ipairs(rows) do
  if n > 24 then break end
  local kind = r.active and 'objective' or 'accept'
  local ok, map, x, y = pcall(FT.ResolveQuestWaypoint, r.id, kind, 1)
  local state = r.current and 'current' or (r.status == 'Tamamlandı' and 'done' or (r.active and 'active' or (r.status == 'Alınabilir' and 'open' or 'locked')))
  list[#list + 1] = {n=n, id=r.id, title=r.title, map=ok and map or nil, x=ok and x or nil, y=ok and y or nil, state=state}
 end
 FT.chainPreview = list
 if FT.RefreshMap and caption then FT.RefreshMap() end
end

function FT.ClearChainPreview()
 if not FT.chainPreview then return end
 FT.chainPreview = nil
 if FT.DrawChain and overlay then FT.DrawChain(0) end
end

function FT.DrawChain(mapID)
 for _, m in ipairs(chainMarks) do m.bg:Hide(); m.text:Hide() end
 for _, l in ipairs(chainLines) do l:Hide() end
 local list = FT.chainPreview
 if not (list and overlay and mapID) then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local used, lineUsed, previous = 0, 0, nil
 for _, item in ipairs(list) do
  if item.map == mapID and item.x and item.y then
   used = used + 1
   local mark = chainMarks[used]
   if not mark then
    mark = {bg=overlay:CreateTexture(nil, 'OVERLAY'), text=overlay:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')}
    mark.bg:SetTexture('Interface\\Cooldown\\star4'); mark.bg:SetBlendMode('ADD'); mark.bg:SetSize(34, 34)
    mark.text:SetShadowOffset(1, -1)
    chainMarks[used] = mark
   end
   local c = chainColors[item.state] or chainColors.locked
   mark.bg:ClearAllPoints(); mark.bg:SetPoint('CENTER', overlay, 'TOPLEFT', item.x * w, -item.y * h)
   mark.bg:SetVertexColor(c[1], c[2], c[3], 0.95)
   mark.text:ClearAllPoints(); mark.text:SetPoint('CENTER', mark.bg, 'CENTER')
   mark.text:SetText(item.n); mark.text:SetTextColor(1, 1, 1)
   mark.bg:Show(); mark.text:Show()
   if previous and (previous.x ~= item.x or previous.y ~= item.y) then
    lineUsed = lineUsed + 1
    local line = chainLines[lineUsed]
    if not line then
     line = overlay:CreateLine(nil, 'ARTWORK')
     line:SetThickness(3)
     chainLines[lineUsed] = line
    end
    line:SetColorTexture(c[1], c[2], c[3], 0.7)
    line:SetStartPoint('TOPLEFT', overlay, previous.x * w, -previous.y * h)
    line:SetEndPoint('TOPLEFT', overlay, item.x * w, -item.y * h)
    line:Show()
   end
   previous = item
  end
 end
end

function FT.ShowChainOnMap()
 local list = FT.chainPreview
 if not list then return FT.Print('Zincir bulunamadı.') end
 local target
 for _, item in ipairs(list) do if item.map and item.state == 'current' then target = item end end
 if not target then for _, item in ipairs(list) do if item.map then target = item; break end end end
 if not target then return FT.Print('Zincirdeki görevlerin harita konumu bulunamadı.') end
 local ok, err = pcall(function()
  ShowUIPanel(WorldMapFrame)
  WorldMapFrame:SetMapID(target.map)
  ensureOverlay()
  FT.RefreshMap()
 end)
 if not ok then FT.Print('Harita açılamadı: ' .. tostring(err)) end
end


-- Çizilen yol: numaralı noktalar, geçilen kısım soluk gri, kalan kısım mavi; giriş/ara nokta işareti
local viaMark, viaLabel
local pathMarks, pathLines = {}, {}
function FT.DrawVia(mapID)
 if viaMark then viaMark:Hide(); viaLabel:Hide() end
 for _, m in ipairs(pathMarks) do m:Hide() end
 for _, l in ipairs(pathLines) do l:Hide() end
 if not overlay then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local points, passed = {}, 0
 if FT.PathPoints then points, passed = FT.PathPoints() end
 local prev, nl = nil, 0
 for i, pt in ipairs(points) do
  if pt.uiMapID == mapID then
   local m = pathMarks[i]
   if not m then
    m = CreateFrame('Frame', nil, overlay); m:SetSize(18, 18)
    m.bg = m:CreateTexture(nil, 'ARTWORK'); m.bg:SetTexture('Interface\\CHARACTERFRAME\\TempPortraitAlphaMask'); m.bg:SetAllPoints()
    m.t = m:CreateFontString(nil, 'OVERLAY'); m.t:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', 10, 'OUTLINE'); m.t:SetPoint('CENTER')
    pathMarks[i] = m
   end
   local done = i <= passed
   m.bg:SetVertexColor(done and 0.4 or 0.2, done and 0.4 or 0.55, done and 0.4 or 1, done and 0.6 or 0.95)
   m.t:SetText(i)
   m:SetFrameLevel(overlay:GetFrameLevel() + 9)
   m:ClearAllPoints(); m:SetPoint('CENTER', overlay, 'TOPLEFT', pt.x * w, -pt.y * h); m:Show()
   if prev and overlay.CreateLine then
    nl = nl + 1
    local l = pathLines[nl]
    if not l then l = overlay:CreateLine(nil, 'ARTWORK'); l:SetThickness(3); pathLines[nl] = l end
    if done then l:SetColorTexture(0.6, 0.6, 0.6, 0.45) else l:SetColorTexture(0.35, 0.65, 1, 0.85) end
    l:SetStartPoint('TOPLEFT', overlay, prev.x * w, -prev.y * h)
    l:SetEndPoint('TOPLEFT', overlay, pt.x * w, -pt.y * h)
    l:Show()
   end
   prev = pt
  else prev = nil end
 end
 local nav = FT.nav
 if not (nav and nav.hint and nav.step and nav.step.uiMapID == mapID and nav.px) then return end
 if not viaMark then
  viaMark = overlay:CreateTexture(nil, 'OVERLAY')
  viaMark:SetTexture('Interface\\Cooldown\\star4'); viaMark:SetBlendMode('ADD'); viaMark:SetSize(36, 36)
  viaMark:SetVertexColor(0.6, 0.85, 1, 1)
  viaLabel = overlay:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  viaLabel:SetTextColor(0.7, 0.9, 1); viaLabel:SetShadowOffset(1, -1)
 end
 local gx, gy = nav.step.x * w, -nav.step.y * h
 viaMark:ClearAllPoints(); viaMark:SetPoint('CENTER', overlay, 'TOPLEFT', gx, gy)
 viaLabel:ClearAllPoints(); viaLabel:SetPoint('BOTTOM', viaMark, 'TOP', 0, 2)
 viaLabel:SetText(nav.hint)
 viaMark:Show(); viaLabel:Show()
 trailPts = {{nav.px * w, -nav.py * h}, {gx, gy}}
end
