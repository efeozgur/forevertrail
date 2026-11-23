local _, FT = ...

local function module(name)
 if FT.Module then local own = FT.Module(name) if own then return own end end
 if not (QuestieLoader and QuestieLoader.ImportModule) then return nil end
 local ok, result = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
 if ok then return result end
end

function FT.GetRecommendations()
 local available, xpDB, db = module('AvailableQuests'), module('QuestXP'), module('QuestieDB')
 local level = UnitLevel('player')
 local rows, seen = {}, {}
 local function query(id, key)
  if not (db and db.QueryQuestSingle) then return nil end
  local ok, value = pcall(db.QueryQuestSingle, id, key)
  if ok then return value end
 end
 local function add(id, title, questLevel, active, ready)
  if seen[id] then return end
  questLevel = questLevel or query(id, 'questLevel')
  local required = query(id, 'requiredLevel')
  if not active then
   if type(required)=='number' and required>level then return end
   if type(questLevel)=='number' and questLevel>0 and (questLevel>level+3 or (questLevel<level-5 and ForeverTrailSettings and ForeverTrailSettings.showLow == false)) then return end
  end
  local xp
  if xpDB and xpDB.db and xpDB.db[id] and xpDB.GetQuestLogRewardXP then
   local ok, value = pcall(xpDB.GetQuestLogRewardXP, xpDB, id, false)
   if ok and type(value)=='number' then xp=value end
  end
  local translation = QTR_QuestData and QTR_QuestData[tostring(id)]
  local t=(translation and translation.Title) or title or query(id,'name') or ('Görev '..id)
  if FT.IsNewQuest and FT.IsNewQuest(id) then t='|cff6fd8ff[Yeni]|r '..t end
  rows[#rows+1]={id=id, title=t, level=questLevel, xp=xp, active=active, ready=ready}
  seen[id]=true
 end
 local q=C_QuestLog
 if q and q.GetNumQuestLogEntries and q.GetInfo then
  for i=1,q.GetNumQuestLogEntries() do
   local info=q.GetInfo(i)
   if info and not info.isHeader and not info.isHidden and info.questID and info.questID>0 then
    add(info.questID, info.title, info.level, true, q.IsComplete and q.IsComplete(info.questID))
   end
  end
 end
 if available and type(available.__availableQuests)=='table' then
  for id, yes in pairs(available.__availableQuests) do
   if yes and type(id)=='number' then add(id, nil, nil, false, false) end
  end
 end
 if FT.OwnAvailable then
  for id, r in pairs(FT.OwnAvailable()) do
   if not seen[id] then
    local lvl = r.l
    if not (type(lvl)=='number' and (lvl>level+3 or (lvl<level-5 and ForeverTrailSettings and ForeverTrailSettings.showLow == false))) then
     rows[#rows+1]={id=id, title=r.t or ('Görev '..id), level=lvl, active=false, ready=false}
     seen[id]=true
    end
   end
  end
 end
 table.sort(rows,function(a,b)
  if (a.xp~=nil) ~= (b.xp~=nil) then return a.xp~=nil end
  if a.xp~=b.xp then return (a.xp or 0)>(b.xp or 0) end
  return a.id<b.id
 end)
 return rows, (available ~= nil and type(available.__availableQuests)=='table') or (FT.OwnAvailable ~= nil)
end

function FT.GetNearbyRecommendations(rows)
 local map = C_Map and C_Map.GetBestMapForUnit
 local ok, mapID = false, nil
 if map then ok, mapID=pcall(map,'player') end
 local questieMap=module('QuestieMap')
 if not ok or not mapID or not questieMap or type(questieMap.GetFramesForQuest)~='function' then return {},false end
 local nearby={}
 for _,row in ipairs(rows) do
  local success, frames=pcall(questieMap.GetFramesForQuest,questieMap,row.id)
  if success and type(frames)=='table' then
   for _,frame in pairs(frames) do
    if frame and frame.UiMapID==mapID and type(frame.x)=='number' and type(frame.y)=='number' then
     nearby[#nearby+1]=row
     break
    end
   end
  end
 end
 return nearby,true
end

function FT.GetQuestChain()
 local id=ForeverTrailCharacter and ForeverTrailCharacter.lastAcceptedQuest
 if not id then
  local journey=Questie and Questie.db and Questie.db.char and Questie.db.char.journey
  if type(journey)=='table' then
   for i=#journey,1,-1 do
    local entry=journey[i]
    if entry.Event=='Quest' and entry.SubType=='Accept' and type(entry.Quest)=='number' and entry.Quest>0 then id=entry.Quest; break end
   end
  end
 end
 if not id then return {},'noquest' end
 local db,available=module('QuestieDB'),module('AvailableQuests')
 if not db or type(db.QueryQuestSingle)~='function' then return {},'unavailable' end
 local function query(q,key)
  local ok,value=pcall(db.QueryQuestSingle,q,key)
  if ok then return value end
 end
 local ordered,seen={},{}
 local function previous(q,depth)
  if depth>64 or seen[q] or #ordered>=100 then return end
  seen[q]=true
  for _,key in ipairs({'preQuestSingle','preQuestGroup'}) do
   local list=query(q,key)
   if type(list)=='table' then for _,p in ipairs(list) do if type(p)=='number' and p>0 then previous(p,depth+1) end end end
  end
  ordered[#ordered+1]=q
 end
 previous(id,0)
 local index=1
 while index<=#ordered and #ordered<100 do
  local q=ordered[index]
  local nextID=query(q,'nextQuestInChain')
  if type(nextID)=='number' and nextID>0 and not seen[nextID] then seen[nextID]=true; ordered[#ordered+1]=nextID end
  if FT.QuestFollowers then
   for _,f in ipairs(FT.QuestFollowers(q)) do
    if #ordered>=100 then break end
    if not seen[f] then seen[f]=true; ordered[#ordered+1]=f end
   end
  end
  local children=query(q,'childQuests')
  if type(children)=='table' then
   for _,child in ipairs(children) do
    if #ordered>=100 then break end
    if type(child)=='number' and child>0 and not seen[child] then seen[child]=true; ordered[#ordered+1]=child end
   end
  end
  index=index+1
 end
 local rows={}
 for _,q in ipairs(ordered) do
  local completed,active=false,false
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then local ok,v=pcall(C_QuestLog.IsQuestFlaggedCompleted,q); completed=ok and v==true end
  if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then local ok,v=pcall(C_QuestLog.GetLogIndexForQuestID,q); active=ok and type(v)=='number' and v>0 end
  local canTake=available and type(available.__availableQuests)=='table' and available.__availableQuests[q]
  local translation=QTR_QuestData and QTR_QuestData[tostring(q)]
  rows[#rows+1]={id=q,title=(translation and translation.Title) or query(q,'name') or ('Görev '..q),level=query(q,'questLevel'),active=active,zone=FT.QuestGiverZone and FT.QuestGiverZone(q),chainCurrent=q==id,chainStatus=completed and 'Tamamlandı' or (active and 'Günlükte' or (canTake and 'Alınabilir' or 'Kilitli'))}
 end
 return rows,'ok'
end
