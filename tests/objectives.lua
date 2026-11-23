QuestieLoader=nil
UnitLevel=function() return 5 end
UnitRace=function() return 'Human','Human',1 end
UnitClass=function() return 'Warrior','WARRIOR',1 end
GetTime=function() return 100 end
strsplit=function(sep,s) local out={} for part in (s..sep):gmatch('(.-)'..sep) do out[#out+1]=part end return unpack(out) end
local quests={{questID=6,title='Bounty on Garrick Padfoot',level=5},{questID=7,title='Kobold Camp Cleanup',level=4}}
C_QuestLog={GetNumQuestLogEntries=function() return #quests end, GetInfo=function(i) return quests[i] end,
 GetQuestObjectives=function(id)
  if id==6 then return {{text="Garrick's Head: 0/1",numFulfilled=0,numRequired=1,finished=false,type='item'}} end
  return {{text='Kobold Vermin slain: 3/10',numFulfilled=3,numRequired=10,finished=false,type='monster'}}
 end,
 GetLogIndexForQuestID=function() return nil end, IsQuestFlaggedCompleted=function() return false end}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
UnitExists=function() return true end UnitIsPlayer=function() return false end UnitIsDead=function() return false end
local guid='Creature-0-0-0-0-103-0000'
UnitGUID=function() return guid end
ForeverTrailSettings={} ForeverTrailCharacter={}
local ft={RegisterGuide=function() end, SaveStep=function() end}
for _,f in ipairs({'DataZones.lua','DataQuests.lua','DataNpcs.lua','DataObjects.lua','DataItems.lua','OwnDB.lua','Objectives.lua'}) do assert(loadfile(f))('ForeverTrail',ft) end
local objs=ft.ActiveObjectives()
assert(#objs==2,'two objectives: '..#objs)
assert(objs[1].kind=='loot' and objs[2].kind=='kill','kinds: '..objs[1].kind..' '..objs[2].kind)
local o=ft.QuestCreatureInfo('target')
assert(o and o.questId==6 and o.kind=='loot','Garrick Padfoot (103) should match quest 6 loot objective')
guid='Creature-0-0-0-0-6-0000'
local k=ft.QuestCreatureInfo('target')
assert(k and k.questId==7 and k.have==3 and k.need==10,'Kobold Vermin (6) should match quest 7')
local areas=ft.ObjectiveAreas(1429)
local cells,hulls=0,0
for _,a in ipairs(areas) do for _,g in ipairs(a.groups) do cells=cells+#g.cells; if #g.hull>=3 then hulls=hulls+1 end end end
assert(#areas==2 and cells>0,'areas drawn')
print(('Objectives tests passed (%d bölge, %d küme, %d sınır çizgisi, kobold %d/%d)'):format(#areas,cells,hulls,k.have,k.need))
