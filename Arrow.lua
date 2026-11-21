local _, FT = ...
local atan2 = math.atan2 or math.atan
local TWO_PI = math.pi * 2

-- dx, dy: hedef - oyuncu (harita ekseni, y aşağı). facing: oyuncunun baktığı yön (radyan, saat yönünün tersi, kuzey=0).
function FT.Bearing(dx, dy, facing)
 return (atan2(-dx, -dy) - (facing or 0)) % TWO_PI
end

local arrow, driver

function FT.PlayProgressSound()
 local id = SOUNDKIT and (SOUNDKIT.IG_QUEST_LIST_SELECT or SOUNDKIT.IG_QUEST_LIST_OPEN)
 if id and PlaySound and ForeverTrailSettings.sound ~= false then pcall(PlaySound, id) end
end

function FT.Alert(message, withSound)
 if FT.Flash then FT.Flash(message, 0.3, 1, 0.3) elseif UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(message, 0.3, 1, 0.3, 1) end
 FT.Print(message)
 if withSound then
  local id = SOUNDKIT and (SOUNDKIT.IG_QUEST_LIST_COMPLETE or SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01)
  if id and PlaySound and ForeverTrailSettings.sound ~= false then pcall(PlaySound, id) end
 end
end

local function hide()
 if arrow and arrow:IsShown() then arrow:Hide() end
end

local function otherZone(step, current)
 if ForeverTrailSettings.arrow == false then return hide() end
 local name = FT.MapName and FT.MapName(step.uiMapID)
 arrow.title:SetText((FT.QuestTitle and step.questId and FT.QuestTitle(step.questId, step.questTitle)) or step.questTitle or (FT.guide and FT.guide.title) or '')
 arrow.title:SetTextColor(1, 0.88, 0.6)
 arrow.tex:SetRotation(0)
 arrow.tex:SetAlpha(0.35)
 arrow.tex:SetVertexColor(0.78, 0.74, 0.68)
 arrow.dist:SetText('Başka bölge')
 local inside = current and FT.MapAncestor and FT.MapAncestor(current, step.uiMapID)
 arrow.eta:SetText(inside and 'Önce dışarı çık' or (FT.travelText or name or '?'))
 arrow.coords:SetText('')
 arrow.glow:SetAlpha(0)
 if not arrow:IsShown() then arrow:Show() end
end

function FT.FormatETA(seconds)
 if type(seconds) ~= 'number' or seconds < 0 then return '' end
 if seconds < 60 then return ('~%d sn'):format(math.max(1, math.floor(seconds + 0.5))) end
 return ('~%d dk'):format(math.floor(seconds / 60 + 0.5))
end

local function travelSpeed()
 local ok, _, run = pcall(GetUnitSpeed or function() return 0, 0 end, 'player')
 return (ok and type(run) == 'number' and run > 0) and run or 7
end

function FT.UpdateArrow()
 if not arrow then return end
 FT.travelText = nil
 FT.nav = nil
 local step = FT.customTarget or (FT.guide and not FT.complete and FT.CurrentStep())
 if (not step or not step.uiMapID) and FT.PathEndStep then step = FT.PathEndStep() end
 if not step or not step.uiMapID or not step.x or not step.y then return hide() end
 if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_Map.GetMapWorldSize) then return hide() end
 local ok, map = pcall(C_Map.GetBestMapForUnit, 'player')
 if not ok or not map then return hide() end
 local goal, hint = step, nil
 local viaStep = FT.ViaTarget and FT.ViaTarget(map, step)
 if viaStep then goal, hint = viaStep, viaStep.hint
 elseif map ~= step.uiMapID then
  local entrance = FT.EntranceTo and FT.EntranceTo(map, step.uiMapID)
  if entrance then goal, hint = entrance, entrance.hint
  else
   local flight = FT.FlightPlan and FT.FlightPlan(map, step)
   if flight then goal, hint = flight, flight.hint
   else
    local travel, text
    if FT.TravelHint then travel, text = FT.TravelHint(map, step) end
    if travel then goal, hint = travel, travel.hint else FT.travelText = text; return otherZone(step, map) end
   end
  end
 end
 local gotPos, pos = pcall(C_Map.GetPlayerMapPosition, map, 'player')
 if not gotPos or not pos then return hide() end
 local valid, px, py = pcall(function() return pos:GetXY() end)
 if not valid or type(px) ~= 'number' or type(py) ~= 'number' or (px == 0 and py == 0) then return hide() end
 local sized, width, height = pcall(C_Map.GetMapWorldSize, map)
 if not sized or not width or not height or width <= 0 or height <= 0 then return hide() end
 local dx, dy = (goal.x - px) * width, (goal.y - py) * height
 local dist = math.sqrt(dx * dx + dy * dy)
 FT.nav = {dx=dx, dy=dy, dist=dist, step=goal, px=px, py=py, hint=hint, final=step}
 if dist < 15 then
  if arrow.arrivedKey ~= goal.stepId then
   arrow.arrivedKey = goal.stepId
   if goal.via and FT.PassVia then
    FT.PassVia()
   elseif hint then
    FT.Alert(hint .. ' noktasına vardın', true)
   elseif step.pathEnd then
    if FT.PassVia then FT.PassVia() end
   elseif step.type == 'objective' and step ~= FT.customTarget then
    -- toplama/öldürme: ok her seferinde en yakın nesneye döner; uyarı yalnızca bölgeye ilk girişte
    local areaKey = tostring(step.questId) .. ':' .. tostring(step.objectiveIndex or step.text or '')
    if arrow.areaKey ~= areaKey then
     arrow.areaKey = areaKey
     FT.Alert('Görev bölgesine vardın: ' .. (step.questTitle or ''), true)
    end
   else
    FT.Alert('Hedefe vardın: ' .. (step.questTitle or ''), true)
    if step == FT.customTarget then FT.customTarget = nil; if ForeverTrailCharacter then ForeverTrailCharacter.customTarget = nil end end
   end
  end
 elseif dist > 40 and arrow.arrivedKey == goal.stepId then
  arrow.arrivedKey = nil
 end
 if ForeverTrailSettings.arrow == false then return hide() end
 local color = (FT.TypeColor and FT.TypeColor[step.type]) or {1, 0.82, 0.2}
 if hint then
  arrow.title:SetText(hint)
  arrow.title:SetTextColor(0.6, 0.85, 1)
 else
  arrow.title:SetText((FT.QuestTitle and step.questId and FT.QuestTitle(step.questId, step.questTitle)) or step.questTitle or (FT.guide and FT.guide.title) or '')
  arrow.title:SetTextColor(color[1], color[2], color[3])
 end
 arrow.coords:SetText(('%.1f, %.1f'):format(goal.x * 100, goal.y * 100))
 if dist < 15 then
  arrow.tex:SetAlpha(0.45)
  arrow.tex:SetVertexColor(0.3, 1, 0.3)
  arrow.glow:SetVertexColor(0.3, 1, 0.3)
  arrow.glow:SetAlpha(0.5 + 0.3 * math.sin(GetTime() * 5))
  arrow.dist:SetText('|cff55ff55Vardın!|r')
  arrow.eta:SetText('')
 else
  local facing = GetPlayerFacing and GetPlayerFacing()
  local r, g, b = color[1], color[2], color[3]
  if facing then
   local rotation = FT.Bearing(dx, dy, facing)
   arrow.tex:SetRotation(rotation)
   -- yönelim doğruluğu: karşıya bakınca yeşil, ters yöndeyken kırmızı
   local error = math.abs(((rotation + math.pi) % (2 * math.pi)) - math.pi)
   local accuracy = 1 - error / math.pi
   if accuracy >= 0.5 then
    local t = (accuracy - 0.5) * 2
    r, g, b = 1 - 0.7 * t, 0.85 + 0.15 * t, 0.2 + 0.1 * t
   else
    local t = accuracy * 2
    r, g, b = 1, 0.3 + 0.55 * t, 0.3 - 0.1 * t
   end
  end
  local mode = ForeverTrailSettings.c_arrowColor or 'yon'
  if mode == 'tema' then local a = FT.Style.accent; r, g, b = a[1], a[2], a[3]
  elseif mode == 'tur' then r, g, b = color[1], color[2], color[3] end
  arrow.tex:SetAlpha(1)
  arrow.tex:SetVertexColor(r, g, b)
  arrow.glow:SetVertexColor(r, g, b)
  arrow.glow:SetAlpha(0.35 + 0.2 * math.sin(GetTime() * 3))
  arrow.dist:SetText(('%d yd'):format(dist + 0.5))
  arrow.eta:SetText(FT.FormatETA(dist / travelSpeed()))
 end
 if not arrow:IsShown() then arrow:Show() end
end

function FT.ToggleArrow()
 ForeverTrailSettings.arrow = ForeverTrailSettings.arrow == false
 FT.Print(ForeverTrailSettings.arrow == false and 'Yön oku kapatıldı.' or 'Yön oku açıldı.')
 FT.UpdateArrow()
end

function FT.CreateArrow()
 if arrow then return end
 arrow = CreateFrame('Frame', 'ForeverTrailArrow', UIParent)
 FT.arrow = arrow
 arrow:SetSize(150, 142)
 if FT.SoftBackdrop then pcall(FT.SoftBackdrop, arrow) end
 arrow:SetScale(ForeverTrailSettings.arrowScale or 1)
 arrow:SetMovable(true)
 arrow:EnableMouse(true)
 arrow:SetClampedToScreen(true)
 arrow:RegisterForDrag('LeftButton')
 arrow:SetScript('OnDragStart', function(self)
  if ForeverTrailSettings.arrowLocked or ForeverTrailSettings.locked then return end
  self.dragged = true
  self:StartMoving()
 end)
 arrow:SetScript('OnMouseUp', function(self, button)
  if self.dragged then self.dragged = nil; return end
  if button == 'LeftButton' and FT.OpenMap then FT.OpenMap()
  elseif button == 'RightButton' and FT.SelectNearest then FT.SelectNearest() end
 end)
 arrow:SetScript('OnEnter', function(self)
  GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
  GameTooltip:SetText('ForeverTrail', 1, 0.85, 0.5)
  GameTooltip:AddLine('Sol tık: haritayı aç', 1, 1, 1)
  GameTooltip:AddLine('Sağ tık: en yakın adıma geç', 1, 1, 1)
  GameTooltip:AddLine(ForeverTrailSettings.arrowLocked and 'Kilitli (/ftrail kilit)' or 'Sürükle: taşı  |  /ftrail kilit: kilitle', 0.7, 0.7, 0.7)
  FT.ShowTip(GameTooltip)
 end)
 arrow:SetScript('OnLeave', function() GameTooltip:Hide() end)
 arrow:SetScript('OnDragStop', function(self)
  self:StopMovingOrSizing()
  local point, _, relative, x, y = self:GetPoint()
  ForeverTrailSettings.arrowPoint = {point, relative, x, y}
 end)
 local p = ForeverTrailSettings.arrowPoint
 if p and p[1] and p[2] and p[3] and p[4] then arrow:SetPoint(p[1], UIParent, p[2], p[3], p[4])
 else arrow:SetPoint('TOP', UIParent, 'TOP', 0, -140) end
 arrow.title = arrow:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
 arrow.title:SetPoint('TOP', 0, -9)
 arrow.title:SetWidth(134); arrow.title:SetHeight(12); arrow.title:SetMaxLines(1)
 arrow.glow = arrow:CreateTexture(nil, 'BACKGROUND')
 arrow.glow:SetTexture('Interface\\Cooldown\\star4'); arrow.glow:SetBlendMode('ADD')
 arrow.glow:SetSize(84, 84); arrow.glow:SetPoint('TOP', 0, -20)
 arrow.tex = arrow:CreateTexture(nil, 'ARTWORK')
 arrow.tex:SetSize(54, 54)
 arrow.tex:SetPoint('CENTER', arrow.glow, 'CENTER')
 arrow.tex:SetTexture('Interface\\Minimap\\ROTATING-MINIMAPARROW')
 arrow.dist = arrow:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
 arrow.dist:SetPoint('BOTTOM', 0, 38)
 arrow.eta = arrow:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 arrow.eta:SetPoint('BOTTOM', 0, 23)
 arrow.eta:SetWidth(140)
 arrow.coords = arrow:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 arrow.coords:SetPoint('BOTTOM', 0, 9)
 arrow.coords:SetTextColor(0.7, 0.66, 0.58)
 arrow.eta:SetTextColor(0.8, 0.74, 0.64)
 for _, text in ipairs({arrow.title, arrow.dist, arrow.eta, arrow.coords}) do
  local path, size = text:GetFont()
  if path and size then text:SetFont(WOWTR_Font2 or path, size, 'OUTLINE') end
 end
 arrow:Hide()
 driver = CreateFrame('Frame')
 FT.arrowDriver = driver
 local elapsed = 0
 driver:SetScript('OnUpdate', function(_, dt)
  elapsed = elapsed + dt
  if elapsed >= 0.05 then elapsed = 0; FT.UpdateArrow() end
 end)
end
