local ft = {}
assert(loadfile('UI/Target.lua'))('ForeverTrail', ft)
assert(ft.ParseObjective('Plainstrider Meat: 3/7') == 'Plainstrider Meat', 'count suffix must be stripped')
assert(ft.ParseObjective('Kaşif') == 'Kaşif', 'text without count must stay')
assert(ft.ParseObjective(nil) == '', 'nil text must be empty')
local modules = {QuestieDB = {QueryQuestSingle = function(id, key)
 if key == 'objectives' then return {{{2955, 'Plainstrider'}}, {}, {{5000, 'Meat'}}} end
 if key == 'startedBy' then return {{3000}} end
end}}
QuestieLoader = {ImportModule = function(_, name) return modules[name] end}
local t = ft.TargetsFor({questId = 747, type = 'objective'})
assert(#t == 2 and t[1].kind == 'npc' and t[1].id == 2955 and t[2].kind == 'item' and t[2].id == 5000, 'objective targets wrong')
t = ft.TargetsFor({questId = 747, type = 'accept'})
assert(#t == 1 and t[1].kind == 'npc' and t[1].id == 3000, 'accept giver wrong')
assert(#ft.TargetsFor({type = 'objective'}) == 0, 'no quest id must give no targets')
modules.ZoneDB = {GetUiMapIdByAreaId = function(_, id) return id + 9 end}
modules.QuestieDB.QueryNPCSingle = function() return {[1] = {{10, 20}, {30, 40}}} end
local points = ft.SpawnPoints({questId = 747, type = 'objective', objectiveIndex = 1})
assert(#points == 2 and points[1].map == 10 and points[1].x == 0.1 and points[2].y == 0.4, 'spawn points wrong')
local summary = ft.SummarizeSpawns({{map = 10}, {map = 10}, {map = 11}}, function(id) return id == 10 and 'Mulgore' or 'Barrens' end)
assert(summary == 'Mulgore, Barrens (3 nokta)', 'spawn summary wrong: ' .. summary)
assert(ft.SummarizeSpawns({}) == 'Konum bilinmiyor', 'empty spawn summary wrong')
print('Target tests passed')
