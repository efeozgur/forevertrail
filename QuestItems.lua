local _, FT = ...

-- Görev eşyaları: korunur (otomatik satılmaz, satıcıya yanlışlıkla satılırsa geri alınır)
-- ve çantadan ayrı bir pencerede listelenir (/ftrail gorevesya).
-- Korunanlar: eşya türü "Görev", günlükteki görevlerin hedef/kaynak eşyaları, elle kilitlenenler (pencerede Shift+tık).

local C = C_Container
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local QUEST_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12

local function db() return FT.Module and FT.Module('QuestieDB') end
local function guardOn() return not ForeverTrailSettings or ForeverTrailSettings.questItemGuard ~= false end
local function lockedStore()
 if not ForeverTrailSettings then return {} end
 ForeverTrailSettings.lockedItems = ForeverTrailSettings.lockedItems or {}
 return ForeverTrailSettings.lockedItems
end

----------------------------------------------------------------------
-- Günlükteki görevlerin istediği eşyalar (5 sn önbellek)
----------------------------------------------------------------------
local needed, neededAt
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() needed = nil end

function FT.QuestItemSet()
 local now = GetTime and GetTime() or 0
 if needed and now - (neededAt or 0) < 5 then return needed end
 local set = {}
 local q, d = C_QuestLog, db()
 if q and q.GetNumQuestLogEntries and q.GetInfo and d and d.QueryQuestSingle then
  for i = 1, q.GetNumQuestLogEntries() do
   local info = q.GetInfo(i)
   if info and not info.isHeader and info.questID and info.questID > 0 then
    local okS, src = pcall(d.QueryQuestSingle, info.questID, 'sourceItemId')
    if okS and type(src) == 'number' and src > 0 then set[src] = true end
    local okO, obj = pcall(d.QueryQuestSingle, info.questID, 'objectives')
    if okO and type(obj) == 'table' and type(obj[3]) == 'table' then
     for _, it in ipairs(obj[3]) do
      if type(it) == 'table' and type(it[1]) == 'number' then set[it[1]] = true end
     end
    end
   end
  end
 end
 needed, neededAt = set, now
 return set
end

local function itemClass(itemID)
 if C_Item and C_Item.GetItemInfoInstant then
  local ok, _, _, _, _, icon, classID = pcall(C_Item.GetItemInfoInstant, itemID)
  if ok then return classID, icon end
 end
end

-- Kilitli (elle) ya da görev eşyası mı? classID biliniyorsa verilebilir.
function FT.IsProtectedItem(itemID, classID)
 if type(itemID) ~= 'number' then return false end
 if lockedStore()[itemID] then return true end
 if not guardOn() then return false end
 if (classID or itemClass(itemID)) == QUEST_CLASS then return true end
 return FT.QuestItemSet()[itemID] == true
end

----------------------------------------------------------------------
-- Satıcı: yanlışlıkla satılan korunan eşyayı geri al
----------------------------------------------------------------------
local MF = C_MerchantFrame
local function numBuyback() local f = (MF and MF.GetNumBuybackItems) or GetNumBuybackItems; return f and f() or 0 end
local function buybackLink(i) local f = (MF and MF.GetBuybackItemLink) or GetBuybackItemLink; return f and f(i) end
local function buyBack(i) local f = (MF and MF.BuybackItem) or BuybackItem; if f then f(i); return true end end

local rescued = 0
local function rescue()
 if not (MerchantFrame and MerchantFrame:IsShown()) or rescued >= 12 then return end
 for i = numBuyback(), 1, -1 do
  local link = buybackLink(i)
  local id = link and tonumber(tostring(link):match('item:(%d+)'))
  if id and FT.IsProtectedItem(id) then
   rescued = rescued + 1
   if pcall(buyBack, i) then
    FT.Print(('Korunan eşya satılmıştı, geri alındı: %s (kilidi açmak için /ftrail gorevesya, Shift+tık)'):format(tostring(link)))
   end
   return -- her satışta olay yeniden gelir; sıradaki bir sonraki olayda
  end
 end
end

----------------------------------------------------------------------
-- Çanttaki görev eşyaları listesi
----------------------------------------------------------------------
local function lastBag() return (NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 0) end

function FT.QuestBagItems()
 local list = {}
 if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return list end
 for bag = 0, lastBag() do
  for slot = 1, C.GetContainerNumSlots(bag) or 0 do
   local info = C.GetContainerItemInfo(bag, slot)
   if info and info.itemID then
    local classID, icon = itemClass(info.itemID)
    local locked = lockedStore()[info.itemID] and true or false
    local isQuest = (classID == QUEST_CLASS) or FT.QuestItemSet()[info.itemID] == true
    if isQuest or locked then
     local name = info.hyperlink and GetItemInfo and GetItemInfo(info.hyperlink) or nil
     list[#list + 1] = {bag = bag, slot = slot, itemID = info.itemID, count = info.stackCount or 1, icon = info.iconFileID or icon,
      name = name or ('Eşya ' .. info.itemID), link = info.hyperlink, locked = locked, quest = isQuest}
    end
   end
  end
 end
 table.sort(list, function(a, b) if a.name ~= b.name then return a.name < b.name end return a.itemID < b.itemID end)
 return list
end

local frame, rows = nil, {}
local MAX_ROWS = 18

local function build()
 local f = FT.NewWindow('ForeverTrailQuestItems', UIParent)
 f:SetSize(300, 100); f:SetPoint('CENTER', UIParent, 'CENTER', 260, 0)
 f:SetFrameStrata('DIALOG'); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
 f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart', function(self) self:StartMoving() end)
 f:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
 f.title = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 f.title:SetPoint('TOPLEFT', 14, -10); f.title:SetText('Görev eşyaları')
 if FT.StyleTitle then FT.StyleTitle(f.title) end
 f.hint = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 f.hint:SetPoint('TOPLEFT', 14, -30); f.hint:SetWidth(272); f.hint:SetJustifyH('LEFT')
 f.hint:SetText('Korunur: otomatik satılmaz, satılırsa geri alınır. Shift+tık: elle kilitle / aç.')
 f.empty = f:CreateFontString(nil, 'OVERLAY', 'GameFontDisable')
 f.empty:SetPoint('TOPLEFT', 14, -62); f.empty:SetText('Çantada görev eşyası yok.')
 f.more = f:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
 local close = FT.NewButton and FT.NewButton(f, 'Kapat', 80, 22) or CreateFrame('Button', nil, f, 'UIPanelButtonTemplate')
 close:SetSize(80, 22); close:SetPoint('BOTTOMRIGHT', -14, 10); if close.SetText and not FT.NewButton then close:SetText('Kapat') end
 close:SetScript('OnClick', function() f:Hide() end)
 f:Hide()
 return f
end

local function getRow(i)
 if rows[i] then return rows[i] end
 local r = CreateFrame('Button', nil, frame)
 r:SetSize(272, 24)
 r.icon = r:CreateTexture(nil, 'ARTWORK'); r.icon:SetSize(20, 20); r.icon:SetPoint('LEFT', 0, 0)
 r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
 r.text = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
 r.text:SetPoint('LEFT', r.icon, 'RIGHT', 6, 0); r.text:SetPoint('RIGHT', r, 'RIGHT', -56, 0)
 r.text:SetJustifyH('LEFT'); r.text:SetWordWrap(false)
 r.tag = r:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
 r.tag:SetPoint('RIGHT', 0, 0); r.tag:SetJustifyH('RIGHT')
 r.hl = r:CreateTexture(nil, 'HIGHLIGHT'); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 1, 1, 0.07)
 r:SetScript('OnClick', function(self)
  if IsShiftKeyDown and IsShiftKeyDown() and self.itemID then
   local store = lockedStore()
   store[self.itemID] = not store[self.itemID] or nil
   FT.RefreshQuestItems()
  end
 end)
 r:SetScript('OnEnter', function(self)
  if not (GameTooltip and self.bag) then return end
  GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
  if GameTooltip.SetBagItem then pcall(GameTooltip.SetBagItem, GameTooltip, self.bag, self.slot) end
  GameTooltip:Show()
 end)
 r:SetScript('OnLeave', function() if GameTooltip then GameTooltip:Hide() end end)
 rows[i] = r
 return r
end

function FT.RefreshQuestItems()
 if not (frame and frame:IsShown()) then return end
 local list = FT.QuestBagItems()
 for _, r in ipairs(rows) do r:Hide() end
 local y = 52
 for i = 1, math.min(MAX_ROWS, #list) do
  local e, r = list[i], getRow(i)
  r.bag, r.slot, r.itemID = e.bag, e.slot, e.itemID
  r:ClearAllPoints(); r:SetPoint('TOPLEFT', frame, 'TOPLEFT', 14, -y)
  r.icon:SetTexture(e.icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
  r.text:SetText(e.name .. (e.count > 1 and (' |cff9aa0a6x' .. e.count .. '|r') or ''))
  r.tag:SetText(e.locked and '|cffffd100Kilitli|r' or (e.quest and '|cff55ddffGörev|r' or ''))
  r:Show()
  y = y + 26
 end
 frame.empty:SetShown(#list == 0)
 if #list == 0 then y = y + 22 end
 frame.more:ClearAllPoints()
 if #list > MAX_ROWS then
  frame.more:SetPoint('TOPLEFT', frame, 'TOPLEFT', 14, -y); frame.more:SetText(('+%d eşya daha'):format(#list - MAX_ROWS)); frame.more:Show(); y = y + 16
 else
  frame.more:Hide()
 end
 frame:SetHeight(y + 44)
 if FT.FixFonts then pcall(FT.FixFonts, frame) end
end

function FT.ToggleQuestItems()
 if not frame then
  local ok, made = pcall(build)
  if not ok then FT.Print('Görev eşyaları penceresi açılamadı: ' .. tostring(made)); return end
  frame = made
 end
 if frame:IsShown() then frame:Hide() else frame:Show(); FT.RefreshQuestItems() end
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local ev = CreateFrame('Frame')
for _, e in ipairs({'MERCHANT_SHOW', 'MERCHANT_CLOSED', 'MERCHANT_UPDATE', 'BAG_UPDATE_DELAYED', 'QUEST_LOG_UPDATE'}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript('OnEvent', function(_, event)
 local ok, err = pcall(function()
  if event == 'MERCHANT_SHOW' then rescued = 0
  elseif event == 'MERCHANT_CLOSED' then rescued = 0
  elseif event == 'MERCHANT_UPDATE' then rescue()
  elseif event == 'QUEST_LOG_UPDATE' then needed = nil
  else
   rescue()
   if frame and frame:IsShown() then FT.RefreshQuestItems() end
  end
 end)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'görev eşyaları: ' .. tostring(err) end
end)
