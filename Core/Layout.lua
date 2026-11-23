local _, FT = ...

-- Açılır pencereleri üst üste binmeden ekranın üst ortasına sırayla diz.
-- Kullanıcı bir pencereyi sürüklerse o pencere artık dizilmez.
local stack = {}
local TOP = -110

local function restack()
 local y = TOP
 table.sort(stack, function(a, b) return (a.ftShownAt or 0) < (b.ftShownAt or 0) end)
 for _, f in ipairs(stack) do
  if f:IsShown() and not f.ftMoved then
   f:ClearAllPoints(); f:SetPoint('TOP', UIParent, 'TOP', 0, y)
   y = y - (f:GetHeight() or 100) - 8
  end
 end
end
FT.RestackPopups = restack

function FT.RegisterPopup(frame)
 if not frame or frame.ftStacked then return end
 frame.ftStacked = true
 stack[#stack + 1] = frame
 frame:HookScript('OnShow', function(self) self.ftShownAt = GetTime and GetTime() or 0; restack() end)
 frame:HookScript('OnHide', restack)
 frame:HookScript('OnDragStop', function(self) self.ftMoved = true end)
 frame:HookScript('OnSizeChanged', function(self) if self:IsShown() then restack() end end)
end

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function after(s, fn) if C_Timer and C_Timer.After then C_Timer.After(s, fn) else fn() end end
local function font(fs, size, flags)
 if fs:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', size, flags or '') == false then fs:SetFont('Fonts\\ARIALN.TTF', size, flags or '') end
 fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.9)
end

----------------------------------------------------------------------
-- Düzen modu (Edit Mode gibi): ızgara, sürükle-bırak, hazır düzenler
----------------------------------------------------------------------
local MANAGED = {
 {key = 'arrow', label = 'Yön oku', get = function() return FT.arrow end},
 {key = 'tracker', label = 'Görev kutusu', get = function() return FT.tracker end},
 {key = 'avail', label = 'Alınabilir', get = function() return FT.availableBox end},
 {key = 'dock', label = 'Düğme çubuğu', get = function() return FT.dock end},
 {key = 'card', label = 'Hedef kartı', get = function() return FT.card end},
 {key = 'info', label = 'Bilgi çubuğu', get = function() return _G.ForeverTrailInfoBar end},
 {key = 'session', label = 'Oturum hedefi', get = function() return _G.ForeverTrailSessionBar end},
}
local editing, grid, panel = false, nil, nil
local overlays = {}

local function snap(v) return math.floor(v / 8 + 0.5) * 8 end

local function savePoint(def, f)
 local point, _, relPoint, x, y = f:GetPoint()
 if not point then return end
 ForeverTrailSettings.layout = ForeverTrailSettings.layout or {}
 ForeverTrailSettings.layout[def.key] = {point, relPoint, x, y}
end

function FT.ApplySavedLayout()
 local saved = ForeverTrailSettings and ForeverTrailSettings.layout or {}
 for _, def in ipairs(MANAGED) do
  local p, f = saved[def.key], def.get()
  if p and f and not (def.key == 'tracker' or def.key == 'arrow' or def.key == 'dock' or def.key == 'avail') then
   f:ClearAllPoints(); f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  end
 end
end

local function ensureGrid()
 if grid then return grid end
 grid = CreateFrame('Frame', nil, UIParent); grid:SetAllPoints(); grid:SetFrameStrata('BACKGROUND')
 local w, h = UIParent:GetWidth() or 1920, UIParent:GetHeight() or 1080
 for x = 0, w, 40 do local t = grid:CreateTexture(nil, 'BACKGROUND'); t:SetColorTexture(1, 1, 1, x == math.floor(w / 80) * 40 and 0.25 or 0.06); t:SetSize(1, h); t:SetPoint('TOPLEFT', x, 0) end
 for y = 0, h, 40 do local t = grid:CreateTexture(nil, 'BACKGROUND'); t:SetColorTexture(1, 1, 1, 0.06); t:SetSize(w, 1); t:SetPoint('TOPLEFT', 0, -y) end
 local cx = grid:CreateTexture(nil, 'BACKGROUND'); cx:SetColorTexture(1, 0.8, 0.2, 0.3); cx:SetSize(1, h); cx:SetPoint('TOP', 0, 0)
 local cy = grid:CreateTexture(nil, 'BACKGROUND'); cy:SetColorTexture(1, 0.8, 0.2, 0.3); cy:SetSize(w, 1); cy:SetPoint('LEFT', 0, 0)
 grid:Hide()
 return grid
end

local function overlayFor(def)
 local f = def.get()
 if not f then return nil end
 local o = overlays[def.key]
 if not o then
  o = CreateFrame('Button', nil, UIParent); o:SetFrameStrata('DIALOG')
  o.bg = o:CreateTexture(nil, 'BACKGROUND'); o.bg:SetAllPoints(); o.bg:SetColorTexture(0.2, 0.7, 1, 0.25)
  o.edge = o:CreateTexture(nil, 'BORDER'); o.edge:SetPoint('TOPLEFT'); o.edge:SetPoint('TOPRIGHT'); o.edge:SetHeight(2); o.edge:SetColorTexture(0.3, 0.8, 1, 0.9)
  o.label = o:CreateFontString(nil, 'OVERLAY'); font(o.label, 12, 'OUTLINE'); o.label:SetPoint('CENTER')
  o:EnableMouse(true); o:RegisterForClicks('AnyUp')
  o:SetScript('OnMouseDown', function()
   local t = def.get(); if not t then return end
   t:SetMovable(true); t:StartMoving()
  end)
  o:SetScript('OnMouseUp', function()
   local t = def.get(); if not t then return end
   t:StopMovingOrSizing()
   local point, _, relPoint, x, y = t:GetPoint()
   t:ClearAllPoints(); t:SetPoint(point, UIParent, relPoint, snap(x), snap(y))
   local stop = t:GetScript('OnDragStop')
   if stop then pcall(stop, t) end
   savePoint(def, t)
  end)
  overlays[def.key] = o
 end
 o:ClearAllPoints(); o:SetAllPoints(f)
 o.label:SetText(def.label)
 return o
end

local function ensurePanel()
 if panel then return panel end
 panel = FT.NewWindow('ForeverTrailEditMode', UIParent)
 panel:SetSize(360, 128); panel:SetPoint('TOP', 0, -60); panel:SetFrameStrata('FULLSCREEN_DIALOG')
 local t = panel:CreateFontString(nil, 'OVERLAY'); font(t, 14, 'OUTLINE'); t:SetPoint('TOP', 0, -10); t:SetText('Düzen modu')
 if FT.StyleTitle then FT.StyleTitle(t) end
 local hint = panel:CreateFontString(nil, 'OVERLAY'); font(hint, 11, ''); hint:SetPoint('TOP', 0, -30); hint:SetWidth(340)
 hint:SetText('Mavi kutuları sürükle; 8 piksellik ızgaraya oturur. Hazır düzen seç:')
 local presets = {{'varsayilan', 'Varsayılan'}, {'sade', 'Sade'}, {'genis', 'Geniş ekran'}, {'hud', 'HUD'}}
 for i, p in ipairs(presets) do
  local b = FT.NewButton(panel, p[2], 80, 22); b:SetPoint('TOPLEFT', 12 + (i - 1) * 84, -50)
  b:SetScript('OnClick', function() FT.ApplyLayoutPreset(p[1]) end)
 end
 local g = FT.NewButton(panel, 'Izgara', 80, 22); g:SetPoint('BOTTOMLEFT', 12, 12)
 g:SetScript('OnClick', function() ForeverTrailSettings.editGrid = not ForeverTrailSettings.editGrid; if ForeverTrailSettings.editGrid == false then ensureGrid():Hide() else ensureGrid():Show() end end)
 local done = FT.NewButton(panel, 'Bitti', 80, 22); done:SetPoint('BOTTOMRIGHT', -12, 12)
 done:SetScript('OnClick', function() FT.ToggleEditMode(false) end)
 panel:Hide()
 return panel
end

function FT.ToggleEditMode(state)
 if state == nil then state = not editing end
 if state and InCombatLockdown and InCombatLockdown() then return FT.Print('Savaşta düzen modu açılamaz.') end
 editing = state
 if editing then
  if FT.tracker and not FT.tracker:IsShown() then FT.tracker:Show() end
  if FT.availableBox and not FT.availableBox:IsShown() and ForeverTrailSettings.availbox ~= false then FT.availableBox:Show() end
  for _, def in ipairs(MANAGED) do local o = overlayFor(def); if o then o:Show() end end
  if ForeverTrailSettings.editGrid ~= false then ensureGrid():Show() end
  ensurePanel():Show()
  if FT.FixFonts then pcall(FT.FixFonts, panel) end
 else
  for _, o in pairs(overlays) do o:Hide() end
  if grid then grid:Hide() end
  if panel then panel:Hide() end
  FT.Print('Düzen kaydedildi.')
 end
end

local function place(f, point, rel, x, y, key)
 if not f then return end
 f:ClearAllPoints(); f:SetPoint(point, UIParent, rel, x, y)
 if key then ForeverTrailSettings[key] = {point, rel, x, y} end
end

function FT.ApplyLayoutPreset(name)
 local s = ForeverTrailSettings
 if name == 'varsayilan' then
  s.simple, s.availbox, s.tracker, s.card, s.dock, s.trackerCollapsed = false, true, true, true, true, false
  if FT.ResetLayout then FT.ResetLayout() end
  s.layout = nil
 elseif name == 'sade' then
  s.simple, s.availbox, s.tracker, s.trackerCollapsed = true, false, true, false
 elseif name == 'genis' then
  s.simple, s.availbox, s.tracker, s.trackerCollapsed = false, true, true, false
  place(FT.tracker, 'TOPRIGHT', 'TOPRIGHT', -40, -160, 'trackerPoint')
  place(FT.availableBox, 'TOPLEFT', 'TOPLEFT', 40, -160, 'availPoint')
  place(FT.arrow, 'TOP', 'TOP', 0, -96, 'arrowPoint')
  place(FT.dock, 'BOTTOMLEFT', 'BOTTOMLEFT', 40, 240, 'dockPoint')
 elseif name == 'hud' then
  s.simple, s.availbox, s.tracker, s.trackerCollapsed = true, false, true, true
  place(FT.arrow, 'TOP', 'TOP', 0, -160, 'arrowPoint')
 end
 if FT.ApplySimple then pcall(FT.ApplySimple) end
 if FT.tracker then if s.tracker == false then FT.tracker:Hide() else FT.tracker:Show() end end
 if FT.RefreshTracker then pcall(FT.RefreshTracker) end
 if FT.RefreshAvailableBox then pcall(FT.RefreshAvailableBox) end
 if editing then for _, def in ipairs(MANAGED) do overlayFor(def) end end
end

----------------------------------------------------------------------
-- Duruma göre görünüm: savaşta ve zindanda gereksiz kutuları gizle
----------------------------------------------------------------------
local hiddenByCtx = {}
local function ctxHide(f) if f and f:IsShown() then hiddenByCtx[f] = true; f:Hide() end end
local function ctxRestore() for f in pairs(hiddenByCtx) do f:Show() end hiddenByCtx = {} end
local dungeonPrompted = {}

----------------------------------------------------------------------
-- Sessiz mod
----------------------------------------------------------------------
local silentUntil = 0
function FT.IsSilent() return GetTime and GetTime() < silentUntil end
function FT.ToggleSilent(minutes)
 if FT.IsSilent() then silentUntil = 0; FT.Print('Sessiz mod kapandı.')
 else silentUntil = GetTime() + 60 * (minutes or 30); FT.Print(('Sessiz mod: %d dakika uyarı ve açılır pencere yok. Tekrar bas: kapat.'):format(minutes or 30)) end
end
local function wrapSilent()
 for _, name in ipairs({'ShowChoice', 'Alert', 'ShowLevelCard', 'ShowUpgradeCompare', 'ShowDoneBanner'}) do
  local fn = FT[name]
  if type(fn) == 'function' then
   FT[name] = function(...) if FT.IsSilent() then return false end return fn(...) end
  end
 end
end

----------------------------------------------------------------------
-- Ayar yedeği
----------------------------------------------------------------------
local function copy(t, depth)
 if type(t) ~= 'table' or (depth or 0) > 8 then return t end
 local out = {}
 for k, v in pairs(t) do out[k] = copy(v, (depth or 0) + 1) end
 return out
end

function FT.BackupNow(silent)
 ForeverTrailBackup = ForeverTrailBackup or {}
 ForeverTrailBackup.list = ForeverTrailBackup.list or {}
 table.insert(ForeverTrailBackup.list, 1, {t = time and time() or 0, settings = copy(ForeverTrailSettings)})
 for i = #ForeverTrailBackup.list, 6, -1 do ForeverTrailBackup.list[i] = nil end
 ForeverTrailBackup.last = time and time() or 0
 if not silent then FT.Print('Ayarların yedeklendi.') end
end

local backupWin
function FT.ShowBackups()
 if not backupWin then
  backupWin = FT.NewWindow('ForeverTrailBackups', UIParent)
  backupWin:SetSize(320, 250); backupWin:SetPoint('CENTER'); backupWin:SetFrameStrata('DIALOG')
  backupWin:SetMovable(true); backupWin:EnableMouse(true); backupWin:RegisterForDrag('LeftButton')
  backupWin:SetScript('OnDragStart', backupWin.StartMoving); backupWin:SetScript('OnDragStop', backupWin.StopMovingOrSizing)
  local t = backupWin:CreateFontString(nil, 'OVERLAY'); font(t, 14, 'OUTLINE'); t:SetPoint('TOP', 0, -10); t:SetText('Ayar yedekleri')
  if FT.StyleTitle then FT.StyleTitle(t) end
  backupWin.rows = {}
  for i = 1, 5 do
   local r = CreateFrame('Frame', nil, backupWin); r:SetSize(296, 26); r:SetPoint('TOPLEFT', 12, -36 - (i - 1) * 30)
   r.t = r:CreateFontString(nil, 'OVERLAY'); font(r.t, 12, ''); r.t:SetPoint('LEFT', 0, 0)
   r.b = FT.NewButton(r, 'Geri yükle', 90, 22); r.b:SetPoint('RIGHT', 0, 0)
   backupWin.rows[i] = r
  end
  local now = FT.NewButton(backupWin, 'Şimdi yedekle', 120, 22); now:SetPoint('BOTTOMLEFT', 12, 12)
  now:SetScript('OnClick', function() FT.BackupNow(); FT.ShowBackups() end)
  local close = FT.NewButton(backupWin, 'Kapat', 80, 22); close:SetPoint('BOTTOMRIGHT', -12, 12)
  close:SetScript('OnClick', function() backupWin:Hide() end)
 end
 local list = ForeverTrailBackup and ForeverTrailBackup.list or {}
 for i, r in ipairs(backupWin.rows) do
  local e = list[i]
  if e then
   r.t:SetText(date and date('%d.%m.%Y %H:%M', e.t) or tostring(e.t))
   r.b:SetScript('OnClick', function()
    FT.BackupNow(true)
    for k in pairs(ForeverTrailSettings) do ForeverTrailSettings[k] = nil end
    for k, v in pairs(copy(e.settings)) do ForeverTrailSettings[k] = v end
    FT.Print('Yedek geri yüklendi. Tamamen uygulanması için /reload yaz.')
    backupWin:Hide()
   end)
   r:Show()
  else r:Hide() end
 end
 backupWin:Show()
 if FT.FixFonts then pcall(FT.FixFonts, backupWin) end
end

----------------------------------------------------------------------
-- Kendi teman: renk seçici
----------------------------------------------------------------------
local function pickColor(c, cb)
 local r, g, b = c[1], c[2], c[3]
 if not ColorPickerFrame then return end
 if ColorPickerFrame.SetupColorPickerAndShow then
  ColorPickerFrame:SetupColorPickerAndShow({r = r, g = g, b = b, hasOpacity = false,
   swatchFunc = function() cb(ColorPickerFrame:GetColorRGB()) end,
   cancelFunc = function() cb(r, g, b) end})
 else
  ColorPickerFrame.hasOpacity = false
  ColorPickerFrame.previousValues = {r = r, g = g, b = b}
  ColorPickerFrame.func = function() cb(ColorPickerFrame:GetColorRGB()) end
  ColorPickerFrame.cancelFunc = function() cb(r, g, b) end
  ColorPickerFrame:SetColorRGB(r, g, b)
  ColorPickerFrame:Hide(); ColorPickerFrame:Show()
 end
end

local function customTheme()
 local s = ForeverTrailSettings
 if not s.customTheme then
  local base = FT.Themes[s.theme or FT.defaultTheme] or FT.Themes[FT.defaultTheme]
  s.customTheme = {bg = {unpack(base.bg)}, border = {unpack(base.border)}, band = {unpack(base.band)}, accent = {unpack(base.accent)}}
 end
 local c = s.customTheme
 FT.Themes.ozel = {name = 'Kendi temam', bg = c.bg, border = c.border, band = c.band, accent = c.accent}
 return c
end

function FT.BuildThemeEditor(page, y, width)
 local label = page:CreateFontString(nil, 'OVERLAY'); font(label, 11, ''); label:SetPoint('TOPLEFT', 4, y); label:SetText('Kendi temam:')
 local parts = {{'accent', 'Vurgu'}, {'bg', 'Zemin'}, {'border', 'Kenar'}}
 local bw = math.floor((width - 90 - 80) / 3) - 4
 for i, p in ipairs(parts) do
  local b = FT.NewButton(page, p[2], bw, 20); b:SetPoint('TOPLEFT', 90 + (i - 1) * (bw + 4), y + 3)
  b:SetScript('OnClick', function()
   local c = customTheme()
   pickColor(c[p[1]], function(r, g, bl)
    local a = c[p[1]][4]
    c[p[1]] = {r, g, bl, a}
    if p[1] == 'accent' then c.band = {r * 0.35, g * 0.35, bl * 0.35, 0.65} end
    customTheme(); FT.ApplyTheme('ozel')
   end)
  end)
 end
 local apply = FT.NewButton(page, 'Uygula', 72, 20); apply:SetPoint('TOPLEFT', 90 + 3 * (bw + 4), y + 3)
 apply:SetScript('OnClick', function() customTheme(); FT.ApplyTheme('ozel') end)
 return y - 26
end

----------------------------------------------------------------------
-- Yazı boyutu
----------------------------------------------------------------------
function FT.ApplyFontScale()
 for _, f in ipairs({FT.tracker, FT.availableBox, FT.hub, FT.card, FT.dock, FT.arrow, _G.ForeverTrailInfoBar, _G.ForeverTrailMapRoute}) do
  if f and FT.FixFonts then pcall(FT.FixFonts, f) end
 end
 if FT.RefreshTracker then pcall(FT.RefreshTracker) end
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local ev = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_LOGIN', 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED', 'PLAYER_ENTERING_WORLD', 'PLAYER_LOGOUT'}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript('OnEvent', function(_, event)
 local ok, err = pcall(function()
  if event == 'PLAYER_LOGIN' then
   wrapSilent()
   if ForeverTrailSettings.customTheme then customTheme() end
   if not (ForeverTrailBackup and ForeverTrailBackup.last) or (time and time() - ForeverTrailBackup.last > 20 * 3600) then FT.BackupNow(true) end
   after(3, FT.ApplySavedLayout)
   if (ForeverTrailSettings.c_fontScale or 1) ~= 1 then after(4, FT.ApplyFontScale) end
  elseif event == 'PLAYER_REGEN_DISABLED' then
   if on('ctxauto') then ctxHide(FT.availableBox); ctxHide(FT.card); ctxHide(FT.dock) end
  elseif event == 'PLAYER_REGEN_ENABLED' then
   ctxRestore()
  elseif event == 'PLAYER_ENTERING_WORLD' then
   local inInst, kind = IsInInstance and IsInInstance()
   if on('ctxauto') and inInst and (kind == 'party' or kind == 'raid') then
    if FT.availableBox then FT.availableBox:Hide() end
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player') or 0
    if not dungeonPrompted[map] and FT.ShowDungeonGuide then
     dungeonPrompted[map] = true
     after(3, function() if FT.ShowChoice then FT.ShowChoice('Zindandasın', 'Interface\\Icons\\INV_Misc_Head_Dragon_01', 'Zindan rehberinde görevler ve boss hedefleri var.', 'Rehberi aç', function() FT.ShowDungeonGuide() end) end end)
    end
   elseif not inInst and FT.RefreshAvailableBox then pcall(FT.RefreshAvailableBox) end
  end
 end)
 if not ok and FT.errors and #FT.errors < 20 then FT.errors[#FT.errors + 1] = 'layout: ' .. tostring(err) end
end)
