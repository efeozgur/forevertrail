local _, FT = ...

-- "Görevlerim" listesi (görev penceresinin ilk sekmesi). Eski takip kutusunun çizimi yerine geçer; veri, sıralama, sabitleme,
-- odak, daraltma ve ilerleme efektleri eskisiyle aynı anahtarları ve yardımcıları kullanır.
--
-- Tasarım: bol boşluk ve açık bir yazı hiyerarşisi. Görev adı büyük ve nötr renkte, hedefler soluk ve küçük; renk yalnızca
-- anlam taşıyan yerde (seviye rozeti zorluk renginde, "Teslim" yeşil, ilerleme vurgu renginde). Her görev tek ve bitişik bir
-- bloktur: tıklama ve ipucu bloğun tamamında çalışır, bloklar arasında ölü boşluk yoktur.

local PAD = 16
local WIDTH = 360
local CW = WIDTH - PAD * 2 -- içerik genişliği
local MAX_QUESTS = 12

local state = {}
local blocks, zones = {}, {}

local function charStore(key)
 ForeverTrailCharacter = ForeverTrailCharacter or {}
 ForeverTrailCharacter[key] = ForeverTrailCharacter[key] or {}
 return ForeverTrailCharacter[key]
end

-- Görev uzaklığı kısa süreli önbellekte tutulur (her yenilemede veritabanı taranmasın)
local distCache = {}
local function distanceOf(id)
 if not FT.QuestDistance then return nil end
 local now = GetTime and GetTime() or 0
 local c = distCache[id]
 if c and now - c.t < 3 then return c.d end
 local d = FT.QuestDistance(id)
 distCache[id] = {d = d, t = now}
 return d
end

local function hex(c) return ('%02x%02x%02x'):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end

----------------------------------------------------------------------
-- Küçük bileşenler
----------------------------------------------------------------------
local function newChip(parent) return FT.Kit.Chip(parent) end

local function newObjective(block)
 local K = FT.Kit
 local o = {}
 o.label = K.Text(block, 12, 'muted'); o.label:SetJustifyH('LEFT'); o.label:SetWordWrap(false)
 o.count = K.Text(block, 12, 'text'); o.count:SetJustifyH('RIGHT')
 o.barBg = block:CreateTexture(nil, 'ARTWORK'); o.barBg:SetHeight(3); K.Fill(o.barBg, 'line')
 o.barFill = block:CreateTexture(nil, 'OVERLAY'); o.barFill:SetHeight(3)
 -- adım adım görünümü: sol numara ve altta yer satırı ("Durotar · 45, 62")
 o.num = K.Text(block, 12, 'muted'); o.num:SetJustifyH('LEFT')
 o.place = K.Text(block, 11, 'muted'); o.place:SetJustifyH('LEFT'); o.place:SetWordWrap(false)
 return o
end

local function hideObjective(o)
 o.label:Hide(); o.count:Hide(); o.barBg:Hide(); o.barFill:Hide(); o.num:Hide(); o.place:Hide()
end

-- Görevin altındaki numaralı adımlar (FT.QuestSteps). Biten adımlar yeşil, sıradaki adım vurgulu, sonrakiler soluk;
-- numara her zaman adımın gerçek sırasıdır (biten adımlar gizlense de "2." "2." kalır). y: sonraki boş satır.
local STEP_INDENT = 18
local function drawSteps(b, steps, ctx, left, y, a)
 local K = FT.Kit
 local hideDone = ForeverTrailSettings.trkHideDoneObj ~= false
 local oi = 0
 for n, s in ipairs(steps) do
  if not (s.done and hideDone) then
   oi = oi + 1
   local o = b.objs[oi]
   if not o then o = newObjective(b); b.objs[oi] = o end
   local tx = left + STEP_INDENT
   local num = s.done and {0.55, 0.9, 0.6} or (s.current and a or K.Color('muted'))
   local txt = s.done and {0.55, 0.9, 0.6} or K.Color(s.current and 'text' or 'muted')
   o.num:ClearAllPoints(); o.num:SetPoint('TOPLEFT', left, -y); o.num:SetText(tostring(n) .. '.')
   o.num:SetTextColor(num[1], num[2], num[3]); o.num:Show()
   o.label:ClearAllPoints(); o.label:SetPoint('TOPLEFT', tx, -y); o.label:SetWidth(CW - tx - 52)
   o.label:SetText(s.text or ''); o.label:SetTextColor(txt[1], txt[2], txt[3]); o.label:Show()
   o.count:ClearAllPoints(); o.count:SetPoint('TOPRIGHT', -2, -y)
   if s.need > 0 then
    o.count:SetText(('%d/%d'):format(s.have, s.need)); o.count:SetTextColor(s.done and 0.55 or 1, s.done and 0.9 or 1, s.done and 0.6 or 1); o.count:Show()
   else o.count:SetText('') end
   y = y + 19
   if s.place and not s.done then
    o.place:ClearAllPoints(); o.place:SetPoint('TOPLEFT', tx, -(y - 3)); o.place:SetWidth(CW - tx - 4)
    o.place:SetText(s.place.text); o.place:SetTextColor(0.5, 0.55, 0.65); o.place:Show()
    y = y + 15
   end
   if s.current and s.need > 0 and ctx.bars then
    local c = s.done and {0.45, 0.9, 0.5} or {a[1], a[2], a[3]}
    o.barBg:ClearAllPoints(); o.barBg:SetPoint('TOPLEFT', tx, -(y - 2)); o.barBg:SetWidth(CW - tx - 2); o.barBg:Show()
    o.barFill:ClearAllPoints(); o.barFill:SetPoint('TOPLEFT', tx, -(y - 2))
    o.barFill:SetWidth(math.max(1, (CW - tx - 2) * math.min(1, s.have / s.need))); o.barFill:SetColorTexture(c[1], c[2], c[3], 1); o.barFill:Show()
    y = y + 7
   end
   if s.objIndex and s.need > 0 and FT.ObjectiveProgress then pcall(FT.ObjectiveProgress, o, b.questId, s.objIndex, s.have, s.need) end
   y = y + 3
  end
 end
 return y
end

local function newBlock(i)
 local K = FT.Kit
 local b = CreateFrame('Button', nil, state.content)
 b:SetSize(CW, 40)
 b:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
 b.hl = b:CreateTexture(nil, 'BACKGROUND'); b.hl:SetAllPoints(); K.Fill(b.hl, 'card', 0.9); b.hl:Hide()
 b.focus = b:CreateTexture(nil, 'ARTWORK'); b.focus:SetWidth(3)
 b.focus:SetPoint('TOPLEFT', -PAD + 4, -6); b.focus:SetPoint('BOTTOMLEFT', -PAD + 4, 6)
 K.Fill(b.focus, 'accent'); b.focus:Hide()
 b.sep = b:CreateTexture(nil, 'ARTWORK'); b.sep:SetHeight(1)
 b.sep:SetPoint('TOPLEFT', 0, 0); b.sep:SetPoint('TOPRIGHT', 0, 0); K.Fill(b.sep, 'line', 0.55)
 b.badge = K.LevelBadge(b); b.badge:SetSize(28, 18); b.badge.text:SetPoint('CENTER', 0, 0)
 b.title = K.Text(b, 14, 'text'); b.title:SetJustifyH('LEFT'); b.title:SetWordWrap(false)
 b.dist = K.Text(b, 11, 'muted'); b.dist:SetJustifyH('RIGHT')
 b.chips = {newChip(b), newChip(b)}
 b.turn = K.Text(b, 12, 'text'); b.turn:SetJustifyH('LEFT'); b.turn:SetWordWrap(false)
 b.party = K.Text(b, 11, 'text'); b.party:SetJustifyH('LEFT'); b.party:SetWordWrap(false)
 b.objs = {}
 b:SetScript('OnClick', function(self, button)
  local id = self.questId
  if not id then return end
  if button == 'LeftButton' and IsControlKeyDown and IsControlKeyDown() then
   local pins = charStore('trkPin'); pins[id] = not pins[id] or nil
   return FT.RefreshTracker()
  end
  if button == 'LeftButton' and IsAltKeyDown and IsAltKeyDown() then
   local order = FT.trkLastOrder or {}
   for n, qid in ipairs(order) do
    if qid == id and n > 1 then order[n], order[n - 1] = order[n - 1], order[n]; break end
   end
   ForeverTrailCharacter = ForeverTrailCharacter or {}
   ForeverTrailCharacter.trkOrder = order
   return FT.RefreshTracker()
  end
  if button == 'LeftButton' and IsShiftKeyDown and IsShiftKeyDown() then
   local store = charStore('trkMin'); store[id] = not store[id] or nil
   return FT.RefreshTracker()
  end
  if button == 'RightButton' and FT.ToggleFocus then FT.ToggleFocus(id)
  elseif FT.SelectTrackedQuest then FT.SelectTrackedQuest(id) end
 end)
 b:SetScript('OnEnter', function(self)
  self.hl:Show()
  if FT.tracker then FT.tracker.hovering = true; if FT.ApplyTrackerAlpha then FT.ApplyTrackerAlpha() end end
  if FT.QuestRowTip and self.questId then FT.QuestRowTip(self, self.questId) end
 end)
 b:SetScript('OnLeave', function(self)
  self.hl:Hide()
  if FT.Kit then FT.Kit.HideTips() end
  if FT.tracker and not FT.tracker:IsMouseOver() then FT.tracker.hovering = false; if FT.ApplyTrackerAlpha then FT.ApplyTrackerAlpha() end end
 end)
 blocks[i] = b
 return b
end

local function newZone(i)
 local K = FT.Kit
 local z = CreateFrame('Button', nil, state.content)
 z:SetSize(CW, 28)
 z.hl = z:CreateTexture(nil, 'BACKGROUND'); z.hl:SetAllPoints(); K.Fill(z.hl, 'card', 0.6); z.hl:Hide()
 z.text = K.Text(z, 11, 'muted'); z.text:SetPoint('LEFT', 0, -2); z.text:SetJustifyH('LEFT')
 z.count = K.Text(z, 11, 'muted'); z.count:SetPoint('RIGHT', 0, -2); z.count:SetJustifyH('RIGHT')
 z:SetScript('OnClick', function(self)
  local store = charStore('trkZones'); store[self.zone] = not store[self.zone] or nil
  FT.RefreshTracker()
 end)
 z:SetScript('OnEnter', function(self) self.hl:Show() end)
 z:SetScript('OnLeave', function(self) self.hl:Hide() end)
 zones[i] = z
 return z
end

----------------------------------------------------------------------
-- Eski takip kutusunun çizimi (görev penceresi kurulmadan önce bir kez çizilmiş olabilir): her şeyi gizle
----------------------------------------------------------------------
local function hideLegacy()
 local t = FT.tracker
 if not t then return end
 for _, part in ipairs(t.legacyParts or {}) do part:Hide() end
 for _, pool in ipairs(t.legacyRows or {}) do
  for _, row in ipairs(pool) do row:Hide() end
 end
 for _, name in ipairs({'xpFill', 'xpRest', 'colHdr'}) do
  if t[name] then t[name]:Hide() end
 end
 if FT.HideTrackerItems and not (InCombatLockdown and InCombatLockdown()) then FT.HideTrackerItems(1) end
end

----------------------------------------------------------------------
-- Kurulum: özet bölümü ve kaydırmalı liste
----------------------------------------------------------------------
local function setup()
 if state.ready then return true end
 local t = FT.tracker
 if not (t and FT.Kit) then return false end
 local K = FT.Kit
 state.root = t
 -- özet
 state.level = K.Text(t, 15, 'text'); state.level:SetPoint('TOPLEFT', PAD, -14); state.level:SetJustifyH('LEFT')
 state.pct = K.Text(t, 13, 'accent'); state.pct:SetPoint('TOPRIGHT', -PAD, -16); state.pct:SetJustifyH('RIGHT')
 state.barBg = t:CreateTexture(nil, 'ARTWORK'); state.barBg:SetHeight(4); K.Fill(state.barBg, 'line')
 state.barBg:SetPoint('TOPLEFT', PAD, -40); state.barBg:SetWidth(CW)
 state.barFill = t:CreateTexture(nil, 'OVERLAY'); state.barFill:SetHeight(4); K.Fill(state.barFill, 'accent')
 state.barFill:SetPoint('TOPLEFT', PAD, -40)
 state.barRest = t:CreateTexture(nil, 'OVERLAY'); state.barRest:SetHeight(4); state.barRest:SetColorTexture(0.35, 0.6, 1, 0.85)
 state.gain = K.Text(t, 11, 'muted'); state.gain:SetJustifyH('LEFT'); state.gain:SetWordWrap(false); state.gain:SetTextColor(0.6, 0.82, 1)
 state.rested = K.Text(t, 11, 'muted'); state.rested:SetJustifyH('RIGHT')
 state.route = K.Text(t, 11, 'muted'); state.route:SetJustifyH('LEFT'); state.route:SetWordWrap(false)
 state.rule = K.Divider(t); state.rule:SetPoint('TOPLEFT', 0, 0); state.rule:SetPoint('TOPRIGHT', 0, 0)
 -- kaydırmalı liste
 state.scroll = K.Scroll(t)
 state.scroll:SetWidth(CW)
 state.content = CreateFrame('Frame', nil, state.scroll)
 state.content:SetSize(CW, 10)
 state.scroll:SetScrollChild(state.content)
 -- boş durum
 state.empty = K.Text(state.content, 12, 'muted'); state.empty:SetJustifyH('LEFT')
 state.more = K.Text(state.content, 11, 'muted'); state.more:SetJustifyH('LEFT')
 -- görev eşyası düğmeleri liste kaydırılınca yeniden konumlanır
 local previous = state.scroll:GetScript('OnVerticalScroll')
 state.scroll:SetScript('OnVerticalScroll', function(self, offset)
  if previous then previous(self, offset) end
  if state.layoutItems then state.layoutItems() end
 end)
 state.ready = true
 return true
end

-- Görev eşyası düğmeleri (kullanılabilir görev eşyası çantadaysa bloğun sağ üstünde); yalnızca tam görünen bloklar için
local function layoutItems()
 if InCombatLockdown and InCombatLockdown() then return end
 if not FT.TrackerItemButton then return end
 local top = state.scroll:GetVerticalScroll() or 0
 local view = state.scroll:GetHeight() or 0
 local n = 0
 for _, b in ipairs(blocks) do
  if b:IsShown() and b.questId and b.y and b.y >= top - 1 and b.y + 28 <= top + view + 1 then
   n = n + 1
   FT.TrackerItemButton(n, b, b.questId, function(btn) btn:ClearAllPoints(); btn:SetPoint('TOPRIGHT', b, 'TOPRIGHT', -4, -8) end)
  end
 end
 if FT.HideTrackerItems then FT.HideTrackerItems(n + 1) end
end
state.layoutItems = layoutItems

----------------------------------------------------------------------
-- Veri: günlükteki görevler, sıralama
----------------------------------------------------------------------
local function gather()
 local q = C_QuestLog
 local entries, zoneName = {}, nil
 if q and q.GetNumQuestLogEntries and q.GetInfo then
  for index = 1, q.GetNumQuestLogEntries() do
   local info = q.GetInfo(index)
   if info and info.isHeader then zoneName = info.title
   elseif info and not info.isHidden and info.questID and info.questID > 0 then
    entries[#entries + 1] = {info = info, zone = zoneName or 'Diğer', order = #entries}
   end
  end
 end
 return entries
end

local function sortEntries(entries, sort)
 local q = C_QuestLog
 local useZones = ForeverTrailSettings.trkzones ~= false and sort ~= 'yakin'
 if sort == 'yakin' then
  for _, e in ipairs(entries) do e.dist = distanceOf(e.info.questID) or 1e9 end
  table.sort(entries, function(a, b) if a.dist ~= b.dist then return a.dist < b.dist end return a.order < b.order end)
 elseif sort == 'durum' then
  useZones = true
  for _, e in ipairs(entries) do
   e.ready = q.IsComplete and q.IsComplete(e.info.questID) and true or false
   e.zone = e.ready and 'TESLİME HAZIR' or 'DEVAM EDEN'
  end
  table.sort(entries, function(a, b)
   if a.ready ~= b.ready then return a.ready end
   local fa, fb = FT.focusQuest == a.info.questID, FT.focusQuest == b.info.questID
   if fa ~= fb then return fa end
   return a.order < b.order
  end)
 elseif sort == 'yuzde' then
  for _, e in ipairs(entries) do e.pct = FT.QuestPercent and FT.QuestPercent(e.info.questID) or 0 end
  table.sort(entries, function(a, b) if a.pct ~= b.pct then return a.pct > b.pct end return a.order < b.order end)
  useZones = false
 elseif sort == 'seviye' then
  local zoneOrder = {}
  for _, e in ipairs(entries) do zoneOrder[e.zone] = zoneOrder[e.zone] or e.order end
  table.sort(entries, function(a, b)
   if useZones and a.zone ~= b.zone then return zoneOrder[a.zone] < zoneOrder[b.zone] end
   local la, lb = a.info.level or 0, b.info.level or 0
   if la ~= lb then return la < lb end
   return a.order < b.order
  end)
 end
 -- sabitlenenler (Ctrl+tık) ve elle sıralama (Alt+tık) en son uygulanır; bölge gruplaması korunur
 local pins = charStore('trkPin')
 local custom = {}
 for i, id in ipairs((ForeverTrailCharacter and ForeverTrailCharacter.trkOrder) or {}) do custom[id] = i end
 local zoneFirst = {}
 for i, e in ipairs(entries) do e.pos = i; if not zoneFirst[e.zone] then zoneFirst[e.zone] = i end end
 table.sort(entries, function(a, b)
  local za, zb = useZones and zoneFirst[a.zone] or 0, useZones and zoneFirst[b.zone] or 0
  if za ~= zb then return za < zb end
  local pa, pb = pins[a.info.questID] and 0 or 1, pins[b.info.questID] and 0 or 1
  if pa ~= pb then return pa < pb end
  local ca, cb = custom[a.info.questID] or 1e6, custom[b.info.questID] or 1e6
  if ca ~= cb then return ca < cb end
  return a.pos < b.pos
 end)
 FT.trkLastOrder = {}
 for i, e in ipairs(entries) do FT.trkLastOrder[i] = e.info.questID end
 return useZones
end

----------------------------------------------------------------------
-- Özet bölümü: seviye, XP çubuğu, teslimle gelecek XP, rota
----------------------------------------------------------------------
local function drawSummary()
 local K = FT.Kit
 local level = UnitLevel and UnitLevel('player') or 0
 local xp, max = UnitXP and UnitXP('player') or 0, UnitXPMax and UnitXPMax('player') or 0
 local rested = GetXPExhaustion and GetXPExhaustion() or 0
 state.level:SetText(('Seviye %d'):format(level))
 state.barBg:SetWidth(CW)
 local f1 = max > 0 and math.min(1, xp / max) or 0
 local f2 = max > 0 and math.min(1 - f1, rested / max) or 0
 state.pct:SetText(('%%%d'):format(math.floor(f1 * 100)))
 state.barFill:SetWidth(math.max(1, CW * f1))
 state.barRest:ClearAllPoints(); state.barRest:SetPoint('TOPLEFT', state.barFill, 'TOPRIGHT', 0, 0)
 state.barRest:SetWidth(math.max(1, CW * f2)); state.barRest:SetShown(f2 > 0)
 local _, gainText = FT.LevelParts and FT.LevelParts()
 local route = FT.RouteSummary and ForeverTrailSettings.routenums ~= false and (FT.RouteOrder and pcall(FT.RouteOrder)) and FT.RouteSummary() or nil
 local y = 52
 state.gain:ClearAllPoints(); state.rested:ClearAllPoints(); state.route:ClearAllPoints()
 if gainText or rested > 0 then
  state.gain:SetPoint('TOPLEFT', PAD, -y); state.gain:SetWidth(CW - 120)
  state.gain:SetText(gainText or ''); state.gain:Show()
  state.rested:SetPoint('TOPRIGHT', -PAD, -y); state.rested:SetText(rested > 0 and ('Dinlenmiş %%%d'):format(math.floor(f2 * 100 + 0.5)) or ''); state.rested:SetTextColor(0.6, 0.82, 1); state.rested:Show()
  y = y + 17
 else state.gain:Hide(); state.rested:Hide() end
 if route then
  state.route:SetPoint('TOPLEFT', PAD, -y); state.route:SetWidth(CW); state.route:SetText(route); state.route:Show(); y = y + 17
 else state.route:Hide() end
 return y + 8
end

----------------------------------------------------------------------
-- Bir görev bloğunu doldur; yüksekliğini döndürür
----------------------------------------------------------------------
local function fillBlock(b, e, ctx)
 local K = FT.Kit
 local q = C_QuestLog
 local info = e.info
 local id = info.questID
 b.questId = id
 b:SetWidth(CW)
 local translation = QTR_QuestData and QTR_QuestData[tostring(id)]
 local title = translation and translation.Title or info.title or ('Görev ' .. id)
 local ready = q.IsComplete and q.IsComplete(id) and true or false
 local mini = ctx.minimized[id] or (ready and ForeverTrailSettings.trkAutoMin == true) or ctx.compact
 local pinned = ctx.pins[id]
 local focused = FT.focusQuest == id
 local pad = ctx.pad
 -- seviye rozeti ve başlık
 local lr, lg, lb = 1, 0.82, 0
 if FT.DiffColor and info.level and info.level > 0 then lr, lg, lb = FT.DiffColor(info.level) end
 b.badge:ClearAllPoints(); b.badge:SetPoint('TOPLEFT', 0, -(pad + 1))
 b.badge:SetLevel(ForeverTrailSettings.trkdiff ~= false and info.level or nil, lr, lg, lb)
 b.badge:SetShown(ForeverTrailSettings.trkdiff ~= false)
 local left = ForeverTrailSettings.trkdiff ~= false and 38 or 0
 local a = K.Color('accent')
 local mark = (pinned and ('|cff' .. hex(a) .. '•|r ') or '') .. ((mini and not ctx.compact) and '|cff8a90a0+|r ' or '')
 b.title:ClearAllPoints(); b.title:SetPoint('TOPLEFT', left, -pad)
 b.title:SetText(mark .. title)
 -- sağ üst: etiketler ve uzaklık
 local dist = (e.dist and e.dist < 1e9 and e.dist) or distanceOf(id)
 local routeNo = ForeverTrailSettings.routenums ~= false and FT.RouteNumber and FT.RouteNumber[id]
 local distText = dist and ('%d m'):format(dist) or ''
 if routeNo then distText = distText ~= '' and ('%d  ·  %s'):format(routeNo, distText) or tostring(routeNo) end
 b.dist:ClearAllPoints(); b.dist:SetPoint('TOPRIGHT', -2, -(pad + 2)); b.dist:SetText(distText)
 local chips = {}
 if ready then chips[#chips + 1] = {'Teslim', 0.45, 0.9, 0.5} end
 local group = info.suggestedGroup and info.suggestedGroup > 1
 local shared = FT.SharedCount and FT.SharedCount(id) or 0
 if group then chips[#chips + 1] = {('Grup %d'):format(info.suggestedGroup), 1, 0.45, 0.45}
 elseif shared > 0 then chips[#chips + 1] = {('+%d ortak'):format(shared), 0.55, 0.75, 1}
 elseif FT.IsNewQuest and FT.IsNewQuest(id) then chips[#chips + 1] = {'Yeni', 0.55, 0.8, 1} end
 local x = (b.dist:GetStringWidth() or 0) + 10
 for i, chip in ipairs(b.chips) do
  local def = chips[i]
  if def then
   chip:Set(def[1], def[2], def[3], def[4])
   chip:ClearAllPoints(); chip:SetPoint('TOPRIGHT', b, 'TOPRIGHT', -x - 2, -(pad + 1)); chip:Show()
   x = x + chip:GetWidth() + 6
  else chip:Hide() end
 end
 b.title:SetWidth(math.max(60, CW - left - x - 8))
 b.focus:SetShown(focused)
 b:SetAlpha(FT.focusQuest and not focused and 0.5 or 1)
 -- gövde: hedefler, teslim, grup
 local y = pad + 22
 for _, o in ipairs(b.objs) do hideObjective(o) end
 b.turn:Hide(); b.party:Hide()
 local steps
 if not mini and ForeverTrailSettings.trkSteps ~= false and FT.QuestSteps then
  local okSteps, list = pcall(FT.QuestSteps, id)
  if okSteps and type(list) == 'table' and #list > 0 then steps = list end
 end
 if steps then
  y = drawSteps(b, steps, ctx, left, y, a)
  local partyText = FT.PartyText and FT.PartyText(id)
  if partyText then
   b.party:ClearAllPoints(); b.party:SetPoint('TOPLEFT', left, -y); b.party:SetWidth(CW - left - 4)
   b.party:SetText(partyText); b.party:SetTextColor(0.55, 0.8, 1); b.party:Show(); y = y + 18
  end
 elseif not mini then
  local oi = 0
  if ready then
   local ender = FT.TurnInName and FT.TurnInName(id)
   if ender then
    b.turn:ClearAllPoints(); b.turn:SetPoint('TOPLEFT', left, -y); b.turn:SetWidth(CW - left - 4)
    b.turn:SetText('Teslim: ' .. ender); b.turn:SetTextColor(0.55, 0.9, 0.6); b.turn:Show()
    y = y + 20
   end
  elseif q.GetQuestObjectives then
   local ok, objectives = pcall(q.GetQuestObjectives, id)
   if ok and type(objectives) == 'table' then
    for idx, data in ipairs(objectives) do
     local need, have = data.numRequired or 0, data.numFulfilled or 0
     local done = data.finished or (need > 0 and have >= need)
     if not (done and ForeverTrailSettings.trkHideDoneObj ~= false) then
      oi = oi + 1
      local o = b.objs[oi]
      if not o then o = newObjective(b); b.objs[oi] = o end
      o.label:ClearAllPoints(); o.label:SetPoint('TOPLEFT', left, -y); o.label:SetWidth(CW - left - 52)
      o.label:SetText(FT.ParseObjective and FT.ParseObjective(data.text or '') or (data.text or ''))
      local c = done and {0.55, 0.9, 0.6} or K.Color('muted')
      o.label:SetTextColor(c[1], c[2], c[3]); o.label:Show()
      o.count:ClearAllPoints(); o.count:SetPoint('TOPRIGHT', -2, -y)
      local pr, pg, pb = unpack(done and {0.45, 0.9, 0.5} or {a[1], a[2], a[3]})
      if need > 0 then
       o.count:SetText(('%d/%d'):format(have, need)); o.count:SetTextColor(done and 0.55 or 1, done and 0.9 or 1, done and 0.6 or 1)
      else o.count:SetText(done and 'OK' or ''); o.count:SetTextColor(0.55, 0.9, 0.6) end
      o.count:Show()
      y = y + 19
      if need > 0 and ctx.bars then
       o.barBg:ClearAllPoints(); o.barBg:SetPoint('TOPLEFT', left, -(y - 2)); o.barBg:SetWidth(CW - left - 2); o.barBg:Show()
       o.barFill:ClearAllPoints(); o.barFill:SetPoint('TOPLEFT', left, -(y - 2))
       o.barFill:SetWidth(math.max(1, (CW - left - 2) * math.min(1, have / need))); o.barFill:SetColorTexture(pr, pg, pb, 1); o.barFill:Show()
       y = y + 7
      end
      if FT.ObjectiveProgress then pcall(FT.ObjectiveProgress, o, id, idx, have, need) end
     end
    end
   end
  end
  local partyText = FT.PartyText and FT.PartyText(id)
  if partyText then
   b.party:ClearAllPoints(); b.party:SetPoint('TOPLEFT', left, -y); b.party:SetWidth(CW - left - 4)
   b.party:SetText(partyText); b.party:SetTextColor(0.55, 0.8, 1); b.party:Show(); y = y + 18
  end
 end
 local height = y + pad - (mini and 4 or 0)
 b:SetHeight(height)
 return height
end

----------------------------------------------------------------------
-- Ana yenileme
----------------------------------------------------------------------
function FT.RefreshQuestList()
 local t = FT.tracker
 if not (t and ForeverTrailSettings and C_QuestLog) then return end
 CW = (FT.QuestDockWidth and FT.QuestDockWidth() or WIDTH) - PAD * 2 -- pencere boyutlandırılabilir
 if not setup() then return end
 hideLegacy()
 local sumH = drawSummary()
 local entries = gather()
 local sort = ForeverTrailSettings.c_trackerSort or 'durum'
 local view = ForeverTrailSettings.c_trackerView
 local compact = view == 'liste' or view == 'tablo'
 local useZones = sortEntries(entries, sort)
 local maxQuests = tonumber(ForeverTrailSettings.c_trackerMax) or MAX_QUESTS
 local density = ForeverTrailSettings.c_trackerDensity or 'normal'
 local ctx = {
  compact = compact, pins = charStore('trkPin'), minimized = charStore('trkMin'),
  pad = density == 'sikisik' and 6 or (density == 'ferah' and 14 or 10), bars = true,
 }
 local zoneCollapsed = charStore('trkZones')
 local zoneCount = {}
 for _, e in ipairs(entries) do zoneCount[e.zone] = (zoneCount[e.zone] or 0) + 1 end
 for _, b in ipairs(blocks) do b:Hide(); b.y = nil end
 for _, z in ipairs(zones) do z:Hide() end
 state.empty:Hide(); state.more:Hide()
 local y, used, hidden, usedZones, lastZone = 6, 0, 0, 0, nil
 local first = true
 for _, e in ipairs(entries) do
  if used >= maxQuests then break end
  if useZones and e.zone ~= lastZone then
   lastZone = e.zone
   usedZones = usedZones + 1
   local z = zones[usedZones] or newZone(usedZones)
   z.zone = e.zone
   z:SetWidth(CW)
   z:ClearAllPoints(); z:SetPoint('TOPLEFT', state.content, 'TOPLEFT', 0, -y)
   z.text:SetText((zoneCollapsed[e.zone] and '+  ' or '') .. e.zone)
   z.count:SetText(tostring(zoneCount[e.zone]))
   z:Show()
   y = y + 28
   first = true
  end
  if useZones and zoneCollapsed[e.zone] then hidden = hidden + 1 else
   used = used + 1
   local b = blocks[used] or newBlock(used)
   b.sep:SetShown(not first)
   b:ClearAllPoints(); b:SetPoint('TOPLEFT', state.content, 'TOPLEFT', 0, -y)
   b.y = y
   local height = fillBlock(b, e, ctx)
   b:Show()
   y = y + height
   first = false
  end
 end
 if #entries > used + hidden then
  state.more:ClearAllPoints(); state.more:SetPoint('TOPLEFT', 0, -(y + 8))
  state.more:SetText(('+%d görev daha  (Ansiklopedi)'):format(#entries - used - hidden)); state.more:Show(); y = y + 30
 elseif #entries == 0 then
  state.empty:ClearAllPoints(); state.empty:SetPoint('TOPLEFT', 0, -(y + 12))
  state.empty:SetText('Günlükte görev yok.'); state.empty:Show(); y = y + 40
 end
 state.content:SetHeight(math.max(10, y)); state.content:SetWidth(CW)
 -- liste yüksekliği ekrana göre sınırlanır, taşarsa kaydırılır
 local screen = UIParent and UIParent:GetHeight() or 800
 local maxView = math.max(160, math.floor(screen * 0.58) - sumH)
 local fixed = FT.QuestDockViewHeight and FT.QuestDockViewHeight(sumH)
 local viewH = fixed or math.min(y, maxView)
 state.scroll:ClearAllPoints(); state.scroll:SetPoint('TOPLEFT', t, 'TOPLEFT', PAD, -sumH)
 state.scroll:SetSize(CW, viewH)
 state.rule:ClearAllPoints(); state.rule:SetPoint('TOPLEFT', t, 'TOPLEFT', 0, -(sumH - 4)); state.rule:SetPoint('TOPRIGHT', t, 'TOPRIGHT', 0, -(sumH - 4))
 local range = math.max(0, y - viewH)
 if (state.scroll:GetVerticalScroll() or 0) > range then state.scroll:SetVerticalScroll(range) end
 t:SetHeight(sumH + viewH + 10)
 layoutItems()
end

-- Test ve tanı için: görünen numaralı adım satırları ({quest, num, text, place})
function FT.QuestListStepRows()
 local out = {}
 for _, b in ipairs(blocks) do
  if b:IsShown() then
   for _, o in ipairs(b.objs) do
    if o.num:IsShown() then out[#out + 1] = {quest = b.questId, num = o.num:GetText(), text = o.label:GetText(), place = o.place:IsShown() and o.place:GetText() or nil} end
   end
  end
 end
 return out
end

-- Test ve tanı için: görünen görev bloğu ve bölge başlığı sayısı
function FT.QuestListInfo()
 local n, z = 0, 0
 for _, b in ipairs(blocks) do if b:IsShown() then n = n + 1 end end
 for _, h in ipairs(zones) do if h:IsShown() then z = z + 1 end end
 return n, z
end
