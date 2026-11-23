local _, FT = ...
local OUTDOOR = {[0]=233.33, 200, 166.67, 133.33, 100, 66.67}
local INDOOR = {[0]=150, 120, 90, 60, 40, 25}

-- dx, dy: hedef - oyuncu (yard, y aşağı). Dönüş: mini harita kenarı = 1 olacak şekilde normalize (x sağ, y yukarı).
function FT.MinimapOffset(dx, dy, facing, rotate, radius)
 local ux, uy = dx, -dy
 if rotate and facing then
  local c, s = math.cos(facing), math.sin(facing)
  ux, uy = ux * c + uy * s, -ux * s + uy * c
 end
 return ux / radius, uy / radius
end

local pin

-- İçeride mi? Mini haritanın kendi yakınlaştırma ayarlarına bak (dışarı/içeri ayrı tutulur)
local function indoors()
 local zoom = Minimap:GetZoom() or 0
 local out = tonumber(GetCVar and GetCVar('minimapZoom'))
 local inside = tonumber(GetCVar and GetCVar('minimapInsideZoom'))
 if out and inside and out ~= inside then return zoom == inside end
 return IsIndoors and IsIndoors() and true or false
end

local function radiusYards()
 local zoom = Minimap:GetZoom() or 0
 return (indoors() and INDOOR or OUTDOOR)[zoom] or 150
end
FT.MinimapRadius = radiusYards

-- Ortak yerleştirici: hangi simgelerin gösterileceğini modüller seyrek hesaplar,
-- konumları burada her karede güncellenir (mini harita akarken simgeler kaymasın).
local tracked = {}
function FT.MinimapTrack(pin, map, x, y, keepEdge)
 if not pin then return end
 pin.ftMap, pin.ftX, pin.ftY, pin.ftEdge = map, x, y, keepEdge
 tracked[pin] = true
end
FT.MinimapPins = tracked

-- Mini haritada çizilen yol: oyuncudan sıradaki noktaya ve noktalar arasına, çembere kırpılmış çizgi
local pathFrame, pathLines = nil, {}
local function clip(ax, ay, bx, by, r)
 local function inside(x, y) return x * x + y * y <= r * r end
 local ia, ib = inside(ax, ay), inside(bx, by)
 if ia and ib then return ax, ay, bx, by end
 local dx, dy = bx - ax, by - ay
 local A = dx * dx + dy * dy
 if A == 0 then return nil end
 local B = 2 * (ax * dx + ay * dy)
 local C = ax * ax + ay * ay - r * r
 local disc = B * B - 4 * A * C
 if disc < 0 then return nil end
 local sq = math.sqrt(disc)
 local t1, t2 = (-B - sq) / (2 * A), (-B + sq) / (2 * A)
 local s, e = math.max(0, t1), math.min(1, t2)
 if s > e then return nil end
 return ax + dx * s, ay + dy * s, ax + dx * e, ay + dy * e
end

local function drawPath(map, px, py, ww, wh, radius, facing, rotate, half)
 for _, l in ipairs(pathLines) do l:Hide() end
 if not (FT.PathPoints and Minimap.CreateLine) then return end
 local points, passed = FT.PathPoints()
 if #points <= passed then return end
 if not pathFrame then
  pathFrame = CreateFrame('Frame', nil, Minimap); pathFrame:SetAllPoints(); pathFrame:SetFrameLevel(Minimap:GetFrameLevel() + 4)
 end
 local r = half * 0.95
 local lastX, lastY = 0, 0
 local n = 0
 for i = passed + 1, #points do
  local pt = points[i]
  if pt.uiMapID ~= map then break end
  local nx, ny = FT.MinimapOffset((pt.x - px) * ww, (pt.y - py) * wh, facing, rotate, radius)
  local x, y = nx * half, ny * half
  local ax, ay, bx, by = clip(lastX, lastY, x, y, r)
  if ax then
   n = n + 1
   local l = pathLines[n]
   if not l then l = pathFrame:CreateLine(nil, 'ARTWORK'); l:SetThickness(2.5); pathLines[n] = l end
   l:SetColorTexture(0.35, 0.65, 1, 0.9)
   l:SetStartPoint('CENTER', Minimap, ax, ay); l:SetEndPoint('CENTER', Minimap, bx, by)
   l:Show()
  end
  lastX, lastY = x, y
 end
end

FT.MinimapClip = clip
local placer = CreateFrame and CreateFrame('Frame')
if placer then placer:SetScript('OnUpdate', function()
 if not (Minimap and Minimap:IsVisible() and C_Map and C_Map.GetBestMapForUnit) then return end
 local map = C_Map.GetBestMapForUnit('player')
 local pos = map and C_Map.GetPlayerMapPosition(map, 'player')
 if not pos then return end
 local px, py = pos:GetXY()
 local ok, ww, wh = pcall(C_Map.GetMapWorldSize, map)
 if not ok or not ww or ww <= 0 then return end
 local radius = radiusYards()
 local rotate = GetCVar and GetCVar('rotateMinimap') == '1'
 local facing = GetPlayerFacing and GetPlayerFacing()
 local half = Minimap:GetWidth() / 2
 pcall(drawPath, map, px, py, ww, wh, radius, facing, rotate, half)
 for p in pairs(tracked) do
  if p:IsShown() or p.ftOut then
   if p.ftMap ~= map then p:Hide(); p.ftOut = nil
   else
    local nx, ny = FT.MinimapOffset((p.ftX - px) * ww, (p.ftY - py) * wh, facing, rotate, radius)
    local len = math.sqrt(nx * nx + ny * ny)
    if len > 0.94 and not p.ftEdge then
     if p:IsShown() then p:Hide(); p.ftOut = true end
    else
     if p.ftEdge and len > 0.9 then nx, ny = nx / len * 0.9, ny / len * 0.9 end
     p:ClearAllPoints(); p:SetPoint('CENTER', Minimap, 'CENTER', nx * half, ny * half)
     if p.ftOut then p.ftOut = nil; p:Show() end
     if FT.MinimapFade and not p.ftNoFade then p:SetAlpha((p.ftAlpha or 1) * FT.MinimapFade(nx, ny)) end
    end
   end
  end
 end
end) end

-- Hedefe giden rota: oyuncudan hedef işaretine sarı, parıltılı çizgi; üstünde hedefe doğru akan noktalar.
-- Rota, yol verisi varsa (Polestar_Nav ya da öğrenilmiş yollar, Map/Roads.lua) kıvrımlıdır; yoksa düz çizgi.
-- Çizgiler Minimap'in kendi katmanına değil, üstteki ayrı bir çerçeveye konur: aksi halde mini haritanın kendi çizimi üstlerine biner.
-- Çemberin dışına taşan kısım kenarda kırpılır. Ayar: minimapRoute (kapatılabilir).
local routeFrame
local glowLines, coreLines, routeDots = {}, {}, {}
local ROUTE_R, ROUTE_G, ROUTE_B = 1, 0.85, 0.15
local lastSegments = 0
local function hideRoute()
 for _, l in ipairs(glowLines) do l:Hide() end
 for _, l in ipairs(coreLines) do l:Hide() end
 for _, d in ipairs(routeDots) do d:Hide() end
 lastSegments = 0
end
-- points: mini harita piksel koordinatında {{x, y}, ...}; ilk nokta (0, 0) = oyuncu
local function drawRoute(points, half)
 if ForeverTrailSettings and ForeverTrailSettings.minimapRoute == false or not Minimap.CreateLine or not points or #points < 2 then return hideRoute() end
 if not routeFrame then
  routeFrame = CreateFrame('Frame', nil, Minimap)
  routeFrame:SetAllPoints()
  routeFrame:SetFrameLevel(Minimap:GetFrameLevel() + 6)
 end
 local r = half * 0.95
 local segs, total = {}, 0
 for i = 2, #points do
  local ax, ay, bx, by = clip(points[i - 1][1], points[i - 1][2], points[i][1], points[i][2], r)
  if ax then
   local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
   if len > 0.5 then segs[#segs + 1] = {ax, ay, bx, by, len, total}; total = total + len end
  end
 end
 if total < 10 then return hideRoute() end
 for i, sg in ipairs(segs) do
  local glow, core = glowLines[i], coreLines[i]
  if not glow then
   glow = routeFrame:CreateLine(nil, 'ARTWORK'); glow:SetThickness(7); glowLines[i] = glow
   core = routeFrame:CreateLine(nil, 'OVERLAY'); core:SetThickness(2.5); coreLines[i] = core
  end
  glow:SetColorTexture(ROUTE_R, ROUTE_G, ROUTE_B, 0.16)
  glow:SetStartPoint('CENTER', Minimap, sg[1], sg[2]); glow:SetEndPoint('CENTER', Minimap, sg[3], sg[4]); glow:Show()
  core:SetColorTexture(ROUTE_R, ROUTE_G, ROUTE_B, 0.85)
  core:SetStartPoint('CENTER', Minimap, sg[1], sg[2]); core:SetEndPoint('CENTER', Minimap, sg[3], sg[4]); core:Show()
 end
 for i = #segs + 1, #glowLines do glowLines[i]:Hide(); coreLines[i]:Hide() end
 lastSegments = #segs
 -- akan noktalar: yol boyunca oyuncudan hedefe doğru
 local spacing = 16
 local at = ((GetTime and GetTime() or 0) * 28) % spacing
 local n, si = 0, 1
 while at < total - 4 and n < 40 do
  while segs[si + 1] and at > segs[si][6] + segs[si][5] do si = si + 1 end
  local sg = segs[si]
  local t = (at - sg[6]) / sg[5]
  n = n + 1
  local d = routeDots[n]
  if not d then d = routeFrame:CreateTexture(nil, 'OVERLAY', nil, 2); d:SetSize(4, 4); routeDots[n] = d end
  d:SetColorTexture(1, 0.97, 0.7, 0.35 + 0.6 * (at / total))
  d:ClearAllPoints(); d:SetPoint('CENTER', Minimap, 'CENTER', sg[1] + (sg[3] - sg[1]) * t, sg[2] + (sg[4] - sg[2]) * t); d:Show()
  at = at + spacing
 end
 for i = n + 1, #routeDots do routeDots[i]:Hide() end
end
FT.MinimapRouteInfo = function() return {core = coreLines[1], glow = glowLines[1], dots = routeDots, segments = lastSegments} end -- test ve tanı için

-- Rotanın mini harita piksel noktaları: yol verisi varsa kıvrımlı, yoksa oyuncudan işarete düz çizgi
local function routePixels(nav, ex, ey, half, radius, facing, rotate)
 local step = nav.step
 if FT.CurrentRoute and step and step.x and step.uiMapID and nav.px and C_Map and C_Map.GetBestMapForUnit then
  local okMap, map = pcall(C_Map.GetBestMapForUnit, 'player')
  if okMap and map == step.uiMapID then
   local okSize, ww, wh = pcall(C_Map.GetMapWorldSize, map)
   local pts = okSize and ww and FT.CurrentRoute(map, nav.px, nav.py, step.x, step.y, ww, wh)
   if pts then
    local out = {}
    for i, p in ipairs(pts) do
     local nx, ny = FT.MinimapOffset((p[1] - nav.px) * ww, (p[2] - nav.py) * wh, facing, rotate, radius)
     out[i] = {nx * half, ny * half}
    end
    return out
   end
  end
 end
 return {{0, 0}, {ex, ey}}
end

function FT.UpdateMinimapPin()
 if not pin then return end
 local nav = FT.nav
 if not nav or ForeverTrailSettings.minimap == false or not Minimap or not Minimap:IsVisible() then
  if pin:IsShown() then pin:Hide() end
  hideRoute()
  return
 end
 local rotate = GetCVar and GetCVar('rotateMinimap') == '1'
 local facing = GetPlayerFacing and GetPlayerFacing()
 local nx, ny = FT.MinimapOffset(nav.dx, nav.dy, facing, rotate, radiusYards())
 local length = math.sqrt(nx * nx + ny * ny)
 local edge = length > 0.9
 if edge then nx, ny = nx / length * 0.9, ny / length * 0.9 end
 local half = Minimap:GetWidth() / 2
 pin:SetScale(FT.Scale and FT.Scale('mmIcons') or 1)
 pin:ClearAllPoints()
 pin:SetPoint('CENTER', Minimap, 'CENTER', nx * half, ny * half)
 drawRoute(routePixels(nav, nx * half, ny * half, half, radiusYards(), facing, rotate), half)
 local color = (FT.TypeColor and FT.TypeColor[nav.step.type]) or {1, 0.82, 0.2}
 pin.glow:SetVertexColor(color[1], color[2], color[3], 1)
 if not edge and FT.DrawRing then
  local area = nav.hint and 12 or FT.AreaRadiusYards(nav.step)
  local px = math.max(9, math.min(half * 0.85, area / radiusYards() * half))
  local wave = 1 + 0.04 * math.sin(GetTime() * 3)
  FT.DrawRing(pin.ring, pin, pin, 'CENTER', 0, 0, px * wave, color[1], color[2], color[3], 0.9)
 elseif FT.HideRing then
  FT.HideRing(pin.ring)
 end
 pin.icon:SetAlpha(edge and 0.7 or 1)
 pin.glow:SetAlpha(edge and 0.5 or 0.9)
 if not pin:IsShown() then pin:Show() end
end

function FT.CreateMinimapPin()
 if pin or not Minimap then return end
 pin = CreateFrame('Frame', 'ForeverTrailMinimapPin', Minimap)
 FT.minimapPin = pin
 pin:SetSize(18, 18)
 pin.ftInfo = {kind = 'target'}
 pin.ring = {}
 pin:SetFrameStrata('HIGH')
 pin.glow = pin:CreateTexture(nil, 'ARTWORK')
 pin.glow:SetTexture('Interface\\Cooldown\\star4')
 pin.glow:SetBlendMode('ADD')
 pin.glow:SetSize(34, 34)
 pin.glow:SetPoint('CENTER')
 pin.icon = pin:CreateTexture(nil, 'OVERLAY')
 pin.icon:SetTexture('Interface\\TargetingFrame\\UI-RaidTargetingIcon_4')
 pin.icon:SetAllPoints()
 pin:Hide()
 local driver = CreateFrame('Frame')
 FT.minimapDriver = driver
 local elapsed = 0
 driver:SetScript('OnUpdate', function(_, dt)
  elapsed = elapsed + dt
  if elapsed >= 0.05 then elapsed = 0; FT.UpdateMinimapPin() end
 end)
end
