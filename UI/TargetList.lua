local _, FT = ...

-- Hedef listesi: görev günlüğündeki yapılmamış hedefler (yaratık portresi / eşya simgesi, ad, sayaç) küçük, bağımsız bir pencerede.
-- Etkileşim: satıra tıkla = en yakın noktaya git (ok + harita), sağ tık = yalnızca o görevi izle (tekrar sağ tık = hepsi),
-- Shift+tık = haritayı aç, başlığa tıkla = daralt, sürükle = taşı. İlerleme olunca satır yeşil yanıp söner.
-- Veri FT.ActiveObjectives()'ten (Map/Objectives.lua) gelir. Ayar: ForeverTrailSettings.targetList (false = kapalı). /ftrail hedefler.

local WIDTH, HEAD_H, ROW_H, GAP, MAX_ROWS = 250, 26, 38, 3, 6
local QUESTION = 'Interface\\Icons\\INV_Misc_QuestionMark'
local KIND = {kill = 'Öldür', loot = 'Topla', object = 'Kullan', talk = 'Konuş'}

local win, rows = nil, {}
local list, focusQuest = {}, nil
local lastHave = {}
local waited = 0

local function enabled() return not ForeverTrailSettings or ForeverTrailSettings.targetList ~= false end

local function itemIconOf(id)
 local ok, icon = pcall(function()
  if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
  if GetItemIcon then return GetItemIcon(id) end
 end)
 return ok and icon or nil
end

local function objectiveName(o)
 local name = FT.ParseObjective and FT.ParseObjective(o.text) or o.text or ''
 if name == '' then name = o.text or '' end
 return name
end

local function keyOf(o) return tostring(o.questId) .. ':' .. tostring(o.index) end

-- Gösterilecek hedefler: yapılmamış olanlar; rehberin şu anki görevi önce; odak varsa yalnızca o görev
local function collect()
 local out = {}
 if not FT.ActiveObjectives then return out end
 local ok, all = pcall(FT.ActiveObjectives)
 if not (ok and type(all) == 'table') then return out end
 local g = FT.guide
 local step = g and g.steps and g.steps[FT.view or 1]
 local current = step and step.questId
 for pass = 1, 2 do
  for _, o in ipairs(all) do
   if not o.done and (not focusQuest or o.questId == focusQuest) then
    local first = current and o.questId == current
    if (pass == 1 and first) or (pass == 2 and not first) then out[#out + 1] = o end
   end
  end
 end
 return out
end

-- Hedefin en yakın noktası: oyuncunun haritasında en yakın, yoksa ilk nokta
local function nearestPoint(o)
 if not FT.SpawnPoints then return nil end
 local ok, points = pcall(FT.SpawnPoints, {questId = o.questId, type = 'objective', objectiveIndex = o.index})
 if not (ok and type(points) == 'table' and #points > 0) then return nil end
 local map = C_Map and C_Map.GetBestMapForUnit and select(2, pcall(C_Map.GetBestMapForUnit, 'player'))
 local px, py
 if map and FT.PlayerPosition then
  local good, x, y = pcall(FT.PlayerPosition, map)
  if good then px, py = x, y end
 end
 local best, bestD
 for _, p in ipairs(points) do
  local d = (p.map == map and px) and ((p.x - px) ^ 2 + (p.y - py) ^ 2) or (1000 + (p.x - 0.5) ^ 2)
  if not bestD or d < bestD then best, bestD = p, d end
 end
 return best
end

local function go(o)
 local p = nearestPoint(o)
 if p and FT.SetCustomTarget then
  FT.SetCustomTarget(p.map, p.x, p.y, objectiveName(o))
 elseif FT.OpenMap then
  FT.OpenMap()
 end
end

local function newRow(i)
 local K = FT.Kit
 local r = CreateFrame('Button', nil, win)
 r:SetHeight(ROW_H)
 r:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
 r:RegisterForDrag('LeftButton')
 r.bg = r:CreateTexture(nil, 'BACKGROUND'); r.bg:SetAllPoints(); K.Fill(r.bg, 'card', 0.92)
 r.hl = r:CreateTexture(nil, 'BORDER'); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 1, 1, 0.07); r.hl:Hide()
 r.flash = r:CreateTexture(nil, 'ARTWORK'); r.flash:SetAllPoints(); r.flash:SetColorTexture(0.4, 1, 0.45, 1); r.flash:SetAlpha(0)
 r.mark = r:CreateTexture(nil, 'ARTWORK', nil, 1); r.mark:SetWidth(3); r.mark:SetPoint('TOPLEFT', 0, 0); r.mark:SetPoint('BOTTOMLEFT', 0, 0)
 r.frame = CreateFrame('Frame', nil, r); r.frame:SetSize(32, 32); r.frame:SetPoint('LEFT', 7, 0)
 pcall(K.Skin, r.frame, 'deep', 'line')
 r.icon = r.frame:CreateTexture(nil, 'ARTWORK'); r.icon:SetPoint('TOPLEFT', 1, -1); r.icon:SetPoint('BOTTOMRIGHT', -1, 1)
 local ok, model = pcall(CreateFrame, 'PlayerModel', nil, r.frame)
 if ok and model then
  r.model = model; model:SetPoint('TOPLEFT', 1, -1); model:SetPoint('BOTTOMRIGHT', -1, 1); model:Hide()
  -- animasyonu dondur: istemci hangisini destekliyorsa (hiçbiri yoksa model kullanılmaz, simge gösterilir)
  model.canFreeze = (model.SetPaused or model.FreezeAnimation or model.SetAnimation) and true or false
  model.freeze = function()
   if model.SetAnimation then pcall(model.SetAnimation, model, 0, 0) end
   if model.FreezeAnimation then pcall(model.FreezeAnimation, model, 0, 0, 0) end
   if model.SetPaused then pcall(model.SetPaused, model, true) end
  end
  -- model geç yüklenirse yeniden dondur
  if model.HookScript then pcall(model.HookScript, model, 'OnModelLoaded', function() model.freeze() end) end
 end
 r.name = K.Text(r, 12, 'text'); r.name:SetPoint('LEFT', r.frame, 'RIGHT', 9, 0); r.name:SetPoint('RIGHT', r, 'RIGHT', -46, 0); r.name:SetJustifyH('LEFT'); r.name:SetWordWrap(false)
 r.count = K.Text(r, 13, 'text'); r.count:SetPoint('RIGHT', -10, 0); r.count:SetJustifyH('RIGHT')
 r:SetScript('OnEnter', function(self)
  self.hl:Show()
  local tip = K.Tooltip(); if not tip or not self.o then return end
  tip:SetOwner(self, 'ANCHOR_LEFT')
  tip:SetText(self.fullName or '', 1, 0.82, 0)
  tip:AddLine((self.o.title or '') .. (self.kindLabel and ('  ·  ' .. self.kindLabel) or ''), 0.85, 0.85, 0.85)
  tip:AddLine('Tık: en yakın noktaya git', 0.65, 0.65, 0.65)
  tip:AddLine(focusQuest == self.o.questId and 'Sağ tık: tüm görevleri göster' or 'Sağ tık: yalnızca bu görevi izle', 0.65, 0.65, 0.65)
  tip:AddLine('Shift+tık: haritayı aç', 0.65, 0.65, 0.65)
  tip:Show()
 end)
 r:SetScript('OnLeave', function(self) self.hl:Hide(); K.HideTips() end)
 r:SetScript('OnClick', function(self, button)
  local o = self.o; if not o then return end
  if button == 'RightButton' then
   if focusQuest == o.questId then focusQuest = nil else focusQuest = o.questId end
   FT.RefreshTargetList(true)
  elseif IsShiftKeyDown and IsShiftKeyDown() then
   if FT.OpenMap then FT.OpenMap() end
  else
   go(o)
  end
 end)
 r:SetScript('OnDragStart', function() if win:IsMovable() then win:StartMoving() end end)
 r:SetScript('OnDragStop', function() win:GetScript('OnDragStop')(win) end)
 rows[i] = r
 return r
end

local function fillRow(r, o)
 local K = FT.Kit
 r.o = o
 r.fullName = objectiveName(o); r.kindLabel = KIND[o.kind]
 r.name:SetText(r.fullName)
 r.count:SetText(o.need and o.need > 0 and ('%d/%d'):format(o.have or 0, o.need) or '')
 local c = o.color or K.Color('accent')
 r.mark:SetColorTexture(c[1], c[2], c[3], 1)
 local tc = K.Color('text'); r.name:SetTextColor(tc[1], tc[2], tc[3])
 r.count:SetTextColor(c[1], c[2], c[3])
 -- portre: yaratık (3B model) → eşya simgesi → genel simge
 local npc = o.npcs and o.npcs[1]
 local shown = false
 if npc and r.model and r.model.canFreeze then
  -- yalnızca hedef değişince yükle (her yenilemede yeniden yüklemek titretir); animasyon donuk, sabit portre
  if r.npc ~= npc then
   r.npc = npc
   r.model:ClearModel()
   if not pcall(r.model.SetCreature, r.model, npc) then r.npc = nil end
   if r.model.SetPortraitZoom then pcall(r.model.SetPortraitZoom, r.model, 0.8) end
   r.model.freeze()
  end
  if r.npc == npc then r.model:Show(); r.icon:Hide(); shown = true end
 end
 if not shown then r.npc = nil end
 if not shown then
  if r.model then r.model:Hide() end
  r.icon:SetTexture((o.itemId and itemIconOf(o.itemId)) or (FT.ObjectiveIcons and FT.ObjectiveIcons[o.kind]) or QUESTION)
  r.icon:Show()
 end
 -- ilerleme olduysa yeşil parlama
 local key = keyOf(o)
 if lastHave[key] and (o.have or 0) > lastHave[key] then r.flashT = 0.9 end
 lastHave[key] = o.have or 0
end

local function build()
 local K = FT.Kit
 win = CreateFrame('Frame', 'ForeverTrailTargetList', UIParent)
 FT.targetList = win
 win:SetSize(WIDTH, HEAD_H + 8)
 win:SetFrameStrata('MEDIUM'); win:SetClampedToScreen(true)
 win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag('LeftButton')
 local p = ForeverTrailSettings.targetListPoint
 if p and p[1] and p[3] and p[4] then win:SetPoint(p[1], UIParent, p[2] or p[1], p[3], p[4]) else win:SetPoint('RIGHT', UIParent, 'RIGHT', -40, 60) end
 win:SetScript('OnDragStart', function(self) self:StartMoving() end)
 win:SetScript('OnDragStop', function(self)
  self:StopMovingOrSizing()
  local point, _, relative, x, y = self:GetPoint()
  if point then ForeverTrailSettings.targetListPoint = {point, relative or point, x, y} end
 end)
 K.Skin(win, 'mid', 'line')
 -- başlık: tıklayınca daralır
 win.head = CreateFrame('Button', nil, win); win.head:SetHeight(HEAD_H)
 win.head:SetPoint('TOPLEFT', 0, 0); win.head:SetPoint('TOPRIGHT', -26, 0)
 win.head:RegisterForDrag('LeftButton')
 win.head:SetScript('OnDragStart', function() win:StartMoving() end)
 win.head:SetScript('OnDragStop', function() win:GetScript('OnDragStop')(win) end)
 win.head:SetScript('OnClick', function()
  ForeverTrailSettings.targetListCollapsed = not ForeverTrailSettings.targetListCollapsed
  FT.RefreshTargetList(true)
 end)
 win.title = K.Text(win.head, 11, 'accent'); win.title:SetPoint('LEFT', 10, 0); win.title:SetText('Hedefler')
 win.sub = K.Text(win.head, 10, 'muted'); win.sub:SetPoint('LEFT', win.title, 'RIGHT', 8, 0); win.sub:SetJustifyH('LEFT')
 win.close = K.CloseButton(win, function() ForeverTrailSettings.targetList = false; FT.RefreshTargetList(true) end)
 win.close:SetPoint('TOPRIGHT', -2, -2)
 win:SetScript('OnUpdate', function(_, dt)
  for _, r in ipairs(rows) do
   if r.flashT then
    r.flashT = r.flashT - dt
    if r.flashT <= 0 then r.flashT = nil; r.flash:SetAlpha(0) else r.flash:SetAlpha(r.flashT * 0.45) end
   end
  end
 end)
 win:Hide()
 if FT.FixFonts then pcall(FT.FixFonts, win) end
end

function FT.RefreshTargetList(force)
 if not enabled() then if win and win:IsShown() then win:Hide() end return end
 if not win then
  if not FT.Kit then return end
  local ok, err = pcall(build)
  if not ok then win = nil; if FT.errors and #FT.errors < 20 then FT.errors[#FT.errors + 1] = 'targetlist: ' .. tostring(err) end; return end
 end
 list = collect()
 if focusQuest then
  local still = false
  for _, o in ipairs(list) do if o.questId == focusQuest then still = true end end
  if not still then focusQuest = nil; list = collect() end
 end
 if #list == 0 then if win:IsShown() then win:Hide() end return end
 local collapsed = ForeverTrailSettings.targetListCollapsed
 win.sub:SetText(focusQuest and (list[1].title or '') or ('%d hedef'):format(#list))
 local n = collapsed and 0 or math.min(#list, MAX_ROWS)
 for i = 1, math.max(n, #rows) do
  local r = rows[i] or (i <= n and newRow(i))
  if r then
   if i <= n then
    r:ClearAllPoints(); r:SetPoint('TOPLEFT', win, 'TOPLEFT', 4, -(HEAD_H + (i - 1) * (ROW_H + GAP))); r:SetPoint('RIGHT', win, 'RIGHT', -4, 0)
    fillRow(r, list[i]); r:Show()
   else r:Hide(); r.o = nil end
  end
 end
 win:SetHeight(HEAD_H + 4 + (n > 0 and (n * (ROW_H + GAP)) or 0))
 if not win:IsShown() then win:Show() end
end

function FT.ToggleTargetList()
 ForeverTrailSettings.targetList = not enabled()
 ForeverTrailSettings.targetListCollapsed = nil
 FT.RefreshTargetList(true)
 FT.Print(enabled() and 'Hedef listesi açık.' or 'Hedef listesi kapalı.')
end

local driver = CreateFrame('Frame')
driver:SetScript('OnUpdate', function(_, dt)
 waited = waited + dt
 if waited < 0.5 then return end
 waited = 0
 pcall(FT.RefreshTargetList)
end)

-- Test ve tanı için
function FT.TargetListRows()
 local out = {}
 for _, r in ipairs(rows) do if r:IsShown() then out[#out + 1] = r end end
 return out
end
function FT.TargetListFocus() return focusQuest end
