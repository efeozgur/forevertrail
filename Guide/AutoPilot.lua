local _, FT = ...

-- Otopilot: rehberi senin yerine yönetir.
--  1) Bölgeye girince (ya da giriş yapınca) seviyene uygun bölge rehberini ÖNERİR; onaylarsan geçer.
--  2) Rehber sırasını izler; hedeften çok uzaklaşıp rehberde yapılabilir başka bir adımın yakınına gidersen oraya atlar.
--  3) Atlanan ya da atlayarak geçilen adımlar rehber bitince geri gelir (Engine.Advance FT.NextPendingStep'e bakar);
--     elle "Atla" dediğin adımlar geri gelmez.
--  4) Konuşma penceresinde yalnızca rehberdeki görevler otomatik alınır/teslim edilir (FT.GuideAllows, Helpers/Assist.lua).
-- Ayarlar: guideSuggest (öneri), autopilot (yakına atlama), autoquestAll (rehber dışı görevler de otomatik).

local STRAY = 400      -- yd: şimdiki adımdan bu kadar uzaksan yakındaki adıma atlama düşünülür
local NEAR = 160       -- yd: atlanacak adım bu kadar yakında olmalı
local JUMP_GAP = 15    -- sn: iki atlama arası en az
local TICK = 2         -- sn: kontrol aralığı

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function after(t, fn) if C_Timer and C_Timer.After then C_Timer.After(t, fn) else fn() end end
local function char() ForeverTrailCharacter = ForeverTrailCharacter or {}; return ForeverTrailCharacter end

----------------------------------------------------------------------
-- Rehberdeki görevler (otomatik al/teslim için)
----------------------------------------------------------------------
local setCache = setmetatable({}, {__mode = 'k'})
local function questSet(guide)
 local c = setCache[guide]
 if c then return c end
 c = {accept = {}, turnin = {}, acceptTitle = {}, turninTitle = {}}
 for _, s in ipairs(guide.steps or {}) do
  if s.questId and (s.type == 'accept' or s.type == 'turnin') then
   c[s.type][s.questId] = true
   local title = s.questTitle or (FT.DBQ and FT.DBQ[s.questId] and FT.DBQ[s.questId][1])
   if title then c[s.type .. 'Title'][title] = true end
  end
 end
 setCache[guide] = c
 return c
end

-- Görev bu rehberde mi? kind: 'accept' | 'turnin'. Dönüş: nil (kısıt yok: eski davranış), true, false.
-- Kısıt yalnızca hazır/otomatik (canlı olmayan) bir rehber seçiliyken ve autoquestAll kapalıyken vardır.
function FT.GuideAllows(questId, kind)
 local g = FT.guide
 if not g or g.live or not g.steps then return nil end
 if ForeverTrailSettings and ForeverTrailSettings.autoquestAll == true then return nil end
 if not questId then return false end
 return questSet(g)[kind][questId] == true
end
function FT.GuideAllowsTitle(title, kind)
 local g = FT.guide
 if not g or g.live or not g.steps then return nil end
 if ForeverTrailSettings and ForeverTrailSettings.autoquestAll == true then return nil end
 return questSet(g)[kind .. 'Title'][title] == true
end

----------------------------------------------------------------------
-- Bekleyen (yapılabilir ama yapılmamış) adımlar
----------------------------------------------------------------------
local function skippedKey(guide, step) return tostring(guide.guideId) .. ':' .. tostring(step.stepId) end

-- Adım atlandı olarak işaretlenir: geri çağrılmaz
function FT.MarkSkipped(guide, step)
 if not (guide and step) then return end
 char().skipped = char().skipped or {}
 char().skipped[skippedKey(guide, step)] = true
end

local function level() return UnitLevel and UnitLevel('player') or 1 end

-- Şu an yapılabilir mi? (alma: günlükte değil ve ön koşullar tamam; hedef: günlükte; teslim: tamamlanmış)
local function doable(step, state)
 if not step.questId then return false end
 if step.type == 'accept' then
  if state.status ~= 'not_taken' then return false end
  local q = FT.DBQ and FT.DBQ[step.questId]
  if q then
   if type(q[4]) == 'number' and q[4] > level() then return false end
   for _, pid in ipairs(type(q[10]) == 'table' and q[10] or {}) do
    if FT.QuestState(pid).status ~= 'turned_in' then return false end
   end
   local any = type(q[11]) == 'table' and #q[11] > 0
   if any then
    local ok = false
    for _, pid in ipairs(q[11]) do if FT.QuestState(pid).status == 'turned_in' then ok = true break end end
    if not ok then return false end
   end
  end
  return true
 elseif step.type == 'objective' then return state.status == 'active'
 elseif step.type == 'turnin' then return state.status == 'ready' end
 return false
end

local function pending(guide, exceptIndex)
 local out = {}
 for i, s in ipairs(guide.steps) do
  if i ~= exceptIndex and not (char().skipped and char().skipped[skippedKey(guide, s)]) then
   local state = FT.QuestState(s.questId, s.objectiveIndex)
   if not FT.IsStepDone(s, state) and doable(s, state) then out[#out + 1] = i end
  end
 end
 return out
end

-- Rehber bitmek üzereyken geriye kalan yapılabilir ilk adım (yoksa nil); Engine.Advance çağırır
function FT.NextPendingStep()
 local g = FT.guide
 if not g or g.live or not g.steps or not FT.QuestState then return nil end
 local list = pending(g, FT.active)
 return list[1]
end

----------------------------------------------------------------------
-- Uzaklaşınca en yakın yapılabilir adıma atla
----------------------------------------------------------------------
local lastJump = -100

local function playerSpot(map)
 if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
 local ok, best = pcall(C_Map.GetBestMapForUnit, 'player')
 if not ok or not best then return nil end
 local got, pos = pcall(C_Map.GetPlayerMapPosition, map or best, 'player')
 if not got or not pos then return best, nil end
 local valid, x, y = pcall(function() return pos:GetXY() end)
 if not valid or type(x) ~= 'number' or (x == 0 and y == 0) then return best, nil end
 return best, x, y
end

local function yards(map, ax, ay, bx, by)
 local ok, w, h = pcall(C_Map.GetMapWorldSize, map)
 if not ok or not w or w <= 0 then return nil end
 return math.sqrt(((ax - bx) * w) ^ 2 + ((ay - by) * (h or w)) ^ 2)
end

-- Dönüş: atlanan adım numarası ya da nil. now: saat (test için)
function FT.AutoPilotStep(now)
 now = now or (GetTime and GetTime() or 0)
 local g = FT.guide
 if not (g and not g.live and g.steps and FT.ready and ForeverTrailSettings and ForeverTrailSettings.auto and on('autopilot')) then return nil end
 if now - lastJump < JUMP_GAP then return nil end
 if InCombatLockdown and InCombatLockdown() then return nil end
 local cur = FT.CurrentStep()
 local map, px, py = playerSpot()
 if not (map and px) then return nil end
 -- şimdiki adıma uzaklık: başka haritadaysa çok uzak sayılır
 local curDist = math.huge
 if cur and not FT.complete and cur.uiMapID == map and cur.x then curDist = yards(map, px, py, cur.x, cur.y) or math.huge end
 if curDist <= STRAY then return nil end
 local best, bestDist
 for _, i in ipairs(pending(g, FT.active)) do
  local s = g.steps[i]
  if s.uiMapID == map and s.x and s.y then
   local d = yards(map, px, py, s.x, s.y)
   if d and d <= NEAR and (not bestDist or d < bestDist) then best, bestDist = i, d end
  end
 end
 if not best then return nil end -- (NEAR 160 yd, STRAY 400 yd: yakındaki adım her zaman şimdikinden belirgin biçimde yakındır)
 lastJump = now
 FT.active, FT.view, FT.complete = best, best, false
 FT.notice = 'Yakındaki adıma geçildi.'
 if FT.SaveStep then FT.SaveStep() end
 if FT.Evaluate then FT.Evaluate() end
 return best
end
function FT.AutoPilotReset() lastJump = -100 end

----------------------------------------------------------------------
-- Bölgeye girince rehber önerisi
----------------------------------------------------------------------
local declinedSession = {}
local suggestRetry = false

local function windowsHere()
 if not (FT.AutoGuide and FT.AutoGuide.Zones and C_Map and C_Map.GetBestMapForUnit) then return nil end
 local ok, map = pcall(C_Map.GetBestMapForUnit, 'player')
 if not ok or not map then return nil end
 -- önce bulunduğun harita, yoksa üst haritaları (şehir/alt bölge -> bölge)
 local guard = 0
 while map and guard < 4 do
  local list = FT.AutoGuide.Zones(map)
  local best
  for _, z in ipairs(list) do
   if z.recommended and (not best or z.count > best.count) then best = z end
  end
  if best then return best end
  local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  map = info and info.parentMapID
  guard = guard + 1
 end
end

-- Dönüş: 'asked' (soru açıldı), 'busy' (başka pencere açık), ya da nil (sorulmadı)
function FT.SuggestGuide()
 if not on('guideSuggest') or not FT.ready or not FT.ShowChoice then return nil end
 if InCombatLockdown and InCombatLockdown() then return nil end
 if IsInInstance and IsInInstance() then return nil end
 local z = windowsHere()
 if not z then return nil end
 local g = FT.guide
 local key = z.key
 -- zaten bu pencerenin rehberindeyse sorma; hazır rehber yürürken ve bitmemişken de rahatsız etme
 if g and g.guideId == ('auto-%d-%d-%d'):format(z.map, z.lo, z.hi) and not FT.complete then return nil end
 if g and not g.live and not g.auto and not FT.complete then return nil end
 if declinedSession[key] or (char().guideDeclines and (char().guideDeclines[key] or 0) >= 2) then return nil end
 local text = ('%s (%d-%d) bölge rehberine geçilsin mi?\n%d görev  ·  %d adım'):format(z.name, z.lo, z.hi, z.count, z.steps or 0)
 local shown = FT.ShowChoice('Rehber önerisi', 'Interface\\AddOns\\ForeverTrail\\Media\\route_flag', text, 'Rehbere geç',
  function()
   local ok = FT.AutoGuide.Select(z.map, z.lo, z.hi)
   if ok then
    if ForeverTrailSettings then ForeverTrailSettings.dockTab = 'guide' end
    if FT.RefreshQuestDock then FT.RefreshQuestDock() end
    if FT.Refresh then FT.Refresh() end
   end
  end,
  function()
   declinedSession[key] = true
   char().guideDeclines = char().guideDeclines or {}
   char().guideDeclines[key] = (char().guideDeclines[key] or 0) + 1
  end)
 if shown == false then suggestRetry = true; return 'busy' end
 return 'asked'
end
function FT.SuggestGuideReset() declinedSession = {}; suggestRetry = false end

----------------------------------------------------------------------
-- Sürücü
----------------------------------------------------------------------
local events = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_ENTERING_WORLD', 'ZONE_CHANGED_NEW_AREA', 'PLAYER_LEVEL_UP'}) do pcall(events.RegisterEvent, events, e) end
local pendingCheck = false
events:SetScript('OnEvent', function()
 if pendingCheck then return end
 pendingCheck = true
 after(5, function() pendingCheck = false; pcall(FT.SuggestGuide) end)
end)

local driver = CreateFrame('Frame')
local waited, retryWaited = 0, 0
driver:SetScript('OnUpdate', function(_, dt)
 waited = waited + dt
 if waited >= TICK then waited = 0; pcall(FT.AutoPilotStep) end
 if suggestRetry then
  retryWaited = retryWaited + dt
  if retryWaited >= 30 then retryWaited = 0; suggestRetry = false; pcall(FT.SuggestGuide) end
 end
end)
