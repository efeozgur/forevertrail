local _, FT = ...

-- Forever (Mainline altyapısı): eski global GetItemInfo olmayabilir; C_Item.GetItemInfo kullanılır
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)

-- Görev eşyası düğmesi, cesede yol, ocak taşı danışmanı, günlük temizliği,
-- dayanıklılık/ok uyarısı, zindan görevleri, dinlenmiş XP, panel görünümü.

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function after(t, fn) if C_Timer and C_Timer.After then C_Timer.After(t, fn) else fn() end end
local function combat() return InCombatLockdown and InCombatLockdown() end

----------------------------------------------------------------------
-- Görev eşyası düğmesi (kullanılabilir görev eşyası varsa ekranda)
----------------------------------------------------------------------
local itemButton, pendingItem
local QUEST_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12

local function findQuestItem()
 local q = C_QuestLog
 local step = FT.CurrentStep and FT.CurrentStep()
 -- 1) Görev günlüğünün kendi özel eşyası (istemci destekliyorsa), önce aktif adımın görevi
 if GetQuestLogSpecialItemInfo and q and q.GetNumQuestLogEntries then
  local fallback
  for i = 1, q.GetNumQuestLogEntries() do
   local ok, link, icon = pcall(GetQuestLogSpecialItemInfo, i)
   if ok and link then
    local info = q.GetInfo(i)
    if info and step and info.questID == step.questId then return link, icon end
    fallback = fallback or {link, icon}
   end
  end
  if fallback then return fallback[1], fallback[2] end
 end
 -- 2) Çantada kullanılabilen (büyüsü olan) görev eşyası
 local C = C_Container
 for bag = 0, NUM_BAG_SLOTS or 4 do
  local slots = (C and C.GetContainerNumSlots or GetContainerNumSlots)(bag) or 0
  for slot = 1, slots do
   local link
   if C and C.GetContainerItemInfo then local i = C.GetContainerItemInfo(bag, slot); link = i and i.hyperlink
   elseif GetContainerItemInfo then link = select(7, GetContainerItemInfo(bag, slot)) end
   if link then
    local _, _, _, _, _, _, _, _, _, icon, _, classID = GetItemInfo(link)
    if classID == QUEST_CLASS and GetItemSpell and GetItemSpell(link) then return link, icon end
   end
  end
 end
end

local function updateItemButton()
 if not itemButton then return end
 if combat() then pendingItem = true; return end
 pendingItem = false
 local link, icon = nil, nil
 if on('questitem') then link, icon = findQuestItem() end
 if not link then itemButton:Hide(); itemButton:SetAttribute('item', nil); return end
 local name = GetItemInfo(link)
 itemButton:SetAttribute('type', 'item')
 itemButton:SetAttribute('item', name)
 itemButton.icon:SetTexture(icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
 itemButton.link = link
 itemButton:Show()
end

local function createItemButton()
 if itemButton then return end
 itemButton = CreateFrame('Button', 'ForeverTrailQuestItem', UIParent, 'SecureActionButtonTemplate')
 itemButton:SetSize(40, 40)
 itemButton:SetPoint('TOP', FT.arrow or UIParent, FT.arrow and 'BOTTOM' or 'TOP', 0, FT.arrow and -6 or -300)
 itemButton:RegisterForClicks('AnyUp', 'AnyDown')
 itemButton:SetMovable(true); itemButton:RegisterForDrag('LeftButton')
 itemButton.icon = itemButton:CreateTexture(nil, 'ARTWORK'); itemButton.icon:SetAllPoints()
 itemButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
 itemButton:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square', 'ADD')
 itemButton.cd = CreateFrame('Cooldown', nil, itemButton, 'CooldownFrameTemplate'); itemButton.cd:SetAllPoints()
 local glow = itemButton:CreateTexture(nil, 'BACKGROUND')
 glow:SetTexture('Interface\\Cooldown\\star4'); glow:SetBlendMode('ADD'); glow:SetSize(70, 70); glow:SetPoint('CENTER')
 glow:SetVertexColor(1, 0.8, 0.3, 0.6)
 itemButton:SetScript('OnEnter', function(self)
  if self.link then GameTooltip:SetOwner(self, 'ANCHOR_RIGHT'); GameTooltip:SetHyperlink(self.link); GameTooltip:AddLine('Görev eşyası: tıkla ve kullan', 1, 0.85, 0.5); GameTooltip:Show() end
 end)
 itemButton:SetScript('OnLeave', function() GameTooltip:Hide() end)
 itemButton:SetScript('OnUpdate', function(self)
  if self.link and GetItemCooldown then
   local id = tonumber(self.link:match('item:(%d+)'))
   local start, duration = GetItemCooldown(id)
   if start and duration and duration > 1.5 then self.cd:SetCooldown(start, duration) end
  end
 end)
 itemButton:Hide()
end

----------------------------------------------------------------------
-- Ölünce cesede yol
----------------------------------------------------------------------
local function corpseRoute()
 if not on('corpse') or not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition and C_Map) then return end
 local map = C_Map.GetBestMapForUnit('player')
 if not map then return end
 local ok, pos = pcall(C_DeathInfo.GetCorpseMapPosition, map)
 if not ok or not pos then return end
 local x, y = pos:GetXY()
 if not x or (x == 0 and y == 0) then return end
 FT.corpseActive = true
 FT.SetCustomTarget(map, x, y, 'Cesedin')
end

local function corpseClear()
 if FT.corpseActive and FT.customTarget and FT.customTarget.questTitle == 'Cesedin' then
  FT.customTarget = nil
  if ForeverTrailCharacter then ForeverTrailCharacter.customTarget = nil end
  if FT.Refresh then FT.Refresh() end
 end
 FT.corpseActive = false
end

----------------------------------------------------------------------
-- Ocak taşı danışmanı
----------------------------------------------------------------------
local HEARTH = 6948
function FT.HearthInfo()
 local place = GetBindLocation and GetBindLocation() or '?'
 local start, duration = 0, 0
 if GetItemCooldown then start, duration = GetItemCooldown(HEARTH) end
 local left = (start and start > 0) and math.max(0, start + duration - GetTime()) or 0
 return place, left
end

local hearthWarned = false
local function hearthCheck()
 if not on('hearth') then return end
 local q = C_QuestLog
 if not (q and q.GetNumQuestLogEntries) then return end
 local total, ready = 0, 0
 for i = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(i)
  if info and not info.isHeader and info.questID and info.questID > 0 then
   total = total + 1
   if q.IsComplete and q.IsComplete(info.questID) then ready = ready + 1 end
  end
 end
 if total > 0 and ready == total then
  if hearthWarned then return end
  hearthWarned = true
  local place, left = FT.HearthInfo()
  if left <= 0 then FT.Alert(('Tüm görevlerin teslime hazır. Ocak taşıyla %s\'e dönebilirsin.'):format(place), true)
  else FT.Alert(('Tüm görevlerin hazır. Ocak taşı %d dk sonra hazır (%s); uçmak daha hızlı olabilir.'):format(math.ceil(left / 60), place), true) end
 else
  hearthWarned = false
 end
end

----------------------------------------------------------------------
-- Günlük temizliği ve zindan görevleri
----------------------------------------------------------------------
local function logEntries()
 local out, q, header = {}, C_QuestLog, nil
 if not (q and q.GetNumQuestLogEntries) then return out end
 for i = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(i)
  if info then
   if info.isHeader then header = info.title
   elseif info.questID and info.questID > 0 then info.header = header; out[#out + 1] = info end
  end
 end
 return out
end

function FT.ShowLogCleanup()
 local level = UnitLevel('player')
 local lines, entries = {}, logEntries()
 lines[1] = ('Günlükte %d / 20 görev.'):format(#entries)
 local found = 0
 for _, info in ipairs(entries) do
  if info.level and info.level > 0 and info.level <= level - 6 and not (C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)) then
   found = found + 1
   lines[#lines + 1] = ('|cff9d9d9d[%d] %s|r  — gri, az XP'):format(info.level, info.title)
  end
 end
 if found == 0 then lines[#lines + 1] = '|cff55ff55Bırakılacak gri görev yok.|r'
 else lines[#lines + 1] = ' '; lines[#lines + 1] = '|cff9aa0a6Bırakmak için görev günlüğünden "Bırak" de.|r' end
 FT.InfoWindow('Günlük temizliği', lines)
end

function FT.ShowDungeonQuests()
 local groups, order = {}, {}
 for _, info in ipairs(logEntries()) do
  local tag = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(info.questID)
  local dungeon = (tag and tag.tagName and tag.tagName:lower():find('dungeon')) or (info.suggestedGroup and info.suggestedGroup >= 5)
  if dungeon then
   local key = info.header or 'Zindan'
   if not groups[key] then groups[key] = {}; order[#order + 1] = key end
   table.insert(groups[key], info.title)
  end
 end
 local lines = {}
 for _, key in ipairs(order) do
  lines[#lines + 1] = ('|cffffd100%s: %d görev|r'):format(key, #groups[key])
  for _, t in ipairs(groups[key]) do lines[#lines + 1] = '  ' .. t end
 end
 if #lines == 0 then lines[1] = 'Günlüğünde zindan görevi yok.' end
 FT.InfoWindow('Zindan görevleri', lines)
end

local logWarned = 0
local function logFullCheck()
 local n = #logEntries()
 if n >= 18 and GetTime() - logWarned > 600 then
  logWarned = GetTime()
  FT.Alert(('Görev günlüğün dolmak üzere (%d/20). Menü > Günlük temizliği.'):format(n), true)
 end
end

----------------------------------------------------------------------
-- Dayanıklılık ve ok/mermi uyarısı
----------------------------------------------------------------------
local warnedAt = {}
local function offerShop(cat, text, key)
 if warnedAt[key] and GetTime() - warnedAt[key] < 900 then return end
 warnedAt[key] = GetTime()
 local place, distance = FT.NearestPlace and FT.NearestPlace(cat)
 if place and FT.ShowChoice and FT.ShowChoice(cat == 'Tamirci' and 'Tamir gerekli' or 'İhtiyaç', 'Interface\\Icons\\Trade_BlackSmithing',
  text .. ('\nEn yakın %s: %s%s'):format(cat:lower(), place.name, distance and (' (' .. math.floor(distance + 0.5) .. ' yd)') or ''),
  'Yol göster', function() FT.SetCustomTarget(place.map, place.x, place.y, place.name) end) then return end
 FT.Alert(text, true)
end

local function supplyCheck()
 if not on('supplies') or combat() then return end
 local lowest = 1
 for slot = 1, 18 do
  local cur, max = GetInventoryItemDurability and GetInventoryItemDurability(slot)
  if cur and max and max > 0 then lowest = math.min(lowest, cur / max) end
 end
 if lowest < 0.25 then offerShop('Tamirci', ('Ekipman dayanıklılığı %%%d.'):format(lowest * 100), 'repair') end
 local _, class = UnitClass('player')
 if class == 'HUNTER' and GetInventoryItemCount then
  local ammo = GetInventoryItemCount('player', 0) or 0
  if ammo > 0 and ammo < 200 then offerShop('Satıcı', ('Ok/mermi azaldı: %d kaldı.'):format(ammo), 'ammo') end
 end
end

----------------------------------------------------------------------
-- Dinlenmiş XP (görev kutusunun özet satırı için)
----------------------------------------------------------------------
function FT.RestedText()
 local rested = GetXPExhaustion and GetXPExhaustion()
 local max = UnitXPMax('player')
 if not rested or rested <= 0 or not max or max <= 0 then return nil end
 return ('|cff6fb7ffDinlenmiş: %d (%%%d)|r'):format(rested, rested / max * 100)
end

----------------------------------------------------------------------
-- Ana panel görünümü (görev kutusuyla uyumlu, sade)
----------------------------------------------------------------------
function FT.StylePanel()
 local f = FT.panel
 if not f then return end
 local path = FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF'
 local a = FT.Style.accent
 local function font(fs, size, flags)
  if fs then pcall(fs.SetFont, fs, path, size, flags or ''); fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.85) end
 end
 if f.title and FT.StyleTitle then FT.StyleTitle(f.title) end
 if FT.Kit then return end -- yeni Rehber paneli (Kit) yazı boyutlarını ve renklerini kendisi yönetir
 font(f.guide, 12, 'OUTLINE'); if f.guide then f.guide:SetTextColor(a[1], a[2], a[3]) end
 font(f.info, 11)
 font(f.instruction, 14)
 font(f.state, 12)
 if f.state then f.state:SetTextColor(0.86, 0.82, 0.74) end
 for _, t in ipairs({f.guideBg, f.boxBg, f.stateBg}) do if t then t:SetColorTexture(0, 0, 0, 0.28) end end
 if f.barBg then f.barBg:SetColorTexture(1, 1, 1, 0.1) end
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local events = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD', 'BAG_UPDATE_DELAYED', 'QUEST_LOG_UPDATE', 'PLAYER_REGEN_ENABLED',
 'PLAYER_DEAD', 'PLAYER_ALIVE', 'PLAYER_UNGHOST', 'UPDATE_INVENTORY_DURABILITY', 'MERCHANT_CLOSED', 'UNIT_INVENTORY_CHANGED'}) do
 pcall(events.RegisterEvent, events, e)
end
local questPending = false
events:SetScript('OnEvent', function(_, event, a)
 local ok, err = pcall(function()
  if event == 'PLAYER_LOGIN' then createItemButton(); after(1, FT.StylePanel)
  elseif event == 'PLAYER_ENTERING_WORLD' then
   createItemButton(); after(2, updateItemButton)
   if UnitIsGhost and UnitIsGhost('player') then after(1, corpseRoute) end
  elseif event == 'BAG_UPDATE_DELAYED' or event == 'PLAYER_REGEN_ENABLED' then
   if event == 'BAG_UPDATE_DELAYED' or pendingItem then updateItemButton() end
   if event == 'PLAYER_REGEN_ENABLED' then supplyCheck() end
  elseif event == 'QUEST_LOG_UPDATE' then
   if not questPending then
    questPending = true
    after(1, function() questPending = false; pcall(updateItemButton); pcall(hearthCheck); pcall(logFullCheck) end)
   end
  elseif event == 'PLAYER_DEAD' then after(1, corpseRoute)
  elseif event == 'PLAYER_ALIVE' then
   if UnitIsGhost and UnitIsGhost('player') then after(1, corpseRoute) else corpseClear() end
  elseif event == 'PLAYER_UNGHOST' then corpseClear()
  elseif event == 'UPDATE_INVENTORY_DURABILITY' or event == 'MERCHANT_CLOSED' then supplyCheck()
  elseif event == 'UNIT_INVENTORY_CHANGED' and a == 'player' then supplyCheck()
  end
 end)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'helpers: ' .. tostring(err) end
end)
