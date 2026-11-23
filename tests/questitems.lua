-- Görev eşyaları: otomatik satışta korunur, satılırsa geri alınır, çantadaki liste çalışır
local function stub()
 return setmetatable({}, {__index = function(_, k) if not tostring(k):match('^%u') then return nil end return function() return stub() end end, __call = function() return stub() end})
end
local handlers = {}
CreateFrame = function()
 local f = stub()
 rawset(f, 'SetScript', function(_, name, fn) if name == 'OnEvent' then handlers[#handlers + 1] = fn end end)
 return f
end
hooksecurefunc = function() end
GetTime = function() return 100 end
NUM_BAG_SLOTS, NUM_REAGENTBAG_SLOTS = 4, 0
GetItemInfo = nil
local sold = {}
local bags = {[0] = {
 {hyperlink = 'item:1', stackCount = 3, quality = 0, itemID = 1}, -- sıradan çöp: satılır
 {hyperlink = 'item:2', stackCount = 2, quality = 0, itemID = 2}, -- görev hedefi (gri): satılmaz
 {hyperlink = 'item:3', stackCount = 1, quality = 0, itemID = 3}, -- elle kilitli: satılmaz
 {hyperlink = 'item:4', stackCount = 1, quality = 1, itemID = 4}, -- görev sınıfı
}}
C_Container = {
 GetContainerNumSlots = function(b) return bags[b] and #bags[b] or 0 end,
 GetContainerItemInfo = function(b, s) return bags[b] and bags[b][s] end,
 UseContainerItem = function(b, s) sold[#sold + 1] = b .. ':' .. s end,
 GetContainerNumFreeSlots = function() return 0 end,
}
local items = {
 ['item:1'] = {'Kemik', 'item:1', 0, 1, 1, '', '', 1, '', 0, 25, 15, 0}, ['item:2'] = {'Kurt Eti', 'item:2', 0, 1, 1, '', '', 1, '', 0, 25, 7, 0},
 ['item:3'] = {'Süs', 'item:3', 0, 1, 1, '', '', 1, '', 0, 25, 15, 0}, ['item:4'] = {'Mektup', 'item:4', 1, 1, 1, '', '', 1, '', 0, 0, 12, 0},
}
local class = {[1] = 15, [2] = 7, [3] = 15, [4] = 12}
C_Item = {GetItemInfo = function(link) local t = items[link]; if t then return table.unpack(t) end end,
 GetItemInfoInstant = function(id) return id, 'x', 'y', '', 134400, class[id], 0 end}
C_Timer = {After = function(_, fn) fn() end}
MerchantFrame = {IsShown = function() return true end}
GetCoinTextureString = function(c) return c .. ' bakır' end
C_QuestLog = {GetNumQuestLogEntries = function() return 1 end, GetInfo = function() return {questID = 77, title = 'Kurtlar'} end}
ForeverTrailSettings = {autosell = true, lockedItems = {[3] = true}}
local printed = {}
local ft = {Print = function(m) printed[#printed + 1] = m end, errors = {}}
ft.Module = function(n) if n == 'QuestieDB' then return {QueryQuestSingle = function(id, key)
 if key == 'objectives' then return {nil, nil, {{2}}} end
 return nil
end} end end
ft.NewWindow = function() return stub() end
ft.NewButton = function() return stub() end
assert(loadfile('Helpers/Gear.lua'))('ForeverTrail', ft)
assert(loadfile('Helpers/QuestItems.lua'))('ForeverTrail', ft)

-- Koruma
assert(ft.IsProtectedItem(2, 7) and ft.IsProtectedItem(3, 15) and ft.IsProtectedItem(4, 12) and not ft.IsProtectedItem(1, 15))
ft.SellJunk(true)
assert(#ft.errors == 0, ft.errors[1])
assert(#sold == 1 and sold[1] == '0:1', table.concat(sold, ','))
-- Koruma kapalıyken yalnızca elle kilitli kalır
ForeverTrailSettings.questItemGuard = false
assert(not ft.IsProtectedItem(2, 7) and ft.IsProtectedItem(3, 15))
ForeverTrailSettings.questItemGuard = nil

-- Liste: görev hedefi + elle kilitli + görev sınıfı
local list = ft.QuestBagItems()
assert(#list == 3, #list)

-- Geri alma: satıcı geri alım listesinde korunan eşya varsa alınır
local bought = {}
local buyback = {'|cffffffff|Hitem:2::|h[Kurt Eti]|h|r', '|cffffffff|Hitem:1::|h[Kemik]|h|r'}
GetNumBuybackItems = function() return #buyback end
GetBuybackItemLink = function(i) return buyback[i] end
BuybackItem = function(i) bought[#bought + 1] = i end
local onEvent = handlers[#handlers]
onEvent(nil, 'MERCHANT_SHOW'); onEvent(nil, 'MERCHANT_UPDATE')
assert(#bought == 1 and bought[1] == 1, 'geri alınmadı: ' .. table.concat(bought, ','))
buyback = {'|Hitem:1::|h[Kemik]|h'}
onEvent(nil, 'MERCHANT_UPDATE')
assert(#bought == 1, 'çöp geri alındı')
assert(#ft.errors == 0, ft.errors[1])
ft.ToggleQuestItems()
print('QuestItems test passed', #list .. ' liste', table.concat(printed, ' | '))
