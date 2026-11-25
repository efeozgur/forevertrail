local _, FT = ...

-- Rehber adımının ayrıntıları: kim (NPC), nerede (bölge), ne yapılacak (fiil + görev adı + açıklama), kaç XP, sıradaki durak.
-- Rehber penceresi (UI/GuideTab.lua) ve Hub'daki Rehber sayfası (UI/Panel.lua) aynı bilgiyi gösterir.

local VERB = {accept = 'Görevi al', objective = 'Hedef', turnin = 'Teslim et', location = 'Konuma git', manual = 'Yapılacak'}
FT.StepVerb = VERB

local function dbName(kind, id)
 local row = kind == 'object' and FT.DBO and FT.DBO[id] or (FT.DBN and FT.DBN[id])
 if row and type(row[1]) == 'string' and row[1] ~= '' then return row[1] end
 local d = FT.Module and FT.Module('QuestieDB')
 if d then
  local ok, name = pcall(kind == 'object' and d.QueryObjectSingle or d.QueryNPCSingle, id, 'name')
  if ok and type(name) == 'string' and name ~= '' then return name end
 end
end

-- Adımın konuşulacak NPC'si ya da nesnesi (görevi veren / teslim alan); yoksa nil
function FT.StepNpc(step)
 if not step then return nil end
 if type(step.npc) == 'string' and step.npc ~= '' then return step.npc end
 if not step.questId or (step.type ~= 'accept' and step.type ~= 'turnin') then return nil end
 if FT.TargetsFor then
  local ok, list = pcall(FT.TargetsFor, step)
  if ok and type(list) == 'table' then
   for _, t in ipairs(list) do
    local name = dbName(t.kind == 'object' and 'object' or 'npc', t.id)
    if name then return name end
   end
  end
 end
 if step.type == 'turnin' and FT.TurnInName then
  local ok, name = pcall(FT.TurnInName, step.questId)
  if ok and type(name) == 'string' and name ~= '' then return name end
 end
end

local function translated(questId)
 local record = type(QTR_QuestData) == 'table' and questId and QTR_QuestData[tostring(questId)]
 return type(record) == 'table' and record or nil
end

-- Bir adım için gösterilecek her şey. Alanlar: type, verb, title, npc, zone, detail, xp (sayı), hasPlace
function FT.StepInfo(step)
 local info = {type = step and step.type or 'manual'}
 if not step then return info end
 info.verb = VERB[step.type] or ''
 local record = translated(step.questId)
 local title = (record and type(record.Title) == 'string' and record.Title ~= '' and record.Title) or step.questTitle
 if (not title or title == '') and step.questId and FT.QuestTitle then title = FT.QuestTitle(step.questId) end
 info.title = (title and title ~= '') and title or (step.text or '')
 info.npc = FT.StepNpc(step)
 info.zone = step.uiMapID and FT.MapName and FT.MapName(step.uiMapID) or nil
 info.hasPlace = (step.x and step.y) and true or false
 -- açıklama: görev hedefi (çeviri varsa Türkçe), yoksa adımın kendi metni
 local detail
 if step.type == 'accept' then
  local row = step.questId and FT.DBQ and FT.DBQ[step.questId]
  detail = (record and type(record.Objectives) == 'string' and not record.Objectives:find('[$]') and record.Objectives) or (row and type(row[8]) == 'string' and row[8]) or nil
 elseif step.type == 'objective' then
  detail = step.text
  if record and not step.objectiveIndex and type(record.Objectives) == 'string' and record.Objectives ~= '' and not record.Objectives:find('[$]') then detail = record.Objectives end
 elseif step.type == 'turnin' then
  detail = nil
 else
  detail = step.text
 end
 if detail == '' or detail == info.title then detail = nil end
 info.detail = detail
 if step.questId and FT.QuestXPInfo then
  local ok, xp = pcall(FT.QuestXPInfo, step.questId)
  if ok and type(xp) == 'number' and xp > 0 then info.xp = xp end
 end
 return info
end

----------------------------------------------------------------------
-- Alınmış bir görevin "ne yapacağım" adımları (görev listesinde görevin altında numaralı gösterilir):
-- her hedef bir adım (Öldür / Topla / Kullan / Konuş + ad, sayaç, bölge ve en yakın nokta), sonda teslim adımı.
----------------------------------------------------------------------
local KIND_VERB = {kill = 'Öldür', loot = 'Topla', object = 'Kullan', talk = 'Konuş'}
FT.StepKindVerb = KIND_VERB

local function playerSpot()
 if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
 local ok, map = pcall(C_Map.GetBestMapForUnit, 'player')
 if not (ok and map) then return nil end
 local ok2, pos = pcall(C_Map.GetPlayerMapPosition, map, 'player')
 if not (ok2 and pos and pos.GetXY) then return nil end
 local x, y = pos:GetXY()
 if type(x) ~= 'number' or type(y) ~= 'number' then return nil end
 return map, x, y
end

-- {map, x, y} noktaları içinden gösterilecek yer: oyuncunun haritasındaki en yakın nokta, yoksa en çok nokta olan
-- haritanın ağırlık merkezine en yakın nokta. Dönüş: {map, x, y, text = "Bölge · 45, 62"} ya da nil
function FT.PlaceOf(points)
 if type(points) ~= 'table' or #points == 0 then return nil end
 local pm, px, py = playerSpot()
 local best, bestD
 if pm then
  for _, p in ipairs(points) do
   if p.map == pm then
    local d = (p.x - px) ^ 2 + (p.y - py) ^ 2
    if not bestD or d < bestD then best, bestD = p, d end
   end
  end
 end
 if not best then
  local count, top = {}, nil
  for _, p in ipairs(points) do
   count[p.map] = (count[p.map] or 0) + 1
   if not top or count[p.map] > count[top] then top = p.map end
  end
  local cx, cy, n = 0, 0, 0
  for _, p in ipairs(points) do if p.map == top then cx, cy, n = cx + p.x, cy + p.y, n + 1 end end
  cx, cy = cx / n, cy / n
  for _, p in ipairs(points) do
   if p.map == top then
    local d = (p.x - cx) ^ 2 + (p.y - cy) ^ 2
    if not bestD or d < bestD then best, bestD = p, d end
   end
  end
 end
 if not best then return nil end
 local name = FT.MapName and FT.MapName(best.map)
 local coords = ('%d, %d'):format(math.floor(best.x * 100 + 0.5), math.floor(best.y * 100 + 0.5))
 return {map = best.map, x = best.x, y = best.y, text = name and (name .. ' · ' .. coords) or coords}
end

-- Bir görev hedefinin (FT.ActiveObjectives satırı) göründüğü noktalar
local function objectivePoints(o)
 local out = {}
 local d, z = FT.Module and FT.Module('QuestieDB'), FT.Module and FT.Module('ZoneDB')
 if d and z then
  local function add(kind, id)
   local getter = kind == 'object' and d.QueryObjectSingle or d.QueryNPCSingle
   local ok, spawns = pcall(getter, id, 'spawns')
   if not (ok and type(spawns) == 'table') then return end
   for area, list in pairs(spawns) do
    local good, map = pcall(z.GetUiMapIdByAreaId, z, area)
    if good and map and type(list) == 'table' then
     for _, p in ipairs(list) do
      if #out < 120 and type(p) == 'table' and type(p[1]) == 'number' and type(p[2]) == 'number' then
       out[#out + 1] = {map = map, x = p[1] / 100, y = p[2] / 100}
      end
     end
    end
   end
  end
  for _, n in ipairs(o.npcs or {}) do add('npc', n) end
  for _, ob in ipairs(o.objs or {}) do add('object', ob) end
 end
 if #out == 0 and not o.noOwn and FT.OwnObjectivePoints then out = FT.OwnObjectivePoints(o.questId, o.index) or {} end
 return out
end

-- Görevi veren (alan 2: startedBy) ya da teslim alan (alan 3: finishedBy) NPC ve NESNELERİN noktaları.
-- FT.SpawnPoints "al/teslim" adımında yalnızca NPC'ye baktığı için nesneyle (ilan tahtası, kitap...) başlayan görevler yersiz kalıyordu.
local function giverPoints(questId, field)
 local q = FT.DBQ and FT.DBQ[questId]
 local row = q and q[field]
 if type(row) ~= 'table' then return {} end
 return objectivePoints({npcs = row[1], objs = row[2], noOwn = true})
end

-- Görevi bir EŞYA başlatıyorsa (yaratıktan/nesneden düşer): {itemId, name, points = eşyanın düştüğü yerler}; yoksa nil
local function startItem(questId)
 local q = FT.DBQ and FT.DBQ[questId]
 local by = q and q[2]
 local itemId = type(by) == 'table' and type(by[3]) == 'table' and by[3][1]
 if type(itemId) ~= 'number' then return nil end
 local it = FT.DBI and FT.DBI[itemId]
 local function first(list, n) local out = {} for i, v in ipairs(type(list) == 'table' and list or {}) do if i > n then break end out[i] = v end return out end
 local points = it and objectivePoints({npcs = first(it[2], 8), objs = first(it[3], 4), noOwn = true}) or {}
 return {itemId = itemId, name = (it and type(it[1]) == 'string' and it[1] ~= '') and it[1] or ('Eşya ' .. itemId), points = points}
end
function FT.QuestStartItem(questId) return startItem(questId) end

-- Görevi veren varlığın adı: NPC, yoksa nesne (ilan tahtası...); yoksa nil
function FT.QuestGiverName(questId)
 local q = FT.DBQ and FT.DBQ[questId]
 local by = q and q[2]
 if type(by) ~= 'table' then return nil end
 for _, id in ipairs(type(by[1]) == 'table' and by[1] or {}) do
  local n = FT.DBN and FT.DBN[id]
  if n and type(n[1]) == 'string' and n[1] ~= '' then return n[1] end
 end
 for _, id in ipairs(type(by[2]) == 'table' and by[2] or {}) do
  local o = FT.DBO and FT.DBO[id]
  if o and type(o[1]) == 'string' and o[1] ~= '' then return o[1] end
 end
end

-- Görevin bölgesi (veri satırındaki bölge alanından): tam nokta bilinmese de "şu bölgede" denebilsin
function FT.QuestZoneName(questId)
 local q = FT.DBQ and FT.DBQ[questId]
 local area = q and q[13]
 if type(area) ~= 'number' or area <= 0 then return nil end
 local z = FT.Module and FT.Module('ZoneDB')
 if not z then return nil end
 local ok, map = pcall(z.GetUiMapIdByAreaId, z, area)
 if not (ok and map) then return nil end
 return FT.MapName and FT.MapName(map) or nil
end

local function turnInPlace(questId)
 if FT.Module and FT.Module('QuestieDB') and FT.SpawnPoints then
  local ok, pts = pcall(FT.SpawnPoints, {questId = questId, type = 'turnin'})
  if ok and type(pts) == 'table' and #pts > 0 then return FT.PlaceOf(pts) end
 end
 local own = giverPoints(questId, 3)
 if #own > 0 then return FT.PlaceOf(own) end
 if FT.OwnQuestPoint then
  local map, x, y = FT.OwnQuestPoint(questId, 'turnin')
  if map and x and y then return FT.PlaceOf({{map = map, x = x, y = y}}) end
 end
end

-- Yer aramak (veritabanı + harita) pahalı: kısa süre önbellekte tutulur; sayaçlar ise her çağrıda günlükten okunur
local placeCache = {}
local function cachedPlace(key, compute)
 local now = GetTime and GetTime() or 0
 local c = placeCache[key]
 if c and now - c.t < 5 then return c.v end
 local v = compute()
 placeCache[key] = {v = v or false, t = now}
 return v
end
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() placeCache = {} end

-- Dönüş: sıralı adımlar {kind, text, have, need, done, current, place = {text,...}|nil, objIndex}. Son adım her zaman teslim.
function FT.QuestSteps(questId)
 local list = {}
 if not questId then return list end
 local q = C_QuestLog
 local byIndex = {}
 if FT.ActiveObjectives then
  local ok, all = pcall(FT.ActiveObjectives)
  if ok and type(all) == 'table' then for _, o in ipairs(all) do if o.questId == questId then byIndex[o.index] = o end end end
 end
 local rows = {}
 if q and q.GetQuestObjectives then
  local ok, r = pcall(q.GetQuestObjectives, questId)
  if ok and type(r) == 'table' then rows = r end
 end
 for index, row in ipairs(rows) do
  local need, have = row.numRequired or 0, row.numFulfilled or 0
  local done = (row.finished or (need > 0 and have >= need)) and true or false
  local o = byIndex[index]
  local label = FT.ParseObjective and FT.ParseObjective(row.text or '') or (row.text or '')
  local verb = o and KIND_VERB[o.kind]
  local text = (o and o.name and verb) and (verb .. ': ' .. o.name) or label
  local place
  if o and not done then place = cachedPlace(questId .. ':' .. index, function() return FT.PlaceOf(objectivePoints(o)) end) or nil end
  list[#list + 1] = {kind = o and o.kind or 'misc', text = text, have = have, need = need, done = done, place = place, objIndex = index}
 end
 local npc
 if FT.TurnInName then local ok, name = pcall(FT.TurnInName, questId); if ok and type(name) == 'string' and name ~= '' then npc = name end end
 npc = npc or (FT.OwnGiverName and FT.OwnGiverName(questId, 'turnin')) or nil
 list[#list + 1] = {kind = 'turnin', text = npc and ('Teslim et: ' .. npc) or 'Görevi teslim et', done = false, have = 0, need = 0,
  place = cachedPlace(questId .. ':turnin', function() return turnInPlace(questId) end) or nil}
 for _, s in ipairs(list) do if not s.done then s.current = true; break end end
 return list
end

local function acceptPlaceOf(questId)
 if FT.Module and FT.Module('QuestieDB') and FT.SpawnPoints then
  local ok, pts = pcall(FT.SpawnPoints, {questId = questId, type = 'accept'})
  if ok and type(pts) == 'table' and #pts > 0 then return FT.PlaceOf(pts) end
 end
 local own = giverPoints(questId, 2)
 if #own > 0 then return FT.PlaceOf(own) end
 local item = startItem(questId)
 if item and #item.points > 0 then return FT.PlaceOf(item.points) end
 if FT.OwnQuestPoint then
  local map, x, y = FT.OwnQuestPoint(questId, 'accept')
  if map and x and y then return FT.PlaceOf({{map = map, x = x, y = y}}) end
 end
end

-- Görevi veren ('accept') ya da teslim alan ('turnin') NPC'nin yeri: {map, x, y, text = "Bölge · 45, 62"} ya da nil (önbellekli)
function FT.QuestSpot(questId, kind)
 if not questId then return nil end
 if kind == 'turnin' then return cachedPlace(questId .. ':turnin', function() return turnInPlace(questId) end) or nil end
 return cachedPlace(questId .. ':accept', function() return acceptPlaceOf(questId) end) or nil
end

-- Görevin tam planı: günlükteyse gerçek adımlar (FT.QuestSteps); henüz alınmamışsa veritabanından önizleme
-- ("Görevi al: NPC" + hedefler + teslim). Teslim edilmiş görevde boş liste. Rehberde ve ayrıntılı ipucunda kullanılır.
function FT.QuestPlan(questId)
 if not questId then return {} end
 local q = C_QuestLog
 local inLog = q and q.GetLogIndexForQuestID and (q.GetLogIndexForQuestID(questId) or 0) > 0
 if inLog then return FT.QuestSteps(questId) end
 if q and q.IsQuestFlaggedCompleted and q.IsQuestFlaggedCompleted(questId) then return {} end
 if FT.turnedIn and FT.turnedIn[questId] then return {} end
 local list = {}
 local giver = FT.StepNpc and FT.StepNpc({type = 'accept', questId = questId}) or nil
 local givePlace = FT.QuestSpot(questId, 'accept')
 list[1] = {kind = 'accept', text = giver and ('Görevi al: ' .. giver) or 'Görevi al', done = false, have = 0, need = 0, place = givePlace or nil}
 local objectives = FT.QuestObjectiveList and FT.QuestObjectiveList(questId) or {}
 for index, e in ipairs(objectives) do
  local verb = KIND_VERB[e.kind]
  local name = e.name
  local place = cachedPlace(questId .. ':p' .. index, function()
   return FT.PlaceOf(objectivePoints({questId = questId, index = index, npcs = e.npcs, objs = e.objs}))
  end)
  list[#list + 1] = {kind = e.kind, text = (name and verb) and (verb .. ': ' .. name) or (name or 'Hedef'), done = false, have = 0, need = 0, place = place or nil, objIndex = index}
 end
 local npc
 if FT.TurnInName then local ok, name = pcall(FT.TurnInName, questId); if ok and type(name) == 'string' and name ~= '' then npc = name end end
 npc = npc or (FT.OwnGiverName and FT.OwnGiverName(questId, 'turnin')) or nil
 list[#list + 1] = {kind = 'turnin', text = npc and ('Teslim et: ' .. npc) or 'Görevi teslim et', done = false, have = 0, need = 0,
  place = cachedPlace(questId .. ':turnin', function() return turnInPlace(questId) end) or nil}
 list[1].current = true
 return list
end

-- Sıradaki durak: bu adımdan sonra, farklı bir NPC ile konuşulacak ilk adım ({npc, verb, title}); yoksa nil
function FT.NextStop(guide, index)
 if not (guide and guide.steps and index) then return nil end
 local current = FT.StepNpc(guide.steps[index])
 for i = index + 1, math.min(#guide.steps, index + 12) do
  local s = guide.steps[i]
  if s and (s.type == 'accept' or s.type == 'turnin') then
   local npc = FT.StepNpc(s)
   if npc and npc ~= current then
    local info = FT.StepInfo(s)
    return {npc = npc, verb = info.verb, title = info.title, index = i}
   end
  end
 end
end

-- Görev günlüğünde tamamlanmış ama henüz teslim edilmemiş görevler: sayı ve toplam XP ("başka yerde teslim edilecek")
function FT.PendingTurnIns(exceptQuestId)
 local q = C_QuestLog
 local count, xp = 0, 0
 if not (q and q.GetNumQuestLogEntries and q.GetInfo and q.IsComplete) then return 0, 0 end
 for i = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(i)
  local id = info and not info.isHeader and info.questID
  if id and id > 0 and id ~= exceptQuestId then
   local ok, done = pcall(q.IsComplete, id)
   if ok and done == true then
    count = count + 1
    if FT.QuestXPInfo then local ok2, v = pcall(FT.QuestXPInfo, id); if ok2 and type(v) == 'number' then xp = xp + v end end
   end
  end
 end
 return count, xp
end

-- Seviye tahmini: rehber `index` adımından sürdürülürse, teslim adımlarının XP'si bir sonraki seviyeyi hangi adımda getirir?
-- Dönüş: adım sırası, seviye (yoksa nil)
function FT.LevelForecast(guide, index)
 if not (guide and guide.steps and index and UnitXP and UnitXPMax and UnitLevel and FT.QuestXPInfo) then return nil end
 local need = UnitXPMax('player') - UnitXP('player')
 if need <= 0 then return nil end
 local gained = 0
 for i = index, #guide.steps do
  local s = guide.steps[i]
  if s and s.type == 'turnin' and s.questId then
   local ok, xp = pcall(FT.QuestXPInfo, s.questId)
   if ok and type(xp) == 'number' then gained = gained + xp end
   if gained >= need then return i, UnitLevel('player') + 1 end
  end
 end
end

-- XP kazancı eklenince seviye ve seviye içi oran: (level, oran 0-1, çok seviye atlandı mı).
-- Sonraki seviyelerin XP eşiği bilinmiyor; her seviye için şimdiki eşiğin ~%7 fazlası varsayılır (tahmini).
function FT.ProjectXP(gain)
 if not (UnitXP and UnitXPMax and UnitLevel) then return nil end
 local level, xp, max = UnitLevel('player'), UnitXP('player'), UnitXPMax('player')
 if not max or max <= 0 then return nil end
 local cap = GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
 local jumped = false
 xp = xp + (gain or 0)
 while xp >= max and level < cap do
  xp = xp - max; level = level + 1; max = max * 1.07; jumped = true
 end
 return level, math.min(1, xp / max), jumped
end

-- "Yapılacaklar": günlükteki görevler (teslime hazır / sürüyor) ve rehberde kalan görevlerin XP katkısı.
-- Dönüş: {rows = {{questId,title,xp,status,npc,estimated}...}, readyCount, readyXP, activeXP, futureCount, futureXP, totalXP,
--         thisXP, thisPct, ready = {level, oran}, all = {level, oran, tahminiMi}, estimated}
function FT.TodoSummary(guide, index)
 local q = C_QuestLog
 local out = {rows = {}, readyCount = 0, readyXP = 0, activeCount = 0, activeXP = 0, futureCount = 0, futureXP = 0, estimated = false}
 local seen = {}
 local max = UnitXPMax and UnitXPMax('player') or 0
 local function xpOf(id)
  if not FT.QuestXPInfo then return nil end
  local ok, v, est = pcall(FT.QuestXPInfo, id)
  if ok and type(v) == 'number' and v > 0 then
   if est then out.estimated = true end
   return v, est
  end
 end
 if q and q.GetNumQuestLogEntries and q.GetInfo then
  local ready, active = {}, {}
  for i = 1, q.GetNumQuestLogEntries() do
   local info = q.GetInfo(i)
   local id = info and not info.isHeader and info.questID
   if id and id > 0 then
    seen[id] = true
    local done = false
    if q.IsComplete then local ok, v = pcall(q.IsComplete, id); done = ok and v == true end
    local xp, est = xpOf(id)
    local row = {questId = id, title = FT.QuestTitle and FT.QuestTitle(id, info.title) or info.title or '', xp = xp or 0, estimated = est,
     status = done and 'ready' or 'active', npc = FT.StepNpc and FT.StepNpc({type = 'turnin', questId = id}) or nil}
    if done then out.readyCount = out.readyCount + 1; out.readyXP = out.readyXP + row.xp; ready[#ready + 1] = row
    else out.activeCount = out.activeCount + 1; out.activeXP = out.activeXP + row.xp; active[#active + 1] = row end
   end
  end
  table.sort(ready, function(a, b) return a.xp > b.xp end)
  table.sort(active, function(a, b) return a.xp > b.xp end)
  for _, r in ipairs(ready) do out.rows[#out.rows + 1] = r end
  for _, r in ipairs(active) do out.rows[#out.rows + 1] = r end
 end
 -- rehberde kalan, günlükte olmayan görevler (teslim adımı olanlar)
 if guide and guide.steps and index then
  for i = index, #guide.steps do
   local s = guide.steps[i]
   if s and s.type == 'turnin' and s.questId and not seen[s.questId] then
    seen[s.questId] = true
    local state = FT.QuestState and FT.QuestState(s.questId) or {}
    if state.status ~= 'turned_in' then
     out.futureCount = out.futureCount + 1
     out.futureXP = out.futureXP + (xpOf(s.questId) or 0)
    end
   end
  end
  local cur = guide.steps[index]
  if cur and cur.questId then
   out.thisXP = xpOf(cur.questId)
   if out.thisXP and max > 0 then out.thisPct = out.thisXP / max end
  end
 end
 out.totalXP = out.readyXP + out.activeXP + out.futureXP
 local rl, rp = FT.ProjectXP(out.readyXP)
 if rl then out.ready = {rl, rp} end
 local al, ap, jumped = FT.ProjectXP(out.totalXP)
 if al then out.all = {al, ap, jumped} end
 return out
end

----------------------------------------------------------------------
-- Tempo: oturumdaki XP hızı ve seviyeye kalan süre
----------------------------------------------------------------------
local pace = {start = nil, gained = 0, lastXP = nil, lastMax = nil}

local function now() return GetTime and GetTime() or 0 end

local function snapshot()
 if not (UnitXP and UnitXPMax) then return end
 pace.lastXP, pace.lastMax = UnitXP('player'), UnitXPMax('player')
end

-- Test için: ölçümü sıfırla
function FT.PaceReset() pace.start, pace.gained, pace.lastXP, pace.lastMax = nil, 0, nil, nil end

-- Test için: olay işlemeyi doğrudan çağırır
function FT.PaceEvent(event)
 if event == 'PLAYER_XP_UPDATE' then
  if not (UnitXP and UnitXPMax) then return end
  local xp, max = UnitXP('player'), UnitXPMax('player')
  if pace.lastXP then
   if xp >= pace.lastXP then pace.gained = pace.gained + (xp - pace.lastXP)
   else pace.gained = pace.gained + math.max(0, (pace.lastMax or 0) - pace.lastXP) + xp end
  end
  pace.lastXP, pace.lastMax = xp, max
 elseif event == 'PLAYER_ENTERING_WORLD' then
  pace.start = pace.start or now()
  if not pace.lastXP then snapshot() end
 end
end

-- Dönüş: saatlik XP (sayı ya da nil), seviyeye kalan dakika (sayı ya da nil), kısa metin
function FT.Pace()
 local elapsed = pace.start and (now() - pace.start) or 0
 if pace.gained <= 0 or elapsed < 30 then return nil, nil, 'XP hızı ölçülüyor…' end
 local perHour = pace.gained / elapsed * 3600
 local remaining = UnitXP and UnitXPMax and (UnitXPMax('player') - UnitXP('player')) or nil
 local minutes = remaining and remaining > 0 and perHour > 0 and (remaining / perHour * 60) or nil
 local text = ('%d XP/sa'):format(math.floor(perHour + 0.5))
 if minutes then
  text = text .. (minutes >= 90 and ('  ·  seviyeye ~%.1f sa'):format(minutes / 60) or ('  ·  seviyeye ~%d dk'):format(math.max(1, math.floor(minutes + 0.5))))
 end
 return perHour, minutes, text
end

local ev = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_ENTERING_WORLD', 'PLAYER_XP_UPDATE'}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript('OnEvent', function(_, event) pcall(FT.PaceEvent, event) end)
