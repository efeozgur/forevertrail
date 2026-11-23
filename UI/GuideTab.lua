local _, FT = ...

-- "Rehber" sekmesi: görev penceresinde (UI/QuestDock.lua) ilk sekme. Seçili rehberi buradan takip edersin:
-- rehberin adı ve ilerlemesi, şu anki adım, adımlar arası gezinme ve sıradaki adımların listesi.
-- Rehber panelindeki ayrıntılı görünümün (yolculuk, hızlı eylemler) hafif bir özetidir; aynı durumu (FT.view / FT.active) paylaşır.

local HEAD_H, CARD_PAD, ROW_H, BAR_H = 52, 12, 26, 4
local DEFAULT_ROWS = 6
local TYPE_COLOR = FT.TypeColor or {accept = {0.55, 0.82, 0.5}, objective = {0.98, 0.8, 0.4}, turnin = {0.55, 0.72, 0.95}, location = {0.75, 0.62, 0.95}, manual = {0.78, 0.74, 0.68}}
local TYPE_LABEL = {accept = 'GÖREVİ AL', objective = 'HEDEF', turnin = 'TESLİM ET', location = 'KONUMA GİT', manual = 'ELLE ONAYLA'}
local TYPE_SHORT = {accept = 'AL', objective = 'HEDEF', turnin = 'TESLİM', location = 'YER', manual = 'ELLE'}
local STATUS = {unknown = 'Bilinmiyor', not_taken = 'Alınmamış', active = 'Aktif', ready = 'Teslim edilebilir', turned_in = 'Teslim edilmiş'}
local STATUS_COLOR = {turned_in = {0.62, 0.78, 0.6}, ready = {0.55, 0.9, 0.5}, active = {0.98, 0.8, 0.4}, not_taken = {0.95, 0.6, 0.5}, unknown = {0.78, 0.72, 0.64}}

local box
local rows = {}

local function stepTitle(s)
 local record = type(QTR_QuestData) == 'table' and s.questId and QTR_QuestData[tostring(s.questId)]
 local title = (record and record.Title) or s.questTitle
 if type(title) == 'string' and title ~= '' then return title, s.text end
 return s.text or '', ''
end

local function go(delta)
 local g = FT.guide
 if not g then return end
 if delta < 0 then FT.view = math.max(1, FT.view - 1)
 elseif g.live then FT.view = math.min(#g.steps, FT.view + 1)
 elseif FT.view < FT.active then FT.view = FT.view + 1
 elseif not FT.complete then FT.Advance(); if FT.Evaluate then FT.Evaluate() end end
 FT.Refresh()
end

local function newRow(i)
 local K = FT.Kit
 local r = CreateFrame('Button', nil, box.list)
 r:SetHeight(ROW_H)
 r.hl = r:CreateTexture(nil, 'BACKGROUND'); r.hl:SetAllPoints(); K.Fill(r.hl, 'card', 0.9); r.hl:Hide()
 r.dot = r:CreateTexture(nil, 'ARTWORK'); r.dot:SetSize(3, 14); r.dot:SetPoint('LEFT', 2, 0)
 r.kind = K.Text(r, 10, 'muted'); r.kind:SetPoint('LEFT', 12, 0); r.kind:SetWidth(46); r.kind:SetJustifyH('LEFT')
 r.text = K.Text(r, 12, 'text'); r.text:SetPoint('LEFT', 62, 0); r.text:SetPoint('RIGHT', -6, 0); r.text:SetJustifyH('LEFT'); r.text:SetWordWrap(false)
 r:SetScript('OnEnter', function(self) self.hl:Show() end)
 r:SetScript('OnLeave', function(self) self.hl:Hide() end)
 r:SetScript('OnClick', function(self) if self.index then FT.view = self.index; FT.Refresh() end end)
 rows[i] = r
 return r
end

-- Kaç sıradaki adım satırı sığar: elle ayarlanan pencere yüksekliğine göre, yoksa varsayılan
local function rowCapacity(fixedH)
 local view = FT.QuestDockViewHeight and FT.QuestDockViewHeight(0)
 if not view then return DEFAULT_ROWS end
 return math.max(2, math.floor((view - fixedH) / ROW_H))
end

function FT.RefreshGuideTab()
 if not box then return end
 local K = FT.Kit
 local g = FT.guide
 local width = (FT.QuestDockWidth and FT.QuestDockWidth()) or 360
 box:SetWidth(width)
 local textW = width - CARD_PAD * 2 - 8
 if not g or not g.steps or #g.steps == 0 then
  box.title:SetText('Rehber seçilmedi'); box.sub:SetText('Aşağıdaki düğmeyle bir rehber ya da bölge seç.')
  box.progress:SetText(''); box.fill:SetWidth(1)
  box.card:Hide(); box.nav:Hide()
  for _, r in ipairs(rows) do r:Hide() end
  box.listHead:Hide()
  box.empty:SetWidth(textW); box.empty:Show()
  box:SetHeight(HEAD_H + 90)
  return
 end
 box.empty:Hide(); box.card:Show(); box.nav:Show()
 local view = FT.view or 1
 local s = g.steps[view] or g.steps[1]
 box.title:SetText(g.title or '')
 box.sub:SetText((g.zone or '') .. (g.levels and ('  ·  ' .. g.levels .. '. seviye') or ''))
 local n = #g.steps
 local ratio = math.min(1, (FT.complete and view == FT.active) and 1 or view / math.max(1, n))
 box.progress:SetText(('%d / %d  ·  %%%d'):format(view, n, math.floor(ratio * 100 + 0.5)))
 local ac = K.Color('accent')
 box.fill:SetColorTexture(ac[1], ac[2], ac[3], 1)
 box.fill:SetWidth(math.max(1, (width - CARD_PAD * 2) * ratio))
 -- şu anki adım
 if FT.EnsureWaypoint then pcall(FT.EnsureWaypoint, s) end
 local tc = TYPE_COLOR[s.type] or TYPE_COLOR.manual
 box.chip:Set(TYPE_LABEL[s.type] or tostring(s.type), tc[1], tc[2], tc[3])
 box.review:SetText(view ~= FT.active and '(inceleme)' or '')
 local title, detail = stepTitle(s)
 box.stepTitle:SetWidth(textW); box.stepTitle:SetText(title)
 box.stepText:SetWidth(textW); box.stepText:SetText(detail or '')
 local state = FT.QuestState and FT.QuestState(s.questId, s.objectiveIndex) or {status = 'unknown'}
 local message = (FT.complete and view == FT.active) and 'Rehber tamamlandı.' or (STATUS[state.status] or 'Bilinmiyor')
 if not g.live and state.objective and state.objective.text then message = message .. ' - ' .. state.objective.text end
 if s.x and s.y then message = message .. ('  ·  %.1f, %.1f'):format(s.x * 100, s.y * 100) end
 local sc = STATUS_COLOR[(FT.complete and view == FT.active) and 'turned_in' or state.status] or STATUS_COLOR.unknown
 box.state:SetTextColor(sc[1], sc[2], sc[3]); box.state:SetWidth(textW); box.state:SetText(message)
 -- kart yüksekliği içeriğe göre
 local y = 34
 box.stepTitle:ClearAllPoints(); box.stepTitle:SetPoint('TOPLEFT', box.card, 'TOPLEFT', CARD_PAD, -y)
 y = y + math.max(16, box.stepTitle:GetStringHeight() or 16) + 4
 local hasDetail = type(detail) == 'string' and detail ~= ''
 box.stepText:SetShown(hasDetail)
 if hasDetail then
  box.stepText:ClearAllPoints(); box.stepText:SetPoint('TOPLEFT', box.card, 'TOPLEFT', CARD_PAD, -y)
  y = y + math.max(14, box.stepText:GetStringHeight() or 14) + 6
 end
 box.state:ClearAllPoints(); box.state:SetPoint('TOPLEFT', box.card, 'TOPLEFT', CARD_PAD, -y)
 y = y + math.max(14, box.state:GetStringHeight() or 14) + 10
 box.card:SetHeight(y)
 -- gezinme düğmeleri
 box.resume:SetShown(view ~= FT.active)
 box.nav:ClearAllPoints(); box.nav:SetPoint('TOPLEFT', box.card, 'BOTTOMLEFT', 0, -8)
 -- sıradaki adımlar
 local top = HEAD_H + y + 8 + 28 + 8
 local fixed = top + 30
 local cap = rowCapacity(fixed)
 box.listHead:Show(); box.listHead:ClearAllPoints(); box.listHead:SetPoint('TOPLEFT', box, 'TOPLEFT', CARD_PAD, -top)
 box.list:ClearAllPoints(); box.list:SetPoint('TOPLEFT', box, 'TOPLEFT', CARD_PAD, -(top + 22)); box.list:SetWidth(width - CARD_PAD * 2)
 local shown = 0
 for i = 1, cap do
  local index = view + i
  local st = g.steps[index]
  local r = rows[i] or newRow(i)
  if st then
   shown = shown + 1
   r:ClearAllPoints(); r:SetPoint('TOPLEFT', box.list, 'TOPLEFT', 0, -(i - 1) * ROW_H); r:SetPoint('RIGHT', box.list, 'RIGHT', 0, 0)
   local c = TYPE_COLOR[st.type] or TYPE_COLOR.manual
   r.dot:SetColorTexture(c[1], c[2], c[3], 1)
   r.kind:SetText(TYPE_SHORT[st.type] or '')
   local t = stepTitle(st)
   r.text:SetText(t)
   r.index = index; r:Show()
  else r:Hide(); r.index = nil end
 end
 for i = cap + 1, #rows do rows[i]:Hide() end
 local remaining = n - view - shown
 box.listHead.more:SetText(remaining > 0 and ('+%d adım daha'):format(remaining) or (view >= n and 'son adım' or ''))
 box.list:SetHeight(math.max(1, shown * ROW_H))
 box:SetHeight(top + 22 + math.max(shown, 1) * ROW_H + 10)
end

-- Rehber sekmesinin kutusunu kurar (pencere kurulurken bir kez çağrılır)
function FT.BuildGuideBox(parent)
 if box then return box end
 local K = FT.Kit
 box = CreateFrame('Frame', 'ForeverTrailGuideTab', parent)
 FT.guideBox = box
 box:SetSize(360, 300)
 -- başlık: rehberin adı, bölge/seviye, ilerleme çubuğu
 box.title = K.Text(box, 14, 'text'); box.title:SetPoint('TOPLEFT', CARD_PAD, -10); box.title:SetPoint('RIGHT', box, 'RIGHT', -92, 0); box.title:SetJustifyH('LEFT'); box.title:SetWordWrap(false)
 box.sub = K.Text(box, 11, 'muted'); box.sub:SetPoint('TOPLEFT', CARD_PAD, -29); box.sub:SetPoint('RIGHT', box, 'RIGHT', -CARD_PAD, 0); box.sub:SetJustifyH('LEFT'); box.sub:SetWordWrap(false)
 box.pick = K.Button(box, 'Rehber seç', 76, 22)
 box.pick:SetPoint('TOPRIGHT', box, 'TOPRIGHT', -CARD_PAD, -8)
 box.pick:SetScript('OnClick', function() if FT.ToggleGuidePicker then FT.ToggleGuidePicker() end end)
 local track = box:CreateTexture(nil, 'ARTWORK'); track:SetHeight(BAR_H)
 track:SetPoint('TOPLEFT', box, 'TOPLEFT', CARD_PAD, -(HEAD_H - 4)); track:SetPoint('TOPRIGHT', box, 'TOPRIGHT', -CARD_PAD, -(HEAD_H - 4))
 K.Fill(track, 'line', 0.8)
 box.fill = box:CreateTexture(nil, 'OVERLAY'); box.fill:SetHeight(BAR_H); box.fill:SetPoint('TOPLEFT', track, 'TOPLEFT', 0, 0)
 K.Fill(box.fill, 'accent')
 -- şu anki adım kartı
 box.card = CreateFrame('Frame', nil, box)
 box.card:SetPoint('TOPLEFT', box, 'TOPLEFT', CARD_PAD, -(HEAD_H + 6)); box.card:SetPoint('TOPRIGHT', box, 'TOPRIGHT', -CARD_PAD, -(HEAD_H + 6))
 box.card:SetHeight(90)
 local cbg = box.card:CreateTexture(nil, 'BACKGROUND'); cbg:SetAllPoints(); K.Fill(cbg, 'card', 0.9)
 box.chip = K.Chip(box.card); box.chip:SetPoint('TOPLEFT', CARD_PAD, -10)
 box.review = K.Text(box.card, 10, 'muted'); box.review:SetPoint('LEFT', box.chip, 'RIGHT', 8, 0)
 box.progress = K.Text(box.card, 11, 'muted'); box.progress:SetPoint('TOPRIGHT', box.card, 'TOPRIGHT', -CARD_PAD, -12); box.progress:SetJustifyH('RIGHT')
 box.stepTitle = K.Text(box.card, 13, 'text'); box.stepTitle:SetJustifyH('LEFT'); box.stepTitle:SetJustifyV('TOP')
 box.stepText = K.Text(box.card, 12, 'muted'); box.stepText:SetJustifyH('LEFT'); box.stepText:SetJustifyV('TOP')
 box.state = K.Text(box.card, 11, 'muted'); box.state:SetJustifyH('LEFT'); box.state:SetJustifyV('TOP')
 -- gezinme: önceki / sonraki / haritada göster / buradan sürdür
 box.nav = CreateFrame('Frame', nil, box); box.nav:SetSize(100, 28)
 local prev = K.Button(box.nav, '<', 28, 24); prev:SetPoint('LEFT', 0, 0)
 prev:SetScript('OnClick', function() go(-1) end)
 local nxt = K.Button(box.nav, '>', 28, 24); nxt:SetPoint('LEFT', prev, 'RIGHT', 4, 0)
 nxt:SetScript('OnClick', function() go(1) end)
 local map = K.Button(box.nav, 'Haritada göster', 104, 24); map:SetPoint('LEFT', nxt, 'RIGHT', 8, 0)
 map:SetScript('OnClick', function() if FT.OpenMap then FT.OpenMap() end end)
 box.resume = K.Button(box.nav, 'Buradan sürdür', 104, 24); box.resume:SetPoint('LEFT', map, 'RIGHT', 4, 0)
 box.resume:SetScript('OnClick', function() if FT.ResumeViewed then FT.ResumeViewed() end end)
 box.prev, box.next, box.map = prev, nxt, map
 -- sıradaki adımlar
 box.listHead = CreateFrame('Frame', nil, box); box.listHead:SetSize(200, 18)
 box.listHead.text = K.Text(box.listHead, 11, 'accent'); box.listHead.text:SetPoint('LEFT', 0, 0); box.listHead.text:SetText('Sıradakiler')
 box.listHead.more = K.Text(box.listHead, 10, 'muted'); box.listHead.more:SetPoint('LEFT', box.listHead.text, 'RIGHT', 8, 0)
 box.list = CreateFrame('Frame', nil, box); box.list:SetSize(300, ROW_H)
 box.empty = K.Text(box, 12, 'muted'); box.empty:SetPoint('TOPLEFT', CARD_PAD, -(HEAD_H + 14)); box.empty:SetJustifyH('LEFT'); box.empty:SetJustifyV('TOP')
 box.empty:SetText('Görev günlüğünü izleyen rehber, hazır bir rehber ya da seviyene göre bir bölge rehberi seçebilirsin. Bölge rehberleri görev veritabanından hazırlanır.')
 box.empty:Hide()
 if FT.FixFonts then pcall(FT.FixFonts, box) end
 -- rehber durumu değişince (adım ilerledi, rehber seçildi) sekme de güncellenir
 local refresh = FT.Refresh
 FT.Refresh = function(...)
  local r = refresh(...)
  pcall(FT.RefreshGuideTab)
  if FT.RefreshQuestDock then FT.RefreshQuestDock() end
  return r
 end
 return box
end

-- Sekme başlığındaki sayaç: rehber yüzdesi
function FT.GuideProgressText()
 local g = FT.guide
 if not g or not g.steps or #g.steps == 0 then return '' end
 local ratio = (FT.complete and 1) or ((FT.active or 1) - 1) / #g.steps
 return ('%%%d'):format(math.floor(ratio * 100 + 0.5))
end

-- Test ve tanı için: gösterilen sıradaki adım satırı sayısı
function FT.GuideTabRows()
 local n = 0
 for _, r in ipairs(rows) do if r:IsShown() then n = n + 1 end end
 return n
end
function FT.GuideTabRow(i) return rows[i] end
