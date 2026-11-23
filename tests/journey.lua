QuestieLoader=nil
UnitLevel=function() return 18 end
UnitRace=function() return 'Human','Human',1 end
UnitClass=function() return 'Warrior','WARRIOR',1 end
local faction='Alliance' UnitFactionGroup=function() return faction end
GetTime=function() return 100 end time=os.time date=os.date
strsplit=function(sep,s) local out={} for part in (s..sep):gmatch('(.-)'..sep) do out[#out+1]=part end return unpack(out) end
local map,px,py=1436,0.425,0.70
C_Map={GetBestMapForUnit=function() return map end, GetPlayerMapPosition=function() return {GetXY=function() return px,py end} end,
 GetMapInfo=function(m) local cont={[1436]=1415,[1429]=1415,[1411]=1414,[1454]=1414} if m==1414 or m==1415 then return {mapType=2} end return {mapType=3,parentMapID=cont[m]} end}
local quests={{questID=6,title='Bounty on Garrick Padfoot'}}
C_QuestLog={GetNumQuestLogEntries=function() return #quests end, GetInfo=function(i) return quests[i] end,
 GetQuestObjectives=function() return {{text="Garrick's Head: 0/1",numFulfilled=0,numRequired=1,finished=false}} end,
 GetLogIndexForQuestID=function(id) return id==6 and 1 or nil end, IsQuestFlaggedCompleted=function() return false end}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
GetItemInfo=function() return nil end GetNumSkillLines=function() return 0 end
ForeverTrailSettings={} ForeverTrailCharacter={}
local ft={RegisterGuide=function() end, MapName=function(m) return 'Harita'..m end}
local target ft.SetCustomTarget=function(m,x,y,n) target={m,x,y,n} end
local info ft.InfoWindow=function(t,l) info={t,l} end
for _,f in ipairs({'Data/DataZones.lua','Data/DataQuests.lua','Data/DataNpcs.lua','Data/DataObjects.lua','Data/DataItems.lua','Data/DataStations.lua','Data/DataDungeons.lua','Data/OwnDB.lua','Map/Discovery.lua','Map/Objectives.lua','Guide/Journey.lua'}) do assert(loadfile(f))('ForeverTrail',ft) end
-- 1) eşya ipucu: Garrick's Head (182)
local lines={}
local tip={GetItem=function() return "Garrick's Head",'item:182:0' end, AddLine=function(_,t) lines[#lines+1]=t end, Show=function() end}
-- itemLines is local; drive through objectives directly
local objs=ft.ActiveObjectives()
assert(objs[1].itemId==182,'objective item id')
-- 8) zindan rehberi: Westfall, Deadmines girişi yanında
ft.ShowDungeonGuide()
for _,l in ipairs(info[2]) do print('  rehber>',l) end
assert(info and info[2][1]:find('Deadmines'),'dungeon should be Deadmines: '..tostring(info and info[2][1]))
local text=table.concat(info[2],'\n')
assert(text:find('VanCleef'),'VanCleef should be listed as quest boss')
assert(target and target[4]:find('Deadmines'),'arrow to entrance')
-- 7) ekipman bulucu: ödül indeksi
local idx=0 for q in pairs(ft.DBQ) do if #ft.QuestRewards(q)>0 then idx=idx+1 end end
assert(idx>1000,'reward index: '..idx)
ft.ShowGearFinder()
assert(info[1]=='Ekipman bulucu')
-- 2) silah ustaları (Alliance)
ft.ShowWeaponMasters()
assert(#info[2]>=4,'weapon masters listed')
-- 6) yolculuk: Horde, Durotar'dan Doğu Krallıklar'a
faction='Horde'; map=1411; px,py=0.5,0.13
local goal,hint=ft.TravelHint(1411,{uiMapID=1429,x=0.5,y=0.5})
assert((goal and goal.hint:find('Zeplin')) or hint,'travel hint')
-- 5) geçmiş
ft.ShowJourney()
assert(info[1]=='Görev geçmişi')
print(('Journey tests passed (zindan: %s; ödüllü görev: %d; yolculuk: %s)'):format(info and 'ok', idx, goal and goal.hint or hint))
