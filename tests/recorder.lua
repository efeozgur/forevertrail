local ft = {}
assert(loadfile('Guide/Recorder.lua'))('ForeverTrail', ft)
local text = ft.ExportGuide({title = 'Test Rehber', zone = 'Mulgore', steps = {
 {stepId = 'step-1', type = 'accept', questId = 747, uiMapID = 1412, x = 0.445, y = 0.775, text = 'Görevi al'},
 {stepId = 'step-2', type = 'manual', text = 'Elle onayla'},
}})
assert(text:find('FT.RegisterGuide', 1, true), 'export must register the guide')
assert(text:find('guideId="test-rehber"', 1, true), 'guide id must be derived from the title')
assert(text:find('x=0.445', 1, true) and text:find('questId=747', 1, true), 'coordinates and quest id must be exported')
assert(not text:find('uiMapID', 1, true) or select(2, text:gsub('uiMapID', '')) == 1, 'manual step must not get coordinates')
print('Recorder tests passed')
