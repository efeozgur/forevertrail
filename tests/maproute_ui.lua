-- Yol sor arayüzü için duman testi: evrensel taslak nesnelerle create() ve refresh() hatasız çalışmalı
local handlers = {}
RIGHT = 1000
local function stub()
 local t = {}
 return setmetatable(t, {
  __index = function(self, k)
   return function(_, ...)
    if k == 'GetText' then return '' end
    if k == 'GetMapID' then return 1429 end
    if k == 'IsShown' then return true end
    if k == 'HasFocus' then return false end
    if k == 'SetScript' or k == 'HookScript' then local name, fn = ...; if name == 'OnEvent' then handlers.event = fn end; if name == 'OnShow' then handlers.show = fn end; return end
    if k == 'GetWidth' or k == 'GetHeight' or k == 'GetFrameLevel' then return 700 end
    if k == 'GetFrameStrata' then return 'HIGH' end
    if k == 'GetEffectiveScale' then return 1 end
    if k == 'GetRight' then return RIGHT end
    if k == 'GetLeft' then return 100 end
    if k == 'GetHighlightTexture' then return stub() end
    return stub()
   end
  end,
  __call = function() return stub() end,
 })
end
CreateFrame = function() return stub() end
GameTooltip = stub()
UIParent = {GetWidth = function() return 1920 end, GetEffectiveScale = function() return 1 end}
WorldMapFrame = stub()
UnitFactionGroup = function() return 'Alliance' end
UnitLevel = function() return 10 end
UnitClass = function() return 'Warrior', 'WARRIOR', 1 end
C_Map = {GetBestMapForUnit = function() return 1429 end, GetMapInfo = function() return {name = 'Elwynn'} end,
 GetPlayerMapPosition = function() return {GetXY = function() return .5, .5 end} end, GetMapWorldSize = function() return 1000, 1000 end}
ForeverTrailSettings = {}
local ft = {Print = function(m) print('PRINT', m) end,
 NewWindow = function() return stub() end, NewButton = function() return stub() end, FixFonts = function() end, StyleTitle = function() end,
 MapName = function() return 'Elwynn' end, Style = {accent = {1, 1, 1}}, errors = {}}
for _, f in ipairs({'Data/DataZones.lua', 'Data/DataNpcs.lua', 'Data/OwnDB.lua', 'Map/MapRoute.lua'}) do assert(loadfile(f))('ForeverTrail', ft) end
handlers.event()
assert(#ft.errors == 0, ft.errors[1])
assert(ft.mapRoute, 'panel created')
ft.RefreshMapRoute()
ft.RouteCategory('inn'); ft.RouteCategory('gorev'); ft.RouteCategory('kayit')
ft.RouteSearch('zzzz')
-- Sağda yer yok (tam ekran): sola ya da içeri yerleşmeli, hata vermemeli
RIGHT = 1900; if handlers.show then handlers.show() end; ft.RefreshMapRoute()
ForeverTrailSettings.routeSide = 'left'; RIGHT = 1000; if handlers.show then handlers.show() end; ft.RefreshMapRoute()
print('MapRoute UI smoke test passed, results for empty search:', ft.RouteCount())
