local _, FT = ...

-- Yolculuk kartı: seçtiğin yer başka bir bölgedeyse oraya giden adımları simgelerle (uçuş, zeplin, gemi, yürüyüş, giriş/çıkış, varış)
-- ve akan noktalarla gösterir. Sohbete yazmaz. Aynı bölgeye gelince kendiliğinden kapanır; ok, mini harita ve harita çizgisi devralır.
-- Adımlar FT.RoutePlan'dan gelir ve bulunduğun yere göre yeniden hesaplanır; bu yüzden ilk adım her zaman "şimdi yapılacak" olandır.

local WIDTH, HEAD_H, ROW_H, FOOT_H, MAX_ROWS = 340, 54, 50, 34, 6
local BADGE, BADGE_X = 30, 14
local ICON = {['UÇUŞ'] = 'flight', ['ZEPLİN'] = 'zeppelin', ['GEMİ'] = 'ship', ['YÜRÜ'] = 'walk', ['ÇIKIŞ'] = 'door', ['GİRİŞ'] = 'door', ['VARIŞ'] = 'flag', ['ADIM'] = 'step'}
local MEDIA = 'Interface\\AddOns\\ForeverTrail\\Media\\route_'

local card, rowsUI, dots, driver
local plan, planKey, dismissed
local t, appear = 0, 0

local function accent() return FT.Kit.Color('accent') end

local function playerMap()
 if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
 local ok, map = pcall(C_Map.GetBestMapForUnit, 'player')
 return ok and map or nil
end

-- Kart gösterilmeli mi? Hedef özel bir nokta ve başka bölgede olmalı.
local function wanted()
 local target = FT.customTarget
 if not target or not target.uiMapID or ForeverTrailSettings.routeCard == false or dismissed == target then return false end
 local map = playerMap()
 return map ~= nil and map ~= target.uiMapID
end

local function buildPlan()
 local target = FT.customTarget
 local steps = FT.RoutePlan and FT.RoutePlan(target) or {}
 local out, total = {}, 0
 for i, text in ipairs(steps) do
  if i > MAX_ROWS then break end
  local clean, seconds = text, nil
  if FT.JourneySplitTime then clean, seconds = FT.JourneySplitTime(text) end
  local label, color = 'ADIM', {0.67, 0.7, 0.76}
  if FT.JourneyClassify then label, color = FT.JourneyClassify(clean, i == #steps) end
  if seconds then total = total + seconds end
  out[#out + 1] = {text = clean, seconds = seconds, label = label, color = color, icon = ICON[label] or 'step'}
 end
 return out, total
end

local function newRow(i)
 local K = FT.Kit
 local r = CreateFrame('Frame', nil, card)
 r:SetHeight(ROW_H)
 r.bar = r:CreateTexture(nil, 'BACKGROUND'); r.bar:SetWidth(2); r.bar:SetPoint('TOPLEFT', 0, -4); r.bar:SetPoint('BOTTOMLEFT', 0, 4)
 r.glow = r:CreateTexture(nil, 'ARTWORK'); r.glow:SetTexture('Interface\\Cooldown\\star4'); r.glow:SetBlendMode('ADD'); r.glow:SetSize(BADGE + 14, BADGE + 14)
 r.glow:SetPoint('CENTER', r, 'TOPLEFT', BADGE_X + BADGE / 2, -(8 + BADGE / 2))
 r.badge = r:CreateTexture(nil, 'ARTWORK', nil, 1); r.badge:SetSize(BADGE, BADGE); r.badge:SetPoint('TOPLEFT', BADGE_X, -8)
 r.icon = r:CreateTexture(nil, 'OVERLAY'); r.icon:SetSize(BADGE - 8, BADGE - 8); r.icon:SetPoint('CENTER', r.badge, 'CENTER', 0, 0)
 r.kind = K.Text(r, 10, 'muted'); r.kind:SetPoint('TOPLEFT', 56, -8); r.kind:SetJustifyH('LEFT')
 r.text = K.Text(r, 12, 'text'); r.text:SetPoint('TOPLEFT', 56, -22); r.text:SetPoint('RIGHT', r, 'RIGHT', -60, 0); r.text:SetJustifyH('LEFT'); r.text:SetJustifyV('TOP'); r.text:SetWordWrap(true)
 r.time = K.Text(r, 11, 'muted'); r.time:SetPoint('TOPRIGHT', -12, -9); r.time:SetJustifyH('RIGHT')
 rowsUI[i] = r
 return r
end

local function layout()
 local n = #plan
 local K = FT.Kit
 local a = accent()
 for i = 1, math.max(n, #rowsUI) do
  local r = rowsUI[i] or (i <= n and newRow(i))
  if r then
   local s = plan[i]
   if s then
    r:ClearAllPoints(); r:SetPoint('TOPLEFT', card, 'TOPLEFT', 0, -(HEAD_H + (i - 1) * ROW_H)); r:SetPoint('RIGHT', card, 'RIGHT', 0, 0)
    r.icon:SetTexture(MEDIA .. s.icon)
    local c = s.color
    r.badge:SetColorTexture(c[1], c[2], c[3], i == 1 and 0.28 or 0.14)
    r.icon:SetVertexColor(c[1], c[2], c[3], i == 1 and 1 or 0.75)
    r.glow:SetVertexColor(c[1], c[2], c[3], 1)
    r.kind:SetText(i == 1 and ('ŞİMDİ  ·  ' .. s.label) or s.label)
    local kc = i == 1 and a or K.Color('muted')
    r.kind:SetTextColor(kc[1], kc[2], kc[3])
    r.text:SetText(s.text)
    local tc = K.Color(i == 1 and 'text' or 'muted'); r.text:SetTextColor(tc[1], tc[2], tc[3])
    r.time:SetText(s.seconds and ('%d:%02d'):format(math.floor(s.seconds / 60), s.seconds % 60) or '')
    r.bar:SetColorTexture(a[1], a[2], a[3], i == 1 and 0.9 or 0)
    r.glow:SetShown(i == 1)
    r:Show()
   else r:Hide() end
  end
 end
 card:SetHeight(HEAD_H + n * ROW_H + FOOT_H)
end

local function refresh(force)
 if not card then return end
 if not wanted() then
  if card:IsShown() then card:Hide() end
  plan, planKey = nil, nil
  return
 end
 local target = FT.customTarget
 local key = tostring(playerMap()) .. ':' .. tostring(target.uiMapID) .. ':' .. tostring(target.x) .. ':' .. tostring(target.y) .. ':' .. tostring(target.text)
 if key ~= planKey or force then
  planKey = key
  local total
  plan, total = buildPlan()
  card.title:SetText(target.questTitle or target.text or 'Hedef')
  local zone = FT.MapName and FT.MapName(target.uiMapID) or ''
  card.sub:SetText((zone ~= '' and zone or '?') .. '  ·  başka bölgede')
  local summary = {('%d adım'):format(#plan)}
  if total and total > 0 then summary[#summary + 1] = ('uçuş ~%d dk'):format(math.max(1, math.floor(total / 60 + 0.5))) end
  card.foot:SetText(table.concat(summary, '  ·  '))
  layout()
 end
 if not card:IsShown() then appear = 0; card:Show() end
end

-- kart açıkken her karede: açılış animasyonu, nabız atan simge, akan noktalar
local function animate(dt)
 t = t + dt
 appear = math.min(1, appear + dt / 0.35)
 local e = 1 - (1 - appear) * (1 - appear)
 card:SetAlpha(e)
 if card.basePoint then
  card:ClearAllPoints()
  card:SetPoint(card.basePoint[1], UIParent, card.basePoint[2], card.basePoint[3], card.basePoint[4] + (1 - e) * 14)
 end
 local n = plan and #plan or 0
 local a = accent()
 for i = 1, n do
  local r = rowsUI[i]
  if r and i == 1 then
   local w = math.sin(t * 3.2)
   r.glow:SetAlpha(0.55 + 0.35 * w)
   local size = BADGE + 12 + 6 * w
   r.glow:SetSize(size, size)
   r.icon:ClearAllPoints(); r.icon:SetPoint('CENTER', r.badge, 'CENTER', 0, 1.2 * math.sin(t * 2.4))
  end
 end
 -- bağlantı çizgisi: simgeler arasında aşağı akan noktalar
 local used = 0
 for i = 1, n - 1 do
  local top = HEAD_H + (i - 1) * ROW_H + 8 + BADGE + 2
  local gap = ROW_H - BADGE - 4
  for k = 0, 2 do
   used = used + 1
   local d = dots[used]
   if not d then
    d = card:CreateTexture(nil, 'ARTWORK'); d:SetTexture('Interface\\Buttons\\WHITE8X8'); d:SetSize(3, 3)
    dots[used] = d
   end
   local phase = ((t * 0.9) + k / 3) % 1
   d:ClearAllPoints(); d:SetPoint('CENTER', card, 'TOPLEFT', BADGE_X + BADGE / 2, -(top + gap * phase))
   local fade = math.sin(phase * math.pi)
   d:SetVertexColor(a[1], a[2], a[3], (i == 1 and 0.95 or 0.45) * fade)
   d:Show()
  end
 end
 for i = used + 1, #dots do dots[i]:Hide() end
end

local function build()
 local K = FT.Kit
 card = CreateFrame('Frame', 'ForeverTrailRouteCard', UIParent)
 FT.routeCard = card
 rowsUI, dots, plan = {}, {}, {}
 card:SetSize(WIDTH, HEAD_H + FOOT_H)
 card:SetFrameStrata('HIGH'); card:SetClampedToScreen(true)
 card:SetMovable(true); card:EnableMouse(true); card:RegisterForDrag('LeftButton')
 local p = ForeverTrailSettings.routeCardPoint
 card.basePoint = (p and p[1] and p[2] and p[3] and p[4]) and {p[1], p[2], p[3], p[4]} or {'TOP', 'TOP', 0, -140}
 card:SetPoint(card.basePoint[1], UIParent, card.basePoint[2], card.basePoint[3], card.basePoint[4])
 card:SetScript('OnDragStart', function(self) self:StartMoving() end)
 card:SetScript('OnDragStop', function(self)
  self:StopMovingOrSizing()
  local point, _, relative, x, y = self:GetPoint()
  if point then ForeverTrailSettings.routeCardPoint = {point, relative, x, y}; self.basePoint = {point, relative, x, y} end
 end)
 K.Skin(card, 'mid', 'line')
 -- başlık
 card.flag = card:CreateTexture(nil, 'OVERLAY'); card.flag:SetSize(22, 22); card.flag:SetPoint('TOPLEFT', 14, -12)
 card.flag:SetTexture(MEDIA .. 'flag')
 local a = accent(); card.flag:SetVertexColor(a[1], a[2], a[3], 1)
 card.title = K.Text(card, 14, 'text'); card.title:SetPoint('TOPLEFT', 44, -10); card.title:SetPoint('RIGHT', card, 'RIGHT', -40, 0); card.title:SetJustifyH('LEFT'); card.title:SetWordWrap(false)
 card.sub = K.Text(card, 11, 'muted'); card.sub:SetPoint('TOPLEFT', 44, -29); card.sub:SetJustifyH('LEFT')
 card.close = K.CloseButton(card, function() dismissed = FT.customTarget; refresh() end)
 card.close:SetPoint('TOPRIGHT', -4, -4)
 local rule = K.Divider(card); rule:SetPoint('TOPLEFT', 1, -(HEAD_H - 2)); rule:SetPoint('TOPRIGHT', -1, -(HEAD_H - 2))
 -- alt: özet ve hedefi kaldır
 card.foot = K.Text(card, 11, 'muted'); card.foot:SetPoint('BOTTOMLEFT', 14, 11); card.foot:SetJustifyH('LEFT')
 local cancel = K.Button(card, 'Hedefi kaldır', 96, 22); cancel:SetPoint('BOTTOMRIGHT', -10, 6)
 cancel:SetScript('OnClick', function() if FT.ClearCustomTarget then FT.ClearCustomTarget() end; refresh() end)
 card:SetScript('OnUpdate', function(_, dt) animate(dt) end)
 card:Hide()
 if FT.FixFonts then pcall(FT.FixFonts, card) end
end

function FT.RefreshRouteCard(force)
 if not card then
  if not (FT.Kit and FT.RoutePlan) then return end
  local ok, err = pcall(build)
  if not ok then card = nil; if FT.errors and #FT.errors < 20 then FT.errors[#FT.errors + 1] = 'routecard: ' .. tostring(err) end; return end
 end
 refresh(force)
end

-- Hedef değişince ya da bölge değişince kart güncellenir (yarım saniyede bir bakılır)
driver = CreateFrame('Frame')
local waited = 0
driver:SetScript('OnUpdate', function(_, dt)
 waited = waited + dt
 if waited < 0.5 then return end
 waited = 0
 if FT.customTarget or card then pcall(FT.RefreshRouteCard) end
end)

-- Test ve tanı için
function FT.RouteCardRows()
 local out = {}
 for i = 1, plan and #plan or 0 do out[#out + 1] = rowsUI[i] end
 return out
end
