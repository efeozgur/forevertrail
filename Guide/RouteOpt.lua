local _, FT = ...

-- Rota sıralama: duraklar (adımlar) arasındaki toplam yol en kısa olacak biçimde dizilir.
-- Her görevin kendi içindeki sırası (al → hedef → teslim) korunur; ama farklı görevlerin durakları iç içe girebilir
-- (A'yı teslim ederken yanındaki C'yi de almak gibi). Kurulum: en yakın komşu + yer değiştirme / ters çevirme iyileştirmesi.
-- Mesafe: aynı kıtada dünya koordinatından, aynı haritada harita boyutundan; farklı kıta/harita için büyük bir ceza.

local FAR = 4000

local function worldOf(map, x, y)
 if FT.ToWorld then
  local ok, inst, wx, wy = pcall(FT.ToWorld, map, x, y)
  if ok and inst ~= nil and wx and wy then return inst, wx, wy end
 end
end

-- İki nokta {map, x, y} arasındaki mesafe (yd)
local function defaultDist(a, b)
 if a.world == nil and a.map and a.x then a.inst, a.wx, a.wy = worldOf(a.map, a.x, a.y); a.world = a.inst ~= nil end
 if b.world == nil and b.map and b.x then b.inst, b.wx, b.wy = worldOf(b.map, b.x, b.y); b.world = b.inst ~= nil end
 if a.world and b.world and a.inst == b.inst then
  return math.sqrt((a.wx - b.wx) ^ 2 + (a.wy - b.wy) ^ 2)
 end
 if a.map and a.map == b.map and C_Map and C_Map.GetMapWorldSize then
  local ok, w, h = pcall(C_Map.GetMapWorldSize, a.map)
  if ok and w and w > 0 then return math.sqrt(((a.x - b.x) * w) ^ 2 + ((a.y - b.y) * (h or w)) ^ 2) end
 end
 return FAR
end

-- steps: koordinatlı/koordinatsız adım listesi (questId, uiMapID, x, y). start: {map, x, y} ya da nil.
-- Dönüş: sıralı adım listesi, yeni toplam yol (yd), özgün sıranın toplam yolu (yd)
function FT.RouteOrder(steps, start, opts)
 local dist = opts and opts.dist or defaultDist
 local n = #steps
 if n == 0 then return {}, 0, 0 end
 -- 1) konumlar: koordinatı olmayan adım aynı görevin komşu adımından ödünç alır; hiç yoksa "yüzer" (konumsuz)
 local pos, located = {}, {}
 for i = 1, n do
  local s = steps[i]
  if s.x and s.y and s.uiMapID then pos[i] = {map = s.uiMapID, x = s.x, y = s.y} end
 end
 for i = 1, n do
  if not pos[i] and steps[i].questId then
   for d = 1, n do
    local a, b = steps[i - d], steps[i + d]
    local ia, ib = i - d, i + d
    if a and a.questId == steps[i].questId and pos[ia] then pos[i] = pos[ia]; break end
    if b and b.questId == steps[i].questId and pos[ib] then pos[i] = pos[ib]; break end
   end
  end
 end
 local floating = {}
 for i = 1, n do if pos[i] then located[#located + 1] = i else floating[#floating + 1] = i end end
 local m = #located
 -- 2) öncelik: aynı görevin önceki (konumlu) adımı önce yapılmalı
 local pred = {}
 local lastOf = {}
 for k, i in ipairs(located) do
  local q = steps[i].questId
  if q then pred[k] = lastOf[q]; lastOf[q] = k end
 end
 -- 3) mesafe matrisi (0 = başlangıç)
 local D = {}
 local nodes = {}
 for k = 1, m do nodes[k] = pos[located[k]] end
 local startNode = start and start.map and start.x and start or nil
 for a = 0, m do
  D[a] = {}
  for b = 0, m do
   if a == b then D[a][b] = 0
   elseif D[b] and D[b][a] then D[a][b] = D[b][a]
   else
    local na = a == 0 and startNode or nodes[a]
    local nb = b == 0 and startNode or nodes[b]
    D[a][b] = (na and nb) and dist(na, nb) or 0
   end
  end
 end
 local function length(order)
  local total, prev = 0, 0
  for _, k in ipairs(order) do total = total + D[prev][k]; prev = k end
  return total
 end
 local function valid(order)
  local at = {}
  for p, k in ipairs(order) do at[k] = p end
  for k = 1, m do if pred[k] and at[pred[k]] > at[k] then return false end end
  return true
 end
 -- özgün sıra (öncelik zaten sağlanır: girdi sırası görev içi sırayı korur)
 local original = {}
 for k = 1, m do original[k] = k end
 local oldLen = length(original)
 -- 4) en yakın komşu kurulumu
 local order, done, prev = {}, {}, 0
 for _ = 1, m do
  local best, bestD
  for k = 1, m do
   if not done[k] and (not pred[k] or done[pred[k]]) then
    local d = D[prev][k]
    if not bestD or d < bestD then best, bestD = k, d end
   end
  end
  order[#order + 1] = best; done[best] = true; prev = best
 end
 -- 5) iyileştirme: tek adım taşıma ve parça ters çevirme (öncelik bozulmuyorsa)
 local cur = length(order)
 for _ = 1, 8 do
  local improved = false
  for i = 1, m do
   for j = 1, m do
    if i ~= j then
     local trial = {}
     for p = 1, m do trial[p] = order[p] end
     local k = table.remove(trial, i)
     table.insert(trial, j, k)
     local len = length(trial)
     if len < cur - 1e-6 and valid(trial) then order, cur, improved = trial, len, true end
    end
   end
  end
  for i = 1, m - 1 do
   for j = i + 1, m do
    local trial = {}
    for p = 1, m do trial[p] = order[p] end
    local a, b = i, j
    while a < b do trial[a], trial[b] = trial[b], trial[a]; a = a + 1; b = b - 1 end
    local len = length(trial)
    if len < cur - 1e-6 and valid(trial) then order, cur, improved = trial, len, true end
   end
  end
  if not improved then break end
 end
 -- 6) sonuç: konumlu adımlar sırayla; yüzenler önceki aynı görev adımının hemen arkasına, olmayanlar sona
 local result = {}
 local placedAfter = {}
 local tail = {}
 for _, i in ipairs(floating) do
  local q = steps[i].questId
  local anchor
  if q then for d = 1, i - 1 do if steps[i - d].questId == q and pos[i - d] then anchor = i - d; break end end end
  if anchor then placedAfter[anchor] = placedAfter[anchor] or {}; table.insert(placedAfter[anchor], steps[i])
  else tail[#tail + 1] = steps[i] end
 end
 for _, k in ipairs(order) do
  local i = located[k]
  result[#result + 1] = steps[i]
  for _, s in ipairs(placedAfter[i] or {}) do result[#result + 1] = s end
 end
 for _, s in ipairs(tail) do result[#result + 1] = s end
 return result, cur, oldLen
end
