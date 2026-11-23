local _, FT = ...

-- Rehber seçici: hazır rehberler, seviyene uygun bölge rehberleri ve tüm bölgeler tek pencerede.
-- Bölge rehberleri görev veritabanından, karakterin ırkına, sınıfına ve seviyesine göre hazırlanır (Guide/AutoGuide.lua).

local WIDTH, HEIGHT, PAD = 520, 620, 18
local CW = WIDTH - PAD * 2 - 8
local win, scroll, content, intro
local rows, heads = {}, {}

local function currentId() return FT.guide and FT.guide.guideId end

local function money(n) n = math.floor((n or 0) + 0.5); if n >= 1000 then return ('%d.%03d'):format(math.floor(n / 1000), n % 1000) end return tostring(n) end

local function newRow(i)
 local K = FT.Kit
 local r = CreateFrame('Button', nil, content)
 r:SetSize(CW, 52)
 r.hl = r:CreateTexture(nil, 'BACKGROUND'); r.hl:SetAllPoints(); K.Fill(r.hl, 'card', 0.9); r.hl:Hide()
 r.sep = r:CreateTexture(nil, 'ARTWORK'); r.sep:SetHeight(1); r.sep:SetPoint('TOPLEFT', 0, 0); r.sep:SetPoint('TOPRIGHT', 0, 0); K.Fill(r.sep, 'line', 0.55)
 r.title = K.Text(r, 14, 'text'); r.title:SetPoint('TOPLEFT', 6, -9); r.title:SetJustifyH('LEFT'); r.title:SetWordWrap(false)
 r.sub = K.Text(r, 12, 'muted'); r.sub:SetPoint('TOPLEFT', 6, -29); r.sub:SetJustifyH('LEFT'); r.sub:SetWordWrap(false)
 r.chip = K.Chip(r); r.chip:SetPoint('TOPRIGHT', -6, -10)
 r:SetScript('OnEnter', function(self) self.hl:Show() end)
 r:SetScript('OnLeave', function(self) self.hl:Hide() end)
 r:SetScript('OnClick', function(self) if self.pick then self.pick() end end)
 rows[i] = r
 return r
end

local function newHead(i)
 local K = FT.Kit
 local h = CreateFrame('Frame', nil, content)
 h:SetSize(CW, 30)
 h.text = K.Text(h, 12, 'accent'); h.text:SetPoint('BOTTOMLEFT', 6, 6); h.text:SetJustifyH('LEFT')
 h.hint = K.Text(h, 11, 'muted'); h.hint:SetPoint('BOTTOMRIGHT', -6, 6); h.hint:SetJustifyH('RIGHT')
 heads[i] = h
 return h
end

local function close() if win then win:Hide() end end

local function pickAuto(z)
 return function()
  local ok, result = FT.AutoGuide.Select(z.map, z.lo, z.hi)
  if ok then
   FT.notice = 'Bölge rehberi seçildi. Görev sırası: merkezde görevleri al, hedeflere git, teslim et.'
   close(); if FT.Refresh then FT.Refresh() end
  else FT.Print(tostring(result)) end
 end
end

local function pickStatic(index)
 return function() FT.SelectGuide(index); FT.notice = 'Rehber seçildi.'; close(); if FT.Refresh then FT.Refresh() end end
end

-- Liste: önce hazır rehberler, sonra seviyene uygun bölgeler, sonra tüm bölgeler (seviye bandına göre başlıklı)
local function refresh()
 for _, r in ipairs(rows) do r:Hide() end
 for _, h in ipairs(heads) do h:Hide() end
 local level = UnitLevel and UnitLevel('player') or 1
 local zones = FT.AutoGuide and FT.AutoGuide.Zones() or {}
 local usedRow, usedHead, y = 0, 0, 4
 local current = currentId()
 local function head(text, hint)
  usedHead = usedHead + 1
  local h = heads[usedHead] or newHead(usedHead)
  h:ClearAllPoints(); h:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, -y)
  h.text:SetText(text); h.hint:SetText(hint or ''); h:Show()
  y = y + 30
 end
 local function row(title, sub, chipText, chipColor, pick, first)
  usedRow = usedRow + 1
  local r = rows[usedRow] or newRow(usedRow)
  r:ClearAllPoints(); r:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, -y)
  r.sep:SetShown(not first)
  r.title:SetText(title); r.sub:SetText(sub)
  if chipText then r.chip:Set(chipText, chipColor[1], chipColor[2], chipColor[3]); r.chip:Show() else r.chip:Hide() end
  r.title:SetWidth(CW - 12 - (chipText and (r.chip:GetWidth() + 16) or 0)); r.sub:SetWidth(CW - 12)
  r.pick = pick; r:Show()
  y = y + 52
 end
 local function zoneRow(z, first)
  local sub = ('%d görev  ·  %d adım'):format(z.count, z.steps or 0)
  if (z.xp or 0) > 0 then sub = sub .. ('  ·  ~%s XP'):format(money(z.xp)) end
  local chip, color
  if current == ('auto-%d-%d-%d'):format(z.map, z.lo, z.hi) then chip, color = 'Seçili', {0.55, 0.9, 0.5} end
  row(('%s  ·  %d-%d'):format(z.name, z.lo, z.hi), sub, chip, color, pickAuto(z), first)
 end

 -- 1) hazır rehberler
 local statics = {}
 for index, g in ipairs(FT.validGuides or {}) do if not g.auto then statics[#statics + 1] = {index = index, guide = g} end end
 if #statics > 0 then
  head('Hazır rehberler', 'elle yazılmış ya da günlüğünü izleyen')
  for i, e in ipairs(statics) do
   local g = e.guide
   local chip, color
   if current == g.guideId then chip, color = 'Seçili', {0.55, 0.9, 0.5} elseif g.live then chip, color = 'Günlüğünü izler', {0.55, 0.8, 1} end
   row(g.title, g.zone or '', chip, color, pickStatic(e.index), i == 1)
  end
 end

 -- 2) seviyene uygun bölgeler
 local recommended = {}
 for _, z in ipairs(zones) do if z.recommended then recommended[#recommended + 1] = z end end
 table.sort(recommended, function(a, b)
  local ca, cb = (a.lo + a.hi) / 2, (b.lo + b.hi) / 2
  local da, db = math.abs(ca - level), math.abs(cb - level)
  if da ~= db then return da < db end
  if a.count ~= b.count then return a.count > b.count end
  return a.map < b.map
 end)
 if #recommended > 0 then
  head(('Seviye %d için önerilen bölgeler'):format(level), 'görev sayısı fazla olan başta')
  for i, z in ipairs(recommended) do zoneRow(z, i == 1) end
 end

 -- 3) tüm bölgeler, seviye bandına göre
 if #zones > 0 then
  local band, row_first
  for _, z in ipairs(zones) do
   local b = math.floor((z.lo - 1) / 10)
   if b ~= band then band = b; head(('Seviye %d-%d'):format(b * 10 + 1, b * 10 + 10)); row_first = true end
   zoneRow(z, row_first); row_first = false
  end
 else
  head('Bölge rehberi yok', '')
  usedRow = usedRow + 1
 end
 content:SetHeight(math.max(10, y + 10))
 content:SetWidth(CW)
 local range = math.max(0, y + 10 - (scroll:GetHeight() or 400))
 if (scroll:GetVerticalScroll() or 0) > range then scroll:SetVerticalScroll(range) end
end

local function build()
 local K = FT.Kit
 win = FT.NewWindow('ForeverTrailGuidePicker', UIParent)
 win:SetSize(WIDTH, HEIGHT); win:SetPoint('CENTER', UIParent, 'CENTER', 0, 20); win:SetFrameStrata('DIALOG')
 win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag('LeftButton'); win:SetClampedToScreen(true)
 win:SetScript('OnDragStart', function(self) self:StartMoving() end)
 win:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
 local title = K.Text(win, 14, 'accent'); title:SetPoint('TOPLEFT', PAD, -8); title:SetText('Rehber seç')
 intro = K.Text(win, 12, 'muted'); intro:SetPoint('TOPLEFT', PAD, -42); intro:SetWidth(WIDTH - PAD * 2); intro:SetJustifyH('LEFT'); intro:SetJustifyV('TOP')
 intro:SetText('Bölge rehberleri görev veritabanından, ırkına, sınıfına ve seviyene göre hazırlanır. Sıra: bir merkezde önce oradaki görevleri al, sonra hedeflere git, sonra teslim et; zincirlerin devamı aynı NPC\'den alınır. İlerleme otomatik izlenir, istediğin adımı atlayabilirsin.')
 local rule = K.Divider(win); rule:SetPoint('TOPLEFT', 1, -96); rule:SetPoint('TOPRIGHT', -1, -96)
 scroll = K.Scroll(win)
 scroll:SetPoint('TOPLEFT', PAD, -104); scroll:SetPoint('BOTTOMRIGHT', -PAD - 8, 14)
 content = CreateFrame('Frame', nil, scroll)
 content:SetSize(CW, 10)
 scroll:SetScrollChild(content)
 if UISpecialFrames then tinsert(UISpecialFrames, 'ForeverTrailGuidePicker') end
 win:SetScript('OnShow', refresh)
 win:Hide()
 if FT.FixFonts then pcall(FT.FixFonts, win) end
end

function FT.ToggleGuidePicker()
 if not win then
  local ok, err = pcall(build)
  if not ok then win = nil; FT.Print('Rehber seçici açılamadı: ' .. tostring(err)); return false end
 end
 if win:IsShown() then win:Hide() else win:Show(); if scroll and scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end end
 return true
end

-- Test ve tanı için: listedeki satır ve başlık sayısı
function FT.GuidePickerInfo()
 local r, h = 0, 0
 for _, x in ipairs(rows) do if x:IsShown() then r = r + 1 end end
 for _, x in ipairs(heads) do if x:IsShown() then h = h + 1 end end
 return r, h
end

-- Test ve tanı için: i. görünen satır
function FT.GuidePickerRow(i) return rows[i] end
