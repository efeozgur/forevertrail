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
-- C_Map taslağı bölge verisinin kendi aramasını bozar; hizmet önbelleği dolunca devreye girer (mesafe için)
local mapStub = {GetBestMapForUnit = function() return 1429 end, GetMapInfo = function() return {name = 'Elwynn'} end,
 GetPlayerMapPosition = function() return {GetXY = function() return .5, .5 end} end, GetMapWorldSize = function() return 1000, 1000 end}
ForeverTrailSettings = {}
local kitStub = setmetatable({}, {__index = function() return function() return stub() end end})
local ft = {Print = function(m) print('PRINT', m) end, Kit = kitStub,
 NewWindow = function() return stub() end, NewButton = function() return stub() end, FixFonts = function() end, StyleTitle = function() end,
 MapName = function() return 'Elwynn' end, Style = {accent = {1, 1, 1}}, errors = {},
 FormatETA = function(s) return ('~%d sn'):format(s) end}
for _, f in ipairs({'Data/DataZones.lua', 'Data/DataNpcs.lua', 'Data/OwnDB.lua', 'Map/MapRoute.lua'}) do assert(loadfile(f))('ForeverTrail', ft) end
ft.DBQ = ft.DBQ or {[1] = {}} -- maproute.lua testiyle aynı: hizmet NPC'leri için gömülü veri açılır
assert(#ft.MapServices(1429) > 10, 'hizmet önbelleği dolmalı')
C_Map = mapStub
handlers.event()
assert(#ft.errors == 0, ft.errors[1])
assert(ft.mapRoute, 'panel created')
ft.RefreshMapRoute()
ft.RouteCategory('inn'); ft.RouteCategory('gorev'); ft.RouteCategory('kayit')
ft.RouteSearch('zzzz')
assert(ft.RouteCount() == 0, 'olmayan aramada sonuç çıkmamalı')
-- Sağda yer yok (tam ekran): sola ya da içeri yerleşmeli, hata vermemeli
RIGHT = 1900; if handlers.show then handlers.show() end; ft.RefreshMapRoute()
ForeverTrailSettings.routeSide = 'left'; RIGHT = 1000; if handlers.show then handlers.show() end; ft.RefreshMapRoute()

-- sıralama ve favoriler
ft.RouteSearch('')
ft.RouteCategory('repair')
local base = ft.RouteCount()
assert(base > 3, 'Elwynn\'de birkaç tamirci olmalı: ' .. base)
local entries = ft.RouteEntries()
for i = 2, #entries do
 assert(entries[i - 1].dist == nil or entries[i].dist == nil or entries[i - 1].dist <= entries[i].dist, 'varsayılan sıralama yakından uzağa')
end
ForeverTrailSettings.routeSort = 'ad'; ft.RefreshMapRoute()
entries = ft.RouteEntries()
for i = 2, #entries do assert(tostring(entries[i - 1].name) <= tostring(entries[i].name), 'ad sıralaması: ' .. tostring(entries[i - 1].name) .. ' > ' .. tostring(entries[i].name)) end
-- bir tamirciyi favori yap: listenin en üstüne çıkar
local last = entries[#entries]
ForeverTrailSettings.places = {{name = last.name, cat = 'Kayıtlı', map = last.map, x = last.x, y = last.y}}
ft.RefreshMapRoute()
entries = ft.RouteEntries()
assert(entries[1].name == last.name and ft.RouteCount() == base, 'favori en üstte ve tekrarlanmamalı: ' .. tostring(entries[1].name) .. ' ' .. ft.RouteCount() .. '/' .. base)
ForeverTrailSettings.routeSort = 'tur'; ft.RefreshMapRoute()
assert(ft.RouteCount() == base, 'tür sıralaması sayıyı değiştirmemeli')
-- kayıtlarım türü yalnızca kayıtlı yerleri gösterir
ft.RouteCategory('kayit')
assert(ft.RouteCount() == 1 and ft.RouteEntries()[1].saved, 'kayıtlarım: ' .. ft.RouteCount())
-- hepsi: kayıtlı yer zaten listede olduğundan ikinci kez eklenmez
ft.RouteCategory('hepsi')
local hepsi = ft.RouteCount()
ForeverTrailSettings.places = {}
ft.RefreshMapRoute()
assert(ft.RouteCount() == hepsi, 'kayıtlı kopya, aynı yerin ikinci satırı olmamalı: ' .. hepsi .. '/' .. ft.RouteCount())
-- çip şeridi açık, işaretler kapalı: hata vermemeli
ForeverTrailSettings.routeChipsOpen = true; ForeverTrailSettings.routeHighlight = false; ForeverTrailSettings.routeCollapsed = true
ft.RouteCategory('vendor'); ft.RefreshMapRoute()
ForeverTrailSettings.routeCollapsed = nil
print('MapRoute UI smoke test passed, results for empty search:', ft.RouteCount())
