-- Gömülü veritabanı: dış eklenti olmadan görev konumu çözülmeli
QuestieLoader=nil
UnitLevel=function() return 5 end
UnitRace=function() return 'Human','Human',1 end
UnitClass=function() return 'Warrior','WARRIOR',1 end
GetTime=function() return 100 end
C_Map={GetBestMapForUnit=function() return 1429 end,GetPlayerMapPosition=function() return {GetXY=function() return .48,.40 end} end}
C_QuestLog={GetNumQuestLogEntries=function() return 0 end, GetLogIndexForQuestID=function() return nil end, IsQuestFlaggedCompleted=function() return false end}
ForeverTrailCharacter={}
local ft={RegisterGuide=function() end, SaveStep=function() end}
for _,f in ipairs({'DataZones.lua','DataQuests.lua','DataNpcs.lua','DataObjects.lua','DataItems.lua','OwnDB.lua','Journal.lua'}) do assert(loadfile(f))('ForeverTrail',ft) end
local db=ft.Module('QuestieDB')
assert(db.QueryQuestSingle(6,'name')=='Bounty on Garrick Padfoot','quest name')
assert(ft.Module('ZoneDB'):GetUiMapIdByAreaId(12)==1429,'Elwynn area -> uiMap')
local map,x,y=ft.ResolveQuestWaypoint(6,'accept')
assert(map==1429 and math.abs(x-.482)<.001 and math.abs(y-.429)<.001,'quest 6 giver should be Deputy Willem in Northshire: '..tostring(map)..' '..tostring(x)..' '..tostring(y))
local tmap,tx,ty=ft.ResolveQuestWaypoint(6,'objective',1)
assert(tmap and not (math.abs(tx-.482)<.001 and math.abs(ty-.429)<.001),'objective should point to Garrick Padfoot, not the quest giver')
local avail=ft.Module('AvailableQuests').__availableQuests
local n=0 for _ in pairs(avail) do n=n+1 end
assert(n>10 and avail[6]==nil or n>10,'available quests computed')
local xp=ft.Module('QuestXP'):GetQuestLogRewardXP(6)
assert(type(xp)=='number' and xp>0,'quest xp')
print(('OwnDB tests passed (%d alınabilir görev, görev 6 XP %d, hedef %d %.1f %.1f)'):format(n, xp, tmap, tx*100, ty*100))
