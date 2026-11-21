-- Görev yardımcısı: seçilen görevi adım adım anlatır
-- (nereden alınır, her hedef nasıl yapılır, nereye teslim edilir, ipuçları) ve her adıma "Yol göster" düğmesi koyar.
local _, FT = ...

local helper, rows, listButtons = nil, {}, {}
local selected

local function module(name)
 if FT.Module then local m = FT.Module(name) if m then return m end end
 if QuestieLoader and QuestieLoader.ImportModule then
  local ok, m = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
  if ok then return m end
 end
end

local function q(id, field)
 local db = module('QuestieDB')
 if not (db and db.QueryQuestSingle) then return nil end
 local ok, v = pcall(db.QueryQuestSingle, id, field)
 if ok then return v end
end

local function zoneName(map)
 local info = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
 return info and info.name or '?'
end

local function nearest(points)
 if type(points) ~= 'table' or #points == 0 then return nil end
 local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
 local pos = map and C_Map.GetPlayerMapPosition(map, 'player')
 local best, bestD
 if pos then
  local ok, ww, wh = pcall(C_Map.GetMapWorldSize, map)
  local px, py
  if pos.GetXY then px, py = pos:GetXY() end
  px, py = px or pos.x, py or pos.y
  for _, p in ipairs(points) do
   if p.map == map and ok and ww and px and py and p.x and p.y then
    local dx, dy = (p.x - px) * ww, (p.y - py) * wh
    local d = math.sqrt(dx * dx + dy * dy)
    if not bestD or d < bestD then best, bestD = p, d end
   end
  end
 end
 return best or points[1], bestD
end

local function inLog(id)
 return C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id) ~= nil
end

local function isComplete(id)
 return C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)
end

local function entityNames(step)
 local names = {}
 for _, t in ipairs(FT.TargetsFor and FT.TargetsFor(step) or {}) do
  local info = FT.EntityInfo and FT.EntityInfo(t, step)
  if info and info.name then
   names[#names + 1] = info.name .. (info.level and (' (sv ' .. info.level .. ')') or '')
   if #names >= 3 then break end
  end
 end
 return names
end

local HOW = {
 kill = 'Bu yaratıkları öldür. Haritadaki kırmızı alanlarda çok bulunur.',
 loot = 'Eşya yaratıklardan düşer ya da yerden toplanır. Öldürüp cesedi yağmala.',
 object = 'Bu nesneye git ve üzerine tıkla (sandık, bitki, taş, kutu...).',
 event = 'Bu yere git veya olayı tamamla. Yaklaşınca kendiliğinden ilerler.',
 talk = 'Bu NPC ile konuş.',
}

-- Görevin adımlarını hazırla
function FT.QuestHelperSteps(id)
 local steps = {}
 local function add(t) steps[#steps + 1] = t end
 local level = q(id, 'questLevel')
 local req = q(id, 'requiredLevel')
 local my = UnitLevel and UnitLevel('player') or 1

 if not inLog(id) and not (C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id)) then
  local step = {questId = id, type = 'accept'}
  local who = entityNames(step)
  local pts = FT.SpawnPoints and FT.SpawnPoints(step) or {}
  local p = nearest(pts)
  local detail = (#who > 0 and ('Veren: ' .. table.concat(who, ', ')) or 'Veren bilinmiyor')
  if p then detail = detail .. ' · ' .. zoneName(p.map) end
  if type(req) == 'number' and req > my then detail = detail .. ('\n|cffff6060Seviye %d gerekli (sen %d).|r'):format(req, my) end
  add({title = 'Görevi al', detail = detail, how = 'Sarı ! işaretli NPC ile konuş ve görevi kabul et.', point = p, name = who[1]})
 end

 local objectives = C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(id)
 local active = {}
 for _, o in ipairs(FT.ActiveObjectives and FT.ActiveObjectives() or {}) do if o.questId == id then active[o.index or (#active + 1)] = o end end
 if type(objectives) == 'table' and #objectives > 0 then
  for i, row in ipairs(objectives) do
   local o = active[i] or {}
   local step = {questId = id, type = 'objective', objectiveIndex = i}
   local kind = o.kind or (row.type == 'monster' and 'kill') or (row.type == 'item' and 'loot') or (row.type == 'object' and 'object') or 'event'
   local pts = FT.SpawnPoints and FT.SpawnPoints(step) or {}
   local p, d = nearest(pts)
   local who = entityNames(step)
   local detail = ''
   if #who > 0 then detail = (kind == 'loot' and 'Kaynak: ' or 'Hedef: ') .. table.concat(who, ', ') end
   if p then detail = detail .. (detail ~= '' and ' · ' or '') .. zoneName(p.map) .. (d and (' · %d m'):format(d) or '') end
   if #pts == 0 then detail = detail .. (detail ~= '' and '\n' or '') .. '|cffaaaaaaKonum veritabanında yok; görev metnine bak.|r' end
   add({title = (FT.ParseObjective and FT.ParseObjective(row.text or '') or row.text or ('Hedef ' .. i)), detail = detail, how = HOW[kind],
    done = row.finished, have = row.numFulfilled, need = row.numRequired, point = p, name = who[1]})
  end
 else
  local step = {questId = id, type = 'objective'}
  local targets = FT.TargetsFor and FT.TargetsFor(step) or {}
  for i, t in ipairs(targets) do
   local info = FT.EntityInfo and FT.EntityInfo(t, step)
   local s2 = {questId = id, type = 'objective', objectiveIndex = i}
   local p = nearest(FT.SpawnPoints and FT.SpawnPoints(s2) or {})
   local kind = t.kind == 'npc' and 'kill' or (t.kind == 'item' and 'loot' or 'object')
   add({title = (info and info.name) or ('Hedef ' .. i), detail = p and zoneName(p.map) or '', how = HOW[kind], point = p, name = info and info.name})
  end
  if #targets == 0 then
   local txt = q(id, 'objectivesText')
   if type(txt) == 'table' then txt = table.concat(txt, ' ') end
   if txt and txt ~= '' then add({title = 'Görevi yap', detail = txt, how = 'Görev metnindeki talimatı izle.'}) end
  end
 end

 local step = {questId = id, type = 'turnin'}
 local who = entityNames(step)
 local p = nearest(FT.SpawnPoints and FT.SpawnPoints(step) or {})
 add({title = 'Teslim et', detail = (#who > 0 and ('Teslim: ' .. table.concat(who, ', ')) or 'Teslim NPC\'si bilinmiyor') .. (p and (' · ' .. zoneName(p.map)) or ''),
  how = 'Bütün hedefler bitince sarı ? işaretli NPC\'ye git, ödülünü seç.', point = p, name = who[1], done = false, final = true})

 -- ipuçları
 local tips = {}
 if type(level) == 'number' then
  local diff = level - my
  if diff >= 3 then tips[#tips + 1] = ('|cffff4040Görev senden %d seviye yüksek: zor olabilir, grup bul ya da biraz seviye kas.|r'):format(diff)
  elseif diff <= -6 then tips[#tips + 1] = '|cff9d9d9dGri görev: çok az XP verir, istersen atla.|r'
  else tips[#tips + 1] = '|cff40ff40Seviyene uygun.|r' end
 end
 local _, xp = FT.QuestMeta and FT.QuestMeta(id)
 if xp then tips[#tips + 1] = ('Ödül: %d XP'):format(xp) end
 local pre = q(id, 'preQuestSingle') or q(id, 'preQuestGroup')
 if type(pre) == 'table' and #pre > 0 then
  local names = {}
  for _, pid in ipairs(pre) do names[#names + 1] = (FT.QuestTitle and FT.QuestTitle(pid)) or tostring(pid) end
  tips[#tips + 1] = 'Önce bitirilmesi gereken: ' .. table.concat(names, ', ')
 end
 local nxt = q(id, 'nextQuestInChain')
 if type(nxt) == 'number' and nxt > 0 then tips[#tips + 1] = 'Sonraki görev: ' .. ((FT.QuestTitle and FT.QuestTitle(nxt)) or nxt) end
 local desc = FT.QuestDescription and FT.QuestDescription(id, inLog(id) and 'taken' or 'not_taken')
 return steps, tips, desc
end

local function goTo(s)
 if not s.point then FT.Print('Bu adımın konumu bilinmiyor.'); return end
 if FT.SetCustomTarget then FT.SetCustomTarget(s.point.map, s.point.x, s.point.y, s.name or s.title) end
end

local function rowFor(i, parent)
 local r = rows[i]
 if r then return r end
 r = CreateFrame('Frame', nil, parent)
 r:SetSize(330, 60)
 r.num = r:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
 r.num:SetPoint('TOPLEFT', 2, -2); r.num:SetWidth(22)
 r.title = r:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 r.title:SetPoint('TOPLEFT', 28, -2); r.title:SetWidth(220); r.title:SetJustifyH('LEFT')
 r.detail = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 r.detail:SetPoint('TOPLEFT', r.title, 'BOTTOMLEFT', 0, -2); r.detail:SetWidth(300); r.detail:SetJustifyH('LEFT')
 r.how = r:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
 r.how:SetPoint('TOPLEFT', r.detail, 'BOTTOMLEFT', 0, -2); r.how:SetWidth(300); r.how:SetJustifyH('LEFT')
 r.go = CreateFrame('Button', nil, r, 'UIPanelButtonTemplate')
 r.go:SetSize(80, 20); r.go:SetPoint('TOPRIGHT', 0, 0); r.go:SetText('Yol göster')
 rows[i] = r
 return r
end

function FT.RefreshQuestHelper()
 if not (helper and helper:IsShown()) then return end
 -- sol liste: günlükteki görevler
 local ids = {}
 if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
   local info = C_QuestLog.GetInfo(i)
   if info and not info.isHeader and info.questID then ids[#ids + 1] = info.questID end
  end
 end
 if not selected then selected = FT.focusQuest or (FT.customTarget and FT.customTarget.questId) or ids[1] end
 for i, id in ipairs(ids) do
  local b = listButtons[i]
  if not b then
   b = CreateFrame('Button', nil, helper.list)
   b:SetSize(150, 18)
   b:SetPoint('TOPLEFT', 0, -(i - 1) * 19)
   b.text = b:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall'); b.text:SetAllPoints(); b.text:SetJustifyH('LEFT')
   b:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight', 'ADD')
   b:SetScript('OnClick', function(self) selected = self.id; FT.RefreshQuestHelper() end)
   listButtons[i] = b
  end
  b.id = id
  local lvl = FT.QuestLevel and FT.QuestLevel(id)
  local hex = FT.DiffHex and FT.DiffHex(lvl) or '|cffffd100'
  b.text:SetText(('%s%s%s|r%s'):format(hex, lvl and ('[' .. lvl .. '] ') or '', (FT.QuestTitle and FT.QuestTitle(id)) or id, isComplete(id) and ' |cff40ff40✓|r' or ''))
  if id == selected then b:LockHighlight() else b:UnlockHighlight() end
  b:Show()
 end
 for i = #ids + 1, #listButtons do listButtons[i]:Hide() end
 if FT.FixFonts then pcall(FT.FixFonts, helper) end
 helper.list:SetHeight(math.max(10, #ids * 19))
 if #ids == 0 then helper.empty:Show() else helper.empty:Hide() end

 for _, r in ipairs(rows) do r:Hide() end
 if not selected then helper.head:SetText('Görev seç'); helper.tips:SetText(''); return end
 local lvl = FT.QuestLevel and FT.QuestLevel(selected)
 helper.head:SetText(((lvl and ('[' .. lvl .. '] ')) or '') .. ((FT.QuestTitle and FT.QuestTitle(selected)) or selected))
 local steps, tips, desc = FT.QuestHelperSteps(selected)
 local y = 0
 for i, s in ipairs(steps) do
  local r = rowFor(i, helper.content)
  r:ClearAllPoints(); r:SetPoint('TOPLEFT', 0, y)
  local done = s.done or (s.final and false)
  r.num:SetText(done and '|cff40ff40✓|r' or tostring(i))
  local prog = (s.need and s.need > 0) and (' (%d/%d)'):format(s.have or 0, s.need) or ''
  r.title:SetText((done and '|cff40ff40' or '|cffffd100') .. (s.title or '') .. prog .. '|r')
  r.detail:SetText(s.detail or '')
  r.how:SetText(s.how and ('→ ' .. s.how) or '')
  r.go:SetEnabled(s.point ~= nil)
  r.go:SetScript('OnClick', function() goTo(s) end)
  local h = 8 + (r.title:GetStringHeight() or 12) + (r.detail:GetStringHeight() or 10) + (r.how:GetStringHeight() or 10)
  r:SetHeight(math.max(44, h))
  r:Show()
  y = y - r:GetHeight() - 6
 end
 local text = table.concat(tips, '\n')
 if desc and desc ~= '' then text = text .. (text ~= '' and '\n\n' or '') .. '|cffffd100Görev metni:|r ' .. desc end
 helper.tips:ClearAllPoints(); helper.tips:SetPoint('TOPLEFT', 0, y - 4)
 helper.tips:SetText(text)
 helper.content:SetHeight(-y + (helper.tips:GetStringHeight() or 0) + 20)
 if FT.FixFonts then pcall(FT.FixFonts, helper) end
end

function FT.ShowQuestHelper(questId)
 if not helper then
  helper = CreateFrame('Frame', 'ForeverTrailQuestHelper', UIParent, 'BasicFrameTemplateWithInset')
  helper:SetSize(560, 440); helper:SetPoint('CENTER'); helper:SetFrameStrata('HIGH')
  helper:SetMovable(true); helper:EnableMouse(true); helper:RegisterForDrag('LeftButton')
  helper:SetScript('OnDragStart', helper.StartMoving); helper:SetScript('OnDragStop', helper.StopMovingOrSizing)
  helper:SetClampedToScreen(true)
  local t = helper:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  t:SetPoint('TOP', 0, -5); t:SetText('Görev yardımcısı')
  local ls = CreateFrame('ScrollFrame', nil, helper, 'UIPanelScrollFrameTemplate')
  ls:SetPoint('TOPLEFT', 10, -30); ls:SetSize(160, 395)
  helper.list = CreateFrame('Frame', nil, ls); helper.list:SetSize(150, 10); ls:SetScrollChild(helper.list)
  helper.empty = helper:CreateFontString(nil, 'OVERLAY', 'GameFontDisable')
  helper.empty:SetPoint('TOPLEFT', 14, -34); helper.empty:SetWidth(150); helper.empty:SetText('Görev günlüğün boş.')
  helper.head = helper:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
  helper.head:SetPoint('TOPLEFT', 200, -32); helper.head:SetWidth(340); helper.head:SetJustifyH('LEFT')
  local cs = CreateFrame('ScrollFrame', nil, helper, 'UIPanelScrollFrameTemplate')
  cs:SetPoint('TOPLEFT', 200, -58); cs:SetSize(330, 370)
  helper.content = CreateFrame('Frame', nil, cs); helper.content:SetSize(330, 10); cs:SetScrollChild(helper.content)
  helper.tips = helper.content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  helper.tips:SetWidth(320); helper.tips:SetJustifyH('LEFT')
  table.insert(UISpecialFrames, 'ForeverTrailQuestHelper')
  local ev = CreateFrame('Frame')
  ev:RegisterEvent('QUEST_LOG_UPDATE'); ev:RegisterEvent('QUEST_ACCEPTED'); ev:RegisterEvent('QUEST_REMOVED')
  ev:SetScript('OnEvent', function()
   if helper:IsShown() then
    if selected and not inLog(selected) and not helper.keep then selected = nil end
    pcall(FT.RefreshQuestHelper)
   end
  end)
 end
 if questId then selected = questId; helper.keep = not inLog(questId) end
 if helper:IsShown() and not questId then helper:Hide(); return end
 helper:Show()
 pcall(FT.RefreshQuestHelper)
end

SLASH_FORVERTRAILHELPER1 = '/yardim'
SLASH_FORVERTRAILHELPER2 = '/ftyardim'
SlashCmdList.FORVERTRAILHELPER = function(msg)
 local id = tonumber(msg or '')
 FT.ShowQuestHelper(id)
end
