local _, FT = ...

-- Zygor/RestedXP tarzı yardımcılar, kendi kodumuzla:
-- otomatik diyalog, görev ödülü danışmanı, NPC işaretleri, gruba paylaş, yetenek hatırlatıcı,
-- seviye süresi, güvenli mod (tehlikeli yaratık), meslek eğitmeni hatırlatıcı, rehber kayıt penceresi.

local function on(key) return ForeverTrailSettings and ForeverTrailSettings[key] ~= false end
local function optIn(key) return ForeverTrailSettings and ForeverTrailSettings[key] == true end
local function after(t, fn) if C_Timer and C_Timer.After then C_Timer.After(t, fn) else fn() end end
local function skip() return IsShiftKeyDown and IsShiftKeyDown() end
-- Açık konuşma penceresindeki görev otomatik işlenebilir mi? Rehber seçiliyken yalnızca rehberdeki görevler (FT.GuideAllows)
local function guideOk(kind)
 local r = FT.GuideAllows and FT.GuideAllows(GetQuestID and GetQuestID() or nil, kind)
 return r == nil or r == true
end

----------------------------------------------------------------------
-- Görev ödülü danışmanı
----------------------------------------------------------------------
local rewardGlow
local function rewardButton(i)
 return _G['QuestInfoRewardsFrameQuestInfoItem' .. i] or _G['QuestInfoItem' .. i] or _G['QuestRewardItem' .. i]
end

local function adviseReward()
 local count = GetNumQuestChoices and GetNumQuestChoices() or 0
 if count <= 1 then return count == 1 and 1 or nil end
 local best, bestGain, bestValue, reason
 for i = 1, count do
  local link = GetQuestItemLink and GetQuestItemLink('choice', i)
  if link and FT.ItemAdvice then
   local gain, value = FT.ItemAdvice(link)
   if gain and gain > 0 and (not bestGain or gain > bestGain) then best, bestGain, reason = i, gain, ('+%d puan yükseltme (sınıfına göre statlar)'):format(gain) end
   if not bestGain and (not bestValue or value > bestValue) then best, bestValue = i, value end
  end
 end
 if best and not bestGain then
  reason = 'yükseltme yok, en değerlisi (' .. (GetCoinTextureString and GetCoinTextureString(bestValue or 0) or tostring(bestValue)) .. ')'
 end
 if best then
  local button = rewardButton(best)
  if button then
   if not rewardGlow then
    rewardGlow = UIParent:CreateTexture(nil, 'OVERLAY')
    rewardGlow:SetTexture('Interface\\Buttons\\CheckButtonHilight'); rewardGlow:SetBlendMode('ADD')
   end
   rewardGlow:SetParent(button); rewardGlow:ClearAllPoints(); rewardGlow:SetAllPoints(button)
   rewardGlow:SetVertexColor(0.3, 1, 0.3); rewardGlow:Show()
  end
  FT.Print(('Önerilen ödül: %s — %s'):format(GetQuestItemLink('choice', best) or best, reason))
 end
 return best, bestGain ~= nil
end

----------------------------------------------------------------------
-- Otomatik diyalog (Shift basılıyken çalışmaz)
----------------------------------------------------------------------
local function gossipShow()
 if not on('autoquest') or skip() then return end
 local G = C_GossipInfo
 if G and G.GetActiveQuests then
  -- Rehber seçiliyken yalnızca rehberdeki görevler (FT.GuideAllows: nil = kısıt yok, eski davranış)
  local function allowed(q, kind) local r = FT.GuideAllows and FT.GuideAllows(q.questID, kind); return r == nil or r == true end
  for _, q in ipairs(G.GetActiveQuests() or {}) do
   if q.isComplete and allowed(q, 'turnin') then return G.SelectActiveQuest(q.questID) end
  end
  for _, q in ipairs(G.GetAvailableQuests() or {}) do
   if not q.repeatable and allowed(q, 'accept') then return G.SelectAvailableQuest(q.questID) end
  end
 end
end

local function questGreeting()
 if not on('autoquest') or skip() then return end
 local function allowed(title, kind) local r = FT.GuideAllowsTitle and FT.GuideAllowsTitle(title, kind); return r == nil or r == true end
 for i = 1, (GetNumActiveQuests and GetNumActiveQuests() or 0) do
  local title, complete = GetActiveTitle(i)
  if complete and allowed(title, 'turnin') then return SelectActiveQuest(i) end
 end
 for i = 1, (GetNumAvailableQuests and GetNumAvailableQuests() or 0) do
  if allowed(GetAvailableTitle and GetAvailableTitle(i), 'accept') then return SelectAvailableQuest(i) end
 end
end

----------------------------------------------------------------------
-- NPC / yaratık işaretleri (yıldız: konuş, kafatası: öldür)
----------------------------------------------------------------------
local STAR, SKULL = 1, 8
local function npcId(unit)
 local guid = UnitGUID(unit)
 return guid and tonumber((select(6, strsplit('-', guid))))
end

local function markUnit(unit)
 if not (ForeverTrailSettings and ForeverTrailSettings.raidmarks == true) or not UnitExists(unit) or UnitIsPlayer(unit) or UnitIsDead(unit) then return end
 if not SetRaidTarget or (GetRaidTargetIndex and GetRaidTargetIndex(unit)) then return end
 if IsInGroup and IsInGroup() and not (UnitIsGroupLeader('player') or UnitIsGroupAssistant('player')) then return end
 if FT.QuestCreatureInfo and FT.QuestCreatureInfo(unit) then return SetRaidTarget(unit, SKULL) end
 local step = FT.CurrentStep and FT.CurrentStep()
 local id = npcId(unit)
 if step and id and FT.TargetsFor then
  for _, t in ipairs(FT.TargetsFor(step)) do
   if t.kind == 'npc' and t.id == id and (step.type == 'accept' or step.type == 'turnin') then return SetRaidTarget(unit, STAR) end
  end
 end
end

----------------------------------------------------------------------
-- Gruba paylaş
----------------------------------------------------------------------
function FT.ShareStep()
 local step = FT.TargetStep and FT.TargetStep()
 if not step then return FT.Print('Paylaşılacak adım yok.') end
 local text = ('[ForeverTrail] %s: %s'):format(step.questTitle or 'Adım', step.text or '')
 if step.x and step.y then text = text .. (' (%.1f, %.1f)'):format(step.x * 100, step.y * 100) end
 local channel = (IsInRaid and IsInRaid()) and 'RAID' or ((IsInGroup and IsInGroup()) and 'PARTY' or nil)
 if channel then SendChatMessage(text:sub(1, 250), channel) else FT.Print('Grupta değilsin. ' .. text) end
end

----------------------------------------------------------------------
-- Yetenek önerisi (seviye atlarken genel öneri)
----------------------------------------------------------------------
local TALENT = {
 WARRIOR={'Silahlar (Arms)', 'Seviye atlarken iki elli silahla Arms; Sweeping Strikes ve Mortal Strike hedefle.'},
 PALADIN={'İntikam (Retribution)', 'Seal of Command ve iki elli silah; kalan puanlar Holy\'de Spiritual Focus.'},
 HUNTER={'Hayvan Ustalığı (Beast Mastery)', 'Pet hasarı ve Bestial Wrath; menzilden güvenli kasılır.'},
 ROGUE={'Savaş (Combat)', 'Kılıç/hançer uzmanlığı ve Blade Flurry; Improved Sinister Strike önce.'},
 PRIEST={'Gölge (Shadow)', 'Spirit Tap, Mind Flay ve Shadowform; mana dostu kasma.'},
 SHAMAN={'Güçlendirme (Enhancement)', 'Flurry ve iki elli silah; Stormstrike hedefle.'},
 MAGE={'Buz (Frost)', 'Improved Frostbolt ve Frost Nova; AoE kasma için Blizzard.'},
 WARLOCK={'Lanet (Affliction)', 'Improved Corruption ve Drain Life; Siphon Life ile kesintisiz kasma.'},
 DRUID={'Vahşi (Feral)', 'Ferocity ve kedi formu; tank gerektiğinde ayı.'},
}
function FT.ShowTalentAdvice()
 local _, token = UnitClass('player')
 local t = TALENT[token]
 local points = FT.Compat.UnspentPoints()
 local lines = {('Harcanmamış yetenek puanı: |cffffd100%d|r'):format(points or 0)}
 if t then
  lines[#lines + 1] = 'Seviye atlama için önerilen ağaç: |cff55ff55' .. t[1] .. '|r'
  lines[#lines + 1] = t[2]
 end
 lines[#lines + 1] = ' '
 lines[#lines + 1] = '|cff9aa0a6Genel öneridir; Forever\'daki yetenekler farklı olabilir.|r'
 FT.InfoWindow('Yetenek önerisi', lines)
end

local function talentReminder()
 if not on('talentadvisor') or on('levelcard') then return end
 local points = FT.Compat.UnspentPoints()
 if points and points > 0 then
  FT.Alert(('%d yetenek puanın harcanmamış (N tuşu). Öneri için menü > Yetenek önerisi.'):format(points), true)
 end
end

----------------------------------------------------------------------
-- Seviye süresi takibi
----------------------------------------------------------------------
local levelStart
local function levelData()
 ForeverTrailCharacter.levels = ForeverTrailCharacter.levels or {}
 return ForeverTrailCharacter.levels
end
local function flushLevel()
 if not levelStart then return end
 local data = levelData()
 local level = UnitLevel('player')
 data.current = data.current or {level=level, seconds=0}
 if data.current.level ~= level then data.current = {level=level, seconds=0} end
 data.current.seconds = data.current.seconds + (GetTime() - levelStart)
 levelStart = GetTime()
end

function FT.LevelTimeLines()
 flushLevel()
 local data = levelData()
 local lines = {}
 local cur = data.current
 if cur then lines[#lines + 1] = ('Bu seviyede geçen süre: |cffffd100%d dk|r'):format(cur.seconds / 60) end
 local xp, max = UnitXP('player'), UnitXPMax('player')
 if cur and cur.seconds > 120 and xp > 0 then
  local rate = xp / cur.seconds
  lines[#lines + 1] = ('Sonraki seviyeye tahmini: |cffffd100%d dk|r'):format((max - xp) / rate / 60)
 end
 for level = (UnitLevel('player') - 1), math.max(1, UnitLevel('player') - 3), -1 do
  if data[level] then lines[#lines + 1] = ('Seviye %d: %d dk'):format(level, data[level] / 60) end
 end
 return lines
end

----------------------------------------------------------------------
-- Güvenli mod: tehlikeli yaratıklar (can barının solunda kırmızı kafatası)
----------------------------------------------------------------------
local dangerSeen = {}
local function dangerous(unit)
 if not on('danger') or not UnitExists(unit) or UnitIsPlayer(unit) or UnitIsDead(unit) then return false end
 if not (UnitCanAttack and UnitCanAttack('player', unit)) then return false end
 local level, mine = UnitLevel(unit) or 0, UnitLevel('player') or 1
 local class = UnitClassification and UnitClassification(unit) or 'normal'
 return level == -1 or level >= mine + 4 or ((class == 'elite' or class == 'rareelite') and level >= mine - 2)
end

local function dangerMark(plate, show)
 if not plate then return end
 if show then
  if not plate.ftDanger then
   local uf = plate.UnitFrame
   local bar = (uf and (uf.healthBar or uf.HealthBar)) or uf or plate
   local t = plate:CreateTexture(nil, 'OVERLAY')
   t:SetTexture('Interface\\TargetingFrame\\UI-RaidTargetingIcon_8'); t:SetSize(16, 16)
   t:SetPoint('RIGHT', bar, 'LEFT', -3, 0); t:SetVertexColor(1, 0.35, 0.35)
   plate.ftDanger = t
  end
  plate.ftDanger:Show()
 elseif plate.ftDanger then plate.ftDanger:Hide() end
end

----------------------------------------------------------------------
-- Meslek eğitmeni hatırlatıcı
----------------------------------------------------------------------
local trainerWarned = {}
local function trainerCheck()
 if not on('trainerwarn') or not FT.ProfessionSkill then return end
 for _, kind in ipairs({'herb', 'ore'}) do
  local rank, max = FT.ProfessionSkill(kind)
  if rank and max and max < 300 and rank >= max - 5 and not trainerWarned[kind .. max] then
   trainerWarned[kind .. max] = true
   local trainer, distance = FT.NearestPlace and FT.NearestPlace('Meslek eğitmeni')
   local label = kind == 'herb' and 'Bitki toplama' or 'Madencilik'
   if trainer and FT.ShowChoice then
    FT.ShowChoice('Meslek sınırı', 'Interface\\Icons\\Trade_Engineering', ('%s %d/%d: sınıra geldin.\nEğitmen: %s'):format(label, rank, max, trainer.name), 'Yol göster',
     function() FT.SetCustomTarget(trainer.map, trainer.x, trainer.y, trainer.name) end)
   else
    FT.Alert(('%s %d/%d: eğitmenden bir üst seviyeyi öğren.'):format(label, rank, max), true)
   end
  end
 end
end

----------------------------------------------------------------------
-- Rehber kayıt penceresi (komut yazmadan)
----------------------------------------------------------------------
local recorder
function FT.ToggleRecorder()
 if not recorder then
  recorder = FT.NewWindow('ForeverTrailRecorder', UIParent)
  recorder:SetSize(300, 150); recorder:SetPoint('CENTER', UIParent, 'CENTER', 0, -120); recorder:SetFrameStrata('DIALOG')
  recorder:SetMovable(true); recorder:EnableMouse(true); recorder:RegisterForDrag('LeftButton')
  recorder:SetScript('OnDragStart', function(self) self:StartMoving() end)
  recorder:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
  local title = recorder:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  title:SetPoint('TOP', 0, -7); title:SetText('Rehber kaydı')
  if FT.StyleTitle then FT.StyleTitle(title) end
  recorder.status = recorder:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  recorder.status:SetPoint('TOPLEFT', 14, -30); recorder.status:SetWidth(272); recorder.status:SetJustifyH('LEFT')
  local box = (FT.Kit and FT.Kit.Input(recorder) or CreateFrame('EditBox', nil, recorder, 'InputBoxTemplate'))
  box:SetSize(260, 22); box:SetPoint('TOPLEFT', 20, -48); box:SetAutoFocus(false)
  box:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
  local function refresh()
   local rec = ForeverTrailSettings.recording
   recorder.status:SetText(rec and ('Kayıt: %s — %d adım. Kutuya metin yaz, türünü seç.'):format(rec.title, #rec.steps) or 'Kayıt yok. Kutuya başlık yazıp "Başlat"a bas.')
  end
  local function quick(kind, label)
   local rec = ForeverTrailSettings.recording
   local text = box:GetText()
   if not rec then FT.Record('kayit', 'baslat ' .. (text ~= '' and text or 'Özel rehber'))
   else
    local questId = ''
    if kind ~= 'konum' and kind ~= 'elle' then
     local step = FT.CurrentStep and FT.CurrentStep()
     questId = step and step.questId and (tostring(step.questId) .. ' ') or ''
     if questId == '' then return FT.Print('Bu tür için panelde bir görev seçili olmalı.') end
    end
    FT.Record('adim', kind .. ' ' .. questId .. (text ~= '' and text or label))
   end
   box:SetText(''); refresh()
  end
  local buttons = {
   {'Başlat', function() if not ForeverTrailSettings.recording then quick('baslat') end end},
   {'Konum', function() quick('konum', 'Buraya git') end},
   {'Görev al', function() quick('al', 'Görevi al') end},
   {'Hedef', function() quick('hedef', 'Hedefi tamamla') end},
   {'Teslim', function() quick('teslim', 'Görevi teslim et') end},
   {'Dışa aktar', function() FT.Record('kayit', 'yaz') end},
  }
  for i, def in ipairs(buttons) do
   local b = FT.NewButton(recorder, def[1], 86, 22)
   b:SetPoint('TOPLEFT', 14 + ((i - 1) % 3) * 92, -78 - math.floor((i - 1) / 3) * 26)
   b:SetScript('OnClick', def[2])
  end
  recorder:SetScript('OnShow', refresh)
  recorder:Hide()
  if FT.ApplyFont then pcall(FT.ApplyFont) end
 end
 if recorder:IsShown() then recorder:Hide() else recorder:Show() end
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local events = CreateFrame('Frame')
for _, e in ipairs({'GOSSIP_SHOW', 'QUEST_GREETING', 'QUEST_DETAIL', 'QUEST_ACCEPT_CONFIRM', 'QUEST_PROGRESS', 'QUEST_COMPLETE', 'QUEST_FINISHED',
 'UPDATE_MOUSEOVER_UNIT', 'PLAYER_TARGET_CHANGED', 'PLAYER_LEVEL_UP', 'PLAYER_ENTERING_WORLD', 'PLAYER_LOGOUT',
 'NAME_PLATE_UNIT_ADDED', 'NAME_PLATE_UNIT_REMOVED', 'SKILL_LINES_CHANGED', 'CHARACTER_POINTS_CHANGED'}) do
 pcall(events.RegisterEvent, events, e)
end
events:SetScript('OnEvent', function(_, event, a)
 local ok, err = pcall(function()
  if event == 'GOSSIP_SHOW' then gossipShow()
  elseif event == 'QUEST_GREETING' then questGreeting()
  elseif event == 'QUEST_DETAIL' then
   if FT.OwnLearnDetail and on('autoquest') and not skip() then FT.OwnLearnDetail() end
   if on('autoquest') and not skip() and guideOk('accept') then AcceptQuest() end
  elseif event == 'QUEST_ACCEPT_CONFIRM' then if on('autoquest') and not skip() and guideOk('accept') then ConfirmAcceptQuest() end
  elseif event == 'QUEST_PROGRESS' then if on('autoquest') and not skip() and guideOk('turnin') and IsQuestCompletable() then CompleteQuest() end
  elseif event == 'QUEST_COMPLETE' then
   local best, upgrade = nil, false
   if on('rewardadvisor') then best, upgrade = adviseReward() end
   local count = GetNumQuestChoices and GetNumQuestChoices() or 0
   local restricted = FT.GuideAllows and FT.GuideAllows(GetQuestID and GetQuestID(), 'turnin') ~= nil
   if on('autoquest') and not skip() and guideOk('turnin') then
    if FT.OwnLearnComplete then FT.OwnLearnComplete() end
    -- rehber görevinde en iyi ödül otomatik seçilir (autoreward=false ile kapatılır); rehber dışında eski açık-onay ayarı geçerli
    if count <= 1 then GetQuestReward(count)
    elseif best and (optIn('autoreward') or (restricted and ForeverTrailSettings.autoreward ~= false)) then
     FT.Print(('Ödül otomatik seçildi: %s'):format(GetQuestItemLink('choice', best) or best))
     GetQuestReward(best)
    end
   end
  elseif event == 'QUEST_FINISHED' then if rewardGlow then rewardGlow:Hide() end
  elseif event == 'UPDATE_MOUSEOVER_UNIT' then markUnit('mouseover')
  elseif event == 'PLAYER_TARGET_CHANGED' then markUnit('target')
  elseif event == 'PLAYER_ENTERING_WORLD' then levelStart = levelStart or GetTime(); after(5, talentReminder)
  elseif event == 'PLAYER_LOGOUT' then flushLevel()
  elseif event == 'PLAYER_LEVEL_UP' then
   flushLevel()
   local data = levelData()
   if data.current then data[data.current.level] = data.current.seconds end
   data.current = {level=a or (UnitLevel('player') + 1), seconds=0}
   if data[(a or 2) - 1] then FT.Print(('Seviye %d, %d dakikada tamamlandı.'):format((a or 2) - 1, data[(a or 2) - 1] / 60)) end
   after(2, talentReminder)
  elseif event == 'CHARACTER_POINTS_CHANGED' then -- sessiz
  elseif event == 'NAME_PLATE_UNIT_ADDED' and C_NamePlate then
   local plate = C_NamePlate.GetNamePlateForUnit(a)
   local bad = dangerous(a)
   dangerMark(plate, bad)
   if bad then
    local guid = UnitGUID(a)
    if guid and not dangerSeen[guid] then
     dangerSeen[guid] = true
     FT.Flash(('Dikkat: %s (Sv %s) yakında!'):format(UnitName(a) or '?', UnitLevel(a) == -1 and '??' or UnitLevel(a)), 1, 0.3, 0.3)
    end
   end
  elseif event == 'NAME_PLATE_UNIT_REMOVED' and C_NamePlate then dangerMark(C_NamePlate.GetNamePlateForUnit(a), false)
  elseif event == 'SKILL_LINES_CHANGED' then trainerCheck()
  end
 end)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'assist: ' .. tostring(err) end
end)
