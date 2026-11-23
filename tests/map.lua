GetTime = GetTime or function() return 0 end
local objects = {}
local methods = {}
local function widget()
 local w = setmetatable({}, {__index = function(_, key) return methods[key] or function() end end})
 objects[#objects + 1] = w
 return w
end
CreateFrame = widget
methods.CreateTexture = widget
methods.CreateLine = function() local w = widget(); w.isLine = true; return w end
methods.CreateFontString = widget
methods.GetCanvas = widget
methods.GetFrameLevel = function() return 1 end
methods.SetFrameLevel = function(self, level) self.level = level end
methods.GetWidth = function() return 100 end
methods.GetHeight = methods.GetWidth
methods.SetTexture = function(self, path) self.path = path end
methods.Show = function(self) self.visible = true end
methods.Hide = function(self) self.visible = false end
methods.IsShown = function(self) return self.visible == true end
methods.SetText = function(self, text) self.text = text end
WorldMapFrame = widget()
WorldMapFrame.pinFrameLevelsManager = {definitions={PIN_FRAME_LEVEL_DIG_SITE={startLevel=2100}}}
methods.SetMapID = function(self, id) self.mapID = id end
methods.SetStartPoint = function(self, _, _, x, y) self.sx, self.sy = x, y end
methods.SetEndPoint = function(self, _, _, x, y) self.ex, self.ey = x, y end
methods.GetMapID = function(self) return self.mapID or 1 end
ShowUIPanel = function() end
hooksecurefunc = function() end
C_Map = {
 GetBestMapForUnit = function() return 1 end,
 GetPlayerMapPosition = function() return {GetXY = function() return .2, .3 end} end,
 GetMapWorldSize = function() return 100, 200 end,
}
local step = {uiMapID = 1, x = .5, y = .5}
local ft = {CurrentStep = function() return step end, Print = error}
assert(loadfile('Map/Map.lua'))('ForeverTrail', ft)
assert(type(ft.MapDebug)=='function', 'map diagnostics must be available')
ft.OpenMap()
local parts = ft.mapParts
local marker, player, route, caption, overlay = parts.marker, parts.player, parts.route, parts.caption, parts.overlay
assert(parts.glow and parts.glow.visible and parts.label and parts.label.text and parts.label.text:find('50 yd'), 'marker glow or label missing')
assert(overlay.level >= 2100, 'navigation is hidden beneath map artwork')
assert(marker.path == 'Interface\\TargetingFrame\\UI-RaidTargetingIcon_4', 'invalid target texture path')
assert(player.path == 'Interface\\TargetingFrame\\UI-RaidTargetingIcon_6', 'invalid player texture path')
assert(player.visible and marker.visible and route.visible and caption.text:find('50 yd'), 'map navigation missing')
-- güzergah: parıltılı çizgi, nokta izi ve akan ışıklar
assert(parts.routeGlow and parts.routeGlow.visible, 'parıltı çizgisi görünmeli')
local function visibleWith(path) local n = 0; for _, o in ipairs(objects) do if o.visible and o.path == path then n = n + 1 end end return n end
ft.UpdateMapTrail(0.2)
local dots, stars = visibleWith('Interface\\Buttons\\WHITE8X8'), visibleWith('Interface\\Cooldown\\star4')
assert(dots >= 3, 'nokta izi ve ışık kuyruğu çizilmeli: ' .. dots)
assert(stars >= 2, 'akan ışığın başı (ve hedef parıltısı) görünmeli: ' .. stars)
-- yol verisi varsa rota kıvrımlıdır: çok parçalı çizgi ve onun boyunca akan ışıklar
ft.RefreshMap()
assert(ft.MapRouteSegments() == 1, 'yol verisi yokken düz çizgi (tek parça) olmalı: ' .. ft.MapRouteSegments())
ft.CurrentRoute = function() return {{.2, .3}, {.3, .3}, {.3, .5}, {.5, .5}} end
ft.RefreshMap()
assert(ft.MapRouteSegments() == 3, 'kıvrımlı rota yol noktası sayısından bir az parçadan oluşmalı: ' .. ft.MapRouteSegments())
ft.UpdateMapTrail(0.2)
assert(visibleWith('Interface\\Buttons\\WHITE8X8') >= 3, 'ışıklar kıvrımlı yol boyunca çizilmeli')
ft.CurrentRoute = nil
ft.RefreshMap()
assert(ft.MapRouteSegments() == 1, 'yol verisi kalkınca düz çizgiye dönülmeli (ek parçalar gizlenmeli): ' .. ft.MapRouteSegments())
-- hedef adım değişince açık harita o adımın haritasına geçer (koordinatı hazır adım için de)
WorldMapFrame.visible = true
WorldMapFrame.mapID = 1
step.uiMapID, step.x, step.y, step.stepId = 5, .4, .4, 'harita-gecisi'
ft.RefreshMap()
assert(WorldMapFrame.mapID == 5, 'hedef başka haritadaysa açık harita ona geçmeli: ' .. tostring(WorldMapFrame.mapID))
WorldMapFrame.mapID = 7; ft.RefreshMap()
assert(WorldMapFrame.mapID == 7, 'aynı hedef için kullanıcının gezdiği harita zorla geri çevrilmemeli')
step.stepId = 'sonraki-adim'; ft.RefreshMap()
assert(WorldMapFrame.mapID == 5, 'yeni adım için harita yeniden geçmeli')
WorldMapFrame.visible = false; WorldMapFrame.mapID = 9; step.stepId = 'kapali-harita'; ft.RefreshMap()
assert(WorldMapFrame.mapID == 9, 'harita kapalıyken çevrilmemeli')
step.uiMapID, step.x, step.y, step.stepId = 1, .5, .5, nil
WorldMapFrame.visible = true; WorldMapFrame.mapID = 1; ft.RefreshMap()
-- tuvale kırpma: giren, çıkan, tamamen dışarıda, tamamen içeride
local function same(a, b) if #a ~= #b then return false end for i = 1, #a do if math.abs(a[i][1] - b[i][1]) > 1e-9 or math.abs(a[i][2] - b[i][2]) > 1e-9 then return false end end return true end
assert(same(ft.MapClipToCanvas({{-50, -50}, {50, -50}}, 100, 100), {{0, -50}, {50, -50}}), 'tuvale giren çizgi kenarda başlamalı')
assert(same(ft.MapClipToCanvas({{50, -50}, {150, -50}}, 100, 100), {{50, -50}, {100, -50}}), 'tuvalden çıkan çizgi kenarda bitmeli')
assert(same(ft.MapClipToCanvas({{-50, -50}, {50, -50}, {50, -150}}, 100, 100), {{0, -50}, {50, -50}, {50, -100}}), 'giren ve çıkan yol: görünen kısım')
assert(ft.MapClipToCanvas({{-50, -50}, {-10, -80}}, 100, 100) == nil, 'tamamen dışarıdaki çizgi görünmemeli')
assert(same(ft.MapClipToCanvas({{10, -10}, {60, -30}, {90, -90}}, 100, 100), {{10, -10}, {60, -30}, {90, -90}}), 'tamamen içerideki yol değişmemeli')

-- oyuncu hedefin haritasında değil (şehir dışında): konum dünya koordinatından çevrilir, çizgi tuvale kırpılır
do
 local realPos = C_Map.GetPlayerMapPosition
 C_Map.GetPlayerMapPosition = function(m) if m == 5 then return nil end return realPos(m) end
 C_Map.GetBestMapForUnit = function() return 1 end
 C_Map.GetMapInfo = function() return {name = 'Bölge'} end
 WorldMapFrame.visible = true; WorldMapFrame.mapID = 5
 step.uiMapID, step.x, step.y, step.stepId = 5, .4, .4, 'sehir-ici'
 local asked
 ft.ProjectToMap = function(src, x, y, dst) asked = {src, dst}; return -0.4, 0.5 end -- oyuncu şehir haritasının solunda, dışında
 ft.CurrentRoute = nil
 ft.RefreshMap()
 assert(asked and asked[1] == 1 and asked[2] == 5, 'oyuncunun konumu hedef haritasına çevrilmeli')
 assert(not parts.player.visible, 'oyuncu hedef haritasının dışındayken işaretçi gizlenmeli')
 assert(parts.route.visible and ft.MapRouteSegments() == 1, 'dışarıdaki oyuncudan hedefe çizgi çizilmeli')
 assert(math.abs(parts.route.sx) < 1e-6, 'çizgi tuval kenarında başlamalı: ' .. tostring(parts.route.sx))
 assert(math.abs(parts.route.ex - 40) < 1e-6 and math.abs(parts.route.ey + 40) < 1e-6, 'çizgi hedefte bitmeli')
 assert(parts.caption.text:find('dışındasın', 1, true), 'başlık haritanın dışında olunduğunu söylemeli: ' .. tostring(parts.caption.text))
 -- kıvrımlı rota da kırpılır; tamamen dışarıdaysa çizilmez
 ft.CurrentRoute = function() return {{-0.4, 0.5}, {0.1, 0.5}, {0.1, 0.4}, {0.4, 0.4}} end
 ft.RefreshMap()
 assert(ft.MapRouteSegments() == 3 and math.abs(parts.route.sx) < 1e-6, 'kıvrımlı rota tuvale kırpılmış çok parçalı olmalı: ' .. ft.MapRouteSegments())
 ft.CurrentRoute = function() return {{-1, -1}, {-0.5, -0.5}} end
 ft.RefreshMap()
 assert(not parts.route.visible, 'tamamen tuval dışındaki rota çizilmemeli')
 -- projeksiyon yoksa (farklı kıta) eski davranış: çizgi yok
 ft.ProjectToMap = function() return nil end; ft.CurrentRoute = nil
 ft.RefreshMap()
 assert(not parts.route.visible and not parts.player.visible, 'projeksiyon yokken çizgi ve oyuncu işareti olmamalı')
 C_Map.GetPlayerMapPosition = realPos
 ft.ProjectToMap = nil
 step.uiMapID, step.x, step.y, step.stepId = 1, .5, .5, nil
 WorldMapFrame.mapID = 1; ft.RefreshMap()
end

local report = ft.MapDebug()
assert(report:find('target=1,0.5,0.5',1,true) and report:find('route=true',1,true), 'diagnostics must include target and route state')
step.x, step.y = nil, nil
ft.RefreshMap()
assert(player.visible and not route.visible, 'player should remain visible without target coordinates')
assert(ft.MapDebug():find('route=false',1,true), 'diagnostics must report hidden route')
ft.UpdateMapTrail()
assert(visibleWith('Interface\\Buttons\\WHITE8X8') == 0 and not parts.routeGlow.visible, 'hedef yokken iz ve parıltı gizlenmeli')
print('Map navigation tests passed')
