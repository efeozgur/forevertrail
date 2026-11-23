-- Görev ayrıntıları: XP (kesin/tahmini) ve ipucu satırları gömülü veriyle çalışmalı
UnitLevel=function() return 20 end
UnitXPMax=function() return 10000 end
ForeverTrailSettings={}
local ft={}
for _,f in ipairs({'DataZones.lua','DataQuests.lua','DataNpcs.lua','DataObjects.lua','DataItems.lua','DataNewQuests.lua','DataXP.lua','OwnDB.lua','QuestInfo.lua'}) do assert(loadfile(f))('ForeverTrail',ft) end
ft.QuestTitle=function(id) local q=ft.DBQ[id]; return q and q[1] or ('Görev '..id) end
ft.IsNewQuest=function(id) return ft.DBNewQuests[id]==true end
ft.DiffColor=function() return 1,1,1 end
-- XP kapsamı
local exact,est,none=0,0,0
for id in pairs(ft.DBQ) do
 local xp,estimated=ft.QuestXPInfo(id)
 if not xp then none=none+1 elseif estimated then est=est+1 else exact=exact+1 end
end
local newExact,newEst=0,0
for id in pairs(ft.DBNewQuests) do local xp,e=ft.QuestXPInfo(id); if xp then if e then newEst=newEst+1 else newExact=newExact+1 end end end
assert(exact>3000,'exact xp: '..exact)
assert(newExact+newEst>1700,'new quests covered: '..(newExact+newEst))
-- İpucu satırları
local lines={}
local tip={SetText=function(_,t) lines[#lines+1]=t end, AddLine=function(_,t) lines[#lines+1]=t end}
local newId; for id in pairs(ft.DBNewQuests) do if ft.DBQ[id] and ft.DBQ[id][8] then newId=id break end end
ft.QuestInfoTip(tip,newId,{level=30,giver='Test NPC',map=1429,x=.5,y=.5},123.4)
local joined=table.concat(lines,'\n')
assert(joined:find('Forever',1,true) and joined:find('XP',1,true) and joined:find('Test NPC',1,true),joined)
print(('QuestInfo tests passed — kesin XP %d, tahmini %d, veri yok %d; yeni görevler: kesin %d, tahmini %d'):format(exact,est,none,newExact,newEst))
print(joined)
