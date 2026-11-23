local _, FT = ...

-- Forever (Mainline altyapısı): eski global GetItemInfo olmayabilir; C_Item.GetItemInfo kullanılır
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)

-- Eşya ipucunda görev bilgisi, silah ustaları, meslek istasyonları, görev bağlantıları,
-- görev geçmişi, kıtalar arası yolculuk, ekipman bulucu, zindan rehberi.

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function db() return FT.Module and FT.Module('QuestieDB') end
local function zone() return FT.Module and FT.Module('ZoneDB') end
local function title(id) return FT.QuestTitle and FT.QuestTitle(id) or ('Görev ' .. id) end

local function playerSpot()
 local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
 local pos = map and C_Map.GetPlayerMapPosition(map, 'player')
 if not pos then return map end
 local x, y = pos:GetXY()
 return map, x, y
end

local function completed(id)
 local q = C_QuestLog
 return (FT.turnedIn and FT.turnedIn[id]) or (q and q.IsQuestFlaggedCompleted and q.IsQuestFlaggedCompleted(id) == true)
end

-- Bir NPC'nin tüm noktaları (harita kimliği ile)
local function npcSpots(id)
 local d, z = db(), zone()
 local out = {}
 local spawns = d and d.QueryNPCSingle(id, 'spawns')
 if type(spawns) ~= 'table' or not z then return out end
 for area, pts in pairs(spawns) do
  local ui = z:GetUiMapIdByAreaId(area)
  if ui then for _, p in ipairs(pts) do out[#out + 1] = {map=ui, x=p[1] / 100, y=p[2] / 100} end end
 end
 return out
end

local function nearest(points)
 local map, px, py = playerSpot()
 local best, bd
 for _, p in ipairs(points) do
  local d = (map and p.map == map and px) and ((p.x - px) ^ 2 + (p.y - py) ^ 2) or 100
  if not bd or d < bd then best, bd = p, d end
 end
 return best
end

----------------------------------------------------------------------
-- 1) Eşya ipucunda görev bilgisi
----------------------------------------------------------------------
local function itemLines(tip)
 if not on('itemquests') then return end
 local _, link = tip:GetItem()
 local id = link and tonumber(link:match('item:(%d+)'))
 if not id then return end
 local added = false
 for _, o in ipairs(FT.ActiveObjectives and FT.ActiveObjectives() or {}) do
  if o.itemId == id then
   tip:AddLine(('|cffffd100[ForeverTrail]|r Görev için gerekli: %s (%d/%d)'):format(o.title or '?', o.have, o.need), 1, 1, 1, true)
   added = true
  end
 end
 local it = FT.DBI and FT.DBI[id]
 if it then
  if type(it[4]) == 'number' and it[4] > 0 and not completed(it[4]) then
   tip:AddLine(('|cffffd100[ForeverTrail]|r Bu eşya bir görev başlatır: %s'):format(title(it[4])), 0.4, 1, 0.4, true)
   added = true
  end
  if type(it[5]) == 'table' and it[5][1] then
   tip:AddLine(('|cffffd100[ForeverTrail]|r Görev ödülü: %s'):format(title(it[5][1])), 0.75, 0.75, 0.75, true)
   added = true
  end
 end
 if added then if tip == GameTooltip and FT.ShowTip then FT.ShowTip(tip) else tip:Show() end end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
 pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(tip) pcall(itemLines, tip) end)
else
 for _, tip in ipairs({GameTooltip, ItemRefTooltip}) do
  if tip and tip.HookScript then pcall(tip.HookScript, tip, 'OnTooltipSetItem', function(self) pcall(itemLines, self) end) end
 end
end

----------------------------------------------------------------------
-- 2) Silah ustaları (Classic verisi)
----------------------------------------------------------------------
local WEAPON_MASTERS = {
 [11865] = {'Yumruk silahları', 'Tüfekler', 'Tek elli baltalar', 'Tek elli gürzler', 'İki elli baltalar', 'İki elli gürzler'},
 [11866] = {'Yaylar', 'Hançerler', 'Yumruk silahları', 'Asalar', 'Fırlatma'},
 [11867] = {'Arbaletler', 'Hançerler', 'Tek elli kılıçlar', 'Mızraklar', 'Asalar', 'İki elli kılıçlar'},
 [13084] = {'Arbaletler', 'Hançerler', 'Fırlatma'},
 [2704] = {'Yaylar', 'Tek elli baltalar', 'Asalar', 'Fırlatma', 'İki elli baltalar'},
 [11868] = {'Yaylar', 'Hançerler', 'Yumruk silahları', 'Tek elli baltalar', 'Fırlatma', 'İki elli baltalar'},
 [11869] = {'Tüfekler', 'Tek elli gürzler', 'Asalar', 'İki elli gürzler'},
 [11870] = {'Arbaletler', 'Hançerler', 'Tek elli kılıçlar', 'Mızraklar', 'İki elli kılıçlar'},
}
function FT.ShowWeaponMasters()
 local d = db()
 local faction = UnitFactionGroup and UnitFactionGroup('player') == 'Horde' and 'H' or 'A'
 local lines, closest, closestName = {}, nil, nil
 for id, skills in pairs(WEAPON_MASTERS) do
  local friendly = d and d.QueryNPCSingle(id, 'friendlyToFaction')
  if not friendly or friendly:find(faction, 1, true) then
   local name = d and d.QueryNPCSingle(id, 'name') or ('NPC ' .. id)
   local p = nearest(npcSpots(id))
   local where = p and FT.MapName and FT.MapName(p.map) or '?'
   lines[#lines + 1] = ('|cffffd100%s|r — %s'):format(name, where)
   lines[#lines + 1] = '   ' .. table.concat(skills, ', ')
   if p then
    local map = playerSpot()
    if not closest or (p.map == map and closest.map ~= map) then closest, closestName = p, name end
   end
  end
 end
 if #lines == 0 then lines[1] = 'Silah ustası bulunamadı.' end
 if closest then
  FT.SetCustomTarget(closest.map, closest.x, closest.y, closestName .. ' (silah ustası)')
  lines[#lines + 1] = ' '
  lines[#lines + 1] = '|cff55ff55Ok en yakın silah ustasını gösteriyor.|r'
 end
 FT.InfoWindow('Silah ustaları', lines)
end

----------------------------------------------------------------------
-- 3) Meslek istasyonları haritada
----------------------------------------------------------------------
local STATION = {
 anvil = {icon='Interface\\Icons\\Trade_BlackSmithing', label='Örs', skill={'blacksmith', 'demircilik', 'engineer', 'mühendislik'}},
 forge = {icon='Interface\\Icons\\Trade_Mining', label='Ocak (eritme)', skill={'mining', 'madencilik', 'blacksmith', 'demircilik'}},
 alchemyLab = {icon='Interface\\Icons\\Trade_Alchemy', label='Simya masası', skill={'alchemy', 'simya'}},
}
local function knows(words)
 if not FT.Compat then return false end
 for i = 1, FT.Compat.NumSkillLines() do
  local name, header = FT.Compat.SkillLine(i)
  if name and not header then
   local lower = name:lower()
   for _, w in ipairs(words) do if lower:find(w, 1, true) then return true end end
  end
 end
 return false
end

local stationDots, stationCache = {}, {}
FT.stationDots = stationDots
function FT.DrawStations(mapID)
 for _, d in ipairs(stationDots) do d:Hide() end
 local parts = FT.mapParts
 local overlay = parts and parts.overlay
 if not (overlay and mapID and on('stations') and FT.DBStations) then return end
 local d, z = db(), zone()
 if not (d and z) then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local used = 0
 for key, def in pairs(STATION) do
  if knows(def.skill) then
   local ck = key .. ':' .. mapID
   if not stationCache[ck] then
    local pts = {}
    for _, oid in ipairs(FT.DBStations[key] or {}) do
     local spawns = d.QueryObjectSingle(oid, 'spawns')
     for area, list in pairs(spawns or {}) do
      if z:GetUiMapIdByAreaId(area) == mapID then
       for _, p in ipairs(list) do pts[#pts + 1] = {p[1] / 100, p[2] / 100} end
      end
     end
    end
    stationCache[ck] = pts
   end
   for _, p in ipairs(stationCache[ck]) do
    if used < 60 then
     used = used + 1
     local t = stationDots[used]
     if not t then t = overlay:CreateTexture(nil, 'OVERLAY'); t:SetTexCoord(0.08, 0.92, 0.08, 0.92); stationDots[used] = t end
     local sc = 16 * FT.Scale('mapIcons'); t:SetSize(sc, sc)
     t:SetTexture(def.icon)
     t:ClearAllPoints(); t:SetPoint('CENTER', overlay, 'TOPLEFT', p[1] * w, -p[2] * h)
     t.step = {x=p[1], y=p[2], uiMapID=mapID, questTitle=def.label, text='Meslek istasyonu', type='manual'}
     t:Show()
    end
   end
  end
 end
end

----------------------------------------------------------------------
-- 4) Görev bağlantıları: sohbetteki görev linkine bilgi ekle
----------------------------------------------------------------------
local function questLinkLines(tip, link)
 local id = type(link) == 'string' and tonumber(link:match('quest:(%d+)'))
 local d = db()
 if not (id and d) then return end
 local level = d.QueryQuestSingle(id, 'questLevel')
 local starters = d.QueryQuestSingle(id, 'startedBy')
 local npc = starters and starters[1] and starters[1][1]
 local npcName = npc and d.QueryNPCSingle(npc, 'name')
 local p = npc and nearest(npcSpots(npc))
 tip:AddLine(' ')
 tip:AddLine(('|cffffd100[ForeverTrail]|r Seviye %s'):format(level or '?'), 1, 1, 1)
 if npcName then tip:AddLine(('Veren: %s%s'):format(npcName, p and FT.MapName and (' — ' .. (FT.MapName(p.map) or '')) or ''), 1, 1, 1) end
 local q = C_QuestLog
 local index = q and q.GetLogIndexForQuestID and q.GetLogIndexForQuestID(id)
 if index and index > 0 then
  local ok, rows = pcall(q.GetQuestObjectives, id)
  for _, r in ipairs(ok and rows or {}) do tip:AddLine(('  %s'):format(r.text or ''), r.finished and 0.5 or 1, r.finished and 1 or 0.9, 0.5) end
 elseif completed(id) then tip:AddLine('Bu görevi tamamladın.', 0.5, 1, 0.5) end
 if tip == GameTooltip and FT.ShowTip then FT.ShowTip(tip) else tip:Show() end
end
for _, tip in ipairs({ItemRefTooltip, GameTooltip}) do
 if tip and hooksecurefunc then pcall(hooksecurefunc, tip, 'SetHyperlink', function(self, link) pcall(questLinkLines, self, link) end) end
end

----------------------------------------------------------------------
-- 5) Görev geçmişi (zaman çizelgesi)
----------------------------------------------------------------------
local function journal()
 ForeverTrailCharacter.journey = ForeverTrailCharacter.journey or {}
 return ForeverTrailCharacter.journey
end
local function log(kind, id, extra)
 local j = journal()
 j[#j + 1] = {t=time and time() or 0, e=kind, id=id, l=UnitLevel('player'), x=extra}
 while #j > 600 do table.remove(j, 1) end
end
local LABEL = {accept='|cffffd100Aldın|r', turnin='|cff55ff55Teslim ettin|r', abandon='|cff9d9d9dBıraktın|r', level='|cff6fb7ffSeviye atladın|r'}
function FT.ShowJourney()
 local j = journal()
 local lines, lastDay = {}, nil
 for i = #j, math.max(1, #j - 40), -1 do
  local e = j[i]
  local day = date and date('%d.%m.%Y', e.t) or ''
  if day ~= lastDay then lines[#lines + 1] = '|cffd6a64c' .. day .. '|r'; lastDay = day end
  local what = e.e == 'level' and ('Seviye ' .. (e.x or e.l)) or title(e.id)
  lines[#lines + 1] = ('  %s %s  %s'):format(date and date('%H:%M', e.t) or '', LABEL[e.e] or e.e, what)
  if #lines >= 18 then break end
 end
 if #lines == 0 then lines[1] = 'Henüz kayıt yok. Görev aldıkça ve teslim ettikçe burada görünür.' end
 FT.InfoWindow('Görev geçmişi', lines)
end

----------------------------------------------------------------------
-- 6) Kıtalar arası yolculuk
----------------------------------------------------------------------
local CONTINENT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2
local function continentOf(map)
 local guard = 0
 while map and guard < 10 do
  local mi = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  if not mi then return nil end
  if mi.mapType == CONTINENT then return map end
  map = mi.parentMapID; guard = guard + 1
 end
end
local zeppelins
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() zeppelins = nil end
local function zeppelinMasters()
 if zeppelins then return zeppelins end
 zeppelins = {}
 for id, n in pairs(FT.DBN or {}) do
  if n[11] == 'Zeppelin Master' then zeppelins[#zeppelins + 1] = {id=id, name=n[1]} end
 end
 return zeppelins
end
-- Dönüş: geçici hedef (zeplin ustası) ya da yalnızca metin ipucu
function FT.TravelHint(playerMap, step)
 if not on('travel') or not (C_Map and C_Map.GetMapInfo and step and step.uiMapID) then return nil end
 local from, to = continentOf(playerMap), continentOf(step.uiMapID)
 if not from or not to or from == to then return nil end
 local toName = FT.MapName and FT.MapName(to) or 'diğer kıta'
 if UnitFactionGroup and UnitFactionGroup('player') == 'Horde' then
  local best, bd
  local _, px, py = playerSpot()
  for _, z in ipairs(zeppelinMasters()) do
   for _, p in ipairs(npcSpots(z.id)) do
    if p.map == playerMap and px then
     local d = (p.x - px) ^ 2 + (p.y - py) ^ 2
     if not bd or d < bd then best, bd = {map=p.map, x=p.x, y=p.y, name=z.name}, d end
    end
   end
  end
  if best then
   return {uiMapID=best.map, x=best.x, y=best.y, type='location', stepId='zeplin:' .. best.name, hint=('Zeplin: %s → %s'):format(best.name, toName)}
  end
  return nil, ('Zeplin kulesine git (%s)'):format(toName)
 end
 return nil, ('Gemiyle geç: %s'):format(toName)
end

----------------------------------------------------------------------
-- 7) Ekipman bulucu: alınabilir/aktif görevlerin ödüllerinde yükseltme
----------------------------------------------------------------------
local rewardIndex
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() rewardIndex = nil end
local function rewardsOf(questId)
 if not rewardIndex then
  rewardIndex = {}
  for itemId, it in pairs(FT.DBI or {}) do
   for _, q in ipairs(type(it[5]) == 'table' and it[5] or {}) do
    rewardIndex[q] = rewardIndex[q] or {}
    table.insert(rewardIndex[q], itemId)
   end
  end
 end
 return rewardIndex[questId] or {}
end
FT.QuestRewards = rewardsOf

function FT.ShowGearFinder()
 local candidates = {}
 local avail = FT.Module and FT.Module('AvailableQuests')
 for id in pairs(avail and avail.__availableQuests or {}) do candidates[id] = 'alınabilir' end
 local q = C_QuestLog
 for i = 1, (q and q.GetNumQuestLogEntries and q.GetNumQuestLogEntries() or 0) do
  local info = q.GetInfo(i)
  if info and not info.isHeader and info.questID and info.questID > 0 then candidates[info.questID] = 'günlükte' end
 end
 local found, pending = {}, 0
 for qid, state in pairs(candidates) do
  for _, itemId in ipairs(rewardsOf(qid)) do
   local name, link = GetItemInfo(itemId)
   if not link then pending = pending + 1
   elseif FT.ItemAdvice then
    local gain = FT.ItemAdvice(link)
    if gain and gain > 0 then found[#found + 1] = {gain=gain, link=link, quest=qid, state=state} end
   end
  end
 end
 table.sort(found, function(a, b) return a.gain > b.gain end)
 local lines = {}
 for i = 1, math.min(14, #found) do
  local f = found[i]
  lines[#lines + 1] = ('|cff55ff55+%d puan|r %s — %s (%s)'):format(f.gain, f.link, title(f.quest), f.state)
 end
 if #lines == 0 then lines[1] = 'Yakın görevlerin ödüllerinde sana yükseltme bulunamadı.' end
 if pending > 0 then lines[#lines + 1] = ('|cff9d9d9d%d eşya bilgisi yükleniyor; birkaç saniye sonra tekrar bak.|r'):format(pending) end
 FT.InfoWindow('Ekipman bulucu', lines)
end

----------------------------------------------------------------------
-- 8) Zindan rehberi
----------------------------------------------------------------------
local function dungeonAreas(id, d)
 local set = {[id] = true}
 for _, a in ipairs(d[2] or {}) do set[a] = true end
 return set
end

local function pickDungeon()
 local inInstance, kind = IsInInstance and IsInInstance()
 if inInstance and GetInstanceInfo then
  local name = GetInstanceInfo()
  for id, d in pairs(FT.DBDungeons or {}) do if d[1] == name then return id, d, true end end
 end
 local map, px, py = playerSpot()
 local z = zone()
 local best, bd, bid
 for id, d in pairs(FT.DBDungeons or {}) do
  for _, loc in ipairs((not FT.DungeonAllowed or FT.DungeonAllowed(id, d)) and d[4] or {}) do
   local ui = z and z:GetUiMapIdByAreaId(loc[1])
   if ui == map and px then
    local dist = (loc[2] / 100 - px) ^ 2 + (loc[3] / 100 - py) ^ 2
    if not bd or dist < bd then best, bd, bid = d, dist, id end
   end
  end
 end
 return bid, best, false
end

function FT.ShowDungeonGuide()
 local id, d, inside = pickDungeon()
 if not id then return FT.InfoWindow('Zindan rehberi', {'Yakında bilinen bir zindan yok. Bir zindanın bulunduğu bölgeye git.'}) end
 local areas = dungeonAreas(id, d)
 local lines = {('|cffffd100%s|r'):format(d[1])}
 local z = zone()
 local loc = d[4] and d[4][1]
 local ui = loc and z and z:GetUiMapIdByAreaId(loc[1])
 if loc and ui then
  lines[#lines + 1] = ('Giriş: %s %.1f, %.1f'):format(FT.MapName and FT.MapName(ui) or '', loc[2], loc[3])
  if not inside then FT.SetCustomTarget(ui, loc[2] / 100, loc[3] / 100, d[1] .. ' girişi') end
 end
 local inLog, open = {}, {}
 local q = C_QuestLog
 for qid, row in pairs(FT.DBQ or {}) do
  if areas[row[13]] then
   local index = q and q.GetLogIndexForQuestID and q.GetLogIndexForQuestID(qid)
   if index and index > 0 then inLog[#inLog + 1] = qid end
  end
 end
 local avail = FT.Module and FT.Module('AvailableQuests')
 for qid in pairs(avail and avail.__availableQuests or {}) do
  local row = FT.DBQ[qid]
  if row and areas[row[13]] then open[#open + 1] = qid end
 end
 lines[#lines + 1] = ('|cff55ff55Günlüğündeki görevler (%d):|r'):format(#inLog)
 for i = 1, math.min(5, #inLog) do lines[#lines + 1] = '  ' .. title(inLog[i]) end
 lines[#lines + 1] = ('|cffffd100Alabileceğin görevler (%d):|r'):format(#open)
 for i = 1, math.min(4, #open) do
  local giver = FT.QuestGiverZone and FT.QuestGiverZone(open[i])
  lines[#lines + 1] = '  ' .. title(open[i]) .. (giver and (' — ' .. giver) or '')
 end
 -- Görev bossları: bu zindanın görevlerinde hedef olan elitler (öldür ya da eşya düşür)
 local bosses, seenBoss = {}, {}
 local d = db()
 local function addNpc(nid)
  local n = FT.DBN and FT.DBN[nid]
  if n and (n[4] or 0) >= 1 and not seenBoss[nid] then seenBoss[nid] = true; bosses[#bosses + 1] = {name=n[1], level=n[3] or 0} end
 end
 for qid, row in pairs(FT.DBQ or {}) do
  if areas[row[13]] and type(row[9]) == 'table' then
   for _, r in ipairs(row[9][1] or {}) do addNpc(r[1]) end
   for _, r in ipairs(row[9][3] or {}) do
    local drops = d and d.QueryItemSingle(r[1], 'npcDrops')
    if type(drops) == 'table' and #drops <= 3 then for _, nid in ipairs(drops) do addNpc(nid) end end
   end
  end
 end
 table.sort(bosses, function(a, b) return a.level < b.level end)
 local names = {}
 for i = 1, math.min(9, #bosses) do names[i] = bosses[i].name end
 if #bosses > 0 then lines[#lines + 1] = '|cffff7070Görev bossları:|r ' .. table.concat(names, ', ') end
 if not inside and ui then lines[#lines + 1] = '|cff9d9d9dOk zindan girişini gösteriyor.|r' end
 FT.InfoWindow('Zindan rehberi', lines)
end

----------------------------------------------------------------------
-- Olaylar (geçmiş kaydı)
----------------------------------------------------------------------
local events = CreateFrame('Frame')
for _, e in ipairs({'QUEST_ACCEPTED', 'QUEST_TURNED_IN', 'PLAYER_LEVEL_UP', 'SKILL_LINES_CHANGED'}) do pcall(events.RegisterEvent, events, e) end
events:SetScript('OnEvent', function(_, event, a, b)
 local ok, err = pcall(function()
  if event == 'QUEST_ACCEPTED' then
   local id = (type(b) == 'number' and b > 0) and b or a
   if type(id) == 'number' and id > 0 then log('accept', id) end
  elseif event == 'QUEST_TURNED_IN' then log('turnin', a)
  elseif event == 'PLAYER_LEVEL_UP' then log('level', nil, a)
  elseif event == 'SKILL_LINES_CHANGED' then stationCache = {}
  end
 end)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'journey: ' .. tostring(err) end
end)
