local _, FT = ...

-- Forever (Mainline altyapısı): eski global GetItemInfo olmayabilir; C_Item.GetItemInfo kullanılır
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)

-- Çanta, banka, satıcı ve ekipman yardımcıları.
-- Görev eşyaları hiçbir koşulda satılmaz, atılmaz veya değiştirilmez.

local C = C_Container

local function enabled(key)
 return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false
end

local function optedIn(key)
 return ForeverTrailSettings and ForeverTrailSettings[key] == true
end

local function money(copper)
 copper = copper or 0
 if GetCoinTextureString then return GetCoinTextureString(copper) end
 return ('%dg %ds %dc'):format(math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100)
end

local function after(seconds, fn)
 if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
end

----------------------------------------------------------------------
-- Çanta erişimi (eski ve yeni istemci uyumlu)
----------------------------------------------------------------------
-- Çantalar 0..4, malzeme çantası da varsa +1 (Mainline altyapısı)
local function lastBag() return (NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 0) end

local function numSlots(bag)
 local fn = (C and C.GetContainerNumSlots) or GetContainerNumSlots
 return fn and fn(bag) or 0
end

local function slotInfo(bag, slot)
 if C and C.GetContainerItemInfo then
  local info = C.GetContainerItemInfo(bag, slot)
  if not info then return nil end
  return {link=info.hyperlink, count=info.stackCount or 1, quality=info.quality, itemID=info.itemID, locked=info.isLocked, noValue=info.hasNoValue}
 end
 if GetContainerItemInfo then
  local _, count, locked, quality, _, _, link, _, noValue, itemID = GetContainerItemInfo(bag, slot)
  if not link then return nil end
  return {link=link, count=count or 1, quality=quality, itemID=itemID, locked=locked, noValue=noValue}
 end
end

local function useSlot(bag, slot)
 if C and C.UseContainerItem then C.UseContainerItem(bag, slot) elseif UseContainerItem then UseContainerItem(bag, slot) end
end

local function pickupSlot(bag, slot)
 if C and C.PickupContainerItem then C.PickupContainerItem(bag, slot) elseif PickupContainerItem then PickupContainerItem(bag, slot) end
end

local function freeSlots()
 local total = 0
 for bag = 0, lastBag() do
  local fn = (C and C.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  local free = fn and fn(bag)
  if type(free) == 'number' then total = total + free end
 end
 return total
end

local function itemFacts(link)
 if not link then return nil end
 local name, _, quality, itemLevel, minLevel, _, _, _, equipLoc, _, sellPrice, classID, subClassID, bindType = GetItemInfo(link)
 if not name then return nil end
 return {link=link, name=name, quality=quality, itemLevel=itemLevel or 0, minLevel=minLevel or 0, equipLoc=equipLoc, sellPrice=sellPrice or 0, classID=classID, subClassID=subClassID, bindType=bindType}
end

local QUEST_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12
local function isQuestItem(facts)
 return facts and facts.classID == QUEST_CLASS
end

-- Satıcıya otomatik satılacak (gri, değerli, görev dışı) eşya mı?
local function isJunk(bag, slot)
 local info = slotInfo(bag, slot)
 if not info or not info.link or info.locked or info.noValue then return false end
 if info.quality ~= 0 then return false end
 local facts = itemFacts(info.link)
 if not facts or facts.sellPrice <= 0 or isQuestItem(facts) then return false end
 -- günlükteki görevlerin istediği ya da elle kilitlenen eşyalar satılmaz (QuestItems.lua)
 if FT.IsProtectedItem and FT.IsProtectedItem(info.itemID, facts.classID) then return false end
 return true, facts.sellPrice * info.count
end

----------------------------------------------------------------------
-- Çanta ve banka düzenleme
----------------------------------------------------------------------
function FT.SortBags()
 if InCombatLockdown and InCombatLockdown() then return FT.Print('Savaşta çanta düzenlenemez.') end
 if C and C.SortBags then C.SortBags()
 elseif SortBags then SortBags()
 else return FT.Print('Bu sürümde çanta düzenleme desteklenmiyor.') end
 FT.Print('Çanta düzenlendi.')
end

function FT.SortBank()
 if InCombatLockdown and InCombatLockdown() then return FT.Print('Savaşta banka düzenlenemez.') end
 if C and C.SortBankBags then C.SortBankBags()
 elseif SortBankBags then SortBankBags()
 else return FT.Print('Bu sürümde banka düzenleme desteklenmiyor.') end
 FT.Print('Banka düzenlendi.')
end

local bankButton
local function ensureBankButton()
 if bankButton or not BankFrame then return end
 bankButton = FT.NewButton and FT.NewButton(BankFrame, 'Düzenle', 70, 22)
 if not bankButton then bankButton = CreateFrame('Button', nil, BankFrame, 'UIPanelButtonTemplate'); bankButton:SetSize(70, 22); bankButton:SetText('Düzenle') end
 bankButton:SetPoint('TOPRIGHT', BankFrame, 'TOPRIGHT', -50, -32)
 bankButton:SetScript('OnClick', function() FT.SortBank() end)
 if FT.ApplyFont then pcall(FT.ApplyFont) end
end

----------------------------------------------------------------------
-- Satıcı: otomatik tamir ve otomatik satış
----------------------------------------------------------------------
local selling = false

-- verbose: elle çağrıldığında (/ftrail sat) neden satılmadığını da yazar
function FT.SellJunk(verbose)
 if selling then return end
 local queue, total = {}, 0
 local scanned, grey = 0, 0
 for bag = 0, lastBag() do
  for slot = 1, numSlots(bag) do
   scanned = scanned + 1
   local info = slotInfo(bag, slot)
   if info and info.quality == 0 then grey = grey + 1 end
   local junk, value = isJunk(bag, slot)
   if junk then queue[#queue + 1] = {bag, slot}; total = total + (value or 0) end
  end
 end
 if #queue == 0 then
  if verbose then
   FT.Print(('Satılacak çöp eşya yok. Taranan yuva: %d, gri eşya: %d%s'):format(scanned, grey,
    (grey > 0) and ' (gri eşyaların satış değeri yok ya da bilgisi henüz yüklenmedi)' or ''))
  end
  return
 end
 if not (MerchantFrame and MerchantFrame:IsShown()) then
  if verbose then FT.Print(('%d çöp eşya var; satmak için bir satıcı penceresi aç.'):format(#queue)) end
  return
 end
 selling = true
 local index = 0
 local function step()
  local ok, err = pcall(function()
   index = index + 1
   local entry = queue[index]
   if not entry or not (MerchantFrame and MerchantFrame:IsShown()) then
    selling = false
    FT.Print(('%d çöp eşya satıldı: %s'):format(math.min(index - 1, #queue), money(total)))
    return
   end
   if isJunk(entry[1], entry[2]) then useSlot(entry[1], entry[2]) end
   after(0.1, step)
  end)
  if not ok then
   selling = false
   if FT.errors then FT.errors[#FT.errors + 1] = 'sat: ' .. tostring(err) end
   FT.Print('Çöp satışı yarıda kesildi: ' .. tostring(err))
  end
 end
 step()
end

local function autoRepair()
 if not (CanMerchantRepair and CanMerchantRepair()) then return end
 local cost, canRepair = GetRepairAllCost()
 if not canRepair or not cost or cost <= 0 then return end
 if cost > GetMoney() then return FT.Print(('Tamir için yeterli altın yok (%s gerekiyor).'):format(money(cost))) end
 RepairAllItems()
 FT.Print('Ekipman tamir edildi: ' .. money(cost))
end

----------------------------------------------------------------------
-- Çantadaki satılacak eşyalara altın işareti
----------------------------------------------------------------------
local function mark(button, show)
 if not button then return end
 if show then
  if not button.ftCoin then
   local t = button:CreateTexture(nil, 'OVERLAY')
   t:SetTexture('Interface\\MoneyFrame\\UI-GoldIcon')
   t:SetSize(14, 14)
   t:SetPoint('TOPLEFT', 2, -2)
   button.ftCoin = t
  end
  button.ftCoin:Show()
 elseif button.ftCoin then
  button.ftCoin:Hide()
 end
end

function FT.UpdateBagMarks()
 local on = enabled('goldmark')
 for i = 1, (NUM_CONTAINER_FRAMES or 13) do
  local frame = _G['ContainerFrame' .. i]
  if frame and frame:IsShown() then
   if frame.EnumerateValidItems then
    for _, button in frame:EnumerateValidItems() do
     local bag = button.GetBagID and button:GetBagID() or frame:GetID()
     mark(button, on and isJunk(bag, button:GetID()))
    end
   elseif frame.size then
    local bag = frame:GetID()
    for j = 1, frame.size do
     local button = _G['ContainerFrame' .. i .. 'Item' .. j]
     if button then mark(button, on and isJunk(bag, button:GetID())) end
    end
   end
  end
 end
 local combined = _G.ContainerFrameCombinedBags
 if combined and combined:IsShown() and combined.EnumerateValidItems then
  for _, button in combined:EnumerateValidItems() do
   local bag = button.GetBagID and button:GetBagID() or button:GetParent():GetID()
   mark(button, on and isJunk(bag, button:GetID()))
  end
 end
end

local markPending = false
local function scheduleMarks()
 if markPending then return end
 markPending = true
 after(0.15, function() markPending = false; pcall(FT.UpdateBagMarks) end)
end

----------------------------------------------------------------------
-- Daha iyi ekipman uyarısı
----------------------------------------------------------------------
local SLOTS = {
 INVTYPE_HEAD={1}, INVTYPE_NECK={2}, INVTYPE_SHOULDER={3}, INVTYPE_CLOAK={15}, INVTYPE_CHEST={5}, INVTYPE_ROBE={5},
 INVTYPE_WRIST={9}, INVTYPE_HAND={10}, INVTYPE_WAIST={6}, INVTYPE_LEGS={7}, INVTYPE_FEET={8},
 INVTYPE_FINGER={11, 12}, INVTYPE_TRINKET={13, 14},
 INVTYPE_WEAPON={16}, INVTYPE_2HWEAPON={16}, INVTYPE_WEAPONMAINHAND={16},
 INVTYPE_WEAPONOFFHAND={17}, INVTYPE_SHIELD={17}, INVTYPE_HOLDABLE={17},
 INVTYPE_RANGED={18}, INVTYPE_RANGEDRIGHT={18}, INVTYPE_THROWN={18},
}
local FREE_SLOT = {INVTYPE_NECK=true, INVTYPE_CLOAK=true, INVTYPE_FINGER=true, INVTYPE_TRINKET=true}
local ARMOR_BY_CLASS = {
 WARRIOR='plate', PALADIN='plate', DEATHKNIGHT='plate', HUNTER='mail', SHAMAN='mail',
 ROGUE='leather', DRUID='leather', MONK='leather', DEMONHUNTER='leather', PRIEST='cloth', MAGE='cloth', WARLOCK='cloth',
}
local ARMOR_ID = {cloth=1, leather=2, mail=3, plate=4}

local function bestArmorId()
 local _, token = UnitClass('player')
 local kind = ARMOR_BY_CLASS[token] or 'cloth'
 local level = UnitLevel('player') or 1
 if (token == 'WARRIOR' or token == 'PALADIN') and level < 40 then kind = 'mail' end
 if (token == 'HUNTER' or token == 'SHAMAN') and level < 40 then kind = 'leather' end
 return ARMOR_ID[kind]
end

local declined = {}
local popup

local function equippedFacts(slot)
 local link = GetInventoryItemLink and GetInventoryItemLink('player', slot)
 return link and itemFacts(link) or nil, link
end

-- Çantadaki parça bu yuvadaki mevcut parçadan daha iyi mi? (dönüş: yuva, mevcut ilvl)
local function upgradeSlot(facts)
 local slots = SLOTS[facts.equipLoc]
 if not slots or facts.quality == nil or facts.quality < 1 then return nil end
 if facts.minLevel > (UnitLevel('player') or 1) then return nil end
 if facts.classID ~= 2 and facts.classID ~= 4 then return nil end
 local bestSlot, bestLevel, bestLink
 for _, slot in ipairs(slots) do
  local current, currentLink = equippedFacts(slot)
  local level = current and (FT.ItemScore and FT.ItemScore(currentLink) or current.itemLevel) or -1
  if current then
   if facts.classID ~= current.classID or facts.subClassID ~= current.subClassID then
    -- tür uyuşmuyorsa (ör. zırh tipi) öneri yapma
    if not (FREE_SLOT[facts.equipLoc]) and not (facts.classID == 4 and facts.subClassID == bestArmorId()) then level = nil end
   elseif facts.classID == 2 and facts.equipLoc ~= current.equipLoc and not (facts.equipLoc == 'INVTYPE_WEAPON' or facts.equipLoc == 'INVTYPE_WEAPONMAINHAND') then
    level = nil
   end
  elseif facts.classID == 4 and not FREE_SLOT[facts.equipLoc] and facts.equipLoc ~= 'INVTYPE_SHIELD' and facts.subClassID ~= bestArmorId() then
   level = nil
  elseif facts.classID == 2 then
   level = nil -- boş silah yuvasında hangi silahı kullanabildiğini bilemeyiz
  end
  if level and (not bestLevel or level < bestLevel) then bestSlot, bestLevel, bestLink = slot, level, currentLink end
 end
 if not bestSlot then return nil end
 local mine = FT.ItemScore and FT.ItemScore(facts.link) or facts.itemLevel
 local margin = FT.ItemScore and 1.03 or 1
 if bestLevel < 0 or mine > bestLevel * margin then return bestSlot, bestLevel, bestLink, mine end
end

local function ensurePopup()
 if popup then return popup end
 popup = FT.NewWindow and FT.NewWindow('ForeverTrailUpgrade', UIParent) or CreateFrame('Frame', 'ForeverTrailUpgrade', UIParent, 'BasicFrameTemplateWithInset')
 FT.upgradePopup = popup
 popup:SetSize(300, 130); popup:SetPoint('TOP', UIParent, 'TOP', 0, -170); popup:SetFrameStrata('DIALOG')
 popup:SetMovable(true); popup:EnableMouse(true); popup:RegisterForDrag('LeftButton')
 popup:SetScript('OnDragStart', function(self) self:StartMoving() end)
 popup:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
 popup.title = popup:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 popup.title:SetPoint('TOP', 0, -7)
 popup.icon = popup:CreateTexture(nil, 'ARTWORK')
 popup.icon:SetSize(40, 40); popup.icon:SetPoint('TOPLEFT', 16, -32)
 popup.text = popup:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
 popup.text:SetPoint('TOPLEFT', popup.icon, 'TOPRIGHT', 10, 0)
 popup.text:SetWidth(220); popup.text:SetJustifyH('LEFT'); popup.text:SetJustifyV('TOP'); popup.text:SetHeight(44)
 local function btn(text, x, handler)
  local b = FT.NewButton and FT.NewButton(popup, text, 110, 24)
  if not b then b = CreateFrame('Button', nil, popup, 'UIPanelButtonTemplate'); b:SetSize(110, 24); b:SetText(text) end
  b:SetPoint('BOTTOMLEFT', x, 14); b:SetScript('OnClick', handler)
  return b
 end
 popup.accept = btn('Tak', 24, function() if popup.onAccept then popup.onAccept() end popup:Hide() end)
 popup.decline = btn('Şimdi değil', 166, function() if popup.onDecline then popup.onDecline() end popup:Hide() end)
 popup:Hide()
 if FT.RegisterPopup then FT.RegisterPopup(popup) end
 if FT.ApplyFont then pcall(FT.ApplyFont) end
 return popup
end

local function showPopup(title, iconTexture, text, acceptText, onAccept, onDecline)
 local p = ensurePopup()
 p.title:SetText(title)
 p.icon:SetTexture(iconTexture)
 p.text:SetText(text)
 p.accept:SetText(acceptText)
 p.onAccept, p.onDecline = onAccept, onDecline
 p:Show()
end

-- Diğer modüller için ortak seçim penceresi (açıksa false döner)
function FT.ShowChoice(title, icon, text, acceptText, onAccept, onDecline)
 if popup and popup:IsShown() then return false end
 showPopup(title, icon, text, acceptText, onAccept, onDecline)
 return true
end

local scanPending = false
local function itemId(link) return link and tonumber(link:match('item:(%d+)')) end
local function never()
 ForeverTrailCharacter = ForeverTrailCharacter or {}
 ForeverTrailCharacter.neverEquip = ForeverTrailCharacter.neverEquip or {}
 return ForeverTrailCharacter.neverEquip
end

function FT.ScanUpgrades()
 if not enabled('upgrades') or (InCombatLockdown and InCombatLockdown()) then return end
 if popup and popup:IsShown() then return end
 if FT.upgradeCompare and FT.upgradeCompare:IsShown() then return end
 local skip = never()
 for bag = 0, lastBag() do
  for slot = 1, numSlots(bag) do
   local info = slotInfo(bag, slot)
   local id = info and itemId(info.link)
   if info and info.link and not declined[info.link] and not (id and skip[id]) then
    local facts = itemFacts(info.link)
    if facts then
     local target, currentScore, currentLink = upgradeSlot(facts)
     if target then
      local link = info.link
      local equip = function() FT.EquipFromBag(bag, slot, link, target) end
      local boe = facts.bindType == 2
      if optedIn('autoequip') and not boe then equip(); return end
      local note = boe and 'Kuşanınca ruhuna bağlanır (satılamaz/takas edilemez olur).' or nil
      local shown = FT.ShowUpgradeCompare and FT.ShowUpgradeCompare(link, currentLink, equip,
       function() declined[link] = true; after(0.5, function() pcall(FT.ScanUpgrades) end) end,
       function() if id then skip[id] = true end; after(0.5, function() pcall(FT.ScanUpgrades) end) end, note)
      if not shown and not FT.ShowUpgradeCompare then
       showPopup('Daha iyi eşya', select(10, GetItemInfo(link)) or 'Interface\\Icons\\INV_Misc_QuestionMark', link, 'Tak', equip, function() declined[link] = true end)
      end
      return
     end
    end
   end
  end
 end
end

-- Kuşanma sonucunu doğrula: hedef yuvadaki eşya, istenen eşyayla aynı mı? (API yoksa doğrulanamaz: başarılı sayılır)
local function isEquipped(link, target)
 if not GetInventoryItemLink then return true end
 local now = GetInventoryItemLink('player', target)
 return now ~= nil and itemId(now) == itemId(link)
end

-- "Ruhuna bağlanır" onayı açıksa kabul et. Kullanıcı zaten "Tak" dedi; pencereyi gizlemek kuşanmayı iptal ederdi.
local function confirmBind()
 for i = 1, 4 do
  local f = _G['StaticPopup' .. i]
  if f and f.IsShown and f:IsShown() and (f.which == 'EQUIP_BIND' or f.which == 'AUTOEQUIP_BIND' or f.which == 'EQUIP_BIND_TRADEABLE') then
   if StaticPopup_OnClick then pcall(StaticPopup_OnClick, f, 1) elseif EquipPendingItem then pcall(EquipPendingItem, 0) end
   return true
  end
 end
 if EquipPendingItem then pcall(EquipPendingItem, 0) end
end

-- Çantadaki eşyayı hedef yuvaya tak. Yöntemler sırayla denenir ve her denemeden sonra sonuç doğrulanır:
-- takılmadıysa sıradaki yönteme geçilir; hiçbiri olmazsa eşya "ertelendi" sayılır ve kullanıcıya elle takması söylenir
-- (aksi halde aynı öneri sürekli yeniden açılırdı).
function FT.EquipFromBag(bag, slot, link, target)
 if InCombatLockdown and InCombatLockdown() then return FT.Print('Savaşta ekipman değiştirilemez.') end
 if CursorHasItem and CursorHasItem() then return FT.Print('İmlecinde bir eşya var; önce onu bırak, sonra tekrar dene.') end
 local methods = {
  function()
   local fn = (C_Item and C_Item.EquipItemByName) or EquipItemByName
   if not fn then return false end
   fn(link, target)
   return true
  end,
  function()
   local info = slotInfo(bag, slot)
   if not (info and info.link and itemId(info.link) == itemId(link)) then return false end
   useSlot(bag, slot)
   return true
  end,
 }
 local function attempt(i)
  if i > #methods then
   declined[link] = true
   FT.Print('Takılamadı: ' .. link .. ' - elle takabilirsin (çantadan sağ tık).')
   return
  end
  local ok, started = pcall(methods[i])
  if not ok or not started then return attempt(i + 1) end
  after(0.2, confirmBind)
  after(0.9, function()
   if isEquipped(link, target) then
    FT.Print('Takıldı: ' .. link)
    after(0.5, function() pcall(FT.ScanUpgrades) end)
   else attempt(i + 1) end
  end)
 end
 attempt(1)
end

local function scheduleScan()
 if scanPending then return end
 scanPending = true
 after(0.6, function() scanPending = false; pcall(FT.ScanUpgrades) end)
end

----------------------------------------------------------------------
-- Otomatik toplama ve çanta doluyken değiştirme önerisi
----------------------------------------------------------------------
local function lootValue(slot)
 local link = GetLootSlotLink and GetLootSlotLink(slot)
 if not link then return nil end
 local facts = itemFacts(link)
 local _, _, quantity, _, _, flagA, flagB = GetLootSlotInfo(slot)
 if type(quantity) ~= 'number' then quantity = 1 end
 if isQuestItem(facts) or flagA == true or flagB == true then return math.huge, link, true end
 return facts and facts.sellPrice * quantity or 0, link, false
end

-- En değersiz, görev dışı çanta eşyaları (ucuzdan pahalıya)
local function cheapBagItems(limit)
 local list = {}
 for bag = 0, lastBag() do
  for slot = 1, numSlots(bag) do
   local info = slotInfo(bag, slot)
   if info and info.link and not info.locked then
    local facts = itemFacts(info.link)
    if facts and not isQuestItem(facts) and (facts.quality or 0) <= 2 then
     list[#list + 1] = {bag=bag, slot=slot, value=facts.sellPrice * (info.count or 1), link=info.link, count=info.count}
    end
   end
  end
 end
 table.sort(list, function(a, b) return a.value < b.value end)
 for i = #list, (limit or 3) + 1, -1 do list[i] = nil end
 return list
end

local onLootReady
local function doSwap(victim, lootLink)
 if InCombatLockdown and InCombatLockdown() then return end
 local check = slotInfo(victim.bag, victim.slot)
 if not check or check.link ~= victim.link then return FT.Print('Eşya yerinde değil, değiştirme iptal.') end
 pickupSlot(victim.bag, victim.slot)
 if CursorHasItem and CursorHasItem() then DeleteCursorItem() end
 FT.Print(('Atıldı: %s  →  alındı: %s'):format(victim.link, lootLink))
 after(0.25, function()
  for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
   if GetLootSlotLink(i) == lootLink then LootSlot(i); break end
  end
  after(0.5, function() if onLootReady then pcall(onLootReady, true) end end)
 end)
end

local function offerSwap(slot, lootLink, value)
 if not enabled('swap') then return end
 local list = {}
 for _, v in ipairs(cheapBagItems(3)) do if v.value < value then list[#list + 1] = v end end
 if #list == 0 then return end
 if FT.ShowSwapCompare and FT.ShowSwapCompare(lootLink, value, list, function(v) doSwap(v, lootLink) end) then return end
 local victim = list[1]
 local icon = select(10, GetItemInfo(lootLink)) or 'Interface\\Icons\\INV_Misc_QuestionMark'
 local gain = value == math.huge and 'görev eşyası' or money(value)
 showPopup('Çanta dolu', icon, ('%s alınamıyor (%s).\n%s (%s) atılıp yerine alınsın mı?'):format(lootLink, gain, victim.link, money(victim.value)), 'Değiştir',
  function() doSwap(victim, lootLink) end)
end

onLootReady = function(again)
 local count = GetNumLootItems and GetNumLootItems() or 0
 if count == 0 then return end
 if enabled('autoloot') and not again then
  for i = count, 1, -1 do pcall(LootSlot, i) end
 end
 if freeSlots() > 0 then return end
 after(0.3, function()
  local best
  for i = 1, GetNumLootItems() do
   if LootSlotHasItem and LootSlotHasItem(i) then
    local value, link = lootValue(i)
    if value and link and value > 0 and (not best or value > best.value) then best = {i = i, link = link, value = value} end
   end
  end
  if best then offerSwap(best.i, best.link, best.value) end
 end)
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local events = CreateFrame('Frame')
for _, e in ipairs({'MERCHANT_SHOW', 'LOOT_READY', 'LOOT_CLOSED', 'BANKFRAME_OPENED', 'BAG_UPDATE_DELAYED', 'PLAYER_LEVEL_UP', 'GET_ITEM_INFO_RECEIVED', 'PLAYER_ENTERING_WORLD'}) do
 pcall(events.RegisterEvent, events, e)
end
events:SetScript('OnEvent', function(_, event)
 local ok, err = pcall(function()
  if event == 'MERCHANT_SHOW' then
   if enabled('autorepair') then autoRepair() end
   if enabled('autosell') then after(0.2, FT.SellJunk) end
  elseif event == 'LOOT_READY' then onLootReady()
  elseif event == 'LOOT_CLOSED' then
   if popup and popup:IsShown() and popup.title:GetText() == 'Çanta dolu' then popup:Hide() end
   if FT.swapCompare and FT.swapCompare:IsShown() then FT.swapCompare:Hide() end
  elseif event == 'BANKFRAME_OPENED' then
   ensureBankButton()
   if optedIn('banksort') then after(0.4, FT.SortBank) end
  elseif event == 'BAG_UPDATE_DELAYED' then scheduleMarks(); scheduleScan()
  elseif event == 'GET_ITEM_INFO_RECEIVED' then scheduleScan(); scheduleMarks()
  else scheduleScan() end
 end)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'gear: ' .. tostring(err) end
end)

for _, name in ipairs({'OpenAllBags', 'ToggleAllBags', 'ToggleBackpack', 'ToggleBag', 'OpenBag', 'ContainerFrame_Update'}) do
 if type(_G[name]) == 'function' then pcall(hooksecurefunc, name, scheduleMarks) end
end


----------------------------------------------------------------------
-- Eşya karşılaştırma ipucu: takılı olanla ilvl farkı
----------------------------------------------------------------------
local function compareLine(tip)
 if ForeverTrailSettings and ForeverTrailSettings.compare == false then return end
 local _, link = tip:GetItem()
 local facts = link and itemFacts(link)
 local slots = facts and SLOTS[facts.equipLoc]
 if not slots or (facts.classID ~= 2 and facts.classID ~= 4) then return end
 local lowest
 for _, slot in ipairs(slots) do
  local current, currentLink = equippedFacts(slot)
  if currentLink == link then return end
  local level = current and current.itemLevel or -1
  if not lowest or level < lowest then lowest = level end
 end
 local text
 if lowest < 0 then text = '|cff55ff55Yuva boş — takabilirsin|r'
 else
  local diff = facts.itemLevel - lowest
  local color = diff > 0 and '|cff55ff55▲ +' or (diff < 0 and '|cffff5555▼ ' or '|cffcccccc= ')
  text = ('%s%d ilvl|r  (takılı: %d)'):format(color, diff, lowest)
 end
 if facts.minLevel > (UnitLevel('player') or 1) then text = text .. ('  |cffff5555Sv %d gerekli|r'):format(facts.minLevel) end
 tip:AddLine('|cffffd100[ForeverTrail]|r ' .. text)
 if tip == GameTooltip and FT.ShowTip then FT.ShowTip(tip) else tip:Show() end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
 pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(tip) if tip == GameTooltip or tip == ItemRefTooltip then pcall(compareLine, tip) end end)
else
 for _, tip in ipairs({GameTooltip, ItemRefTooltip}) do
  if tip and tip.HookScript then pcall(tip.HookScript, tip, 'OnTooltipSetItem', function(self) pcall(compareLine, self) end) end
 end
end

-- Görev ödülü danışmanı için: eşya ne kadar yükseltme? (ilvl farkı, yoksa nil) ve satış değeri
function FT.ItemAdvice(link)
 local facts = itemFacts(link)
 if not facts then return nil, 0 end
 local slot, current, currentLink, mine = upgradeSlot(facts)
 local gain = nil
 if slot then
  if current < 0 then gain = facts.itemLevel else gain = math.max(1, math.floor(((mine or 0) - current) + 0.5)) end
 end
 return gain, facts.sellPrice or 0, facts
end
