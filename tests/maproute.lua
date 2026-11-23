UnitFactionGroup=function() return 'Alliance' end
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
ForeverTrailSettings={}
local ft={}
for _,f in ipairs({'Data/DataZones.lua','Data/DataNpcs.lua','Data/OwnDB.lua','Map/MapRoute.lua'}) do assert(loadfile(f))('ForeverTrail',ft) end
ft.DBQ=ft.DBQ or {[1]={}}
local list=ft.MapServices(1429)
local cats={}
for _,e in ipairs(list) do cats[e.cat]=(cats[e.cat] or 0)+1 end
local inn
for _,e in ipairs(list) do if e.cat=='inn' then inn=e end end
assert(#list>10,'Elwynn services: '..#list)
assert(inn and inn.x>0 and inn.x<1,'innkeeper found with valid coords')
print(('MapRoute tests passed (Elwynn: %d hizmet NPC; han: %s %.1f, %.1f; tamir %d, satıcı %d, eğitmen %d)'):format(#list, inn.name, inn.x*100, inn.y*100, cats.repair or 0, cats.vendor or 0, cats.trainer or 0))
