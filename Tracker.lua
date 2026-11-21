local _, FT = ...

-- Sağ kenara yaslı görev takip kutusu: başlık solda üstte, her hedef için ilerleme çubuğu ve "4/5" sayacı.
local WIDTH = 276
local PAD = 12
local BODY_TOP = 44
local MAX_QUESTS, MAX_OBJECTIVES = 12, 36
local tracker, header, summary, toggle, divider
local questRows, objectiveRows = {}, {}
local emptyText, moreText

local function fontPath()
 return FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF'
end

local function setFont(fs, size, flags)
 if fs:SetFont(fontPath(), size, flags or '') == false then fs:SetFont('Fonts\\ARIALN.TTF', size, flags or '') end
 fs:SetShadowOffset(1, -1)
 fs:SetShadowColor(0, 0, 0, 0.85)
end

local function newText(parent, size, flags, justify)
 local fs = parent:CreateFontString(nil, 'OVERLAY')
 setFont(fs, size, flags)
 fs:SetJustifyH(justify or 'LEFT')
 return fs
end

local function solid(parent, layer, w, h)
 local t = parent:CreateTexture(nil, layer)
 t:SetColorTexture(1, 1, 1, 1)
 t:SetSize(w, h)
 return t
end

local function accent()
 local a = FT.Style and FT.Style.accent or {0.95, 0.72, 0.35}
 return a[1], a[2], a[3]
end

local function applyAlpha()
 if not tracker then return end
 tracker.baseAlpha = ForeverTrailSettings.trackerAlpha or 1
 tracker:SetAlpha(tracker.hovering and 1 or tracker.baseAlpha)
 local bg = tracker.softBg or tracker.bg
 if bg then
  local st = FT.TrackerStyle and FT.TrackerStyle() or 'kutu'
  local clear = (st == 'seffaf' or st == 'questie') and not tracker.hovering
  bg:SetAlpha(clear and 0 or 1)
 end
end
FT.ApplyTrackerAlpha = applyAlpha

-- Görevi panelde seçip haritada göster
local function selectQuest(questId, noMap)
 -- Seçilen göreve ok yönelsin: eski özel hedef ve yol noktaları oku başka yere çekmesin
 local cleared
 if FT.customTarget and not FT.corpseActive then
  FT.customTarget = nil
  if ForeverTrailCharacter then ForeverTrailCharacter.customTarget = nil end
  cleared = true
 end
 if FT.PathEndStep and FT.PathEndStep() and FT.ClearVia then FT.ClearVia(true); cleared = true end
 if cleared then FT.Print('Özel hedef/yol kaldırıldı; ok seçilen göreve yöneliyor.') end
 for guideIndex, guide in ipairs(FT.validGuides or {}) do
  if guide.live then
   FT.SelectGuide(guideIndex)
   for j, step in ipairs(guide.steps) do
    if step.questId == questId then FT.active = j; FT.view = j; if FT.SaveStep then FT.SaveStep() end; break end
   end
   break
  end
 end
 if FT.Refresh then FT.Refresh() end
 if FT.UpdateArrow then pcall(FT.UpdateArrow) end
 if not noMap and FT.OpenMap then FT.OpenMap() end
end
FT.SelectQuestTarget = selectQuest

local function getQuestRow(i)
 local row = questRows[i]
 if row then return row end
 row = CreateFrame('Button', nil, tracker)
 row:SetSize(WIDTH - PAD * 2, 18)
 row.title = newText(row, 13, '', 'LEFT')
 row.title:SetPoint('LEFT', 0, 0); row.title:SetPoint('RIGHT', row, 'RIGHT', -46, 0)
 row.title:SetWordWrap(false)
 row.tag = newText(row, 11, '', 'RIGHT')
 row.tag:SetPoint('RIGHT', 0, 0)
 row.hl = row:CreateTexture(nil, 'HIGHLIGHT')
 row.hl:SetAllPoints(); row.hl:SetColorTexture(1, 1, 1, 0.07)
 row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
 row:SetScript('OnClick', function(self, button)
  if not self.questId then return end
  if button == 'LeftButton' and IsControlKeyDown and IsControlKeyDown() then
   local pins = charStore('trkPin')
   pins[self.questId] = not pins[self.questId] or nil
   return FT.RefreshTracker()
  end
  if button == 'LeftButton' and IsAltKeyDown and IsAltKeyDown() then
   local order = FT.trkLastOrder or {}
   for i, id in ipairs(order) do
    if id == self.questId and i > 1 then order[i], order[i - 1] = order[i - 1], order[i]; break end
   end
   ForeverTrailCharacter = ForeverTrailCharacter or {}
   ForeverTrailCharacter.trkOrder = order
   return FT.RefreshTracker()
  end
  if button == 'LeftButton' and IsShiftKeyDown and IsShiftKeyDown() then
   local store = charStore('trkMin')
   store[self.questId] = not store[self.questId] or nil
   return FT.RefreshTracker()
  end
  if button == 'RightButton' and FT.ToggleFocus then FT.ToggleFocus(self.questId) else selectQuest(self.questId) end
 end)
 row:SetScript('OnEnter', function(self)
  tracker.hovering = true; applyAlpha()
  if FT.QuestRowTip then FT.QuestRowTip(self, self.questId) end
 end)
 row:SetScript('OnLeave', function()
  if GameTooltip then GameTooltip:Hide() end
  if not tracker:IsMouseOver() then tracker.hovering = false; applyAlpha() end
 end)
 questRows[i] = row
 return row
end

local zoneRows = {}
local function charStore(key)
 ForeverTrailCharacter = ForeverTrailCharacter or {}
 ForeverTrailCharacter[key] = ForeverTrailCharacter[key] or {}
 return ForeverTrailCharacter[key]
end

local function getZoneRow(i)
 local row = zoneRows[i]
 if row then return row end
 row = CreateFrame('Button', nil, tracker)
 row:SetSize(WIDTH - PAD * 2, 16)
 row.text = newText(row, 12, 'OUTLINE', 'LEFT')
 row.text:SetPoint('LEFT', 0, 0)
 row.line = solid(row, 'ARTWORK', 10, 1)
 row.line:SetPoint('LEFT', row.text, 'RIGHT', 6, 0); row.line:SetPoint('RIGHT', row, 'RIGHT', 0, 0)
 row.hl = row:CreateTexture(nil, 'HIGHLIGHT')
 row.hl:SetAllPoints(); row.hl:SetColorTexture(1, 1, 1, 0.05)
 row:SetScript('OnClick', function(self)
  local store = charStore('trkZones')
  store[self.zone] = not store[self.zone] or nil
  FT.RefreshTracker()
 end)
 zoneRows[i] = row
 return row
end

local function getObjectiveRow(i)
 local row = objectiveRows[i]
 if row then return row end
 row = CreateFrame('Frame', nil, tracker)
 row:SetSize(WIDTH - PAD * 2, 22)
 row.label = newText(row, 12, '', 'LEFT')
 row.label:SetPoint('TOPLEFT', 8, 0); row.label:SetWidth(WIDTH - PAD * 2 - 66); row.label:SetHeight(14)
 row.label:SetWordWrap(false)
 row.count = newText(row, 13, 'OUTLINE', 'RIGHT')
 row.count:SetPoint('TOPRIGHT', 0, 1)
 row.barBg = solid(row, 'ARTWORK', WIDTH - PAD * 2 - 8, 3)
 row.barBg:SetPoint('TOPLEFT', 8, -16); row.barBg:SetColorTexture(1, 1, 1, 0.12)
 row.barFill = solid(row, 'OVERLAY', 1, 3)
 row.barFill:SetPoint('TOPLEFT', 8, -16)
 objectiveRows[i] = row
 return row
end

function FT.CreateTracker()
 if tracker then return end
 tracker = CreateFrame('Frame', 'ForeverTrailTracker', UIParent)
 FT.tracker = tracker
 tracker:SetSize(WIDTH, 60)
 tracker:SetMovable(true); tracker:EnableMouse(true); tracker:SetClampedToScreen(true)
 tracker:RegisterForDrag('LeftButton')
 tracker:SetScript('OnDragStart', function(self)
  if ForeverTrailSettings.locked then return end
  self:StartMoving()
 end)
 tracker:SetScript('OnDragStop', function(self)
  self:StopMovingOrSizing()
  local point, _, relative, x, y = self:GetPoint()
  ForeverTrailSettings.trackerPoint = {point, relative, x, y}
 end)
 tracker:SetScript('OnEnter', function(self) self.hovering = true; applyAlpha() end)
 tracker:SetScript('OnLeave', function(self)
  if self:IsMouseOver() then return end
  self.hovering = false; applyAlpha()
 end)
 if ForeverTrailSettings.trackerLayout ~= 2 then
  ForeverTrailSettings.trackerPoint = nil
  ForeverTrailSettings.trackerLayout = 2
 end
 local p = ForeverTrailSettings.trackerPoint
 if p and p[1] and p[2] and p[3] and p[4] then tracker:SetPoint(p[1], UIParent, p[2], p[3], p[4])
 else tracker:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -2, -230) end
 if FT.SoftBackdrop then tracker.bg = FT.SoftBackdrop(tracker) else
  tracker.bg = tracker:CreateTexture(nil, 'BACKGROUND')
  tracker.bg:SetAllPoints(); tracker.bg:SetColorTexture(0.1, 0.1, 0.12, 0.85)
 end
 header = newText(tracker, 15, 'OUTLINE', 'LEFT')
 header:SetPoint('TOPLEFT', PAD, -9)
 summary = newText(tracker, 11, '', 'LEFT')
 summary:SetPoint('TOPLEFT', PAD, -26); summary:SetWidth(WIDTH - PAD * 2 - 30)
 summary:SetTextColor(0.78, 0.74, 0.68)
 divider = solid(tracker, 'ARTWORK', WIDTH - PAD * 2, 1)
 divider:SetPoint('TOPLEFT', PAD, -40)
 if FT.RegisterAccent then FT.RegisterAccent(divider, 0.55) end
 toggle = FT.NewButton and FT.NewButton(tracker, '-', 20, 18)
 if not toggle then toggle = CreateFrame('Button', nil, tracker, 'UIPanelButtonTemplate'); toggle:SetSize(20, 18); toggle:SetText('-') end
 toggle:SetPoint('TOPRIGHT', -8, -8)
 toggle:SetScript('OnClick', function()
  ForeverTrailSettings.trackerCollapsed = not ForeverTrailSettings.trackerCollapsed
  FT.RefreshTracker()
 end)
 emptyText = newText(tracker, 12, '', 'LEFT')
 emptyText:SetPoint('TOPLEFT', PAD + 4, -BODY_TOP)
 emptyText:SetTextColor(0.78, 0.72, 0.64)
 moreText = newText(tracker, 11, '', 'LEFT')
 moreText:SetTextColor(0.78, 0.72, 0.64)
 applyAlpha()
 if ForeverTrailSettings.tracker == false then tracker:Hide() end
end

function FT.ToggleTracker()
 if not tracker then return end
 ForeverTrailSettings.tracker = not tracker:IsShown() and true or false
 if ForeverTrailSettings.tracker then tracker:Show(); FT.RefreshTracker() else tracker:Hide() end
end

local function progressColor(have, need, done)
 if FT.ProgressColor then return FT.ProgressColor(have, need, done) end
 if done then return 0.55, 0.95, 0.5 end
 if have <= 0 then return 0.85, 0.8, 0.74 end
 local t = math.min(1, have / math.max(1, need))
 return 1 - 0.45 * t, 0.78 + 0.17 * t, 0.3 + 0.2 * t
end

-- Görevin hedeflerinden toplam ilerleme: have, need, teslime hazır mı
local function questProgress(id)
 local q = C_QuestLog
 if q and q.IsComplete and q.IsComplete(id) then return 1, 1, true end
 local have, need = 0, 0
 if q and q.GetQuestObjectives then
  local ok, list = pcall(q.GetQuestObjectives, id)
  for _, o in ipairs(ok and type(list) == 'table' and list or {}) do
   if (o.numRequired or 0) > 0 then have = have + math.min(o.numFulfilled or 0, o.numRequired); need = need + o.numRequired end
  end
 end
 return have, need, false
end

-- Tablo görünümünün sütun başlıkları (Sv | Görev | İlerleme | Mesafe)
local function drawColumnHeader(y)
 if not tracker.colHdr then
  local f = CreateFrame('Frame', nil, tracker)
  f:SetSize(WIDTH - PAD * 2, 14)
  f.lvl = newText(f, 10, '', 'LEFT'); f.lvl:SetPoint('LEFT', 0, 0); f.lvl:SetText('Sv')
  f.name = newText(f, 10, '', 'LEFT'); f.name:SetPoint('LEFT', 28, 0); f.name:SetText('Görev')
  f.prog = newText(f, 10, '', 'RIGHT'); f.prog:SetText('İlerleme')
  f.dist = newText(f, 10, '', 'RIGHT'); f.dist:SetPoint('RIGHT', 0, 0); f.dist:SetText('Mesafe')
  for _, fs in ipairs({f.lvl, f.name, f.prog, f.dist}) do fs:SetTextColor(0.62, 0.6, 0.56) end
  tracker.colHdr = f
 end
 local f = tracker.colHdr
 local showDist = ForeverTrailSettings.trkColDist ~= false
 f:ClearAllPoints(); f:SetPoint('TOPLEFT', tracker, 'TOPLEFT', PAD, -y)
 f.dist:SetShown(showDist)
 f.prog:ClearAllPoints(); f.prog:SetPoint('RIGHT', f, 'RIGHT', showDist and -48 or 0, 0)
 f:Show()
 return 16
end

-- Satırı eski (ayrıntılı) biçime geri al
local function resetCompactRow(row)
 if row.cLvl then row.cLvl:Hide(); row.cDist:Hide() end
 row.tag:ClearAllPoints(); row.tag:SetPoint('RIGHT', 0, 0); row.tag:SetWidth(0)
 row.tagMoved = nil
end

-- Liste: tek satır, sağda ilerleme. Tablo: Sv | Görev | İlerleme | Mesafe sütunları.
local function styleCompact(row, info, view, title, pinned, dist)
 local have, need, done = questProgress(info.questID)
 local prog = done and '|cff55ff55Teslim|r' or (need > 0 and ('%d/%d'):format(have, need) or '')
 setFont(row.title, 12, '')
 row.tagMoved = true
 if view == 'liste' then
  if row.cLvl then row.cLvl:Hide(); row.cDist:Hide() end
  row.tag:ClearAllPoints(); row.tag:SetPoint('RIGHT', 0, 0); row.tag:SetWidth(0); row.tag:SetText(prog)
  row.title:ClearAllPoints(); row.title:SetPoint('LEFT', 0, 0); row.title:SetPoint('RIGHT', row, 'RIGHT', -50, 0)
  return
 end
 if not row.cLvl then
  row.cLvl = newText(row, 11, '', 'LEFT'); row.cLvl:SetPoint('LEFT', 0, 0); row.cLvl:SetWidth(26)
  row.cDist = newText(row, 11, '', 'RIGHT'); row.cDist:SetPoint('RIGHT', 0, 0); row.cDist:SetWidth(46)
 end
 local showDist = ForeverTrailSettings.trkColDist ~= false
 local distW = showDist and 48 or 0
 if info.level and info.level > 0 then row.cLvl:SetText(tostring(info.level)) else row.cLvl:SetText('') end
 if FT.DiffColor and info.level then row.cLvl:SetTextColor(FT.DiffColor(info.level)) else row.cLvl:SetTextColor(0.85, 0.8, 0.74) end
 row.cLvl:Show()
 local d = dist
 if showDist and not d and FT.QuestDistance then d = FT.QuestDistance(info.questID) end
 row.cDist:SetText((showDist and d and d < 1e9) and ('%d m'):format(math.floor(d + 0.5)) or '')
 row.cDist:SetTextColor(0.75, 0.72, 0.66)
 row.cDist:SetShown(showDist)
 row.tag:ClearAllPoints(); row.tag:SetPoint('RIGHT', row, 'RIGHT', -distW, 0); row.tag:SetWidth(54); row.tag:SetText(prog)
 row.title:ClearAllPoints(); row.title:SetPoint('LEFT', 28, 0); row.title:SetPoint('RIGHT', row, 'RIGHT', -(distW + 58), 0)
 row.title:SetText((pinned and '|cffffd100•|r ' or '') .. (FT.focusQuest == info.questID and '|cff55ddff◆|r ' or '') .. title)
end

function FT.RefreshTracker()
 if not tracker or not tracker:IsShown() then return end
 local q = C_QuestLog
 local ar, ag, ab = accent()
 for _, r in ipairs(questRows) do r:Hide() end
 for _, r in ipairs(objectiveRows) do r:Hide() end
 for _, r in ipairs(zoneRows) do r:Hide() end
 if tracker.colHdr then tracker.colHdr:Hide() end
 emptyText:Hide(); moreText:Hide()
 local entries, zoneName = {}
 if q and q.GetNumQuestLogEntries and q.GetInfo then
  for index = 1, q.GetNumQuestLogEntries() do
   local info = q.GetInfo(index)
   if info and info.isHeader then zoneName = info.title
   elseif info and not info.isHidden and info.questID and info.questID > 0
    and not (ForeverTrailSettings.trkShowDone == false and q.IsComplete and q.IsComplete(info.questID)) then
    entries[#entries + 1] = {info = info, zone = zoneName or 'Diğer', order = #entries}
   end
  end
 end
 local qs = FT.TrackerStyle and FT.TrackerStyle() == 'questie'
 local sort = ForeverTrailSettings.c_trackerSort or (qs and 'bolge' or 'durum')
 -- Biçim: detay (hedefler ve çubuklar), liste (tek satır) ya da tablo (sütunlar). Liste/tablo Questie görünümünü kullanmaz.
 local view = ForeverTrailSettings.c_trackerView or 'detay'
 if view ~= 'liste' and view ~= 'tablo' then view = 'detay' end
 local compact = view ~= 'detay'
 if compact then qs = false end
 local maxQuests = tonumber(ForeverTrailSettings.c_trackerMax) or MAX_QUESTS
 local useZones = ForeverTrailSettings.trkzones ~= false and sort ~= 'yakin'
 if sort == 'yakin' and FT.QuestDistance then
  for _, e in ipairs(entries) do e.dist = FT.QuestDistance(e.info.questID) or 1e9 end
  table.sort(entries, function(a, b) if a.dist ~= b.dist then return a.dist < b.dist end return a.order < b.order end)
 elseif sort == 'durum' then
  -- TESLİME HAZIR / DEVAM EDEN; odaklanılan görev kendi grubunda en üstte
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
  local function pct(id)
   if q.IsComplete and q.IsComplete(id) then return 1 end
   local ok, list = pcall(q.GetQuestObjectives, id)
   local have, need = 0, 0
   for _, o in ipairs(ok and type(list) == 'table' and list or {}) do
    if (o.numRequired or 0) > 0 then have = have + math.min(o.numFulfilled or 0, o.numRequired); need = need + o.numRequired end
   end
   return need > 0 and have / need or 0
  end
  for _, e in ipairs(entries) do e.pct = pct(e.info.questID) end
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
 if qs then
  setFont(header, 12, '')
  header:SetText(('ForeverTrail: %d/%d'):format(#entries, MAX_QUESTLOG_QUESTS or 20))
  header:SetTextColor(1, 0.82, 0)
 else
  setFont(header, 15, 'OUTLINE')
  header:SetText(('Görevler  |cff9aa0a6%d|r'):format(#entries))
  header:SetTextColor(ar, ag, ab)
 end
 -- üstte tek satır: seviye ve dinlenmiş XP; varsa ikinci satırda rota
 local restedText = FT.RestedText and FT.RestedText()
 if FT.RouteOrder then pcall(FT.RouteOrder) end
 local route = FT.RouteSummary and ForeverTrailSettings.routenums ~= false and FT.RouteSummary()
 local rested = route
 summary:SetText((FT.LevelSummary and FT.LevelSummary() or '') .. (restedText and ('  ·  ' .. restedText) or '') .. (route and ('\n|cff9aa0a6' .. route .. '|r') or ''))
 toggle:SetText(ForeverTrailSettings.trackerCollapsed and '+' or '-')
 -- sabitlenenler (Ctrl+tık) ve elle sıralama (Alt+tık) en son uygulanır; bölge gruplaması korunur
 do
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
 end
 local inst = ForeverTrailSettings.trkInstance == true and IsInInstance and IsInInstance()
 if ForeverTrailSettings.trackerCollapsed or FT.trkCombatCollapsed or inst then
  if FT.HideTrackerItems then pcall(FT.HideTrackerItems, 1) end
  divider:Hide(); summary:Hide()
  if tracker.xpFill then tracker.xpFill:Hide(); tracker.xpRest:Hide() end
  tracker:SetHeight(32)
  return
 end
 divider:Show(); summary:Show()
 local extra = rested and 13 or 0
 if qs then summary:Hide(); divider:Hide(); extra = -18 end
 divider:ClearAllPoints(); divider:SetPoint('TOPLEFT', PAD, -40 - extra)
 -- ince XP çubuğu: dolu kısım vurgu renginde, dinlenmiş XP mavi
 do
  local xp, max = UnitXP and UnitXP('player') or 0, UnitXPMax and UnitXPMax('player') or 1
  local restXP = GetXPExhaustion and GetXPExhaustion() or 0
  local full = WIDTH - PAD * 2
  if not tracker.xpFill then
   tracker.xpFill = tracker:CreateTexture(nil, 'OVERLAY'); tracker.xpFill:SetHeight(3)
   tracker.xpRest = tracker:CreateTexture(nil, 'OVERLAY'); tracker.xpRest:SetHeight(3)
  end
  divider:SetHeight(3); divider:SetColorTexture(1, 1, 1, 0.12)
  local f1 = max > 0 and math.min(1, xp / max) or 0
  local f2 = max > 0 and math.min(1 - f1, (restXP or 0) / max) or 0
  tracker.xpFill:ClearAllPoints(); tracker.xpFill:SetPoint('TOPLEFT', divider, 'TOPLEFT', 0, 0); tracker.xpFill:SetWidth(math.max(1, full * f1))
  tracker.xpFill:SetColorTexture(ar, ag, ab, 0.9)
  tracker.xpRest:ClearAllPoints(); tracker.xpRest:SetPoint('TOPLEFT', tracker.xpFill, 'TOPRIGHT', 0, 0); tracker.xpRest:SetWidth(math.max(1, full * f2))
  tracker.xpRest:SetColorTexture(0.35, 0.6, 1, f2 > 0 and 0.8 or 0)
  tracker.xpFill:Show(); tracker.xpRest:Show()
  if qs then tracker.xpFill:Hide(); tracker.xpRest:Hide() end
 end
 local y, used, usedObjectives = BODY_TOP + extra, 0, 0
 local qStep, oStep, bars = 19, 23, true
 if FT.TrackerSteps then qStep, oStep, bars = FT.TrackerSteps() end
 if qs then qStep, oStep, bars = 15, 14, false end
 if compact then qStep = view == 'tablo' and 18 or math.max(16, qStep - 3) end
 local zoneCollapsed, minimized = charStore('trkZones'), charStore('trkMin')
 local zoneCount = {}
 for _, e in ipairs(entries) do zoneCount[e.zone] = (zoneCount[e.zone] or 0) + 1 end
 local lastZone, usedZones, hidden = nil, 0, 0
 if view == 'tablo' then y = y + drawColumnHeader(y) end
 local diff = ForeverTrailSettings.trkdiff ~= false
 for _, entry in ipairs(entries) do
  local info = entry.info
  if used >= maxQuests then break end
  if useZones and entry.zone ~= lastZone then
   lastZone = entry.zone
   usedZones = usedZones + 1
   local z = getZoneRow(usedZones)
   z.zone = entry.zone
   z:ClearAllPoints(); z:SetPoint('TOPLEFT', tracker, 'TOPLEFT', PAD, -y)
   if qs then
    setFont(z.text, 12, '')
    z.text:SetText('|cffc0c0c0' .. entry.zone .. (zoneCollapsed[entry.zone] and ' +' or '') .. '|r')
    z.line:SetColorTexture(0, 0, 0, 0)
   else
    setFont(z.text, 12, 'OUTLINE')
    z.text:SetText(('%s %s |cff9aa0a6(%d)|r'):format(zoneCollapsed[entry.zone] and '+' or '-', entry.zone, zoneCount[entry.zone]))
    z.text:SetTextColor(ar, ag, ab)
    z.line:SetColorTexture(ar, ag, ab, 0.3)
   end
   z:Show()
   y = y + 18
  end
  if useZones and zoneCollapsed[entry.zone] then hidden = hidden + 1 else
  used = used + 1
  local translation = QTR_QuestData and QTR_QuestData[tostring(info.questID)]
  local title = translation and translation.Title or info.title or ('Görev ' .. info.questID)
  local ready = q.IsComplete and q.IsComplete(info.questID)
  local mini = minimized[info.questID] or (ready and ForeverTrailSettings.trkAutoMin == true)
  local shared = FT.SharedCount and FT.SharedCount(info.questID) or 0
  local row = getQuestRow(used)
  row.questId = info.questID
  row:ClearAllPoints(); row:SetPoint('TOPLEFT', tracker, 'TOPLEFT', PAD, -y)
  local pinned = charStore('trkPin')[info.questID]
  if qs then
   setFont(row.title, 11, ''); row.title:ClearAllPoints(); row.title:SetPoint('LEFT', 14, 0); row.title:SetPoint('RIGHT', row, 'RIGHT', -4, 0)
   if not row.exp then
    row.exp = CreateFrame('Button', nil, row); row.exp:SetSize(12, 12); row.exp:SetPoint('LEFT', 0, 0)
    row.exp.tex = row.exp:CreateTexture(nil, 'ARTWORK'); row.exp.tex:SetAllPoints()
    row.exp:SetScript('OnClick', function(self)
     local store = charStore('trkMin'); local id = self:GetParent().questId
     if id then store[id] = not store[id] or nil; FT.RefreshTracker() end
    end)
   end
   row.exp.tex:SetTexture(mini and 'Interface\\Buttons\\UI-PlusButton-Up' or 'Interface\\Buttons\\UI-MinusButton-Up')
   row.exp:Show()
  else
   setFont(row.title, 13, ''); row.title:ClearAllPoints(); row.title:SetPoint('LEFT', 0, 0); row.title:SetPoint('RIGHT', row, 'RIGHT', -46, 0)
   if row.exp then row.exp:Hide() end
  end
  row.title:SetText((pinned and '|cffffd100•|r ' or '') .. ((mini and not qs) and '|cff9aa0a6+|r ' or '') .. (FT.focusQuest == info.questID and '|cff55ddff◆|r ' or '') .. ((diff and info.level and info.level > 0) and ('[' .. info.level .. '] ') or '') .. title)
  row:SetAlpha(FT.focusQuest and FT.focusQuest ~= info.questID and 0.5 or 1)
  local tag = (not diff and info.level) and tostring(info.level) or ''
  if entry.dist and entry.dist < 1e9 then tag = ('%d m'):format(entry.dist) end
  if shared > 0 then tag = ('+%d ortak'):format(shared) end
  local group = info.suggestedGroup and info.suggestedGroup > 1
  if group then tag = ('Grup %d'):format(info.suggestedGroup) end
  if FT.IsNewQuest and FT.IsNewQuest(info.questID) then tag = FT.NEW_TAG .. (tag ~= '' and (' ' .. tag) or '') end
  if ready then
   if qs then
    if FT.DiffColor then row.title:SetTextColor(FT.DiffColor(info.level)) end
    row.title:SetText(row.title:GetText() .. ' |cff40ff40(Tamamlandı)|r')
    row.tag:SetText('')
   else
    row.title:SetTextColor(0.62, 0.95, 0.55)
    row.tag:SetText('|cff55ff55Teslim|r')
   end
  else
   if diff and FT.DiffColor then row.title:SetTextColor(FT.DiffColor(info.level)) else row.title:SetTextColor(1, 0.92, 0.75) end
   row.tag:SetText(qs and '' or tag)
   if group then row.tag:SetTextColor(1, 0.35, 0.35) elseif shared > 0 then row.tag:SetTextColor(0.45, 0.7, 1) else row.tag:SetTextColor(0.75, 0.72, 0.66) end
  end
  if compact then styleCompact(row, info, view, title, pinned, entry.dist) elseif row.tagMoved then resetCompactRow(row) end
  row:Show()
  if FT.DecorateQuestRow then pcall(FT.DecorateQuestRow, row, info.questID, ready) end
  if FT.TrackerItemButton then pcall(FT.TrackerItemButton, used, row, info.questID) end
  y = y + qStep
  local ender = ready and not mini and not compact and FT.TurnInName and FT.TurnInName(info.questID)
  if ender and usedObjectives < MAX_OBJECTIVES then
   usedObjectives = usedObjectives + 1
   local o = getObjectiveRow(usedObjectives)
   o:ClearAllPoints(); o:SetPoint('TOPLEFT', tracker, 'TOPLEFT', PAD + (qs and 14 or 0), -y)
   setFont(o.label, qs and 11 or 12, '')
   o.label:SetText('Teslim: ' .. ender); o.label:SetTextColor(qs and 0.94 or 0.55, qs and 0.94 or 1, qs and 0.94 or 0.55)
   o.count:SetText(''); o.barBg:Hide(); o.barFill:Hide()
   o:Show()
   y = y + 17
  end
  if not ready and not mini and not compact and q.GetQuestObjectives then
   local ok, objectives = pcall(q.GetQuestObjectives, info.questID)
   if ok and type(objectives) == 'table' then
    for objIndex, data in ipairs(objectives) do
     if usedObjectives >= MAX_OBJECTIVES then break end
     usedObjectives = usedObjectives + 1
     local o = getObjectiveRow(usedObjectives)
     o:ClearAllPoints(); o:SetPoint('TOPLEFT', tracker, 'TOPLEFT', PAD + (qs and 14 or 0), -y)
     setFont(o.label, qs and 11 or 12, '')
     if not qs then o.label:SetWidth(WIDTH - PAD * 2 - 66) end
     local need, have = data.numRequired or 0, data.numFulfilled or 0
     local done = data.finished or (need > 0 and have >= need)
     if done and ForeverTrailSettings.trkHideDoneObj ~= false then usedObjectives = usedObjectives - 1 else
     o.label:SetText(FT.ParseObjective and FT.ParseObjective(data.text or '') or (data.text or ''))
     o.label:SetTextColor(done and 0.62 or 0.92, done and 0.85 or 0.88, done and 0.6 or 0.8)
     local r, g, b = progressColor(have, need, done)
     if need > 0 then
      o.count:SetText(('%d/%d'):format(have, need))
      if bars then o.barBg:Show(); o.barFill:Show() else o.barBg:Hide(); o.barFill:Hide() end
      o.barFill:SetWidth(math.max(1, (WIDTH - PAD * 2 - 8) * math.min(1, have / need)))
      o.barFill:SetColorTexture(r, g, b, 1)
     else
      o.count:SetText(done and 'OK' or '')
      o.barBg:Hide(); o.barFill:Hide()
     end
     o.count:SetTextColor(r, g, b)
     if qs then
      -- Questie: hedef metni oyunun yazdığı gibi ("X öldürüldü: 3/8"), beyaz; tamamlanınca yeşil
      o.label:SetText(data.text or ''); o.label:SetWidth(WIDTH - PAD * 2 - 22)
      if done then o.label:SetTextColor(0.25, 1, 0.25) else o.label:SetTextColor(0.94, 0.94, 0.94) end
      o.count:SetText(''); o.barBg:Hide(); o.barFill:Hide()
     end
     if FT.ObjectiveProgress then pcall(FT.ObjectiveProgress, o, info.questID, objIndex, have, need) end
     o:Show()
     y = y + oStep
     end
    end
   end
  end
  local partyText = not compact and FT.PartyText and FT.PartyText(info.questID)
  if partyText and usedObjectives < MAX_OBJECTIVES then
   usedObjectives = usedObjectives + 1
   local o = getObjectiveRow(usedObjectives)
   o:ClearAllPoints(); o:SetPoint('TOPLEFT', tracker, 'TOPLEFT', PAD, -y)
   o.label:SetText(partyText); o.label:SetTextColor(0.55, 0.8, 1)
   o.count:SetText(''); o.barBg:Hide(); o.barFill:Hide()
   o:Show()
   y = y + 17
  end
  y = y + (compact and 1 or 4)
  end
 end
 if #entries > used + hidden then
  moreText:ClearAllPoints(); moreText:SetPoint('TOPLEFT', tracker, 'TOPLEFT', PAD + 4, -y)
  moreText:SetText(('+%d görev daha (panelden bak)'):format(#entries - used - hidden)); moreText:Show()
  y = y + 16
 end
 if #entries == 0 then emptyText:SetText('Günlükte görev yok.'); emptyText:Show(); y = y + 20 end
 if FT.HideTrackerItems then pcall(FT.HideTrackerItems, used + 1) end
 tracker:SetHeight(y + 8)
end

local combat = CreateFrame('Frame')
pcall(combat.RegisterEvent, combat, 'PLAYER_REGEN_DISABLED'); pcall(combat.RegisterEvent, combat, 'PLAYER_REGEN_ENABLED')
combat:SetScript('OnEvent', function(_, event)
 FT.trkCombatCollapsed = event == 'PLAYER_REGEN_DISABLED' and ForeverTrailSettings and ForeverTrailSettings.trkCombat == true or nil
 if FT.RefreshTracker then pcall(FT.RefreshTracker) end
end)
