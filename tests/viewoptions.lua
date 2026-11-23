-- Görünüm ayarları penceresi ve "Ayar" düğmesi hatasız kurulmalı
local function stub()
 return setmetatable({}, {
  __index = function(_, k)
   if not tostring(k):match('^%u') then return nil end
   return function(_, ...) if k == 'IsShown' then return false end return stub() end
  end,
  __call = function() return stub() end,
 })
end
CreateFrame = function() return stub() end
GameTooltip = stub(); UIParent = stub()
ForeverTrailSettings = {c_trackerView = 'tablo', trkColDist = false}
local built = {}
local ft = {Print = print, tracker = stub(), availableBox = stub(), NewButton = function() return stub() end, NewWindow = function() return stub() end,
 BuildOptions = function(page, y, width, defs) built[#built + 1] = #defs; return y - 20 * #defs end, RefreshOptions = function() end}
assert(loadfile('UI/ViewOptions.lua'))('ForeverTrail', ft)
ft.AttachViewGears()
assert(ft.tracker.viewGear and ft.availableBox.viewGear, 'gears attached')
ft.ToggleViewOptions('tracker'); ft.ToggleViewOptions('avail')
assert(#built == 2, 'both popups built')
print('ViewOptions smoke test passed')
