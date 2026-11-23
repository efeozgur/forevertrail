local _, FT = ...

-- Varsayılan görünüm "Gece": koyu mürekkep zemin, ince kenarlık, kehribar vurgu. Renkler Engine'de ApplyTheme ile yeniden uygulanır.
FT.Style = {
 bg = {0.071, 0.110, 0.141, 0.95},
 border = {0.141, 0.204, 0.255, 1},
 band = {0.114, 0.169, 0.220, 0.90},
 panelFill = {0.04, 0.07, 0.09, 0.45},
 accent = {0.898, 0.663, 0.310},
 text = {0.93, 0.94, 0.96},
 muted = {0.67, 0.70, 0.76},
}
FT.Themes = {
 sicak = {name='Sıcak', bg={0.14, 0.10, 0.07, 0.94}, border={0.82, 0.64, 0.32, 1}, band={0.40, 0.26, 0.12, 0.60}, accent={0.95, 0.72, 0.35}},
 gece = {name='Gece', bg={0.06, 0.08, 0.14, 0.94}, border={0.45, 0.60, 0.85, 1}, band={0.15, 0.22, 0.40, 0.60}, accent={0.55, 0.75, 1.00}},
 orman = {name='Orman', bg={0.07, 0.12, 0.08, 0.94}, border={0.55, 0.75, 0.45, 1}, band={0.15, 0.30, 0.14, 0.60}, accent={0.60, 0.85, 0.50}},
}
FT.Themes.safak = {name='Şafak', bg={0.14, 0.07, 0.09, 0.94}, border={0.88, 0.55, 0.62, 1}, band={0.40, 0.16, 0.24, 0.60}, accent={1.00, 0.62, 0.70}}
FT.Themes.mor = {name='Mor', bg={0.10, 0.07, 0.15, 0.94}, border={0.68, 0.52, 0.88, 1}, band={0.28, 0.17, 0.42, 0.60}, accent={0.78, 0.62, 1.00}}
FT.Themes.kum = {name='Kum', bg={0.17, 0.15, 0.11, 0.94}, border={0.78, 0.72, 0.55, 1}, band={0.35, 0.31, 0.20, 0.60}, accent={0.90, 0.84, 0.62}}
FT.Themes.aurora = {name='Aurora', bg={0.04, 0.07, 0.12, 0.93}, border={0.25, 0.85, 0.78, 1}, band={0.07, 0.24, 0.30, 0.70}, accent={0.30, 0.92, 0.82}}
FT.Themes.kozmik = {name='Kozmik', bg={0.07, 0.04, 0.15, 0.93}, border={0.75, 0.45, 1.00, 1}, band={0.26, 0.10, 0.44, 0.70}, accent={0.84, 0.58, 1.00}}
FT.Themes.gunbatimi = {name='Gün Batımı', bg={0.13, 0.05, 0.08, 0.93}, border={1.00, 0.55, 0.40, 1}, band={0.44, 0.14, 0.14, 0.70}, accent={1.00, 0.64, 0.46}}
FT.Themes.okyanus = {name='Okyanus', bg={0.03, 0.09, 0.14, 0.93}, border={0.35, 0.75, 0.95, 1}, band={0.07, 0.27, 0.40, 0.70}, accent={0.46, 0.84, 1.00}}
FT.Themes.klasik = {name='Klasik WoW', bg={0.03, 0.03, 0.05, 0.82}, border={0.62, 0.62, 0.66, 1}, band={0.30, 0.24, 0.08, 0.55}, accent={1.00, 0.82, 0.00}}
-- Sabit görünümün renk şemaları: zemin (üç kademeden en açığı), ince kenar, başlık bandı ve tek vurgu rengi.
-- Menüde yalnızca bunlar görünür (themeOrder); yukarıdaki eski temalar kodda durur ama listelenmez.
FT.Themes.g_gece = {name='Gece', bg={0.071, 0.110, 0.141, 0.95}, border={0.141, 0.204, 0.255, 1}, band={0.114, 0.169, 0.220, 0.90}, accent={0.898, 0.663, 0.310}}
FT.Themes.g_grafit = {name='Grafit', bg={0.102, 0.110, 0.125, 0.95}, border={0.173, 0.188, 0.220, 1}, band={0.165, 0.180, 0.212, 0.90}, accent={0.498, 0.722, 0.902}}
FT.Themes.g_orman = {name='Orman', bg={0.078, 0.122, 0.102, 0.95}, border={0.149, 0.220, 0.184, 1}, band={0.122, 0.200, 0.161, 0.90}, accent={0.604, 0.804, 0.478}}
FT.Themes.g_erik = {name='Erik', bg={0.118, 0.082, 0.153, 0.95}, border={0.227, 0.165, 0.278, 1}, band={0.180, 0.125, 0.251, 0.90}, accent={0.898, 0.561, 0.659}}
FT.defaultTheme = 'g_gece'
-- Tema değişince çağrılacak işlevler (Kit bileşenleri kendini yeniden boyar)
FT.themeListeners = {}
FT.themeOrder = {'g_gece', 'g_grafit', 'g_orman', 'g_erik'}
-- Eski tema anahtarları: kayıtlı ayarda kalmışsa yeni varsayılana çevrilir (kendi temam ve sınıf rengi korunur)
FT.legacyThemes = {sicak = true, gece = true, orman = true, safak = true, mor = true, kum = true, aurora = true, kozmik = true, gunbatimi = true, okyanus = true, klasik = true}
local skinned, bands, accents, buttons = {}, {}, {}, {}

-- Başlık bandı: soldan sağa solan geçişli renk (eski ve yeni istemci uyumlu)
local function paintBand(band, c)
 band:SetColorTexture(1, 1, 1, 1)
 local ok = false
 if CreateColor and band.SetGradient then
  ok = pcall(band.SetGradient, band, 'HORIZONTAL', CreateColor(c[1], c[2], c[3], 0.95), CreateColor(c[1], c[2], c[3], 0.08))
 end
 if not ok and band.SetGradientAlpha then
  ok = pcall(band.SetGradientAlpha, band, 'HORIZONTAL', c[1], c[2], c[3], 0.95, c[1], c[2], c[3], 0.08)
 end
 if not ok then band:SetColorTexture(c[1], c[2], c[3], c[4] or 0.6) end
end
FT.PaintBand = paintBand

-- Pencere başlığı: büyük, dış hatlı, tema vurgusu renginde
local titles = {}
function FT.StyleTitle(fs)
 if not fs then return end
 local path = (FT.FontPath and FT.FontPath()) or select(1, fs:GetFont())
 if path then pcall(fs.SetFont, fs, path, 14, 'OUTLINE') end
 fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.9)
 local a = FT.Style.accent
 fs:SetTextColor(a[1], a[2], a[3])
 titles[#titles + 1] = fs
end

function FT.RegisterAccent(texture, alpha)
 accents[#accents + 1] = {texture=texture, alpha=alpha or 0.7}
end

function FT.ApplyTheme(key)
 local theme = FT.Themes[key] or FT.Themes[FT.defaultTheme]
 local s = FT.Style
 s.bg, s.border, s.band, s.accent = theme.bg, theme.border, theme.band, theme.accent
 for _, entry in ipairs(skinned) do
  if entry.frame.SetBackdrop then
   entry.frame:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], s.bg[4])
   entry.frame:SetBackdropBorderColor(s.border[1], s.border[2], s.border[3], s.border[4])
  end
  if entry.fill then entry.fill:SetColorTexture(s.bg[1], s.bg[2], s.bg[3], s.bg[4]) end
 end
 for _, band in ipairs(bands) do paintBand(band, s.band) end
 for _, fs in ipairs(titles) do fs:SetTextColor(s.accent[1], s.accent[2], s.accent[3]) end
 for _, entry in ipairs(accents) do entry.texture:SetColorTexture(s.accent[1], s.accent[2], s.accent[3], entry.alpha) end
 for _, b in ipairs(buttons) do FT.SkinButton(b) end
 for _, listener in ipairs(FT.themeListeners) do pcall(listener) end
 if FT.RefreshDock then pcall(FT.RefreshDock) end
 if FT.RefreshTracker then pcall(FT.RefreshTracker) end
 if FT.StylePanel then pcall(FT.StylePanel) end
 if FT.RefreshHub then pcall(FT.RefreshHub) end
 if FT.BumpLayers then FT.BumpLayers() end
 if ForeverTrailSettings then ForeverTrailSettings.theme = FT.Themes[key] and key or FT.defaultTheme end
end

FT.TypeColor = {
 accept = {0.55, 0.82, 0.50}, objective = {0.98, 0.80, 0.40}, turnin = {0.55, 0.72, 0.95},
 location = {0.75, 0.62, 0.95}, manual = {0.78, 0.74, 0.68},
}

function FT.SoftBackdrop(frame)
 local bg = CreateFrame('Frame', nil, frame, BackdropTemplateMixin and 'BackdropTemplate' or nil)
 bg:SetAllPoints(frame)
 bg:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
 local s = FT.Style
 if bg.SetBackdrop then
  bg:SetBackdrop({bgFile='Interface\\Tooltips\\UI-Tooltip-Background', edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',
   tile=true, tileSize=16, edgeSize=14, insets={left=3, right=3, top=3, bottom=3}})
  bg:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], s.bg[4])
  bg:SetBackdropBorderColor(s.border[1], s.border[2], s.border[3], s.border[4])
 else
  local fill = bg:CreateTexture(nil, 'BACKGROUND')
  fill:SetAllPoints(); fill:SetColorTexture(s.bg[1], s.bg[2], s.bg[3], s.bg[4])
  skinned[#skinned + 1] = {frame=bg, fill=fill}
 end
 if bg.SetBackdrop then skinned[#skinned + 1] = {frame=bg} end
 local bar = bg:CreateTexture(nil, 'ARTWORK')
 bar:SetHeight(2); bar:SetPoint('TOPLEFT', 5, -4); bar:SetPoint('TOPRIGHT', -5, -4)
 bar:SetColorTexture(s.accent[1], s.accent[2], s.accent[3], 0.9)
 FT.RegisterAccent(bar, 0.9)
 frame.softBg = bg
 frame:HookScript('OnShow', function(self) self.softBg:SetFrameLevel(math.max(0, self:GetFrameLevel() - 1)) end)
 return bg
end

-- Türkçe harfleri (ş ğ ı İ ç ö ü) gösterebilen yazı tipi: WoWTR, yoksa Arial
local TR_FONTS = {'Interface\\AddOns\\WoWTR\\Assets\\Fonts\\frizquadrata_tr.ttf', 'Fonts\\ARIALN.TTF'}
local probe
function FT.TurkishFont()
 if FT.FontPath then return FT.FontPath() end
 probe = probe or UIParent:CreateFontString(nil, 'OVERLAY')
 for _, path in ipairs(TR_FONTS) do
  local ok, result = pcall(probe.SetFont, probe, path, 12, '')
  if ok and result ~= false then return path end
 end
 return 'Fonts\\ARIALN.TTF'
end

-- Düğmelerin kendi yazı tipi nesneleri: üstüne gelince/seçiliyken oyun varsayılanına dönmesin
local fontObjects
function FT.FontObjects()
 if not fontObjects then
  fontObjects = {
   normal = CreateFont('ForeverTrailFontButton'),
   highlight = CreateFont('ForeverTrailFontButtonHighlight'),
   disabled = CreateFont('ForeverTrailFontButtonDisabled'),
  }
  fontObjects.normal:SetTextColor(1, 0.82, 0.45)
  fontObjects.highlight:SetTextColor(1, 1, 1)
  fontObjects.disabled:SetTextColor(1, 1, 1)
 end
 local path = FT.TurkishFont()
 for _, f in pairs(fontObjects) do
  f:SetFont(path, 11, '')
  f:SetShadowOffset(1, -1); f:SetShadowColor(0, 0, 0, 0.85)
 end
 return fontObjects
end

FT.fontRoots = FT.fontRoots or {}

-- Queston Forever açıkken pencere ve düğmeler onun görünümünü alır:
-- ipucu kenarlığı, koyu zemin (Queston'un plaka renkleri), Blizzard düğmeleri ve oyun yazı tipleri.
function FT.QuestonLook()
 if ForeverTrailSettings and ForeverTrailSettings.questonLook == false then return false end
 if FT.QuestonActive ~= nil then return FT.QuestonActive end
 return FT.AddOnEnabled and FT.AddOnEnabled('QuestonForever') or false
end

local function questonColors()
 local Q = rawget(_G, 'QuestonForever')
 local ui = Q and Q.UI
 local edge = ui and ui.PLATE_EDGE or {0.55, 0.47, 0.32}
 local ground = ui and ui.PLATE_GROUND or {0.06, 0.05, 0.04}
 return edge, ground
end

function FT.QuestonSkin(f, alpha)
 local edge, ground = questonColors()
 if not f.SetBackdrop and BackdropTemplateMixin then Mixin(f, BackdropTemplateMixin) end
 if f.SetBackdrop then
  f:SetBackdrop({edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border', edgeSize = 14, insets = {left = 3, right = 3, top = 3, bottom = 3}})
  if f.SetBackdropBorderColor then f:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1) end
 end
 if not f.qfFill then
  f.qfFill = f:CreateTexture(nil, 'BACKGROUND')
  f.qfFill:SetPoint('TOPLEFT', 3, -3); f.qfFill:SetPoint('BOTTOMRIGHT', -3, 3)
 end
 f.qfFill:SetColorTexture(ground[1], ground[2], ground[3], alpha or 0.96)
end

function FT.NewWindow(name, parent)
 if FT.QuestonLook() then
  local f = CreateFrame('Frame', name, parent, BackdropTemplateMixin and 'BackdropTemplate' or nil)
  FT.fontRoots[#FT.fontRoots + 1] = f
  f:HookScript('OnShow', function(self) if FT.FixFonts then FT.FixFonts(self) end end)
  FT.QuestonSkin(f)
  local line = f:CreateTexture(nil, 'ARTWORK')
  line:SetHeight(1); line:SetPoint('TOPLEFT', 8, -26); line:SetPoint('TOPRIGHT', -8, -26)
  line:SetColorTexture(1, 0.82, 0, 0.35)
  f.close = CreateFrame('Button', nil, f, 'UIPanelCloseButton')
  f.close:SetPoint('TOPRIGHT', 1, 1)
  f.questonLook = true
  return f
 end
 local f = CreateFrame('Frame', name, parent)
 FT.fontRoots[#FT.fontRoots + 1] = f
 f:HookScript('OnShow', function(self) if FT.FixFonts then FT.FixFonts(self) end end)
 local bg = FT.SoftBackdrop(f)
 local band = bg:CreateTexture(nil, 'BORDER')
 band:SetPoint('TOPLEFT', 5, -5); band:SetPoint('TOPRIGHT', -5, -5); band:SetHeight(20)
 paintBand(band, FT.Style.band)
 bands[#bands + 1] = band
 f.close = CreateFrame('Button', nil, f, 'UIPanelCloseButton')
 f.close:SetPoint('TOPRIGHT', 2, 2)
 return f
end

-- Düz, sıcak tonlu düğme: üzerine gelince parlar, devre dışıyken (seçili sekme) vurgulu kenarlık alır.
function FT.SkinButton(b)
 if not (b.SetBackdrop or b.fill) then return end
 local s = FT.Style
 local selected = b.IsEnabled and not b:IsEnabled()
 local lift = selected and 0.16 or 0.08
 if b.SetBackdrop then
  b:SetBackdropColor(s.bg[1] + lift, s.bg[2] + lift * 0.8, s.bg[3] + lift * 0.6, 0.96)
  if selected then b:SetBackdropBorderColor(s.accent[1], s.accent[2], s.accent[3], 1)
  else b:SetBackdropBorderColor(s.border[1], s.border[2], s.border[3], 0.75) end
 elseif b.fill then
  b.fill:SetColorTexture(s.bg[1] + lift, s.bg[2] + lift * 0.8, s.bg[3] + lift * 0.6, 0.96)
 end
 local highlight = b.GetHighlightTexture and b:GetHighlightTexture()
 if highlight then highlight:SetVertexColor(s.accent[1], s.accent[2], s.accent[3], 0.25) end
end

function FT.NewButton(parent, text, width, height)
 if FT.QuestonLook() then
  local b = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
  b:SetSize(width, height or 22)
  b:SetText(text or '')
  local fs = b:GetFontString()
  if fs and FT.TurkishFont then local _, size = fs:GetFont(); pcall(fs.SetFont, fs, FT.TurkishFont(), size or 12, '') end
  return b
 end
 local b = CreateFrame('Button', nil, parent, BackdropTemplateMixin and 'BackdropTemplate' or nil)
 b:SetSize(width, height or 24)
 if b.SetBackdrop then
  b:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8', edgeFile='Interface\\Buttons\\WHITE8X8', edgeSize=1})
 else
  b.fill = b:CreateTexture(nil, 'BACKGROUND')
  b.fill:SetAllPoints()
 end
 local fo = FT.FontObjects()
 b:SetNormalFontObject(fo.normal)
 b:SetHighlightFontObject(fo.highlight)
 b:SetDisabledFontObject(fo.disabled)
 b:SetHighlightTexture('Interface\\Buttons\\WHITE8X8')
 b:SetPushedTextOffset(1, -1)
 b:SetText(text or '')
 local enable, disable = b.Enable, b.Disable
 b.Enable = function(self) enable(self); FT.SkinButton(self) end
 b.Disable = function(self) disable(self); FT.SkinButton(self) end
 buttons[#buttons + 1] = b
 FT.SkinButton(b)
 return b
end


-- Özelleştirme değerleri (Ayarlar > Özelleştir)
local DEFAULTS = {mapIcons=1, mmIcons=1, areaAlpha=1, plate=1, plateX=0, plateY=0, trackerScale=1, iconGiver=1, iconKill=1, iconLoot=1, iconObject=1, mmFadeStart=0.55, fontScale=1, trackerFont=13}
function FT.Scale(key)
 local v = ForeverTrailSettings and ForeverTrailSettings['c_' .. key]
 if type(v) ~= 'number' then return DEFAULTS[key] or 1 end
 return v
end

FT.Palettes = {
 canli = {name='Canlı', {1, 0.78, 0.25}, {0.35, 0.85, 1}, {0.55, 1, 0.45}, {1, 0.45, 0.6}, {0.75, 0.55, 1}, {1, 0.6, 0.3}, {0.4, 1, 0.85}, {0.95, 0.95, 0.5}},
 pastel = {name='Pastel', {1, 0.85, 0.6}, {0.65, 0.85, 1}, {0.7, 0.95, 0.7}, {1, 0.7, 0.8}, {0.85, 0.75, 1}, {1, 0.8, 0.65}, {0.7, 1, 0.92}, {0.98, 0.95, 0.7}},
 neon = {name='Neon', {1, 0.9, 0}, {0, 0.9, 1}, {0.2, 1, 0.2}, {1, 0.1, 0.6}, {0.7, 0.3, 1}, {1, 0.45, 0}, {0, 1, 0.75}, {1, 1, 0.3}},
 tema = {name='Tema'},
}
FT.paletteOrder = {'canli', 'pastel', 'neon', 'tema'}
function FT.QuestColor(i)
 local key = ForeverTrailSettings and ForeverTrailSettings.c_palette or 'canli'
 local p = FT.Palettes[key] or FT.Palettes.canli
 if key == 'tema' then
  local a = FT.Style.accent
  local k = 0.55 + 0.45 * (((i - 1) % 4) / 3)
  return {a[1] * k + (1 - k) * 0.4, a[2] * k + (1 - k) * 0.4, a[3] * k + (1 - k) * 0.4}
 end
 return p[(i - 1) % #p + 1]
end
