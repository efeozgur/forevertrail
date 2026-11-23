local _, FT = ...

-- Harita gösterim modu, görev ansiklopedisi, ön koşul bulucu, yaratığın düşürdüğü görev eşyaları,
-- seviyeye kalan yaratık sayısı, haritada zindan simgeleri, Türkçe görev okuma penceresi.

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function db() return FT.Module and FT.Module('QuestieDB') end
local function zone() return FT.Module and FT.Module('ZoneDB') end
local function title(id) return FT.QuestTitle and FT.QuestTitle(id) or ('Görev ' .. id) end

----------------------------------------------------------------------
-- 1) Harita gösterim modu: tümü / takip edilen / odak / kapalı
----------------------------------------------------------------------
FT.MapModes = {
 {key='all', label='Tüm görevler'},
 {key='tracked', label='Takip edilen'},
 {key='focus', label='Yalnızca odak'},
 {key='off', label='Bölgeler kapalı'},
}
function FT.MapMode() return ForeverTrailSettings and ForeverTrailSettings.c_mapMode or 'all' end

local function watched(questId)
 local q = C_QuestLog
 local index = q and q.GetLogIndexForQuestID and q.GetLogIndexForQuestID(questId)
 if q and q.IsQuestWatched then local ok, v = pcall(q.IsQuestWatched, questId) if ok and v ~= nil then return v end end
 if index and IsQuestWatched then local ok, v = pcall(IsQuestWatched, index) if ok then return v end end
 return true
end

-- Hedef bölgesi bu modda çizilsin mi?
function FT.ShowObjectiveOnMap(questId)
 local mode = FT.MapMode()
 if mode == 'off' then return false end
 if mode == 'focus' then
  local f = FT.focusQuest or (FT.CurrentStep and FT.CurrentStep() and FT.CurrentStep().questId)
  return f == questId
 end
 if mode == 'tracked' then return watched(questId) end
 return true
end

function FT.CycleMapMode()
 local cur, idx = FT.MapMode(), 1
 for i, m in ipairs(FT.MapModes) do if m.key == cur then idx = i end end
 local nextMode = FT.MapModes[idx % #FT.MapModes + 1]
 ForeverTrailSettings.c_mapMode = nextMode.key
 if FT.BumpLayers then FT.BumpLayers() end
 if FT.RefreshMap and WorldMapFrame and WorldMapFrame:IsShown() then pcall(FT.RefreshMap) end
 return nextMode.label
end

----------------------------------------------------------------------
-- 3) Ön koşul bulucu: "bu görevi neden alamıyorum?"
----------------------------------------------------------------------
local function completed(id)
 local q = C_QuestLog
 return (FT.turnedIn and FT.turnedIn[id]) or (q and q.IsQuestFlaggedCompleted and q.IsQuestFlaggedCompleted(id) == true)
end
local function inLog(id)
 local q = C_QuestLog
 local i = q and q.GetLogIndexForQuestID and q.GetLogIndexForQuestID(id)
 return i and i > 0
end
local function hasBit(mask, bit)
 if type(mask) ~= 'number' or mask == 0 then return true end
 return math.floor(mask / 2 ^ bit) % 2 == 1
end

-- Dönüş: durum metni, eksik ön koşul görevi (varsa)
function FT.QuestStatus(id)
 local q = FT.DBQ and FT.DBQ[id]
 if not q then return 'Veride yok' end
 if completed(id) then return '|cff55ff55Tamamlandı|r' end
 if inLog(id) then return '|cffffd100Günlüğünde|r' end
 local level = UnitLevel('player') or 1
 if (q[4] or 1) > level then return ('|cffff7070Seviye %d gerekli|r'):format(q[4]) end
 local raceId = select(3, UnitRace('player')) or 0
 local classId = select(3, UnitClass('player')) or 0
 if not hasBit(q[6], raceId - 1) then return '|cff9d9d9dIrkın için değil|r' end
 if not hasBit(q[7], classId - 1) then return '|cff9d9d9dSınıfın için değil|r' end
 local visited = {}
 local function missing(qid, depth)
  if depth > 15 or visited[qid] then return nil end
  visited[qid] = true
  local row = FT.DBQ[qid]
  if not row then return nil end
  if type(row[11]) == 'table' and #row[11] > 0 then
   local any = false
   for _, p in ipairs(row[11]) do if completed(p) then any = true end end
   if not any then
    local p = row[11][1]
    return missing(p, depth + 1) or p
   end
  end
  if type(row[10]) == 'table' then
   for _, p in ipairs(row[10]) do if not completed(p) then return missing(p, depth + 1) or p end end
  end
 end
 local need = missing(id, 0)
 if need and need ~= id then
  if inLog(need) then return ('|cffffd100Önce bitir:|r %s (günlüğünde)'):format(title(need)), need end
  return ('|cffffd100Önce yap:|r %s'):format(title(need)), need
 end
 if type(q[12]) == 'table' then for _, p in ipairs(q[12]) do if completed(p) then return '|cff9d9d9dAlternatif görevi yaptın|r' end end end
 return '|cff55ff55Alınabilir|r'
end

local function giverPoint(id)
 local pts = FT.GiverPoints and FT.GiverPoints(id, nil, false) or {}
 local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
 for _, p in ipairs(pts) do if p.map == map then return p end end
 return pts[1]
end

function FT.GoToQuest(id)
 local status, need = FT.QuestStatus(id)
 local target = need or id
 local p = giverPoint(target)
 if not p then return FT.Print('Görevi verenin yeri veride yok.') end
 FT.SetCustomTarget(p.map, p.x, p.y, title(target))
 if need then FT.Print(('Ön koşul: %s — ok onu verene gidiyor.'):format(title(need))) end
end

----------------------------------------------------------------------
-- 2) Görev ansiklopedisi (ana pencerede sayfa)
----------------------------------------------------------------------
local enc
local FILTERS = {
 {key='all', label='Tümü'}, {key='avail', label='Alınabilir'}, {key='log', label='Günlükte'}, {key='done', label='Bitti'}, {key='new', label='Forever yeni'},
}
local function questZoneMap(row)
 local z = zone()
 local area = row[13]
 return type(area) == 'number' and area > 0 and z and z:GetUiMapIdByAreaId(area) or nil
end

local function buildList()
 local text = (enc.search:GetText() or ''):lower()
 local filter, here = enc.filter, enc.hereOnly
 local map = here and C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
 local avail = FT.Module and FT.Module('AvailableQuests')
 local availSet = filter == 'avail' and avail and avail.__availableQuests or nil
 local out = {}
 for id, row in pairs(FT.DBQ or {}) do
  local name = row[1] or ''
  local tr = title(id)
  if text == '' or name:lower():find(text, 1, true) or tr:lower():find(text, 1, true) or tostring(id) == text then
   local ok = true
   if filter == 'avail' then ok = availSet and availSet[id]
   elseif filter == 'log' then ok = inLog(id)
   elseif filter == 'done' then ok = completed(id)
   elseif filter == 'new' then ok = FT.IsNewQuest and FT.IsNewQuest(id) end
   if ok and map then ok = questZoneMap(row) == map or (giverPoint(id) and giverPoint(id).map == map) end
   if ok then out[#out + 1] = {id=id, level=row[5] or 0, name=tr} end
  end
  if #out >= 400 then break end
 end
 table.sort(out, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.name < b.name end)
 return out
end

local function showDetail(id)
 enc.selected = id
 local row = FT.DBQ[id]
 if not row then return end
 local status = FT.QuestStatus(id)
 local lines = {('|cffffd100[%d] %s|r  %s'):format(row[5] or 0, title(id), (FT.IsNewQuest and FT.IsNewQuest(id)) and FT.NEW_TAG or '')}
 lines[#lines + 1] = 'Durum: ' .. status
 local p = giverPoint(id)
 if p then lines[#lines + 1] = ('Veren: %s — %s %.1f, %.1f'):format(p.name or '?', FT.MapName and FT.MapName(p.map) or '', p.x * 100, p.y * 100) end
 local xpText = FT.QuestXPText and FT.QuestXPText(id)
 if xpText then lines[#lines + 1] = 'Ödül: ' .. xpText end
 local rewards = FT.QuestRewards and FT.QuestRewards(id) or {}
 if #rewards > 0 then
  local names = {}
  for i = 1, math.min(3, #rewards) do local it = FT.DBI[rewards[i]]; names[#names + 1] = it and it[1] or '?' end
  lines[#lines + 1] = 'Eşya ödülü: ' .. table.concat(names, ', ')
 end
 if row[8] then lines[#lines + 1] = '|cffc8c0b0' .. row[8]:sub(1, 160) .. '|r' end
 enc.detail:SetText(table.concat(lines, '\n'))
 enc.go:Show()
end

local function refreshList()
 if not enc then return end
 enc.list = buildList()
 enc.page = math.max(1, math.min(enc.page, math.ceil(math.max(1, #enc.list) / #enc.rows)))
 for i, r in ipairs(enc.rows) do
  local e = enc.list[(enc.page - 1) * #enc.rows + i]
  r.entry = e
  if e then
   local new = FT.IsNewQuest and FT.IsNewQuest(e.id)
   r.text:SetText(('[%d] %s%s'):format(e.level, e.name, new and '  |cff6fd8ffYeni|r' or ''))
   r:Show()
  else r:Hide() end
 end
 enc.count:SetText(('%d görev  (%d/%d)'):format(#enc.list, enc.page, math.max(1, math.ceil(#enc.list / #enc.rows))))
 for _, b in ipairs(enc.filterButtons) do if b.key == enc.filter then b:Disable() else b:Enable() end end
 enc.here:SetText(enc.hereOnly and 'Bu bölge' or 'Her yer')
end
FT.RefreshEncyclopedia = refreshList

function FT.BuildEncyclopedia(holder)
 if enc or not holder then return end
 enc = {filter='all', hereOnly=true, page=1, filterButtons={}}
 enc.search = (FT.Kit and FT.Kit.Input(holder) or CreateFrame('EditBox', nil, holder, 'InputBoxTemplate'))
 enc.search:SetSize(250, 20); enc.search:SetPoint('TOPLEFT', 8, -2); enc.search:SetAutoFocus(false)
 enc.search:SetScript('OnTextChanged', function() enc.page = 1; refreshList() end)
 enc.search:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
 enc.here = FT.NewButton(holder, 'Bu bölge', 90, 20); enc.here:SetPoint('LEFT', enc.search, 'RIGHT', 8, 0)
 enc.here:SetScript('OnClick', function() enc.hereOnly = not enc.hereOnly; enc.page = 1; refreshList() end)
 for i, f in ipairs(FILTERS) do
  local b = FT.NewButton(holder, f.label, 84, 20); b:SetPoint('TOPLEFT', (i - 1) * 88, -28)
  b.key = f.key; b:SetScript('OnClick', function() enc.filter = f.key; enc.page = 1; refreshList() end)
  enc.filterButtons[i] = b
 end
 enc.rows = {}
 for i = 1, 12 do
  local r = CreateFrame('Button', nil, holder); r:SetSize(440, 20); r:SetPoint('TOPLEFT', 0, -54 - (i - 1) * 21)
  r.bg = r:CreateTexture(nil, 'BACKGROUND'); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)
  r:SetHighlightTexture('Interface\\Buttons\\WHITE8X8'); r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
  r.text = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall'); r.text:SetPoint('LEFT', 6, 0); r.text:SetWidth(430); r.text:SetJustifyH('LEFT'); r.text:SetWordWrap(false)
  r:SetScript('OnClick', function(self) if self.entry then showDetail(self.entry.id) end end)
  enc.rows[i] = r
 end
 local y = -54 - 12 * 21 - 4
 local prev = FT.NewButton(holder, '<', 28, 20); prev:SetPoint('TOPLEFT', 0, y)
 prev:SetScript('OnClick', function() enc.page = enc.page - 1; refreshList() end)
 local nextB = FT.NewButton(holder, '>', 28, 20); nextB:SetPoint('TOPLEFT', 32, y)
 nextB:SetScript('OnClick', function() enc.page = enc.page + 1; refreshList() end)
 enc.count = holder:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall'); enc.count:SetPoint('TOPLEFT', 68, y - 4)
 local line = holder:CreateTexture(nil, 'ARTWORK'); line:SetPoint('TOPLEFT', 0, y - 26); line:SetSize(440, 1)
 if FT.RegisterAccent then FT.RegisterAccent(line, 0.6) end
 enc.detail = holder:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
 enc.detail:SetPoint('TOPLEFT', 4, y - 34); enc.detail:SetWidth(432); enc.detail:SetJustifyH('LEFT'); enc.detail:SetJustifyV('TOP')
 enc.detail:SetText('Bir göreve tıkla: durumu, veren, ödülü ve neden alınamadığı burada görünür.')
 enc.go = FT.NewButton(holder, 'Yol göster (ön koşul dahil)', 200, 22); enc.go:SetPoint('BOTTOMLEFT', 0, 4)
 enc.go:SetScript('OnClick', function() if enc.selected then FT.GoToQuest(enc.selected) end end)
 enc.go:Hide()
 holder:HookScript('OnShow', refreshList)
 if FT.FixFonts then FT.FixFonts(holder) end
end

----------------------------------------------------------------------
-- 4) Yaratığın düşürdüğü görev eşyaları (fare ipucu)
----------------------------------------------------------------------
local dropsByNpc
local function dropsOf(npcId)
 if not dropsByNpc then
  dropsByNpc = {}
  for itemId, it in pairs(FT.DBI or {}) do
   if type(it[2]) == 'table' and #it[2] <= 12 then
    for _, n in ipairs(it[2]) do dropsByNpc[n] = dropsByNpc[n] or {}; table.insert(dropsByNpc[n], itemId) end
   end
  end
 end
 return dropsByNpc[npcId]
end
FT.DropsOf = dropsOf

local function unitDropLines(tip)
 if not on('mobloot') then return end
 local _, unit = tip:GetUnit()
 if not unit or UnitIsPlayer(unit) then return end
 local guid = UnitGUID(unit)
 local npcId = guid and tonumber((select(6, strsplit('-', guid))))
 local items = npcId and dropsOf(npcId)
 if not items then return end
 local wanted = {}
 for _, o in ipairs(FT.ActiveObjectives and FT.ActiveObjectives() or {}) do if o.itemId and not o.done then wanted[o.itemId] = o end end
 local shown = 0
 for _, itemId in ipairs(items) do
  if shown < 3 then
   local it = FT.DBI[itemId]
   local o = wanted[itemId]
   if o or shown < 2 then
    shown = shown + 1
    tip:AddLine(('|cffffd100[ForeverTrail]|r Düşürür: %s%s'):format(it and it[1] or '?', o and (' |cff55ff55(görevin: %d/%d)|r'):format(o.have, o.need) or ''), 1, 1, 1)
   end
  end
 end
 if shown > 0 then if tip == GameTooltip and FT.ShowTip then FT.ShowTip(tip) else tip:Show() end end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
 pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tip) if tip == GameTooltip then pcall(unitDropLines, tip) end end)
elseif GameTooltip and GameTooltip.HookScript then
 pcall(GameTooltip.HookScript, GameTooltip, 'OnTooltipSetUnit', function(tip) pcall(unitDropLines, tip) end)
end

----------------------------------------------------------------------
-- 5) Seviyeye kalan yaratık sayısı (son öldürmelerin XP ortalaması)
----------------------------------------------------------------------
local killXP, lastXP, lastTurnIn = {}, nil, -10
function FT.KillsToLevel()
 if #killXP == 0 then return nil end
 local sum = 0
 for _, v in ipairs(killXP) do sum = sum + v end
 local avg = sum / #killXP
 local left = UnitXPMax('player') - UnitXP('player')
 if avg <= 0 then return nil end
 return math.ceil(left / avg), math.floor(avg + 0.5)
end

----------------------------------------------------------------------
-- 6) Dünya haritasında zindan simgeleri
----------------------------------------------------------------------
local dungeonDots = {}
FT.dungeonDots = dungeonDots
function FT.DrawDungeons(mapID)
 for _, d in ipairs(dungeonDots) do d:Hide() end
 local parts = FT.mapParts
 local overlay = parts and parts.overlay
 local z = zone()
 if not (overlay and mapID and on('dungeonicons') and z) then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local used = 0
 for id, d in pairs(FT.DBDungeons or {}) do
  if FT.DungeonAllowed and FT.DungeonAllowed(id, d) then
  for _, loc in ipairs(d[4] or {}) do
   if z:GetUiMapIdByAreaId(loc[1]) == mapID and used < 30 then
    used = used + 1
    local t = dungeonDots[used]
    if not t then
     t = CreateFrame('Frame', nil, overlay)
     t.glow = t:CreateTexture(nil, 'BACKGROUND'); t.glow:SetTexture('Interface\\CHARACTERFRAME\\TempPortraitAlphaMask'); t.glow:SetPoint('CENTER')
     t.icon = t:CreateTexture(nil, 'ARTWORK'); t.icon:SetAllPoints(); t.icon:SetTexture('Interface\\Icons\\INV_Misc_Head_Dragon_01'); t.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
     dungeonDots[used] = t
    end
    local sc = 20 * (FT.Scale and FT.Scale('mapIcons') or 1)
    t:SetSize(sc, sc); t.glow:SetSize(sc * 1.5, sc * 1.5); t.glow:SetVertexColor(0.85, 0.3, 0.3, 0.9)
    t:SetFrameLevel(overlay:GetFrameLevel() + 4)
    t:ClearAllPoints(); t:SetPoint('CENTER', overlay, 'TOPLEFT', loc[2] / 100 * w, -loc[3] / 100 * h)
    t.step = {x=loc[2] / 100, y=loc[3] / 100, uiMapID=mapID, questTitle=d[1], text='Zindan girişi — Araçlar > Zindan rehberi', type='location'}
    t:Show()
   end
  end
  end
 end
end

----------------------------------------------------------------------
-- 7) Türkçe görev okuma penceresi
----------------------------------------------------------------------
local reader
local function ensureReader()
 if reader then return reader end
 reader = FT.NewWindow('ForeverTrailReader', UIParent)
 reader:SetSize(380, 420); reader:SetFrameStrata('DIALOG')
 reader:SetPoint('TOPLEFT', QuestFrame or UIParent, QuestFrame and 'TOPRIGHT' or 'CENTER', 4, 0)
 reader.title = reader:CreateFontString(nil, 'OVERLAY'); reader.title:SetPoint('TOP', 0, -8); reader.title:SetWidth(340)
 reader.title:SetFont(FT.FontPath(), 15, 'OUTLINE')
 reader.meta = reader:CreateFontString(nil, 'OVERLAY'); reader.meta:SetPoint('TOPLEFT', 18, -34); reader.meta:SetWidth(344); reader.meta:SetJustifyH('LEFT')
 reader.meta:SetFont(FT.FontPath(), 11, ''); reader.meta:SetTextColor(0.75, 0.72, 0.66)
 reader.body = reader:CreateFontString(nil, 'OVERLAY'); reader.body:SetPoint('TOPLEFT', 18, -56); reader.body:SetWidth(344); reader.body:SetJustifyH('LEFT'); reader.body:SetJustifyV('TOP')
 reader.body:SetHeight(250); reader.body:SetFont(FT.FontPath(), 13, ''); reader.body:SetSpacing(3); reader.body:SetTextColor(1, 0.95, 0.85)
 reader.goal = reader:CreateFontString(nil, 'OVERLAY'); reader.goal:SetPoint('TOPLEFT', 18, -314); reader.goal:SetWidth(344); reader.goal:SetJustifyH('LEFT')
 reader.goal:SetFont(FT.FontPath(), 12, '')
 local accept = FT.NewButton(reader, 'Kabul et', 120, 26); accept:SetPoint('BOTTOMLEFT', 18, 14)
 accept:SetScript('OnClick', function() if AcceptQuest then AcceptQuest() end reader:Hide() end)
 local decline = FT.NewButton(reader, 'Reddet', 120, 26); decline:SetPoint('BOTTOMRIGHT', -18, 14)
 decline:SetScript('OnClick', function() if DeclineQuest then DeclineQuest() end reader:Hide() end)
 reader:Hide()
 return reader
end

local function showReader()
 if not on('reader') then return end
 local id = GetQuestID and GetQuestID()
 local tr = type(QTR_QuestData) == 'table' and id and QTR_QuestData[tostring(id)]
 local r = ensureReader()
 local name = (type(tr) == 'table' and tr.Title) or (GetTitleText and GetTitleText()) or ''
 local body = (type(tr) == 'table' and (tr.Description or tr.Details)) or (GetQuestText and GetQuestText()) or ''
 local goal = (type(tr) == 'table' and tr.Objectives) or (GetObjectiveText and GetObjectiveText()) or ''
 body = body:gsub('%$[Nn]', UnitName('player') or ''):gsub('%$[Bb]', '\n')
 r.title:SetText(name)
 local a = FT.Style.accent; r.title:SetTextColor(a[1], a[2], a[3])
 local row = id and FT.DBQ and FT.DBQ[id]
 local xpDB = FT.Module and FT.Module('QuestXP')
 local xp = id and xpDB and xpDB:GetQuestLogRewardXP(id)
 r.meta:SetText(('Seviye %s%s%s'):format(row and row[5] or '?', xp and ('  •  %d XP'):format(xp) or '', (id and FT.IsNewQuest and FT.IsNewQuest(id)) and ('  •  ' .. FT.NEW_TAG) or ''))
 r.body:SetText(body)
 r.goal:SetText('|cffffd100Görev:|r ' .. goal)
 r:Show()
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local events = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_ENTERING_WORLD', 'PLAYER_XP_UPDATE', 'QUEST_TURNED_IN', 'QUEST_DETAIL', 'QUEST_FINISHED', 'QUEST_ACCEPTED'}) do pcall(events.RegisterEvent, events, e) end
events:SetScript('OnEvent', function(_, event)
 local ok, err = pcall(function()
  if event == 'PLAYER_ENTERING_WORLD' then lastXP = UnitXP('player')
  elseif event == 'QUEST_TURNED_IN' then lastTurnIn = GetTime()
  elseif event == 'PLAYER_XP_UPDATE' then
   local xp = UnitXP('player')
   if lastXP and xp > lastXP and GetTime() - lastTurnIn > 2 then
    killXP[#killXP + 1] = xp - lastXP
    while #killXP > 12 do table.remove(killXP, 1) end
   end
   lastXP = xp
  elseif event == 'QUEST_DETAIL' then
   if FT.Assisting and FT.Assisting() then return end
   if C_Timer and C_Timer.After then C_Timer.After(0.05, function() if QuestFrame and QuestFrame:IsShown() then pcall(showReader) end end) else showReader() end
  elseif event == 'QUEST_FINISHED' or event == 'QUEST_ACCEPTED' then if reader then reader:Hide() end
  end
 end)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'atlas: ' .. tostring(err) end
end)

----------------------------------------------------------------------
-- Zindan verisi tüm genişlemeleri içeriyor: yalnızca klasik zindan ve baskınlar gösterilir
-- (Darkmoon Faire Island, Outland/Northrend vb. elenir; aynı adlı sonraki sürümler tek kayda iner)
----------------------------------------------------------------------
local CLASSIC = {}
for _, n in ipairs({'Ragefire Chasm', 'Wailing Caverns', 'The Deadmines', 'Shadowfang Keep', 'Blackfathom Deeps', 'The Stockade',
 'Gnomeregan', 'Razorfen Kraul', 'Scarlet Monastery', 'Razorfen Downs', 'Uldaman', "Zul'Farrak", 'Maraudon',
 "The Temple of Atal'Hakkar", 'Blackrock Depths', 'Blackrock Spire', 'Dire Maul', 'Stratholme', 'Scholomance',
 'Molten Core', "Onyxia's Lair", 'Blackwing Lair', "Zul'Gurub", "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj", 'Naxxramas'}) do CLASSIC[n] = true end
local allowed
local function build()
 allowed = {}
 local first = {}
 for id, d in pairs(FT.DBDungeons or {}) do
  local name = d[1]
  if CLASSIC[name] and (not first[name] or id < first[name]) then first[name] = id end
 end
 for _, id in pairs(first) do allowed[id] = true end
end
function FT.ResetDungeonFilter() allowed = nil end
function FT.DungeonAllowed(id)
 if not allowed then build() end
 return allowed[id] == true
end
