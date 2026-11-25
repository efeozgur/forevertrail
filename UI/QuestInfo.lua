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

-- Eşya simgesi ve kalite rengi (önbellekte olmayan eşya için genel simge)
local function itemTile(id, count)
 local texture, color
 local ok, icon = pcall(function()
  if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
  if GetItemIcon then return GetItemIcon(id) end
 end)
 if ok and icon then texture = icon end
 local ok2, quality = pcall(function() local _, _, q = GetItemInfo(id); return q end)
 if ok2 and quality and GetItemQualityColor then
  local good, r, g, b = pcall(GetItemQualityColor, quality)
  if good and r then color = {r, g, b, 1} end
 end
 return {texture = texture, color = color, count = count}
end

local function itemName(id)
 local it = FT.DBI and FT.DBI[id]
 return it and type(it[1]) == 'string' and it[1] or ('Eşya ' .. id)
end

-- Görevin "yüzü": önce yapılacak hedefin yaratığı, yoksa teslim, yoksa veren NPC (3B portre için kimlik)
local function focusCreature(questId)
 if FT.ActiveObjectives then
  local ok, all = pcall(FT.ActiveObjectives)
  if ok and type(all) == 'table' then
   for _, o in ipairs(all) do
    if o.questId == questId and not o.done and type(o.npcs) == 'table' and type(o.npcs[1]) == 'number' then return o.npcs[1] end
   end
  end
 end
 if FT.TargetsFor then
  for _, kind in ipairs({'turnin', 'accept'}) do
   local ok, list = pcall(FT.TargetsFor, {questId = questId, type = kind})
   if ok and type(list) == 'table' then
    for _, t in ipairs(list) do if t.kind == 'npc' and type(t.id) == 'number' then return t.id end end
   end
  end
 end
end

-- Kit ipucunun ek yöntemleri (çizgi, çubuk, medya) düz GameTooltip'te yok: orada sade satırlara düşer
local function addRule(tip) if tip.AddRule then tip:AddRule() else tip:AddLine(' ') end end
local function addDouble(tip, left, right, lr, lg, lb, rr, rg, rb)
 if tip.AddDoubleLine then tip:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb) else tip:AddLine(left .. (right ~= '' and (': ' .. right) or ''), rr or 1, rg or 1, rb or 1) end
end
local function addBar(tip, text, have, need, r, g, b)
 if tip.AddBar then tip:AddBar(text, have, need, r, g, b) else addDouble(tip, text, ('%d/%d'):format(have, need), 1, 1, 1, r, g, b) end
end

-- Görevin durumu: metin ve renk
local function statusOf(questId)
 local q = C_QuestLog
 if q and q.GetLogIndexForQuestID and (q.GetLogIndexForQuestID(questId) or 0) > 0 then
  if q.IsComplete and q.IsComplete(questId) then return 'Teslime hazır', {0.55, 0.9, 0.5} end
  return 'Devam ediyor', {0.98, 0.8, 0.4}
 end
 if (q and q.IsQuestFlaggedCompleted and q.IsQuestFlaggedCompleted(questId)) or (FT.turnedIn and FT.turnedIn[questId]) then
  return 'Tamamlandı', {0.62, 0.78, 0.6}
 end
 return 'Henüz alınmadı', {0.6, 0.75, 1}
end

-- Görevin bütün ayrıntıları (tek, opak Kit ipucunda): başlık ve durum, ne yapılacağı ve hikâye, portre + eşya simgeleri,
-- numaralı adımlar (sayaç çubuklu, yerli), ödüller, seviye, zincir, uzaklık.
-- tip: FT.Kit.Tooltip() (SetOwner çağrılmış olmalı). opts: {mark = Discovery işareti, distance = metre, hints = {satırlar}}
function FT.QuestDetailTip(tip, questId, opts)
 if not (tip and questId) then return end
 opts = opts or {}
 local mark = opts.mark
 local row = FT.DBQ and FT.DBQ[questId]
 local level = (mark and mark.level) or (FT.QuestLevel and FT.QuestLevel(questId)) or (row and (row[5] or row[4]))
 local r, g, b = 1, 0.82, 0
 if FT.DiffColor and level then r, g, b = FT.DiffColor(level) end
 local title = FT.QuestTitle and FT.QuestTitle(questId) or ('Görev ' .. questId)
 tip:SetText((level and level > 0 and ('[' .. level .. '] ') or '') .. title, r, g, b)

 -- durum satırı: durum · tür · yenilik
 local status, sc = statusOf(questId)
 local tags = {}
 if FT.IsNewQuest and FT.IsNewQuest(questId) then tags[#tags + 1] = "Forever'a özel" end
 local kind = FT.QuestKind and FT.QuestKind(questId)
 if kind and KIND_TEXT[kind] then tags[#tags + 1] = KIND_TEXT[kind] end
 local shared = FT.SharedCount and FT.SharedCount(questId) or 0
 if shared > 0 then tags[#tags + 1] = ('%d görevle ortak hedef'):format(shared) end
 tip:AddLine(status .. (#tags > 0 and ('  ·  ' .. table.concat(tags, '  ·  ')) or ''), sc[1], sc[2], sc[3])

 -- uyarı: bu görev için önce gerekli olanlar (ön koşul görev, başka görevden gelen eşya)
 local okReq, reqs = false, nil
 if FT.QuestRequirements then okReq, reqs = pcall(FT.QuestRequirements, questId) end
 if okReq and type(reqs) == 'table' then
  for _, rq in ipairs(reqs) do
   if rq.ready then
    tip:AddLine('Hazır: ' .. (rq.text or ''), 0.55, 0.9, 0.5)
    tip:AddLine('   ' .. (rq.detail or ''), 0.5, 0.75, 0.48)
   else
    tip:AddLine('Dikkat: ' .. (rq.text or ''), 1, 0.72, 0.28)
    tip:AddLine('   ' .. (rq.detail or '') .. (rq.where and (' · ' .. rq.where) or ''), 0.82, 0.68, 0.42)
   end
  end
 end

 -- ne yapılacak ve hikâye (WoWTR çevirisi varsa Türkçe)
 local translation = type(QTR_QuestData) == 'table' and QTR_QuestData[tostring(questId)]
 local function usable(v) return type(v) == 'string' and v ~= '' and not v:find('[$]') and v or nil end
 local what = (type(translation) == 'table' and usable(translation.Objectives)) or (row and usable(row[8]))
 local story = type(translation) == 'table' and usable(translation.Description) or nil
 if what then tip:AddLine(cut(what, 300), 0.92, 0.92, 0.92) end
 if story and story ~= what then tip:AddLine(cut(story, 360), 0.62, 0.65, 0.72) end

 -- portre ve simgeler: hedef eşyaları, sonra ödül eşyaları
 local icons, rewards = {}, FT.QuestRewards and FT.QuestRewards(questId) or {}
 if FT.ActiveObjectives then
  local ok, all = pcall(FT.ActiveObjectives)
  if ok and type(all) == 'table' then
   for _, o in ipairs(all) do
    if o.questId == questId and o.itemId and #icons < 3 then icons[#icons + 1] = itemTile(o.itemId, o.need) end
   end
  end
 end
 for i = 1, math.min(5, #rewards) do icons[#icons + 1] = itemTile(rewards[i]) end
 local npc = focusCreature(questId)
 if (npc or #icons > 0) and tip.AddMedia then tip:AddMedia({npc = npc, icons = icons}) end

 -- görevi veren (alınabilir görev işaretinden: kim, hangi bölge, hangi nokta)
 local giver = mark and mark.giver
 if giver then
  local where = mark.map and FT.MapName and FT.MapName(mark.map)
  local coords = (mark.x and mark.y) and (' %.0f, %.0f'):format(mark.x * 100, mark.y * 100) or ''
  addDouble(tip, 'Veren', giver .. (where and (' — ' .. where .. coords) or ''), 0.67, 0.7, 0.76, 1, 1, 1)
 end

 -- numaralı adımlar
 local plan = FT.QuestPlan and FT.QuestPlan(questId) or {}
 if #plan > 0 then
  addRule(tip)
  for n, s in ipairs(plan) do
   local pr, pg, pb = 0.67, 0.7, 0.76
   if s.done then pr, pg, pb = 0.55, 0.9, 0.6 elseif s.current then pr, pg, pb = 1, 1, 1 end
   local counter = s.need > 0 and ('%d/%d'):format(s.have, s.need) or ''
   if s.current and s.need > 0 and not s.done then
    addBar(tip, ('%d.  %s'):format(n, s.text), s.have, s.need, 0.98, 0.8, 0.4)
   else
    addDouble(tip, ('%d.  %s'):format(n, s.text), counter, pr, pg, pb, pr, pg, pb)
   end
   if s.place and not s.done then tip:AddLine('      ' .. s.place.text, 0.5, 0.55, 0.65) end
  end
 end

 -- ödül ve koşullar
 addRule(tip)
 local xpText = FT.QuestXPText and FT.QuestXPText(questId)
 addDouble(tip, 'Ödül', xpText or 'XP bilgisi yok', 0.67, 0.7, 0.76, 0.6, 0.8, 1)
 if #rewards > 0 then
  local list = {}
  for i = 1, math.min(4, #rewards) do list[#list + 1] = itemName(rewards[i]) end
  addDouble(tip, 'Eşya', table.concat(list, ', ') .. (#rewards > 4 and (' +%d'):format(#rewards - 4) or ''), 0.67, 0.7, 0.76, 1, 0.9, 0.5)
 end
 if row then
  local need, qlevel = row[4], row[5]
  local parts = {}
  if type(need) == 'number' and need > 0 then parts[#parts + 1] = 'Gerekli ' .. need end
  if type(qlevel) == 'number' and qlevel > 0 then parts[#parts + 1] = 'Görev ' .. qlevel end
  if #parts > 0 then addDouble(tip, 'Seviye', table.concat(parts, '  ·  '), 0.67, 0.7, 0.76, 0.85, 0.85, 0.85) end
  local before = names(type(row[10]) == 'table' and row[10] or (type(row[11]) == 'table' and row[11]) or {}, 2)
  if #before > 0 then addDouble(tip, 'Önceki görev', table.concat(before, ', '), 0.67, 0.7, 0.76, 0.7, 0.85, 1) end
  local nextId = row[15]
  if type(nextId) == 'number' and nextId > 0 then
   addDouble(tip, 'Sonraki görev', FT.QuestTitle and FT.QuestTitle(nextId) or ('Görev ' .. nextId), 0.67, 0.7, 0.76, 0.7, 0.85, 1)
  end
 end
 local dist = opts.distance or (FT.QuestDistance and FT.QuestDistance(questId))
 if dist and dist < 1e9 then addDouble(tip, 'Uzaklık', ('%d m'):format(math.floor(dist + 0.5)), 0.67, 0.7, 0.76, 1, 1, 1) end
 if opts.hints and #opts.hints > 0 then
  tip:AddLine(' ')
  for _, h in ipairs(opts.hints) do tip:AddLine(h, 0.55, 0.57, 0.62) end
 end
end

-- Eski ad: Alınabilir görevler kutusu ve diğerleri bunu çağırır. tip: Kit ipucu ya da GameTooltip
function FT.QuestInfoTip(tip, questId, mark, distance)
 if not (tip and questId) then return end
 return FT.QuestDetailTip(tip, questId, {mark = mark, distance = distance, hints = {'Sol tık: yol göster'}})
end
