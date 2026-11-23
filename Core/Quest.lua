local _, FT = ...
FT.turnedIn = {}
local function call(fn, ...) if not fn then return nil end local ok, result = pcall(fn, ...); if ok then return result end end
function FT.QuestState(id, objectiveIndex)
 if not id then return {status='unknown'} end
 local q = C_QuestLog
 if FT.turnedIn[id] or (q and call(q.IsQuestFlaggedCompleted, id) == true) then return {status='turned_in'} end
 if not (q and q.GetLogIndexForQuestID) then return {status='unknown'} end
 local ok, idx = pcall(q.GetLogIndexForQuestID,id)
 if not ok then return {status='unknown'} end
 if not idx or idx == 0 then return {status='not_taken'} end
 local state = {status='active'}
 if q.IsComplete and call(q.IsComplete,id) == true then state.status='ready' end
 if objectiveIndex and q.GetQuestObjectives then
  local objectives = call(q.GetQuestObjectives,id)
  if type(objectives)=='table' then
   local row = objectives[objectiveIndex]
   if type(row)=='table' then
    local complete = row.finished
    if complete == nil and type(row.numFulfilled)=='number' and type(row.numRequired)=='number' and row.numRequired > 0 then complete = row.numFulfilled >= row.numRequired end
    state.objective = {finished=complete == true, text=row.text, have=row.numFulfilled, need=row.numRequired, kind=row.type}
   end
  end
 end
 return state
end
