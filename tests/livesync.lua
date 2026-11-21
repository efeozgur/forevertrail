-- LiveSync: QuestieDB varsa gömülü satırlar güncellenir, yoksa/yedekte gömülü veri korunur
local frameScript
CreateFrame=function() local f={} f.RegisterEvent=function() end f.SetScript=function(self,k,fn) if k=='OnUpdate' then frameScript=fn end end return f end
local ft={Print=function() end}
ForeverTrailSettings={}
ft.DBQ={[6]={'Eski ad',{{1}},nil,5},[999999]={'Kendi görevim',{{2}},nil,1}}
ft.DBN={}; ft.DBO={}; ft.DBI={}
assert(loadfile('LiveSync.lua'))('ForeverTrail',ft)
-- QuestieDB yok
ft.StartLiveSync(); assert(ft.live.state=='absent')
-- Sahte QuestieDB
local function entity(rows) local ids={} for id in pairs(rows) do ids[#ids+1]=id end table.sort(ids)
 return {GetAllIds=function() return ids end, Get=function(id,k) return rows[id] and rows[id][k] end} end
LibQuestieDB={contractVersion=4, RequireContract=function(v) return v==4 end,
 Quest=entity({[6]={name='Yeni ad',startedBy={{1}},requiredLevel=7,objectivesText={'a','b'}}}),
 Npc=entity({[1]={name='NPC',spawns={[12]={{44.55,77.5}}},minLevel=3}}),
 Object=entity({}), Item=entity({[5]={name='Eşya',questRewards={1}}})}
ft.StartLiveSync(); assert(ft.live.state=='running')
for _=1,10 do if frameScript then frameScript({SetScript=function() frameScript=nil end}) end end
assert(ft.live.state=='done',ft.live.state)
assert(ft.DBQ[6][1]=='Yeni ad' and ft.DBQ[6][4]==7 and ft.DBQ[6][8]=='a b','quest overwritten')
assert(ft.DBQ[999999][1]=='Kendi görevim','own addition kept')
assert(ft.DBN[1][5][12][1]==446 and ft.DBN[1][5][12][2]==775,'spawns x10 flat')
assert(ft.DBI[5][1]=='Eşya')
print('LiveSync tests passed')
