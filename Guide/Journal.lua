local _, FT = ...
local journal = {guideId="character-log", title="Karakterimin görevleri", zone="Görev günlüğü", version=1, steps={}, live=true}
local function placeholder(text)
 return {stepId="waiting", type="manual", text=text}
end
journal.steps[1] = placeholder("Görev günlüğü yükleniyor.")
FT.RegisterGuide(journal)

 local function questWaypoint(id, kind, objective)
  local QuestieDB = (FT.Module and FT.Module('QuestieDB')) or _G.QuestieDB
  if not QuestieDB and QuestieLoader and QuestieLoader.ImportModule then
   local ok, db = pcall(QuestieLoader.ImportModule, QuestieLoader, 'QuestieDB')
   if ok then QuestieDB = db end
  end
  local map, x, y
  if C_QuestLog and C_QuestLog.GetNextWaypoint then
   local ok, a, b, c = pcall(C_QuestLog.GetNextWaypoint, id)
   if ok then map, x, y = a, b, c end
  end
  if (not map or map == 0) and GetQuestUiMapID then
   local ok, value = pcall(GetQuestUiMapID, id)
   if ok then map = value end
  end
  if map == 0 then map = nil end
  if type(map) ~= 'number' then map = nil end
  if type(x) ~= 'number' or type(y) ~= 'number' then x, y = nil, nil end
  if not (map and x and y) and QuestieDB and (QuestieDB.GetQuest or QuestieDB.QueryQuestSingle) then
   local ok, quest = false, nil
   if QuestieDB.GetQuest then ok, quest = pcall(QuestieDB.GetQuest, id) end
   if (not ok or not quest) and QuestieDB.QueryQuestSingle then
    local startedOK, started = pcall(QuestieDB.QueryQuestSingle, id, 'startedBy')
    local finishedOK, finished = pcall(QuestieDB.QueryQuestSingle, id, 'finishedBy')
    if not startedOK then started = nil end
    if not finishedOK then finished = nil end
    quest = {
     Starts = {NPC = started and started[1]},
     Finisher = {NPC = finished and finished[1]},
    }
    if objective then
     local rawOK, raw = pcall(QuestieDB.QueryQuestSingle, id, 'objectives')
     if not rawOK then raw = nil end
     -- Hedefleri günlükteki sırayla düzleştir: yaratık, nesne, eşya (eşyayı düşüren yaratık/nesne)
     local list = {}
     if type(raw) == 'table' then
      for _, r in ipairs(raw[1] or {}) do if type(r) == 'table' then list[#list + 1] = {Type = 'monster', Id = r[1]} end end
      for _, r in ipairs(raw[2] or {}) do if type(r) == 'table' then list[#list + 1] = {Type = 'object', Id = r[1]} end end
      for _, r in ipairs(raw[3] or {}) do
       if type(r) == 'table' and QuestieDB.QueryItemSingle then
        local okN, npcs = pcall(QuestieDB.QueryItemSingle, r[1], 'npcDrops')
        local okO, objs = pcall(QuestieDB.QueryItemSingle, r[1], 'objectDrops')
        if okN and type(npcs) == 'table' and npcs[1] then list[#list + 1] = {Type = 'monster', Id = npcs[1]}
        elseif okO and type(objs) == 'table' and objs[1] then list[#list + 1] = {Type = 'object', Id = objs[1]} end
       end
      end
     end
     local row = list[objective] or list[1]
     if row then quest.ObjectiveData = {[objective] = row} end
    end
   end
   if quest then
    local entityID, entityType
    if kind == 'turnin' and quest.Finisher then
     entityID, entityType = quest.Finisher.NPC, 'npc'
    elseif kind == 'objective' and objective and quest.ObjectiveData and quest.ObjectiveData[objective] then
     local row = quest.ObjectiveData[objective]
     entityID = row.Id or (row.IdList and row.IdList[1])
     entityType = row.Type == 'object' and 'object' or 'npc'
    elseif quest.Starts then
     entityID, entityType = quest.Starts.NPC, 'npc'
    end
    if type(entityID)=='table' then entityID=entityID[1] end
    local getter = entityType == 'object' and QuestieDB.QueryObjectSingle or QuestieDB.QueryNPCSingle
    if getter and entityID then
     local success, spawned = pcall(getter, entityID, 'spawns')
     if not success then spawned = nil end
     local zones = spawned and type(spawned) == 'table' and spawned or nil
     local zoneDB = FT.Module and FT.Module('ZoneDB')
     if not zoneDB and QuestieLoader and QuestieLoader.ImportModule then
      local okZone, zone = pcall(QuestieLoader.ImportModule, QuestieLoader, 'ZoneDB')
      if okZone then zoneDB = zone end
     end
     if zones then
      local playerMap, playerX, playerY
      if C_Map and C_Map.GetBestMapForUnit then
       local ok, value = pcall(C_Map.GetBestMapForUnit, 'player')
       if ok then playerMap=value end
      end
      if playerMap and C_Map.GetPlayerMapPosition then
       local ok, position=pcall(C_Map.GetPlayerMapPosition, playerMap, 'player')
       if ok and position then
        local valid, px, py=pcall(function() return position:GetXY() end)
        if valid and type(px)=='number' and type(py)=='number' then playerX,playerY=px,py end
       end
      end
      local bestScore
      for areaID, rows in pairs(zones) do
       local uiMap = zoneDB and zoneDB.GetUiMapIdByAreaId and zoneDB:GetUiMapIdByAreaId(areaID)
       if uiMap and type(rows)=='table' then
        for _,row in ipairs(rows) do
         if type(row)=='table' and type(row[1])=='number' and type(row[2])=='number' then
          local px,py=row[1]/100,row[2]/100
          local score=uiMap==playerMap and 0 or 10
          if score==0 and playerX and playerY then score=(px-playerX)^2+(py-playerY)^2 end
          if not bestScore or score<bestScore then map,x,y,bestScore=uiMap,px,py,score end
         end
        end
       end
      end
     end
    end
   end
  end
  local questieMap = QuestieMap
  if not questieMap and QuestieLoader and QuestieLoader.ImportModule then
   local imported, module = pcall(QuestieLoader.ImportModule, QuestieLoader, 'QuestieMap')
   if imported then questieMap = module end
  end
  if not (map and x and y) and questieMap and questieMap.GetFramesForQuest then
   local success, frames = pcall(questieMap.GetFramesForQuest, questieMap, id)
   if success and type(frames) == 'table' then
    for _, frame in pairs(frames) do
     if frame and type(frame.x) == 'number' and type(frame.y) == 'number' and frame.UiMapID then
      map, x, y = frame.UiMapID, frame.x / 100, frame.y / 100
      break
     end
    end
   end
  end
  -- Son çare: kendi topladığımız veri (önceki kaynakların hiçbiri sonuç vermezse)
  if not (map and x and y) and FT.OwnQuestPoint then
   local om, ox, oy = FT.OwnQuestPoint(id, kind, objective)
   if om and ox then map, x, y = om, ox, oy end
  end
  return map, x, y
 end

FT.ResolveQuestWaypoint = questWaypoint

local function readSteps()
 local q = C_QuestLog
 local count = q.GetNumQuestLogEntries()
 local steps = {}
 local known = {}
 for _, old in ipairs(journal.steps) do
  if old.stepId and old.x and old.y and old.uiMapID then known[old.stepId] = old end
 end
 for index = 1, count do
  local info = q.GetInfo(index)
  if info and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then
   local id = info.questID
   local translation = QTR_QuestData and QTR_QuestData[tostring(id)]
   local name = translation and translation.Title or info.title
   local function add(kind, objective, text)
    local step = {stepId=id..":"..kind..":"..(objective or 0), type=kind, questId=id,
     objectiveIndex=objective, questTitle=name, text=text}
    local prev = known[step.stepId]
    if prev then step.uiMapID, step.x, step.y, step.auto = prev.uiMapID, prev.x, prev.y, prev.auto end
    if id == 747 then
     step.uiMapID=1412
     step.x=kind=="turnin" and 0.445 or 0.422
     step.y=kind=="turnin" and 0.775 or 0.777
     step.auto=nil
    end
    steps[#steps+1]=step
   end
   if q.IsComplete(id) then
    add("turnin",nil,"Görevi teslim et.")
   else
    local rows = q.GetQuestObjectives(id) or {}
    local pending = false
    for i,row in ipairs(rows) do
     local done = row.finished or (row.numRequired and row.numRequired>0 and row.numFulfilled and row.numFulfilled>=row.numRequired)
     if not done then
      pending=true
      add("objective",i,row.text or ("Hedef "..i))
     end
    end
    if not pending then add("objective",nil,"Görev günlüğündeki koşulları tamamla.") end
   end
  end
 end
 return steps
end

function FT.SelectNearest()
 -- Hazır ya da bölge rehberi seçiliyken onun içinde en yakın yapılmamış adım seçilir; günlük rehberine geçilmez
 local custom = FT.guide and not FT.guide.live and FT.guide.steps and true or false
 if not custom then
  for index, guide in ipairs(FT.validGuides) do
   if guide.live then FT.SelectGuide(index); break end
  end
 end
 local function notify(text) FT.notice = text; FT.Refresh() end
 if not (C_Map and C_Map.GetBestMapForUnit and FT.PlayerPosition) then return notify('Konum okunamıyor.') end
 local ok, map = pcall(C_Map.GetBestMapForUnit, 'player')
 if not ok or not map then return notify('Konum okunamıyor.') end
 local good, px, py = pcall(FT.PlayerPosition, map)
 if not good or not px then return notify('Konum okunamıyor.') end
 local best, bestDistance
 for index, step in ipairs(FT.guide.steps) do
  local finished = false
  if custom and step.questId then
   -- yapılmış ya da elle atlanmış adım aday değil
   finished = FT.IsStepDone(step, FT.QuestState(step.questId, step.objectiveIndex)) or
    (ForeverTrailCharacter and ForeverTrailCharacter.skipped and ForeverTrailCharacter.skipped[tostring(FT.guide.guideId) .. ':' .. tostring(step.stepId)]) and true or false
  end
  if step.questId and not finished then
   FT.EnsureWaypoint(step, true)
   if step.uiMapID == map and step.x and step.y then
    local measured, yards = pcall(FT.DistanceYards, step, px, py)
    if measured and yards and (not bestDistance or yards < bestDistance) then best, bestDistance = index, yards end
   end
  end
 end
 if not best then return notify('Bu bölgede konumu bilinen görev adımı yok.') end
 FT.active, FT.view, FT.complete, FT.notice = best, best, false, nil
 FT.SaveStep()
 FT.Refresh()
 FT.OpenMap()
end

function FT.BuildRoute()
 for index, guide in ipairs(FT.validGuides) do
  if guide.live then FT.SelectGuide(index); break end
 end
 local live = FT.guide
 local function notify(text) FT.notice = text; FT.Refresh() end
 local order, groups = {}, {}
 for _, step in ipairs(live.steps) do
  if step.questId then
   if not groups[step.questId] then groups[step.questId] = {}; order[#order+1] = step.questId end
   local list = groups[step.questId]
   list[#list+1] = step
  end
 end
 if #order == 0 then return notify('Günlükte rota için görev yok.') end
 local map, px, py
 if C_Map and C_Map.GetBestMapForUnit then
  local ok, value = pcall(C_Map.GetBestMapForUnit, 'player')
  if ok then map = value end
  if map and FT.PlayerPosition then
   local good, x, y = pcall(FT.PlayerPosition, map)
   if good then px, py = x, y end
  end
 end
 local known, unknown = {}, {}
 for _, questId in ipairs(order) do
  local anchor
  for _, step in ipairs(groups[questId]) do
   FT.EnsureWaypoint(step, true)
   if not anchor and map and step.uiMapID == map and step.x and step.y then anchor = step end
  end
  if anchor then known[#known+1] = {questId=questId, anchor=anchor} else unknown[#unknown+1] = questId end
 end
 local route, cx, cy = {}, px, py
 local total = 0
 local function take(questId)
  for _, step in ipairs(groups[questId]) do
   local copy = {}
   for key, value in pairs(step) do copy[key] = value end
   route[#route+1] = copy
  end
 end
 while #known > 0 do
  local bestIndex, bestDistance = 1, nil
  if cx and cy then
   for i, entry in ipairs(known) do
    local ok, yards = pcall(FT.DistanceYards, entry.anchor, cx, cy)
    if ok and yards and (not bestDistance or yards < bestDistance) then bestIndex, bestDistance = i, yards end
   end
  end
  if bestDistance then total = total + bestDistance end
  local entry = table.remove(known, bestIndex)
  take(entry.questId)
  cx, cy = entry.anchor.x, entry.anchor.y
  -- aynı hedefi isteyen görevleri hemen arkasına diz
  local grouped = true
  while grouped and FT.SharesTarget do
   grouped = false
   for i, other in ipairs(known) do
    if FT.SharesTarget(entry.questId, other.questId) then
     table.remove(known, i)
     take(other.questId)
     cx, cy = other.anchor.x, other.anchor.y
     entry = other
     grouped = true
     break
    end
   end
  end
 end
 for _, questId in ipairs(unknown) do take(questId) end
 local guide = {guideId='auto-route', version=1, title='Otomatik rota', zone='Günlük', steps=route}
 local valid, reason = FT.ValidateGuide(guide)
 if not valid then return notify('Rota oluşturulamadı: ' .. tostring(reason)) end
 FT.guide = guide
 FT.active, FT.view, FT.complete = 1, 1, false
 FT.notice = ('Rota oluşturuldu: %d görev, en yakından başlıyor.'):format(#order)
 if total > 0 and FT.FormatETA then FT.notice = FT.notice .. (' Tahmini yol: ~%d yd (%s).'):format(total, FT.FormatETA(total / 7)) end
 FT.SaveStep()
 FT.Evaluate()
 FT.OpenMap()
end

function FT.UpdateJournal()
 local old = journal.steps
 local active = old[FT.active]
 local view = old[FT.view]
 local saved = ForeverTrailCharacter.journalStep
 local ok, steps = pcall(readSteps)
 if not ok then
  FT.journalError = tostring(steps)
  if not active or not active.questId then
   journal.steps={placeholder("Görev günlüğü henüz okunamıyor.")}
   FT.active, FT.view = 1, 1
  end
  return
 end
 FT.journalError = nil
 if #steps==0 then steps[1]=placeholder("Günlüğünde aktif görev yok. Bir görev aldığında burada görünecek.") end
 local activeKey = active and active.questId and active.stepId or saved
 local quest = activeKey and tonumber(activeKey:match("^(%d+):"))
 local nextIndex, sameQuest, review
 for i,step in ipairs(steps) do
  if step.stepId==activeKey then nextIndex=i end
  if quest and step.questId==quest and not sameQuest then sameQuest=i end
  if view and view~=active and step.stepId==view.stepId then review=i end
 end
 journal.steps=steps
 FT.active=nextIndex or sameQuest or 1
 FT.view=review or FT.active
 FT.complete=false
 FT.SaveStep()
end
