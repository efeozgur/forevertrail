local modules={
 QuestieDB={GetQuest=function() return {Starts={NPC={42}}} end,
  QueryNPCSingle=function() return {[1]={{10,20}},[2]={{70,80}}} end},
 ZoneDB={GetUiMapIdByAreaId=function(_,id) return id+9 end},
}
QuestieLoader={ImportModule=function(_,name) return modules[name] end}
C_Map={GetBestMapForUnit=function() return 11 end,GetPlayerMapPosition=function() return {GetXY=function() return .68,.79 end} end}
C_QuestLog={GetNumQuestLogEntries=function() return 0 end}
ForeverTrailCharacter={}
local ft={RegisterGuide=function() end, SaveStep=function() end}
assert(loadfile('Journal.lua'))('ForeverTrail',ft)
ft.UpdateJournal()
local map,x,y=ft.ResolveQuestWaypoint(100,'accept')
assert(map==11 and x==.7 and y==.8, 'should prefer a spawn in the player zone')
print('Quest waypoint selection passed')
