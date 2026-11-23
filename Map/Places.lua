local _, FT = ...

-- Yerler: uçuş noktaları, öğrenilen hizmet NPC'leri, muhafız tarifleri, meslek düğümleri ve kendi kayıtların.
-- Hedef seçilince ok, mini harita ve harita güzergahı o noktaya çalışır.

local CATEGORIES = {
 {key='flight', label='Uçuş'},
 {key='services', label='Hizmetler'},
 {key='prof', label='Meslek'},
 {key='mine', label='Kayıtlarım'},
 {key='search', label='Ara'},
}
local SERVICE_CATS = {['Satıcı']=true, ['Tamirci']=true, ['Banka']=true, ['Posta']=true, ['Müzayede']=true, ['Han']=true, ['Eğitmen']=true, ['Muhafız tarifi']=true}

local function placeList()
 ForeverTrailSettings.places = ForeverTrailSettings.places or {}
 return ForeverTrailSettings.places
end

local function nodeList()
 if type(ForeverTrailSettings.nodes) == 'table' then ForeverTrailSettings.gatherNodes = ForeverTrailSettings.nodes; ForeverTrailSettings.nodes = nil end
 ForeverTrailSettings.gatherNodes = ForeverTrailSettings.gatherNodes or {}
 return ForeverTrailSettings.gatherNodes
end

local function playerSpot()
 if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
 local ok, map = pcall(C_Map.GetBestMapForUnit, 'player')
 if not ok or not map then return nil end
 local got, pos = pcall(C_Map.GetPlayerMapPosition, map, 'player')
 if not got or not pos then return nil end
 local valid, x, y = pcall(function() return pos:GetXY() end)
 if not valid or type(x) ~= 'number' or (x == 0 and y == 0) then return nil end
 return map, x, y
end

local function yardsBetween(map, x1, y1, x2, y2)
 if not (C_Map and C_Map.GetMapWorldSize) then return nil end
 local ok, w, h = pcall(C_Map.GetMapWorldSize, map)
 if not ok or not w or w <= 0 then return nil end
 local dx, dy = (x1 - x2) * w, (y1 - y2) * h
 return math.sqrt(dx * dx + dy * dy)
end

----------------------------------------------------------------------
-- Kayıtlı yerler
----------------------------------------------------------------------
function FT.AddPlace(name, cat, map, x, y, silent)
 if type(name) ~= 'string' or name == '' or not map or not x or not y then return false end
 local list = placeList()
 for _, p in ipairs(list) do
  if p.cat == cat and p.name == name and p.map == map and math.abs(p.x - x) < 0.006 and math.abs(p.y - y) < 0.006 then return false end
 end
 list[#list + 1] = {name=name, cat=cat, map=map, x=x, y=y}
 while #list > 300 do table.remove(list, 1) end
 if not silent then FT.Print(('Yer kaydedildi: %s (%s)'):format(name, cat)) end
 return true
end

function FT.NearestPlace(cat)
 local map, px, py = playerSpot()
 if not map then return nil end
 local best, bestDistance
 for _, p in ipairs(placeList()) do
  if p.cat == cat and p.map == map then
   local d = yardsBetween(map, p.x, p.y, px, py)
   if d and (not bestDistance or d < bestDistance) then best, bestDistance = p, d end
  end
 end
 return best, bestDistance
end

function FT.AddPlaceHere(name, cat)
 local map, x, y = playerSpot()
 if not map then return FT.Print('Konum okunamıyor.') end
 return FT.AddPlace(name, cat or 'Kayıtlı', map, x, y)
end

----------------------------------------------------------------------
-- Uçuş noktaları (oyunun taksi haritası verisi)
----------------------------------------------------------------------
local function flightState(name)
 local e = Enum and Enum.FlightPathState
 local fallback = {Current=0, Reachable=1, Unreachable=2}
 return (e and e[name]) or fallback[name]
end

-- {name, map, x, y, known, id} listesi
function FT.TaxiNodes(map)
 local out = {}
 if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and map) then return out end
 local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, map)
 if not ok or type(nodes) ~= 'table' then return out end
 for _, node in ipairs(nodes) do
  local x, y
  if node.position then
   local got, px, py = pcall(function() return node.position:GetXY() end)
   if got then x, y = px, py else x, y = node.position.x, node.position.y end
  end
  if type(x) == 'number' and type(y) == 'number' and node.name then
   local state = node.state
   out[#out + 1] = {name=node.name, map=map, x=x, y=y, id=node.nodeID, known=(state == flightState('Reachable') or state == flightState('Current'))}
  end
 end
 return out
end

----------------------------------------------------------------------
-- Satır listesi ve pencere
----------------------------------------------------------------------
local function rowsFor(category)
 local map, px, py = playerSpot()
 local rows = {}
 local function add(name, cat, m, x, y, extra)
  local dist = (map and m == map and px) and yardsBetween(m, x, y, px, py) or nil
  rows[#rows + 1] = {name=name, cat=cat, map=m, x=x, y=y, dist=dist, extra=extra}
 end
 if category == 'flight' then
  if map then
   for _, n in ipairs(FT.TaxiNodes(map)) do add(n.name, 'Uçuş noktası', n.map, n.x, n.y, n.known and nil or 'keşfedilmemiş') end
  end
  for _, p in ipairs(placeList()) do if p.cat == 'Uçuş noktası' then add(p.name, p.cat, p.map, p.x, p.y) end end
 elseif category == 'search' then
  for _, r in ipairs(FT.Search and FT.Search(FT.placesSearchText or '') or {}) do add(r.name, r.cat, r.map, r.x, r.y) end
 elseif category == 'services' then
  for _, p in ipairs(placeList()) do if SERVICE_CATS[p.cat] then add(p.name, p.cat, p.map, p.x, p.y) end end
 elseif category == 'prof' then
  for _, p in ipairs(placeList()) do if p.cat == 'Meslek eğitmeni' then add(p.name, p.cat, p.map, p.x, p.y) end end
  local seen = {}
  for _, n in ipairs(nodeList()) do
   local key = n.kind .. ':' .. n.name
   local best
   if map and n.map == map then
    local d = px and yardsBetween(map, n.x, n.y, px, py) or 1e9
    if not seen[key] or d < seen[key].d then seen[key] = {d=d, node=n} end
   end
  end
  for _, entry in pairs(seen) do
   local n = entry.node
   add(n.name, n.kind == 'herb' and 'Bitki' or 'Maden', n.map, n.x, n.y)
  end
 else
  for _, p in ipairs(placeList()) do if p.cat == 'Kayıtlı' then add(p.name, p.cat, p.map, p.x, p.y) end end
 end
 table.sort(rows, function(a, b)
  if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
  if a.dist and b.dist and a.dist ~= b.dist then return a.dist < b.dist end
  return a.name < b.name
 end)
 return rows
end

local frame, rowButtons, categoryButtons, pageLabel, nameBox
local currentCategory, page, rows = 'flight', 1, {}
local PER_PAGE = 9

local function refreshList()
 if not frame then return end
 rows = rowsFor(currentCategory)
 page = math.max(1, math.min(page, math.ceil(math.max(1, #rows) / PER_PAGE)))
 for i, b in ipairs(rowButtons) do
  local row = rows[(page - 1) * PER_PAGE + i]
  if row then
   local where = row.dist and ('%d yd'):format(row.dist + 0.5) or (FT.MapName and FT.MapName(row.map)) or ''
   b.row = row
   b.left:SetText(row.name .. (row.extra and ('  |cffff9a55(' .. row.extra .. ')|r') or ''))
   b.tag:SetText(('|cff9aa0a6%s|r'):format(row.cat))
   b.right:SetText(where)
   b:Show()
  else
   b.row = nil; b:Hide()
  end
 end
 pageLabel:SetText(('%d / %d'):format(page, math.max(1, math.ceil(#rows / PER_PAGE))))
 for _, cb in ipairs(categoryButtons) do
  if cb.key == currentCategory then cb:Disable() else cb:Enable() end
 end
 if #rows == 0 then
  frame.empty:SetText(currentCategory == 'flight' and 'Bu haritada uçuş noktası bulunamadı. Uçuş ustasıyla konuşunca konumu kaydedilir.'
   or currentCategory == 'services' and 'Henüz kayıtlı yer yok. Satıcı, banka, posta veya han kullandıkça konumları otomatik öğrenilir.'
   or currentCategory == 'prof' and 'Meslek eğitmeni ve topladığın bitki/maden konumları burada görünür.'
   or currentCategory == 'search' and 'Aşağıdaki kutuya görev, yer, bitki veya maden adı yaz (en az 2 harf).'
   or 'Kayıt yok. Aşağıdan bulunduğun yeri adıyla kaydedebilirsin.')
  frame.empty:Show()
 else
  frame.empty:Hide()
 end
end
FT.RefreshPlaces = refreshList

local function createWindow()
 frame = FT.NewWindow and FT.NewWindow('ForeverTrailPlaces', UIParent) or CreateFrame('Frame', 'ForeverTrailPlaces', UIParent, 'BasicFrameTemplateWithInset')
 FT.placesWindow = frame
 frame:SetSize(360, 410); frame:SetPoint('CENTER', UIParent, 'CENTER', -200, 20); frame:SetFrameStrata('DIALOG')
 frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag('LeftButton')
 frame:SetScript('OnDragStart', function(self) self:StartMoving() end)
 frame:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
 local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 title:SetPoint('TOP', 0, -7); title:SetText('Nereye gitmek istersin?')
 categoryButtons = {}
 for i, c in ipairs(CATEGORIES) do
  local b = FT.NewButton and FT.NewButton(frame, c.label, 80, 22)
  if not b then b = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate'); b:SetSize(80, 22); b:SetText(c.label) end
  b:SetWidth(62); b:SetPoint('TOPLEFT', 14 + (i - 1) * 66, -32)
  b.key = c.key
  b:SetScript('OnClick', function() currentCategory = c.key; page = 1; refreshList() end)
  categoryButtons[i] = b
 end
 frame.empty = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 frame.empty:SetPoint('TOPLEFT', 18, -70); frame.empty:SetWidth(320); frame.empty:SetJustifyH('LEFT'); frame.empty:SetTextColor(0.78, 0.72, 0.64)
 rowButtons = {}
 for i = 1, PER_PAGE do
  local b = FT.NewButton and FT.NewButton(frame, '', 332, 30)
  if not b then b = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate'); b:SetSize(332, 30) end
  b:SetPoint('TOPLEFT', 14, -62 - (i - 1) * 32)
  b.left = b:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  b.left:SetPoint('TOPLEFT', 8, -4); b.left:SetWidth(215); b.left:SetJustifyH('LEFT'); b.left:SetWordWrap(false)
  b.tag = b:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  b.tag:SetPoint('BOTTOMLEFT', 8, 4); b.tag:SetJustifyH('LEFT')
  b.right = b:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
  b.right:SetPoint('RIGHT', -8, 0); b.right:SetJustifyH('RIGHT')
  b:SetScript('OnClick', function(self)
   local row = self.row
   if not row then return end
   FT.SetCustomTarget(row.map, row.x, row.y, row.name)
   if FT.OpenMap then FT.OpenMap() end
  end)
  rowButtons[i] = b
 end
 local prev = FT.NewButton and FT.NewButton(frame, '<', 28, 22)
 prev:SetPoint('BOTTOMLEFT', 14, 50); prev:SetScript('OnClick', function() page = page - 1; refreshList() end)
 local nextB = FT.NewButton and FT.NewButton(frame, '>', 28, 22)
 nextB:SetPoint('BOTTOMLEFT', 100, 50); nextB:SetScript('OnClick', function() page = page + 1; refreshList() end)
 pageLabel = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 pageLabel:SetPoint('BOTTOMLEFT', 48, 54); pageLabel:SetWidth(50); pageLabel:SetJustifyH('CENTER')
 nameBox = CreateFrame('EditBox', nil, frame, 'InputBoxTemplate')
 nameBox:SetSize(190, 22); nameBox:SetPoint('BOTTOMLEFT', 22, 16); nameBox:SetAutoFocus(false); nameBox:SetMaxLetters(40)
 nameBox:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
nameBox:SetScript('OnTextChanged', function(self) FT.placesSearchText = self:GetText(); if currentCategory == 'search' then page = 1; refreshList() end end)
 local save = FT.NewButton and FT.NewButton(frame, 'Buraya kaydet', 112, 22)
 save:SetPoint('BOTTOMRIGHT', -14, 16)
 save:SetScript('OnClick', function()
  local text = nameBox:GetText()
  if text == '' then return FT.Print('Önce kayıt için bir ad yaz.') end
  FT.AddPlaceHere(text, 'Kayıtlı')
  nameBox:SetText(''); nameBox:ClearFocus()
  currentCategory = 'mine'; page = 1; refreshList()
 end)
 frame:SetScript('OnShow', refreshList)
 frame:Hide()
 if FT.ApplyFont then pcall(FT.ApplyFont) end
end

function FT.EnsurePlacesWindow()
 if not frame then createWindow() end
 return frame
end

function FT.TogglePlaces()
 if not frame then createWindow() end
 if frame:IsShown() then frame:Hide() else frame:Show() end
end

----------------------------------------------------------------------
-- Hizmetleri yürürken öğrenme ve muhafız tarifleri
----------------------------------------------------------------------
local function learn(cat, nameOverride)
 local map, x, y = playerSpot()
 if not map then return end
 local name = nameOverride or (UnitName and UnitName('npc')) or cat
 FT.AddPlace(name, cat, map, x, y, true)
end

local learnEvents = {
 MERCHANT_SHOW = function()
  learn('Satıcı')
  if CanMerchantRepair and CanMerchantRepair() then learn('Tamirci') end
 end,
 BANKFRAME_OPENED = function() learn('Banka') end,
 MAIL_SHOW = function() learn('Posta', 'Posta kutusu') end,
 AUCTION_HOUSE_SHOW = function() learn('Müzayede') end,
 TAXIMAP_OPENED = function() learn('Uçuş noktası') end,
 TRAINER_SHOW = function()
  if IsTradeskillTrainer and IsTradeskillTrainer() then
   local skill = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(1)
   local npc = UnitName and UnitName('npc') or 'Eğitmen'
   learn('Meslek eğitmeni', skill and (npc .. ' (' .. skill .. ')') or npc)
  else
   learn('Eğitmen')
  end
 end,
 CONFIRM_BINDER = function(_, location) learn('Han', location and ('Han: ' .. tostring(location)) or nil) end,
}

local function onGossipPoi(poiID)
 if not (C_Map and C_Map.GetBestMapForUnit and C_GossipInfo and C_GossipInfo.GetPoiInfo) then return end
 local map = C_Map.GetBestMapForUnit('player')
 if not poiID and C_GossipInfo.GetPoiForUiMapID then poiID = C_GossipInfo.GetPoiForUiMapID(map) end
 if not poiID then return end
 local ok, info = pcall(C_GossipInfo.GetPoiInfo, map, poiID)
 if not ok or type(info) ~= 'table' or not info.position then return end
 local got, x, y = pcall(function() return info.position:GetXY() end)
 if not got or type(x) ~= 'number' then return end
 local name = info.name or 'Muhafız tarifi'
 FT.AddPlace(name, 'Muhafız tarifi', map, x, y, true)
 FT.SetCustomTarget(map, x, y, name)
end

----------------------------------------------------------------------
-- Uçuş noktası uyarıları: şehre girince ve yakından geçerken
----------------------------------------------------------------------
local alerted = {}
local function nearestNode(map, wantUnknown)
 local _, px, py = playerSpot()
 if not px then return nil end
 local best, bestDistance
 for _, n in ipairs(FT.TaxiNodes(map)) do
  if (wantUnknown and not n.known) or (not wantUnknown and n.known) then
   local d = yardsBetween(map, n.x, n.y, px, py)
   if d and (not bestDistance or d < bestDistance) then best, bestDistance = n, d end
  end
 end
 return best, bestDistance
end

local function offerFlight(node, distance, text, key)
 if alerted[key] then return end
 local icon = 'Interface\\Icons\\Ability_Mount_Gryphon_01'
 local shown = FT.ShowChoice and FT.ShowChoice('Uçuş noktası', icon, text, 'Yol göster', function()
  FT.SetCustomTarget(node.map, node.x, node.y, node.name)
 end)
 if shown then alerted[key] = true end
end

local function onEnterCity()
 if ForeverTrailSettings.flightalert == false or (InCombatLockdown and InCombatLockdown()) then return end
 local map = playerSpot()
 if not map then return end
 local unknown, ud = nearestNode(map, true)
 if unknown then
  return offerFlight(unknown, ud, ('Şehirdesin. %s uçuş noktasını henüz keşfetmedin (%d yd). Yol gösterilsin mi?'):format(unknown.name, ud + 0.5), 'city-unknown:' .. map)
 end
 local known, kd = nearestNode(map, false)
 if known then
  offerFlight(known, kd, ('Şehirdesin. En yakın uçuş noktası: %s (%d yd). Yol gösterilsin mi?'):format(known.name, kd + 0.5), 'city-known:' .. map)
 end
end

local acc = 0
local function proximityCheck()
 if ForeverTrailSettings.flightalert == false or (InCombatLockdown and InCombatLockdown()) then return end
 if IsMounted and IsMounted() then return end
 local map = playerSpot()
 if not map then return end
 local unknown, d = nearestNode(map, true)
 if unknown and d and d <= 110 then
  offerFlight(unknown, d, ('Yakında keşfedilmemiş bir uçuş noktası var: %s (%d yd). Yol gösterilsin mi?'):format(unknown.name, d + 0.5), 'near:' .. tostring(unknown.id or unknown.name))
 end
end

----------------------------------------------------------------------
-- Meslek düğümleri: toplarken öğren, haritada göster
----------------------------------------------------------------------
local GATHER = {herb={2366}, ore={2575}}
local KIND_LABEL = {herb='Bitki', ore='Maden'}
local KIND_COLOR = {herb={0.45, 0.95, 0.5}, ore={0.7, 0.8, 1}}
local pendingGather

local function spellKnown(id)
 if IsPlayerSpell and IsPlayerSpell(id) then return true end
 if IsSpellKnown and IsSpellKnown(id) then return true end
 return false
end

local function kindOfSpell(spellID)
 local name = GetSpellInfo and GetSpellInfo(spellID)
 if not name then return nil end
 for kind, ids in pairs(GATHER) do
  for _, id in ipairs(ids) do
   if GetSpellInfo(id) == name then return kind end
  end
 end
end

function FT.RecordNode(kind, name)
 local map, x, y = playerSpot()
 if not map or type(name) ~= 'string' or name == '' then return end
 local list = nodeList()
 for _, n in ipairs(list) do
  if n.kind == kind and n.name == name and n.map == map and math.abs(n.x - x) < 0.006 and math.abs(n.y - y) < 0.006 then return end
 end
 list[#list + 1] = {kind=kind, name=name, map=map, x=x, y=y}
 while #list > 500 do table.remove(list, 1) end
end

local nodeDots = {}
FT.nodeDots = nodeDots
function FT.DrawNodes(mapID)
 for _, d in ipairs(nodeDots) do d:Hide() end
 nodeList()
 if ForeverTrailSettings.nodes == false or not mapID then return end
 local parts = FT.mapParts
 local overlay = parts and parts.overlay
 if not overlay then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local used = 0
 for _, n in ipairs(nodeList()) do
  if n.map == mapID and used < 200 then
   local known = false
   for _, id in ipairs(GATHER[n.kind] or {}) do if spellKnown(id) then known = true end end
   if known then
    used = used + 1
    local d = nodeDots[used]
    if not d then
     d = overlay:CreateTexture(nil, 'ARTWORK')
     d:SetTexture('Interface\\Cooldown\\star4')
     nodeDots[used] = d
    end
    local c = KIND_COLOR[n.kind] or {1, 1, 1}
    local diff = FT.GatherDifficulty and FT.GatherDifficulty(n.kind, n.name)
    d:SetSize(12 * FT.Scale('mapIcons'), 12 * FT.Scale('mapIcons'))
    d:SetVertexColor(c[1], c[2], c[3], (diff == 'gray' or diff == 'red') and 0.3 or 0.95)
    d:ClearAllPoints(); d:SetPoint('CENTER', overlay, 'TOPLEFT', n.x * w, -n.y * h)
    d.step = {x=n.x, y=n.y, uiMapID=n.map, questTitle=n.name, text=(KIND_LABEL[n.kind] or 'Düğüm') .. ' (topladığın yer)', type='manual'}
    d:Show()
   end
  end
 end
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local events = CreateFrame('Frame')
for event in pairs(learnEvents) do pcall(events.RegisterEvent, events, event) end
for _, e in ipairs({'GOSSIP_POI_UPDATE', 'PLAYER_UPDATE_RESTING', 'ZONE_CHANGED_NEW_AREA', 'UNIT_SPELLCAST_SENT', 'UNIT_SPELLCAST_SUCCEEDED'}) do
 pcall(events.RegisterEvent, events, e)
end
events:SetScript('OnEvent', function(_, event, a, b, c, d)
 local ok, err = pcall(function()
  if learnEvents[event] then learnEvents[event](a, b)
  elseif event == 'GOSSIP_POI_UPDATE' then onGossipPoi(a)
  elseif event == 'PLAYER_UPDATE_RESTING' or event == 'ZONE_CHANGED_NEW_AREA' then
   if IsResting and IsResting() then
    if C_Timer and C_Timer.After then C_Timer.After(1.5, onEnterCity) else onEnterCity() end
   end
  elseif event == 'UNIT_SPELLCAST_SENT' and a == 'player' then
   local kind = kindOfSpell(d)
   pendingGather = kind and {kind=kind, name=b} or nil
  elseif event == 'UNIT_SPELLCAST_SUCCEEDED' and a == 'player' then
   local kind = kindOfSpell(c)
   if kind and pendingGather and pendingGather.kind == kind then
    FT.RecordNode(kind, pendingGather.name)
    pendingGather = nil
    if FT.RefreshMap and WorldMapFrame and WorldMapFrame:IsShown() then FT.RefreshMap() end
   end
  end
 end)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'places: ' .. tostring(err) end
end)

events:SetScript('OnUpdate', function(_, dt)
 acc = acc + dt
 if acc < 2 then return end
 acc = 0
 pcall(proximityCheck)
end)
