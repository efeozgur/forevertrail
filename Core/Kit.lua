local _, FT = ...

-- Ortak arayüz bileşenleri (düz, kenarlıksız-oyun-şablonu görünümü): kademeli zemin, ince çizgi, tek vurgu rengi.
-- Renkler temadan türetilir; tema değişince kayıtlı her bileşen kendini yeniden boyar (FT.themeListeners).

local Kit = {}
FT.Kit = Kit

-- Ana pencerenin icerik alani genisligi: tum sayfalar bu genislige gore yerlesir
Kit.CONTENT_W = 620

local function scale(c, k) return {math.min(c[1] * k, 1), math.min(c[2] * k, 1), math.min(c[3] * k, 1), 1} end

-- Rol -> renk. rail: en koyu yan şerit; mid: ana zemin; panel: başlık ve yüksek yüzeyler; card: kart ve seçili öğe;
-- line: ince ayırıcı ve kenar; deep: arama kutusu gibi gömülü alanlar.
function Kit.Color(role)
 local s = FT.Style
 if role == 'rail' then return scale(s.bg, 0.87)
 elseif role == 'mid' then return scale(s.bg, 1)
 elseif role == 'panel' then return scale(s.bg, 1.22)
 elseif role == 'card' then return {s.band[1], s.band[2], s.band[3], 1}
 elseif role == 'line' then return {s.border[1], s.border[2], s.border[3], 1}
 elseif role == 'deep' then return scale(s.bg, 0.5)
 elseif role == 'accent' then return {s.accent[1], s.accent[2], s.accent[3], 1}
 elseif role == 'text' then return {s.text[1], s.text[2], s.text[3], 1}
 elseif role == 'muted' then return {s.muted[1], s.muted[2], s.muted[3], 1}
 end
 return {1, 1, 1, 1}
end

local refreshers = {}
-- Kendini boyayan her bileşen bir yenileme işlevi kaydeder ve hemen bir kez çağrılır
local function track(fn) refreshers[#refreshers + 1] = fn; fn() end
Kit.Track = track
function Kit.Repaint() for _, fn in ipairs(refreshers) do pcall(fn) end end
FT.themeListeners[#FT.themeListeners + 1] = Kit.Repaint

function Kit.Fill(tex, role, alpha)
 track(function() local c = Kit.Color(role); tex:SetColorTexture(c[1], c[2], c[3], alpha or 1) end)
end

function Kit.Font(fs, size, flags)
 local path = FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF'
 if fs:SetFont(path, size, flags or '') == false then fs:SetFont('Fonts\\ARIALN.TTF', size, flags or '') end
 return fs
end

function Kit.Text(parent, size, role, flags)
 local fs = parent:CreateFontString(nil, 'OVERLAY')
 Kit.Font(fs, size, flags)
 track(function() local c = Kit.Color(role or 'text'); fs:SetTextColor(c[1], c[2], c[3]) end)
 return fs
end

-- Var olan bir çerçeveye düz zemin (ve istenirse 1 piksellik kenar) ekler
function Kit.Skin(frame, role, edgeRole)
 if edgeRole then
  frame.edge = frame:CreateTexture(nil, 'BACKGROUND', nil, 0); frame.edge:SetAllPoints()
  Kit.Fill(frame.edge, edgeRole)
  frame.fill = frame:CreateTexture(nil, 'BACKGROUND', nil, 1)
  frame.fill:SetPoint('TOPLEFT', 1, -1); frame.fill:SetPoint('BOTTOMRIGHT', -1, 1)
 else
  frame.fill = frame:CreateTexture(nil, 'BACKGROUND', nil, 1); frame.fill:SetAllPoints()
 end
 Kit.Fill(frame.fill, role)
 return frame
end

function Kit.Frame(parent, role, edgeRole)
 return Kit.Skin(CreateFrame('Frame', nil, parent), role, edgeRole)
end

function Kit.Divider(parent)
 local t = parent:CreateTexture(nil, 'ARTWORK')
 t:SetHeight(1)
 Kit.Fill(t, 'line')
 return t
end

-- Yan şeritteki düğme: üstte simge, altında yazı. Seçiliyken solda vurgu çizgisi ve açık zemin.
Kit.RAIL_W = 84
function Kit.RailButton(parent, def, onClick)
 local b = CreateFrame('Button', nil, parent)
 b:SetSize(Kit.RAIL_W, 58)
 b.key = def.key
 b.sel = b:CreateTexture(nil, 'BACKGROUND', nil, 2); b.sel:SetAllPoints(); Kit.Fill(b.sel, 'card'); b.sel:Hide()
 b.bar = b:CreateTexture(nil, 'ARTWORK'); b.bar:SetPoint('TOPLEFT'); b.bar:SetPoint('BOTTOMLEFT'); b.bar:SetWidth(3); Kit.Fill(b.bar, 'accent'); b.bar:Hide()
 b.icon = b:CreateTexture(nil, 'ARTWORK'); b.icon:SetSize(22, 22); b.icon:SetPoint('TOP', 0, -9)
 b.icon:SetTexture('Interface\\AddOns\\ForeverTrail\\Media\\' .. def.icon)
 b.icon:SetDesaturated(true) -- simgeler renkli olabilir; tek renge boyanmaları için önce grileştirilir
 b.text = Kit.Text(b, 10, 'muted'); b.text:SetPoint('BOTTOM', 0, 8); b.text:SetText(def.label)
 b:SetHighlightTexture('Interface\\Buttons\\WHITE8X8'); b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.05)
 b:SetScript('OnClick', onClick)
 function b:SetSelected(on)
  self.selected = on and true or false
  self:Refresh()
 end
 function b:Refresh()
  self.sel:SetShown(self.selected); self.bar:SetShown(self.selected)
  local c = Kit.Color(self.selected and 'accent' or 'muted')
  self.icon:SetVertexColor(c[1], c[2], c[3]); self.text:SetTextColor(c[1], c[2], c[3])
 end
 track(function() b:Refresh() end)
 return b
end

function Kit.CloseButton(parent, onClick)
 local b = CreateFrame('Button', nil, parent)
 b:SetSize(28, 28)
 b.text = Kit.Text(b, 20, 'muted'); b.text:SetPoint('CENTER', 0, 1); b.text:SetText('x')
 b:SetScript('OnEnter', function(self) local c = Kit.Color('accent'); self.text:SetTextColor(c[1], c[2], c[3]) end)
 b:SetScript('OnLeave', function(self) local c = Kit.Color('muted'); self.text:SetTextColor(c[1], c[2], c[3]) end)
 b:SetScript('OnClick', onClick)
 return b
end

-- Düz düğme. kind = 'primary' (vurgu rengi dolgulu, ana eylem) ya da boş (kart zeminli, ince çizgili).
-- SetText / GetFontString / Enable / Disable oyunun düğmesi gibi çalışır.
local function lighten(c, k) return {math.min(c[1] * k, 1), math.min(c[2] * k, 1), math.min(c[3] * k, 1), 1} end
function Kit.Button(parent, text, width, height, kind)
 local b = CreateFrame('Button', nil, parent)
 b:SetSize(width, height or 24)
 b.kind = kind
 b.edge = b:CreateTexture(nil, 'BACKGROUND', nil, 0); b.edge:SetAllPoints()
 b.fill = b:CreateTexture(nil, 'BACKGROUND', nil, 1); b.fill:SetPoint('TOPLEFT', 1, -1); b.fill:SetPoint('BOTTOMRIGHT', -1, 1)
 b.label = b:CreateFontString(nil, 'OVERLAY'); Kit.Font(b.label, 12); b.label:SetPoint('CENTER', 0, 0)
 b.label:SetText(text or '')
 function b:SetText(t) self.label:SetText(t or '') end
 function b:GetText() return self.label:GetText() end
 function b:GetFontString() return self.label end
 function b:Refresh()
  -- Devre dışı düğme seçili sekme gibi gösterilir (eski davranış): açık zemin, vurgu kenarlı ve yazılı
  local off = self.IsEnabled and self:IsEnabled() == false
  local fill, edge, text
  if off then fill, edge, text = Kit.Color('card'), Kit.Color('accent'), Kit.Color('accent')
  elseif self.kind == 'primary' then
   fill = self.hover and lighten(Kit.Color('accent'), 1.12) or Kit.Color('accent')
   edge, text = fill, Kit.Color('deep')
  else
   fill = self.hover and lighten(Kit.Color('card'), 1.3) or Kit.Color('card')
   edge, text = Kit.Color('line'), Kit.Color(self.hover and 'accent' or 'text')
  end
  self.fill:SetColorTexture(fill[1], fill[2], fill[3], 1); self.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
  self.label:SetTextColor(text[1], text[2], text[3])
 end
 local enable, disable = b.Enable, b.Disable
 function b:Enable() if enable then enable(self) end; self:Refresh() end
 function b:Disable() if disable then disable(self) end; self:Refresh() end
 b:SetScript('OnEnter', function(self) self.hover = true; self:Refresh() end)
 b:SetScript('OnLeave', function(self) self.hover = false; self:Refresh() end)
 track(function() b:Refresh() end)
 return b
end

-- Düz onay kutusu + yazı. get() açık mı döndürür, set(v) değişince çağrılır.
function Kit.Check(parent, label, get, set)
 local c = CreateFrame('Button', nil, parent)
 c:SetSize(170, 20)
 c.box = Kit.Frame(c, 'deep', 'line'); c.box:SetSize(16, 16); c.box:SetPoint('LEFT', 0, 0)
 c.mark = c.box:CreateTexture(nil, 'ARTWORK'); c.mark:SetPoint('TOPLEFT', 4, -4); c.mark:SetPoint('BOTTOMRIGHT', -4, 4)
 Kit.Fill(c.mark, 'accent')
 c.text = Kit.Text(c, 12, 'text'); c.text:SetPoint('LEFT', c.box, 'RIGHT', 8, 0); c.text:SetText(label)
 function c:SetChecked(v) self.on = v and true or false; self.mark:SetShown(self.on) end
 function c:GetChecked() return self.on end
 c:SetScript('OnClick', function(self) self:SetChecked(not self.on); if set then set(self.on) end end)
 c:SetChecked(get and get())
 return c
end

-- Pencere: düz zemin, ince kenar, 28 px başlık şeridi ve ortak kapatma düğmesi. Pencereler başlıklarını kendileri yazar.
function Kit.Window(name, parent)
 local f = CreateFrame('Frame', name, parent)
 Kit.Skin(f, 'mid', 'line')
 f.headerBand = f:CreateTexture(nil, 'BACKGROUND', nil, 2)
 f.headerBand:SetPoint('TOPLEFT', 1, -1); f.headerBand:SetPoint('TOPRIGHT', -1, -1); f.headerBand:SetHeight(27)
 Kit.Fill(f.headerBand, 'panel')
 f.headerLine = f:CreateTexture(nil, 'ARTWORK')
 f.headerLine:SetHeight(1); f.headerLine:SetPoint('TOPLEFT', 1, -28); f.headerLine:SetPoint('TOPRIGHT', -1, -28)
 Kit.Fill(f.headerLine, 'line')
 f.close = Kit.CloseButton(f, function() f:Hide() end)
 f.close:SetPoint('TOPRIGHT', -3, -1)
 return f
end

-- Bir pencere başka bir pencerenin (ana pencere) içine alınırken kendi çerçevesini bırakır
function Kit.Unchrome(f)
 for _, key in ipairs({'edge', 'fill', 'headerBand', 'headerLine', 'close'}) do
  if f[key] then f[key]:Hide() end
 end
end

-- Yazısız düz onay kutusu: oyunun CheckButton'ı gibi SetChecked / GetChecked / OnClick (tıklamada önce değişir, sonra çağrılır).
function Kit.CheckBox(parent)
 local c = CreateFrame('Button', nil, parent)
 c:SetSize(18, 18)
 Kit.Skin(c, 'deep', 'line')
 c.mark = c:CreateTexture(nil, 'ARTWORK')
 c.mark:SetPoint('TOPLEFT', 4, -4); c.mark:SetPoint('BOTTOMRIGHT', -4, 4)
 Kit.Fill(c.mark, 'accent')
 c.mark:Hide()
 function c:SetChecked(v) self.on = v and true or false; self.mark:SetShown(self.on) end
 function c:GetChecked() return self.on end
 local rawSetScript, userClick = c.SetScript, nil
 function c:SetScript(name, fn)
  if name == 'OnClick' then userClick = fn else rawSetScript(self, name, fn) end
 end
 rawSetScript(c, 'OnClick', function(self) self:SetChecked(not self.on); if userClick then userClick(self) end end)
 return c
end

-- Düz kaydırıcı: ince çizgi, vurgu dolgusu, küçük tutamak. OptionsSliderTemplate yerine geçer.
function Kit.Slider(parent, name)
 local s = CreateFrame('Slider', name, parent)
 s:SetOrientation('HORIZONTAL'); s:SetHeight(14)
 s.track = s:CreateTexture(nil, 'BACKGROUND'); s.track:SetHeight(4)
 s.track:SetPoint('LEFT', 0, 0); s.track:SetPoint('RIGHT', 0, 0)
 Kit.Fill(s.track, 'line')
 s.fillBar = s:CreateTexture(nil, 'ARTWORK'); s.fillBar:SetHeight(4); s.fillBar:SetPoint('LEFT', 0, 0); s.fillBar:SetWidth(1)
 Kit.Fill(s.fillBar, 'accent')
 s:SetThumbTexture('Interface\\Buttons\\WHITE8X8')
 local thumb = s:GetThumbTexture()
 if thumb then thumb:SetSize(8, 14); track(function() local a = Kit.Color('accent'); thumb:SetVertexColor(a[1], a[2], a[3]) end) end
 local function update(self)
  local lo, hi = self:GetMinMaxValues()
  local v, w = self:GetValue(), self:GetWidth()
  if lo and hi and v and w and hi > lo then self.fillBar:SetWidth(math.max(1, w * (v - lo) / (hi - lo))) end
 end
 local rawSetScript, rawSetValue, rawSetMinMax = s.SetScript, s.SetValue, s.SetMinMaxValues
 function s:SetScript(name, fn)
  if name == 'OnValueChanged' then rawSetScript(self, name, function(sl, v) update(sl); if fn then fn(sl, v) end end)
  else rawSetScript(self, name, fn) end
 end
 function s:SetValue(v) rawSetValue(self, v); update(self) end
 function s:SetMinMaxValues(lo, hi) rawSetMinMax(self, lo, hi); update(self) end
 return s
end

-- Düz arama / yazı kutusu (InputBoxTemplate yerine): koyu zemin, ince çizgi, odaktayken vurgu kenarlı.
function Kit.Input(parent)
 local e = CreateFrame('EditBox', nil, parent)
 e:SetSize(160, 22); e:SetAutoFocus(false)
 Kit.Skin(e, 'deep', 'line')
 Kit.Font(e, 12)
 e:SetTextInsets(8, 8, 0, 0)
 track(function() local c = Kit.Color('text'); e:SetTextColor(c[1], c[2], c[3]) end)
 local function edge()
  local c = Kit.Color(e.focused and 'accent' or 'line'); e.edge:SetColorTexture(c[1], c[2], c[3], 1)
 end
 e:HookScript('OnEditFocusGained', function() e.focused = true; edge() end)
 e:HookScript('OnEditFocusLost', function() e.focused = false; edge() end)
 e:HookScript('OnEscapePressed', function(self) self:ClearFocus() end)
 track(edge)
 return e
end

-- Düz kaydırma alanı: ince bir kaydırma çubuğu (alanın sağ dışında 8 px), fare tekerleği.
function Kit.Scroll(parent)
 local sf = CreateFrame('ScrollFrame', nil, parent)
 sf:EnableMouseWheel(true)
 sf.bar = sf:CreateTexture(nil, 'ARTWORK'); sf.bar:SetWidth(3)
 sf.bar:SetPoint('TOPRIGHT', sf, 'TOPRIGHT', 8, 0); sf.bar:SetPoint('BOTTOMRIGHT', sf, 'BOTTOMRIGHT', 8, 0)
 Kit.Fill(sf.bar, 'line')
 sf.thumb = sf:CreateTexture(nil, 'OVERLAY'); sf.thumb:SetWidth(3)
 Kit.Fill(sf.thumb, 'muted', 0.55)
 local function update(self)
  local ok, range = pcall(self.GetVerticalScrollRange, self)
  local h = self:GetHeight()
  if not ok or type(range) ~= 'number' or range <= 0 or not h or h <= 0 then self.thumb:Hide(); return end
  local off = self:GetVerticalScroll() or 0
  local th = math.max(24, h * h / (h + range))
  self.thumb:SetHeight(th); self.thumb:ClearAllPoints()
  self.thumb:SetPoint('TOPRIGHT', self, 'TOPRIGHT', 8, -((off / range) * (h - th)))
  self.thumb:Show()
 end
 sf:SetScript('OnMouseWheel', function(self, delta)
  local range = self:GetVerticalScrollRange() or 0
  self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 40)))
 end)
 sf:SetScript('OnVerticalScroll', update)
 sf:SetScript('OnScrollRangeChanged', update)
 return sf
end

-- Bölmeli seçici (segmented control): bir grup seçenekten biri seçili. items = {{anahtar, yazı}, ...}
function Kit.Segmented(parent, items, width, height, onPick)
 height = height or 24
 local seg = CreateFrame('Frame', nil, parent)
 seg:SetSize(width, height)
 Kit.Skin(seg, 'deep', 'line')
 seg.buttons = {}
 local count = #items
 local bw = (width - 2) / count
 for i, it in ipairs(items) do
  local b = CreateFrame('Button', nil, seg)
  b:SetSize(bw, height - 2); b:SetPoint('TOPLEFT', 1 + (i - 1) * bw, -1)
  b.fill = b:CreateTexture(nil, 'BACKGROUND', nil, 2); b.fill:SetAllPoints()
  b.text = b:CreateFontString(nil, 'OVERLAY'); Kit.Font(b.text, 11); b.text:SetPoint('CENTER', 0, 0); b.text:SetText(it[2])
  b.key = it[1]
  b:SetScript('OnEnter', function(self) self.hover = true; seg:Refresh() end)
  b:SetScript('OnLeave', function(self) self.hover = false; seg:Refresh() end)
  b:SetScript('OnClick', function() if onPick then onPick(it[1]) end end)
  seg.buttons[i] = b
 end
 function seg:SetValue(key) self.value = key; self:Refresh() end
 function seg:Refresh()
  for _, b in ipairs(self.buttons) do
   local on = b.key == self.value
   local fill = on and Kit.Color('accent') or (b.hover and Kit.Color('card') or Kit.Color('deep'))
   local text = on and Kit.Color('deep') or Kit.Color(b.hover and 'accent' or 'text')
   b.fill:SetColorTexture(fill[1], fill[2], fill[3], 1); b.text:SetTextColor(text[1], text[2], text[3])
  end
 end
 track(function() seg:Refresh() end)
 return seg
end

-- Anahtar (switch): kaydıran açık/kapalı düğmesi. SetChecked / GetChecked / OnClick onay kutusuyla aynı.
function Kit.Switch(parent)
 local s = CreateFrame('Button', nil, parent)
 s:SetSize(34, 18)
 Kit.Skin(s, 'deep', 'line')
 s.knob = s:CreateTexture(nil, 'ARTWORK'); s.knob:SetSize(12, 12)
 function s:Refresh()
  local on = self.on
  self.knob:ClearAllPoints(); self.knob:SetPoint(on and 'RIGHT' or 'LEFT', on and -3 or 3, 0)
  local k = Kit.Color(on and 'accent' or 'muted'); self.knob:SetColorTexture(k[1], k[2], k[3], 1)
  local e = Kit.Color(on and 'accent' or 'line'); self.edge:SetColorTexture(e[1], e[2], e[3], 1)
 end
 function s:SetChecked(v) self.on = v and true or false; self:Refresh() end
 function s:GetChecked() return self.on end
 local rawSetScript, userClick = s.SetScript, nil
 function s:SetScript(name, fn)
  if name == 'OnClick' then userClick = fn else rawSetScript(self, name, fn) end
 end
 rawSetScript(s, 'OnClick', function(self) self:SetChecked(not self.on); if userClick then userClick(self) end end)
 track(function() s:Refresh() end)
 return s
end

-- Seviye rozeti: görev zorluk renginde yarı saydam zemin üzerinde seviye numarası
function Kit.LevelBadge(parent)
 local b = CreateFrame('Frame', nil, parent)
 b:SetSize(24, 16)
 b.bg = b:CreateTexture(nil, 'BACKGROUND'); b.bg:SetAllPoints()
 b.text = b:CreateFontString(nil, 'OVERLAY'); Kit.Font(b.text, 11); b.text:SetPoint('CENTER', 0, 0)
 function b:SetLevel(level, r, g, bl)
  level = tonumber(level)
  self.text:SetText(level and level > 0 and tostring(level) or '?')
  self.bg:SetColorTexture(r, g, bl, 0.18); self.text:SetTextColor(r, g, bl)
 end
 return b
end

-- Modern ipucu: oyunun GameTooltip yöntemlerini (SetOwner, SetText, AddLine, AddDoubleLine) sunar, ama düz çerçevede,
-- sabit genişlikte, kaydırmasız satır aralığıyla çizer. AddBar (ilerleme çubuklu satır) ve AddRule (ince çizgi) ek yöntemlerdir.
local tipObject
function Kit.Tooltip()
 if tipObject then return tipObject end
 local W, PAD = 288, 14
 local f = CreateFrame('Frame', 'ForeverTrailTip', UIParent)
 f:SetFrameStrata('TOOLTIP'); f:SetClampedToScreen(true); f:SetSize(W + PAD * 2, 40); f:Hide()
 Kit.Skin(f, 'panel', 'line')
 local top = f:CreateTexture(nil, 'ARTWORK'); top:SetHeight(2)
 top:SetPoint('TOPLEFT', 1, -1); top:SetPoint('TOPRIGHT', -1, -1)
 Kit.Fill(top, 'accent')
 local tip = {frame = f}
 local items, pool = {}, {}
 local function color(r, g, b)
  if r == nil then return Kit.Color('text') end
  if r > 0.98 and g > 0.98 and b > 0.98 then return Kit.Color('text') end
  if math.abs(r - g) < 0.03 and math.abs(g - b) < 0.03 and r < 0.72 then return Kit.Color('muted') end
  return {r, g, b, 1}
 end
 local function part(i)
  local p = pool[i]
  if not p then
   p = {left = f:CreateFontString(nil, 'OVERLAY'), right = f:CreateFontString(nil, 'OVERLAY'),
    rule = f:CreateTexture(nil, 'ARTWORK'), barBg = f:CreateTexture(nil, 'ARTWORK'), barFill = f:CreateTexture(nil, 'OVERLAY')}
   p.left:SetJustifyH('LEFT'); p.left:SetJustifyV('TOP'); p.right:SetJustifyH('RIGHT')
   p.rule:SetHeight(1); p.barBg:SetHeight(3); p.barFill:SetHeight(3)
   pool[i] = p
  end
  p.left:Hide(); p.right:Hide(); p.rule:Hide(); p.barBg:Hide(); p.barFill:Hide()
  return p
 end
 local function font(fs, size) Kit.Font(fs, size) end
 function tip:ClearLines() items = {} end
 function tip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor or 'ANCHOR_RIGHT'; items = {} end
 function tip:SetText(text, r, g, b) items = {{kind = 'title', text = text, r = r, g = g, b = b}} end
 function tip:AddLine(text, r, g, b) items[#items + 1] = {kind = (text == ' ' or text == '') and 'space' or 'line', text = text, r = r, g = g, b = b} end
 function tip:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb) items[#items + 1] = {kind = 'double', left = left, right = right, lr = lr, lg = lg, lb = lb, rr = rr, rg = rg, rb = rb} end
 function tip:AddRule() items[#items + 1] = {kind = 'rule'} end
 function tip:AddBar(text, have, need, r, g, b) items[#items + 1] = {kind = 'bar', text = text, have = have, need = need, r = r, g = g, b = b} end
 function tip:NumLines() return #items end
 function tip:GetName() return nil end
 function tip:IsShown() return f:IsShown() end
 function tip:Hide() f:Hide() end
 function tip:Show()
  local y, used = 12, 0
  for _, it in ipairs(items) do
   used = used + 1
   local p = part(used)
   if it.kind == 'title' then
    local c = color(it.r, it.g, it.b)
    font(p.left, 14); p.left:SetWidth(W); p.left:SetWordWrap(true); p.left:ClearAllPoints(); p.left:SetPoint('TOPLEFT', PAD, -y)
    p.left:SetText(it.text or ''); p.left:SetTextColor(c[1], c[2], c[3]); p.left:Show()
    y = y + math.max(16, p.left:GetStringHeight() or 16) + 8
   elseif it.kind == 'line' then
    local c = color(it.r, it.g, it.b)
    font(p.left, 12); p.left:SetWidth(W); p.left:SetWordWrap(true); p.left:ClearAllPoints(); p.left:SetPoint('TOPLEFT', PAD, -y)
    p.left:SetText(it.text or ''); p.left:SetTextColor(c[1], c[2], c[3]); p.left:Show()
    y = y + math.max(14, p.left:GetStringHeight() or 14) + 3
   elseif it.kind == 'space' then y = y + 5
   elseif it.kind == 'rule' then
    p.rule:ClearAllPoints(); p.rule:SetPoint('TOPLEFT', PAD, -(y + 3)); p.rule:SetWidth(W)
    local c = Kit.Color('line'); p.rule:SetColorTexture(c[1], c[2], c[3], 1); p.rule:Show()
    y = y + 8
   elseif it.kind == 'double' or it.kind == 'bar' then
    local lc = color(it.lr or it.r, it.lg or it.g, it.lb or it.b)
    local rr = it.kind == 'bar' and (it.need and it.need > 0 and ('%d/%d'):format(it.have or 0, it.need) or '') or (it.right or '')
    local rc = it.kind == 'bar' and {it.r or 1, it.g or 1, it.b or 1} or color(it.rr, it.rg, it.rb)
    font(p.right, 12); p.right:ClearAllPoints(); p.right:SetPoint('TOPRIGHT', f, 'TOPRIGHT', -PAD, -y)
    p.right:SetText(rr); p.right:SetTextColor(rc[1], rc[2], rc[3]); p.right:Show()
    local rw = (p.right:GetStringWidth() or 0) + 10
    font(p.left, 12); p.left:SetWidth(math.max(60, W - rw)); p.left:SetWordWrap(false); p.left:ClearAllPoints(); p.left:SetPoint('TOPLEFT', PAD, -y)
    p.left:SetText(it.kind == 'bar' and it.text or it.left or ''); p.left:SetTextColor(lc[1], lc[2], lc[3]); p.left:Show()
    y = y + 16
    if it.kind == 'bar' then
     local track = Kit.Color('line')
     p.barBg:ClearAllPoints(); p.barBg:SetPoint('TOPLEFT', PAD, -y); p.barBg:SetWidth(W); p.barBg:SetColorTexture(track[1], track[2], track[3], 1); p.barBg:Show()
     local frac = (it.need and it.need > 0) and math.min(1, (it.have or 0) / it.need) or 0
     p.barFill:ClearAllPoints(); p.barFill:SetPoint('TOPLEFT', PAD, -y); p.barFill:SetWidth(math.max(1, W * frac))
     p.barFill:SetColorTexture(it.r or 1, it.g or 1, it.b or 1, 1); p.barFill:Show()
     y = y + 8
    else y = y + 2 end
   end
  end
  f:SetSize(W + PAD * 2, y + 10)
  local owner, a = self.owner, self.anchor
  f:ClearAllPoints()
  if not owner then f:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
  elseif a == 'ANCHOR_LEFT' then f:SetPoint('TOPRIGHT', owner, 'TOPLEFT', -8, 0)
  elseif a == 'ANCHOR_BOTTOM' then f:SetPoint('TOP', owner, 'BOTTOM', 0, -6)
  elseif a == 'ANCHOR_TOP' then f:SetPoint('BOTTOM', owner, 'TOP', 0, 6)
  else f:SetPoint('TOPLEFT', owner, 'TOPRIGHT', 8, 0) end
  f:Show()
 end
 tipObject = tip
 return tip
end

-- Hem modern ipucunu hem oyunun ipucunu kapatır (satırların OnLeave'inde kullanılır)
function Kit.HideTips()
 if tipObject then tipObject:Hide() end
 if GameTooltip then GameTooltip:Hide() end
end
