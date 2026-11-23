local _, FT = ...

-- Uçuş rotası, grup ilerlemesi, elit uyarısı, oturum özeti, meslek rehberi, çanta doluluk uyarısı.

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function after(t, fn) if C_Timer and C_Timer.After then C_Timer.After(t, fn) else fn() end end

----------------------------------------------------------------------
-- Bilgi penceresi (özet ve meslek rehberi için)
----------------------------------------------------------------------
local info
function FT.InfoWindow(title, lines)
 if not info then
  info = FT.NewWindow and FT.NewWindow('ForeverTrailInfo', UIParent) or CreateFrame('Frame', 'ForeverTrailInfo', UIParent, 'BasicFrameTemplateWithInset')
  FT.infoWindow = info
  info:SetSize(320, 60); info:SetPoint('CENTER', UIParent, 'CENTER', 220, 60); info:SetFrameStrata('DIALOG')
  info:SetMovable(true); info:EnableMouse(true); info:RegisterForDrag('LeftButton')
  info:SetScript('OnDragStart', function(self) self:StartMoving() end)
  info:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
  info.title = info:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  info.title:SetPoint('TOP', 0, -7)
  if FT.StyleTitle then FT.StyleTitle(info.title) end
  info.lines = {}
  for i = 1, 18 do
   local fs = info:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
   fs:SetPoint('TOPLEFT', 16, -32 - (i - 1) * 18); fs:SetWidth(288); fs:SetJustifyH('LEFT')
   info.lines[i] = fs
  end
  if FT.ApplyFont then pcall(FT.ApplyFont) end
 end
 info.title:SetText(title)
 for i, fs in ipairs(info.lines) do
  if lines[i] then fs:SetText(lines[i]); fs:Show() else fs:Hide() end
 end
 info:SetHeight(44 + math.min(#lines, #info.lines) * 18)
 info:Show()
end

----------------------------------------------------------------------
-- Uçuş rotası planlayıcı: başka bölgedeki hedef için uçuş ustası → uçuş → yürüyüş
----------------------------------------------------------------------
local CONTINENT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2

local function continentOf(map)
 local guard = 0
 while map and guard < 10 do
  local ok, mi = pcall(C_Map.GetMapInfo, map)
  if not ok or not mi then return nil end
  if mi.mapType == CONTINENT then return map end
  map = mi.parentMapID; guard = guard + 1
 end
end

local function toMap(fromMap, x, y, toMapID)
 if not (C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
 local ok, cont, world = pcall(C_Map.GetWorldPosFromMapPos, fromMap, CreateVector2D(x, y))
 if not ok or not world then return nil end
 local got, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, world, toMapID)
 if not got or not pos then return nil end
 local px, py = pos:GetXY()
 return px, py
end

local planCache = {}
function FT.FlightPlan(playerMap, step)
 if not on('flightplan') or not (C_Map and C_Map.GetMapInfo and FT.TaxiNodes and FT.PlayerPosition) or not step.uiMapID then return nil end
 local key = tostring(step) .. ':' .. playerMap
 local cached = planCache[key]
 if cached and GetTime() - cached.t < 4 then return cached.plan end
 local plan
 local ok = pcall(function()
  local continent = continentOf(playerMap)
  if not continent or continentOf(step.uiMapID) ~= continent then return end
  local px, py = FT.PlayerPosition(playerMap)
  if not px then return end
  local cpx, cpy = toMap(playerMap, px, py, continent)
  local ctx, cty = toMap(step.uiMapID, step.x, step.y, continent)
  if not (cpx and ctx) then return end
  local src, dst, sd, dd
  for _, n in ipairs(FT.TaxiNodes(continent)) do
   if n.known then
    local a = (n.x - cpx) ^ 2 + (n.y - cpy) ^ 2
    local b = (n.x - ctx) ^ 2 + (n.y - cty) ^ 2
    if not sd or a < sd then src, sd = n, a end
    if not dd or b < dd then dst, dd = n, b end
   end
  end
  if not src or not dst or src == dst then return end
  local direct = (ctx - cpx) ^ 2 + (cty - cpy) ^ 2
  if math.sqrt(sd) + math.sqrt(dd) > math.sqrt(direct) * 0.6 then return end
  local lx, ly = toMap(continent, src.x, src.y, playerMap)
  if not lx or lx < 0 or lx > 1 or ly < 0 or ly > 1 then return end
  plan = {uiMapID=playerMap, x=lx, y=ly, type='location', stepId='flight:' .. src.name, hint=('Uçuş: %s → %s'):format(src.name, dst.name)}
 end)
 if not ok then plan = nil end
 planCache[key] = {t=GetTime(), plan=plan}
 return plan
end

----------------------------------------------------------------------
-- Grup görev yardımı (gruptakilerde de ForeverTrail olmalı)
----------------------------------------------------------------------
local PREFIX = 'FTRAIL'
local party, sent = {}, {}
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end

local function channel()
 if IsInRaid and IsInRaid() then return 'RAID' end
 if IsInGroup and IsInGroup() then return 'PARTY' end
end

local function broadcast()
 local ch = channel()
 if not ch or not on('groupsync') or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
 local q = C_QuestLog
 for i = 1, q.GetNumQuestLogEntries() do
  local qi = q.GetInfo(i)
  if qi and not qi.isHeader and qi.questID and qi.questID > 0 then
   local ok, rows = pcall(q.GetQuestObjectives, qi.questID)
   local parts = {}
   if ok and type(rows) == 'table' then
    for _, r in ipairs(rows) do parts[#parts + 1] = ('%d/%d'):format(r.numFulfilled or 0, r.numRequired or 0) end
   end
   local msg = qi.questID .. ':' .. (q.IsComplete and q.IsComplete(qi.questID) and 'T' or table.concat(parts, ','))
   if sent[qi.questID] ~= msg then
    sent[qi.questID] = msg
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, ch)
   end
  end
 end
end

function FT.PartyQuests() return party end

function FT.PartyText(questId)
 if not on('groupsync') then return nil end
 local parts = {}
 for name, quests in pairs(party) do
  local v = quests[questId]
  if v then parts[#parts + 1] = name .. ' ' .. (v == 'T' and '|cff55ff55tamam|r' or v) end
 end
 if #parts == 0 then return nil end
 table.sort(parts)
 return 'Grup: ' .. table.concat(parts, '  ')
end

----------------------------------------------------------------------
-- Elit / zor hedef uyarısı
----------------------------------------------------------------------
local warned = {}
local function checkTarget()
 if not on('elitewarn') or not UnitExists('target') or UnitIsDead('target') or UnitIsPlayer('target') then return end
 if UnitIsFriend and UnitIsFriend('player', 'target') then return end
 local guid = UnitGUID('target')
 if not guid or warned[guid] then return end
 local class = UnitClassification and UnitClassification('target') or 'normal'
 local level, mine = UnitLevel('target') or 0, UnitLevel('player') or 1
 local elite = class == 'elite' or class == 'rareelite' or class == 'worldboss'
 local hard = level == -1 or level >= mine + 3
 if not (elite or hard) then return end
 warned[guid] = true
 local what = elite and 'Elit hedef' or 'Zor hedef'
 local lvl = level == -1 and '??' or tostring(level)
 FT.Flash(('%s (Sv %s) — grup önerilir!'):format(what, lvl), 1, 0.3, 0.3)
 FT.Print(('|cffff5555%s (Sv %s): tek başına zor olabilir, grup önerilir.|r'):format(what, lvl))
end

----------------------------------------------------------------------
-- Oturum özeti
----------------------------------------------------------------------
local session = {start=nil, xp=0, quests=0, levels=0}
local lastXP, lastMax

function FT.SessionStats() return session end

function FT.ShowSummary()
 local elapsed = math.max(1, GetTime() - (session.start or GetTime()))
 local hours = elapsed / 3600
 local gold = GetMoney() - (session.money or GetMoney())
 local sign = gold < 0 and '-' or '+'
 local coin = GetCoinTextureString and GetCoinTextureString(math.abs(gold)) or tostring(math.abs(gold))
 local lines = {
  ('Süre: %d sa %d dk'):format(math.floor(elapsed / 3600), math.floor(elapsed % 3600 / 60)),
  ('Teslim edilen görev: |cffffd100%d|r'):format(session.quests),
  ('Kazanılan XP: |cffffd100%d|r'):format(session.xp),
  ('XP / saat: |cffffd100%d|r'):format(session.xp / hours),
  ('Görev / saat: |cffffd100%.1f|r'):format(session.quests / hours),
  ('Altın: %s%s'):format(sign, coin),
  ('Seviye atlama: |cffffd100%d|r'):format(session.levels),
 }
 local extra = FT.LevelTimeLines and FT.LevelTimeLines() or {}
 local all = {}
 for _, l in ipairs(lines) do all[#all + 1] = l end
 if #extra > 0 then all[#all + 1] = ' ' end
 for _, l in ipairs(extra) do all[#all + 1] = l end
 FT.InfoWindow('Oturum özeti', all)
end

----------------------------------------------------------------------
-- Meslek seviye rehberi
----------------------------------------------------------------------
local GUIDE = {
 herb = {{'Peacebloom',1},{'Silverleaf',1},{'Earthroot',15},{'Mageroyal',50},{'Briarthorn',70},{'Stranglekelp',85},{'Bruiseweed',100},{'Wild Steelbloom',115},{'Grave Moss',120},{'Kingsblood',125},{'Liferoot',150},{'Fadeleaf',160},{'Goldthorn',170},{"Khadgar's Whisker",185},{'Wintersbite',195},{'Firebloom',205},{'Purple Lotus',210},{"Arthas' Tears",220},{'Sungrass',230},{'Blindweed',235},{'Ghost Mushroom',245},{'Gromsblood',250},{'Golden Sansam',260},{'Dreamfoil',270},{'Mountain Silversage',280},{'Plaguebloom',285},{'Icecap',290},{'Black Lotus',300}},
 ore = {{'Copper Vein',1},{'Tin Vein',65},{'Incendicite Mineral Vein',65},{'Silver Vein',75},{'Ooze Covered Silver Vein',75},{'Lesser Bloodstone Deposit',75},{'Iron Deposit',125},{'Gold Vein',155},{'Mithril Deposit',175},{'Truesilver Deposit',230},{'Dark Iron Deposit',230},{'Small Thorium Vein',245},{'Rich Thorium Vein',275}},
}
local SKILL_MATCH = {herb={'herbalism', 'bitki'}, ore={'mining', 'maden'}}

function FT.ProfessionSkill(kind)
 if not FT.Compat then return nil end
 for i = 1, FT.Compat.NumSkillLines() do
  local name, header, rank, max = FT.Compat.SkillLine(i)
  if name and not header then
   local lower = name:lower()
   for _, word in ipairs(SKILL_MATCH[kind]) do
    if lower:find(word, 1, true) then return rank, max end
   end
  end
 end
end

-- 'orange' | 'yellow' | 'green' | 'gray' | 'red' (henüz toplanamaz) | nil (bilinmiyor)
function FT.GatherDifficulty(kind, name)
 local skill = FT.ProfessionSkill(kind)
 if not skill then return nil end
 for _, e in ipairs(GUIDE[kind] or {}) do
  if e[1] == name then
   local req = e[2]
   if skill < req then return 'red' end
   if skill < req + 25 then return 'orange' end
   if skill < req + 50 then return 'yellow' end
   if skill < req + 100 then return 'green' end
   return 'gray'
  end
 end
end

local DIFF = {orange='|cffff8040', yellow='|cffffff00', green='|cff40c040', gray='|cff808080', red='|cffff3030'}
function FT.ShowProfessionGuide()
 local lines = {}
 for _, kind in ipairs({'herb', 'ore'}) do
  local skill, max = FT.ProfessionSkill(kind)
  if skill then
   lines[#lines + 1] = ('|cffffd100%s: %d / %d|r'):format(kind == 'herb' and 'Bitki toplama' or 'Madencilik', skill, max or 0)
   local shown = 0
   for _, e in ipairs(GUIDE[kind]) do
    local d = FT.GatherDifficulty(kind, e[1])
    if d and d ~= 'gray' and shown < 5 then
     shown = shown + 1
     local note = d == 'red' and (' (beceri ' .. e[2] .. ' gerekir)') or (d == 'orange' and ' (her toplamada puan)' or '')
     lines[#lines + 1] = '  ' .. DIFF[d] .. e[1] .. '|r' .. note
    end
   end
   if max and skill >= max - 5 and max < 300 then lines[#lines + 1] = '  |cffff9a55Sınıra yakınsın: eğitmenden üst seviyeyi öğren.|r' end
  end
 end
 if #lines == 0 then lines[1] = 'Bitki toplama veya madencilik mesleğin yok.' end
 lines[#lines + 1] = ' '
 lines[#lines + 1] = '|cff9aa0a6Turuncu: kesin puan, sarı: çoğunlukla, yeşil: bazen.|r'
 FT.InfoWindow('Meslek rehberi', lines)
end

----------------------------------------------------------------------
-- Çanta doluluk uyarısı
----------------------------------------------------------------------
local lastBagWarn = -1000
local function checkBags()
 if not on('bagwarn') then return end
 local free = 0
 for bag = 0, NUM_BAG_SLOTS or 4 do
  local fn = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  local n = fn and fn(bag)
  if type(n) == 'number' then free = free + n end
 end
 if free > 2 or GetTime() - lastBagWarn < 300 then return end
 lastBagWarn = GetTime()
 local vendor, distance = FT.NearestPlace and FT.NearestPlace('Satıcı')
 if vendor and FT.ShowChoice then
  FT.ShowChoice('Çanta dolmak üzere', 'Interface\\Icons\\INV_Misc_Bag_08',
   ('Çantada %d boş yer kaldı.\nEn yakın satıcı: %s%s'):format(free, vendor.name, distance and (' (' .. math.floor(distance + 0.5) .. ' yd)') or ''),
   'Yol göster', function() FT.SetCustomTarget(vendor.map, vendor.x, vendor.y, vendor.name) end)
 else
  FT.Alert(('Çanta dolmak üzere: %d boş yer.'):format(free), true)
 end
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local events = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_ENTERING_WORLD', 'PLAYER_XP_UPDATE', 'PLAYER_LEVEL_UP', 'QUEST_TURNED_IN', 'QUEST_LOG_UPDATE', 'GROUP_ROSTER_UPDATE', 'CHAT_MSG_ADDON', 'PLAYER_TARGET_CHANGED', 'BAG_UPDATE_DELAYED'}) do
 pcall(events.RegisterEvent, events, e)
end
local pendingBroadcast = false
events:SetScript('OnEvent', function(_, event, a, b, c, d)
 local ok, err = pcall(function()
  if event == 'PLAYER_ENTERING_WORLD' then
   if not session.start then session.start = GetTime(); session.money = GetMoney() end
   lastXP, lastMax = UnitXP('player'), UnitXPMax('player')
  elseif event == 'PLAYER_XP_UPDATE' then
   local xp, max = UnitXP('player'), UnitXPMax('player')
   if lastXP then
    if xp >= lastXP then session.xp = session.xp + (xp - lastXP)
    else session.xp = session.xp + ((lastMax or 0) - lastXP) + xp end
   end
   lastXP, lastMax = xp, max
  elseif event == 'PLAYER_LEVEL_UP' then session.levels = session.levels + 1
  elseif event == 'QUEST_TURNED_IN' then session.quests = session.quests + 1
  elseif event == 'QUEST_LOG_UPDATE' then
   if not pendingBroadcast and channel() then
    pendingBroadcast = true
    after(2, function() pendingBroadcast = false; pcall(broadcast) end)
   end
  elseif event == 'GROUP_ROSTER_UPDATE' then
   sent = {}
   for name in pairs(party) do if not (UnitInParty(name) or UnitInRaid(name)) then party[name] = nil end end
   after(1, function() pcall(broadcast) end)
  elseif event == 'CHAT_MSG_ADDON' and a == PREFIX then
   local sender = Ambiguate and Ambiguate(d, 'short') or d
   if sender == UnitName('player') then return end
   local id, data = b:match('^(%d+):(.*)$')
   if id then
    party[sender] = party[sender] or {}
    party[sender][tonumber(id)] = data
    if FT.RefreshTracker then FT.RefreshTracker() end
   end
  elseif event == 'PLAYER_TARGET_CHANGED' then checkTarget()
  elseif event == 'BAG_UPDATE_DELAYED' then checkBags()
  end
 end)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'advisor: ' .. tostring(err) end
end)
