local _, FT = ...

-- Rehber adımının ayrıntıları: kim (NPC), nerede (bölge), ne yapılacak (fiil + görev adı + açıklama), kaç XP, sıradaki durak.
-- Rehber penceresi (UI/GuideTab.lua) ve Hub'daki Rehber sayfası (UI/Panel.lua) aynı bilgiyi gösterir.

local VERB = {accept = 'Görevi al', objective = 'Hedef', turnin = 'Teslim et', location = 'Konuma git', manual = 'Yapılacak'}
FT.StepVerb = VERB

local function dbName(kind, id)
 local row = kind == 'object' and FT.DBO and FT.DBO[id] or (FT.DBN and FT.DBN[id])
 if row and type(row[1]) == 'string' and row[1] ~= '' then return row[1] end
 local d = FT.Module and FT.Module('QuestieDB')
 if d then
  local ok, name = pcall(kind == 'object' and d.QueryObjectSingle or d.QueryNPCSingle, id, 'name')
  if ok and type(name) == 'string' and name ~= '' then return name end
 end
end

-- Adımın konuşulacak NPC'si ya da nesnesi (görevi veren / teslim alan); yoksa nil
function FT.StepNpc(step)
 if not step then return nil end
 if type(step.npc) == 'string' and step.npc ~= '' then return step.npc end
 if not step.questId or (step.type ~= 'accept' and step.type ~= 'turnin') then return nil end
 if FT.TargetsFor then
  local ok, list = pcall(FT.TargetsFor, step)
  if ok and type(list) == 'table' then
   for _, t in ipairs(list) do
    local name = dbName(t.kind == 'object' and 'object' or 'npc', t.id)
    if name then return name end
   end
  end
 end
 if step.type == 'turnin' and FT.TurnInName then
  local ok, name = pcall(FT.TurnInName, step.questId)
  if ok and type(name) == 'string' and name ~= '' then return name end
 end
end

local function translated(questId)
 local record = type(QTR_QuestData) == 'table' and questId and QTR_QuestData[tostring(questId)]
 return type(record) == 'table' and record or nil
end

-- Bir adım için gösterilecek her şey. Alanlar: type, verb, title, npc, zone, detail, xp (sayı), hasPlace
function FT.StepInfo(step)
 local info = {type = step and step.type or 'manual'}
 if not step then return info end
 info.verb = VERB[step.type] or ''
 local record = translated(step.questId)
 local title = (record and type(record.Title) == 'string' and record.Title ~= '' and record.Title) or step.questTitle
 if (not title or title == '') and step.questId and FT.QuestTitle then title = FT.QuestTitle(step.questId) end
 info.title = (title and title ~= '') and title or (step.text or '')
 info.npc = FT.StepNpc(step)
 info.zone = step.uiMapID and FT.MapName and FT.MapName(step.uiMapID) or nil
 info.hasPlace = (step.x and step.y) and true or false
 -- açıklama: görev hedefi (çeviri varsa Türkçe), yoksa adımın kendi metni
 local detail
 if step.type == 'accept' then
  local row = step.questId and FT.DBQ and FT.DBQ[step.questId]
  detail = (record and type(record.Objectives) == 'string' and not record.Objectives:find('[$]') and record.Objectives) or (row and type(row[8]) == 'string' and row[8]) or nil
 elseif step.type == 'objective' then
  detail = step.text
  if record and not step.objectiveIndex and type(record.Objectives) == 'string' and record.Objectives ~= '' and not record.Objectives:find('[$]') then detail = record.Objectives end
 elseif step.type == 'turnin' then
  detail = nil
 else
  detail = step.text
 end
 if detail == '' or detail == info.title then detail = nil end
 info.detail = detail
 if step.questId and FT.QuestXPInfo then
  local ok, xp = pcall(FT.QuestXPInfo, step.questId)
  if ok and type(xp) == 'number' and xp > 0 then info.xp = xp end
 end
 return info
end

-- Sıradaki durak: bu adımdan sonra, farklı bir NPC ile konuşulacak ilk adım ({npc, verb, title}); yoksa nil
function FT.NextStop(guide, index)
 if not (guide and guide.steps and index) then return nil end
 local current = FT.StepNpc(guide.steps[index])
 for i = index + 1, math.min(#guide.steps, index + 12) do
  local s = guide.steps[i]
  if s and (s.type == 'accept' or s.type == 'turnin') then
   local npc = FT.StepNpc(s)
   if npc and npc ~= current then
    local info = FT.StepInfo(s)
    return {npc = npc, verb = info.verb, title = info.title, index = i}
   end
  end
 end
end

-- Görev günlüğünde tamamlanmış ama henüz teslim edilmemiş görevler: sayı ve toplam XP ("başka yerde teslim edilecek")
function FT.PendingTurnIns(exceptQuestId)
 local q = C_QuestLog
 local count, xp = 0, 0
 if not (q and q.GetNumQuestLogEntries and q.GetInfo and q.IsComplete) then return 0, 0 end
 for i = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(i)
  local id = info and not info.isHeader and info.questID
  if id and id > 0 and id ~= exceptQuestId then
   local ok, done = pcall(q.IsComplete, id)
   if ok and done == true then
    count = count + 1
    if FT.QuestXPInfo then local ok2, v = pcall(FT.QuestXPInfo, id); if ok2 and type(v) == 'number' then xp = xp + v end end
   end
  end
 end
 return count, xp
end

----------------------------------------------------------------------
-- Tempo: oturumdaki XP hızı ve seviyeye kalan süre
----------------------------------------------------------------------
local pace = {start = nil, gained = 0, lastXP = nil, lastMax = nil}

local function now() return GetTime and GetTime() or 0 end

local function snapshot()
 if not (UnitXP and UnitXPMax) then return end
 pace.lastXP, pace.lastMax = UnitXP('player'), UnitXPMax('player')
end

-- Test için: ölçümü sıfırla
function FT.PaceReset() pace.start, pace.gained, pace.lastXP, pace.lastMax = nil, 0, nil, nil end

-- Test için: olay işlemeyi doğrudan çağırır
function FT.PaceEvent(event)
 if event == 'PLAYER_XP_UPDATE' then
  if not (UnitXP and UnitXPMax) then return end
  local xp, max = UnitXP('player'), UnitXPMax('player')
  if pace.lastXP then
   if xp >= pace.lastXP then pace.gained = pace.gained + (xp - pace.lastXP)
   else pace.gained = pace.gained + math.max(0, (pace.lastMax or 0) - pace.lastXP) + xp end
  end
  pace.lastXP, pace.lastMax = xp, max
 elseif event == 'PLAYER_ENTERING_WORLD' then
  pace.start = pace.start or now()
  if not pace.lastXP then snapshot() end
 end
end

-- Dönüş: saatlik XP (sayı ya da nil), seviyeye kalan dakika (sayı ya da nil), kısa metin
function FT.Pace()
 local elapsed = pace.start and (now() - pace.start) or 0
 if pace.gained <= 0 or elapsed < 30 then return nil, nil, 'XP hızı ölçülüyor…' end
 local perHour = pace.gained / elapsed * 3600
 local remaining = UnitXP and UnitXPMax and (UnitXPMax('player') - UnitXP('player')) or nil
 local minutes = remaining and remaining > 0 and perHour > 0 and (remaining / perHour * 60) or nil
 local text = ('%d XP/sa'):format(math.floor(perHour + 0.5))
 if minutes then
  text = text .. (minutes >= 90 and ('  ·  seviyeye ~%.1f sa'):format(minutes / 60) or ('  ·  seviyeye ~%d dk'):format(math.max(1, math.floor(minutes + 0.5))))
 end
 return perHour, minutes, text
end

local ev = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_ENTERING_WORLD', 'PLAYER_XP_UPDATE'}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript('OnEvent', function(_, event) pcall(FT.PaceEvent, event) end)
