QuestieLoader=nil
local level=5
UnitLevel=function() return level end
UnitRace=function() return 'Human','Human',1 end
UnitClass=function() return 'Warrior','WARRIOR',1 end
local now=100 GetTime=function() return now end
C_Map={GetBestMapForUnit=function() return 1429 end,GetPlayerMapPosition=function() return {GetXY=function() return .48,.42 end} end,GetMapWorldSize=function() return 3470,2315 end}
C_QuestLog={GetNumQuestLogEntries=function() return 0 end, GetLogIndexForQuestID=function() return nil end, IsQuestFlaggedCompleted=function() return false end}
ForeverTrailSettings={} ForeverTrailCharacter={}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
local ft={RegisterGuide=function() end, SaveStep=function() end, MapName=function(m) return 'Harita '..m end}
local target
ft.SetCustomTarget=function(m,x,y,n) target={m,x,y,n} end
ft.Print=function() end
for _,f in ipairs({'Data/DataZones.lua','Data/DataQuests.lua','Data/DataNpcs.lua','Data/DataObjects.lua','Data/DataItems.lua','Data/OwnDB.lua','Guide/Journal.lua','Map/Discovery.lua'}) do assert(loadfile(f))('ForeverTrail',ft) end
local t0=os.clock()
local marks=ft.QuestMarks(1429)
local n=0 for _,m in ipairs(marks) do if m.kind=='!' then n=n+1 end end
assert(n>5,'Elwynn should have quest givers: '..n)
ft.SuggestNext()
assert(target and target[1]==1429,'next quest target')
assert(#ft.QuestFollowers(6)>=0)
level=60; now=200
local t1=os.clock()
local m60=ft.QuestMarks(1429)
print(('Discovery tests passed (Elwynn: %d ! işareti, ilk tarama %.2f sn, sv60 tarama %.2f sn, öneri: %s)'):format(n, t1-t0, os.clock()-t1, tostring(target[4])))
