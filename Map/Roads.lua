local _, FT = ...

-- Öğrenen yol ağı: WoW addon API'si arazi ya da yol verisi vermez. Bu yüzden yürüdüğün yollar küçük bir ağa kaydedilir
-- (her harita bir ızgara; komşu hücreler arasında bağlantı bitleri) ve hedefe giden rota bu ağ üzerinde A* ile bulunur.
-- Rota öğrenilmiş yollardan geçer (kıvrımlı); ağ hedefe ya da oyuncuya ulaşmıyorsa nil döner ve düz çizgiye düşülür.
-- Kayıt: ForeverTrailData.roads[haritaNo][hücreAnahtarı] = komşu bit maskesi. Kapatmak için ForeverTrailSettings.roadsLearn = false.

local CELLS = 250            -- bir harita kenarındaki hücre sayısı (büyük bir bölgede ~14 yd)
local MAX_NODES = 9000       -- harita başına en çok hücre (kayıt dosyası şişmesin)
local MAX_JUMP = 4           -- iki kayıt arası bu kadar hücreden uzaksa zıplama sayılır (bağlanmaz)
local START_R, GOAL_R = 6, 9 -- oyuncuya / hedefe en yakın yol hücresinin aranacağı yarıçap (hücre)
local MAX_EXPAND = 7000      -- A* en çok bu kadar hücre açar
local DIRS = {{1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {1, -1}} -- bit i = 2^i

local version = 0 -- yeni hücre öğrenilince artar (önbellek geçersizleşir)
FT.RoadsVersion = function() return version end

local function store()
 ForeverTrailData = ForeverTrailData or {}
 ForeverTrailData.roads = ForeverTrailData.roads or {}
 return ForeverTrailData.roads
end

local function cell(v) return math.max(0, math.min(CELLS - 1, math.floor(v * CELLS))) end
local function key(cx, cy) return cx * 1000 + cy end
local function unkey(k) return math.floor(k / 1000), k % 1000 end

local function hasBit(mask, i) return math.floor(mask / 2 ^ i) % 2 == 1 end

local counts = {}
local function nodeCount(map, road)
 if counts[map] then return counts[map] end
 local n = 0
 for _ in pairs(road) do n = n + 1 end
 counts[map] = n
 return n
end

local function touch(map, road, k)
 if road[k] == nil then
  if nodeCount(map, road) >= MAX_NODES then return false end
  road[k] = 0
  counts[map] = counts[map] + 1
  version = version + 1
 end
 return true
end

local function link(map, road, ax, ay, bx, by)
 local dx, dy = bx - ax, by - ay
 for i, d in ipairs(DIRS) do
  if d[1] == dx and d[2] == dy then
   local ka, kb = key(ax, ay), key(bx, by)
   if not (touch(map, road, ka) and touch(map, road, kb)) then return end
   local bitA, bitB = 2 ^ (i - 1), 2 ^ ((i + 3) % 8)
   if not hasBit(road[ka], i - 1) then road[ka] = road[ka] + bitA; version = version + 1 end
   if not hasBit(road[kb], (i + 3) % 8) then road[kb] = road[kb] + bitB end
   return
  end
 end
end

-- a'dan b'ye hücre hücre ilerle ve ardışık hücreleri bağla
local function addSegment(map, road, ax, ay, bx, by)
 local steps = math.max(math.abs(bx - ax), math.abs(by - ay))
 local px, py = ax, ay
 for s = 1, steps do
  local cx = math.floor(ax + (bx - ax) * s / steps + 0.5)
  local cy = math.floor(ay + (by - ay) * s / steps + 0.5)
  if cx ~= px or cy ~= py then link(map, road, px, py, cx, cy) end
  px, py = cx, cy
 end
end

-- Bir konum kaydı (harita, 0-1 koordinat). Ardışık yakın konumlar bağlanır.
local last
function FT.RoadsRecord(map, x, y)
 if not (map and x and y) then return end
 local cx, cy = cell(x), cell(y)
 local road = store()[map]
 if not road then road = {}; store()[map] = road end
 if last and last.map == map then
  local d = math.max(math.abs(cx - last.cx), math.abs(cy - last.cy))
  if d == 0 then return end
  if d <= MAX_JUMP then addSegment(map, road, last.cx, last.cy, cx, cy) else touch(map, road, key(cx, cy)) end
 else
  touch(map, road, key(cx, cy))
 end
 last = {map = map, cx = cx, cy = cy}
end
function FT.RoadsBreak() last = nil end

----------------------------------------------------------------------
-- Rota (A*)
----------------------------------------------------------------------
local function nearest(road, x, y, radius)
 local cx, cy = cell(x), cell(y)
 local best, bestD
 for dx = -radius, radius do
  for dy = -radius, radius do
   local k = key(cx + dx, cy + dy)
   if cx + dx >= 0 and cy + dy >= 0 and road[k] ~= nil then
    local d = dx * dx + dy * dy
    if d <= radius * radius and (not bestD or d < bestD) then best, bestD = k, d end
   end
  end
 end
 return best
end

-- ikili yığın (en küçük f önde)
local function push(heap, f, k)
 heap[#heap + 1] = {f, k}
 local i = #heap
 while i > 1 do
  local p = math.floor(i / 2)
  if heap[p][1] <= heap[i][1] then break end
  heap[p], heap[i] = heap[i], heap[p]; i = p
 end
end
local function pop(heap)
 local top = heap[1]
 local last = table.remove(heap)
 if #heap > 0 then
  heap[1] = last
  local i = 1
  while true do
   local l, r, s = i * 2, i * 2 + 1, i
   if l <= #heap and heap[l][1] < heap[s][1] then s = l end
   if r <= #heap and heap[r][1] < heap[s][1] then s = r end
   if s == i then break end
   heap[s], heap[i] = heap[i], heap[s]; i = s
  end
 end
 return top
end

local function simplify(points, eps)
 if #points < 3 then return points end
 local function dist(p, a, b)
  local dx, dy = b[1] - a[1], b[2] - a[2]
  local len2 = dx * dx + dy * dy
  if len2 == 0 then return math.sqrt((p[1] - a[1]) ^ 2 + (p[2] - a[2]) ^ 2) end
  local t = math.max(0, math.min(1, ((p[1] - a[1]) * dx + (p[2] - a[2]) * dy) / len2))
  return math.sqrt((p[1] - a[1] - t * dx) ^ 2 + (p[2] - a[2] - t * dy) ^ 2)
 end
 local keep = {[1] = true, [#points] = true}
 local function rec(i, j)
  local worst, at = 0, nil
  for m = i + 1, j - 1 do
   local d = dist(points[m], points[i], points[j])
   if d > worst then worst, at = d, m end
  end
  if at and worst > eps then keep[at] = true; rec(i, at); rec(at, j) end
 end
 rec(1, #points)
 local out = {}
 for i, p in ipairs(points) do if keep[i] then out[#out + 1] = p end end
 return out
end

-- Dönüş: {{x, y}, ...} (başlangıç ve hedef dahil, 0-1 koordinat) ya da nil
function FT.RoadRoute(map, sx, sy, tx, ty, ww, wh)
 local road = store()[map]
 if not road then return nil end
 local start, goal = nearest(road, sx, sy, START_R), nearest(road, tx, ty, GOAL_R)
 if not (start and goal) then return nil end
 local wx, wy = (ww or CELLS) / CELLS, (wh or CELLS) / CELLS
 local gx, gy = unkey(goal)
 local function h(k) local x, y = unkey(k); return math.sqrt(((x - gx) * wx) ^ 2 + ((y - gy) * wy) ^ 2) end
 local g, from, closed, heap = {[start] = 0}, {}, {}, {}
 push(heap, h(start), start)
 local expanded, found = 0, false
 while #heap > 0 and expanded < MAX_EXPAND do
  local node = pop(heap)
  local k = node[2]
  if k == goal then found = true; break end
  if not closed[k] then
   closed[k] = true; expanded = expanded + 1
   local x, y = unkey(k)
   local mask = road[k] or 0
   for i, d in ipairs(DIRS) do
    if hasBit(mask, i - 1) then
     local nk = key(x + d[1], y + d[2])
     if road[nk] ~= nil and not closed[nk] then
      local cost = g[k] + math.sqrt((d[1] * wx) ^ 2 + (d[2] * wy) ^ 2)
      if not g[nk] or cost < g[nk] then g[nk] = cost; from[nk] = k; push(heap, cost + h(nk), nk) end
     end
    end
   end
  end
 end
 if not found then return nil end
 local cells = {}
 local k = goal
 while k do
  local x, y = unkey(k)
  table.insert(cells, 1, {(x + 0.5) / CELLS, (y + 0.5) / CELLS})
  k = from[k]
 end
 cells = simplify(cells, 0.6 / CELLS)
 local out = {{sx, sy}}
 for _, p in ipairs(cells) do out[#out + 1] = p end
 out[#out + 1] = {tx, ty}
 -- yol, düz çizgiden çok uzunsa (yanlış öğrenilmiş uzun dolambaç) kullanma
 local function length(list)
  local total = 0
  for i = 2, #list do total = total + math.sqrt(((list[i][1] - list[i - 1][1]) * wx * CELLS) ^ 2 + ((list[i][2] - list[i - 1][2]) * wy * CELLS) ^ 2) end
  return total
 end
 local straight = length({{sx, sy}, {tx, ty}})
 if straight > 0 and length(out) > straight * 4 then return nil end
 return out
end

-- Öğrenilmiş yollardan önbellekli rota: aynı hedef ve oyuncu yakınsa hesap tekrarlanmaz.
local cache = {}
local function learnedRoute(map, px, py, gx, gy, ww, wh)
 local now = GetTime and GetTime() or 0
 local pcx, pcy = cell(px), cell(py)
 local c = cache
 if c.map == map and c.gx == gx and c.gy == gy and c.version == version and math.abs((c.pcx or -99) - pcx) <= 1 and math.abs((c.pcy or -99) - pcy) <= 1 and now - (c.time or -99) < 2 then
  return c.points
 end
 local points = FT.RoadRoute(map, px, py, gx, gy, ww, wh)
 cache = {map = map, gx = gx, gy = gy, version = version, pcx = pcx, pcy = pcy, time = now, points = points}
 return points
end

----------------------------------------------------------------------
-- ForeverTrail_Nav (yürüme yönlendiricisi ve yürüme haritaları): gerçek yürüme rotaları
-- Klasörleri depoda ForeverTrail_Nav, ForeverTrail_Nav_EK ve ForeverTrail_Nav_Kalimdor'dur (Polestar_Nav'ın değiştirilmiş
-- kopyası, GPL-3.0-or-later; ForeverTrail_Nav/NOTICE.md). Eklenti gerektiğinde yüklenir ve "ForeverTrail_NavEngine" global'ini açar.
-- Arama eşzamansızdır (kareler arasında dilimlenir): sonuç gelene dek öğrenilmiş yollara ya da düz çizgiye düşülür.
-- Noktalar UnitPosition çerçevesindedir (x kuzey, y batı); harita koordinatına C_Map ile çevrilir.
-- Kapatmak için ForeverTrailSettings.roadsNav = false. walkLevel gönderilmez: sıkı politika işi Polestar'ın tehlike tablosunu ister.
----------------------------------------------------------------------
local PS = {tried = -999, failedAt = -999, askedAt = -999}

local function plain(v) if FT.Plain then return FT.Plain(v) end return v end
local function nowTime() return GetTime and GetTime() or 0 end

local function psEngine()
 if ForeverTrailSettings and ForeverTrailSettings.roadsNav == false then return nil end
 if PS.engine then return PS.engine end
 local now = nowTime()
 if now - PS.tried < 30 then return nil end
 if InCombatLockdown and InCombatLockdown() then return nil end -- eklentiyi yüklemek birkaç MB bellek kurar; savaşta yapılmaz
 PS.tried = now
 local P = _G.ForeverTrail_NavEngine
 if type(P) ~= 'table' then
  local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
  if load then pcall(load, 'ForeverTrail_Nav') end
  P = _G.ForeverTrail_NavEngine
 end
 if type(P) == 'table' and type(P.Find) == 'function' and type(P.Cancel) == 'function' then PS.engine = P; return P end
 return nil
end

-- Oyuncunun dünya konumu (UnitPosition: x kuzey, y batı) ve kıta/instance numarası
local function playerWorld()
 if not UnitPosition then return nil end
 local ok, x, y, _, inst = pcall(UnitPosition, 'player')
 if not ok then return nil end
 x, y, inst = plain(x), plain(y), plain(inst)
 if type(x) ~= 'number' or type(y) ~= 'number' or inst == nil then return nil end
 return x, y, inst
end

local function xyOf(pos)
 if type(pos) ~= 'table' then return nil end
 if pos.GetXY then
  local ok, x, y = pcall(pos.GetXY, pos)
  if ok then return plain(x), plain(y) end
 end
 return plain(pos.x), plain(pos.y)
end

-- Harita koordinatı <-> dünya koordinatı (UnitPosition çerçevesi: x kuzey, y batı). Harita kimlikleri arasındaki ilişkiye
-- (şehir haritası, alt bölge, komşu bölge) bakmadan, aynı kıtadaki iki noktayı karşılaştırmayı sağlar.
-- ToWorld: kıta/instance, wx, wy. FromWorld: x, y (harita dışında kalan noktalar için 0-1 dışı değerler döner).
function FT.ToWorld(map, x, y)
 if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D and map and x and y) then return nil end
 local ok, c, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
 if not ok then return nil end
 local wx, wy = xyOf(pos)
 c = plain(c)
 if c == nil or type(wx) ~= 'number' or type(wy) ~= 'number' then return nil end
 return c, wx, wy
end

function FT.FromWorld(inst, wx, wy, map)
 if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D and inst ~= nil and wx and wy and map) then return nil end
 local ok, m, pos = pcall(C_Map.GetMapPosFromWorldPos, inst, CreateVector2D(wx, wy), map)
 if not ok or plain(m) ~= map then return nil end
 local x, y = xyOf(pos)
 if type(x) ~= 'number' or type(y) ~= 'number' then return nil end
 return x, y
end

-- Bir haritadaki noktayı başka bir haritanın koordinatına çevirir (aynı kıtada); olmuyorsa nil
function FT.ProjectToMap(srcMap, x, y, dstMap)
 local inst, wx, wy = FT.ToWorld(srcMap, x, y)
 if not inst then return nil end
 return FT.FromWorld(inst, wx, wy, dstMap)
end

-- Rehber adımını oyuncunun haritasının koordinatlarında bir hedef olarak ver (ok ve mini harita için). Aynı kıtada değilse nil.
function FT.ProjectStep(map, step)
 if not (step and step.uiMapID and step.x and step.y and map) then return nil end
 local inst, wx, wy = FT.ToWorld(step.uiMapID, step.x, step.y)
 if not inst then return nil end
 local x, y = FT.FromWorld(inst, wx, wy, map)
 if not x then return nil end
 return {x = x, y = y, uiMapID = map, stepId = step.stepId or 'projected', type = step.type, questId = step.questId, questTitle = step.questTitle,
  projected = true, world = {inst, wx, wy}}
end

local function ask(P, map, gx, gy, gworld)
 local ux, uy, inst = playerWorld()
 if not ux or not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
 -- hedefin dünya koordinatı verilmişse (başka haritadaki hedef) onu kullan, yoksa harita koordinatından çevir
 local c, wx, wy
 if gworld then c, wx, wy = gworld[1], gworld[2], gworld[3] else c, wx, wy = FT.ToWorld(map, gx, gy) end
 if not (wx and wy) or plain(c) ~= inst then return end -- hedef bu kıtada değil
 if P.Available and not P.Available(inst) then return end
 if PS.job and P.Cancel then pcall(P.Cancel, PS.job); PS.job = nil end
 local faction = UnitFactionGroup and select(1, UnitFactionGroup('player')) or nil
 local key = ('%d:%.4f:%.4f'):format(map, gx, gy)
 PS.askedAt = nowTime()
 PS.askedKey = key
 local okFind, job = pcall(P.Find, inst, {x = ux, y = uy}, {x = wx, y = wy}, function(points)
  PS.job = nil
  if PS.askedKey ~= key then return end
  if type(points) ~= 'table' or #points < 2 then PS.points, PS.key, PS.failedAt = nil, nil, nowTime(); return end
  local out = {}
  for _, pt in ipairs(points) do
   local okMap, m, mpos = pcall(C_Map.GetMapPosFromWorldPos, inst, CreateVector2D(pt.x, pt.y), map)
   local x, y = xyOf(okMap and mpos)
   if not (x and y) or x < -2 or x > 3 or y < -2 or y > 3 then break end -- harita dışında kalan noktalar korunur (çizim tuvale kırpar); uçlar atılır
   out[#out + 1] = {x, y}
  end
  if #out >= 2 then PS.points, PS.key, PS.failedAt = out, key, -999 else PS.points, PS.key, PS.failedAt = nil, nil, nowTime() end
 end, {waterWalking = false, profile = faction})
 if okFind then PS.job = job else PS.failedAt = nowTime() end
end

-- Gelen yolun oyuncunun önündeki kısmı: ilk nokta oyuncu, yolda ilerledikçe geride kalanlar atılır
local function trimmed(points, px, py, gx, gy, ww, wh)
 local wx, wy = ww or 1, wh or 1
 local best, bestD = 1, nil
 for i, p in ipairs(points) do
  local d = ((p[1] - px) * wx) ^ 2 + ((p[2] - py) * wy) ^ 2
  if not bestD or d < bestD then best, bestD = i, d end
 end
 local out = {{px, py}}
 for i = best + 1, #points do out[#out + 1] = points[i] end
 if #out == 1 then out[2] = {gx, gy} end
 return out, math.sqrt(bestD or 0)
end

local function navRoute(P, map, px, py, gx, gy, ww, wh, gworld)
 local key = ('%d:%.4f:%.4f'):format(map, gx, gy)
 local now = nowTime()
 local points, off
 if PS.points and PS.key == key then points, off = trimmed(PS.points, px, py, gx, gy, ww, wh) end
 local stale = not points or (off and off > 60)
 if stale and (not PS.job or PS.askedKey ~= key) and now - PS.askedAt >= 2 and not (PS.failedAt > -999 and PS.askedKey == key and now - PS.failedAt < 15)
  and not (InCombatLockdown and InCombatLockdown()) then
  ask(P, map, gx, gy, gworld)
 end
 if points and not (off and off > 120) then return points end
 return nil
end

-- Şu an hangi kaynak kullanılıyor: 'nav' (yürüme haritası), 'learned' ya da nil (düz çizgi)
FT.RoadsSource = function() return PS.usedSource end

-- Çizim için rota. Dönüş: {{x, y}, ...} (ilk nokta oyuncu, son nokta hedef; 0-1 harita koordinatı) ya da nil.
function FT.CurrentRoute(map, px, py, gx, gy, ww, wh, gworld)
 if not (map and px and gx) then PS.usedSource = nil; return nil end
 local P = psEngine()
 if P then
  local pts = navRoute(P, map, px, py, gx, gy, ww, wh, gworld)
  if pts then PS.usedSource = 'nav'; return pts end
 end
 -- öğrenilmiş yollar harita başınadır: oyuncu ya da hedef bu haritanın dışındaysa kullanılamaz
 local inside = px >= 0 and px <= 1 and py >= 0 and py <= 1 and gx >= 0 and gx <= 1 and gy >= 0 and gy <= 1
 local pts = inside and learnedRoute(map, px, py, gx, gy, ww, wh) or nil
 PS.usedSource = pts and 'learned' or nil
 return pts
end

-- Test için: yürüme yönlendiricisi durumunu sıfırla
function FT.RoadsNavReset() PS = {tried = -999, failedAt = -999, askedAt = -999} end

----------------------------------------------------------------------
-- Öğrenme: yürürken (uçmadan, binekle uçmadan, gemide olmadan) konum kaydı
----------------------------------------------------------------------
local function moving()
 if UnitOnTaxi and UnitOnTaxi('player') then return false end
 if IsFlying and IsFlying() then return false end
 if IsSwimming and IsSwimming() then return false end
 if IsInInstance and IsInInstance() then return false end
 local speed = GetUnitSpeed and GetUnitSpeed('player') or 0
 return type(speed) == 'number' and speed > 0
end

function FT.RoadsTick()
 if ForeverTrailSettings and ForeverTrailSettings.roadsLearn == false then return end
 if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
 if not moving() then FT.RoadsBreak(); return end
 local ok, map = pcall(C_Map.GetBestMapForUnit, 'player')
 if not ok or not map then FT.RoadsBreak(); return end
 local got, pos = pcall(C_Map.GetPlayerMapPosition, map, 'player')
 if not got or not pos then return end
 local valid, x, y = pcall(function() return pos:GetXY() end)
 if not valid or type(x) ~= 'number' or (x == 0 and y == 0) then return end
 FT.RoadsRecord(map, x, y)
end

local driver = CreateFrame('Frame')
local waited = 0
driver:SetScript('OnUpdate', function(_, dt)
 waited = waited + dt
 if waited < 0.5 then return end
 waited = 0
 pcall(FT.RoadsTick)
end)

-- /ftrail yol: öğrenilen yol sayısı
function FT.RoadsStatus()
 local maps, nodes = 0, 0
 for _, road in pairs(store()) do
  maps = maps + 1
  for _ in pairs(road) do nodes = nodes + 1 end
 end
 return maps, nodes
end

-- /ftrail yolbilgi: rota kaynağı ve öğrenilen yol sayısı
function FT.RoadsInfo()
 local maps, nodes = FT.RoadsStatus()
 local nav
 if ForeverTrailSettings and ForeverTrailSettings.roadsNav == false then nav = 'kapalı'
 elseif type(_G.ForeverTrail_NavEngine) == 'table' then nav = 'yüklü'
 elseif C_AddOns and C_AddOns.GetAddOnInfo and select(1, C_AddOns.GetAddOnInfo('ForeverTrail_Nav')) ~= nil then nav = 'kurulu (ilk rotada yüklenir)'
 else nav = 'kurulu değil (tools/link_nav_addons.ps1)' end
 local source = FT.RoadsSource and FT.RoadsSource()
 FT.Print(('Rota kaynağı: %s  |  ForeverTrail_Nav: %s  |  Öğrenilen yol: %d harita, %d hücre%s'):format(
  source == 'nav' and 'yürüme haritası' or (source == 'learned' and 'öğrenilmiş yollar' or 'düz çizgi'), nav, maps, nodes,
  (ForeverTrailSettings and ForeverTrailSettings.roadsLearn == false) and ' (öğrenme kapalı)' or ''))
end
