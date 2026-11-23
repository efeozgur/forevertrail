CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
UnitLevel=function() return 10 end UnitRace=function() return 'Human','Human',1 end UnitClass=function() return 'Warrior','WARRIOR',1 end
local xp=100 UnitXP=function() return xp end UnitXPMax=function() return 1000 end
local now=0 GetTime=function() return now end
C_QuestLog={GetLogIndexForQuestID=function() return nil end, IsQuestFlaggedCompleted=function() return false end}
ForeverTrailSettings={} ForeverTrailCharacter={}
local ft={Print=function() end}
for _,f in ipairs({'Data/DataZones.lua','Data/DataQuests.lua','Data/DataNpcs.lua','Data/DataItems.lua','Data/OwnDB.lua','Map/Atlas.lua'}) do assert(loadfile(f))('ForeverTrail',ft) end
-- ön koşul: Elwynn'de ön koşulu olan bir görev
local pick
for id,q in pairs(ft.DBQ) do if type(q[11])=='table' and q[11][1] and (q[4] or 1)<=10 and q[13]==12 then pick=id break end end
local status, need = ft.QuestStatus(pick)
assert(need and status:find('Önce'),'prerequisite should be found for '..pick..': '..tostring(status))
-- yaratığın düşürdüğü eşyalar: Garrick Padfoot (103) -> Garrick's Head (182)
local drops=ft.DropsOf(103)
local has=false for _,i in ipairs(drops or {}) do if i==182 then has=true end end
assert(has,'Garrick Padfoot drops Garrick\'s Head')
-- seviyeye kalan yaratık
for _,e in ipairs({'PLAYER_ENTERING_WORLD'}) do end
local f=ft -- olayları doğrudan tetikle
-- harita modu
ForeverTrailSettings.c_mapMode='off'; assert(not ft.ShowObjectiveOnMap(6),'off mode hides')
ForeverTrailSettings.c_mapMode='all'; assert(ft.ShowObjectiveOnMap(6),'all mode shows')
print(('Atlas tests passed (görev %d [%s]: %s; ön koşul %d [%s])'):format(pick, ft.DBQ[pick][1], status:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''), need, ft.DBQ[need][1]))
