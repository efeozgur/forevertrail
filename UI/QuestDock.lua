local _, FT = ...

-- Görev penceresi: "Görevlerim" (takip kutusu) ve "Alınabilir" kutuları tek pencerede, sekmeli.
-- İki kutu olduğu gibi çalışmaya devam eder; bu pencere onları kendi içine alır, yalnızca seçili sekmeyi gösterir
-- ve başlık, sayaç, ayar ve daraltma düğmelerini kendisi sunar. Diğer modüllerin kutular üzerindeki Show/Hide/SetScale
-- çağrıları pencereye yönlendirilir (kutuların "istenen görünürlüğü" olarak tutulur).

local WIDTH, TAB_H = 360, 36
-- Kutuların kendi (gizlenen) başlık bandı kadar yukarı kaydırılır; böylece liste sekmelerin hemen altından başlar
local SHIFT = {guide = 0, tracker = 0, avail = 0}
local KINDS = {
 {key = 'guide', label = 'Rehber'},
 {key = 'tracker', label = 'Görevlerim'},
 {key = 'avail', label = 'Alınabilir'},
}

local MIN_W, MAX_W, MIN_H = 300, 640, 220

local dock, tabs, gear, collapse

-- Pencere boyutlandırılabilir: genişlik her zaman, yükseklik yalnızca elle ayarlandıysa sabittir (aksi halde içeriğe göre)
local function dockWidth()
 local w = ForeverTrailSettings and ForeverTrailSettings.dockW
 return w and math.max(MIN_W, math.min(MAX_W, w)) or WIDTH
end
FT.QuestDockWidth = dockWidth
-- Listenin görünen yüksekliği (özet bölümü ve sekme şeridi çıkarıldıktan sonra); elle ayarlanmadıysa nil
function FT.QuestDockViewHeight(sumH)
 local h = ForeverTrailSettings and ForeverTrailSettings.dockH
 if not h then return nil end
 return math.max(80, h - TAB_H - sumH - 10)
end
local raw, wanted = {}, {}

local function frameOf(kind) return kind == 'guide' and FT.guideBox or (kind == 'tracker' and FT.tracker or FT.availableBox) end

-- Günlükteki görev sayısı (Görevlerim sekmesinin sayacı; kutu gizliyken de güncel kalır)
local function questCount()
 local n, q = 0, C_QuestLog
 if q and q.GetNumQuestLogEntries and q.GetInfo then
  for i = 1, q.GetNumQuestLogEntries() do
   local info = q.GetInfo(i)
   if info and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then n = n + 1 end
  end
 end
 return n
end

function FT.RefreshQuestDock()
 if not dock then return end
 local K = FT.Kit
 local has = {guide = wanted.guide, tracker = wanted.tracker, avail = wanted.avail}
 if not has.guide and not has.tracker and not has.avail then
  for kind, r in pairs(raw) do local f = frameOf(kind); if f then r.Hide(f) end end
  dock:Hide()
  return
 end
 local tab = ForeverTrailSettings.dockTab
 if not has[tab] then tab = has.guide and 'guide' or (has.tracker and 'tracker' or 'avail') end
 dock.activeTab = tab
 if tab == 'guide' and FT.RefreshGuideTab then FT.RefreshGuideTab() end
 dock:SetWidth(dockWidth())
 dock:Show()
 local collapsed = ForeverTrailSettings.dockCollapsed or FT.trkCombatCollapsed
 -- sekmeler: yalnızca istenen kutular görünür; seçili olanın altında vurgu çizgisi
 local x = 0
 for _, k in ipairs(KINDS) do
  local b = tabs[k.key]
  if has[k.key] then
   local on = k.key == tab
   b:ClearAllPoints(); b:SetPoint('TOPLEFT', dock, 'TOPLEFT', x, -1)
   b.count:SetText(k.key == 'guide' and (FT.GuideProgressText and FT.GuideProgressText() or '') or (k.key == 'tracker' and questCount() or (FT.availCount or 0)))
   local w = math.floor(b.text:GetStringWidth() + b.count:GetStringWidth() + 38)
   b:SetWidth(w); x = x + w
   b.line:SetShown(on)
   local c = K.Color(on and 'text' or 'muted'); b.text:SetTextColor(c[1], c[2], c[3])
   local a = K.Color(on and 'accent' or 'muted'); b.count:SetTextColor(a[1], a[2], a[3])
   b:Show()
  else b:Hide() end
 end
 -- içerik: yalnızca seçili sekmenin kutusu görünür
 for _, k in ipairs(KINDS) do
  local f = frameOf(k.key)
  if f and raw[k.key] then
   if k.key == tab and not collapsed then raw[k.key].Show(f) else raw[k.key].Hide(f) end
  end
 end
 for _, k in ipairs(KINDS) do local f = frameOf(k.key); if f then f:SetWidth(dockWidth()) end end
 local active = frameOf(tab)
 local h = TAB_H
 if not collapsed and active then h = TAB_H + math.max(8, (active:GetHeight() or 0) - SHIFT[tab]) + 6 end
 if ForeverTrailSettings.dockH and not collapsed then h = ForeverTrailSettings.dockH end
 dock:SetHeight(h)
 if dock.grip then dock.grip:SetShown(not collapsed) end
 collapse:SetText(ForeverTrailSettings.dockCollapsed and '+' or '-')
end

-- Bir kutuyu pencereye al ve Show/Hide/IsShown/SetScale çağrılarını yönlendir
local function adopt(kind, frame)
 if raw[kind] then return end
 raw[kind] = {Show = frame.Show, Hide = frame.Hide, GetScale = frame.GetScale, SetScale = frame.SetScale}
 -- kutu pencereye alınmadan önce kendi ölçeğini taşıyabilir (ör. yazı boyutu ayarından); pencere içinde ikinci kez küçülüp
 -- içeriği pencereden dar ve kısa bırakmasın diye 1'e sıfırlanır. Ölçeği bundan sonra yalnızca pencere taşır.
 raw[kind].SetScale(frame, 1)
 if kind == 'guide' then wanted.guide = ForeverTrailSettings.guideTab ~= false
 elseif kind == 'tracker' then wanted.tracker = ForeverTrailSettings.tracker ~= false
 else wanted.avail = ForeverTrailSettings.availbox ~= false and not ForeverTrailSettings.simple end
 frame:SetParent(dock)
 frame:ClearAllPoints()
 frame:SetPoint('TOPLEFT', dock, 'TOPLEFT', 0, -(TAB_H - SHIFT[kind]))
 frame:SetFrameLevel(dock:GetFrameLevel() + 1)
 frame:SetScript('OnDragStart', nil); frame:SetScript('OnDragStop', nil)
 local back = frame.softBg or frame.bg
 if back then back:Hide() end
 for _, name in ipairs({'headerText', 'toggleButton', 'line', 'viewGear'}) do
  if frame[name] then frame[name]:Hide() end
 end
 -- eski ayarlar: kutuların kendi daraltması artık pencerede
 ForeverTrailSettings.trackerCollapsed = false; ForeverTrailSettings.availCollapsed = false
 frame.Show = function() wanted[kind] = true; FT.RefreshQuestDock() end
 frame.Hide = function() wanted[kind] = false; FT.RefreshQuestDock() end
 frame.IsShown = function() return wanted[kind] and true or false end
 frame.SetScale = function(_, s) if kind == 'tracker' and dock then dock:SetScale(s) end end
 frame.GetScale = function() return kind == 'tracker' and dock and dock:GetScale() or 1 end
end

local function build()
 local K = FT.Kit
 dock = CreateFrame('Frame', 'ForeverTrailQuestDock', UIParent)
 dock:SetSize(dockWidth(), TAB_H + 40)
 dock:SetMovable(true); dock:EnableMouse(true); dock:SetClampedToScreen(true)
 dock:RegisterForDrag('LeftButton')
 dock:SetScript('OnDragStart', function(self) if not ForeverTrailSettings.locked then self:StartMoving() end end)
 dock:SetScript('OnDragStop', function(self)
  self:StopMovingOrSizing()
  local point, _, relative, x, y = self:GetPoint()
  ForeverTrailSettings.trackerPoint = {point, relative, x, y}
 end)
 local p = ForeverTrailSettings.trackerPoint
 if p and p[1] and p[2] and p[3] and p[4] then dock:SetPoint(p[1], UIParent, p[2], p[3], p[4])
 else dock:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -2, -230) end
 K.Skin(dock, 'mid', 'line')
 -- sekme şeridi: panel tonu, altta ince çizgi
 local strip = CreateFrame('Frame', nil, dock)
 strip:SetPoint('TOPLEFT', 1, -1); strip:SetPoint('TOPRIGHT', -1, -1); strip:SetHeight(TAB_H - 1)
 strip:SetFrameLevel(dock:GetFrameLevel() + 10)
 local band = strip:CreateTexture(nil, 'BACKGROUND'); band:SetAllPoints(); K.Fill(band, 'panel')
 local rule = K.Divider(strip); rule:SetPoint('BOTTOMLEFT', 0, 0); rule:SetPoint('BOTTOMRIGHT', 0, 0)
 tabs = {}
 for _, k in ipairs(KINDS) do
  local b = CreateFrame('Button', nil, strip)
  b:SetHeight(TAB_H - 3)
  b.text = b:CreateFontString(nil, 'OVERLAY'); K.Font(b.text, 12); b.text:SetPoint('LEFT', 12, 0); b.text:SetText(k.label)
  b.count = b:CreateFontString(nil, 'OVERLAY'); K.Font(b.count, 11); b.count:SetPoint('LEFT', b.text, 'RIGHT', 6, 0)
  b.line = b:CreateTexture(nil, 'OVERLAY'); b.line:SetHeight(2)
  b.line:SetPoint('BOTTOMLEFT', 6, 0); b.line:SetPoint('BOTTOMRIGHT', -6, 0)
  K.Fill(b.line, 'accent')
  b:SetScript('OnClick', function() ForeverTrailSettings.dockTab = k.key; FT.RefreshQuestDock() end)
  tabs[k.key] = b
 end
 collapse = K.Button(strip, '-', 22, 20)
 collapse:SetPoint('RIGHT', strip, 'RIGHT', -6, 0)
 collapse:SetScript('OnClick', function() ForeverTrailSettings.dockCollapsed = not ForeverTrailSettings.dockCollapsed; FT.RefreshQuestDock() end)
 gear = K.Button(strip, 'Ayar', 42, 20)
 gear:SetPoint('RIGHT', collapse, 'LEFT', -4, 0)
 gear:SetScript('OnClick', function()
  if dock.activeTab == 'guide' then if FT.ToggleGuidePicker then FT.ToggleGuidePicker() end
  elseif FT.ToggleViewOptions then FT.ToggleViewOptions(dock.activeTab == 'avail' and 'avail' or 'tracker') end
 end)
 gear:HookScript('OnEnter', function(self)
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM'); GameTooltip:SetText('Görünüm ayarları', 1, 0.82, 0)
  GameTooltip:AddLine('Seçili sekmenin biçimi, sıralaması ve görev sayısı.', 0.9, 0.9, 0.9, true); GameTooltip:Show()
 end)
 gear:HookScript('OnLeave', function() if GameTooltip then GameTooltip:Hide() end end)
 -- Sağ alt köşede boyutlandırma tutamacı: sürükleyince genişlik ve yükseklik değişir, çift tıklayınca otomatik boyuta döner
 local grip = CreateFrame('Button', nil, dock)
 grip:SetSize(18, 18); grip:SetPoint('BOTTOMRIGHT', -2, 2); grip:SetFrameLevel(dock:GetFrameLevel() + 20)
 grip:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
 grip:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
 grip:SetPushedTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down')
 dock.grip = grip
 local function applySize()
  if FT.RefreshTracker then FT.RefreshTracker() end
  if FT.RefreshAvailableBox then FT.RefreshAvailableBox() end
  if FT.RefreshGuideTab then FT.RefreshGuideTab() end
  FT.RefreshQuestDock()
 end
 grip:SetScript('OnMouseDown', function(self)
  -- sağ kenara yaslıysa genişleme sola kayar; sürüklemeden önce sol üst köşeye sabitle ki tutamak imleci izlesin
  self.left, self.top = dock:GetLeft(), dock:GetTop()
  if self.left and self.top then dock:ClearAllPoints(); dock:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', self.left, self.top) end
  self.dragging, self.waited = true, 1
 end)
 grip:SetScript('OnMouseUp', function(self)
  self.dragging = false
  local point, _, relative, x, y = dock:GetPoint()
  if point then ForeverTrailSettings.trackerPoint = {point, relative, x, y} end
 end)
 grip:SetScript('OnUpdate', function(self, dt)
  if not self.dragging or not (self.left and self.top and GetCursorPosition) then return end
  self.waited = self.waited + dt
  if self.waited < 0.05 then return end
  self.waited = 0
  local cx, cy = GetCursorPosition()
  local es = dock:GetEffectiveScale()
  local w = math.max(MIN_W, math.min(MAX_W, cx / es - self.left))
  local h = math.max(MIN_H, math.min((UIParent:GetHeight() or 800) / dock:GetScale() * 0.95, self.top - cy / es))
  ForeverTrailSettings.dockW, ForeverTrailSettings.dockH = math.floor(w), math.floor(h)
  applySize()
 end)
 grip:SetScript('OnDoubleClick', function() ForeverTrailSettings.dockW, ForeverTrailSettings.dockH = nil, nil; applySize() end)
 grip:SetScript('OnEnter', function(self)
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, 'ANCHOR_LEFT'); GameTooltip:SetText('Boyutu değiştir', 1, 0.82, 0)
  GameTooltip:AddLine('Sürükle: genişlik ve yükseklik. Çift tık: otomatik boyut.', 0.9, 0.9, 0.9, true); GameTooltip:Show()
 end)
 grip:SetScript('OnLeave', function() if GameTooltip then GameTooltip:Hide() end end)
 if FT.FixFonts then pcall(FT.FixFonts, dock) end
 -- kutuların yenileme işlevleri bittiğinde pencere de güncellenir
 local refreshTracker, refreshAvail = FT.RefreshTracker, FT.RefreshAvailableBox
 FT.RefreshTracker = function(...)
  local r
  if FT.RefreshQuestList then r = FT.RefreshQuestList(...) else r = refreshTracker(...) end
  FT.RefreshQuestDock()
  return r
 end
 FT.RefreshAvailableBox = function(...) local r = refreshAvail(...); FT.RefreshQuestDock(); return r end
 -- Alınabilir sekmesi artık her zaman görünür: eski "alınabilir kutusunu kapat" ayarı (ör. Sade düzey) bir kez temizlenir
 if (ForeverTrailSettings.dockVersion or 0) < 1 then ForeverTrailSettings.availbox = nil end
 -- Rehber sekmesi eklendi (sürüm 2): ilk sekme olur ve bir kez seçili açılır
 if (ForeverTrailSettings.dockVersion or 0) < 2 then ForeverTrailSettings.dockTab = 'guide' end
 ForeverTrailSettings.dockVersion = 2
 if FT.BuildGuideBox then FT.BuildGuideBox(dock) end
 FT.questDock = dock -- kutular pencereye alınmadan önce ilan edilmez (kurulum yarıda kalırsa eski düzen bozulmasın)
 if FT.guideBox then adopt('guide', FT.guideBox) end
 adopt('tracker', FT.tracker)
 adopt('avail', FT.availableBox)
 FT.RefreshQuestDock()
end

-- Pencereyi kurar (bir kez). Başarısızsa hata kaydedilir ve eski iki ayrı kutu düzeni korunur.
function FT.BuildQuestDock()
 if dock then return true end
 if not (FT.Kit and FT.tracker and FT.availableBox and FT.RefreshTracker and FT.RefreshAvailableBox and ForeverTrailSettings) then return false end
 local ok, err = pcall(build)
 if not ok then
  FT.questDockError = tostring(err)
  if FT.errors and #FT.errors < 20 then FT.errors[#FT.errors + 1] = 'questdock: ' .. tostring(err) end
  return false
 end
 return true
end

-- İki kutu da oluşunca pencereyi kur (kutular farklı olaylarda oluşturulur)
local ev = CreateFrame('Frame')
local waited = 0
ev:SetScript('OnUpdate', function(self, dt)
 waited = waited + dt
 if waited < 0.5 then return end
 waited = 0
 if FT.BuildQuestDock() or FT.questDockError then self:SetScript('OnUpdate', nil) end
end)

-- Test ve tanı için: kutuların kendi (gerçek) ölçeği; hep 1 olmalı
function FT.QuestDockChildScales()
 local out = {}
 for kind, r in pairs(raw) do local f = frameOf(kind); if f then out[kind] = r.GetScale(f) end end
 return out
end
