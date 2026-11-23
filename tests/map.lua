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
methods.CreateLine = widget
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
methods.GetMapID = function() return 1 end
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
local report = ft.MapDebug()
assert(report:find('target=1,0.5,0.5',1,true) and report:find('route=true',1,true), 'diagnostics must include target and route state')
step.x, step.y = nil, nil
ft.RefreshMap()
assert(player.visible and not route.visible, 'player should remain visible without target coordinates')
assert(ft.MapDebug():find('route=false',1,true), 'diagnostics must report hidden route')
ft.UpdateMapTrail()
assert(visibleWith('Interface\\Buttons\\WHITE8X8') == 0 and not parts.routeGlow.visible, 'hedef yokken iz ve parıltı gizlenmeli')
print('Map navigation tests passed')
