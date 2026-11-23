local _, FT = ...

local function module(name)
 if FT.Module then local own = FT.Module(name) if own then return own end end
 if not (QuestieLoader and QuestieLoader.ImportModule) then return nil end
 local ok, result = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
 if ok then return result end
end

----------------------------------------------------------------------
-- Yazı tipleri
----------------------------------------------------------------------
FT.Fonts = {
 {key='tr', name='WoWTR', path='Interface\\AddOns\\WoWTR\\Assets\\Fonts\\frizquadrata_tr.ttf'},
 {key='arial', name='Arial', path='Fonts\\ARIALN.TTF'},
}

local probe
local function usable(path)
 if type(path) ~= 'string' or path == '' then return false end
 probe = probe or UIParent:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 local ok, result = pcall(probe.SetFont, probe, path, 12, '')
 return ok and result ~= false
end

-- Türkçe harfleri (ş ğ ı İ) olan bir yazı tipi seç: istenen yoksa WoWTR, o da yoksa Arial
local function fontPath(key)
 for _, f in ipairs(FT.Fonts) do
  if f.key == key and usable(f.path) then return f.path end
 end
 if usable(FT.Fonts[1].path) then return FT.Fonts[1].path end
 if usable(WOWTR_Font2) then return WOWTR_Font2 end
 return 'Fonts\\ARIALN.TTF'
end
FT.FontPath = function() return fontPath(ForeverTrailSettings and ForeverTrailSettings.font or 'tr') end

local function walk(frame, path, depth)
 if not frame or depth > 9 then return end
 if frame.GetRegions then
  for _, region in ipairs({frame:GetRegions()}) do
   if region.GetObjectType and region:GetObjectType() == 'FontString' then
    local current, size, flags = region:GetFont()
    if size then
     local base = region.ftBase or size
     region.ftBase = base
     size = math.floor(base * (FT.Scale and FT.Scale('fontScale') or 1) + 0.5)
     if region:SetFont(path, size, flags or '') == false and current then region:SetFont(current, size, flags or '') end
     region:SetShadowOffset(1, -1); region:SetShadowColor(0, 0, 0, 0.8)
    end
   end
  end
 end
 if frame.GetChildren then
  for _, child in ipairs({frame:GetChildren()}) do walk(child, path, depth + 1) end
 end
end

function FT.ApplyFont(key)
 key = key or ForeverTrailSettings.font or 'tr'
 ForeverTrailSettings.font = key
 local path = fontPath(key)
 for _, f in ipairs({FT.panel, FT.card, FT.tracker, FT.settings, FT.arrow, FT.transfer, FT.dock, FT.upgradePopup, FT.placesWindow, FT.infoWindow, FT.menu, FT.hub}) do
  pcall(walk, f, path, 0)
 end
 for _, f in ipairs(FT.fontRoots or {}) do pcall(walk, f, path, 0) end
 if FT.FontObjects then pcall(FT.FontObjects) end
 if FT.flashFrame then pcall(FT.flashFrame.SetFont, FT.flashFrame, path, 20, 'OUTLINE') end
 local parts = FT.mapParts
 if parts then
  for _, name in ipairs({'label', 'caption'}) do
   local fs = parts[name]
   if fs then local _, size, flags = fs:GetFont(); if size then pcall(fs.SetFont, fs, path, size, flags or '') end end
  end
 end
end

function FT.CycleFont()
 local current = ForeverTrailSettings.font or 'tr'
 local nextIndex = 1
 for i, f in ipairs(FT.Fonts) do if f.key == current then nextIndex = i % #FT.Fonts + 1 end end
 FT.ApplyFont(FT.Fonts[nextIndex].key)
 FT.Print('Yazı tipi: ' .. FT.Fonts[nextIndex].name)
 return FT.Fonts[nextIndex].name
end

----------------------------------------------------------------------
-- Harita ipuçları
----------------------------------------------------------------------
local hover, elapsed, tipShown = CreateFrame('Frame'), 0, false
local typeNames = {accept='Görevi al', objective='Hedef', turnin='Teslim et', location='Konum', manual='Adım'}

local function describe(step)
 local lines = {}
 local record = type(QTR_QuestData) == 'table' and step.questId and QTR_QuestData[tostring(step.questId)]
 local title = step.questTitle or (type(record) == 'table' and record.Title)
 lines[1] = type(title) == 'string' and title ~= '' and title or 'Adım'
 lines[2] = (typeNames[step.type] or 'Adım') .. (step.text and (': ' .. step.text) or '')
 return lines
end

local function hideTip()
 if tipShown then GameTooltip:Hide(); tipShown = false end
end

hover:SetScript('OnUpdate', function(_, dt)
 elapsed = elapsed + dt
 if elapsed < 0.05 then return end
 elapsed = 0
 local parts = FT.mapParts
 if not (parts and parts.overlay and WorldMapFrame and WorldMapFrame:IsShown()) then return hideTip() end
 local overlay = parts.overlay
 local scale, left, top = overlay:GetEffectiveScale(), overlay:GetLeft(), overlay:GetTop()
 if not (scale and scale > 0 and left and top) then return hideTip() end
 local cx, cy = GetCursorPosition()
 local mx, my = cx / scale - left, top - cy / scale
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local best, bestDistance
 local found = {}
 local function consider(step)
  if step and step.x and step.y then
   local d = (step.x * w - mx) ^ 2 + (step.y * h - my) ^ 2
   if d <= 130 then
    found[#found + 1] = {step = step, d = d}
    if not bestDistance or d < bestDistance then best, bestDistance = step, d end
   end
  end
 end
 for _, dot in ipairs(FT.mapDots or {}) do if dot:IsShown() then consider(dot.step) end end
 for _, dot in ipairs(FT.nodeDots or {}) do if dot:IsShown() then consider(dot.step) end end
 for _, dot in ipairs(FT.partyDots or {}) do if dot:IsShown() then consider(dot.step) end end
 for _, dot in ipairs(FT.giverDots or {}) do if dot:IsShown() then consider(dot.step) end end
 for _, dot in ipairs(FT.objectiveIcons or {}) do if dot:IsShown() then consider(dot.step) end end
 for _, dot in ipairs(FT.stationDots or {}) do if dot:IsShown() then consider(dot.step) end end
 for _, dot in ipairs(FT.dungeonDots or {}) do if dot:IsShown() then consider(dot.step) end end
 for _, dot in ipairs(FT.townDots or {}) do if dot:IsShown() then consider(dot.step) end end
 for _, dot in ipairs(FT.rareDots or {}) do if dot:IsShown() then consider(dot.step) end end
 local active = FT.TargetStep and FT.TargetStep()
 if active and parts.marker and parts.marker:IsShown() and active.uiMapID == WorldMapFrame:GetMapID() then consider(active) end
 if not best then return hideTip() end
 table.sort(found, function(a, b) return a.d < b.d end)
 if FT.MapTooltip and FT.MapTooltip(found, describe) then tipShown = true; if best.npcId and FT.ShowTooltipModel then pcall(FT.ShowTooltipModel, best.npcId) end; return end
 local lines = describe(best)
 GameTooltip:SetOwner(WorldMapFrame, 'ANCHOR_CURSOR')
 GameTooltip:SetText(lines[1], 1, 0.85, 0.5)
 GameTooltip:AddLine(lines[2], 1, 1, 1, true)
 GameTooltip:AddLine('Rota için sol tık ile haritayı kullan; Ctrl+tık ile özel hedef.', 0.7, 0.7, 0.7, true)
 FT.ShowTip(GameTooltip)
 tipShown = true
end)

----------------------------------------------------------------------
-- XP / saat planlayıcı
----------------------------------------------------------------------
local function logXP()
 local xpDB, q = module('QuestXP'), C_QuestLog
 local total, count, ready = 0, 0, 0
 if not (xpDB and xpDB.db and xpDB.GetQuestLogRewardXP and q and q.GetNumQuestLogEntries and q.GetInfo) then return nil end
 for index = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(index)
  if info and not info.isHeader and info.questID and info.questID > 0 and xpDB.db[info.questID] then
   local ok, value = pcall(xpDB.GetQuestLogRewardXP, xpDB, info.questID, false)
   if ok and type(value) == 'number' then
    total, count = total + value, count + 1
    if q.IsComplete and q.IsComplete(info.questID) then ready = ready + value end
   end
  end
 end
 return total, count, ready
end

function FT.XPRate()
 local history = ForeverTrailCharacter and ForeverTrailCharacter.history or {}
 local now = time and time() or 0
 local first, sum, n = nil, 0, 0
 for _, e in ipairs(history) do
  if e.t and now - e.t <= 4 * 3600 and (e.xp or 0) > 0 then
   first = first and math.min(first, e.t) or e.t
   sum, n = sum + e.xp, n + 1
  end
 end
 if not first or n < 2 then return nil end
 local span = math.max(600, now - first)
 return sum / span * 3600, n
end

function FT.Plan()
 local level, xp, max = UnitLevel('player'), UnitXP('player'), UnitXPMax('player')
 local total, count, ready = logXP()
 if not total then return FT.Print('Plan için görev XP verisi okunamadı.') end
 local needed = max - xp
 FT.Print(('Günlükte %d görev: toplam +%d XP (%%%d seviye), teslime hazır +%d XP.'):format(count, total, math.floor(total / math.max(1, max) * 100), ready))
 if total >= needed then FT.Print(('Günlüğü bitirirsen %d. seviye tamamlanır (%d XP artar).'):format(level, total - needed))
 else FT.Print(('Seviye için %d XP daha lazım; günlük bunun %%%d\'ini karşılar.'):format(needed - total, math.floor(total / math.max(1, needed) * 100))) end
 local rate, n = FT.XPRate()
 if rate then
  local minutes = math.ceil(total / rate * 60)
  FT.Print(('Son teslimlerinden hızın ~%d XP/saat (%d teslim); günlük yaklaşık %d dk sürer.'):format(rate, n, minutes))
 else FT.Print('Hız tahmini için son 4 saatte en az 2 teslim gerekli.') end
end

----------------------------------------------------------------------
-- Ayarları dışa / içe aktarma
----------------------------------------------------------------------
function FT.ExportSettings()
 local parts = {'FT1'}
 local keys = {}
 for k, v in pairs(ForeverTrailSettings or {}) do
  if type(k) == 'string' and k:match('^%w+$') and (type(v) == 'boolean' or type(v) == 'number' or type(v) == 'string') and not tostring(v):find('[;=]') then keys[#keys + 1] = k end
 end
 table.sort(keys)
 for _, k in ipairs(keys) do
  local v = ForeverTrailSettings[k]
  parts[#parts + 1] = ('%s=%s:%s'):format(k, type(v):sub(1, 1), tostring(v))
 end
 return table.concat(parts, ';')
end

function FT.ImportSettings(text)
 if type(text) ~= 'string' or not text:match('^%s*FT1;') then return false, 'Geçersiz ayar metni.' end
 local applied = 0
 for entry in text:gmatch('[^;]+') do
  local k, t, v = entry:match('^(%w+)=(%a):(.*)$')
  if k then
   local value
   if t == 'b' then value = (v == 'true') elseif t == 'n' then value = tonumber(v) else value = v end
   if value ~= nil and k ~= 'pos' then ForeverTrailSettings[k] = value; applied = applied + 1 end
  end
 end
 if FT.ApplyTheme then FT.ApplyTheme(ForeverTrailSettings.theme) end
 FT.ApplyFont(ForeverTrailSettings.font)
 if FT.arrow then FT.arrow:SetScale(ForeverTrailSettings.arrowScale or 1) end
 if FT.SetCompact then FT.SetCompact(ForeverTrailSettings.compact == true) end
 if FT.RefreshMap then pcall(FT.RefreshMap) end
 return true, ('%d ayar alındı. Tam uygulama için /reload önerilir.'):format(applied)
end

local function createTransfer()
 local f = FT.NewWindow and FT.NewWindow('ForeverTrailTransfer', UIParent) or CreateFrame('Frame', 'ForeverTrailTransfer', UIParent, 'BasicFrameTemplateWithInset')
 FT.transfer = f
 f:SetSize(360, 120); f:SetPoint('CENTER'); f:SetFrameStrata('DIALOG')
 f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart', function(self) self:StartMoving() end)
 f:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
 local title = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 title:SetPoint('TOP', 0, -7); title:SetText('Ayarları aktar')
 local box = (FT.Kit and FT.Kit.Input(f) or CreateFrame('EditBox', nil, f, 'InputBoxTemplate'))
 box:SetSize(320, 22); box:SetPoint('TOP', 0, -38); box:SetAutoFocus(false); box:SetMaxLetters(0)
 box:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
 f.box = box
 local function btn(text, x, handler)
  local b = FT.NewButton and FT.NewButton(f, text, 100, 24)
  if not b then b = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate'); b:SetSize(100, 24); b:SetText(text) end
  b:SetPoint('BOTTOMLEFT', x, 14); b:SetScript('OnClick', handler)
 end
 btn('Dışa aktar', 24, function() box:SetText(FT.ExportSettings()); box:SetFocus(); box:HighlightText() end)
 btn('İçe aktar', 130, function()
  local ok, message = FT.ImportSettings(box:GetText())
  FT.Print(message)
 end)
 btn('Kapat', 236, function() f:Hide() end)
 f:Hide()
 FT.ApplyFont(ForeverTrailSettings.font)
end

function FT.ToggleTransfer()
 if not FT.transfer then createTransfer() end
 if FT.transfer:IsShown() then FT.transfer:Hide() else FT.transfer:Show() end
end

----------------------------------------------------------------------
-- Hızlı düğme çubuğu ve minimap düğmesi (komut yazmadan kullanım)
----------------------------------------------------------------------
local dock

local function togglePanel() if FT.ToggleHub then return FT.ToggleHub('rehber') end if FT.panel then if FT.panel:IsShown() then FT.panel:Hide() else FT.panel:Show() end end end

-- Ana şerit: en çok kullanılan 6 düğme, ikonlu
local primary = {
 {'Panel', 'Görev paneli', 'Interface\\Icons\\INV_Misc_Book_09', togglePanel},
 {'Harita', 'Hedefi haritada göster', 'Interface\\Icons\\INV_Misc_Map_01', function() FT.OpenMap() end},
 {'Yakın', 'En yakın adıma geç', 'Interface\\Icons\\Ability_Hunter_Pathfinding', function() FT.SelectNearest() end},
 {'Yerler', 'Nereye gitmek istersin? (uçuş, hizmet, meslek)', 'Interface\\Icons\\Ability_Mount_Gryphon_01', function() FT.TogglePlaces() end},
 {'Sessiz', 'Uyarıları 30 dakika sustur (tekrar bas: aç)', 'Interface\\Icons\\Spell_Holy_Silence', function() FT.ToggleSilent() end},
 {'Sınıf', 'Sınıf rehberi: yetenek planı, sınıf görevleri, evcil hayvan', 'Interface\\Icons\\INV_Misc_Book_11', function() FT.ToggleHub('sinif') end},
 {'Çanta', 'Çantayı düzenle', 'Interface\\Icons\\INV_Misc_Bag_08', function() FT.SortBags() end},
 {'Ayar', 'Ayarlar (sekmeli)', 'Interface\\Icons\\Trade_Engineering', function() FT.ToggleSettings() end},
}
-- "Daha fazla" menüsü
local more = {
 {'Hızlı ayarlar', function() FT.ToggleQuickSettings() end},
 {'Hedef kartı', function() FT.ToggleCard() end, function() return FT.card and FT.card:IsShown() end},
 {'Görev kutusu', function() FT.ToggleTracker() end, function() return FT.tracker and FT.tracker:IsShown() end},
 {'Yön oku', function() FT.ToggleArrow() end, function() return ForeverTrailSettings.arrow ~= false end},
 {'Rota oluştur', function() FT.BuildRoute() end},
 {'Daha iyi eşya ara', function() FT.ScanUpgrades() end},
 {'Gruba paylaş', function() if FT.ShareStep then FT.ShareStep() end end},
 {'Oturum özeti', function() FT.ShowSummary() end},
 {'Meslek rehberi', function() FT.ShowProfessionGuide() end},
 {'Yetenek önerisi', function() if FT.ShowTalentAdvice then FT.ShowTalentAdvice() end end},
 {'Günlük temizliği', function() FT.ShowLogCleanup() end},
 {'Zindan görevleri', function() FT.ShowDungeonQuests() end},
 {'Görev verisi', function() if FT.ToggleDataWindow then FT.ToggleDataWindow() end end},
 {'Rehber kaydı', function() if FT.ToggleRecorder then FT.ToggleRecorder() end end},
}

local ICON, GAP = 30, 4
local menu, lockButton

function FT.RefreshDock()
 if not dock then return end
 local a = FT.Style.accent
 for _, b in ipairs(dock.buttons or {}) do b.border:SetVertexColor(a[1], a[2], a[3], 0.9) end
 if lockButton then lockButton.icon:SetDesaturated(not ForeverTrailSettings.locked) end
 if menu and menu:IsShown() then
  for _, row in ipairs(menu.rows) do
   local check = row.def[3]
   if check then row:GetFontString():SetTextColor(check() and 1 or 0.6, check() and 0.9 or 0.58, check() and 0.6 or 0.55) end
  end
 end
end

function FT.ToggleLock()
 ForeverTrailSettings.locked = not ForeverTrailSettings.locked
 ForeverTrailSettings.arrowLocked = ForeverTrailSettings.locked
 FT.Print(ForeverTrailSettings.locked and 'Arayüz kilitlendi.' or 'Arayüz kilidi açıldı: sürükleyerek taşıyabilirsin.')
 FT.RefreshDock()
end

local function iconButton(parent, texture, tip, handler)
 local b = CreateFrame('Button', nil, parent)
 b:SetSize(ICON, ICON)
 b.icon = b:CreateTexture(nil, 'ARTWORK')
 b.icon:SetPoint('TOPLEFT', 2, -2); b.icon:SetPoint('BOTTOMRIGHT', -2, 2)
 b.icon:SetTexture(texture); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
 b.border = b:CreateTexture(nil, 'BACKGROUND')
 b.border:SetAllPoints(); b.border:SetColorTexture(1, 1, 1, 1)
 b:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square', 'ADD')
 b:SetPushedTexture('Interface\\Buttons\\UI-Quickslot-Depress')
 b:SetScript('OnClick', function()
  local ok, err = pcall(handler)
  if not ok then FT.Print('Hata: ' .. tostring(err)) end
  FT.RefreshDock()
 end)
 b:SetScript('OnEnter', function(self)
  GameTooltip:SetOwner(self, 'ANCHOR_TOP')
  GameTooltip:SetText(tip, 1, 0.85, 0.5)
  FT.ShowTip(GameTooltip)
 end)
 b:SetScript('OnLeave', function() GameTooltip:Hide() end)
 return b
end

local function buildMenu()
 menu = CreateFrame('Frame', 'ForeverTrailMenu', UIParent)
 FT.menu = menu
 menu:SetFrameStrata('DIALOG'); menu:SetClampedToScreen(true)
 if FT.SoftBackdrop then pcall(FT.SoftBackdrop, menu) end
 menu.rows = {}
 for i, def in ipairs(more) do
  local b = FT.NewButton(menu, def[1], 150, 22)
  b:SetPoint('TOPLEFT', 8, -8 - (i - 1) * 24)
  b.def = def
  b:SetScript('OnClick', function()
   local ok, err = pcall(def[2])
   if not ok then FT.Print('Hata: ' .. tostring(err)) end
   if def[3] then FT.RefreshDock() else menu:Hide() end
  end)
  menu.rows[i] = b
 end
 menu:SetSize(166, 16 + #more * 24)
 menu:Hide()
 FT.ApplyFont(ForeverTrailSettings.font)
end

function FT.CreateDock()
 if dock then return end
 dock = CreateFrame('Frame', 'ForeverTrailDock', UIParent)
 FT.dock = dock
 dock:SetMovable(true); dock:EnableMouse(true); dock:SetClampedToScreen(true)
 dock:RegisterForDrag('LeftButton')
 dock:SetScript('OnDragStart', function(self) if not ForeverTrailSettings.locked then self:StartMoving() end end)
 dock:SetScript('OnDragStop', function(self)
  self:StopMovingOrSizing()
  local point, _, relative, x, y = self:GetPoint()
  ForeverTrailSettings.dockPoint = {point, relative, x, y}
 end)
 if ForeverTrailSettings.dockLayout ~= 3 then ForeverTrailSettings.dockPoint = nil; ForeverTrailSettings.dockLayout = 3 end
 local p = ForeverTrailSettings.dockPoint
 if p and p[1] and p[2] and p[3] and p[4] then dock:SetPoint(p[1], UIParent, p[2], p[3], p[4])
 else dock:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', 6, 230) end
 if FT.SoftBackdrop then pcall(FT.SoftBackdrop, dock) end
 dock.buttons = {}
 local x = 8
 for _, def in ipairs(primary) do
  local b = iconButton(dock, def[3], def[2], def[4])
  b:SetPoint('LEFT', x, 0); x = x + ICON + GAP
  dock.buttons[#dock.buttons + 1] = b
 end
 local moreButton = iconButton(dock, 'Interface\\Icons\\INV_Misc_Note_01', 'Araçlar', function()
  if FT.ToggleHub then return FT.ToggleHub('araclar') end
  if not menu then buildMenu() end
  if menu:IsShown() then menu:Hide() return end
  menu:ClearAllPoints(); menu:SetPoint('BOTTOMLEFT', dock, 'TOPLEFT', 0, 4)
  menu:Show(); FT.RefreshDock()
 end)
 moreButton:SetPoint('LEFT', x, 0); x = x + ICON + GAP + 6
 dock.buttons[#dock.buttons + 1] = moreButton
 lockButton = iconButton(dock, 'Interface\\Icons\\INV_Misc_Key_03', 'Kilit: ok, görev kutusu ve şeridi sabitle', function() FT.ToggleLock() end)
 lockButton:SetSize(20, 20); lockButton:SetPoint('LEFT', x, 0); x = x + 24
 dock.buttons[#dock.buttons + 1] = lockButton
 dock:SetSize(x + 4, ICON + 12)
 FT.RefreshDock()
 if ForeverTrailSettings.dock == false or ForeverTrailSettings.simple then dock:Hide() end
end

function FT.ToggleDock()
 if not dock then return end
 ForeverTrailSettings.dock = not dock:IsShown()
 if ForeverTrailSettings.dock then dock:Show() else dock:Hide(); if menu then menu:Hide() end end
end

-- Sade görünüm: yalnızca yön oku ve görev kutusu; geri kalan minimap düğmesinden
function FT.ApplySimple()
 local simple = ForeverTrailSettings.simple == true
 local s = ForeverTrailSettings
 local function set(f, v) if f then if v then f:Show() else f:Hide() end end end
 set(FT.dock, not simple and s.dock ~= false)
 set(FT.card, not simple and s.card ~= false)
 if simple and FT.panel then FT.panel:Hide() end
 if menu then menu:Hide() end
 FT.Print(simple and 'Sade görünüm: düğmeler minimap düğmesinde (sol tık panel, sağ tık menü).' or 'Tam görünüm açıldı.')
end

function FT.CreateMinimapButton()
 if FT.minimapButton or not Minimap then return end
 local b = CreateFrame('Button', 'ForeverTrailMinimapButton', Minimap)
 FT.minimapButton = b
 b:SetSize(28, 28); b:SetFrameStrata('MEDIUM'); b:SetFrameLevel(8)
 b:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
 b:RegisterForDrag('LeftButton')
 local ring = b:CreateTexture(nil, 'OVERLAY')
 ring:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder'); ring:SetSize(52, 52); ring:SetPoint('TOPLEFT')
 local icon = b:CreateTexture(nil, 'ARTWORK')
 icon:SetTexture('Interface\\Icons\\INV_Misc_Map_01'); icon:SetSize(18, 18); icon:SetPoint('CENTER', 0, 1)
 b:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
 local function place(angle)
  local radius = (Minimap:GetWidth() / 2) + 5
  b:ClearAllPoints()
  b:SetPoint('CENTER', Minimap, 'CENTER', math.cos(angle) * radius, math.sin(angle) * radius)
 end
 place(ForeverTrailSettings.mmAngle or math.rad(215))
 b:SetScript('OnDragStart', function(self)
  self:SetScript('OnUpdate', function()
   local mx, my = Minimap:GetCenter()
   local scale = Minimap:GetEffectiveScale()
   local cx, cy = GetCursorPosition()
   local angle = math.atan2(cy / scale - my, cx / scale - mx)
   ForeverTrailSettings.mmAngle = angle
   place(angle)
  end)
 end)
 b:SetScript('OnDragStop', function(self) self:SetScript('OnUpdate', nil) end)
 b:SetScript('OnClick', function(_, button)
  if button == 'RightButton' and IsShiftKeyDown and IsShiftKeyDown() then FT.ToggleSettings()
  elseif button == 'RightButton' then
   if FT.ToggleHub then return FT.ToggleHub('araclar') end
   if not menu then buildMenu() end
   if menu:IsShown() then menu:Hide() else menu:ClearAllPoints(); menu:SetPoint('TOPRIGHT', Minimap, 'BOTTOMLEFT', 0, 0); menu:Show(); FT.RefreshDock() end
  else togglePanel() end
 end)
 b:SetScript('OnEnter', function(self)
  GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
  GameTooltip:SetText('ForeverTrail', 1, 0.85, 0.5)
  GameTooltip:AddLine('Sol tık: paneli aç/kapat', 1, 1, 1)
  GameTooltip:AddLine('Sağ tık: araçlar', 1, 1, 1)
  GameTooltip:AddLine('Shift + sağ tık: ayarlar', 1, 1, 1)
  GameTooltip:AddLine('Sürükle: düğmeyi minimap çevresinde taşı', 0.7, 0.7, 0.7)
  FT.ShowTip(GameTooltip)
 end)
 b:SetScript('OnLeave', function() GameTooltip:Hide() end)
end


----------------------------------------------------------------------
-- İpuçlarında Türkçe harfler: gösterirken yazı tipini değiştir, kapanınca eski haline getir
----------------------------------------------------------------------
local savedFonts, hooked = {}, false
function FT.ShowTip(tip)
 tip = tip or GameTooltip
 tip:Show()
 local path = FT.FontPath()
 local name = tip:GetName()
 if not name then return end
 for i = 1, tip:NumLines() do
  for _, side in ipairs({'Left', 'Right'}) do
   local line = _G[name .. 'Text' .. side .. i]
   if line then
    local current, size, flags = line:GetFont()
    local key = name .. side .. i
    if size and not savedFonts[key] then savedFonts[key] = {line, current, size, flags} end
    if size then pcall(line.SetFont, line, path, size, flags or '') end
   end
  end
 end
 tip:Show()
 if not hooked then
  hooked = true
  tip:HookScript('OnHide', function()
   for key, saved in pairs(savedFonts) do
    pcall(saved[1].SetFont, saved[1], saved[2], saved[3], saved[4] or '')
    savedFonts[key] = nil
   end
  end)
 end
end


----------------------------------------------------------------------
-- Giriş ve ara noktalar: önce mağara/bina kapısına, sonra içeriye
----------------------------------------------------------------------
-- Yol çizme: Alt+sol tık nokta ekler (var olan noktaya Alt+tık siler), Ctrl+sol tık son hedef.
-- Yol karakter başına kaydedilir, görev adımı değişince silinmez. /ftrail geri: son noktayı geri al, /ftrail ara: temizle.
local function pathStore()
 ForeverTrailCharacter = ForeverTrailCharacter or {}
 local p = ForeverTrailCharacter.path
 if type(p) ~= 'table' or type(p.points) ~= 'table' then p = {points = {}, passed = 0}; ForeverTrailCharacter.path = p end
 p.passed = math.max(0, math.min(p.passed or 0, #p.points))
 return p
end

local function syncVia()
 local p = pathStore()
 FT.via = {}
 for i = p.passed + 1, #p.points do FT.via[#FT.via + 1] = p.points[i] end
 if FT.RefreshMap then pcall(FT.RefreshMap) end
end

function FT.PathPoints()
 local p = pathStore()
 return p.points, p.passed
end

function FT.AddVia(map, x, y)
 local p = pathStore()
 for i, pt in ipairs(p.points) do
  if pt.uiMapID == map and math.abs(pt.x - x) < 0.012 and math.abs(pt.y - y) < 0.012 then
   table.remove(p.points, i)
   if i <= p.passed then p.passed = p.passed - 1 end
   FT.Print(('Yol noktası %d silindi.'):format(i))
   return syncVia()
  end
 end
 p.points[#p.points + 1] = {uiMapID = map, x = x, y = y}
 FT.Print(('Yol noktası %d eklendi. (Alt+tık: sil, Ctrl+tık: son hedef, /ftrail geri: geri al, /ftrail ara: temizle)'):format(#p.points))
 syncVia()
end

function FT.UndoVia()
 local p = pathStore()
 if #p.points == 0 then return FT.Print('Yolda nokta yok.') end
 table.remove(p.points)
 p.passed = math.min(p.passed, #p.points)
 FT.Print(('Son nokta geri alındı (%d nokta kaldı).'):format(#p.points))
 syncVia()
end

function FT.ClearVia(quiet)
 local p = pathStore()
 p.points, p.passed = {}, 0
 if not quiet then FT.Print('Yol temizlendi.') end
 syncVia()
end

-- Ok sıradaki noktaya varınca
function FT.PassVia()
 local p = pathStore()
 p.passed = math.min(#p.points, p.passed + 1)
 if p.passed >= #p.points then FT.Alert('Yolun sonuna vardın', true)
 else FT.Alert(('Ara nokta %d/%d geçildi'):format(p.passed, #p.points), true) end
 syncVia()
end

function FT.ViaTarget(playerMap, step)
 local p = pathStore()
 local pt = p.points[p.passed + 1]
 if not pt or pt.uiMapID ~= playerMap then return nil end
 return {uiMapID = pt.uiMapID, x = pt.x, y = pt.y, type = 'location', stepId = 'via:' .. (p.passed + 1),
  hint = ('Yol noktası %d/%d'):format(p.passed + 1, #p.points), via = true}
end

-- Son hedef yoksa yolun son noktası hedef olur
function FT.PathEndStep()
 local p = pathStore()
 local last = p.points[#p.points]
 if not last or p.passed >= #p.points then return nil end
 return {uiMapID = last.uiMapID, x = last.x, y = last.y, type = 'location', stepId = 'pathend', questTitle = 'Yolun sonu', pathEnd = true}
end

do
 local f = CreateFrame('Frame')
 f:RegisterEvent('PLAYER_LOGIN')
 f:SetScript('OnEvent', function() pcall(syncVia) end)
end

local function parentOf(map)
 if not (C_Map and C_Map.GetMapInfo and map) then return nil end
 local ok, info = pcall(C_Map.GetMapInfo, map)
 local parent = ok and info and info.parentMapID
 if parent and parent ~= 0 then return parent end
end

function FT.MapAncestor(map, ancestor)
 local guard = 0
 map = parentOf(map)
 while map and guard < 8 do
  if map == ancestor then return true end
  map = parentOf(map); guard = guard + 1
 end
 return false
end

local entranceCache = {}
-- Oyuncu dış haritadaysa ve hedef bir alt haritadaysa (mağara, bina), giriş noktasını bulur.
function FT.EntranceTo(playerMap, targetMap)
 if not (C_Map and C_Map.GetMapLinksForMap and playerMap and targetMap) then return nil end
 local key = playerMap .. ':' .. targetMap
 if entranceCache[key] ~= nil then return entranceCache[key] or nil end
 local chain, map, guard = {}, targetMap, 0
 while map and guard < 8 do
  chain[#chain + 1] = map
  map = parentOf(map); guard = guard + 1
 end
 local result = false
 for i = 2, #chain do
  if chain[i] == playerMap then
   local child = chain[i - 1]
   local ok, links = pcall(C_Map.GetMapLinksForMap, playerMap)
   if ok and type(links) == 'table' then
    for _, link in ipairs(links) do
     if link.linkedUiMapID == child and link.position then
      local got, x, y = pcall(function() return link.position:GetXY() end)
      if not got or type(x) ~= 'number' then x, y = link.position.x, link.position.y end
      if type(x) == 'number' and type(y) == 'number' then
       result = {uiMapID=playerMap, x=x, y=y, type='location', stepId='giris:' .. child, hint='Giriş: ' .. (link.name or '?')}
       break
      end
     end
    end
   end
   break
  end
 end
 entranceCache[key] = result
 return result or nil
end


----------------------------------------------------------------------
-- Çerçeve (halka) çizimi ve görev alanı yarıçapı
----------------------------------------------------------------------
function FT.DrawRing(pool, parent, relativeTo, point, cx, cy, radius, r, g, b, a)
 local segments = 28
 for i = 1, segments do
  local line = pool[i]
  if not line then
   line = parent:CreateLine(nil, 'OVERLAY')
   line:SetThickness(2)
   pool[i] = line
  end
  local a1, a2 = (i - 1) / segments * 2 * math.pi, i / segments * 2 * math.pi
  line:SetColorTexture(r, g, b, a)
  line:SetStartPoint(point, relativeTo, cx + math.cos(a1) * radius, cy + math.sin(a1) * radius)
  line:SetEndPoint(point, relativeTo, cx + math.cos(a2) * radius, cy + math.sin(a2) * radius)
  line:Show()
 end
end

function FT.HideRing(pool)
 for _, line in ipairs(pool) do line:Hide() end
end

local areaCache = {}
-- Hedef noktanın çevresindeki yaratık/nesne dağılımına göre görev alanı yarıçapı (yard)
function FT.AreaRadiusYards(step)
 if not step or step.type ~= 'objective' or not FT.SpawnPoints or not step.uiMapID or not step.x then return 25 end
 local cached = areaCache[step]
 if cached and GetTime() - cached.t < 10 then return cached.v end
 local value = 25
 local ok, points = pcall(FT.SpawnPoints, step)
 if ok and type(points) == 'table' and #points > 1 and C_Map and C_Map.GetMapWorldSize then
  local sized, wy, hy = pcall(C_Map.GetMapWorldSize, step.uiMapID)
  if sized and wy and wy > 0 and hy and hy > 0 then
   local far = 0
   for _, p in ipairs(points) do
    if p.map == step.uiMapID then
     local dx, dy = (p.x - step.x) * wy, (p.y - step.y) * hy
     local d = math.sqrt(dx * dx + dy * dy)
     if d <= 90 and d > far then far = d end
    end
   end
   value = math.max(25, math.min(90, far + 10))
  end
 end
 areaCache[step] = {t=GetTime(), v=value}
 return value
end

----------------------------------------------------------------------
-- Görev yaratığı uyarısı: ipucu satırı, isim plakası işareti, hedef çerçevesi bandı
----------------------------------------------------------------------
local monsterCache, monsterT = {}, -10
local dropCache, dropT = {}, -100
local dropNames = {} -- yaratık adı -> aynı kayıt (GUID gizliyse ad ile eşleştirmek için)

local function monsterObjectives()
 local now = GetTime()
 if now - monsterT < 1.5 then return monsterCache end
 monsterT, monsterCache = now, {}
 local q = C_QuestLog
 if not (q and q.GetNumQuestLogEntries and q.GetInfo and q.GetQuestObjectives) then return monsterCache end
 for i = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(i)
  if info and not info.isHeader and info.questID and info.questID > 0 then
   local ok, rows = pcall(q.GetQuestObjectives, info.questID)
   if ok and type(rows) == 'table' then
    for _, r in ipairs(rows) do
     if r.type == 'monster' and not r.finished and type(r.text) == 'string' then
      monsterCache[#monsterCache + 1] = {questId=info.questID, text=r.text, title=info.title, have=r.numFulfilled or 0, need=r.numRequired or 0}
     end
    end
   end
  end
 end
 return monsterCache
end

-- npcId -> {title, have, need}: eşya toplama görevlerinde eşyayı düşüren yaratıklar
local function dropperMap()
 local now = GetTime()
 if now - dropT < 20 then return dropCache end
 dropT, dropCache, dropNames = now, {}, {}
 local db = module('QuestieDB')
 local q = C_QuestLog
 if not (db and db.QueryQuestSingle and db.QueryItemSingle and q and q.GetNumQuestLogEntries and q.GetInfo and q.GetQuestObjectives) then return dropCache end
 for i = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(i)
  if info and not info.isHeader and info.questID and info.questID > 0 then
   local ok, rows = pcall(q.GetQuestObjectives, info.questID)
   local pending
   if ok and type(rows) == 'table' then
    for _, r in ipairs(rows) do if r.type == 'item' and not r.finished then pending = r; break end end
   end
   if pending then
    local good, raw = pcall(db.QueryQuestSingle, info.questID, 'objectives')
    local items = good and type(raw) == 'table' and raw[3]
    if type(items) == 'table' then
     for _, row in ipairs(items) do
      if type(row) == 'table' and type(row[1]) == 'number' then
       local got, drops = pcall(db.QueryItemSingle, row[1], 'npcDrops')
       if got and type(drops) == 'table' then
        for _, npc in ipairs(drops) do
         if type(npc) == 'number' then
          local entry = {questId=info.questID, title=info.title, have=pending.numFulfilled or 0, need=pending.numRequired or 0, text=pending.text, itemId=row[1]}
          dropCache[npc] = entry
          if db.QueryNPCSingle then
           local okN, npcName = pcall(db.QueryNPCSingle, npc, 'name')
           if okN and type(npcName) == 'string' and npcName ~= '' then dropNames[npcName] = entry end
          end
         end
        end
       end
      end
     end
    end
   end
  end
 end
 return dropCache
end

-- bypass: "yaratık uyarısı" kapalı olsa da bilgiyi ver (isim plakasındaki eşya resmi için)
function FT.QuestCreatureInfo(unit, bypass)
 if not bypass and ForeverTrailSettings and ForeverTrailSettings.creaturewarn == false then return nil end
 if not (unit and UnitExists(unit)) or UnitIsPlayer(unit) or UnitIsDead(unit) then return nil end
 if UnitIsFriend and UnitIsFriend('player', unit) then return nil end
 -- ad ve GUID "gizli değer" olabilir; o zaman o yoldan eşleştirme yapılmaz, çökme olmaz
 local name = FT.Plain(UnitName(unit))
 if name and name ~= '' then
  for _, o in ipairs(monsterObjectives()) do
   if o.text:find(name, 1, true) then return o end
  end
 end
 local guid = UnitGUID and FT.Plain(UnitGUID(unit))
 if type(guid) == 'string' then
  local npcId = tonumber((select(6, strsplit('-', guid))))
  local d = npcId and dropperMap()[npcId]
  if d then return d end
 end
 -- GUID okunamadıysa (gizli değer) adıyla eşleştir
 if name and name ~= '' then
  dropperMap()
  local d = dropNames[name]
  if d then return d end
 end
end

-- Görevin istediği eşyanın resmi (yoksa nil)
local function itemIconOf(itemId)
 if type(itemId) ~= 'number' then return nil end
 if C_Item and C_Item.GetItemIconByID then
  local ok, icon = pcall(C_Item.GetItemIconByID, itemId)
  if ok and icon then return icon end
 end
 if C_Item and C_Item.GetItemInfoInstant then
  local ok, _, _, _, _, icon = pcall(C_Item.GetItemInfoInstant, itemId)
  if ok and icon then return icon end
 end
 if GetItemIcon then local ok, icon = pcall(GetItemIcon, itemId); if ok then return icon end end
end
FT.ItemIconOf = itemIconOf

local function itemNameOf(itemId)
 if C_Item and C_Item.GetItemNameByID then local ok, n = pcall(C_Item.GetItemNameByID, itemId); if ok and n then return n end end
 if GetItemInfo then local ok, n = pcall(GetItemInfo, itemId); if ok and n then return n end end
end

local function addTooltipLine(tip)
 local _, unit = tip:GetUnit()
 local o = unit and FT.QuestCreatureInfo(unit)
 if o then
  tip:AddLine(('|cffffd100[ForeverTrail]|r Görev hedefi: %s (%d/%d)'):format(o.title or '?', o.have, o.need))
  local icon, name = itemIconOf(o.itemId), o.itemId and itemNameOf(o.itemId)
  if icon then tip:AddLine(('|T%s:16:16:0:0:64:64:5:59:5:59|t %s'):format(tostring(icon), name or 'Görev eşyası'), 1, 0.92, 0.75) end
  local partyText = FT.PartyText and o.questId and FT.PartyText(o.questId)
  if partyText then tip:AddLine(partyText, 0.55, 0.8, 1) end
  if tip == GameTooltip and FT.ShowTip then FT.ShowTip(tip) end
  tip:Show()
 end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
 pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tip) if tip == GameTooltip then addTooltipLine(tip) end end)
elseif GameTooltip and GameTooltip.HookScript then
 pcall(GameTooltip.HookScript, GameTooltip, 'OnTooltipSetUnit', addTooltipLine)
end

-- Hedef çerçevesi rozeti: görev adı, hedef, ilerleme çubuğu
local banner
local BLOB = 'Interface\\CHARACTERFRAME\\TempPortraitAlphaMask'
local function iconFor(o) return (FT.ObjectiveIcons and FT.ObjectiveIcons[o.kind or 'kill']) or 'Interface\\GossipFrame\\IncompleteQuestIcon' end
local function ensureBanner()
 if banner then return banner end
 banner = CreateFrame('Frame', 'ForeverTrailTargetBanner', UIParent)
 banner:SetSize(220, 40)
 banner:SetPoint('TOP', TargetFrame or UIParent, TargetFrame and 'BOTTOM' or 'TOP', 10, TargetFrame and -2 or -120)
 if FT.SoftBackdrop then pcall(FT.SoftBackdrop, banner) end
 banner.ring = banner:CreateTexture(nil, 'BORDER'); banner.ring:SetTexture(BLOB); banner.ring:SetSize(32, 32); banner.ring:SetPoint('LEFT', 5, 0)
 banner.icon = banner:CreateTexture(nil, 'ARTWORK'); banner.icon:SetSize(22, 22); banner.icon:SetPoint('CENTER', banner.ring, 'CENTER')
 banner.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
 banner.title = banner:CreateFontString(nil, 'OVERLAY'); banner.title:SetPoint('TOPLEFT', banner.ring, 'TOPRIGHT', 6, 0); banner.title:SetPoint('RIGHT', -44, 0)
 banner.title:SetJustifyH('LEFT'); banner.title:SetWordWrap(false)
 banner.count = banner:CreateFontString(nil, 'OVERLAY'); banner.count:SetPoint('TOPRIGHT', -8, -6)
 banner.barBg = banner:CreateTexture(nil, 'ARTWORK'); banner.barBg:SetColorTexture(1, 1, 1, 0.12)
 banner.barBg:SetPoint('BOTTOMLEFT', banner.ring, 'BOTTOMRIGHT', 6, 3); banner.barBg:SetPoint('RIGHT', -8, 0); banner.barBg:SetHeight(5)
 banner.bar = banner:CreateTexture(nil, 'OVERLAY'); banner.bar:SetPoint('LEFT', banner.barBg, 'LEFT'); banner.bar:SetHeight(5)
 local path = FT.FontPath()
 banner.title:SetFont(path, 11, ''); banner.count:SetFont(path, 13, 'OUTLINE')
 banner.title:SetShadowOffset(1, -1); banner.count:SetShadowOffset(1, -1)
 banner:Hide()
 return banner
end

local function updateBanner()
 local o = FT.QuestCreatureInfo('target')
 if not o then if banner then banner:Hide() end return end
 local b = ensureBanner()
 local c = o.color or {1, 0.82, 0.3}
 b.ring:SetVertexColor(c[1], c[2], c[3], 1)
 local itemIcon = ForeverTrailSettings.plateItemIcon ~= false and itemIconOf(o.itemId)
 if itemIcon then
  if not b.mask and b.CreateMaskTexture then
   b.mask = b:CreateMaskTexture(); b.mask:SetTexture(BLOB, 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE'); b.mask:SetAllPoints(b.icon)
  end
  b.icon:SetTexture(itemIcon); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); b.icon:SetVertexColor(1, 1, 1)
  if b.mask and not b.masked then b.icon:AddMaskTexture(b.mask); b.masked = true end
 else
  if b.masked then b.icon:RemoveMaskTexture(b.mask); b.masked = false end
  b.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
  if FT.SetObjectiveIcon then FT.SetObjectiveIcon(b.icon, nil, o.kind or 'kill', c, 1) else b.icon:SetTexture(iconFor(o)) end
 end
 b.title:SetText(o.title or 'Görev hedefi'); b.title:SetTextColor(1, 0.92, 0.75)
 local need = o.need or 0
 b.count:SetText(need > 0 and ('%d/%d'):format(o.have or 0, need) or '')
 b.count:SetTextColor(c[1], c[2], c[3])
 local frac = need > 0 and math.min(1, (o.have or 0) / need) or 0
 b.bar:SetWidth(math.max(1, (b.barBg:GetWidth() or 150) * frac)); b.bar:SetColorTexture(c[1], c[2], c[3], 1)
 b:Show()
end

-- İsim plakası: can barının yanında görev simgesi ve "3/8" sayacı, yaklaşınca nabız atar
local function healthBarOf(plate)
 local uf = plate.UnitFrame
 return (uf and (uf.healthBar or uf.HealthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar))) or uf or plate
end

local function plateMark(plate, o)
 if not plate then return end
 -- Queston/Questie kuruluyken simge ayarı kapalıdır; yine de eşya görevlerinde eşya resmi gösterilir
 if ForeverTrailSettings and ForeverTrailSettings.plateicons == false then
  if not (o and o.itemId and ForeverTrailSettings.plateItemIcon ~= false and itemIconOf(o.itemId)) then o = nil end
 end
 if o then
  if not plate.ftMark then
   local bar = healthBarOf(plate)
   local m = CreateFrame('Frame', nil, plate)
   m:SetSize(26, 26); m:SetFrameLevel((bar.GetFrameLevel and bar:GetFrameLevel() or 1) + 5)
   m.bar = bar
   m.glow = m:CreateTexture(nil, 'BACKGROUND'); m.glow:SetTexture('Interface\\Cooldown\\star4'); m.glow:SetBlendMode('ADD')
   m.glow:SetSize(44, 44); m.glow:SetPoint('CENTER')
   m.ring = m:CreateTexture(nil, 'BORDER'); m.ring:SetTexture(BLOB); m.ring:SetAllPoints()
   m.inner = m:CreateTexture(nil, 'ARTWORK', nil, 1); m.inner:SetTexture(BLOB); m.inner:SetSize(22, 22); m.inner:SetPoint('CENTER'); m.inner:SetVertexColor(0, 0, 0, 0.75)
   m.icon = m:CreateTexture(nil, 'OVERLAY'); m.icon:SetSize(16, 16); m.icon:SetPoint('CENTER'); m.icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
   m.count = m:CreateFontString(nil, 'OVERLAY')
   if m.count:SetFont(FT.FontPath(), 11, 'OUTLINE') == false then m.count:SetFont('Fonts\\ARIALN.TTF', 11, 'OUTLINE') end
   m.count:SetPoint('LEFT', m, 'RIGHT', 2, 0)
   m.t = 0
   m:SetScript('OnUpdate', function(self, dt)
    self.t = self.t + dt
    self.glow:SetAlpha(0.3 + 0.3 * math.sin(self.t * 4))
   end)
   plate.ftMark = m
  end
  local m = plate.ftMark
  m:SetScale(FT.Scale('plate'))
  m:ClearAllPoints(); m:SetPoint('LEFT', m.bar, 'RIGHT', 4 + FT.Scale('plateX'), FT.Scale('plateY'))
  local c = o.color or {1, 0.82, 0.3}
  m.ring:SetVertexColor(c[1], c[2], c[3], 1)
  m.glow:SetVertexColor(c[1], c[2], c[3])
  -- eşya toplama görevi: yaratığın düşürdüğü görev eşyasının kendi resmi, yuvarlak ve renkli halkalı
  local itemIcon = ForeverTrailSettings.plateItemIcon ~= false and itemIconOf(o.itemId)
  if itemIcon then
   if not m.mask and m.CreateMaskTexture then
    m.mask = m:CreateMaskTexture(); m.mask:SetTexture(BLOB, 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE'); m.mask:SetAllPoints(m.icon)
   end
   m.icon:SetTexture(itemIcon); m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); m.icon:SetVertexColor(1, 1, 1)
   if m.mask and not m.masked then m.icon:AddMaskTexture(m.mask); m.masked = true end
   m.ring:Show(); m.glow:Show(); m.inner:Hide()
   m.icon:SetSize(21, 21)
  else
   if m.masked then m.icon:RemoveMaskTexture(m.mask); m.masked = false end
   m.icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
   if FT.SetObjectiveIcon then FT.SetObjectiveIcon(m.icon, nil, o.kind or 'kill', c, 1) else m.icon:SetTexture(iconFor(o)) end
   local qsI = FT.IconStyle and FT.IconStyle() == 'questie'
   m.ring:SetShown(not qsI); m.inner:SetShown(not qsI); m.glow:SetShown(not qsI)
   if qsI then m.icon:SetSize(20, 20) else m.icon:SetSize(16, 16) end
  end
  m.count:SetText(o.need and o.need > 0 and ('%d/%d'):format(o.have, o.need) or '')
  m.count:SetTextColor(c[1], c[2], c[3])
  m:Show()
  if FT.TintPlate then pcall(FT.TintPlate, plate, o) end
 elseif plate.ftMark then
  plate.ftMark:Hide()
  if FT.TintPlate then pcall(FT.TintPlate, plate, nil) end
 end
end

-- Yaklaşan görev yaratığı için tek seferlik uyarı (yaratık başına, 60 sn)
local seenNear = {}
local function nearAlert(unit, o)
 if ForeverTrailSettings.creaturenear == false then return end
 local guid = UnitGUID(unit)
 if not guid or (seenNear[guid] and GetTime() - seenNear[guid] < 60) then return end
 seenNear[guid] = GetTime()
 local name = UnitName(unit) or '?'
 FT.Flash(('Görev yaratığı yakında: %s  (%d/%d)'):format(name, o.have, o.need), 1, 0.82, 0.3)
 if ForeverTrailSettings.sound ~= false and PlaySound and SOUNDKIT and SOUNDKIT.MAP_PING then pcall(PlaySound, SOUNDKIT.MAP_PING) end
end

local function refreshPlates()
 if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
 for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
  local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
  if unit then plateMark(plate, FT.QuestCreatureInfo(unit, true)) end
 end
end

FT.RefreshPlates = refreshPlates

-- /ftrail plaka: hedefteki yaratık için eşya resminin neden çıkmadığını adım adım yazar
function FT.PlateDebug()
 local s = ForeverTrailSettings or {}
 local function yn(v) return v == false and 'KAPALI' or 'açık' end
 FT.Print(('plaka ayarları: simge=%s eşya resmi=%s yaratık uyarısı=%s | Queston=%s Questie gömülü=%s'):format(
  yn(s.plateicons), yn(s.plateItemIcon), yn(s.creaturewarn), tostring(FT.QuestonActive), tostring(FT.QuestieEmbedded)))
 local plates = (C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()) or {}
 FT.Print(('görünen isim plakası: %d (kapalıysa V tuşu / Sistem > Ekran > düşman isim plakaları)'):format(#plates))
 local db = module('QuestieDB')
 FT.Print('QuestieDB modülü: ' .. ((db and db.QueryQuestSingle and db.QueryItemSingle) and 'var' or 'YOK (eşya düşüren yaratıklar bulunamaz)'))
 local drop = dropperMap()
 local n = 0
 for _ in pairs(drop) do n = n + 1 end
 FT.Print(('günlükte eşya toplama görevinden bulunan yaratık sayısı: %d'):format(n))
 if not (UnitExists and UnitExists('target')) then return FT.Print('Şimdi bir yaratığı hedefleyip tekrar yaz.') end
 local rawName, rawGuid = UnitName('target'), UnitGUID and UnitGUID('target')
 FT.Print(('hedef: ad=%s (%s)  guid=%s'):format(FT.Plain(rawName) or 'GİZLİ', 'ad okundu: ' .. tostring(FT.Plain(rawName) ~= nil), FT.Plain(rawGuid) and 'okundu' or 'GİZLİ'))
 local o = FT.QuestCreatureInfo('target', true)
 if not o then return FT.Print('Bu yaratık, günlükteki görevlerin hedefi olarak eşleşmedi.') end
 FT.Print(('eşleşti: görev="%s" eşya=%s resim=%s'):format(tostring(o.title), tostring(o.itemId), tostring(o.itemId and itemIconOf(o.itemId))))
 if not o.itemId then FT.Print('Bu bir öldürme hedefi (eşya düşürmüyor); eşya resmi yalnızca eşya toplama görevlerinde çıkar.') end
 for _, plate in ipairs(plates) do
  local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
  if u and UnitIsUnit and UnitIsUnit(u, 'target') then
   FT.Print('hedefin plakası: ' .. (plate.ftMark and (plate.ftMark:IsShown() and 'işaret GÖRÜNÜR' or 'işaret gizli') or 'işaret hiç oluşturulmadı'))
  end
 end
end

-- Düşman isim plakaları kapalıysa uyarı görünmez: bir kez açmayı dene
local function ensurePlates()
 if ForeverTrailSettings.creaturenear == false or ForeverTrailSettings.platesAsked then return end
 if not (GetCVar and SetCVar) or (InCombatLockdown and InCombatLockdown()) then return end
 ForeverTrailSettings.platesAsked = true
 if GetCVar('nameplateShowEnemies') ~= '1' then
  pcall(SetCVar, 'nameplateShowEnemies', '1')
  FT.Print('Görev yaratığı uyarıları için düşman isim plakaları açıldı (V tuşuyla kapatabilirsin).')
 end
end

local warn = CreateFrame('Frame')
for _, e in ipairs({'NAME_PLATE_UNIT_ADDED', 'NAME_PLATE_UNIT_REMOVED', 'PLAYER_TARGET_CHANGED', 'QUEST_LOG_UPDATE', 'PLAYER_ENTERING_WORLD'}) do
 pcall(warn.RegisterEvent, warn, e)
end
local plateRefreshPending = false
warn:SetScript('OnEvent', function(_, event, unit)
 pcall(function()
  if event == 'NAME_PLATE_UNIT_ADDED' and C_NamePlate then
   local o = FT.QuestCreatureInfo(unit, true)
   plateMark(C_NamePlate.GetNamePlateForUnit(unit), o)
   if o and ForeverTrailSettings.creaturewarn ~= false then nearAlert(unit, o) end
  elseif event == 'NAME_PLATE_UNIT_REMOVED' and C_NamePlate then
   plateMark(C_NamePlate.GetNamePlateForUnit(unit), nil)
  elseif event == 'PLAYER_ENTERING_WORLD' then
   ensurePlates()
  else
   monsterT = -10
   updateBanner()
   if event == 'QUEST_LOG_UPDATE' and not plateRefreshPending then
    plateRefreshPending = true
    local run = function() plateRefreshPending = false; pcall(refreshPlates) end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, run) else run() end
   end
  end
 end)
end)

-- Ok, takip kutusu ve düğme çubuğunu varsayılan yerlerine döndürür
function FT.ResetLayout()
 local s = ForeverTrailSettings
 s.arrowPoint, s.trackerPoint, s.dockPoint, s.availPoint = nil, nil, nil, nil
 if FT.availableBox and not FT.questDock then FT.availableBox:ClearAllPoints(); FT.availableBox:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 2, -180) end
 if FT.arrow then FT.arrow:ClearAllPoints(); FT.arrow:SetPoint('TOP', UIParent, 'TOP', 0, -140) end
 do local qf = FT.QuestFrame and FT.QuestFrame() or FT.tracker; if qf then qf:ClearAllPoints(); qf:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -2, -230) end end
 if FT.dock then FT.dock:ClearAllPoints(); FT.dock:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', 6, 230) end
 FT.Print('Ok, takip kutusu ve düğme çubuğu varsayılan yerlerine döndü.')
end


-- Arayüz ölçeği
function FT.ApplyUIScale()
 local scale = ForeverTrailSettings.uiScale or 1
 for _, f in ipairs({FT.card, FT.dock, FT.menu, FT.hub}) do if f then f:SetScale(scale) end end
 if FT.tracker then FT.tracker:SetScale(scale * FT.Scale('trackerScale') * FT.Scale('trackerFont') / 13) end
end


-- Bir pencereyi (ve alt öğelerini) Türkçe yazı tipine geçir
function FT.FixFonts(frame)
 pcall(walk, frame, FT.FontPath(), 0)
end

-- Ekran ortası uyarı: oyunun uyarı yazısı Türkçe harfleri bozduğu için kendi yazı alanımız
function FT.Flash(text, r, g, b)
 if not FT.flashFrame then
  local ok, f = pcall(CreateFrame, 'MessageFrame', 'ForeverTrailFlash', UIParent)
  if ok and f and f.AddMessage then
   f:SetSize(700, 60); f:SetPoint('TOP', UIParent, 'TOP', 0, -170)
   f:SetFrameStrata('HIGH'); f:SetInsertMode('TOP')
   f:SetTimeVisible(3); f:SetFadeDuration(1)
   pcall(f.SetFont, f, FT.FontPath(), 20, 'OUTLINE')
   f:SetShadowOffset(1, -1)
   FT.flashFrame = f
  end
 end
 if FT.flashFrame then FT.flashFrame:AddMessage(text, r or 1, g or 0.82, b or 0.3)
 elseif UIErrorsFrame then UIErrorsFrame:AddMessage(text, r or 1, g or 0.82, b or 0.3, 1) end
end

----------------------------------------------------------------------
-- Oyunun Friz/Morpheus yazı tiplerini WoWTR'deki Türkçe harfli kopyalarla değiştir
-- (ipuçları, liste satırları ve oyunun ekrandaki uyarı yazıları ş ğ ı İ gösterebilsin)
----------------------------------------------------------------------
local TR_REPLACE = {
 {'frizqt', 'Interface\\AddOns\\WoWTR\\Assets\\Fonts\\frizquadrata_tr.ttf'},
 {'morpheus', 'Interface\\AddOns\\WoWTR\\Assets\\Fonts\\morpheus_tr.ttf'},
}
local FONT_OBJECTS = {
 'GameFontNormal', 'GameFontHighlight', 'GameFontDisable', 'GameFontNormalSmall', 'GameFontHighlightSmall', 'GameFontDisableSmall',
 'GameFontNormalLarge', 'GameFontHighlightLarge', 'GameFontNormalHuge', 'GameFontHighlightMedium', 'GameFontNormalMed3',
 'GameTooltipHeaderText', 'GameTooltipText', 'GameTooltipTextSmall', 'QuestTitleFont', 'QuestFont', 'QuestFontNormalSmall',
 'QuestFontHighlight', 'ErrorFont', 'ZoneTextFont', 'SubZoneTextFont', 'PVPInfoTextFont', 'SystemFont_Small', 'SystemFont_Med1',
 'SystemFont_Med2', 'SystemFont_Med3', 'SystemFont_Large', 'SystemFont_Huge1', 'SystemFont_Shadow_Small', 'SystemFont_Shadow_Med1',
 'SystemFont_Shadow_Med2', 'SystemFont_Shadow_Med3', 'SystemFont_Shadow_Large', 'SystemFont_Shadow_Huge1', 'SystemFont_OutlineThick_Huge2',
 'SystemFont_OutlineThick_WTF', 'NumberFontNormal', 'MailTextFontNormal', 'InvoiceTextFontNormal', 'ItemTextFontNormal',
 'GameFontWhite', 'GameFontRed', 'GameFontGreen', 'GameFontBlack', 'DialogButtonNormalText', 'DialogButtonHighlightText', 'Game15Font', 'Game18Font',
}
local probeFS
local function usable(path)
 probeFS = probeFS or UIParent:CreateFontString(nil, 'OVERLAY')
 return probeFS:SetFont(path, 12, '') ~= false and probeFS:GetFont() ~= nil
end
function FT.PatchGameFonts()
 if ForeverTrailSettings and ForeverTrailSettings.globalfonts == false then return 0 end
 local ok = {}
 for _, r in ipairs(TR_REPLACE) do ok[r[1]] = usable(r[2]) end
 local names = {}
 if GetFonts then for _, n in ipairs(GetFonts() or {}) do names[#names + 1] = n end end
 for _, n in ipairs(FONT_OBJECTS) do names[#names + 1] = n end
 local done, count = {}, 0
 for _, name in ipairs(names) do
  local obj = type(name) == 'string' and _G[name] or name
  if obj and not done[obj] and type(obj) == 'table' and obj.GetFont and obj.SetFont then
   done[obj] = true
   local file, size, flags = obj:GetFont()
   if file and size then
    local lower = file:lower()
    for _, r in ipairs(TR_REPLACE) do
     if ok[r[1]] and lower:find(r[1], 1, true) then
      if obj:SetFont(r[2], size, flags or '') ~= false then count = count + 1 end
      break
     end
    end
   end
  end
 end
 return count
end
do
 local f = CreateFrame('Frame')
 f:RegisterEvent('PLAYER_LOGIN')
 f:SetScript('OnEvent', function() pcall(FT.PatchGameFonts) end)
end
