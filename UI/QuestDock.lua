local _, FT = ...

-- Görev penceresi: "Görevlerim" (takip kutusu) ve "Alınabilir" kutuları tek pencerede, sekmeli.
-- İki kutu olduğu gibi çalışmaya devam eder; bu pencere onları kendi içine alır, yalnızca seçili sekmeyi gösterir
-- ve başlık, sayaç, ayar ve daraltma düğmelerini kendisi sunar. Diğer modüllerin kutular üzerindeki Show/Hide/SetScale
-- çağrıları pencereye yönlendirilir (kutuların "istenen görünürlüğü" olarak tutulur).

local WIDTH, TAB_H = 276, 36
-- Kutuların kendi (gizlenen) başlık bandı kadar yukarı kaydırılır; böylece liste sekmelerin hemen altından başlar
local SHIFT = {tracker = 24, avail = 28}
local KINDS = {
 {key = 'tracker', label = 'Görevlerim'},
 {key = 'avail', label = 'Alınabilir'},
}

local dock, tabs, gear, collapse
local raw, wanted = {}, {}

local function frameOf(kind) return kind == 'tracker' and FT.tracker or FT.availableBox end

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
 local has = {tracker = wanted.tracker, avail = wanted.avail}
 if not has.tracker and not has.avail then
  for kind, r in pairs(raw) do local f = frameOf(kind); if f then r.Hide(f) end end
  dock:Hide()
  return
 end
 local tab = ForeverTrailSettings.dockTab
 if not has[tab] then tab = has.tracker and 'tracker' or 'avail' end
 dock.activeTab = tab
 dock:Show()
 local collapsed = ForeverTrailSettings.dockCollapsed or FT.trkCombatCollapsed
 -- sekmeler: yalnızca istenen kutular görünür; seçili olanın altında vurgu çizgisi
 local x = 0
 for _, k in ipairs(KINDS) do
  local b = tabs[k.key]
  if has[k.key] then
   local on = k.key == tab
   b:ClearAllPoints(); b:SetPoint('TOPLEFT', dock, 'TOPLEFT', x, -1)
   b.count:SetText(k.key == 'tracker' and questCount() or (FT.availCount or 0))
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
 local active = frameOf(tab)
 local h = TAB_H
 if not collapsed and active then h = TAB_H + math.max(8, (active:GetHeight() or 0) - SHIFT[tab]) + 6 end
 dock:SetHeight(h)
 collapse:SetText(ForeverTrailSettings.dockCollapsed and '+' or '-')
end

-- Bir kutuyu pencereye al ve Show/Hide/IsShown/SetScale çağrılarını yönlendir
local function adopt(kind, frame)
 if raw[kind] then return end
 raw[kind] = {Show = frame.Show, Hide = frame.Hide}
 if kind == 'tracker' then wanted.tracker = ForeverTrailSettings.tracker ~= false
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
 dock:SetSize(WIDTH, TAB_H + 40)
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
 gear:SetScript('OnClick', function() if FT.ToggleViewOptions then FT.ToggleViewOptions(dock.activeTab == 'avail' and 'avail' or 'tracker') end end)
 gear:HookScript('OnEnter', function(self)
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM'); GameTooltip:SetText('Görünüm ayarları', 1, 0.82, 0)
  GameTooltip:AddLine('Seçili sekmenin biçimi, sıralaması ve görev sayısı.', 0.9, 0.9, 0.9, true); GameTooltip:Show()
 end)
 gear:HookScript('OnLeave', function() if GameTooltip then GameTooltip:Hide() end end)
 if FT.FixFonts then pcall(FT.FixFonts, dock) end
 -- kutuların yenileme işlevleri bittiğinde pencere de güncellenir
 local refreshTracker, refreshAvail = FT.RefreshTracker, FT.RefreshAvailableBox
 FT.RefreshTracker = function(...) local r = refreshTracker(...); FT.RefreshQuestDock(); return r end
 FT.RefreshAvailableBox = function(...) local r = refreshAvail(...); FT.RefreshQuestDock(); return r end
 -- Alınabilir sekmesi artık her zaman görünür: eski "alınabilir kutusunu kapat" ayarı (ör. Sade düzey) bir kez temizlenir
 if ForeverTrailSettings.dockVersion ~= 1 then ForeverTrailSettings.availbox = nil; ForeverTrailSettings.dockVersion = 1 end
 FT.questDock = dock -- kutular pencereye alınmadan önce ilan edilmez (kurulum yarıda kalırsa eski düzen bozulmasın)
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
