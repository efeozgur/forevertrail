local _, FT = ...

-- "Rehber" sekmesi: görev penceresinde (UI/QuestDock.lua) ilk sekme. Seçili rehberi buradan takip edersin.
-- Düzen: rehber adı · gezinme (önceki / sayaç / sonraki, Atla, Harita, Seç) · adım kartı (NPC, bölge, fiil + görev adı, açıklama, durum)
-- · yolculuk (süre, mesafe, simgeli adımlar) · sonra (sıradaki NPC) · yapılacaklar · tempo ve ilerleme çubuğu.
-- Rehber panelindeki ayrıntılı görünümün (UI/Panel.lua) hafif karşılığıdır; aynı durumu (FT.view / FT.active) paylaşır.

local PAD, ROW_H, GAP = 14, 24, 10
local DEFAULT_ROWS = 3
local TYPE_COLOR = FT.TypeColor or {accept = {0.55, 0.82, 0.5}, objective = {0.98, 0.8, 0.4}, turnin = {0.55, 0.72, 0.95}, location = {0.75, 0.62, 0.95}, manual = {0.78, 0.74, 0.68}}
local TYPE_GLYPH = {accept = '!', turnin = '?', objective = '>', location = '•', manual = '•'}
local STATUS = {unknown = 'Bilinmiyor', not_taken = 'Alınmamış', active = 'Aktif', ready = 'Teslim edilebilir', turned_in = 'Teslim edilmiş'}
local STATUS_COLOR = {turned_in = {0.62, 0.78, 0.6}, ready = {0.55, 0.9, 0.5}, active = {0.98, 0.8, 0.4}, not_taken = {0.95, 0.6, 0.5}, unknown = {0.78, 0.72, 0.64}}
local JOURNEY_ROWS = 3
local MEDIA = 'Interface\\AddOns\\ForeverTrail\\Media\\route_'
local ICON = {['UÇUŞ'] = 'flight', ['ZEPLİN'] = 'zeppelin', ['GEMİ'] = 'ship', ['YÜRÜ'] = 'walk', ['ÇIKIŞ'] = 'door', ['GİRİŞ'] = 'door', ['VARIŞ'] = 'flag', ['ADIM'] = 'step'}

local box
local rows, jrows = {}, {}
local plan, planKey, planTime = {}, nil, -100

local function go(delta)
 local g = FT.guide
 if not g then return end
 if delta < 0 then FT.view = math.max(1, FT.view - 1)
 elseif g.live then FT.view = math.min(#g.steps, FT.view + 1)
 elseif FT.view < FT.active then FT.view = FT.view + 1
 elseif not FT.complete then FT.Advance(); if FT.Evaluate then FT.Evaluate() end end
 FT.Refresh()
end

-- Adımı atla: etkin adımı tamamlanmış saymadan sıradakine geç
local function skip()
 local g = FT.guide
 if not g or FT.complete then return end
 if FT.view ~= FT.active then FT.view = FT.active end
 FT.Advance(); if FT.Evaluate then FT.Evaluate() end
 FT.Refresh()
end

local function shortTitle(s)
 local info = FT.StepInfo and FT.StepInfo(s) or {title = s.questTitle or s.text or ''}
 return info.title
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

local function newJourneyRow(i)
 local K = FT.Kit
 local r = CreateFrame('Frame', nil, box)
 r:SetHeight(26)
 r.icon = r:CreateTexture(nil, 'OVERLAY'); r.icon:SetSize(16, 16); r.icon:SetPoint('LEFT', 2, 0)
 r.bar = r:CreateTexture(nil, 'BACKGROUND'); r.bar:SetWidth(2); r.bar:SetPoint('TOPLEFT', -6, 0); r.bar:SetPoint('BOTTOMLEFT', -6, 0)
 r.text = K.Text(r, 12, 'text'); r.text:SetPoint('LEFT', 26, 0); r.text:SetPoint('RIGHT', -50, 0); r.text:SetJustifyH('LEFT'); r.text:SetWordWrap(false)
 r.time = K.Text(r, 11, 'muted'); r.time:SetPoint('RIGHT', -2, 0); r.time:SetJustifyH('RIGHT')
 jrows[i] = r
 return r
end

local function playerMap()
 if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
 local ok, map = pcall(C_Map.GetBestMapForUnit, 'player')
 return ok and map or nil
end

local function distText(yards)
 if not yards then return nil end
 if yards >= 1000 then return ('%.1fk yd'):format(yards / 1000):gsub('%.', ',') end
 return ('%d yd'):format(math.floor(yards + 0.5))
end

-- Yolculuk adımları (en çok birkaç saniyede bir yeniden hesaplanır; hedef ya da bölge değişince hemen)
local function journey(target)
 if not (target and FT.RoutePlan) then plan, planKey = {}, nil; return plan end
 local key = tostring(playerMap()) .. ':' .. tostring(target.stepId) .. ':' .. tostring(target.uiMapID) .. ':' .. tostring(target.x)
 local t = GetTime and GetTime() or 0
 if key == planKey and t - planTime < 2 then return plan end
 planKey, planTime = key, t
 local steps = FT.RoutePlan(target) or {}
 local out, total = {}, 0
 for i, text in ipairs(steps) do
  local clean, seconds = text, nil
  if FT.JourneySplitTime then clean, seconds = FT.JourneySplitTime(text) end
  local label, color = 'ADIM', {0.67, 0.7, 0.76}
  if FT.JourneyClassify then label, color = FT.JourneyClassify(clean, i == #steps) end
  if seconds then total = total + seconds end
  out[#out + 1] = {text = clean, seconds = seconds, label = label, color = color, icon = ICON[label] or 'step'}
 end
 out.total = total
 plan = out
 return plan
end

-- Kaç sıradaki adım satırı sığar: yalnızca pencere elle büyütüldüyse (kalan yükseklik kadar), yoksa 0
local function rowCapacity(usedH)
 local view = FT.QuestDockViewHeight and FT.QuestDockViewHeight(0)
 if not view then return 0 end
 return math.max(0, math.min(12, math.floor((view - usedH - 40) / ROW_H)))
end

function FT.RefreshGuideTab()
 if not box then return end
 local K = FT.Kit
 local g = FT.guide
 local width = (FT.QuestDockWidth and FT.QuestDockWidth()) or 360
 box:SetWidth(width)
 local inner = width - PAD * 2
 local function hideAll()
  box.card:Hide(); box.nav:Hide(); box.journeyHead:Hide(); box.then_:Hide(); box.todo:Hide(); box.foot:Hide(); box.listHead:Hide()
  for _, r in ipairs(rows) do r:Hide() end
  for _, r in ipairs(jrows) do r:Hide() end
 end
 if not g or not g.steps or #g.steps == 0 then
  hideAll()
  box.title:SetText('Rehber seçilmedi'); box.sub:SetText('')
  box.empty:SetWidth(inner); box.empty:Show()
  box:SetHeight(110)
  return
 end
 box.empty:Hide()
 local view = FT.view or 1
 local s = g.steps[view] or g.steps[1]
 local n = #g.steps
 if FT.EnsureWaypoint then pcall(FT.EnsureWaypoint, s) end
 local info = FT.StepInfo and FT.StepInfo(s) or {title = s.questTitle or s.text or '', verb = ''}
 local tc = TYPE_COLOR[s.type] or TYPE_COLOR.manual
 local ac = K.Color('accent')
 local y = 0

 -- 1) rehber adı + seç
 box.title:SetText(g.title or '')
 box.sub:SetText((g.zone and g.zone ~= '' and g.zone or '') .. (g.levels and ((g.zone and g.zone ~= '' and '  ·  ' or '') .. g.levels .. '. seviye') or ''))
 y = 44

 -- 2) gezinme
 box.nav:Show(); box.nav:ClearAllPoints(); box.nav:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD, -y)
 box.nav:SetWidth(inner)
 box.counter:SetText(('%d / %d'):format(view, n))
 box.review:SetText(view ~= FT.active and 'inceleme' or '')
 y = y + 34

 -- 3) adım kartı
 box.card:Show(); box.card:ClearAllPoints(); box.card:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD, -y); box.card:SetWidth(inner)
 box.cardBar:SetColorTexture(tc[1], tc[2], tc[3], 1)
 local textW = inner - 24
 local cy = 12
 if info.npc then
  box.npc:SetText(info.npc); box.npc:SetTextColor(ac[1], ac[2], ac[3])
  box.npc:SetWidth(textW); box.npc:ClearAllPoints(); box.npc:SetPoint('TOPLEFT', box.card, 'TOPLEFT', 14, -cy); box.npc:Show()
  cy = cy + math.max(20, box.npc:GetStringHeight() or 20) + 1
  box.zone:SetText(info.zone or ''); box.zone:SetWidth(textW); box.zone:ClearAllPoints(); box.zone:SetPoint('TOPLEFT', box.card, 'TOPLEFT', 14, -cy)
  box.zone:SetShown(info.zone ~= nil)
  if info.zone then cy = cy + 16 end
  cy = cy + 6
 else
  box.npc:Hide(); box.zone:SetText(info.zone or ''); box.zone:SetWidth(textW); box.zone:ClearAllPoints(); box.zone:SetPoint('TOPLEFT', box.card, 'TOPLEFT', 14, -cy)
  box.zone:SetShown(info.zone ~= nil)
  if info.zone then cy = cy + 18 end
 end
 -- fiil + görev adı (türün renginde)
 box.glyph:SetText(TYPE_GLYPH[s.type] or '•'); box.glyph:SetTextColor(tc[1], tc[2], tc[3])
 box.glyph:ClearAllPoints(); box.glyph:SetPoint('TOPLEFT', box.card, 'TOPLEFT', 14, -cy)
 local verb = info.verb ~= '' and info.verb or ''
 local line = ('%s “%s”'):format(verb, info.title)
 if s.type == 'location' or s.type == 'manual' or verb == '' then line = info.title end
 box.stepLine:SetText(line); box.stepLine:SetWidth(textW - 22)
 box.stepLine:ClearAllPoints(); box.stepLine:SetPoint('TOPLEFT', box.card, 'TOPLEFT', 36, -cy)
 box.stepLine:SetTextColor(tc[1], tc[2], tc[3])
 cy = cy + math.max(18, box.stepLine:GetStringHeight() or 18) + 6
 -- açıklama
 if info.detail then
  box.detail:SetText((info.npc and (info.npc .. ': ') or '') .. info.detail)
  box.detail:SetWidth(textW); box.detail:ClearAllPoints(); box.detail:SetPoint('TOPLEFT', box.card, 'TOPLEFT', 14, -cy); box.detail:Show()
  cy = cy + math.min(48, math.max(14, box.detail:GetStringHeight() or 14)) + 6
 else box.detail:Hide() end
 -- durum + XP
 local state = FT.QuestState and FT.QuestState(s.questId, s.objectiveIndex) or {status = 'unknown'}
 local done = FT.complete and view == FT.active
 local message = done and 'Rehber tamamlandı.' or (STATUS[state.status] or 'Bilinmiyor')
 if not g.live and state.objective and state.objective.text then message = message .. ' · ' .. state.objective.text end
 if info.xp then message = message .. ('  ·  %d XP'):format(info.xp) end
 if s.x and s.y then message = message .. ('  ·  %.1f, %.1f'):format(s.x * 100, s.y * 100) end
 local sc = STATUS_COLOR[done and 'turned_in' or state.status] or STATUS_COLOR.unknown
 box.state:SetTextColor(sc[1], sc[2], sc[3]); box.state:SetText(message); box.state:SetWidth(textW)
 box.state:ClearAllPoints(); box.state:SetPoint('TOPLEFT', box.card, 'TOPLEFT', 14, -cy)
 cy = cy + math.max(14, box.state:GetStringHeight() or 14) + 6
 box.resume:SetShown(view ~= FT.active)
 if view ~= FT.active then box.resume:ClearAllPoints(); box.resume:SetPoint('TOPLEFT', box.card, 'TOPLEFT', 14, -cy); cy = cy + 28 end
 cy = cy + 6
 box.card:SetHeight(cy)
 box.glyph:SetShown(true)
 y = y + cy + GAP

 -- 4) yolculuk
 local target = FT.customTarget or s -- özel hedef varsa ona, yoksa gösterilen adıma giden yolculuk
 local steps = journey(target)
 local showSteps = #steps > 1 or (target and target.uiMapID and playerMap() and target.uiMapID ~= playerMap())
 local dist = FT.nav and FT.nav.final and FT.nav.final == target and FT.nav.dist or (FT.nav and FT.nav.dist)
 local head = {}
 if steps.total and steps.total > 0 then head[#head + 1] = ('%d:%02d'):format(math.floor(steps.total / 60), steps.total % 60) end
 if dist and playerMap() == (target and target.uiMapID) then head[#head + 1] = distText(dist) end
 box.journeyHead:Show(); box.journeyHead:ClearAllPoints(); box.journeyHead:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD, -y); box.journeyHead:SetWidth(inner)
 box.journeyHead.right:SetText(table.concat(head, '  ·  '))
 y = y + 22
 local shownJ = 0
 if showSteps then
  for i = 1, math.min(#steps, JOURNEY_ROWS + 1) do
   local st = steps[i]
   local r = jrows[i] or newJourneyRow(i)
   r:ClearAllPoints(); r:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD + 8, -y); r:SetWidth(inner - 8)
   r.icon:SetTexture(MEDIA .. st.icon); r.icon:SetVertexColor(st.color[1], st.color[2], st.color[3], i == 1 and 1 or 0.7)
   r.text:SetText(st.text)
   local c = K.Color(i == 1 and 'text' or 'muted'); r.text:SetTextColor(c[1], c[2], c[3])
   r.time:SetText(st.seconds and ('%d:%02d'):format(math.floor(st.seconds / 60), st.seconds % 60) or '')
   r.bar:SetColorTexture(ac[1], ac[2], ac[3], i == 1 and 0.9 or 0)
   r:Show(); shownJ = shownJ + 1
   y = y + 26
  end
 elseif target and target.uiMapID then
  -- aynı bölgede: tek satır
  local r = jrows[1] or newJourneyRow(1)
  r:ClearAllPoints(); r:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD + 8, -y); r:SetWidth(inner - 8)
  r.icon:SetTexture(MEDIA .. 'walk'); r.icon:SetVertexColor(0.67, 0.7, 0.76, 1)
  r.text:SetText(distText(dist) and ('Hedefe ' .. distText(dist) .. ' yürü') or 'Hedefe ilerle')
  local c = K.Color('text'); r.text:SetTextColor(c[1], c[2], c[3]); r.time:SetText(''); r.bar:SetColorTexture(ac[1], ac[2], ac[3], 0.9)
  r:Show(); shownJ = 1
  y = y + 26
 else
  box.journeyHead:Hide(); y = y - 22
 end
 for i = shownJ + 1, #jrows do jrows[i]:Hide() end
 y = y + 4

 -- 5) sonra: sıradaki NPC
 local nextStop = FT.NextStop and FT.NextStop(g, view)
 if nextStop then
  box.then_:Show(); box.then_:ClearAllPoints(); box.then_:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD, -y)
  box.then_.label:SetText('Sonra:'); box.then_.name:SetText(nextStop.npc); box.then_.name:SetTextColor(ac[1], ac[2], ac[3])
  y = y + 24
 else box.then_:Hide() end

 -- 6) yapılacaklar: teslime hazır görevler
 local pend, pendXp = 0, 0
 if FT.PendingTurnIns then pend, pendXp = FT.PendingTurnIns(s.questId) end
 if pend > 0 then
  box.todo:Show(); box.todo:ClearAllPoints(); box.todo:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD, -y); box.todo:SetWidth(inner)
  box.todo.text:SetText(('%d tamamlanmış görev başka yerde teslim edilecek%s'):format(pend, pendXp > 0 and (' (%d XP)'):format(pendXp) or ''))
  y = y + 40
 else box.todo:Hide() end

 -- 7) sıradaki adımlar (yalnızca pencere büyütüldüyse)
 local cap = rowCapacity(y + 70)
 local shown = 0
 if cap > 0 and view < n then
  box.listHead:Show(); box.listHead:ClearAllPoints(); box.listHead:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD, -y)
  y = y + 20
  box.list:ClearAllPoints(); box.list:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD, -y); box.list:SetWidth(inner)
  for i = 1, cap do
   local index = view + i
   local st = g.steps[index]
   local r = rows[i] or newRow(i)
   if st then
    shown = shown + 1
    r:ClearAllPoints(); r:SetPoint('TOPLEFT', box.list, 'TOPLEFT', 0, -(i - 1) * ROW_H); r:SetPoint('RIGHT', box.list, 'RIGHT', 0, 0)
    local c = TYPE_COLOR[st.type] or TYPE_COLOR.manual
    r.dot:SetColorTexture(c[1], c[2], c[3], 1)
    local v = FT.StepVerb and FT.StepVerb[st.type] or ''
    r.kind:SetText(v)
    r.text:SetText(shortTitle(st))
    r.index = index; r:Show()
   else r:Hide(); r.index = nil end
  end
  box.listHead.more:SetText(n - view - shown > 0 and ('+%d adım daha'):format(n - view - shown) or '')
  box.list:SetHeight(math.max(1, shown * ROW_H))
  y = y + shown * ROW_H + 6
 else box.listHead:Hide() end
 for i = shown + 1, #rows do rows[i]:Hide(); rows[i].index = nil end

 -- 8) tempo ve ilerleme
 local ratio = math.min(1, done and 1 or (view - 1) / math.max(1, n))
 box.foot:Show(); box.foot:ClearAllPoints(); box.foot:SetPoint('TOPLEFT', box, 'TOPLEFT', 0, -y); box.foot:SetWidth(width)
 local _, _, paceText = FT.Pace and FT.Pace()
 box.paceText:SetText(paceText or '')
 box.pct:SetText(('%%%d'):format(math.floor(ratio * 100 + 0.5)))
 box.fill:SetColorTexture(ac[1], ac[2], ac[3], 1)
 box.fill:SetWidth(math.max(1, width * ratio))
 y = y + 40
 box:SetHeight(y)
end

-- Rehber sekmesinin kutusunu kurar (pencere kurulurken bir kez çağrılır)
function FT.BuildGuideBox(parent)
 if box then return box end
 local K = FT.Kit
 box = CreateFrame('Frame', 'ForeverTrailGuideTab', parent)
 FT.guideBox = box
 box:SetSize(360, 300)
 -- rehber adı
 box.title = K.Text(box, 14, 'text'); box.title:SetPoint('TOPLEFT', PAD, -10); box.title:SetPoint('RIGHT', box, 'RIGHT', -PAD - 84, 0); box.title:SetJustifyH('LEFT'); box.title:SetWordWrap(false)
 box.sub = K.Text(box, 11, 'muted'); box.sub:SetPoint('TOPLEFT', PAD, -28); box.sub:SetPoint('RIGHT', box, 'RIGHT', -PAD - 84, 0); box.sub:SetJustifyH('LEFT'); box.sub:SetWordWrap(false)
 box.pick = K.Button(box, 'Rehber seç', 78, 22)
 box.pick:SetPoint('TOPRIGHT', box, 'TOPRIGHT', -PAD, -9)
 box.pick:SetScript('OnClick', function() if FT.ToggleGuidePicker then FT.ToggleGuidePicker() end end)
 -- gezinme
 box.nav = CreateFrame('Frame', nil, box); box.nav:SetSize(300, 28)
 local prev = K.Button(box.nav, '<', 26, 24); prev:SetPoint('LEFT', 0, 0); prev:SetScript('OnClick', function() go(-1) end)
 box.counter = K.Text(box.nav, 13, 'text'); box.counter:SetPoint('LEFT', prev, 'RIGHT', 8, 0)
 local nxt = K.Button(box.nav, '>', 26, 24); nxt:SetPoint('LEFT', box.counter, 'RIGHT', 8, 0); nxt:SetScript('OnClick', function() go(1) end)
 box.review = K.Text(box.nav, 10, 'muted'); box.review:SetPoint('LEFT', nxt, 'RIGHT', 8, 0)
 local sel = K.Button(box.nav, 'Seç', 40, 24); sel:SetPoint('RIGHT', 0, 0)
 sel:SetScript('OnClick', function() if FT.ToggleGuidePicker then FT.ToggleGuidePicker() end end)
 sel:Hide() -- üstteki "Rehber seç" yeterli; düğme konumu ileride kullanılabilir
 local atla = K.Button(box.nav, 'Atla', 46, 24); atla:SetPoint('RIGHT', 0, 0); atla:SetScript('OnClick', skip)
 local map = K.Button(box.nav, 'Harita', 58, 24); map:SetPoint('RIGHT', atla, 'LEFT', -4, 0)
 map:SetScript('OnClick', function() if FT.OpenMap then FT.OpenMap() end end)
 box.prev, box.next, box.map, box.skip = prev, nxt, map, atla
 -- adım kartı
 box.card = CreateFrame('Frame', nil, box); box.card:SetHeight(120)
 local cbg = box.card:CreateTexture(nil, 'BACKGROUND'); cbg:SetAllPoints(); K.Fill(cbg, 'card', 0.9)
 box.cardBar = box.card:CreateTexture(nil, 'ARTWORK'); box.cardBar:SetWidth(3); box.cardBar:SetPoint('TOPLEFT', 0, 0); box.cardBar:SetPoint('BOTTOMLEFT', 0, 0)
 box.npc = K.Text(box.card, 17, 'accent'); box.npc:SetJustifyH('LEFT'); box.npc:SetJustifyV('TOP')
 box.zone = K.Text(box.card, 12, 'muted'); box.zone:SetJustifyH('LEFT')
 box.glyph = K.Text(box.card, 16, 'text'); box.glyph:SetWidth(18)
 box.stepLine = K.Text(box.card, 14, 'text'); box.stepLine:SetJustifyH('LEFT'); box.stepLine:SetJustifyV('TOP')
 box.detail = K.Text(box.card, 12, 'muted'); box.detail:SetJustifyH('LEFT'); box.detail:SetJustifyV('TOP'); box.detail:SetHeight(48)
 box.state = K.Text(box.card, 11, 'muted'); box.state:SetJustifyH('LEFT'); box.state:SetJustifyV('TOP')
 box.resume = K.Button(box.card, 'Buradan sürdür', 112, 24)
 box.resume:SetScript('OnClick', function() if FT.ResumeViewed then FT.ResumeViewed() end end)
 -- yolculuk başlığı
 box.journeyHead = CreateFrame('Frame', nil, box); box.journeyHead:SetSize(300, 18)
 box.journeyHead.text = K.Text(box.journeyHead, 11, 'muted'); box.journeyHead.text:SetPoint('LEFT', 0, 0); box.journeyHead.text:SetText('Yolculuk')
 box.journeyHead.right = K.Text(box.journeyHead, 11, 'text'); box.journeyHead.right:SetPoint('RIGHT', 0, 0); box.journeyHead.right:SetJustifyH('RIGHT')
 -- sonra
 box.then_ = CreateFrame('Frame', nil, box); box.then_:SetSize(300, 20)
 box.then_.label = K.Text(box.then_, 12, 'muted'); box.then_.label:SetPoint('LEFT', 0, 0)
 box.then_.name = K.Text(box.then_, 12, 'accent'); box.then_.name:SetPoint('LEFT', box.then_.label, 'RIGHT', 6, 0)
 -- yapılacaklar
 box.todo = CreateFrame('Frame', nil, box); box.todo:SetSize(300, 36)
 box.todo.head = K.Text(box.todo, 11, 'muted'); box.todo.head:SetPoint('TOPLEFT', 0, 0); box.todo.head:SetText('Yapılacaklar')
 box.todo.text = K.Text(box.todo, 12, 'text'); box.todo.text:SetPoint('TOPLEFT', 0, -16); box.todo.text:SetPoint('RIGHT', 0, 0); box.todo.text:SetJustifyH('LEFT'); box.todo.text:SetWordWrap(false)
 -- sıradaki adımlar
 box.listHead = CreateFrame('Frame', nil, box); box.listHead:SetSize(200, 18)
 box.listHead.text = K.Text(box.listHead, 11, 'muted'); box.listHead.text:SetPoint('LEFT', 0, 0); box.listHead.text:SetText('Sıradakiler')
 box.listHead.more = K.Text(box.listHead, 10, 'muted'); box.listHead.more:SetPoint('LEFT', box.listHead.text, 'RIGHT', 8, 0)
 box.list = CreateFrame('Frame', nil, box); box.list:SetSize(300, ROW_H)
 -- alt: tempo + ilerleme çubuğu
 box.foot = CreateFrame('Frame', nil, box); box.foot:SetSize(360, 36)
 local rule = K.Divider(box.foot); rule:SetPoint('TOPLEFT', 0, 0); rule:SetPoint('TOPRIGHT', 0, 0)
 box.paceText = K.Text(box.foot, 11, 'muted'); box.paceText:SetPoint('TOPLEFT', PAD, -8); box.paceText:SetJustifyH('LEFT')
 box.pct = K.Text(box.foot, 11, 'text'); box.pct:SetPoint('TOPRIGHT', -PAD, -8); box.pct:SetJustifyH('RIGHT')
 local track = box.foot:CreateTexture(nil, 'ARTWORK'); track:SetHeight(4); track:SetPoint('BOTTOMLEFT', 0, 0); track:SetPoint('BOTTOMRIGHT', 0, 0); K.Fill(track, 'line', 0.8)
 box.fill = box.foot:CreateTexture(nil, 'OVERLAY'); box.fill:SetHeight(4); box.fill:SetPoint('BOTTOMLEFT', 0, 0)
 -- boş durum
 box.empty = K.Text(box, 12, 'muted'); box.empty:SetPoint('TOPLEFT', PAD, -56); box.empty:SetJustifyH('LEFT'); box.empty:SetJustifyV('TOP')
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

-- Test ve tanı için
function FT.GuideTabRows()
 local n = 0
 for _, r in ipairs(rows) do if r:IsShown() then n = n + 1 end end
 return n
end
function FT.GuideTabRow(i) return rows[i] end
function FT.GuideTabJourneyRows()
 local n = 0
 for _, r in ipairs(jrows) do if r:IsShown() then n = n + 1 end end
 return n
end
