local _, FT = ...

-- Forever'a özel yeni görevler, uçuş süreleri, Leatrix tarzı kolaylıklar, bilgi çubuğu,
-- eğitmen hatırlatıcısı ve A'dan B'ye rota planı.

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function optIn(key) return ForeverTrailSettings and ForeverTrailSettings[key] == true end
local function after(t, fn) if C_Timer and C_Timer.After then C_Timer.After(t, fn) else fn() end end
local function combat() return InCombatLockdown and InCombatLockdown() end

----------------------------------------------------------------------
-- 1) Forever'a özel yeni görevler
----------------------------------------------------------------------
function FT.IsNewQuest(id) return FT.DBNewQuests and id and FT.DBNewQuests[id] == true end
FT.NEW_TAG = '|cff6fd8ffYeni|r'

----------------------------------------------------------------------
-- 2) Uçuş süreleri: uçtukça öğren, uçarken kalan süreyi göster
----------------------------------------------------------------------
local flight
local function times()
 ForeverTrailSettings.flightTimes = ForeverTrailSettings.flightTimes or {}
 return ForeverTrailSettings.flightTimes
end
local function currentNode()
 if not (NumTaxiNodes and TaxiNodeGetType and TaxiNodeName) then return nil end
 for i = 1, NumTaxiNodes() do if TaxiNodeGetType(i) == 'CURRENT' then return TaxiNodeName(i) end end
end
function FT.FlightTime(from, to)
 return from and to and times()[from .. ' > ' .. to]
end

local bar
local function ensureBar()
 if bar then return bar end
 bar = CreateFrame('Frame', 'ForeverTrailFlightBar', UIParent)
 bar:SetSize(280, 34); bar:SetPoint('TOP', UIParent, 'TOP', 0, -100)
 if FT.SoftBackdrop then pcall(FT.SoftBackdrop, bar) end
 bar.text = bar:CreateFontString(nil, 'OVERLAY'); bar.text:SetPoint('TOP', 0, -5)
 bar.text:SetFont(FT.FontPath(), 12, 'OUTLINE')
 bar.bg = bar:CreateTexture(nil, 'ARTWORK'); bar.bg:SetPoint('BOTTOMLEFT', 8, 6); bar.bg:SetPoint('BOTTOMRIGHT', -8, 6); bar.bg:SetHeight(5); bar.bg:SetColorTexture(1, 1, 1, 0.12)
 bar.fill = bar:CreateTexture(nil, 'OVERLAY'); bar.fill:SetPoint('LEFT', bar.bg, 'LEFT'); bar.fill:SetHeight(5)
 bar:Hide()
 return bar
end

local function startFlight(index)
 if not (TaxiNodeName and index) then return end
 flight = {from=currentNode(), to=TaxiNodeName(index), start=GetTime(), seenTaxi=false}
end
if hooksecurefunc and TakeTaxiNode then pcall(hooksecurefunc, 'TakeTaxiNode', startFlight) end

local function updateFlight()
 if not flight then if bar then bar:Hide() end return end
 local onTaxi = UnitOnTaxi and UnitOnTaxi('player')
 if onTaxi then flight.seenTaxi = true end
 if flight.seenTaxi and not onTaxi then
  local dur = GetTime() - flight.start
  if flight.from and flight.to and dur > 5 then times()[flight.from .. ' > ' .. flight.to] = math.floor(dur + 0.5) end
  flight = nil
  if bar then bar:Hide() end
  return
 end
 if not flight.seenTaxi and GetTime() - flight.start > 10 then flight = nil; return end
 if not on('flighttimes') then return end
 local b = ensureBar()
 local a = FT.Style.accent
 local known = FT.FlightTime(flight.from, flight.to)
 local spent = GetTime() - flight.start
 if known then
  local left = math.max(0, known - spent)
  b.text:SetText(('%s  |cff9aa0a6kalan %d:%02d|r'):format(flight.to or '?', left / 60, left % 60))
  b.fill:SetWidth(math.max(1, (b.bg:GetWidth() or 260) * math.min(1, spent / known)))
 else
  b.text:SetText(('%s  |cff9aa0a6süre öğreniliyor (%d sn)|r'):format(flight.to or '?', spent))
  b.fill:SetWidth(1)
 end
 b.fill:SetColorTexture(a[1], a[2], a[3], 1)
 b:Show()
end

-- Uçuş haritasında ipucuna süre ekle
if hooksecurefunc and TaxiNodeOnButtonEnter then
 pcall(hooksecurefunc, 'TaxiNodeOnButtonEnter', function(button)
  local index = button and button.GetID and button:GetID()
  local t = index and FT.FlightTime(currentNode(), TaxiNodeName(index))
  if t then GameTooltip:AddLine(('ForeverTrail: uçuş %d:%02d'):format(t / 60, t % 60), 0.6, 0.85, 1); GameTooltip:Show() end
 end)
end

----------------------------------------------------------------------
-- 3) Leatrix tarzı kolaylıklar (hepsi Ayarlar > Kolaylık'tan açılır)
----------------------------------------------------------------------
local function inGuild(name)
 if not (IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then return false end
 for i = 1, GetNumGuildMembers() do
  local member = GetGuildRosterInfo(i)
  if member and (member == name or member:match('^([^-]+)') == name) then return true end
 end
 return false
end

function FT.ApplyCamera()
 if not SetCVar or combat() then return end
 if optIn('maxcamera') then pcall(SetCVar, 'cameraDistanceMaxZoomFactor', '2.6') end
 if optIn('noglow') then pcall(SetCVar, 'ffxGlow', '0') end
end

----------------------------------------------------------------------
-- 4) Bilgi çubuğu
----------------------------------------------------------------------
local info
local function money(c)
 c = math.floor(math.abs(c or 0))
 if c >= 10000 then return ('%dg %ds'):format(c / 10000, (c % 10000) / 100) end
 if c >= 100 then return ('%ds %dc'):format(c / 100, c % 100) end
 return c .. 'c'
end

local function infoText()
 local parts = {}
 local s = FT.SessionStats and FT.SessionStats()
 local level, xp, max = UnitLevel('player'), UnitXP('player'), UnitXPMax('player')
 if s and s.start then
  local hours = math.max(1 / 60, (GetTime() - s.start) / 3600)
  local rate = s.xp / hours
  parts[#parts + 1] = ('|cffffd100XP/sa|r %d'):format(rate)
  if rate > 0 and max and max > 0 then parts[#parts + 1] = ('|cffffd100Sv %d|r %d dk'):format(level + 1, (max - xp) / rate * 60) end
  local gold = GetMoney() - (s.money or GetMoney())
  parts[#parts + 1] = ('|cffffd100Altın/sa|r %s%s'):format(gold < 0 and '-' or '', money(gold / hours))
 end
 local rested = GetXPExhaustion and GetXPExhaustion()
 if rested and rested > 0 and max and max > 0 then parts[#parts + 1] = ('|cff6fb7ffDinlenmiş|r %%%d'):format(rested / max * 100) end
 local lowest = 1
 for slot = 1, 18 do
  local cur, mx = GetInventoryItemDurability and GetInventoryItemDurability(slot)
  if cur and mx and mx > 0 then lowest = math.min(lowest, cur / mx) end
 end
 local dc = lowest < 0.25 and '|cffff5555' or (lowest < 0.5 and '|cffffd100' or '|cff55ff55')
 parts[#parts + 1] = ('Dayanıklılık %s%%%d|r'):format(dc, lowest * 100)
 local free = 0
 for bag = 0, NUM_BAG_SLOTS or 4 do
  local fn = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  local n = fn and fn(bag)
  if type(n) == 'number' then free = free + n end
 end
 parts[#parts + 1] = ('Çanta %s%d|r'):format(free <= 2 and '|cffff5555' or '|cffffffff', free)
 local kills, avg = FT.KillsToLevel and FT.KillsToLevel()
 if kills then parts[#parts + 1] = ('|cffffd100Seviyeye|r ~%d yaratık'):format(kills) end
 return table.concat(parts, '   ')
end

local function ensureInfo()
 if info then return info end
 info = CreateFrame('Frame', 'ForeverTrailInfoBar', UIParent)
 info:SetSize(520, 20)
 local p = ForeverTrailSettings.infoPoint
 if p and p[1] then info:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else info:SetPoint('TOP', UIParent, 'TOP', 0, -2) end
 info:SetMovable(true); info:EnableMouse(true); info:RegisterForDrag('LeftButton'); info:SetClampedToScreen(true)
 info:SetScript('OnDragStart', function(self) if not ForeverTrailSettings.locked then self:StartMoving() end end)
 info:SetScript('OnDragStop', function(self)
  self:StopMovingOrSizing()
  local point, _, relative, x, y = self:GetPoint()
  ForeverTrailSettings.infoPoint = {point, relative, x, y}
 end)
 info.bg = info:CreateTexture(nil, 'BACKGROUND'); info.bg:SetAllPoints(); info.bg:SetColorTexture(0, 0, 0, 0.45)
 info.line = info:CreateTexture(nil, 'BORDER'); info.line:SetPoint('BOTTOMLEFT'); info.line:SetPoint('BOTTOMRIGHT'); info.line:SetHeight(1)
 if FT.RegisterAccent then FT.RegisterAccent(info.line, 0.8) end
 info.text = info:CreateFontString(nil, 'OVERLAY'); info.text:SetPoint('CENTER'); info.text:SetFont(FT.FontPath(), 11, '')
 info.text:SetShadowOffset(1, -1)
 info:SetScript('OnEnter', function(self)
  GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM')
  GameTooltip:SetText('ForeverTrail bilgi çubuğu', 1, 0.85, 0.5)
  GameTooltip:AddLine('Sürükle: taşı. Ayarlar > Görünüm > Bilgi çubuğu ile kapat.', 1, 1, 1, true)
  FT.ShowTip(GameTooltip)
 end)
 info:SetScript('OnLeave', function() GameTooltip:Hide() end)
 return info
end

local function updateInfo()
 if not on('infobar') or optIn('simple') then if info then info:Hide() end return end
 local f = ensureInfo()
 f.text:SetText(infoText())
 f:SetWidth(math.max(300, (f.text:GetStringWidth() or 400) + 24))
 f:Show()
end
FT.UpdateInfoBar = updateInfo

----------------------------------------------------------------------
-- 5) Eğitmen hatırlatıcısı
----------------------------------------------------------------------
local function spells()
 ForeverTrailCharacter.trainer = ForeverTrailCharacter.trainer or {}
 return ForeverTrailCharacter.trainer
end

local function scanTrainer()
 if IsTradeskillTrainer and IsTradeskillTrainer() then return end
 if not (GetNumTrainerServices and GetTrainerServiceInfo) then return end
 local list = {}
 for i = 1, GetNumTrainerServices() do
  local name, rank, state = GetTrainerServiceInfo(i)
  local req = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
  local cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
  if name and state ~= 'used' and state ~= 'header' then list[#list + 1] = {name=name, rank=rank, level=req, cost=cost} end
 end
 ForeverTrailCharacter.trainer = list
end

local function classTrainer()
 local _, token = UnitClass('player')
 local cls = token and (token:sub(1, 1) .. token:sub(2):lower()) or ''
 local want = cls .. ' Trainer'
 local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
 local pos = map and C_Map.GetPlayerMapPosition(map, 'player')
 local px, py = 0.5, 0.5
 if pos then px, py = pos:GetXY() end
 local z = FT.Module and FT.Module('ZoneDB')
 local best, bd
 for id, n in pairs(FT.DBN or {}) do
  if n[11] == want and type(n[5]) == 'table' and z then
   for area, list in pairs(n[5]) do
    local ui = z:GetUiMapIdByAreaId(area)
    if ui and list[1] then
     local x, y = list[1] / 1000, list[2] / 1000
     local d = (ui == map) and ((x - px) ^ 2 + (y - py) ^ 2) or (10 + (x - px) ^ 2)
     if not bd or d < bd then best, bd = {map=ui, x=x, y=y, name=n[1]}, d end
    end
   end
  end
 end
 return best
end
FT.ClassTrainer = classTrainer

function FT.TrainerCheck(level)
 if not on('trainerremind') then return end
 level = level or UnitLevel('player')
 local count, cost = 0, 0
 for _, s in ipairs(spells()) do
  if s.level and s.level > 0 and s.level <= level then count, cost = count + 1, cost + (s.cost or 0) end
 end
 if count == 0 then return end
 local t = classTrainer()
 local text = ('Eğitmende %d yeni yetenek var (toplam %s).'):format(count, money(cost))
 if t and FT.ShowChoice and FT.ShowChoice('Yeni yetenekler', 'Interface\\Icons\\INV_Misc_Book_09', text .. '\nEğitmen: ' .. t.name, 'Yol göster',
  function() FT.SetCustomTarget(t.map, t.x, t.y, t.name) end) then return end
 FT.Alert(text, true)
end

----------------------------------------------------------------------
-- 6) A'dan B'ye rota planı
----------------------------------------------------------------------
local CONTINENT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2
local function continentOf(map)
 local guard = 0
 while map and guard < 10 do
  local mi = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  if not mi then return nil end
  if mi.mapType == CONTINENT then return map end
  map = mi.parentMapID; guard = guard + 1
 end
end

function FT.RoutePlan(target)
 target = target or (FT.TargetStep and FT.TargetStep())
 local steps = {}
 if not (target and target.uiMapID and C_Map and C_Map.GetBestMapForUnit) then return steps end
 local map = C_Map.GetBestMapForUnit('player')
 local name = FT.MapName and FT.MapName(target.uiMapID) or '?'
 local label = target.questTitle or target.text or 'Hedef'
 if FT.MapAncestor and map and FT.MapAncestor(map, target.uiMapID) then steps[#steps + 1] = 'Bulunduğun yerden dışarı çık.' end
 local from, to = map and continentOf(map), continentOf(target.uiMapID)
 if from and to and from ~= to then
  local goal, text = nil, nil
  if FT.TravelHint then goal, text = FT.TravelHint(map, target) end
  steps[#steps + 1] = goal and goal.hint or text or 'Diğer kıtaya geç.'
  steps[#steps + 1] = ('%s kıtasına varınca en yakın uçuş noktasına git.'):format(FT.MapName and FT.MapName(to) or '')
 elseif map ~= target.uiMapID and FT.FlightPlan then
  local plan = FT.FlightPlan(map, target)
  if plan then
   steps[#steps + 1] = plan.hint
   local from, to2 = plan.hint:match('Uçuş: (.-) → (.+)')
   local t = FT.FlightTime(from, to2)
   if t then steps[#steps] = steps[#steps] .. (' (%d:%02d)'):format(t / 60, t % 60) end
  else
   steps[#steps + 1] = ('%s bölgesine yürüyerek ya da binekle git.'):format(name)
  end
 end
 if FT.EntranceTo and map then
  local e = FT.EntranceTo(target.uiMapID ~= map and target.uiMapID or map, target.uiMapID)
  if e then steps[#steps + 1] = e.hint end
 end
 steps[#steps + 1] = ('%s: %s (%.1f, %.1f)'):format(name, label, (target.x or 0) * 100, (target.y or 0) * 100)
 return steps
end

function FT.ShowRoutePlan()
 local steps = FT.RoutePlan()
 if #steps == 0 then return FT.InfoWindow('Rota planı', {'Önce bir hedef seç (panel, Yol sor ya da haritada Ctrl+tık).'}) end
 local lines = {}
 for i, s in ipairs(steps) do lines[#lines + 1] = ('|cffffd100%d.|r %s'):format(i, s) end
 lines[#lines + 1] = ' '
 lines[#lines + 1] = '|cff9aa0a6Ok her adımda bir sonraki noktayı gösterir.|r'
 FT.InfoWindow('Rota planı', lines)
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local events = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_LOGIN', 'CONFIRM_SUMMON', 'RESURRECT_REQUEST', 'DUEL_REQUESTED', 'TRAINER_SHOW', 'TRAINER_UPDATE',
 'PLAYER_LEVEL_UP', 'PLAYER_REGEN_ENABLED'}) do pcall(events.RegisterEvent, events, e) end
events:SetScript('OnEvent', function(_, event, a)
 local ok, err = pcall(function()
  if event == 'PLAYER_LOGIN' then after(2, FT.ApplyCamera); after(3, updateInfo)
  elseif event == 'CONFIRM_SUMMON' and optIn('autosummon') and not combat() then
   after(1, function()
    if C_SummonInfo and C_SummonInfo.ConfirmSummon then C_SummonInfo.ConfirmSummon() elseif ConfirmSummon then ConfirmSummon() end
    if StaticPopup_Hide then StaticPopup_Hide('CONFIRM_SUMMON') end
   end)
  elseif event == 'RESURRECT_REQUEST' and optIn('autorez') then
   if AcceptResurrect then AcceptResurrect() end
   if StaticPopup_Hide then StaticPopup_Hide('RESURRECT') end
  elseif event == 'DUEL_REQUESTED' and optIn('blockduels') and not inGuild(a) then
   if CancelDuel then CancelDuel() end
   if StaticPopup_Hide then StaticPopup_Hide('DUEL_REQUESTED') end
   FT.Print(('%s düello istedi, reddedildi (lonca dışı).'):format(a or '?'))
  elseif event == 'TRAINER_SHOW' or event == 'TRAINER_UPDATE' then scanTrainer()
  elseif event == 'PLAYER_LEVEL_UP' then after(3, function() FT.TrainerCheck(a) end)
  elseif event == 'PLAYER_REGEN_ENABLED' then FT.ApplyCamera() end
 end)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'toolbox: ' .. tostring(err) end
end)
local acc, accInfo = 0, 0
events:SetScript('OnUpdate', function(_, dt)
 acc, accInfo = acc + dt, accInfo + dt
 if acc >= 0.25 then acc = 0; pcall(updateFlight) end
 if accInfo >= 2 then accInfo = 0; pcall(updateInfo) end
end)
