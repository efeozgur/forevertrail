local _, FT = ...

-- Görev gereksinimleri: bir göreve gidip "boşa gitmemek" için eksik olanı önceden bildirir.
--  * önce yapılması gereken görev (ön koşul: preQuestGroup = hepsi, preQuestSingle = herhangi biri), karakterin GERÇEK durumuna göre
--  * görev hedefinin eşyası başka bir görevden geliyorsa (ödül ya da görevi alınca verilen eşya) ve çantada yoksa
-- Rehber kartı, ayrıntılı ipucu, görev listeleri, yola çıkarken açılır uyarı ve otopilot aynı sonucu kullanır.

local cache, srcIndex = {}, nil
-- Sonuçları etkileyen eşyalar ve görüldüğü sayı: çantada bunlardan biri değişince önbellek atılır ve ekranlar yenilenir
-- (eşya alındığında uyarı, başka bir görev olayı gelene kadar eski kalıyordu)
local watched = {}

-- Çantada bu adda bir eşya var mı? Veritabanındaki eşya numarası oyundakiyle uyuşmayabilir (Forever verisi ile Questie ayrışır):
-- numarayla bulunamazsa çanta adla taranır. Yalnızca numarayla bulunamayan, izlenen birkaç eşya için çalışır.
local function bagHasName(name)
 if type(name) ~= 'string' or name == '' then return false end
 local C = C_Container
 if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return false end
 for bag = 0, (NUM_BAG_SLOTS or 4) do
  local slots = C.GetContainerNumSlots(bag) or 0
  for slot = 1, slots do
   local ok, info = pcall(C.GetContainerItemInfo, bag, slot)
   local link = ok and type(info) == 'table' and info.hyperlink
   if link and link:match('%[(.-)%]') == name then return true end
  end
 end
 return false
end

local function haveCount(itemId, name)
 local c = (GetItemCount and GetItemCount(itemId)) or 0
 if c == 0 and name and bagHasName(name) then return 1 end
 return c
end
local function watch(itemId, count, name) watched[itemId] = {count = count, name = name} end

local function listOf(v) return type(v) == 'table' and v or {} end

-- Teslim edilmiş mi (oyunun kaydı ya da bu oturumda teslim edilenler)
function FT.QuestFinished(id)
 local q = C_QuestLog
 if q and q.IsQuestFlaggedCompleted and q.IsQuestFlaggedCompleted(id) then return true end
 return (FT.turnedIn and FT.turnedIn[id]) and true or false
end

local function inLog(id)
 local q = C_QuestLog
 return (q and q.GetLogIndexForQuestID and (q.GetLogIndexForQuestID(id) or 0) > 0) and true or false
end

-- eşya -> o eşyayı görevi alınca veren görevler (sourceItemId)
local function sourceQuests(itemId)
 if not srcIndex then
  srcIndex = {}
  for id, q in pairs(FT.DBQ or {}) do
   local it = q[19]
   if type(it) == 'number' and it > 0 then
    local l = srcIndex[it]
    if not l then l = {}; srcIndex[it] = l end
    l[#l + 1] = id
   end
  end
  for _, l in pairs(srcIndex) do table.sort(l) end
 end
 return srcIndex[itemId]
end

local function itemName(id)
 local it = FT.DBI and FT.DBI[id]
 return (it and type(it[1]) == 'string' and it[1] ~= '') and it[1] or ('Eşya ' .. id)
end

-- Eşyanın düştüğü yaratıklar ve (zindan patronuysa) zindan: {names = "Edwin VanCleef", dungeon = "The Deadmines"}; bilinmiyorsa nil.
-- Eşyayla başlayan görevlerde "nereden alırım?" sorusunun cevabı budur (görevi veren NPC yoktur).
local function dropInfo(itemId)
 local it = FT.DBI and FT.DBI[itemId]
 if not it then return nil end
 local names, dungeon = {}, nil
 for i, nid in ipairs(type(it[2]) == 'table' and it[2] or {}) do
  if i > 3 then break end
  local n = FT.DBN and FT.DBN[nid]
  if n and type(n[1]) == 'string' and n[1] ~= '' then
   names[#names + 1] = n[1]
   local d = type(n[7]) == 'number' and FT.DBDungeons and FT.DBDungeons[n[7]]
   if d and not dungeon then dungeon = d[1] end
  end
 end
 if #names == 0 then
  for i, oid in ipairs(type(it[3]) == 'table' and it[3] or {}) do
   if i > 3 then break end
   local o = FT.DBO and FT.DBO[oid]
   if o and type(o[1]) == 'string' and o[1] ~= '' then names[#names + 1] = o[1] end
  end
 end
 if #names == 0 then return nil end
 return {names = table.concat(names, ', '), dungeon = dungeon}
end

-- Bağlantılı görevin kaydı: günlükteyse teslim edilecek yer, değilse alınacak yer
local function linked(pid)
 local logged = inLog(pid)
 local title = FT.QuestTitle and FT.QuestTitle(pid) or ('Görev ' .. pid)
 local npc, startItem, startItemId
 if logged then
  if FT.TurnInName then local ok, n = pcall(FT.TurnInName, pid); if ok and type(n) == 'string' and n ~= '' then npc = n end end
 else
  -- veren: NPC, yoksa nesne (ilan tahtası...); ikisi de yoksa görevi bir eşya başlatıyordur (yaratıktan düşer)
  if FT.QuestGiverName then local ok, n = pcall(FT.QuestGiverName, pid); if ok and type(n) == 'string' and n ~= '' then npc = n end end
  if not npc and FT.StepNpc then local ok, n = pcall(FT.StepNpc, {type = 'accept', questId = pid}); if ok and type(n) == 'string' and n ~= '' then npc = n end end
  if not npc and FT.QuestStartItem then
   local ok, it = pcall(FT.QuestStartItem, pid)
   if ok and it then startItem, startItemId = it.name, it.itemId end
  end
 end
 local haveStart = false
 if startItemId then local c = haveCount(startItemId, startItem); watch(startItemId, c, startItem); haveStart = c > 0 end
 local spot = FT.QuestSpot and FT.QuestSpot(pid, logged and 'turnin' or 'accept') or nil
 local where = spot and spot.text or nil
 -- tam nokta verisi yoksa en azından bölge
 if not where and FT.QuestZoneName then
  local ok, zone = pcall(FT.QuestZoneName, pid)
  if ok and type(zone) == 'string' and zone ~= '' then where = zone .. ' (tam konum verisi yok)' end
 end
 if startItem and not spot then where = nil end -- eşyayla başlayan görevin bölgesi, eşyanın düştüğü yer değildir: yanıltıcı olur
 return {questId = pid, title = title, logged = logged, npc = npc, startItem = startItem, startItemId = startItemId, haveStartItem = haveStart, startDrop = startItemId and dropInfo(startItemId) or nil, place = spot, where = where}
end

local function questEntry(pid)
 local e = linked(pid)
 e.kind = 'quest'
 e.text = 'Önce görev: ' .. e.title
 local complete = e.logged and C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(pid) and true or false
 if e.logged and complete then
  e.ready = true -- hedefleri bitti: yalnızca teslim kaldı
  e.detail = 'Hazır: teslim et' .. (e.npc and (' → ' .. e.npc) or '')
 elseif e.logged then e.detail = 'Günlüğünde: önce bitirip teslim et' .. (e.npc and (' → ' .. e.npc) or '')
 elseif e.startItem and e.haveStartItem then
  -- görevi bir eşya başlatıyor ve eşya çantada: artık bir yere gitmek gerekmiyor, eşyaya sağ tıklamak yeter
  e.ready = true; e.place = nil; e.where = nil
  e.detail = 'Eşyan çantanda: ' .. e.startItem .. ' — sağ tıkla, görevi başlat'
 elseif e.npc then e.detail = 'Görevi al: ' .. e.npc
 elseif e.startItem then
  local d = e.startDrop
  if d then
   -- eşya bir yaratıktan düşer (çoğu zaman zindan patronu): kimden, nerede
   e.dungeon = d.dungeon
   e.detail = 'Eşyayla başlar: ' .. e.startItem .. ' · düşer: ' .. d.names .. (d.dungeon and (' (' .. d.dungeon .. ' zindanı)') or '')
  else e.detail = 'Eşyayla başlar: ' .. e.startItem .. (e.place and ' (düştüğü yerler)' or '') end
 else e.detail = 'Önce bu görevi al' end
 return e
end

-- Eşyayı sağlayan, henüz yapılmamış görev: görevi alınca verenler önce, sonra ödül olarak verenler
local function providerOf(itemId, exceptQuest)
 for _, pid in ipairs(sourceQuests(itemId) or {}) do
  if pid ~= exceptQuest and not FT.QuestFinished(pid) then return pid, 'verir' end
 end
 local it = FT.DBI and FT.DBI[itemId]
 for _, pid in ipairs(it and listOf(it[5]) or {}) do
  if type(pid) == 'number' and pid ~= exceptQuest and not FT.QuestFinished(pid) then return pid, 'ödül' end
 end
end

local function itemEntry(itemId, questId)
 local pid, how = providerOf(itemId, questId)
 if not pid then return nil end
 local e = linked(pid)
 e.kind = 'item'
 e.itemId = itemId
 e.name = itemName(itemId)
 e.how = how
 e.text = 'Eşya gerekli: ' .. e.name
 e.detail = ('“%s” görevinden gelir (%s)'):format(e.title, how == 'ödül' and 'ödül' or 'görevi alınca verilir')
 if e.logged then e.detail = e.detail .. ' · günlüğünde: önce bitir'
 elseif e.npc then e.detail = e.detail .. ' · ' .. e.npc
 elseif e.startItem then e.detail = e.detail .. ' · eşyayla başlar: ' .. e.startItem end
 return e
end

-- Görevin eksik gereksinimleri (boşsa sorun yok). Kısa süre önbellekte tutulur.
function FT.QuestRequirements(questId)
 if not (questId and FT.DBQ) then return {} end
 local now = GetTime and GetTime() or 0
 local c = cache[questId]
 if c and now - c.t < 3 then return c.list end
 local list, seen = {}, {}
 local q = FT.DBQ[questId]
 if q and not FT.QuestFinished(questId) then
  local logged = inLog(questId)
  if not logged then
   -- ön koşul görevler: hepsi (group) / herhangi biri (single)
   for _, pid in ipairs(listOf(q[10])) do
    if not FT.QuestFinished(pid) and not seen[pid] then seen[pid] = true; list[#list + 1] = questEntry(pid) end
   end
   local single = listOf(q[11])
   if #single > 0 then
    local any = false
    for _, pid in ipairs(single) do if FT.QuestFinished(pid) then any = true; break end end
    if not any then
     local pick
     for _, pid in ipairs(single) do if inLog(pid) then pick = pid; break end end
     pick = pick or single[1]
     if pick and not seen[pick] then
      seen[pick] = true
      local e = questEntry(pick)
      e.alternatives = #single - 1
      list[#list + 1] = e
     end
    end
   end
  end
  -- hedef eşyası: düşme kaynağı yok, başka bir görevden geliyor ve çantada yok
  if GetItemCount then
   local obj = q[9]
   for _, r in ipairs(type(obj) == 'table' and listOf(obj[3]) or {}) do
    local itemId = type(r) == 'table' and r[1]
    if type(itemId) == 'number' then
     local iname = itemName(itemId)
     local have = haveCount(itemId, iname)
     local it = FT.DBI and FT.DBI[itemId]
     local drops = it and ((type(it[2]) == 'table' and #it[2] or 0) + (type(it[3]) == 'table' and #it[3] or 0)) or 0
     if drops == 0 then
      watch(itemId, have, iname) -- çantada olsa da izlenir: eşya gidince uyarı geri gelmeli
      if have == 0 then
       local e = itemEntry(itemId, questId)
       if e and not seen[e.questId] then seen[e.questId] = true; list[#list + 1] = e end
      end
     end
    end
   end
  end
 end
 cache[questId] = {list = list, t = now}
 return list
end

-- Bir gereksinime yönlendir: bağlantılı görevin NPC'sine rota (özel hedef)
-- Gerçekten eksik olanlar: hazır olanlar (eşya çantada, görev bitti) hariç. Liste rozetleri ve açılır uyarı bunu kullanır.
function FT.UnmetRequirements(questId)
 local out = {}
 for _, r in ipairs(FT.QuestRequirements(questId)) do if not r.ready then out[#out + 1] = r end end
 return out
end

function FT.GoToRequirement(req)
 local p = req and req.place
 if not (p and p.map and p.x and p.y and FT.SetCustomTarget) then return false end
 FT.SetCustomTarget(p.map, p.x, p.y, req.npc or req.title, false)
 return true
end

-- Yola çıkarken uyarı: etkin adımın görevinde eksik gereksinim varsa bir kez (görev başına, oturumda) açılır pencere
local warned, lastKey = {}, nil
function FT.StepRequirementWarning()
 local g = FT.guide
 if not (g and g.steps) or (FT.view or 1) ~= (FT.active or 1) then return end
 local s = g.steps[FT.active or 1]
 if not (s and s.questId) then return end
 local key = tostring(g.guideId) .. ':' .. tostring(s.stepId)
 if key == lastKey then return end
 lastKey = key
 if ForeverTrailSettings and ForeverTrailSettings.reqWarn == false then return end
 if s.type ~= 'accept' and s.type ~= 'objective' then return end
 if warned[s.questId] or not FT.ShowChoice then return end
 local reqs = FT.UnmetRequirements(s.questId)
 if #reqs == 0 then return end
 local title = FT.QuestTitle and FT.QuestTitle(s.questId) or s.questTitle or ('Görev ' .. s.questId)
 local lines = {}
 for i, r in ipairs(reqs) do
  if i > 3 then break end
  lines[#lines + 1] = '• ' .. r.text .. (r.where and (' — ' .. r.where) or '')
 end
 local text = ('“%s” için önce gerekli:\n%s'):format(title, table.concat(lines, '\n'))
 local first
 for _, r in ipairs(reqs) do if r.place then first = r; break end end
 local ok = FT.ShowChoice('Dikkat: boşa gitme', 'Interface\\Icons\\INV_Misc_Note_01', text,
  first and 'Gerekene git' or 'Tamam', function() if first then FT.GoToRequirement(first) end end)
 if ok then warned[s.questId] = true else lastKey = nil end
end

FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() cache = {}; srcIndex = nil; watched = {} end

-- Tanı: bir görevin gereksinimleri neden böyle? (/ftrail gereksinim [görev no]) Satırları döndürür.
function FT.RequirementsDebug(questId)
 local out = {}
 local function add(s) out[#out + 1] = s end
 if not questId then
  local g = FT.guide
  local s = g and g.steps and g.steps[FT.view or 1]
  questId = s and s.questId
 end
 if not questId then add('Etkin rehber adımında görev yok; görev numarası ver: /ftrail gereksinim 399'); return out end
 local q = FT.DBQ and FT.DBQ[questId]
 add(('Görev %d "%s": günlükte=%s teslim edilmiş=%s'):format(questId, FT.QuestTitle and FT.QuestTitle(questId) or '?', tostring(inLog(questId)), tostring(FT.QuestFinished(questId))))
 if q then
  add(('  ön koşul grubu=%s  ön koşul tekli=%s  alınca verilen eşya=%s'):format(
   type(q[10]) == 'table' and table.concat(q[10], ',') or '-', type(q[11]) == 'table' and table.concat(q[11], ',') or '-', tostring(q[19])))
  local obj = q[9]
  for _, r in ipairs(type(obj) == 'table' and listOf(obj[3]) or {}) do
   local id = type(r) == 'table' and r[1]
   if type(id) == 'number' then
    local it = FT.DBI and FT.DBI[id]
    local byId = (GetItemCount and GetItemCount(id)) or 0
    add(('  hedef eşyası %d "%s": çantada(numarayla)=%d çantada(adla)=%s  düşen yaratık=%d nesne=%d  ödül olarak=%s'):format(
     id, itemName(id), byId, tostring(bagHasName(itemName(id))),
     it and type(it[2]) == 'table' and #it[2] or 0, it and type(it[3]) == 'table' and #it[3] or 0,
     it and type(it[5]) == 'table' and table.concat(it[5], ',') or '-'))
    local srcs = sourceQuests(id)
    if srcs then add('    alınca veren görevler: ' .. table.concat(srcs, ',')) end
   end
  end
 else add('  (görev veritabanında yok)') end
 local reqs = FT.QuestRequirements(questId)
 add(('Gereksinimler (%d):'):format(#reqs))
 for _, r in ipairs(reqs) do
  add(('  [%s%s] %s | %s | görev=%s eşya=%s yer=%s'):format(r.kind, r.ready and ',hazır' or '', r.text or '', r.detail or '', tostring(r.questId), tostring(r.itemId or r.startItemId), tostring(r.where)))
 end
 return out
end

-- Çantada izlenen bir eşyanın sayısı değişince (alındı, kullanıldı, satıldı) önbellek atılır ve ekranlar bir kez yenilenir.
-- Yalnızca gerçekten izlenen eşyalar için çalışır; her çanta olayında yenileme yapılmaz.
FT.RequirementsBagChanged = function()
 for itemId, w in pairs(watched) do
  if haveCount(itemId, w.name) ~= w.count then
   cache = {}; watched = {}
   for _, fn in ipairs({'Refresh', 'RefreshTracker', 'RefreshAvailableBox'}) do if FT[fn] then pcall(FT[fn]) end end
   return true
  end
 end
 return false
end
if CreateFrame then
 local bag = CreateFrame('Frame')
 local pending = false
 for _, e in ipairs({'BAG_UPDATE_DELAYED', 'BAG_UPDATE'}) do pcall(bag.RegisterEvent, bag, e) end
 bag:SetScript('OnEvent', function()
  if pending or next(watched) == nil then return end
  pending = true
  local function go() pending = false; FT.RequirementsBagChanged() end
  if C_Timer and C_Timer.After then C_Timer.After(0.4, go) else go() end
 end)
end
