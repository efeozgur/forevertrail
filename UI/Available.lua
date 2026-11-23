local _, FT = ...

-- Ekranın sol kenarında "Alınabilir görevler" kutusu: bulunduğun bölgede alabileceğin görevler,
-- en yakından uzağa; görev kutusu (sağ) ile aynı tasarım. Tıkla: yol göster.

local WIDTH, PAD, MAX = 276, 12, 7
local box, header, toggle, emptyText
local rows = {}

local function fontPath() return FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF' end
local function newText(parent, size, flags, justify)
 local fs = parent:CreateFontString(nil, 'OVERLAY')
 if fs:SetFont(fontPath(), size, flags or '') == false then fs:SetFont('Fonts\\ARIALN.TTF', size, flags or '') end
 fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.85)
 fs:SetJustifyH(justify or 'LEFT')
 return fs
end

local function applyAlpha()
 if not box then return end
 local base = ForeverTrailSettings.trackerAlpha or 1
 box:SetAlpha(box.hovering and 1 or base)
 local bg = box.softBg or box.bg
 local st = FT.TrackerStyle and FT.TrackerStyle() or 'kutu'
 if bg then bg:SetAlpha(((st == 'seffaf' or st == 'questie') and not box.hovering) and 0 or 1) end
end
local function hover(on)
 box.hovering = on or box:IsMouseOver()
 applyAlpha()
end

local function getRow(i)
 if rows[i] then return rows[i] end
 local r = CreateFrame('Button', nil, box)
 r:SetSize(WIDTH - PAD * 2, 30)
 r.title = newText(r, 13, '', 'LEFT')
 r.title:SetPoint('TOPLEFT', 0, -1); r.title:SetPoint('RIGHT', r, 'RIGHT', -44, 0); r.title:SetWordWrap(false)
 r.dist = newText(r, 11, '', 'RIGHT')
 r.dist:SetPoint('TOPRIGHT', 0, -2)
 r.sub = newText(r, 11, '', 'LEFT')
 r.sub:SetPoint('TOPLEFT', 8, -16); r.sub:SetPoint('RIGHT', r, 'RIGHT', 0, 0); r.sub:SetWordWrap(false)
 r.sub:SetTextColor(0.75, 0.71, 0.64)
 r.hl = r:CreateTexture(nil, 'HIGHLIGHT'); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 1, 1, 0.07)
 r:SetScript('OnClick', function(self)
  local m = self.mark
  if m then FT.SetCustomTarget(m.map, m.x, m.y, FT.QuestTitle and FT.QuestTitle(m.questId) or m.giver) end
 end)
 r:SetScript('OnEnter', function(self)
  hover(true)
  local m = self.mark
  if not (m and GameTooltip) then return end
  GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
  if FT.QuestInfoTip then
   FT.QuestInfoTip(GameTooltip, m.questId, m, self.distValue)
  else
   GameTooltip:SetText(('[%s] %s'):format(m.level or '?', FT.QuestTitle and FT.QuestTitle(m.questId) or ''), 1, 0.82, 0)
   GameTooltip:AddLine('Görev veren: ' .. (m.giver or '?'), 1, 1, 1)
   GameTooltip:AddLine('Sol tık: yol göster', 0.55, 0.55, 0.55)
  end
  if FT.ShowTip then FT.ShowTip(GameTooltip) else GameTooltip:Show() end
 end)
 r:SetScript('OnLeave', function() if GameTooltip then GameTooltip:Hide() end hover(false) end)
 rows[i] = r
 return r
end

function FT.CreateAvailableBox()
 if box then return end
 box = CreateFrame('Frame', 'ForeverTrailAvailable', UIParent)
 FT.availableBox = box
 box:SetSize(WIDTH, 60)
 box:SetMovable(true); box:EnableMouse(true); box:SetClampedToScreen(true)
 box:RegisterForDrag('LeftButton')
 box:SetScript('OnDragStart', function(self) if not ForeverTrailSettings.locked then self:StartMoving() end end)
 box:SetScript('OnDragStop', function(self)
  self:StopMovingOrSizing()
  local point, _, relative, x, y = self:GetPoint()
  ForeverTrailSettings.availPoint = {point, relative, x, y}
 end)
 box:SetScript('OnEnter', function() hover(true) end)
 box:SetScript('OnLeave', function() hover(false) end)
 local p = ForeverTrailSettings.availPoint
 if p and p[1] and p[2] and p[3] and p[4] then box:SetPoint(p[1], UIParent, p[2], p[3], p[4])
 else box:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 2, -180) end
 if FT.SoftBackdrop then FT.SoftBackdrop(box) end
 header = newText(box, 15, 'OUTLINE', 'LEFT')
 header:SetPoint('TOPLEFT', PAD, -9)
 local line = box:CreateTexture(nil, 'ARTWORK'); line:SetSize(WIDTH - PAD * 2, 1); line:SetPoint('TOPLEFT', PAD, -28)
 line:SetColorTexture(1, 1, 1, 1)
 if FT.RegisterAccent then FT.RegisterAccent(line, 0.55) end
 box.line = line
 toggle = FT.NewButton and FT.NewButton(box, '-', 20, 18)
 if not toggle then toggle = CreateFrame('Button', nil, box, 'UIPanelButtonTemplate'); toggle:SetSize(20, 18) end
 toggle:SetPoint('TOPRIGHT', -8, -8)
 toggle:SetScript('OnClick', function()
  ForeverTrailSettings.availCollapsed = not ForeverTrailSettings.availCollapsed
  FT.RefreshAvailableBox()
 end)
 emptyText = newText(box, 12, '', 'LEFT')
 emptyText:SetPoint('TOPLEFT', PAD + 4, -36)
 emptyText:SetTextColor(0.78, 0.72, 0.64)
 box.headerText, box.toggleButton = header, toggle -- QuestDock bunları gizler
 applyAlpha()
end

-- Tablo görünümünün sütun başlıkları (Sv | Görev | Veren | Mesafe)
local function drawColumnHeader(y)
 if not box.colHdr then
  local f = CreateFrame('Frame', nil, box)
  f:SetSize(WIDTH - PAD * 2, 14)
  f.lvl = newText(f, 10, '', 'LEFT'); f.lvl:SetPoint('LEFT', 0, 0); f.lvl:SetText('Sv')
  f.name = newText(f, 10, '', 'LEFT'); f.name:SetPoint('LEFT', 28, 0); f.name:SetText('Görev')
  f.giver = newText(f, 10, '', 'LEFT'); f.giver:SetPoint('LEFT', 28 + 112, 0); f.giver:SetText('Veren')
  f.dist = newText(f, 10, '', 'RIGHT'); f.dist:SetPoint('RIGHT', 0, 0); f.dist:SetText('Mesafe')
  for _, fs in ipairs({f.lvl, f.name, f.giver, f.dist}) do fs:SetTextColor(0.62, 0.6, 0.56) end
  box.colHdr = f
 end
 box.colHdr:ClearAllPoints(); box.colHdr:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD, -y)
 box.colHdr:Show()
 return 16
end

-- Satırı seçili görünüme göre yerleştir: kart (iki satır), liste (tek satır), tablo (sütunlar)
local function layoutRow(r, view, showGiver)
 if view == 'tablo' then
  if not r.lvl then
   r.lvl = newText(r, 11, '', 'LEFT'); r.lvl:SetPoint('LEFT', 0, 0); r.lvl:SetWidth(26)
   r.giver = newText(r, 11, '', 'LEFT')
  end
  r:SetHeight(18)
  r.title:ClearAllPoints(); r.title:SetPoint('LEFT', 28, 0); r.title:SetWidth(108)
  r.giver:ClearAllPoints(); r.giver:SetPoint('LEFT', 28 + 112, 0); r.giver:SetWidth(WIDTH - PAD * 2 - 28 - 112 - 44)
  r.giver:SetTextColor(0.75, 0.71, 0.64); r.giver:SetWordWrap(false); r.giver:Show(); r.lvl:Show()
  r.dist:ClearAllPoints(); r.dist:SetPoint('RIGHT', 0, 0)
  r.sub:Hide()
 elseif view == 'liste' then
  if r.lvl then r.lvl:Hide(); r.giver:Hide() end
  r:SetHeight(18)
  r.title:SetWidth(0)
  r.title:ClearAllPoints(); r.title:SetPoint('LEFT', 0, 0); r.title:SetPoint('RIGHT', r, 'RIGHT', -48, 0)
  r.dist:ClearAllPoints(); r.dist:SetPoint('RIGHT', 0, 0)
  r.sub:Hide()
 else
  if r.lvl then r.lvl:Hide(); r.giver:Hide() end
  r:SetHeight(showGiver and 30 or 18)
  r.title:SetWidth(0)
  r.title:ClearAllPoints(); r.title:SetPoint('TOPLEFT', 0, -1); r.title:SetPoint('RIGHT', r, 'RIGHT', -44, 0)
  r.dist:ClearAllPoints(); r.dist:SetPoint('TOPRIGHT', 0, -2)
  r.sub:SetShown(showGiver)
 end
end

function FT.RefreshAvailableBox()
 if not box then return end
 if ForeverTrailSettings.availbox == false or (ForeverTrailSettings.simple == true) then box:Hide(); return end
 box:Show()
 if FT.tracker then box:SetScale(FT.tracker:GetScale() or 1) end
 for _, r in ipairs(rows) do r:Hide() end
 emptyText:Hide()
 local a = FT.Style and FT.Style.accent or {0.95, 0.72, 0.35}
 local map, px, py
 if C_Map and C_Map.GetBestMapForUnit then
  map = C_Map.GetBestMapForUnit('player')
  local pos = map and C_Map.GetPlayerMapPosition(map, 'player')
  if pos then px, py = pos:GetXY() end
 end
 local view = ForeverTrailSettings.c_availView or 'kart'
 if view ~= 'liste' and view ~= 'tablo' then view = 'kart' end
 local maxRows = tonumber(ForeverTrailSettings.c_availMax) or MAX
 local sortBy = ForeverTrailSettings.c_availSort or 'yakin'
 local hideLow = ForeverTrailSettings.availHideLow == true
 local showGiver = ForeverTrailSettings.availShowGiver ~= false
 if box.colHdr then box.colHdr:Hide() end
 local list, seen = {}, {}
 local ww, wh
 if map and C_Map.GetMapWorldSize then
  local ok, w, h = pcall(C_Map.GetMapWorldSize, map)
  if ok then ww, wh = w, h end
 end
 if map and FT.QuestMarks then
  local ok, marks = pcall(FT.QuestMarks, map)
  for _, m in ipairs(ok and marks or {}) do
   if m.kind ~= '?' and m.questId and not (hideLow and m.low) then
    local d = 1e9
    if px and ww then d = math.sqrt(((m.x - px) * ww) ^ 2 + ((m.y - py) * wh) ^ 2) end
    local old = seen[m.questId]
    if not old then seen[m.questId] = {m = m, d = d}; list[#list + 1] = seen[m.questId]
    elseif d < old.d then old.m, old.d = m, d end
   end
  end
 end
 table.sort(list, function(x, y)
  if (x.m.low and 1 or 0) ~= (y.m.low and 1 or 0) then return not x.m.low end
  if sortBy == 'seviye' then
   local lx, ly = x.m.level or 0, y.m.level or 0
   if lx ~= ly then return lx < ly end
  elseif sortBy == 'ad' then
   local nx = FT.QuestTitle and FT.QuestTitle(x.m.questId) or ''
   local ny = FT.QuestTitle and FT.QuestTitle(y.m.questId) or ''
   if nx ~= ny then return nx < ny end
  end
  return x.d < y.d
 end)
 FT.availCount = #list
 header:SetText(('Alınabilir  |cff9aa0a6%d|r'):format(#list))
 header:SetTextColor(a[1], a[2], a[3])
 toggle:SetText(ForeverTrailSettings.availCollapsed and '+' or '-')
 if ForeverTrailSettings.availCollapsed and not FT.questDock then box.line:Hide(); box:SetHeight(32); return end
 box.line:Show()
 local y = 34
 if view == 'tablo' then y = y + drawColumnHeader(y) end
 local step = view == 'kart' and (showGiver and 32 or 20) or 19
 for i = 1, math.min(maxRows, #list) do
  local e, r = list[i], getRow(i)
  local m = e.m
  r.mark = m
  r:ClearAllPoints(); r:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD, -y)
  layoutRow(r, view, showGiver)
  local title = FT.QuestTitle and FT.QuestTitle(m.questId) or ('Görev ' .. m.questId)
  local new = FT.IsNewQuest and FT.IsNewQuest(m.questId)
  if view == 'tablo' then
   r.lvl:SetText(m.level and tostring(m.level) or '')
   if FT.DiffColor then r.lvl:SetTextColor(FT.DiffColor(m.level)) else r.lvl:SetTextColor(1, 0.92, 0.75) end
   r.title:SetText(title .. (new and ' |cff55bbff*|r' or ''))
   r.giver:SetText(m.giver or '')
  else
   r.title:SetText(((m.level and ('[' .. m.level .. '] ')) or '') .. title .. (new and ' |cff55bbff*|r' or ''))
   r.sub:SetText(m.giver or '')
  end
  if FT.DiffColor then r.title:SetTextColor(FT.DiffColor(m.level)) else r.title:SetTextColor(1, 0.92, 0.75) end
  r.distValue = e.d
  r.dist:SetText(e.d < 1e9 and ('%d m'):format(math.floor(e.d + 0.5)) or '')
  r.dist:SetTextColor(a[1], a[2], a[3])
  r:Show()
  y = y + step
 end
 if #list > maxRows then
  emptyText:ClearAllPoints(); emptyText:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD + 4, -y)
  emptyText:SetText(('+%d görev daha (Ansiklopedi)'):format(#list - maxRows)); emptyText:Show(); y = y + 16
 elseif #list == 0 then
  emptyText:ClearAllPoints(); emptyText:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD + 4, -36)
  emptyText:SetText('Bu bölgede alınabilir görev yok.'); emptyText:Show(); y = y + 20
 end
 box:SetHeight(y + 6)
end

local ev = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD', 'QUEST_ACCEPTED', 'QUEST_TURNED_IN', 'ZONE_CHANGED_NEW_AREA', 'PLAYER_LEVEL_UP'}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript('OnEvent', function()
 if not ForeverTrailSettings then return end
 FT.CreateAvailableBox()
 pcall(FT.RefreshAvailableBox)
end)
local acc = 0
ev:SetScript('OnUpdate', function(_, dt)
 acc = acc + dt
 if acc < 2 or not box or not box:IsShown() then return end
 acc = 0
 local ok, err = pcall(FT.RefreshAvailableBox)
 if not ok and FT.errors and #FT.errors < 20 then FT.errors[#FT.errors + 1] = 'available: ' .. tostring(err) end
end)
