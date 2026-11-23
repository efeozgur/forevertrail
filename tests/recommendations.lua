local modules = {
 AvailableQuests={__availableQuests={[2]=true,[3]=true,[4]=true}},
 QuestXP={db={[1]={10,100},[2]={10,200},[3]={20,300}},GetQuestLogRewardXP=function(_,id) return ({[1]=100,[2]=200,[3]=300})[id] or 0 end},
 QuestieDB={QueryQuestSingle=function(id,key)
  local rows={[2]={name='Available',questLevel=10,requiredLevel=8},[3]={name='Too hard',questLevel=20,requiredLevel=20},[4]={name='Unknown XP',questLevel=10,requiredLevel=8}}
  return rows[id] and rows[id][key]
 end},
}
QuestieLoader={ImportModule=function(_,name) return modules[name] end}
UnitLevel=function() return 10 end
C_QuestLog={GetNumQuestLogEntries=function() return 1 end, GetInfo=function() return {questID=1,title='Active',level=10} end, IsComplete=function() return false end}
local ft={}
assert(loadfile('Recommendations.lua'))('ForeverTrail',ft)
local rows=ft.GetRecommendations()
assert(#rows==3 and rows[1].id==2 and rows[2].id==1 and rows[3].id==4, 'filtering or XP order incorrect')
assert(rows[1].xp==200 and rows[2].active and rows[3].xp==nil, 'incorrect details')
C_Map={GetBestMapForUnit=function() return 10 end}
modules.QuestieMap={GetFramesForQuest=function(_,id)
 if id==1 then return {{UiMapID=10,x=25,y=50}} end
 if id==2 then return {{UiMapID=10,x=40,y=60}} end
 return {{UiMapID=11,x=30,y=40}}
end}
local nearby, locationReady=ft.GetNearbyRecommendations(rows)
assert(locationReady and #nearby==2 and nearby[1].id==2 and nearby[2].id==1, 'nearby must include active and available quests in current zone only')
C_Map.GetBestMapForUnit=function() return nil end
local unknown, known=ft.GetNearbyRecommendations(rows)
assert(not known and #unknown==0, 'unknown player map must not show guesses')
modules.AvailableQuests=nil
rows=ft.GetRecommendations()
assert(#rows==1 and rows[1].id==1, 'journal must work without Questie availability')
modules.AvailableQuests={}
local _, available=ft.GetRecommendations()
assert(not available, 'an uninitialized Questie module must not be reported as ready')
modules.AvailableQuests=nil
UnitLevel=function() return 30 end
rows=ft.GetRecommendations()
assert(#rows==1 and rows[1].id==1 and rows[1].active, 'active quests must ignore the level filter')
print('Recommendation tests passed')
