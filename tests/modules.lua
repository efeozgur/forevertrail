-- Yüklenmeyen parça uyarısı: /reload yeni dosyaları yüklemez; eksik modüller açıkça söylenmeli
local printed = {}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
SlashCmdList = {}
local ft = {Print = function(m) printed[#printed + 1] = m end}
assert(loadfile('Core/Diagnostics.lua'))('ForeverTrail', ft)
assert(#ft.ExpectedModules >= 8, 'beklenen modül listesi')

-- hepsi yüklüyse sessiz
for _, m in ipairs(ft.ExpectedModules) do ft[m[2]] = function() end end
assert(#ft.CheckModules(true) == 0 and #printed == 0, 'her şey yüklüyken uyarı olmamalı')

-- bir modül eksikse adıyla söyler ve /reload yetmediğini belirtir
ft.RefreshGuideTab = nil; ft.AutoPilotStep = nil
local missing = ft.CheckModules(true)
assert(#missing == 2 and missing[1] == 'Rehber sekmesi' and missing[2] == 'Otopilot', 'eksikler: ' .. table.concat(missing, ','))
assert(#printed == 1 and printed[1]:find('Rehber sekmesi', 1, true) and printed[1]:find('Otopilot', 1, true) and printed[1]:find('/reload yetmez', 1, true), 'uyarı eksik adları ve /reload notunu içermeli: ' .. tostring(printed[1]))
-- announce=false iken yazmaz
printed = {}; ft.CheckModules(false); assert(#printed == 0, 'duyuru istenmediyse yazmamalı')

-- gerçek TOC'taki her yeni dosya beklenen modüllerden birini sağlar: TOC okunur, dosyalar var
local toc = io.open('ForeverTrail.toc', 'rb'):read('*a')
for _, f in ipairs({'Guide/StepInfo.lua', 'UI/GuideTab.lua', 'UI/RouteCard.lua', 'UI/Suggestions.lua', 'UI/GuidePicker.lua', 'Map/Roads.lua', 'Guide/AutoPilot.lua', 'Guide/AutoGuide.lua'}) do
 assert(toc:find(f, 1, true), 'TOC bu dosyayı içermeli: ' .. f)
end
print('Modules tests passed')
