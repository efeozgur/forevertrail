local _, FT = ...

-- Görev ayrıntı bilgisi: XP (bilinmiyorsa seviyeye göre tahmin), açıklama, veren, ödüller, zincir, tür.
-- "Alınabilir" kutusu, görev kutusu ipucu ve ansiklopedi aynı işlevleri kullanır.

----------------------------------------------------------------------
-- XP: kesin değer (Questie XP verisi ya da gömülü kayıtlar) ya da aynı seviyedeki görevlerin ortancası
----------------------------------------------------------------------
local medianByLevel

FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() medianByLevel = nil end

local function buildMedians()
 local groups = {}
 for _, e in pairs(FT.DBXP or {}) do
  local level, xp = e[1], e[2]
  if type(level) == 'number' and level > 0 and type(xp) == 'number' and xp > 0 then
   groups[level] = groups[level] or {}
   table.insert(groups[level], xp)
  end
 end
 medianByLevel = {}
 for level, list in pairs(groups) do
  table.sort(list)
  medianByLevel[level] = list[math.ceil(#list / 2)]
 end
end

-- Oyuncu seviyesi görevden yüksekse XP azalır (Classic kuralı, OwnDB.lua ile aynı)
local function adjusted(xp, questLevel)
 local diff = (UnitLevel and UnitLevel('player') or 1) - questLevel
 local mult = diff <= 5 and 1 or (diff == 6 and 0.8 or (diff == 7 and 0.6 or (diff == 8 and 0.4 or (diff == 9 and 0.2 or 0.1))))
 return math.floor(xp * mult / 5 + 0.5) * 5
end

-- Dönüş: xp, tahmin_mi  (veri hiç yoksa nil)
function FT.QuestXPInfo(questId)
 if type(questId) ~= 'number' then return nil end
 local mod = FT.Module and FT.Module('QuestXP')
 if mod and mod.GetQuestLogRewardXP then
  local ok, v = pcall(mod.GetQuestLogRewardXP, mod, questId, false)
  if ok and type(v) == 'number' and v > 0 then return v, false end
 end
 local row = FT.DBQ and FT.DBQ[questId]
 local level = row and ((type(row[5]) == 'number' and row[5] > 0 and row[5]) or (type(row[4]) == 'number' and row[4] > 0 and row[4]))
 if not level then return nil end
 if not medianByLevel then buildMedians() end
 local base = medianByLevel[level]
 if not base then
  for d = 1, 3 do base = medianByLevel[level - d] or medianByLevel[level + d]; if base then break end end
 end
 if not base then return nil end
 return adjusted(base, level), true
end

function FT.QuestXPText(questId)
 local xp, estimated = FT.QuestXPInfo(questId)
 if not xp then return nil end
 local per = UnitXPMax and UnitXPMax('player')
 local part = (per and per > 0) and ('  |cff9aa0a6(seviyenin %%%d\'i)|r'):format(math.floor(xp / per * 100 + 0.5)) or ''
 if estimated then return ('~%d XP |cff9aa0a6(tahmini)|r'):format(xp) .. part, true end
 return ('%d XP'):format(xp) .. part, false
end

----------------------------------------------------------------------
-- İpucu penceresi içeriği
----------------------------------------------------------------------
local KIND_TEXT = {['repeat'] = 'Tekrarlanabilir görev', event = 'Etkinlik görevi', pvp = 'PvP görevi', dungeon = 'Zindan görevi', raid = 'Baskın görevi'}

local function names(ids, limit)
 local out = {}
 for _, id in ipairs(ids or {}) do
  if type(id) == 'number' then
   out[#out + 1] = FT.QuestTitle and FT.QuestTitle(id) or ('Görev ' .. id)
   if #out >= (limit or 3) then break end
  end
 end
 return out
end

local function cut(text, n)
 if #text <= n then return text end
 return text:sub(1, n):gsub('%s+%S*$', '') .. '…'
end

-- tip: GameTooltip; mark: Discovery işareti (isteğe bağlı: veren, bölge, konum); distance: metre
function FT.QuestInfoTip(tip, questId, mark, distance)
 if not (tip and questId) then return end
 local row = FT.DBQ and FT.DBQ[questId]
 local level = (mark and mark.level) or (row and (row[5] or row[4]))
 local r, g, b = 1, 0.82, 0
 if FT.DiffColor and level then r, g, b = FT.DiffColor(level) end
 local title = FT.QuestTitle and FT.QuestTitle(questId) or ('Görev ' .. questId)
 tip:SetText((level and ('[' .. level .. '] ') or '') .. title, r, g, b)
 if FT.IsNewQuest and FT.IsNewQuest(questId) then tip:AddLine("Forever'a özel yeni görev", 0.55, 0.85, 1) end
 local kind = FT.QuestKind and FT.QuestKind(questId)
 if kind and KIND_TEXT[kind] then tip:AddLine(KIND_TEXT[kind], 1, 0.6, 0.3) end

 -- Ne yapılacak
 local translation = type(QTR_QuestData) == 'table' and QTR_QuestData[tostring(questId)]
 local what = type(translation) == 'table' and translation.Objectives
 if type(what) ~= 'string' or what == '' or what:find('[$]') then what = row and row[8] end
 if type(what) == 'string' and what ~= '' then tip:AddLine(cut(what, 260), 0.92, 0.92, 0.92, true) end
 tip:AddLine(' ')

 -- Kim, nerede
 local giver = mark and mark.giver
 if giver then
  local where = mark.map and FT.MapName and FT.MapName(mark.map)
  local coords = (mark.x and mark.y) and (' %.0f, %.0f'):format(mark.x * 100, mark.y * 100) or ''
  tip:AddLine('Görev veren: ' .. giver .. (where and (' — ' .. where .. coords) or ''), 1, 1, 1, true)
 end
 if FT.TurnInName then
  local ender = FT.TurnInName(questId)
  if ender and ender ~= giver then tip:AddLine('Teslim: ' .. ender, 0.55, 1, 0.55, true) end
 end
 if distance and distance < 1e9 then tip:AddLine(('Uzaklık: %d m'):format(math.floor(distance + 0.5)), 0.8, 0.8, 0.8) end

 -- Seviye ve ödül
 if row then
  local need, qlevel = row[4], row[5]
  local parts = {}
  if type(need) == 'number' and need > 0 then parts[#parts + 1] = 'Gerekli seviye: ' .. need end
  if type(qlevel) == 'number' and qlevel > 0 then parts[#parts + 1] = 'Görev seviyesi: ' .. qlevel end
  if #parts > 0 then tip:AddLine(table.concat(parts, '   '), 0.75, 0.75, 0.75) end
 end
 local xpText, estimated = FT.QuestXPText(questId)
 if xpText then tip:AddLine('Ödül: ' .. xpText, 0.6, 0.8, 1) else tip:AddLine('Ödül: XP bilgisi yok', 0.55, 0.55, 0.55) end
 local rewards = FT.QuestRewards and FT.QuestRewards(questId) or {}
 if #rewards > 0 then
  local list = {}
  for i = 1, math.min(4, #rewards) do
   local it = FT.DBI and FT.DBI[rewards[i]]
   list[#list + 1] = it and it[1] or '?'
  end
  tip:AddLine('Eşya ödülü: ' .. table.concat(list, ', ') .. (#rewards > 4 and (' (+%d)'):format(#rewards - 4) or ''), 1, 0.9, 0.5, true)
 end

 -- Zincir
 if row then
  local before = names(type(row[10]) == 'table' and row[10] or (type(row[11]) == 'table' and row[11]) or {}, 2)
  if #before > 0 then tip:AddLine('Zincir — önceki: ' .. table.concat(before, ', '), 0.7, 0.85, 1, true) end
  local nextId = row[15]
  if type(nextId) == 'number' and nextId > 0 then
   tip:AddLine('Zincir — sonraki: ' .. (FT.QuestTitle and FT.QuestTitle(nextId) or ('Görev ' .. nextId)), 0.7, 0.85, 1, true)
  end
 end
 tip:AddLine(' ')
 tip:AddLine('Sol tık: yol göster', 0.55, 0.55, 0.55)
end
