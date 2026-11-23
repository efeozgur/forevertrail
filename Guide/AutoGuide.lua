local _, FT = ...

-- Otomatik bölge rehberleri: görev veritabanından, bir bölge ve seviye aralığı için sıralı rehber üretir.
--
-- Nasıl çalışır:
-- 1) Bölgenin görevleri toplanır: karakterin ırkına/sınıfına uygun, seviye penceresinde, tekrarlanan/zindan/PvP/etkinlik/meslek
--    olmayan ve hem görevi veren hem teslim alan konumu bu bölgede bulunabilen görevler.
-- 2) Bir yürüyüş simüle edilir. Bulunulan merkezde önce oradaki görevler alınır, sonra yakındaki hedeflere gidilir, sonra
--    teslim edilir; zincirin devamı (aynı NPC'den) hemen alınır. Görev günlüğü kapasitesi aşılmaz, ön koşullar ve zincir
--    sırası korunur, seviye kısıtı yaklaşık bir seviye tahminiyle gözetilir.
-- 3) Çıkan adımlar sıradan bir rehber tablosudur (accept / objective / turnin); Rehber ekranı ve otomatik ilerleme onu
--    elle yazılmış bir rehber gibi izler. Üretim yalnızca bölgeye, seviye aralığına ve karaktere bağlıdır (tamamlanan
--    görevlere değil), bu yüzden aynı girdi hep aynı rehberi verir ve adım kimlikleri (stepId) kararlıdır.

local AG = {}
FT.AutoGuide = AG

local HUB_R = 0.035   -- aynı merkez sayılan uzaklık (harita genişliğinin %3,5'i)
local OBJ_R = 0.08    -- yakındaki hedefler merkezden ayrılmadan yapılır
local CLUSTER_R = 0.06 -- hedef noktalarının tek bir nokta olarak toplandığı yarıçap
local MAX_LOG = 16    -- simülasyonda görev günlüğü kapasitesi (oyunda 20; pay bırakılır)
local WINDOW = 10     -- seviye penceresi genişliği
local MIN_QUESTS = 10 -- bir bölge rehberinde en az görev (daha azı atılır ya da yan yana dilimlerle birleşir)
local UNKNOWN_D = 0.25 -- konumu bilinmeyen hedeflerin sıralamadaki varsayılan uzaklığı

local function hasBit(mask, bit)
 if type(mask) ~= 'number' or mask == 0 then return true end
 return math.floor(mask / 2 ^ bit) % 2 == 1
end

----------------------------------------------------------------------
-- Veri erişimi
----------------------------------------------------------------------
local areaMap = {}
local function mapOfArea(area)
 local v = areaMap[area]
 if v == nil then
  local z = FT.Module and FT.Module('ZoneDB')
  v = (z and z:GetUiMapIdByAreaId(area)) or false
  areaMap[area] = v
 end
 return v or nil
end

local function row(kind, id)
 if kind == 'o' then return FT.DBO and FT.DBO[id] end
 return FT.DBN and FT.DBN[id]
end

local function entityName(kind, id)
 local r = row(kind, id)
 return r and r[1] or nil
end

-- Bir varlığın (npc: 'n', nesne: 'o') haritadaki noktaları: {{x, y, alan, tür, kimlik}, ...}; konuma göre sıralı (kararlı)
local pointCache = {}
local function points(kind, id, map)
 local key = kind .. id .. ':' .. map
 local cached = pointCache[key]
 if cached then return cached end
 local r = row(kind, id)
 local flat = r and (kind == 'o' and r[4] or r[5])
 local out = {}
 if type(flat) == 'table' then
  for area, list in pairs(flat) do
   if mapOfArea(area) == map then
    for i = 1, #list - 1, 2 do out[#out + 1] = {list[i] / 1000, list[i + 1] / 1000, area, kind, id} end
   end
  end
  table.sort(out, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
 end
 pointCache[key] = out
 return out
end

local function collect(kind, ids, map, into)
 for _, id in ipairs(type(ids) == 'table' and ids or {}) do
  if type(id) == 'number' then for _, p in ipairs(points(kind, id, map)) do into[#into + 1] = p end end
 end
end

local function dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

-- noktalar arasında (x, y)'ye en yakın nokta ve uzaklığı
local function nearest(list, x, y)
 local best, bd
 for _, p in ipairs(list) do
  local d = dist(p[1], p[2], x, y)
  if not bd or d < bd then best, bd = p, d end
 end
 return best, bd
end

-- hedef noktaları: en yakın noktanın çevresindeki noktaların ağırlık merkezi (hedef yaratıkların yığıldığı yer)
local function objectiveSpot(list, x, y)
 local p0 = nearest(list, x, y)
 if not p0 then return nil end
 local sx, sy, n = 0, 0, 0
 for _, p in ipairs(list) do
  if dist(p[1], p[2], p0[1], p0[2]) <= CLUSTER_R then sx, sy, n = sx + p[1], sy + p[2], n + 1 end
 end
 return {sx / n, sy / n, p0[3]}
end

----------------------------------------------------------------------
-- Karakter ve görev uygunluğu
----------------------------------------------------------------------
local function playerInfo()
 local race = UnitRace and select(3, UnitRace('player')) or 0
 local class = UnitClass and select(3, UnitClass('player')) or 0
 local level = UnitLevel and UnitLevel('player') or 1
 local faction = UnitFactionGroup and UnitFactionGroup('player') or nil
 return {race = race or 0, class = class or 0, level = level or 1, faction = faction}
end
AG.PlayerInfo = playerInfo

-- tür, ırk, sınıf ve meslek ölçütleri (konumdan bağımsız)
local function eligible(id, q, p)
 local level = q[5]
 if type(level) ~= 'number' or level <= 0 then return false end
 if type(q[13]) ~= 'number' or q[13] <= 0 then return false end
 if q[14] ~= nil then return false end -- meslek becerisi gerektirir
 if p.race > 0 and not hasBit(q[6], p.race - 1) then return false end
 if p.class > 0 and not hasBit(q[7], p.class - 1) then return false end
 if FT.QuestKind and FT.QuestKind(id) then return false end -- tekrar, etkinlik, PvP, zindan, baskın
 return true
end

----------------------------------------------------------------------
-- Bir görevin bu haritadaki konumları ("derlenmiş" görev)
----------------------------------------------------------------------
local compiled = {}
local function compile(id, q, map)
 local key = id .. ':' .. map
 local c = compiled[key]
 if c ~= nil then return c or nil end
 local A, T, O = {}, {}, {}
 local by, to = q[2], q[3]
 collect('n', type(by) == 'table' and by[1], map, A); collect('o', type(by) == 'table' and by[2], map, A)
 collect('n', type(to) == 'table' and to[1], map, T); collect('o', type(to) == 'table' and to[2], map, T)
 if #A == 0 or #T == 0 then compiled[key] = false; return nil end
 local hasObjective = false
 local obj = q[9]
 if type(obj) == 'table' then
  for _, r in ipairs(obj[1] or {}) do
   if type(r) == 'table' and type(r[1]) == 'number' then hasObjective = true; for _, pt in ipairs(points('n', r[1], map)) do O[#O + 1] = pt end end
  end
  for _, r in ipairs(obj[2] or {}) do
   if type(r) == 'table' and type(r[1]) == 'number' then hasObjective = true; for _, pt in ipairs(points('o', r[1], map)) do O[#O + 1] = pt end end
  end
  for _, r in ipairs(obj[3] or {}) do
   if type(r) == 'table' and type(r[1]) == 'number' then
    hasObjective = true
    local it = FT.DBI and FT.DBI[r[1]]
    if it then
     for i, nid in ipairs(type(it[2]) == 'table' and it[2] or {}) do if i > 8 then break end for _, pt in ipairs(points('n', nid, map)) do O[#O + 1] = pt end end
     for i, oid in ipairs(type(it[3]) == 'table' and it[3] or {}) do if i > 4 then break end for _, pt in ipairs(points('o', oid, map)) do O[#O + 1] = pt end end
    end
   end
  end
 end
 if q[16] == 2 then hasObjective = true end -- keşif görevi: hedef, teslim noktasına ulaşmaktır
 -- hedefin konumu veride yok (keşif görevi ya da hedef başka bölgede): adım koordinatsız bırakılır; görev günlüğündeyken
 -- Rehber ekranı konumu oyunun kendi yol noktası verisinden bulur (FT.EnsureWaypoint). Yanlış bir yer göstermekten iyidir.
 local noSpot = hasObjective and #O == 0
 c = {id = id, q = q, A = A, T = T, O = hasObjective and O or nil, noSpot = noSpot, req = q[4] or 1, level = q[5]}
 compiled[key] = c
 return c
end

local function listOf(v) return type(v) == 'table' and v or {} end

----------------------------------------------------------------------
-- Bölgenin görev kümesi
----------------------------------------------------------------------
local byMap
local function buildIndex()
 byMap = {}
 for id, q in pairs(FT.DBQ or {}) do
  if type(q[13]) == 'number' and q[13] > 0 then
   local map = mapOfArea(q[13])
   if map then
    local list = byMap[map]
    if not list then list = {}; byMap[map] = list end
    list[#list + 1] = id
   end
  end
 end
 for _, list in pairs(byMap) do table.sort(list) end
end

-- id -> derlenmiş görev; seviye penceresi [lo, hi]
local function questSet(map, lo, hi, p)
 if not byMap then buildIndex() end
 local out, ids = {}, {}
 for _, id in ipairs(byMap[map] or {}) do
  local q = FT.DBQ[id]
  if eligible(id, q, p) and q[5] >= lo and q[5] <= hi and (q[4] or 1) <= hi then
   local c = compile(id, q, map)
   if c then out[id] = c; ids[#ids + 1] = id end
  end
 end
 return out, ids
end

----------------------------------------------------------------------
-- Yürüyüş simülasyonu
----------------------------------------------------------------------
local function simulate(map, lo, hi, set, ids)
 local st, steps, excluded = {}, {}, {}
 local n = #ids
 for _, id in ipairs(ids) do st[id] = 'new' end
 -- başlangıç: en düşük seviyeli (sonra en küçük kimlikli) görevi veren NPC'nin yanı
 local first
 for _, id in ipairs(ids) do
  local c = set[id]
  if not first or c.req < first.req or (c.req == first.req and c.level < first.level) then first = c end
 end
 if not first then return steps, excluded end
 local px, py = first.A[1][1], first.A[1][2]
 local done, log, boost = 0, 0, 0
 local perLevel = math.max(1, n / math.max(1, hi - lo + 1))

 local function prereqOk(c)
  local q = c.q
  for _, pid in ipairs(listOf(q[10])) do if set[pid] and st[pid] ~= 'done' then return false end end
  local single = listOf(q[11])
  if #single > 0 then
   local ok = false
   for _, pid in ipairs(single) do if not set[pid] or st[pid] == 'done' then ok = true; break end end
   if not ok then return false end
  end
  return true
 end
 local function canAccept(c)
  if st[c.id] ~= 'new' or log >= MAX_LOG or not prereqOk(c) then return false end
  return c.req <= math.max(lo, lo + math.floor(done / perLevel)) + 1 + boost
 end

 local function emit(kind, c, spot)
  local q = c.q
  local title = q[1] or ('Görev ' .. c.id)
  local npc = spot and spot[5] and entityName(spot[4], spot[5])
  local s = {stepId = (kind == 'accept' and 'a' or (kind == 'objective' and 'o' or 't')) .. c.id, type = kind, questId = c.id, questTitle = title}
  if spot then s.uiMapID, s.x, s.y = map, spot[1], spot[2] end
  if npc and kind ~= 'objective' then s.npc = npc end
  if kind == 'accept' then s.text = npc and ('Görevi al: ' .. npc) or 'Görevi al.'
  elseif kind == 'objective' then s.text = (type(q[8]) == 'string' and q[8] ~= '') and q[8] or 'Görevin hedeflerini tamamla.'
  else s.text = npc and ('Teslim et: ' .. npc) or 'Görevi teslim et.' end
  steps[#steps + 1] = s
  if spot then px, py = spot[1], spot[2] end
 end

 local guard = 0
 while done < n and guard < n * 6 + 50 do
  guard = guard + 1
  local bestT, bestA, bestO, bestU
  for _, id in ipairs(ids) do
   local c = set[id]
   local s = st[id]
   if s == 'ready' then
    local p, d = nearest(c.T, px, py)
    if not bestT or d < bestT.d then bestT = {c = c, p = p, d = d} end
   elseif s == 'log' and c.noSpot then
    -- konumu bilinmeyen hedef: yakında başka iş kalmadığında yapılır (sabit, büyük uzaklık)
    if not bestU or c.id < bestU.c.id then bestU = {c = c, d = UNKNOWN_D} end
   elseif s == 'log' and c.O then
    local spot = objectiveSpot(c.O, px, py)
    local d = dist(spot[1], spot[2], px, py)
    if not bestO or d < bestO.d then bestO = {c = c, p = spot, d = d} end
   elseif s == 'new' and canAccept(c) then
    local p, d = nearest(c.A, px, py)
    if not bestA or d < bestA.d then bestA = {c = c, p = p, d = d} end
   end
  end
  local pick, kind
  if bestT and bestT.d <= HUB_R then pick, kind = bestT, 'turnin'
  elseif bestA and bestA.d <= HUB_R then pick, kind = bestA, 'accept'
  elseif bestO and bestO.d <= OBJ_R then pick, kind = bestO, 'objective'
  else
   local best, bs
   for _, cand in ipairs({{bestT, 'turnin', 0.9}, {bestA, 'accept', 1.0}, {bestO, 'objective', 1.1}, {bestU, 'unknown', 1.1}}) do
    if cand[1] then local score = cand[1].d * cand[3]; if not bs or score < bs then best, bs = cand, score end end
   end
   if best then pick, kind = best[1], best[2] end
  end
  if not pick then
   -- ilerlenemiyor: seviye kısıtını gevşet; yine olmuyorsa kalanları sırayla ekle
   boost = boost + 1
   if boost > 60 then break end
  else
   local c = pick.c
   if kind == 'unknown' then
    emit('objective', c, nil)
    st[c.id] = 'ready'
   elseif kind == 'accept' then
    emit('accept', c, pick.p)
    log = log + 1
    for _, xid in ipairs(listOf(c.q[12])) do if st[xid] == 'new' then st[xid] = 'done'; done = done + 1; excluded[xid] = c.id end end -- birbirini dışlayan görev
    if c.O then st[c.id] = 'log' else st[c.id] = 'ready' end
   elseif kind == 'objective' then
    emit('objective', c, pick.p)
    st[c.id] = 'ready'
   else
    emit('turnin', c, pick.p)
    st[c.id] = 'done'; done = done + 1; log = log - 1
   end
  end
 end
 return steps, excluded
end

----------------------------------------------------------------------
-- Genel işlevler
----------------------------------------------------------------------
local function mapName(map)
 return (FT.MapName and FT.MapName(map)) or ('Bölge ' .. map)
end

-- Bölge rehberi tablosu; bölgede (karakter için) uygun görev yoksa nil. Sonuç karaktere göre önbelleklenir.
local built = {}
function AG.Build(map, lo, hi)
 local p = playerInfo()
 local cacheKey = ('%d:%d:%d:%d:%d'):format(map, lo, hi, p.race, p.class)
 if built[cacheKey] ~= nil then return built[cacheKey] or nil end
 local guide = AG.BuildUncached(map, lo, hi, p)
 built[cacheKey] = guide or false
 return guide
end

function AG.BuildUncached(map, lo, hi, p)
 local set, ids = questSet(map, lo, hi, p)
 if #ids == 0 then return nil end
 local steps, excluded = simulate(map, lo, hi, set, ids)
 if #steps == 0 then return nil end
 -- yalnızca gerçekten rehbere giren görevler sayılır. Girmeyenler iki türlüdür: birbirini dışlayan alternatifler (alternatives:
 -- başka bir görev alınınca alınamaz, beklenen durum) ve ulaşılamayanlar (unreachable: ön koşulu hiç sağlanamayan, bir hata göstergesi).
 local emitted = {}
 for _, s in ipairs(steps) do emitted[s.questId] = true end
 local quests, xp, alternatives, unreachable = 0, 0, {}, {}
 for _, id in ipairs(ids) do
  if emitted[id] then
   quests = quests + 1
   if FT.QuestXPInfo then xp = xp + (FT.QuestXPInfo(id) or 0) end
  elseif excluded[id] then alternatives[#alternatives + 1] = id
  else unreachable[#unreachable + 1] = id end
 end
 return {guideId = ('auto-%d-%d-%d'):format(map, lo, hi), version = 1, title = ('%s · %d-%d'):format(mapName(map), lo, hi),
  zone = mapName(map), levels = ('%d-%d'):format(lo, hi), steps = steps, auto = true, alternatives = alternatives, unreachable = unreachable,
  stats = {quests = quests, xp = xp, steps = #steps}}
end

-- Karakter için bölgeler ve seviye pencereleri: {map, name, lo, hi, count, xp, key, recommended}
function AG.Zones(onlyMap)
 local p = playerInfo()
 if not byMap then buildIndex() end
 local out = {}
 for map, list in pairs(byMap) do
 if not onlyMap or map == onlyMap then
  -- uygun görevlerin seviyeye göre sayısı (konumu bulunabilenler)
  local perBin, total = {}, 0
  for _, id in ipairs(list) do
   local q = FT.DBQ[id]
   if eligible(id, q, p) then
    local bin = math.floor((q[5] - 1) / WINDOW)
    if compile(id, q, map) then perBin[bin] = (perBin[bin] or 0) + 1; total = total + 1 end
   end
  end
  if total >= 8 then
   local bins = {}
   for bin in pairs(perBin) do bins[#bins + 1] = bin end
   table.sort(bins)
   -- Pencereler: yeterince görevi olan seviye dilimi tek başına bir pencere olur. Yan yana küçük dilimler, toplamları yeterliyse
   -- birleşir. Tek başına küçük kalan dilimler (zincirlerin yüksek seviyeli kuyrukları gibi uç değerler) atılır; pencereyi
   -- büyütmezler.
   local windows, run = {}, nil
   local function flush()
    if run and run.count >= MIN_QUESTS then windows[#windows + 1] = run end
    run = nil
   end
   for _, bin in ipairs(bins) do
    local c = perBin[bin]
    if c >= MIN_QUESTS then
     flush()
     windows[#windows + 1] = {lo = bin * WINDOW + 1, hi = bin * WINDOW + WINDOW, count = c, bin = bin}
    elseif run and run.bin == bin - 1 and (bin * WINDOW + WINDOW) - run.lo + 1 <= 2 * WINDOW then -- en çok 20 seviyelik birleşme
     run.hi = bin * WINDOW + WINDOW; run.count = run.count + c; run.bin = bin
    else
     flush()
     run = {lo = bin * WINDOW + 1, hi = bin * WINDOW + WINDOW, count = c, bin = bin}
    end
   end
   flush()
   for _, w in ipairs(windows) do
    -- sayı tahmin değil, gerçek üretimden gelir (ön koşulu sağlanamayan ya da alternatif görevler düşer)
    local guide = AG.Build(map, w.lo, w.hi)
    if guide and guide.stats.quests >= MIN_QUESTS then
     out[#out + 1] = {map = map, name = mapName(map), lo = w.lo, hi = w.hi, count = guide.stats.quests, xp = guide.stats.xp, steps = guide.stats.steps,
      key = ('%d:%d:%d'):format(map, w.lo, w.hi), recommended = p.level >= w.lo - 1 and p.level <= w.hi}
    end
   end
  end
 end
 end
 table.sort(out, function(a, b)
  if a.lo ~= b.lo then return a.lo < b.lo end
  if a.count ~= b.count then return a.count > b.count end
  return a.map < b.map
 end)
 return out
end

-- Rehber olarak seç: üretir, geçerli rehberler listesine ekler (öncekini değiştirir) ve etkinleştirir
function AG.Select(map, lo, hi)
 local guide = AG.Build(map, lo, hi)
 if not guide then return false, 'Bu bölge ve seviye aralığı için uygun görev bulunamadı.' end
 local ok, err = FT.ValidateGuide(guide)
 if not ok then return false, err end
 for i = #FT.validGuides, 1, -1 do if FT.validGuides[i].auto then table.remove(FT.validGuides, i) end end
 FT.validGuides[#FT.validGuides + 1] = guide
 if ForeverTrailCharacter then ForeverTrailCharacter.autoGuide = {map = map, lo = lo, hi = hi} end
 -- bölge rehberi seçmek otomatik ilerlemeyi de ister (kullanıcı açıkça kapatmadıysa açılır)
 if ForeverTrailSettings and ForeverTrailSettings.auto == nil then ForeverTrailSettings.auto = true end
 FT.SelectGuide(#FT.validGuides)
 return true, guide
end

-- Girişte: önceden seçilmiş otomatik rehberi yeniden üret (rehber listesi her açılışta baştan kurulur)
function AG.Restore()
 local saved = ForeverTrailCharacter and ForeverTrailCharacter.autoGuide
 if type(saved) ~= 'table' or not (saved.map and saved.lo and saved.hi) then return false end
 local guide = AG.Build(saved.map, saved.lo, saved.hi)
 if not guide or not FT.ValidateGuide(guide) then return false end
 for i = #FT.validGuides, 1, -1 do if FT.validGuides[i].auto then table.remove(FT.validGuides, i) end end
 FT.validGuides[#FT.validGuides + 1] = guide
 return true
end

-- Önbellekleri sıfırla (canlı veri eşitlemesi bitince)
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() byMap = nil; compiled = {}; pointCache = {}; areaMap = {}; built = {} end
