local _, FT = ...

-- Forever (Mainline altyapısı): eski global GetItemInfo olmayabilir; C_Item.GetItemInfo kullanılır
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local QUESTION = 'Interface\\Icons\\INV_Misc_QuestionMark'
local turkishFont = 'Interface\\AddOns\\WoWTR\\Assets\\Fonts\\frizquadrata_tr.ttf'

local function applyFont(label)
 if not label then return end
 local path, size, flags = label:GetFont()
 if size and label:SetFont(turkishFont, size, flags or '') == false and path then label:SetFont(path, size, flags or '') end
end

local function module(name)
 if FT.Module then local own = FT.Module(name) if own then return own end end
 if not (QuestieLoader and QuestieLoader.ImportModule) then return nil end
 local ok, result = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
 if ok then return result end
end

local function query(db, id, key)
 if not (db and db.QueryQuestSingle) then return nil end
 local ok, value = pcall(db.QueryQuestSingle, id, key)
 if ok then return value end
end

-- "Plainstrider Meat: 3/7" -> "Plainstrider Meat"
function FT.ParseObjective(text)
 if type(text) ~= 'string' then return '' end
 return (text:gsub('%s*:?%s*%d+%s*/%s*%d+%s*$', ''))
end

-- Adıma ait hedef varlıkların listesi: {kind='npc'|'object'|'item', id=sayı}
function FT.TargetsFor(step)
 local out = {}
 if not step or not step.questId then return out end
 local db = module('QuestieDB')
 if step.type == 'accept' or step.type == 'turnin' then
  local list = query(db, step.questId, step.type == 'accept' and 'startedBy' or 'finishedBy')
  local npcs = type(list) == 'table' and list[1]
  if type(npcs) == 'table' then
   for _, id in ipairs(npcs) do if type(id) == 'number' then out[#out+1] = {kind='npc', id=id} end end
  end
  return out
 end
 local raw = query(db, step.questId, 'objectives')
 if type(raw) == 'table' then
  local kinds = {'npc', 'object', 'item'}
  for group, kind in ipairs(kinds) do
   local rows = raw[group]
   if type(rows) == 'table' then
    for _, row in ipairs(rows) do
     if type(row) == 'table' and type(row[1]) == 'number' then out[#out+1] = {kind=kind, id=row[1]} end
    end
   end
  end
 end
 return out
end

local function itemIcon(id)
 local ok, icon = pcall(function()
  if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
  if GetItemIcon then return GetItemIcon(id) end
 end)
 return ok and icon or QUESTION
end

local function solid(parent, layer, w, h, point, x, y, r, g, b, a)
 local t = parent:CreateTexture(nil, layer or 'ARTWORK')
 t:SetSize(w, h); t:SetPoint(point, x, y); t:SetColorTexture(r, g, b, a or 1)
 return t
end

local function newWindow(name, parent)
 if FT.NewWindow then return FT.NewWindow(name, parent) end
 return CreateFrame('Frame', name, parent, 'BasicFrameTemplateWithInset')
end

local ROWS = 5
local card, shownKey
local AMBER = {0.82, 0.64, 0.32}

local function borderFrame(parent, w, h, edgeSize)
 local f = CreateFrame('Frame', nil, parent, BackdropTemplateMixin and 'BackdropTemplate' or nil)
 f:SetSize(w, h)
 if f.SetBackdrop then
  f:SetBackdrop({edgeFile='Interface\\Tooltips\\UI-Tooltip-Border', edgeSize=edgeSize or 14})
  f:SetBackdropBorderColor(AMBER[1], AMBER[2], AMBER[3], 1)
 end
 return f
end

local function setBorder(f, r, g, b)
 if f and f.SetBackdropBorderColor then f:SetBackdropBorderColor(r, g, b, 1) end
end

local function qualityColor(itemId)
 local ok, quality = pcall(function() local _, _, q = GetItemInfo(itemId); return q end)
 if ok and quality and GetItemQualityColor then
  local good, r, g, b = pcall(GetItemQualityColor, quality)
  if good and r then return r, g, b end
 end
 return AMBER[1], AMBER[2], AMBER[3]
end

local entityCache = {}
-- Hedef varlığın adı, türü ve seviye aralığı (gömülü görev verisi)
function FT.EntityInfo(target, step)
 if not target then return nil end
 local key = target.kind .. ':' .. target.id .. ':' .. tostring(step and step.type)
 if entityCache[key] then return entityCache[key] end
 local db = module('QuestieDB')
 if not db then return nil end
 local function single(fn, id, field)
  if not fn then return nil end
  local ok, value = pcall(fn, id, field)
  if ok then return value end
 end
 local info = {}
 if target.kind == 'npc' then
  info.name = single(db.QueryNPCSingle, target.id, 'name')
  local low, high = single(db.QueryNPCSingle, target.id, 'minLevel'), single(db.QueryNPCSingle, target.id, 'maxLevel')
  if type(low) == 'number' and low > 0 then info.level = (type(high) == 'number' and high ~= low) and (low .. '-' .. high) or tostring(low) end
  info.label = step and step.type == 'accept' and 'Görevi veren' or (step and step.type == 'turnin' and 'Teslim edilecek NPC' or 'Yaratık')
 elseif target.kind == 'object' then
  info.name = single(db.QueryObjectSingle, target.id, 'name')
  info.label = 'Nesne'
 else
  info.name = single(db.QueryItemSingle, target.id, 'name')
  info.label = 'Eşya'
 end
 if type(info.name) ~= 'string' or info.name == '' then return nil end
 entityCache[key] = info
 return info
end

-- Görev seviyesi ve XP ödülü
function FT.QuestMeta(questId)
 local level = query(module('QuestieDB'), questId, 'questLevel')
 local xp
 local xpDB = module('QuestXP')
 if xpDB and xpDB.db and xpDB.db[questId] and xpDB.GetQuestLogRewardXP then
  local ok, value = pcall(xpDB.GetQuestLogRewardXP, xpDB, questId, false)
  if ok and type(value) == 'number' and value > 0 then xp = value end
 end
 return type(level) == 'number' and level > 0 and level or nil, xp
end

-- Noktaları bölgeye göre özetler: "Mulgore, Thunder Bluff (24 nokta)"
function FT.SummarizeSpawns(points, nameOf)
 if type(points) ~= 'table' or #points == 0 then return 'Konum bilinmiyor' end
 local counts, order = {}, {}
 for _, p in ipairs(points) do
  if not counts[p.map] then counts[p.map] = 0; order[#order + 1] = p.map end
  counts[p.map] = counts[p.map] + 1
 end
 table.sort(order, function(a, b) if counts[a] ~= counts[b] then return counts[a] > counts[b] end return a < b end)
 local names = {}
 for i = 1, math.min(2, #order) do names[#names + 1] = (nameOf and nameOf(order[i])) or tostring(order[i]) end
 return ('%s (%d nokta)'):format(table.concat(names, ', '), #points)
end

local descCache = {}
local function cleanText(text)
 if type(text) ~= 'string' or text == '' then return nil end
 text = text:gsub('%$[Bb]', ' '):gsub('%$[Nn]', UnitName and UnitName('player') or ''):gsub('%s+', ' ')
 if text:find('%$') or text == ' ' then return nil end
 return text
end

-- Görevin durumuna göre açıklama: hikaye (alınmamış), hedef metni (aktif), teslim metni (hazır).
local function logTexts(questId)
 local q = C_QuestLog
 local index = q and q.GetLogIndexForQuestID and q.GetLogIndexForQuestID(questId)
 if not (index and index > 0 and SelectQuestLogEntry and GetQuestLogQuestText) then return nil end
 local previous = GetQuestLogSelection and GetQuestLogSelection()
 local ok, description, objectives = pcall(function() SelectQuestLogEntry(index); return GetQuestLogQuestText() end)
 if previous and previous > 0 then pcall(SelectQuestLogEntry, previous) end
 if ok then return cleanText(description), cleanText(objectives) end
end

function FT.QuestDescription(questId, status)
 if type(questId) ~= 'number' then return nil end
 status = status or 'not_taken'
 if status == 'turned_in' then return 'Bu görev teslim edildi.' end
 local record = type(QTR_QuestData) == 'table' and QTR_QuestData[tostring(questId)]
 local function field(...)
  if type(record) ~= 'table' then return nil end
  for _, key in ipairs({...}) do
   local text = cleanText(record[key])
   if text then return text end
  end
 end
 local key = questId .. ':' .. status
 if status == 'ready' then
  return field('Completion', 'Progress') or 'Tüm hedefler tamam. Görevi verene dönüp teslim et.'
 end
 if status == 'active' then
  if descCache[key] then return descCache[key] end
  local text = field('Objectives')
  if not text then local _, objectives = logTexts(questId); text = objectives end
  text = text or field('Description', 'Details') or select(1, logTexts(questId))
  if text then descCache[key] = text end
  return text
 end
 local text = field('Description', 'Details')
 if text then return text end
 if descCache[key] then return descCache[key] end
 text = select(1, logTexts(questId))
 if text then descCache[key] = text end
 return text
end

function FT.CreateTargetCard()
 if card or not FT.panel then return end
 card = newWindow('ForeverTrailCard', FT.panel)
 FT.card = card
 card:SetSize(230, 478)
 card:SetPoint('TOPRIGHT', FT.panel, 'TOPLEFT', -4, 0)
 card.title = card:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 card.title:SetPoint('TOP', 0, -7); card.title:SetText('Hedef'); applyFont(card.title); card.title:SetTextColor(1, 0.82, 0.45)
 solid(card, 'ARTWORK', 206, 124, 'TOPLEFT', 12, -30, 0.07, 0.04, 0.02, 0.5)
 card.spot = card:CreateTexture(nil, 'ARTWORK')
 card.spot:SetTexture('Interface\\Cooldown\\star4'); card.spot:SetBlendMode('ADD'); card.spot:SetSize(150, 150)
 card.spot:SetPoint('CENTER', card, 'TOPLEFT', 115, -92); card.spot:SetAlpha(0.3)
 local ok, model = pcall(CreateFrame, 'PlayerModel', nil, card)
 if ok and model then
  card.model = model
  model:SetSize(200, 118); model:SetPoint('TOPLEFT', 15, -33)
 end
 card.icon = card:CreateTexture(nil, 'OVERLAY')
 card.icon:SetSize(64, 64); card.icon:SetPoint('TOPLEFT', 83, -58); card.icon:SetTexture(QUESTION)
 card.ring = borderFrame(card, 78, 78, 12)
 card.ring:SetPoint('CENTER', card.icon, 'CENTER')
 card.art = borderFrame(card, 210, 128, 14)
 card.art:SetPoint('TOPLEFT', 10, -28)
 card.badge = card:CreateTexture(nil, 'OVERLAY')
 card.badge:SetSize(34, 34); card.badge:SetPoint('TOPLEFT', 176, -114)
 card.badgeRing = borderFrame(card, 42, 42, 10)
 card.badgeRing:SetPoint('CENTER', card.badge, 'CENTER')
 card.badge:Hide(); card.badgeRing:Hide()
 card.name = card:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 card.name:SetPoint('TOPLEFT', 14, -160); card.name:SetWidth(202); card.name:SetJustifyH('LEFT'); applyFont(card.name); card.name:SetTextColor(1, 0.88, 0.6)
 card.kind = card:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 card.kind:SetPoint('TOPLEFT', 14, -176); card.kind:SetWidth(202); card.kind:SetJustifyH('LEFT'); applyFont(card.kind); card.kind:SetTextColor(0.78, 0.72, 0.64)
 card.zone = card:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 card.zone:SetPoint('TOPLEFT', 14, -190); card.zone:SetWidth(202); card.zone:SetJustifyH('LEFT'); applyFont(card.zone); card.zone:SetTextColor(0.78, 0.72, 0.64)
 local divider = solid(card, 'ARTWORK', 202, 1, 'TOPLEFT', 14, -206, 0.95, 0.72, 0.35, 0.45)
 if FT.RegisterAccent then FT.RegisterAccent(divider, 0.45) end
 card.quest = card:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
 card.quest:SetPoint('TOPLEFT', 14, -212); card.quest:SetWidth(202); card.quest:SetHeight(26); card.quest:SetJustifyH('LEFT'); card.quest:SetJustifyV('TOP')
 applyFont(card.quest); card.quest:SetTextColor(0.98, 0.8, 0.4)
 card.desc = card:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 card.desc:SetPoint('TOPLEFT', 14, -242); card.desc:SetWidth(202); card.desc:SetHeight(72)
 card.desc:SetJustifyH('LEFT'); card.desc:SetJustifyV('TOP'); card.desc:SetMaxLines(6); card.desc:SetSpacing(2)
 applyFont(card.desc); card.desc:SetTextColor(0.9, 0.84, 0.72)
 local divider2 = solid(card, 'ARTWORK', 202, 1, 'TOPLEFT', 14, -318, 0.95, 0.72, 0.35, 0.45)
 if FT.RegisterAccent then FT.RegisterAccent(divider2, 0.45) end
 card.rows = {}
 for i = 1, ROWS do
  local y = -326 - (i - 1) * 28
  local row = {}
  row.label = card:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  row.label:SetPoint('TOPLEFT', 14, y); row.label:SetWidth(150); row.label:SetJustifyH('LEFT'); applyFont(row.label)
  row.count = card:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  row.count:SetPoint('TOPRIGHT', -14, y); row.count:SetWidth(54); row.count:SetJustifyH('RIGHT')
  row.bg = solid(card, 'ARTWORK', 202, 5, 'TOPLEFT', 14, y - 14, 0.05, 0.03, 0.01, 0.7)
  row.fill = solid(card, 'ARTWORK', 1, 5, 'TOPLEFT', 14, y - 14, 0.98, 0.8, 0.4, 1)
  row.mark = solid(card, 'ARTWORK', 3, 22, 'TOPLEFT', 8, y, 0.98, 0.8, 0.4, 0)
  card.rows[i] = row
 end
 card.flash = solid(card, 'OVERLAY', 206, 124, 'TOPLEFT', 12, -30, 0.3, 1, 0.3, 1)
 card.flash:SetAlpha(0)
 card:SetScript('OnUpdate', function(self, dt)
  if self.flashT then
   self.flashT = self.flashT - dt
   if self.flashT <= 0 then self.flashT = nil; self.flash:SetAlpha(0) else self.flash:SetAlpha(self.flashT * 0.6) end
  end
 end)
 if ForeverTrailSettings.card == false then card:Hide() end
end

function FT.ToggleCard()
 if not card then return end
 ForeverTrailSettings.card = not card:IsShown() and true or false
 if ForeverTrailSettings.card then card:Show(); FT.RefreshTarget() else card:Hide() end
end

local function dropperOf(target)
 if not target or target.kind ~= 'item' then return nil end
 local db = module('QuestieDB')
 if not (db and db.QueryItemSingle) then return nil end
 local ok, drops = pcall(db.QueryItemSingle, target.id, 'npcDrops')
 if ok and type(drops) == 'table' and type(drops[1]) == 'number' then return drops[1] end
end
FT.DropperOf = dropperOf

local function setVisual(target)
 local key = target and (target.kind .. ':' .. target.id) or 'none'
 if key == shownKey then return end
 shownKey = key
 local dropper = dropperOf(target)
 if target and (target.kind == 'npc' or dropper) and card.model then
  card.icon:Hide(); card.model:Show()
  card.model:ClearModel()
  pcall(card.model.SetCreature, card.model, dropper or target.id)
  if card.model.SetPortraitZoom then pcall(card.model.SetPortraitZoom, card.model, 0.8) end
 else
  if card.model then card.model:Hide() end
  card.icon:SetTexture(target and target.kind == 'item' and itemIcon(target.id) or QUESTION)
  card.icon:Show()
 end
 local r, g, b = AMBER[1], AMBER[2], AMBER[3]
 if target and target.kind == 'item' then
  r, g, b = qualityColor(target.id)
  card.badge:SetTexture(itemIcon(target.id)); card.badge:Show()
  setBorder(card.badgeRing, r, g, b); card.badgeRing:Show()
 else
  card.badge:Hide(); card.badgeRing:Hide()
 end
 setBorder(card.ring, r, g, b)
 setBorder(card.art, r, g, b)
 if card.ring then if card.icon:IsShown() then card.ring:Show() else card.ring:Hide() end end
end

function FT.RefreshTarget()
 if not card or not card:IsShown() then return end
 local g = FT.guide
 local step = g and g.steps[FT.view]
 if not step then return end
 -- Teslim edilmiş görevleri atla: kart bir sonraki yapılmamış görevi göstersin
 if step.questId and FT.QuestState(step.questId).status == 'turned_in' then
  for i = FT.view + 1, #g.steps do
   local candidate = g.steps[i]
   if candidate and (not candidate.questId or FT.QuestState(candidate.questId).status ~= 'turned_in') then step = candidate; break end
  end
 end
 local record = type(QTR_QuestData) == 'table' and step.questId and QTR_QuestData[tostring(step.questId)]
 local questTitle = (type(record) == 'table' and record.Title) or step.questTitle or g.title or ''
 local targets = FT.TargetsFor(step)
 local target = targets[step.objectiveIndex or 1] or targets[1]
 setVisual(target)
 local tc = (FT.TypeColor and FT.TypeColor[step.type]) or AMBER
 card.spot:SetVertexColor(tc[1], tc[2], tc[3], 1)
 local info = FT.EntityInfo(target, step)
 card.name:SetText(info and info.name or questTitle)
 do
  local text = info and (info.label .. (info.level and ('  |  Sv ' .. info.level) or '')) or ''
  local dropper = FT.DropperOf and FT.DropperOf(target)
  local dropInfo = dropper and FT.EntityInfo({kind='npc', id=dropper}, nil)
  if dropInfo then text = text .. '  |  Düşüren: ' .. dropInfo.name end
  card.kind:SetText(text)
 end
 if target then
  local okPoints, points = pcall(FT.SpawnPoints, step)
  card.zone:SetText(okPoints and FT.SummarizeSpawns(points, FT.MapName) or 'Konum bilinmiyor')
 else
  card.zone:SetText('')
 end
 local level, xp = nil, nil
 if step.questId then level, xp = FT.QuestMeta(step.questId) end
 card.quest:SetText(('%s%s%s'):format(level and ('[' .. level .. '] ') or '', questTitle, xp and ('  +' .. xp .. ' XP') or ''))
 do
  local status = step.questId and FT.QuestState(step.questId).status or 'unknown'
  local heads = {not_taken='Görevi al:', active='Yapılacak:', ready='Teslim et:', turned_in='Tamamlandı:'}
  local head = heads[status] or (step.type == 'location' and 'Konum:' or 'Adım:')
  local lines = {}
  if status ~= 'turned_in' and type(step.text) == 'string' and step.text ~= '' then
   lines[#lines + 1] = ('|cfff2c466%s|r %s'):format(head, step.text)
  end
  local body = step.questId and FT.QuestDescription(step.questId, status) or nil
  if body then lines[#lines + 1] = body end
  card.desc:SetText(#lines > 0 and table.concat(lines, '\n') or 'Bu adım için ayrıntılı açıklama yok.')
 end
 local rows = {}
 if step.questId and C_QuestLog and C_QuestLog.GetQuestObjectives and FT.QuestState(step.questId).status ~= 'not_taken' then
  local ok, list = pcall(C_QuestLog.GetQuestObjectives, step.questId)
  if ok and type(list) == 'table' then rows = list end
 end
 for i, row in ipairs(card.rows) do
  local data = rows[i]
  if data then
   local done = data.finished or (data.numRequired and data.numRequired > 0 and data.numFulfilled and data.numFulfilled >= data.numRequired)
   local need = data.numRequired or 0
   local have = data.numFulfilled or 0
   row.label:SetText(FT.ParseObjective(data.text or ''))
   if need > 0 then row.count:SetText(('%d/%d'):format(have, need)) else row.count:SetText(done and 'OK' or '') end
   if done then row.count:SetTextColor(0.55, 0.95, 0.5) elseif have > 0 then row.count:SetTextColor(1, 0.82, 0.35) else row.count:SetTextColor(0.85, 0.8, 0.74) end
   local frac = need > 0 and math.min(1, have / need) or (done and 1 or 0)
   row.fill:SetWidth(math.max(1, 202 * frac))
   if done then row.fill:SetColorTexture(0.55, 0.88, 0.5, 1); row.label:SetTextColor(0.7, 0.92, 0.65) else row.fill:SetColorTexture(0.98, 0.8, 0.4, 1); row.label:SetTextColor(1, 0.94, 0.82) end
   row.mark:SetAlpha(step.objectiveIndex == i and 1 or 0)
   row.label:Show(); row.count:Show(); row.bg:Show(); row.fill:Show()
  else
   row.label:Hide(); row.count:Hide(); row.bg:Hide(); row.fill:Hide(); row.mark:SetAlpha(0)
  end
 end
 if #rows == 0 then
  local first = card.rows[1]
  first.label:SetText(step.questId and 'Görev günlüğünde hedef yok.' or '')
  first.label:SetTextColor(0.7, 0.7, 0.7); first.label:Show()
 end
end

-- İlerleme / tamamlanma uyarıları (kart kapalıyken de çalışır)
local last, primed = {}, false
function FT.CheckProgress()
 local q = C_QuestLog
 if not (q and q.GetNumQuestLogEntries and q.GetInfo and q.GetQuestObjectives) then return end
 local seen = {}
 for index = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(index)
  if info and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then
   local ok, rows = pcall(q.GetQuestObjectives, info.questID)
   if ok and type(rows) == 'table' then
    for i, row in ipairs(rows) do
     local key = info.questID .. ':' .. i
     local have = row.numFulfilled or 0
     local done = row.finished == true
     seen[key] = true
     local old = last[key]
     if primed and old and (have > old.have or (done and not old.done)) then
      if card and card.flash then card.flashT = 0.6 end
      if done and not old.done then
       FT.Alert(('Hedef tamamlandı: %s'):format(FT.ParseObjective(row.text or '')), true)
      elseif FT.PlayProgressSound then FT.PlayProgressSound() end
      if FT.AnnounceProgress then FT.AnnounceProgress(FT.ParseObjective(row.text or ''), have, row.numRequired or 0, done and not old.done) end
     end
     last[key] = {have=have, done=done}
    end
   end
  end
 end
 for key in pairs(last) do if not seen[key] then last[key] = nil end end
 primed = true
end

-- Ortak hedefler: günlükte aynı yaratık/eşyayı isteyen diğer görevler
local keyCache, spawnCache = {}, {}
local function keysFor(questId)
 if keyCache[questId] then return keyCache[questId] end
 local list = {}
 for _, t in ipairs(FT.TargetsFor({questId=questId, type='objective'})) do list[#list+1] = t.kind .. ':' .. t.id end
 if #list > 0 then keyCache[questId] = list end
 return list
end

function FT.SharedCount(questId)
 local q = C_QuestLog
 local mine = keysFor(questId)
 if #mine == 0 or not (q and q.GetNumQuestLogEntries and q.GetInfo) then return 0 end
 local set = {}
 for _, key in ipairs(mine) do set[key] = true end
 local count = 0
 for index = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(index)
  if info and not info.isHeader and info.questID and info.questID > 0 and info.questID ~= questId then
   for _, key in ipairs(keysFor(info.questID)) do
    if set[key] then count = count + 1; break end
   end
  end
 end
 return count
end

-- Hedefin göründüğü noktalar: {map=uiMapID, x=0-1, y=0-1}
function FT.SpawnPoints(step)
 if not step or not step.questId then return {} end
 local key = step.questId .. ':' .. tostring(step.type) .. ':' .. (step.objectiveIndex or 0)
 if spawnCache[key] then return spawnCache[key] end
 local targets = FT.TargetsFor(step)
 local target = targets[step.objectiveIndex or 1] or targets[1]
 local db, zoneDB = module('QuestieDB'), module('ZoneDB')
 if not target or not db or not zoneDB then
  local own = FT.OwnObjectivePoints and FT.OwnObjectivePoints(step.questId, step.objectiveIndex) or {}
  spawnCache[key] = #own > 0 and own or nil
  return own
 end
 local entities = {}
 if target.kind == 'item' then
  local ok, drops = false, nil
  if db.QueryItemSingle then ok, drops = pcall(db.QueryItemSingle, target.id, 'npcDrops') end
  if ok and type(drops) == 'table' then
   for i = 1, math.min(3, #drops) do
    if type(drops[i]) == 'number' then entities[#entities+1] = {kind='npc', id=drops[i]} end
   end
  end
 else
  entities[1] = target
 end
 local points = {}
 for _, entity in ipairs(entities) do
  local getter = entity.kind == 'object' and db.QueryObjectSingle or db.QueryNPCSingle
  local ok, spawned = false, nil
  if getter then ok, spawned = pcall(getter, entity.id, 'spawns') end
  if ok and type(spawned) == 'table' then
   for areaID, rows in pairs(spawned) do
    local good, uiMap = pcall(zoneDB.GetUiMapIdByAreaId, zoneDB, areaID)
    if good and uiMap and type(rows) == 'table' then
     for _, row in ipairs(rows) do
      if #points >= 80 then break end
      if type(row) == 'table' and type(row[1]) == 'number' and type(row[2]) == 'number' then
       points[#points+1] = {map=uiMap, x=row[1] / 100, y=row[2] / 100}
      end
     end
    end
   end
  end
 end
 spawnCache[key] = points
 return points
end

-- İki görev aynı hedefi (yaratık/eşya/nesne) istiyor mu?
function FT.SharesTarget(questA, questB)
 if not questA or not questB or questA == questB then return false end
 local set = {}
 for _, key in ipairs(keysFor(questA)) do set[key] = true end
 for _, key in ipairs(keysFor(questB)) do if set[key] then return true end end
 return false
end

