local _, FT = ...

local function module(name)
 if FT.Module then local own = FT.Module(name) if own then return own end end
 if not (QuestieLoader and QuestieLoader.ImportModule) then return nil end
 local ok, result = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
 if ok then return result end
end

-- Seviye ilerlemesi ve teslim edilebilir görevlerin getireceği XP
-- Dönüş: seviye metni, teslimle gelecek XP metni (yoksa nil)
function FT.LevelParts()
 local level = UnitLevel and UnitLevel('player') or 0
 local xp, max = UnitXP and UnitXP('player') or 0, UnitXPMax and UnitXPMax('player') or 0
 if not max or max <= 0 then return ('Seviye %d'):format(level) end
 local gain = 0
 local xpDB, q = module('QuestXP'), C_QuestLog
 if xpDB and xpDB.db and xpDB.GetQuestLogRewardXP and q and q.GetNumQuestLogEntries and q.GetInfo and q.IsComplete then
  for index = 1, q.GetNumQuestLogEntries() do
   local info = q.GetInfo(index)
   if info and not info.isHeader and info.questID and info.questID > 0 and q.IsComplete(info.questID) and xpDB.db[info.questID] then
    local ok, value = pcall(xpDB.GetQuestLogRewardXP, xpDB, info.questID, false)
    if ok and type(value) == 'number' then gain = gain + value end
   end
  end
 end
 local text = ('Seviye %d  %%%d'):format(level, math.floor(xp / max * 100))
 local gainText = gain > 0 and ('Teslimle +%d XP (%%%d)'):format(gain, math.floor(gain / max * 100)) or nil
 return text, gainText
end

function FT.LevelSummary()
 local text, gainText = FT.LevelParts()
 if gainText then text = text .. '  |  ' .. gainText:gsub('^T', 't') end
 return text
end

-- Türkçe çevirisi olmayan günlük görevleri bildirir (WoWTR verisi)
function FT.PrintMissingTranslations()
 local q = C_QuestLog
 if type(QTR_QuestData) ~= 'table' then return FT.Print('WoWTR çeviri verisi yüklü değil.') end
 if not (q and q.GetNumQuestLogEntries and q.GetInfo) then return end
 local missing = {}
 for index = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(index)
  if info and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then
   local record = QTR_QuestData[tostring(info.questID)]
   if not (type(record) == 'table' and type(record.Title) == 'string' and record.Title ~= '') then
    missing[#missing + 1] = ('%s (%d)'):format(info.title or '?', info.questID)
   end
  end
 end
 if #missing == 0 then return FT.Print('Günlükteki tüm görevlerin Türkçe çevirisi var.') end
 FT.Print(('%d görevin çevirisi eksik: %s'):format(#missing, table.concat(missing, ', ', 1, math.min(5, #missing))))
end

-- Teslim geçmişi
function FT.RecordTurnIn(questId, xp)
 if type(questId) ~= 'number' then return end
 ForeverTrailCharacter.history = ForeverTrailCharacter.history or {}
 local history = ForeverTrailCharacter.history
 history[#history + 1] = {id = questId, xp = tonumber(xp) or 0, t = time and time() or 0}
 while #history > 200 do table.remove(history, 1) end
end

function FT.PrintHistory()
 local history = ForeverTrailCharacter and ForeverTrailCharacter.history or {}
 local today = date and date('%Y-%m-%d') or ''
 local count, xp = 0, 0
 for _, row in ipairs(history) do
  if not date or date('%Y-%m-%d', row.t) == today then count = count + 1; xp = xp + (row.xp or 0) end
 end
 FT.Print(('Bugün %d görev teslim edildi, toplam %d XP. Kayıtlı toplam: %d.'):format(count, xp, #history))
end
