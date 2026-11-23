local _, FT = ...

-- Ortak arayüz bileşenleri (düz, kenarlıksız-oyun-şablonu görünümü): kademeli zemin, ince çizgi, tek vurgu rengi.
-- Renkler temadan türetilir; tema değişince kayıtlı her bileşen kendini yeniden boyar (FT.themeListeners).

local Kit = {}
FT.Kit = Kit

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
  local off = self.IsEnabled and self:IsEnabled() == false
  local fill, edge, text
  if off then fill, edge, text = Kit.Color('mid'), Kit.Color('line'), Kit.Color('muted')
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
