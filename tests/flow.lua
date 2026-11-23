CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
ForeverTrailSettings={} ForeverTrailCharacter={}
local ft={Print=function() end}
for _,f in ipairs({'Data/DataZones.lua','Data/DataNpcs.lua','Data/DataObjects.lua','Data/DataQuests.lua','Data/OwnDB.lua','Guide/Flow.lua'}) do assert(loadfile(f))('ForeverTrail',ft) end
local rares=ft.RaresOn(1429)
local mail=ft.MailboxesOn(1429)
local names={} for _,r in ipairs(rares) do names[r.name]=true end
assert(#mail>0,'Elwynn mailbox')
local gold for _,m in ipairs(mail) do if m.x>0.40 and m.x<0.46 and m.y>0.6 and m.y<0.7 then gold=m end end
assert(gold,'Goldshire mailbox expected near 42,64')
ForeverTrailSettings.theme='aurora'
ft.SaveProfile('A'); ForeverTrailSettings.theme='neon'; ft.LoadProfile('A')
assert(ForeverTrailSettings.theme=='aurora' and ForeverTrailCharacter.profile=='A','profile roundtrip')
local list={} for n in pairs(names) do list[#list+1]=n end table.sort(list)
print(('Flow tests passed (Elwynn: %d nadir nokta [%s], %d posta kutusu, Goldshire posta %.1f %.1f)'):format(#rares, table.concat(list,', '), #mail, gold.x*100, gold.y*100))
