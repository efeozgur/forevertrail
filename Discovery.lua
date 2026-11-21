local _, FT = ...

-- Gömülü veriyle: haritada/minimapte alınabilir (!) ve teslim (?) görevleri, akıllı sıradaki görev,
-- sınıf görevi uyarısı, Türkçe görev adları, ileri zincir, kaçırılan görevler, ilk kurulum sihirbazı.

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function after(t, fn) if C_Timer and C_Timer.After then C_Timer.After(t, fn) else fn() end end
local function db() return FT.Module and FT.Module('QuestieDB') end
local function zone() return FT.Module and FT.Module('ZoneDB') end

----------------------------------------------------------------------
-- Türkçe görev adı (WoWTR varsa), yoksa veritabanı adı
----------------------------------------------------------------------
function FT.QuestTitle(id, fallback)
 local tr = type(QTR_QuestData) == 'table' and id and QTR_QuestData[tostring(id)]
 if type(tr) == 'table' and type(tr.Title) == 'string' and tr.Title ~= '' then return tr.Title end
 if fallback and fallback ~= '' then return fallback end
 local d = db()
 return d and id and d.QueryQuestSingle(id, 'name') or (id and ('Görev ' .. id)) or ''
end

----------------------------------------------------------------------
-- Görev vereni / teslim alanı konumları
----------------------------------------------------------------------
local function playerSpot()
 if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
 local map = C_Map.GetBestMapForUnit('player')
 if not map then return nil end
 local pos = C_Map.GetPlayerMapPosition(map, 'player')
 if not pos then return map end
 local x, y = pos:GetXY()
 return map, x, y
end

-- Bir varlığın (npc/nesne) belirli haritadaki noktaları: {{x,y,name},...} (0-1)
local function entityPoints(kind, id, mapID)
 local d, z = db(), zone()
 if not (d and z) then return {} end
 local fn = kind == 'object' and d.QueryObjectSingle or d.QueryNPCSingle
 local spawns = fn(id, 'spawns')
 local name = fn(id, 'name')
 local out = {}
 if type(spawns) ~= 'table' then return out end
 for area, pts in pairs(spawns) do
  local ui = z:GetUiMapIdByAreaId(area)
  if ui and (not mapID or ui == mapID) then
   for _, p in ipairs(pts) do out[#out + 1] = {map=ui, x=p[1] / 100, y=p[2] / 100, name=name} end
  end
 end
 return out
end

local giverCache = {}
local function giverPoints(questId, mapID, finish)
 local key = questId .. ':' .. tostring(mapID) .. (finish and 'f' or 's')
 if giverCache[key] then return giverCache[key] end
 local d = db()
 local by = d and d.QueryQuestSingle(questId, finish and 'finishedBy' or 'startedBy')
 local out = {}
 if type(by) ~= 'table' then return out end
 for _, id in ipairs(by[1] or {}) do for _, p in ipairs(entityPoints('npc', id, mapID)) do out[#out + 1] = p end end
 for _, id in ipairs(by[2] or {}) do for _, p in ipairs(entityPoints('object', id, mapID)) do out[#out + 1] = p end end
 giverCache[key] = out
 return out
end
FT.GiverPoints = giverPoints

function FT.QuestGiverZone(questId)
 local pts = giverPoints(questId, nil, false)
 local p = pts[1]
 return p and FT.MapName and FT.MapName(p.map) or nil
end

-- Görev türü (Questie'deki gibi simge süzgeçleri için): tekrar, etkinlik, pvp, zindan, baskın
local RAIDS = {['Molten Core'] = true, ["Onyxia's Lair"] = true, ['Blackwing Lair'] = true, ["Zul'Gurub"] = true,
 ["Ruins of Ahn'Qiraj"] = true, ["Temple of Ahn'Qiraj"] = true, ['Naxxramas'] = true}
local PVP_ZONES = {[2597] = true, [3277] = true, [3358] = true}
local EVENT_SORTS = {[-22] = true, [-364] = true, [-366] = true, [-369] = true, [-370] = true, [-376] = true, [-1001] = true, [-1002] = true, [-1003] = true, [-1005] = true}
local areaKind
local function questKind(id)
 local q = FT.DBQ and FT.DBQ[id]
 if not q then return nil end
 if not areaKind then
  areaKind = {}
  for aid, d in pairs(FT.DBDungeons or {}) do
   local k = RAIDS[d[1]] and 'raid' or 'dungeon'
   areaKind[aid] = k
   for _, sub in ipairs(type(d[2]) == 'table' and d[2] or {}) do areaKind[sub] = k end
  end
 end
 local zone, flags = q[13], q[16]
 if type(flags) == 'number' and flags % 2 == 1 then return 'repeat' end
 if type(zone) == 'number' then
  if zone == -25 or PVP_ZONES[zone] then return 'pvp' end
  if EVENT_SORTS[zone] then return 'event' end
  if areaKind[zone] then return areaKind[zone] end
 end
end
FT.QuestKind = questKind
local KIND_KEY = {['repeat'] = 'qRepeat', event = 'qEvent', pvp = 'qPvP', dungeon = 'qDungeon', raid = 'qRaid'}
local function kindAllowed(id)
 local k = questKind(id)
 local key = k and KIND_KEY[k]
 if not key then return true end
 if key == 'qRaid' then return ForeverTrailSettings and ForeverTrailSettings.qRaid == true end
 return on(key)
end

-- Haritadaki işaretler: {kind='!'|'?', questId, x, y, map, level, low, title, giver}
local markCache, markMap, markTime = nil, nil, -100
function FT.QuestMarks(mapID)
 if markCache and markMap == mapID and GetTime() - markTime < 6 then return markCache end
 local out, level = {}, UnitLevel('player') or 1
 local d = db()
 local avail = FT.Module and FT.Module('AvailableQuests')
 if d and avail and on('givers') then
  for id in pairs(avail.__availableQuests or {}) do
   local ql = d.QueryQuestSingle(id, 'questLevel') or 0
   local low = ql > 0 and ql < level - 5
   if not (low and ForeverTrailSettings.showLow == false) and ql <= level + 3 and kindAllowed(id) then
    for _, p in ipairs(giverPoints(id, mapID, false)) do
     out[#out + 1] = {kind='!', questId=id, x=p.x, y=p.y, map=p.map, level=ql, low=low, giver=p.name}
    end
   end
  end
 end
 local q = C_QuestLog
 if q and q.GetNumQuestLogEntries and on('givers') and on('giversDone') then
  for i = 1, q.GetNumQuestLogEntries() do
   local info = q.GetInfo(i)
   if info and not info.isHeader and info.questID and info.questID > 0 and q.IsComplete and q.IsComplete(info.questID) then
    for _, p in ipairs(giverPoints(info.questID, mapID, true)) do
     out[#out + 1] = {kind='?', questId=info.questID, x=p.x, y=p.y, map=p.map, level=info.level, giver=p.name}
    end
   end
  end
 end
 markCache, markMap, markTime = out, mapID, GetTime()
 return out
end

local function invalidate() markTime = -100; if FT.BumpLayers then FT.BumpLayers() end end

----------------------------------------------------------------------
-- Dünya haritasında ! ve ?
----------------------------------------------------------------------
local mapDots, glows = {}, {}
FT.giverDots = mapDots
local function questieStyle() return FT.IconStyle and FT.IconStyle() == 'questie' end
-- ! ve ? dokusu: Questie görünümünde Questie simgeleri (gri = seviyenin altında)
local function giverTexture(m)
 if questieStyle() and FT.QuestieMedia then
  if m.kind == '?' then return FT.QuestieMedia .. 'complete' end
  return FT.QuestieMedia .. (m.low and 'available_gray' or 'available')
 end
 return m.kind == '?' and 'Interface\\GossipFrame\\ActiveQuestIcon' or 'Interface\\GossipFrame\\AvailableQuestIcon'
end
FT.GiverTexture = giverTexture
function FT.DrawGivers(mapID)
 for _, d in ipairs(mapDots) do d:Hide() end
 for _, g in ipairs(glows) do g:Hide() end
 local parts = FT.mapParts
 local overlay = parts and parts.overlay
 if not (overlay and mapID and on('givers')) then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local used = 0
 for _, m in ipairs(FT.QuestMarks(mapID)) do
  if used >= 150 then break end
  used = used + 1
  local d = mapDots[used]
  if not d then d = overlay:CreateTexture(nil, 'OVERLAY'); mapDots[used] = d end
  local sc = 16 * FT.Scale('mapIcons') * FT.Scale('iconGiver') * (m.kind == '?' and 1.3 or 1); d:SetSize(sc, sc)
  if on('iconglow') and not questieStyle() then
   local g = glows[used]
   if not g then g = overlay:CreateTexture(nil, 'ARTWORK'); g:SetTexture('Interface\\CHARACTERFRAME\\TempPortraitAlphaMask'); glows[used] = g end
   if m.kind == '?' then g:SetSize(sc * 1.9, sc * 1.9); g:SetVertexColor(1, 0.8, 0.2, 0.55)
   else g:SetSize(sc * 1.35, sc * 1.35); g:SetVertexColor(0, 0, 0, m.low and 0.3 or 0.5) end
   g:ClearAllPoints(); g:SetPoint('CENTER', overlay, 'TOPLEFT', m.x * w, -m.y * h); g:Show()
  end
  d:SetTexture(giverTexture(m))
  local q = questieStyle()
  d:SetDesaturated(not q and m.low == true)
  d:SetAlpha((m.low and not q) and 0.6 or 1)
  if not q and FT.IsNewQuest and FT.IsNewQuest(m.questId) and not m.low then d:SetVertexColor(0.55, 0.85, 1) else d:SetVertexColor(1, 1, 1) end
  d:ClearAllPoints(); d:SetPoint('CENTER', overlay, 'TOPLEFT', m.x * w, -m.y * h)
  local title = FT.QuestTitle(m.questId)
  d.step = {x=m.x, y=m.y, uiMapID=m.map, questId=m.questId, questTitle=('[%s] %s'):format(m.level or '?', title),
   text=(m.kind == '?' and 'Teslim: ' or 'Görev veren: ') .. (m.giver or '?') .. (m.low and ' (seviyenin altında)' or '') .. ((FT.IsNewQuest and FT.IsNewQuest(m.questId)) and '  — Forever\'a özel yeni görev' or ''), type=m.kind == '?' and 'turnin' or 'accept'}
  d:Show()
 end
end

----------------------------------------------------------------------
-- Minimapte yakındaki ! ve ?
----------------------------------------------------------------------
local OUTDOOR = {[0]=233.33, 200, 166.67, 133.33, 100, 66.67}
local INDOOR = {[0]=150, 125, 100, 75, 50, 37.5}
local mmPins = {}
local function updateMinimap()
 for _, p in ipairs(mmPins) do p:Hide() end
 if not (on('givers') and Minimap and Minimap:IsVisible() and C_Map and C_Map.GetMapWorldSize) then return end
 local map, px, py = playerSpot()
 if not (map and px) then return end
 local ok, ww, wh = pcall(C_Map.GetMapWorldSize, map)
 if not ok or not ww or ww <= 0 then return end
 local radius = FT.MinimapRadius and FT.MinimapRadius() or ((IsIndoors and IsIndoors()) and INDOOR or OUTDOOR)[Minimap:GetZoom() or 0] or 150
 local rotate = GetCVar and GetCVar('rotateMinimap') == '1'
 local facing = GetPlayerFacing and GetPlayerFacing()
 local half = Minimap:GetWidth() / 2
 local used = 0
 for _, m in ipairs(FT.QuestMarks(map)) do
  local dx, dy = (m.x - px) * ww, (m.y - py) * wh
  if dx * dx + dy * dy < radius * radius * 0.8 and used < 25 then
   used = used + 1
   local pin = mmPins[used]
   if not pin then
    pin = CreateFrame('Frame', nil, Minimap); pin:SetFrameStrata('MEDIUM'); pin:SetFrameLevel(Minimap:GetFrameLevel() + 6)
    pin.icon = pin:CreateTexture(nil, 'OVERLAY'); pin.icon:SetAllPoints()
    mmPins[used] = pin
   end
   local nx, ny = FT.MinimapOffset and FT.MinimapOffset(dx, dy, facing, rotate, radius)
   if nx then
    pin.icon:SetTexture(giverTexture(m))
    pin.icon:SetDesaturated(not questieStyle() and m.low == true)
    local ms = 14 * FT.Scale('mmIcons') * FT.Scale('iconGiver'); pin:SetSize(ms, ms)
    pin:SetAlpha((FT.MinimapFade and FT.MinimapFade(nx, ny) or 1) * (m.low and 0.7 or 1))
    pin.ftAlpha, pin.ftOut = m.low and 0.7 or 1, nil
    pin.ftInfo = {kind = 'giver', mark = m}
    if FT.MinimapTrack then FT.MinimapTrack(pin, map, m.x, m.y) end
    pin:ClearAllPoints(); pin:SetPoint('CENTER', Minimap, 'CENTER', nx * half, ny * half)
    pin:Show()
   end
  end
 end
end

----------------------------------------------------------------------
-- Akıllı sıradaki görev: XP / mesafe
----------------------------------------------------------------------
local function xpOf(id)
 local x = FT.Module and FT.Module('QuestXP')
 return x and x:GetQuestLogRewardXP(id) or 0
end

function FT.SuggestNext()
 local map, px, py = playerSpot()
 if not (map and px) then return FT.Print('Konum okunamıyor.') end
 local ok, ww, wh = pcall(C_Map.GetMapWorldSize, map)
 if not ok or not ww then return end
 local best, bestScore, why
 local function consider(x, y, xp, label, reason, kind)
  local dx, dy = (x - px) * ww, (y - py) * wh
  local dist = math.sqrt(dx * dx + dy * dy)
  local score = (xp + 50) / (dist + 60)
  if kind == '?' then score = score * 1.5 end
  if not bestScore or score > bestScore then best, bestScore, why = {map=map, x=x, y=y, name=label}, score, ('%s, %d yd, ~%d XP'):format(reason, dist, xp) end
 end
 for _, m in ipairs(FT.QuestMarks(map)) do
  consider(m.x, m.y, xpOf(m.questId), FT.QuestTitle(m.questId), m.kind == '?' and 'teslim et' or 'görevi al', m.kind)
 end
 local q = C_QuestLog
 if q and q.GetNumQuestLogEntries and FT.ResolveQuestWaypoint then
  for i = 1, q.GetNumQuestLogEntries() do
   local info = q.GetInfo(i)
   if info and not info.isHeader and info.questID and info.questID > 0 and not (q.IsComplete and q.IsComplete(info.questID)) then
    local good, m, x, y = pcall(FT.ResolveQuestWaypoint, info.questID, 'objective', 1)
    if good and m == map and x then consider(x, y, xpOf(info.questID), FT.QuestTitle(info.questID, info.title), 'hedefi yap', 'o') end
   end
  end
 end
 if not best then return FT.Print('Bu bölgede önerilecek görev bulunamadı.') end
 FT.SetCustomTarget(best.map, best.x, best.y, best.name)
 FT.Print(('Sıradaki: %s (%s)'):format(best.name, why))
end

----------------------------------------------------------------------
-- Sınıf görevi uyarısı
----------------------------------------------------------------------
local classWarned = {}
local function classQuestCheck()
 if not on('classquests') then return end
 local d = db()
 local avail = FT.Module and FT.Module('AvailableQuests')
 if not (d and avail) then return end
 local level = UnitLevel('player') or 1
 for id in pairs(avail.__availableQuests or {}) do
  local classes = d.QueryQuestSingle(id, 'requiredClasses')
  local ql = d.QueryQuestSingle(id, 'questLevel') or 0
  if type(classes) == 'number' and classes > 0 and ql >= level - 3 and not classWarned[id] then
   classWarned[id] = true
   local pts = giverPoints(id, nil, false)
   local p = pts[1]
   local title = FT.QuestTitle(id)
   local where = p and (FT.MapName and FT.MapName(p.map) or '') or ''
   if p and FT.ShowChoice and FT.ShowChoice('Sınıf görevi', 'Interface\\Icons\\INV_Misc_Book_11',
     ('%s alınabilir.\nVeren: %s — %s'):format(title, p.name or '?', where), 'Yol göster',
     function() FT.SetCustomTarget(p.map, p.x, p.y, title) end) then return end
   FT.Print(('Sınıf görevi alınabilir: %s (%s)'):format(title, where))
   return
  end
 end
end

----------------------------------------------------------------------
-- İleri zincir: bu görevi ön koşul alan görevler
----------------------------------------------------------------------
local followers
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() followers = nil end
function FT.QuestFollowers(id)
 if not followers then
  followers = {}
  for qid, q in pairs(FT.DBQ or {}) do
   for _, list in ipairs({q[10], q[11]}) do
    if type(list) == 'table' then
     for _, pre in ipairs(list) do
      if type(pre) == 'number' then followers[pre] = followers[pre] or {}; table.insert(followers[pre], qid) end
     end
    end
   end
  end
 end
 return followers[id] or {}
end

----------------------------------------------------------------------
-- Kaçırılan görevler: bulunduğun bölgede alınabilir, seviyene uygun ya da düşük
----------------------------------------------------------------------
function FT.ShowMissedQuests()
 local map, px, py = playerSpot()
 local level = UnitLevel('player') or 1
 local list = {}
 for _, m in ipairs(map and FT.QuestMarks(map) or {}) do
  if m.kind == '!' and (m.level or 0) <= level then
   local seen = false
   for _, e in ipairs(list) do if e.questId == m.questId then seen = true end end
   if not seen then list[#list + 1] = m end
  end
 end
 table.sort(list, function(a, b) return (a.level or 0) > (b.level or 0) end)
 local lines = {('%s — %d alınmamış görev'):format(map and FT.MapName and FT.MapName(map) or 'Bölge', #list)}
 for i = 1, math.min(15, #list) do
  local m = list[i]
  local color = m.low and '|cff9d9d9d' or '|cffffd100'
  lines[#lines + 1] = ('%s[%d] %s|r — %s (%.0f, %.0f)'):format(color, m.level or 0, FT.QuestTitle(m.questId), m.giver or '?', m.x * 100, m.y * 100)
 end
 if #list == 0 then lines[#lines + 1] = 'Bu bölgede kaçırdığın görev yok.' end
 FT.InfoWindow('Kaçırılan görevler', lines)
end

----------------------------------------------------------------------
-- İlk kurulum sihirbazı
----------------------------------------------------------------------
local wizard
function FT.ShowSetupWizard()
 if not wizard then
  wizard = FT.NewWindow('ForeverTrailSetup', UIParent)
  wizard:SetSize(380, 260); wizard:SetPoint('CENTER'); wizard:SetFrameStrata('DIALOG')
  wizard:SetMovable(true); wizard:EnableMouse(true); wizard:RegisterForDrag('LeftButton')
  wizard:SetScript('OnDragStart', function(self) self:StartMoving() end)
  wizard:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
  local title = wizard:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  title:SetPoint('TOP', 0, -7); title:SetText('ForeverTrail kurulumu')
  if FT.StyleTitle then FT.StyleTitle(title) end
  wizard.text = wizard:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  wizard.text:SetPoint('TOPLEFT', 18, -36); wizard.text:SetWidth(344); wizard.text:SetJustifyH('LEFT')
  wizard.buttons = {}
  for i = 1, 10 do
   local b = FT.NewButton(wizard, '', 110, 26)
   b:SetPoint('TOPLEFT', 18 + ((i - 1) % 3) * 116, -110 - math.floor((i - 1) / 3) * 32)
   wizard.buttons[i] = b
  end
 end
 local function step(n)
  for _, b in ipairs(wizard.buttons) do b:Hide() end
  local function opt(i, text, fn) local b = wizard.buttons[i]; b:SetText(text); b:SetScript('OnClick', fn); b:Show() end
  if n == 1 then
   wizard.text:SetText('1/3 — Ekranda ne kadar şey görmek istersin?\n\nTam: ok, görev kutusu, ikon şeridi ve hedef kartı.\nSade: yalnızca ok ve görev kutusu (gerisi minimap düğmesinde).')
   opt(1, 'Tam', function() ForeverTrailSettings.simple = false; FT.ApplySimple(); step(2) end)
   opt(2, 'Sade', function() ForeverTrailSettings.simple = true; FT.ApplySimple(); step(2) end)
  elseif n == 2 then
   wizard.text:SetText('2/3 — Otomatik işler\n\nGörevleri otomatik al/teslim et (Shift ile durdurulur) ve satıcıda çöp satıp tamir et?')
   opt(1, 'Hepsi açık', function() for _, k in ipairs({'autoquest', 'autosell', 'autorepair', 'autoloot'}) do ForeverTrailSettings[k] = true end step(3) end)
   opt(2, 'Sadece çanta', function() ForeverTrailSettings.autoquest = false; for _, k in ipairs({'autosell', 'autorepair', 'autoloot'}) do ForeverTrailSettings[k] = true end step(3) end)
   opt(3, 'Hepsi kapalı', function() for _, k in ipairs({'autoquest', 'autosell', 'autorepair', 'autoloot'}) do ForeverTrailSettings[k] = false end step(3) end)
  else
   wizard.text:SetText('3/3 — Renk teması seç (sonra Ayarlar > Görünüm\'den değiştirebilirsin).')
   for i, key in ipairs(FT.themeOrder or {}) do
    if i <= 9 then opt(i, FT.Themes[key].name, function() FT.ApplyTheme(key) end) end
   end
   opt(10, 'Bitir', function() ForeverTrailSettings.setupDone = true; wizard:Hide(); FT.Print('Kurulum tamam. Ana pencere için minimap düğmesine tıkla.') end)
  end
 end
 step(1)
 wizard:Show()
 if FT.ApplyFont then pcall(FT.ApplyFont) end
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local events = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_LOGIN', 'QUEST_ACCEPTED', 'QUEST_TURNED_IN', 'QUEST_LOG_UPDATE', 'ZONE_CHANGED_NEW_AREA', 'PLAYER_LEVEL_UP'}) do
 pcall(events.RegisterEvent, events, e)
end
events:SetScript('OnEvent', function(_, event)
 local ok, err = pcall(function()
  if event == 'PLAYER_LOGIN' then
   after(4, function() if not FT.QuestonActive and (not ForeverTrailSettings.setupDone or ForeverTrailSettings.setupVersion ~= 3) then FT.ShowSetupWizard() end end)
   after(8, classQuestCheck)
  elseif event == 'PLAYER_LEVEL_UP' then invalidate(); after(3, classQuestCheck)
  else invalidate() end
 end)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'discovery: ' .. tostring(err) end
end)
local acc = 0
events:SetScript('OnUpdate', function(_, dt)
 acc = acc + dt
 if acc < 0.5 then return end
 acc = 0
 pcall(updateMinimap)
end)
