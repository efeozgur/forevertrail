local _, FT = ...

-- Nadir yaratıklar: yakına gelince 3B görselli kart, dünya haritasında simgeler ve üzerine gelince görsel.
-- Dünya haritasını taşıma (üst kenardan sürükle, sağ tık: varsayılan yer).

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function font(fs, size, flags)
 if fs:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', size, flags or '') == false then fs:SetFont('Fonts\\ARIALN.TTF', size, flags or '') end
 fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.9)
end
local function combat() return InCombatLockdown and InCombatLockdown() end

local function newModel(parent, w, h)
 local ok, m = pcall(CreateFrame, 'PlayerModel', nil, parent)
 if not ok or not m then return nil end
 m:SetSize(w, h)
 return m
end
local function showCreature(model, id)
 if not model then return end
 if model.ClearModel then pcall(model.ClearModel, model) end
 pcall(model.SetCreature, model, id)
 if model.SetPortraitZoom then pcall(model.SetPortraitZoom, model, 0.2) end
 if model.SetCamDistanceScale then pcall(model.SetCamDistanceScale, model, 1.4) end
end

----------------------------------------------------------------------
-- 1) Uyarı kartı
----------------------------------------------------------------------
local card
local function ensureCard()
 if card then return card end
 card = FT.NewWindow('ForeverTrailRareCard', UIParent)
 card:SetSize(230, 260); card:SetPoint('RIGHT', UIParent, 'RIGHT', -260, 60); card:SetFrameStrata('HIGH')
 card:SetMovable(true); card:EnableMouse(true); card:RegisterForDrag('LeftButton')
 card:SetScript('OnDragStart', card.StartMoving); card:SetScript('OnDragStop', card.StopMovingOrSizing)
 card.head = card:CreateFontString(nil, 'OVERLAY'); font(card.head, 13, 'OUTLINE'); card.head:SetPoint('TOP', 0, -10)
 card.head:SetText('Nadir yaratık yakında!'); card.head:SetTextColor(0.8, 0.55, 1)
 card.bg = card:CreateTexture(nil, 'ARTWORK'); card.bg:SetPoint('TOPLEFT', 12, -30); card.bg:SetSize(206, 150); card.bg:SetColorTexture(0, 0, 0, 0.45)
 card.model = newModel(card, 204, 148)
 if card.model then card.model:SetPoint('TOPLEFT', 13, -31) end
 card.name = card:CreateFontString(nil, 'OVERLAY'); font(card.name, 14, 'OUTLINE'); card.name:SetPoint('TOP', 0, -186); card.name:SetWidth(210)
 card.info = card:CreateFontString(nil, 'OVERLAY'); font(card.info, 11, ''); card.info:SetPoint('TOP', card.name, 'BOTTOM', 0, -4); card.info:SetTextColor(0.85, 0.82, 0.75)
 local go = FT.NewButton(card, 'Yol göster', 96, 22); go:SetPoint('BOTTOMLEFT', 12, 10)
 go:SetScript('OnClick', function() local r = card.rare; if r then FT.SetCustomTarget(r.map, r.x, r.y, r.name) end end)
 local close = FT.NewButton(card, 'Kapat', 96, 22); close:SetPoint('BOTTOMRIGHT', -12, 10)
 close:SetScript('OnClick', function() card:Hide() end)
 card:SetScript('OnUpdate', function(self, dt) self.t = (self.t or 0) + dt; if self.t > 25 then self:Hide() end end)
 card:Hide()
 if FT.RegisterPopup then FT.RegisterPopup(card) end
 return card
end

function FT.ShowRareCard(r, dist)
 if not on('rarecard') or (FT.IsSilent and FT.IsSilent()) then return end
 local c = ensureCard()
 c.rare = r; c.t = 0
 c.name:SetText(r.name or '?')
 c.info:SetText(('Seviye %s · %d yd'):format(r.level or '?', dist or 0))
 if c.model then showCreature(c.model, r.id); c.bg:Show() end
 c:Show()
 if FT.FixFonts then pcall(FT.FixFonts, c) end
end

----------------------------------------------------------------------
-- 2) Dünya haritasında nadir yaratıklar + üzerine gelince görsel
----------------------------------------------------------------------
local rareDots = {}
FT.rareDots = rareDots
function FT.DrawRares(mapID)
 for _, d in ipairs(rareDots) do d:Hide() end
 local overlay = FT.mapParts and FT.mapParts.overlay
 if not (overlay and mapID and on('raremap') and FT.RaresOn) then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local used, placed = 0, {}
 for _, r in ipairs(FT.RaresOn(mapID)) do
  if used >= 80 then break end
  -- aynı yaratığın birbirine çok yakın doğma noktalarını tek simgede topla
  local near = false
  for _, p in ipairs(placed[r.id] or {}) do if math.abs(p[1] - r.x) < 0.03 and math.abs(p[2] - r.y) < 0.03 then near = true; break end end
  if not near then
  placed[r.id] = placed[r.id] or {}
  table.insert(placed[r.id], {r.x, r.y})
  used = used + 1
  local d = rareDots[used]
  if not d then d = overlay:CreateTexture(nil, 'OVERLAY'); d:SetTexture('Interface\\TargetingFrame\\UI-RaidTargetingIcon_8'); rareDots[used] = d end
  local sc = 13 * (FT.Scale and FT.Scale('mapIcons') or 1)
  d:SetSize(sc, sc)
  d:ClearAllPoints(); d:SetPoint('CENTER', overlay, 'TOPLEFT', r.x * w, -r.y * h)
  d.step = {x = r.x, y = r.y, uiMapID = mapID, questTitle = r.name, text = ('Nadir yaratık · seviye %s'):format(r.level or '?'), type = 'location', npcId = r.id}
  d:Show()
  end
 end
end

local tipModel
local function tipModelFor(id)
 if not (on('raremodel') and GameTooltip) then return end
 if not tipModel then
  tipModel = CreateFrame('Frame', nil, GameTooltip)
  tipModel:SetSize(140, 140)
  tipModel.bg = tipModel:CreateTexture(nil, 'BACKGROUND'); tipModel.bg:SetAllPoints(); tipModel.bg:SetColorTexture(0, 0, 0, 0.75)
  tipModel.m = newModel(tipModel, 136, 136)
  if tipModel.m then tipModel.m:SetPoint('CENTER') end
  GameTooltip:HookScript('OnHide', function() tipModel:Hide() end)
 end
 tipModel:ClearAllPoints(); tipModel:SetPoint('TOPLEFT', GameTooltip, 'BOTTOMLEFT', 0, -2)
 if tipModel.lastId ~= id then tipModel.lastId = id; showCreature(tipModel.m, id) end
 tipModel:Show()
end
FT.ShowTooltipModel = tipModelFor

----------------------------------------------------------------------
-- 3) Dünya haritasını taşıma
----------------------------------------------------------------------
local handle
local function applyMapPoint()
 local p = ForeverTrailSettings and ForeverTrailSettings.mapPoint
 if not (p and WorldMapFrame) or combat() or not on('mapmove') then return end
 WorldMapFrame:ClearAllPoints()
 WorldMapFrame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function installMover()
 if handle or not WorldMapFrame then return end
 handle = CreateFrame('Frame', nil, WorldMapFrame)
 handle:SetPoint('TOPLEFT', WorldMapFrame, 'TOPLEFT', 60, 0)
 handle:SetPoint('TOPRIGHT', WorldMapFrame, 'TOPRIGHT', -270, 0)
 handle:SetHeight(26)
 local top = type(WorldMapFrame.BorderFrame) == 'table' and WorldMapFrame.BorderFrame or WorldMapFrame
 handle:SetFrameStrata(top:GetFrameStrata())
 handle:SetFrameLevel(top:GetFrameLevel() + 20)
 -- kenarda sürükleme çubuğu görünsün
 handle.bar = handle:CreateTexture(nil, 'HIGHLIGHT')
 handle.bar:SetAllPoints(); handle.bar:SetColorTexture(1, 0.82, 0, 0.12)
 handle:EnableMouse(true)
 handle:SetScript('OnMouseDown', function(_, button)
  if button ~= 'LeftButton' or combat() or not on('mapmove') then return end
  WorldMapFrame:SetMovable(true)
  if WorldMapFrame.SetClampedToScreen then WorldMapFrame:SetClampedToScreen(true) end
  WorldMapFrame:StartMoving()
  handle.moving = true
 end)
 handle:SetScript('OnMouseUp', function(_, button)
  if button == 'RightButton' then
   if ForeverTrailSettings then ForeverTrailSettings.mapPoint = nil end
   FT.Print('Harita varsayılan yerine dönecek (haritayı kapatıp aç).')
   return
  end
  if not handle.moving then return end
  handle.moving = false
  WorldMapFrame:StopMovingOrSizing()
  local point, _, relPoint, x, y = WorldMapFrame:GetPoint()
  if point then ForeverTrailSettings.mapPoint = {point, relPoint, x, y} end
 end)
 handle:SetScript('OnEnter', function(self)
  GameTooltip:SetOwner(self, 'ANCHOR_TOP')
  GameTooltip:SetText('Haritayı taşı', 1, 0.82, 0)
  GameTooltip:AddLine('Sol tık basılı sürükle. Sağ tık: varsayılan yer.', 1, 1, 1, true)
  if FT.ShowTip then FT.ShowTip(GameTooltip) else GameTooltip:Show() end
 end)
 handle:SetScript('OnLeave', function() GameTooltip:Hide() end)
 WorldMapFrame:HookScript('OnShow', function() if C_Timer then C_Timer.After(0, applyMapPoint) else applyMapPoint() end end)
 -- oyun paneli yeniden yerleştirirse kayıtlı yere geri koy
 if UpdateUIPanelPositions then
  hooksecurefunc('UpdateUIPanelPositions', function()
   if WorldMapFrame:IsShown() and not handle.moving and ForeverTrailSettings and ForeverTrailSettings.mapPoint then
    if C_Timer then C_Timer.After(0, applyMapPoint) end
   end
  end)
 end
 -- Alt + sürükle: haritanın her yerinden taşı
 WorldMapFrame:HookScript('OnMouseDown', function(_, button)
  if button == 'LeftButton' and IsAltKeyDown and IsAltKeyDown() and on('mapmove') and not combat() then
   handle:GetScript('OnMouseDown')(handle, 'LeftButton')
  end
 end)
 WorldMapFrame:HookScript('OnMouseUp', function(_, button)
  if handle.moving then handle:GetScript('OnMouseUp')(handle, 'LeftButton') end
 end)
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local ev = CreateFrame('Frame')
ev:RegisterEvent('PLAYER_LOGIN')
ev:SetScript('OnEvent', function()
 local ok, err = pcall(installMover)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'rares: ' .. tostring(err) end
end)
