local ft = {}
assert(loadfile('UI/Arrow.lua'))('ForeverTrail', ft)
local function near(a, b) return math.abs(a - b) < 1e-6 end
assert(near(ft.Bearing(0, -10, 0), 0), 'north target must point up')
assert(near(ft.Bearing(10, 0, 0), math.pi * 1.5), 'east target is 90 degrees clockwise')
assert(near(ft.Bearing(0, 10, 0), math.pi), 'south target must point down')
assert(near(ft.Bearing(0, -10, math.pi / 2), math.pi * 1.5), 'facing west, north target is on the right')
assert(ft.FormatETA(5) == '~5 sn' and ft.FormatETA(0.2) == '~1 sn', 'short ETA wrong')
assert(ft.FormatETA(125) == '~2 dk', 'long ETA wrong')
assert(ft.FormatETA(-1) == '' and ft.FormatETA(nil) == '', 'invalid ETA must be empty')
print('Arrow tests passed')
