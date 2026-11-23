-- Mainline altyapısı: global GetItemInfo yok, yalnızca C_Item.GetItemInfo var; çöp eşyalar satılmalı
local function stub()
 return setmetatable({}, {__index = function(_, k) if not tostring(k):match('^%u') then return nil end return function() return stub() end end, __call = function() return stub() end})
end
CreateFrame = function() return stub() end
hooksecurefunc = function() end
NUM_BAG_SLOTS, NUM_REAGENTBAG_SLOTS = 4, 1
GetItemInfo = nil
local sold = {}
local bags = {
 [0] = {{hyperlink = 'item:1', stackCount = 3, quality = 0, itemID = 1}, {hyperlink = 'item:2', stackCount = 1, quality = 1, itemID = 2}},
 [5] = {{hyperlink = 'item:3', stackCount = 1, quality = 0, itemID = 3}, {hyperlink = 'item:4', stackCount = 1, quality = 0, hasNoValue = true, itemID = 4}},
}
C_Container = {
 GetContainerNumSlots = function(b) return bags[b] and #bags[b] or 0 end,
 GetContainerItemInfo = function(b, s) return bags[b] and bags[b][s] end,
 UseContainerItem = function(b, s) sold[#sold + 1] = b .. ':' .. s end,
 GetContainerNumFreeSlots = function() return 0 end,
}
local items = {['item:1'] = {'Kırık Kemik', 'item:1', 0, 1, 1, '', '', 1, '', 0, 25, 15, 0}, ['item:2'] = {'Yeşil', 'item:2', 1, 1, 1, '', '', 1, '', 0, 100, 2, 0},
 ['item:3'] = {'Yırtık Bez', 'item:3', 0, 1, 1, '', '', 1, '', 0, 10, 15, 0}, ['item:4'] = {'Değersiz', 'item:4', 0, 1, 1, '', '', 1, '', 0, 0, 15, 0}}
C_Item = {GetItemInfo = function(link) local t = items[link]; if t then return table.unpack(t) end end}
C_Timer = {After = function(_, fn) fn() end}
MerchantFrame = {IsShown = function() return true end}
GetCoinTextureString = function(c) return c .. ' bakır' end
ForeverTrailSettings = {autosell = true}
local printed = {}
local ft = {Print = function(m) printed[#printed + 1] = m end, errors = {}}
assert(loadfile('Helpers/Gear.lua'))('ForeverTrail', ft)
ft.SellJunk(true)
assert(#ft.errors == 0, ft.errors[1])
assert(#sold == 2 and sold[1] == '0:1' and sold[2] == '5:1', table.concat(sold, ','))
assert(printed[#printed]:find('2 çöp'), printed[#printed])
-- Satıcı kapalıyken satmaz, nedenini söyler
sold, printed = {}, {}
MerchantFrame = {IsShown = function() return false end}
ft.SellJunk(true)
assert(#sold == 0 and printed[#printed]:find('satıcı'), printed[#printed])
print('SellJunk test passed:', table.concat(printed, ' | '))
