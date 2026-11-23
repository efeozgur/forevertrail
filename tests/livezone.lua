-- ZoneDB/QuestXP: Questie varsa önce o, yanıt yoksa gömülü veri; ön bellekler eşitleme sonrası sıfırlanır
UnitLevel=function() return 5 end
UnitRace=function() return 'Human','Human',1 end
UnitClass=function() return 'Warrior','WARRIOR',1 end
GetTime=function() return 100 end
C_QuestLog={GetNumQuestLogEntries=function() return 0 end}
ForeverTrailCharacter={}
local ft={RegisterGuide=function() end}
for _,f in ipairs({'Data/DataZones.lua','Data/DataQuests.lua','Data/DataNpcs.lua','Data/DataObjects.lua','Data/DataItems.lua','Data/OwnDB.lua'}) do assert(loadfile(f))('ForeverTrail',ft) end
local z=ft.Module('ZoneDB')
local embedded=z:GetUiMapIdByAreaId(12); assert(embedded==1429)
-- Questie yok: gömülü
QuestieLoader=nil; assert(z:GetUiMapIdByAreaId(12)==1429)
-- Questie var ama henüz başlamamış (hata verir): gömülüye düşer
local broken={GetUiMapIdByAreaId=function() error('not initialized') end}
QuestieLoader={ImportModule=function(_,n) if n=='ZoneDB' then return broken end return {} end}
assert(z:GetUiMapIdByAreaId(12)==1429,'fallback on error')
-- Questie yanıt verir
local live={GetUiMapIdByAreaId=function(_,a) if a==12 then return 4242 end end}
QuestieLoader.ImportModule=function(_,n) if n=='ZoneDB' then return live end if n=='QuestXP' then return {db={[6]={5,100}},GetQuestLogRewardXP=function() return 777 end} end end
assert(z:GetUiMapIdByAreaId(12)==4242,'live wins')
assert(z:GetUiMapIdByAreaId(9999999)==nil)
assert(ft.Module('QuestXP'):GetQuestLogRewardXP(6)==777,'live xp')
ForeverTrailSettings={noLive=true}
assert(z:GetUiMapIdByAreaId(12)==1429,'noLive')
assert(ft.Module('QuestXP'):GetQuestLogRewardXP(6)~=777)
-- Ön bellek sıfırlama
local called=0; ft.liveListeners[#ft.liveListeners+1]=function() called=called+1 end
for _,fn in ipairs(ft.liveListeners) do fn() end
assert(called==1 and #ft.liveListeners>=1)
print('Live zone/xp tests passed')
