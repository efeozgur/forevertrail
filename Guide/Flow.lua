local _, FT = ...

-- Sürekli rota, nadir yaratık uyarısı, posta kutuları, kısayol tuşları, ses seçenekleri, karakter profilleri.

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function optIn(key) return ForeverTrailSettings and ForeverTrailSettings[key] == true end
local function after(t, fn) if C_Timer and C_Timer.After then C_Timer.After(t, fn) else fn() end end

----------------------------------------------------------------------
-- Ses seçenekleri: her olay için ayrı ses ve ses kanalı
----------------------------------------------------------------------
FT.SoundChoices = {
 {key='tamam', name='Görev tamam', kit='IG_QUEST_LIST_COMPLETE'},
 {key='zil', name='Zil', kit='READY_CHECK'},
 {key='ping', name='Harita sinyali', kit='MAP_PING'},
 {key='seviye', name='Seviye', kit='LEVELUP'},
 {key='tik', name='Tık', kit='IG_QUEST_LIST_SELECT'},
 {key='kapali', name='Kapalı'},
}
FT.SoundEvents = {
 {key='arrive', label='Hedefe varış', default='tamam'},
 {key='progress', label='Hedef ilerlemesi', default='tik'},
 {key='complete', label='Hedef tamamlandı', default='tamam'},
 {key='warn', label='Uyarılar (yaratık, nadir)', default='ping'},
}
local FALLBACK = {IG_QUEST_LIST_COMPLETE=878, READY_CHECK=8960, MAP_PING=3175, LEVELUP=888, IG_QUEST_LIST_SELECT=875}

function FT.PlayEventSound(event)
 if not ForeverTrailSettings or ForeverTrailSettings.sound == false or not PlaySound then return end
 local default
 for _, e in ipairs(FT.SoundEvents) do if e.key == event then default = e.default end end
 local choice = ForeverTrailSettings['snd_' .. event] or default or 'tamam'
 for _, s in ipairs(FT.SoundChoices) do
  if s.key == choice and s.kit then
   local id = (SOUNDKIT and SOUNDKIT[s.kit]) or FALLBACK[s.kit]
   if id then pcall(PlaySound, id, ForeverTrailSettings.snd_channel or 'Master') end
  end
 end
end

-- Eski ses çağrılarını yeni sisteme bağla
FT.PlayProgressSound = function() FT.PlayEventSound('progress') end
do
 local flash = FT.Alert
 FT.Alert = function(message, withSound)
  if FT.Flash then FT.Flash(message, 0.3, 1, 0.3) end
  FT.Print(message)
  if withSound then
   local event = (type(message) == 'string' and message:find('tamamlandı')) and 'complete' or 'arrive'
   FT.PlayEventSound(event)
  end
 end
end

----------------------------------------------------------------------
-- 1) Sürekli rota: bir hedef bitince sıradakine geç
----------------------------------------------------------------------
local pendingNext = false
local function continueRoute(reason)
 if not optIn('autonext') or pendingNext or not FT.SuggestNext then return end
 pendingNext = true
 after(1.5, function()
  pendingNext = false
  if InCombatLockdown and InCombatLockdown() then return end
  FT.autoRoute = true
  pcall(FT.SuggestNext)
 end)
end
FT.ContinueRoute = continueRoute

function FT.ToggleAutoRoute()
 ForeverTrailSettings.autonext = not optIn('autonext')
 FT.Print(optIn('autonext') and 'Sürekli rota açık: her hedef bitince ok sıradaki en verimli göreve geçer.' or 'Sürekli rota kapalı.')
 if optIn('autonext') then continueRoute() end
end

----------------------------------------------------------------------
-- 2) Nadir yaratıklar: minimapte simge, yaklaşınca uyarı
----------------------------------------------------------------------
local rareCache = {}
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() rareCache = {} end
local function raresOn(mapID)
 if rareCache[mapID] then return rareCache[mapID] end
 local out = {}
 local z = FT.Module and FT.Module('ZoneDB')
 for id, n in pairs(FT.DBN or {}) do
  if (n[4] == 2 or n[4] == 4) and type(n[5]) == 'table' and z then
   for area, list in pairs(n[5]) do
    if z:GetUiMapIdByAreaId(area) == mapID then
     for i = 1, #list - 1, 2 do out[#out + 1] = {id=id, name=n[1], level=n[3], x=list[i] / 1000, y=list[i + 1] / 1000} end
    end
   end
  end
 end
 rareCache[mapID] = out
 return out
end
FT.RaresOn = raresOn

local OUTDOOR = {[0]=233.33, 200, 166.67, 133.33, 100, 66.67}
local INDOOR = {[0]=150, 125, 100, 75, 50, 37.5}
local rarePins, rareWarned = {}, {}
local function updateRares()
 for _, p in ipairs(rarePins) do p:Hide() end
 if not (on('rares') and Minimap and C_Map and C_Map.GetBestMapForUnit) then return end
 local map = C_Map.GetBestMapForUnit('player')
 local pos = map and C_Map.GetPlayerMapPosition(map, 'player')
 if not pos then return end
 local px, py = pos:GetXY()
 local ok, ww, wh = pcall(C_Map.GetMapWorldSize, map)
 if not ok or not ww or ww <= 0 then return end
 local radius = FT.MinimapRadius and FT.MinimapRadius() or ((IsIndoors and IsIndoors()) and INDOOR or OUTDOOR)[Minimap:GetZoom() or 0] or 150
 local rotate = GetCVar and GetCVar('rotateMinimap') == '1'
 local facing = GetPlayerFacing and GetPlayerFacing()
 local half = Minimap:GetWidth() / 2
 local used = 0
 for _, r in ipairs(raresOn(map)) do
  local dx, dy = (r.x - px) * ww, (r.y - py) * wh
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < radius * 0.9 and used < 10 then
   used = used + 1
   local pin = rarePins[used]
   if not pin then
    pin = CreateFrame('Frame', nil, Minimap); pin:SetFrameStrata('MEDIUM'); pin:SetFrameLevel(Minimap:GetFrameLevel() + 7)
    pin.icon = pin:CreateTexture(nil, 'OVERLAY'); pin.icon:SetAllPoints(); pin.icon:SetTexture('Interface\\TargetingFrame\\UI-RaidTargetingIcon_1')
    rarePins[used] = pin
   end
   local s = 14 * (FT.Scale and FT.Scale('mmIcons') or 1)
   pin:SetSize(s, s)
   local nx, ny = FT.MinimapOffset(dx, dy, facing, rotate, radius)
   pin:ClearAllPoints(); pin:SetPoint('CENTER', Minimap, 'CENTER', nx * half, ny * half)
   pin.ftNoFade, pin.ftOut = true, nil
   pin.ftInfo = {kind = 'rare', rare = r}
   if FT.MinimapTrack then FT.MinimapTrack(pin, map, r.x, r.y) end
   pin:Show()
  end
  if dist < 120 then
   -- yaratık başına bir uyarı (her doğma noktası için değil); tekrar süresi ayardan
   local key = r.id
   local rep = ForeverTrailSettings and ForeverTrailSettings.c_rareRepeat or '10'
   local gap = rep == 'once' and math.huge or (tonumber(rep) or 10) * 60
   if not rareWarned[key] or GetTime() - rareWarned[key] > gap then
    rareWarned[key] = GetTime()
    if FT.Flash then FT.Flash(('Nadir yaratık bölgesi: %s (Sv %s)'):format(r.name, r.level or '?'), 0.75, 0.55, 1) end
    if FT.ShowRareCard then pcall(FT.ShowRareCard, {id = r.id, name = r.name, level = r.level, map = map, x = r.x, y = r.y}, dist) end
    FT.PlayEventSound('warn')
   end
  end
 end
end

----------------------------------------------------------------------
-- 3) Posta kutuları (Yol sor paneli ve harita)
----------------------------------------------------------------------
local mailCache = {}
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() mailCache = {} end
function FT.MailboxesOn(mapID)
 if mailCache[mapID] then return mailCache[mapID] end
 local out = {}
 local z = FT.Module and FT.Module('ZoneDB')
 for id, o in pairs(FT.DBO or {}) do
  if o[1] == 'Mailbox' and type(o[4]) == 'table' and z then
   for area, list in pairs(o[4]) do
    if z:GetUiMapIdByAreaId(area) == mapID then
     for i = 1, #list - 1, 2 do out[#out + 1] = {name='Posta kutusu', sub='Posta', cat='posta', map=mapID, x=list[i] / 1000, y=list[i + 1] / 1000} end
    end
   end
  end
 end
 mailCache[mapID] = out
 return out
end

----------------------------------------------------------------------
-- 4) Kısayol tuşları (Tuş Atamaları > Eklentiler > ForeverTrail)
----------------------------------------------------------------------
BINDING_HEADER_FOREVERTRAIL = 'ForeverTrail'
BINDING_NAME_FOREVERTRAIL_NEXT = 'Sıradaki görev'
BINDING_NAME_FOREVERTRAIL_AUTONEXT = 'Sürekli rota aç/kapat'
BINDING_NAME_FOREVERTRAIL_HUB = 'Ana pencere'
BINDING_NAME_FOREVERTRAIL_ASKROUTE = 'Haritada yol sor'
BINDING_NAME_FOREVERTRAIL_CLEAR = 'Özel hedefi kaldır'
_G['BINDING_NAME_CLICK ForeverTrailQuestItem:LeftButton'] = 'Görev eşyasını kullan'

-- Tuş atamalarından eklenti fonksiyonu çağırmak için tek küresel giriş noktası
function FT_ForeverTrailCall(name)
 local fn = FT[name]
 if fn then local ok, err = pcall(fn) if not ok then FT.Print('Hata: ' .. tostring(err)) end end
end

function FT.OpenAskRoute()
 if not WorldMapFrame then return end
 if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) end
 if FT.mapRoute then FT.mapRoute:Show() end
end

----------------------------------------------------------------------
-- 7) Karakter profilleri
----------------------------------------------------------------------
local SKIP = {profiles=true, places=true, gatherNodes=true, recording=true, pos=true, locked=true, arrowLocked=true, lockVersion=true} -- kilit bir profil ayarı değil: profil yüklenince pencereleri kilitlememeli
local function snapshot()
 local copy = {}
 for k, v in pairs(ForeverTrailSettings) do
  if not SKIP[k] and type(v) ~= 'function' then
   if type(v) == 'table' then local t = {} for a, b in pairs(v) do t[a] = b end copy[k] = t else copy[k] = v end
  end
 end
 return copy
end

local function charName() return (UnitName('player') or '?') .. (GetRealmName and ('-' .. GetRealmName()) or '') end

function FT.SaveProfile(name)
 name = (name and name ~= '') and name or charName()
 ForeverTrailSettings.profiles = ForeverTrailSettings.profiles or {}
 ForeverTrailSettings.profiles[name] = snapshot()
 FT.Print(('Profil kaydedildi: %s'):format(name))
end

function FT.LoadProfile(name)
 local p = ForeverTrailSettings.profiles and ForeverTrailSettings.profiles[name]
 if not p then return FT.Print('Profil bulunamadı: ' .. tostring(name)) end
 for k, v in pairs(p) do
  if not SKIP[k] then -- eski profillerdeki kilit ve profil listesi de yok sayılır
   if type(v) == 'table' then local t = {} for a, b in pairs(v) do t[a] = b end ForeverTrailSettings[k] = t else ForeverTrailSettings[k] = v end
  end
 end
 if ForeverTrailCharacter then ForeverTrailCharacter.profile = name end
 if FT.ApplyTheme then FT.ApplyTheme(ForeverTrailSettings.theme) end
 if FT.ApplyFont then FT.ApplyFont(ForeverTrailSettings.font) end
 if FT.ApplyUIScale then FT.ApplyUIScale() end
 if FT.ApplySimple then pcall(FT.ApplySimple) end
 if FT.RefreshTracker then FT.RefreshTracker() end
 FT.Print(('Profil yüklendi: %s (bu karakter için hatırlanacak)'):format(name))
end

function FT.DeleteProfile(name)
 if ForeverTrailSettings.profiles then ForeverTrailSettings.profiles[name] = nil end
 FT.Print('Profil silindi: ' .. tostring(name))
end

local profileWindow
function FT.ToggleProfiles()
 if not profileWindow then
  local w = FT.NewWindow('ForeverTrailProfiles', UIParent)
  profileWindow = w
  w:SetSize(320, 300); w:SetPoint('CENTER'); w:SetFrameStrata('DIALOG')
  w:SetMovable(true); w:EnableMouse(true); w:RegisterForDrag('LeftButton')
  w:SetScript('OnDragStart', function(self) self:StartMoving() end)
  w:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
  local title = w:CreateFontString(nil, 'OVERLAY', 'GameFontNormal'); title:SetPoint('TOP', 0, -7); title:SetText('Profiller')
  if FT.StyleTitle then FT.StyleTitle(title) end
  w.current = w:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall'); w.current:SetPoint('TOPLEFT', 14, -30)
  local box = (FT.Kit and FT.Kit.Input(w) or CreateFrame('EditBox', nil, w, 'InputBoxTemplate'))
  box:SetSize(180, 20); box:SetPoint('TOPLEFT', 20, -50); box:SetAutoFocus(false)
  box:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
  local save = FT.NewButton(w, 'Kaydet', 90, 22); save:SetPoint('LEFT', box, 'RIGHT', 8, 0)
  w.rows = {}
  local function refresh()
   w.current:SetText('Bu karakterin profili: ' .. ((ForeverTrailCharacter and ForeverTrailCharacter.profile) or 'yok (ortak ayarlar)'))
   local names = {}
   for n in pairs(ForeverTrailSettings.profiles or {}) do names[#names + 1] = n end
   table.sort(names)
   for i, r in ipairs(w.rows) do
    local n = names[i]
    if n then r.label:SetText(n); r.name = n; r:Show() else r:Hide() end
   end
  end
  save:SetScript('OnClick', function() FT.SaveProfile(box:GetText()); box:SetText(''); refresh() end)
  for i = 1, 7 do
   local r = CreateFrame('Frame', nil, w); r:SetSize(296, 24); r:SetPoint('TOPLEFT', 12, -80 - (i - 1) * 28)
   r.label = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight'); r.label:SetPoint('LEFT', 4, 0); r.label:SetWidth(150); r.label:SetJustifyH('LEFT')
   local load = FT.NewButton(r, 'Yükle', 64, 20); load:SetPoint('RIGHT', -70, 0)
   load:SetScript('OnClick', function() FT.LoadProfile(r.name); refresh() end)
   local del = FT.NewButton(r, 'Sil', 60, 20); del:SetPoint('RIGHT', -4, 0)
   del:SetScript('OnClick', function() FT.DeleteProfile(r.name); refresh() end)
   w.rows[i] = r
  end
  w:SetScript('OnShow', refresh)
  w:Hide()
 end
 if profileWindow:IsShown() then profileWindow:Hide() else profileWindow:Show() end
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local events = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_LOGIN', 'QUEST_TURNED_IN', 'QUEST_ACCEPTED', 'ZONE_CHANGED_NEW_AREA'}) do pcall(events.RegisterEvent, events, e) end
events:SetScript('OnEvent', function(_, event)
 local ok, err = pcall(function()
  if event == 'PLAYER_LOGIN' then
   local p = ForeverTrailCharacter and ForeverTrailCharacter.profile
   if p and ForeverTrailSettings.profiles and ForeverTrailSettings.profiles[p] then after(1, function() FT.LoadProfile(p) end) end
  elseif event == 'QUEST_TURNED_IN' or event == 'QUEST_ACCEPTED' then continueRoute()
  end
 end)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'flow: ' .. tostring(err) end
end)

-- Hedef tamamlanınca da sürekli rotayı ilerlet
if FT.CheckProgress then
 local check = FT.CheckProgress
 local done = {}
 FT.CheckProgress = function(...)
  check(...)
  if not optIn('autonext') then return end
  local q = C_QuestLog
  for i = 1, (q and q.GetNumQuestLogEntries and q.GetNumQuestLogEntries() or 0) do
   local info = q.GetInfo(i)
   if info and info.questID and info.questID > 0 and q.IsComplete and q.IsComplete(info.questID) and not done[info.questID] then
    done[info.questID] = true
    continueRoute()
   end
  end
 end
end

local acc = 0
events:SetScript('OnUpdate', function(_, dt)
 acc = acc + dt
 if acc < 1 then return end
 acc = 0
 pcall(updateRares)
 -- Özel hedefe varınca sürekli rota sıradakini seçer
 if optIn('autonext') and FT.autoRoute and not FT.customTarget then FT.autoRoute = false; continueRoute() end
end)
