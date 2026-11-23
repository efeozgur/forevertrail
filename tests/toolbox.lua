CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
UnitClass=function() return 'Warrior','WARRIOR',1 end UnitLevel=function() return 10 end
C_Map={GetBestMapForUnit=function() return 1429 end, GetPlayerMapPosition=function() return {GetXY=function() return .48,.42 end} end,
 GetMapInfo=function(m) if m==1415 then return {mapType=2} end return {mapType=3,parentMapID=1415} end}
ForeverTrailSettings={} ForeverTrailCharacter={}
local ft={Print=function() end, MapName=function(m) return 'Elwynn' end}
local target ft.SetCustomTarget=function(m,x,y,n) target={m,x,y,n} end
local choice ft.ShowChoice=function(t,i,text,a,fn) choice=text; fn(); return true end
for _,f in ipairs({'Data/DataZones.lua','Data/DataNpcs.lua','Data/DataNewQuests.lua','Data/OwnDB.lua','UI/Toolbox.lua'}) do assert(loadfile(f))('ForeverTrail',ft) end
ft.DBQ={[1]={}}
assert(ft.IsNewQuest(99050) and not ft.IsNewQuest(6),'new quest detection')
local t=ft.ClassTrainer()
assert(t and t.map==1429,'warrior trainer in Elwynn')
ForeverTrailCharacter.trainer={{name='Rend',level=10,cost=900},{name='Thunder Clap',level=12,cost=1000}}
ft.TrainerCheck(10)
assert(choice and choice:find('1 yeni'),'one spell available at 10')
local plan=ft.RoutePlan({uiMapID=1429,x=.3,y=.6,questTitle='Test'})
assert(#plan>=1 and plan[#plan]:find('Test'),'route plan')
local n=0 for _ in pairs(ft.DBNewQuests) do n=n+1 end
print(('Toolbox tests passed (Forever-yeni görev: %d; sınıf eğitmeni: %s %.1f %.1f; plan: %s)'):format(n, t.name, t.x*100, t.y*100, plan[#plan]))
