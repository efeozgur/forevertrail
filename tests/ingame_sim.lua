-- Oyun ortamı benzetimi: tüm dosyaları TOC sırasıyla yükler, giriş olaylarını ve arayüz eylemlerini çalıştırır.
local errors = {}
local frames, timers = {}, {}
local clock = 0
local function noop() end

local Widget = {}
local function widget(kind, name, parent)
 local w = setmetatable({__kind = kind or 'Frame', __shown = true, __scripts = {}, __name = name, __parent = parent, __text = ''}, Widget)
 frames[#frames + 1] = w
 if name then _G[name] = w end
 return w
end
local methods = {
 CreateTexture = function(self) return widget('Texture', nil, self) end,
 CreateFontString = function(self) return widget('FontString', nil, self) end,
 CreateLine = function(self) return widget('Line', nil, self) end,
 CreateAnimationGroup = function(self) return widget('AnimationGroup', nil, self) end,
 GetObjectType = function(self) return self.__kind end,
 GetName = function(self) return self.__name end,
 GetParent = function(self) return self.__parent end,
 SetParent = function(self, p) self.__parent = p end,
 Show = function(self) if self.__shown then return end self.__shown = true; local s = self.__scripts.OnShow; if s then s(self) end end,
 Hide = function(self) if not self.__shown then return end self.__shown = false; local s = self.__scripts.OnHide; if s then s(self) end end,
 SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
 IsShown = function(self) return self.__shown end,
 IsVisible = function(self) return self.__shown end,
 SetScript = function(self, k, f) self.__scripts[k] = f end,
 GetScript = function(self, k) return self.__scripts[k] end,
 HookScript = function(self, k, f) local old = self.__scripts[k]; self.__scripts[k] = function(...) if old then old(...) end f(...) end end,
 RegisterEvent = function(self, e) rawset(self, '__events', rawget(self, '__events') or {}); self.__events[e] = true end,
 UnregisterEvent = function(self, e) if self.__events then self.__events[e] = nil end end,
 RegisterUnitEvent = function(self, e) rawset(self, '__events', rawget(self, '__events') or {}); self.__events[e] = true end,
 GetWidth = function() return 300 end, GetHeight = function() return 200 end,
 GetFont = function(self) return self.__font or 'Fonts\\FRIZQT__.TTF', 12, '' end,
 SetFont = function(self, path) self.__font = path; return true end,
 GetRegions = function(self) local out = {} for _, f in ipairs(frames) do if f.__parent == self and (f.__kind == 'FontString' or f.__kind == 'Texture') then out[#out + 1] = f end end return unpack(out) end,
 GetChildren = function(self) local out = {} for _, f in ipairs(frames) do if f.__parent == self and f.__kind ~= 'FontString' and f.__kind ~= 'Texture' and f.__kind ~= 'Line' then out[#out + 1] = f end end return unpack(out) end,
 GetFrameLevel = function() return 1 end, GetFrameStrata = function() return 'MEDIUM' end,
 SetScale = function(self, s) self.__scale = s end, GetScale = function(self) return self.__scale or 1 end,
 GetEffectiveScale = function() return 1 end, GetLeft = function() return 0 end, GetTop = function() return 0 end,
 GetCenter = function() return 0, 0 end, GetPoint = function() return 'CENTER', nil, 'CENTER', 0, 0 end,
 IsEnabled = function(self) return not self.__disabled end, Enable = function(self) self.__disabled = false end, Disable = function(self) self.__disabled = true end,
 GetFontString = function(self) self.__fs = self.__fs or widget('FontString', nil, self); return self.__fs end,
 GetHighlightTexture = function(self) self.__hl = self.__hl or widget('Texture', nil, self); return self.__hl end,
 SetText = function(self, t) self.__text = t end, GetText = function(self) return self.__text end,
 GetChecked = function() return false end, IsMouseOver = function() return false end,
 GetID = function() return 0 end, GetZoom = function() return 0 end, GetMapID = function() return 1429 end,
 GetCanvas = function(self) self.__canvas = self.__canvas or widget('Frame', nil, self); return self.__canvas end,
 GetNormalizedCursorPosition = function() return 0.5, 0.5 end,
 NumLines = function() return 0 end, GetUnit = function() return nil end, GetItem = function() return nil end,
 GetStringWidth = function() return 50 end, GetNumPoints = function() return 1 end,
 SetFont_ = noop,
}
Widget.__index = function(self, k) if type(k) == 'string' and k:sub(1, 2) == '__' then return nil end return methods[k] or (type(k) == 'string' and k:match('^%u') and noop) or nil end

_G.CreateFrame = function(kind, name, parent) return widget(kind, name, parent) end
_G.CreateFont = function(name) return widget('Font', name) end
UIParent = widget('Frame', 'UIParent'); Minimap = widget('Frame', 'Minimap')
WorldMapFrame = widget('Frame', 'WorldMapFrame'); WorldMapFrame.ScrollContainer = widget('Frame', nil, WorldMapFrame)
WorldMapFrame:Hide()
GameTooltip = widget('GameTooltip', 'GameTooltip'); ItemRefTooltip = widget('GameTooltip', 'ItemRefTooltip')
UIErrorsFrame = widget('MessageFrame', 'UIErrorsFrame'); TargetFrame = widget('Frame', 'TargetFrame')
UISpecialFrames = {}; SlashCmdList = {}
C_Timer = {After = function(t, fn) timers[#timers + 1] = fn end, NewTicker = function() return {Cancel = noop} end}
local quests = {
 {isHeader = true, title = 'Elwynn Forest'},
 {questID = 6, title = 'Bounty on Garrick Padfoot', level = 5},
 {questID = 7, title = 'Kobold Camp Cleanup', level = 4},
}
if BENCH then
 for _, id in ipairs({33, 15, 47, 40, 35, 37, 52, 18, 54, 60, 61, 62, 64, 83, 85, 86, 87, 88}) do quests[#quests + 1] = {questID = id, title = 'Görev ' .. id, level = 10} end
end
APICALLS = 0
local function counted(t) for k, f in pairs(t) do if type(f) == 'function' then t[k] = function(...) APICALLS = APICALLS + 1 return f(...) end end end return t end
C_QuestLog = counted{
 GetNumQuestLogEntries = function() return #quests end,
 GetInfo = function(i) return quests[i] end,
 GetQuestObjectives = function(id) return {{text = 'Görev hedefi: 1/2', type = 'monster', finished = false, numFulfilled = 1, numRequired = 2}} end,
 IsComplete = function(id) return id == 7 end,
 GetLogIndexForQuestID = function(id) for i, q in ipairs(quests) do if q.questID == id then return i end end end,
 IsQuestFlaggedCompleted = function() return false end,
 GetNextWaypoint = function() return nil end,
 GetQuestTagInfo = function() return nil end,
}
C_Map = {
 GetBestMapForUnit = function() return 1429 end,
 GetPlayerMapPosition = function() return {GetXY = function() return 0.48, 0.42 end} end,
 GetMapWorldSize = function() return 3470, 2315 end,
 GetMapInfo = function(m) return {mapID = m, name = 'Elwynn Forest', mapType = 3, parentMapID = 1415} end,
 GetMapLinksForMap = function() return {} end,
}
C_Container = {
 GetContainerNumSlots = function() return 4 end, GetContainerItemInfo = function() return nil end,
 GetContainerNumFreeSlots = function() return 10 end, SortBags = noop, SortBankBags = noop,
}
C_TaxiMap = {GetAllTaxiNodes = function() return {} end}
C_GossipInfo = {GetActiveQuests = function() return {} end, GetAvailableQuests = function() return {} end}
C_NamePlate = {GetNamePlateForUnit = function() return nil end, GetNamePlates = function() return {} end}
C_ChatInfo = {RegisterAddonMessagePrefix = noop, SendAddonMessage = noop}
C_DeathInfo = {GetCorpseMapPosition = function() return nil end}
Enum = {}; SOUNDKIT = {}; BackdropTemplateMixin = {}
NUM_BAG_SLOTS = 4; NUM_CONTAINER_FRAMES = 13
UnitLevel = function() return BENCH and 30 or 10 end; UnitXP = function() return 100 end; UnitXPMax = function() return 1000 end
UnitName = function() return 'Test' end; UnitClass = function() return 'Warrior', 'WARRIOR', 1 end; UnitRace = function() return 'Human', 'Human', 1 end
UnitExists = function() return false end; UnitIsPlayer = function() return false end; UnitIsDead = function() return false end
UnitGUID = function() return nil end; UnitIsFriend = function() return false end; UnitCanAttack = function() return false end
UnitClassification = function() return 'normal' end; UnitCharacterPoints = function() return 0 end; UnitIsGhost = function() return false end
UnitInParty = function() return false end; UnitFactionGroup = function() return 'Alliance' end; IsInInstance = function() return false end; UnitInRaid = function() return false end
GetTime = function() return clock end; time = os.time; date = os.date
GetBuildInfo = function() return '1.60.1', '70291', 'Nov 1 2026', 16001 end
hooksecurefunc = noop; InCombatLockdown = function() return false end; IsShiftKeyDown = function() return false end
IsControlKeyDown = function() return false end; IsAltKeyDown = function() return false end
IsInGroup = function() return false end; IsInRaid = function() return false end; IsResting = function() return false end
IsMounted = function() return false end; IsIndoors = function() return false end
GetCVar = function() return '0' end; SetCVar = noop; GetPlayerFacing = function() return 0 end
GetUnitSpeed = function() return 0, 7 end; GetCursorPosition = function() return 0, 0 end
GetItemInfo = function() return nil end; GetItemIcon = function() return nil end; GetItemCooldown = function() return 0, 0 end
GetItemSpell = function() return nil end; GetMoney = function() return 12345 end; GetCoinTextureString = function(c) return tostring(c) end
GetBindLocation = function() return 'Goldshire' end; GetXPExhaustion = function() return 500 end
GetInventoryItemLink = function() return nil end; GetInventoryItemDurability = function() return 50, 50 end
GetInventoryItemCount = function() return 0 end; GetNumSkillLines = function() return 0 end
GetSpellInfo = function() return nil end; IsPlayerSpell = function() return false end
GetZoneText = function() return 'Elwynn Forest' end; GetQuestID = function() return 0 end
PlaySound = noop; GetQuestText = function() return 'Metin' end; GetObjectiveText = function() return 'Hedef' end; DeclineQuest = noop; UnitOnTaxi = function() return false end; NumTaxiNodes = function() return 0 end; IsInGuild = function() return false end; GetNumTrainerServices = function() return 0 end; AcceptQuest = noop; GetQuestReward = noop; CompleteQuest = noop; ConfirmAcceptQuest = noop; IsQuestCompletable = function() return false end; GetNumQuestChoices = function() return 0 end; GetTitleText = function() return '' end; GetNumLootItems = function() return 0 end; ShowUIPanel = function(f) f:Show() end; SendChatMessage = noop
strsplit = function(sep, s) local out = {} for part in (s .. sep):gmatch('(.-)' .. sep) do out[#out + 1] = part end return unpack(out) end
Ambiguate = function(s) return s end; CreateVector2D = function(x, y) return {GetXY = function() return x, y end} end
GetRealZoneText = GetZoneText; GetRealmName = function() return 'Forever' end; GetSubZoneText = function() return '' end
tinsert = table.insert; wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

local FT = {}
local t0, m0 = os.clock(), collectgarbage('count')
local toc = io.open('ForeverTrail.toc'):read('*a')
for file in toc:gmatch('([%w_/]+%.lua)') do
 local fn, err = loadfile(file)
 if not fn then errors[#errors + 1] = 'derleme ' .. file .. ': ' .. err
 else
  local ok, e = pcall(fn, 'ForeverTrail', FT)
  if not ok then errors[#errors + 1] = 'yükleme ' .. file .. ': ' .. tostring(e) end
 end
end

collectgarbage('collect')
PERF_LOAD = {os.clock() - t0, collectgarbage('count') - m0}
local function fire(event, ...)
 for _, f in ipairs(frames) do
  if f.__events and f.__events[event] and f.__scripts.OnEvent then
   local ok, e = pcall(f.__scripts.OnEvent, f, event, ...)
   if not ok then errors[#errors + 1] = event .. ': ' .. tostring(e) end
  end
 end
end
local function runTimers()
 for round = 1, 5 do
  local list = timers; timers = {}
  for _, fn in ipairs(list) do local ok, e = pcall(fn); if not ok then errors[#errors + 1] = 'zamanlayıcı: ' .. tostring(e) end end
 end
end
PERF = {}
local function tick(n)
 for i = 1, n do
  clock = clock + 0.25
  for _, f in ipairs(frames) do
   local s = f.__scripts.OnUpdate
   if s and f.__shown then local c = os.clock(); local ok, e = pcall(s, f, 0.25); PERF[f] = (PERF[f] or 0) + (os.clock() - c); if not ok then errors[#errors + 1] = 'OnUpdate: ' .. tostring(e) end end
  end
 end
end
local function try(label, fn, ...)
 local ok, e = pcall(fn, ...)
 if not ok then errors[#errors + 1] = label .. ': ' .. tostring(e) end
end

fire('ADDON_LOADED', 'ForeverTrail')
fire('PLAYER_LOGIN'); fire('PLAYER_ENTERING_WORLD', true, false); fire('QUEST_LOG_UPDATE')
-- kutular görev penceresine alınmadan önce kendi ölçeğini taşıyabilir (yazı boyutu ayarı); pencere kurulunca 1'e sıfırlanmalı
FT.tracker:SetScale(0.8); FT.availableBox:SetScale(0.8)
runTimers(); tick(20)
-- Questie tarzı tasarım
for _, mode in ipairs({'yakin', 'seviye', 'bolge'}) do ForeverTrailSettings.c_trackerSort = mode; try('sıra ' .. mode, FT.RefreshTracker) end
for _, st in ipairs({'renkli', 'sade'}) do ForeverTrailSettings.c_iconStyle = st; try('simge ' .. st, FT.RefreshCustomizePage); try('simge harita ' .. st, FT.RefreshMap) end
try('harita ipucu', FT.MapTooltip, {{step = {x = 0.5, y = 0.5, questId = 6, text = 'x'}}, {step = {x = 0.5, y = 0.5, questTitle = 'Han', text = 'Innkeeper'}}}, function(s) return {s.questTitle, s.text} end)
try('satır ipucu', FT.QuestRowTip, UIParent, 7)
FT.CreateAvailableBox(); try('alınabilir kutu', FT.RefreshAvailableBox)
for _, tab in ipairs({'simge', 'kutu', 'gorunum', 'ozel', 'yol'}) do try('ayar sekmesi ' .. tab, FT.SettingsTab, tab) end
for _, g in ipairs(FT.SettingsTabs) do try('ayar kategorisi ' .. g.key, FT.SettingsTab, g.key) end
for _, p in ipairs(FT.SettingsPages) do try('ayar sayfası ' .. p.key, FT.SettingsTab, p.key) end
try('ayar arama', function()
 local function find(q, label) for _, e in ipairs(FT.SettingsSearch(q)) do if e.label == label then return true end end return false end
 assert(find('yon oku', 'Yön oku'), 'yon oku bulunamadı (Türkçe harf sadeleştirme)')
 assert(find('GÖREV KUTUSU', 'Görev kutusu boyutu'), 'büyük harf araması')
 assert(#FT.SettingsSearch('xyzxyz') == 0, 'olmayan sözcük sonuç vermemeli')
 assert(#FT.SettingsSearch('') == 0, 'boş arama sonuç vermemeli')
 assert(FT.SettingsGroupOf('q_simge') == 'g_harita' and FT.SettingsGroupOf('yol') == 'g_harita', 'sayfa kategorisi')
 FT.settings.searchBox:SetText('harita'); FT.settings.searchBox:GetScript('OnTextChanged')(FT.settings.searchBox)
 assert(FT.settings.pages.zz_search.rows[1].entry, 'arama sonuç satırı dolmalı')
 FT.SettingsTab('q_genel')
end)
try('hızlı ayarlar', function() FT.ToggleQuickSettings(); FT.ToggleQuickSettings() end)
try('kullanım düzeyi', function()
 local S = ForeverTrailSettings
 assert(FT.ApplyUsageLevel('sade') and S.card == false and S.usageLevel == 'sade', 'sade')
 assert(FT.ApplyUsageLevel('tam') and S.card == true and S.usageLevel == 'tam', 'tam')
 assert(FT.ApplyUsageLevel('standart') and S.card == nil and S.usageLevel == nil, 'standart varsayılana döner')
 assert(not FT.ApplyUsageLevel('yok'), 'bilinmeyen düzey reddedilmeli')
end)
try('seçenek yenile', FT.RefreshOptions)
try('kurulum', FT.ShowSetupWizard)
for i = 1, 6 do try('kurulum adım ' .. i, function() ForeverTrailWizard.next:GetScript('OnClick')(ForeverTrailWizard.next) end) end
WIZ = ForeverTrailSettings.setupVersion
try('afiş', FT.ShowDoneBanner, 7)
ForeverTrailSettings.c_trackerDensity = 'sikisik'; try('sıkışık', FT.RefreshTracker); ForeverTrailSettings.c_trackerDensity = 'ferah'; try('ferah', FT.RefreshTracker)
GetItemCount = function() return 1 end; GetItemSpell = function() return 'Kullan' end; GetItemIcon = function() return 'x' end; InCombatLockdown = function() return false end
try('eşya düğmesi', FT.TrackerItemButton, 1, UIParent, 6)
try('ilerleme efekti', FT.ObjectiveProgress, {count = UIParent:CreateFontString()}, 6, 1, 1, 5); try('ilerleme efekti 2', FT.ObjectiveProgress, {count = UIParent:CreateFontString()}, 6, 1, 3, 5)
tick(4)
ForeverTrailSettings.trkAutoMin = true; ForeverTrailSettings.trkHideDoneObj = true; ForeverTrailSettings.trkShowDone = false
ForeverTrailSettings.c_objColor = 'beyaz'; ForeverTrailSettings.c_trackerSort = 'yuzde'; ForeverTrailSettings.c_iconGiver = 1.5; ForeverTrailSettings.c_iconKill = 0.7
try('kutu seçenekleri', FT.RefreshTracker); try('harita seçenekleri', FT.RefreshMap)
fire('PLAYER_REGEN_DISABLED'); fire('PLAYER_REGEN_ENABLED')
ForeverTrailSettings.trkShowDone = nil; ForeverTrailSettings.c_trackerSort = nil
AVAIL = FT.availableBox and FT.availableBox:IsShown()
ForeverTrailSettings.c_trackerBg = 'seffaf'; try('şeffaf', FT.ApplyTrackerAlpha); try('tema klasik', FT.ApplyTheme, 'klasik')
ForeverTrailCharacter = ForeverTrailCharacter or {}; ForeverTrailCharacter.trkZones = {['Elwynn Forest'] = true}; try('bölge daralt', FT.RefreshTracker)
ForeverTrailCharacter.trkZones = {}; ForeverTrailCharacter.trkMin = {[6] = true}; try('görev daralt', FT.RefreshTracker)
assert(FT.TurnInName(7), 'teslim NPC adı yok')
-- Daha iyi eşya ve çanta dolu pencereleri
local ITEMS = {['item:100'] = {'Eski Kılıç', 2, 10, 5, 'INVTYPE_2HWEAPON', 500, 2, 1, 1}, ['item:200'] = {'Yeni Kılıç', 3, 14, 8, 'INVTYPE_2HWEAPON', 900, 2, 1, 1},
 ['item:300'] = {'Kırık Diş', 0, 1, 1, '', 3, 15, 0, 0}, ['item:400'] = {'Değerli Taş', 3, 20, 1, '', 5000, 7, 0, 0}}
GetItemInfo = function(l) local i = l and ITEMS[tostring(l):match('item:%d+')]; if not i then return nil end return i[1], l, i[2], i[3], i[4], '', '', 1, i[5], 'icon', i[6], i[7], i[8], i[9] end
GetItemStats = function(l) if l:find('200') then return {ITEM_MOD_STRENGTH_SHORT = 5, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 9.5} end return {ITEM_MOD_STRENGTH_SHORT = 2, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 7} end
GetInventoryItemLink = function(_, slot) if slot == 16 then return 'item:100' end end
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end
C_Container.GetContainerItemInfo = function(bag, slot) if bag ~= 0 then return nil end return slot == 1 and {hyperlink = 'item:200', stackCount = 1} or {hyperlink = 'item:300', stackCount = 1} end
EquipItemByName = function(l) EQUIPPED = l end
ForeverTrailSettings.upgrades = true
if FT.upgradePopup then FT.upgradePopup:Hide() end
try('eşya tarama', FT.ScanUpgrades)
UPSHOWN = FT.upgradeCompare and FT.upgradeCompare:IsShown()
try('tak', function() FT.upgradeCompare.equip:GetScript('OnClick')(FT.upgradeCompare.equip) end)
SCORE = ('puan yeni %.1f / eski %.1f'):format(FT.ItemScore('item:200'), FT.ItemScore('item:100'))
try('çanta dolu', FT.ShowSwapCompare, 'item:400', 5000, {{bag = 0, slot = 2, link = 'item:300', value = 3, count = 1}}, function(v) SWAPPED = v.link end)
try('çanta seç', function() local r = FT.swapCompare.rows[1]; r:GetScript('OnClick')(r) end)
-- Sınıf rehberi: yetenek planı, seviye kartı, sınıf görevleri, meslekler
TALENT = {}
for tab = 1, 3 do TALENT[tab] = {}; for i = 1, 20 do TALENT[tab][i] = {name = 'Yetenek ' .. tab .. '-' .. i, tier = math.floor((i - 1) / 4) + 1, col = (i - 1) % 4 + 1, rank = 0} end end
GetNumTalents = function(tab) return 20 end
GetTalentInfo = function(tab, i) local t = TALENT[tab][i]; return t.name, 'icon', t.tier, t.col, t.rank, 5 end
GetTalentTabInfo = function(tab) return ({'Silah', 'Öfke', 'Koruma'})[tab], 'icon', 0 end
POINTS = 3
UnitCharacterPoints = function() return POINTS end
LearnTalent = function(tab, i) TALENT[tab][i].rank = TALENT[tab][i].rank + 1; POINTS = POINTS - 1 end
local steps, perr = FT.TalentPlan()
TPLAN = steps and #steps or ('hata: ' .. tostring(perr))
try('yetenek öğren', FT.LearnNextTalent)
local nxt = FT.NextTalent()
TNEXT = nxt and (nxt.talent.name .. ' ' .. nxt.rank .. '/' .. nxt.talent.max .. ' sv' .. nxt.level) or 'yok'
try('seviye kartı', FT.ShowLevelCard, 12)
try('hub sınıf', FT.OpenHub, 'sinif'); try('hub meslek', FT.OpenHub, 'meslek')
try('sınıf görevleri', FT.ClassQuests)
CQ = #FT.ClassQuests()
UnitClass = function() return 'Hunter', 'HUNTER', 3 end
try('evcil', function() TAME = #FT.TameableOn(1429) end)
UnitClass = function() return 'Warrior', 'WARRIOR', 1 end
try('kendi plan', FT.ImportTalentLink, 'https://kami-labs.fr/en/wow-forever/builder/?lang=en&class=warrior&tree=arms&t=s05320203132215201-0525010501&o=sCCCBBFFDDBHHHBBIJJJKMLLKNONNNNQOVVVVVXXXXXbbbbbZdWW')
GetNumSkillLines = function() return 2 end
GetSkillLineInfo = function(i) if i == 1 then return 'Mining', nil, nil, 72, nil, nil, 75 end return 'Cooking', nil, nil, 30, nil, nil, 75 end
try('meslek sayfası', FT.RefreshProfessionPage)
WorldMapFrame:Show(); if FT.mapRoute then FT.mapRoute:Show() end
ROUTE = {}
for _, cat in ipairs({'gorev', 'teslim', 'sinif', 'meslek', 'evcil', 'zindan', 'nadir', 'hepsi'}) do
 try('yol sor ' .. cat, function() FT.RouteCategory(cat) end)
 ROUTE[#ROUTE + 1] = cat .. '=' .. tostring(FT.RouteCount and FT.RouteCount())
end
ForeverTrailSettings.routeEverywhere = true
try('her yer', function() FT.RouteSearch('dughan') end)
ROUTE[#ROUTE + 1] = 'heryer(dughan)=' .. tostring(FT.RouteCount and FT.RouteCount())
ForeverTrailSettings.routeEverywhere = nil; FT.RouteSearch('')
PROF = FT.ProfessionTrainer('mining'); PROF = PROF and (PROF.name .. ' / ' .. (PROF.sub or '')) or 'yok'
local adv = FT.ProfessionAdvice({rank = 72, max = 75}); PADV = adv
-- Yönlendirme 2 ve düzen
try('rota sırası', function() local l, t = FT.RouteOrder(); ROUTE2 = #l .. ' durak, ' .. math.floor(t or 0) .. ' yd' end)
try('rota numaraları', FT.DrawRouteNumbers, 1429)
try('rota özeti', function() RSUM = FT.RouteSummary() end)
ForeverTrailSettings.c_sessionGoal = 'bir'; try('oturum çubuğu', FT.UpdateSessionBar)
try('görev bırakma', FT.QuestDropCheck)
try('bölge uygun', function() local v, c, zl = FT.ZoneFit(1429); ZFIT = v and (v .. ' ' .. zl.lo .. '-' .. zl.hi) or 'yok'; ZBETTER = table.concat(FT.BetterZones(3), ', ') end)
try('uçuş önerisi', FT.FlightSuggestion, 1436, 0.5, 0.5)
try('düzen modu aç', FT.ToggleEditMode, true)
for _, p in ipairs({'genis', 'hud', 'sade', 'varsayilan'}) do try('düzen ' .. p, FT.ApplyLayoutPreset, p) end
try('düzen modu kapat', FT.ToggleEditMode, false)
try('sessiz', FT.ToggleSilent); SIL = FT.IsSilent(); try('sessiz uyarı', FT.ShowChoice, 'x', nil, 'y', 'z', function() end); try('sessiz kapat', FT.ToggleSilent)
try('yedek', FT.BackupNow); try('yedekler', FT.ShowBackups)
ForeverTrailSettings.c_fontScale = 1.2; try('yazı boyutu', FT.ApplyFontScale); ForeverTrailSettings.c_fontScale = nil
ForeverTrailCharacter.trkPin = {[7] = true}; ForeverTrailCharacter.trkOrder = {7, 6}; try('sabitle sırala', FT.RefreshTracker)
TORDER = table.concat(FT.trkLastOrder or {}, ',')
try('oturum kartı', FT.ShowSessionCard)
-- Janti
JMSG = {}
local addm = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage
if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME.AddMessage = function(self, m, ...) if tostring(m):find('Janti', 1, true) then JMSG[#JMSG + 1] = m end if addm then return addm(self, m, ...) end end end
local money = 100; GetMoney = function() return money end
JSHOW = {}
local origShow = FT.JantiShow
fire('PLAYER_DEAD'); JSHOW[#JSHOW + 1] = ForeverTrailJanti and ForeverTrailJanti.text:GetText(); fire('PLAYER_DEAD'); JSHOW[#JSHOW + 1] = ForeverTrailJanti and ForeverTrailJanti.text:GetText()
fire('MERCHANT_SHOW'); money = 150; fire('PLAYER_MONEY'); money = 200; fire('PLAYER_MONEY'); fire('MERCHANT_CLOSED')
JSHOW[#JSHOW + 1] = ForeverTrailJanti and ForeverTrailJanti.text:GetText()
fire('PLAYER_EQUIPMENT_CHANGED'); JSHOW[#JSHOW + 1] = ForeverTrailJanti and ForeverTrailJanti.text:GetText()
JSHOWN = ForeverTrailJanti and ForeverTrailJanti:IsShown(); tick(20); JHIDDEN = ForeverTrailJanti and not ForeverTrailJanti:IsShown()
try('janti off', SlashCmdList.FORVERTRAILJANTI, 'off'); fire('PLAYER_DEAD'); JOFF = ForeverTrailSettings.janti
try('janti on', SlashCmdList.FORVERTRAILJANTI, 'on')
-- Değişiklik kaydı düzeltmeleri
ForeverTrailCharacter.path = nil
try('yol 1', FT.AddVia, 1429, 0.40, 0.50); try('yol 2', FT.AddVia, 1429, 0.45, 0.55); try('yol 3', FT.AddVia, 1429, 0.50, 0.60)
try('yol sil', FT.AddVia, 1429, 0.451, 0.551)
local pts = FT.PathPoints(); PATH = #pts
try('yol geri', FT.UndoVia); PATH2 = #FT.PathPoints()
try('yol ilerle', FT.PassVia); local _, passed = FT.PathPoints(); PASSED = passed
PEND = FT.PathEndStep() and 'var' or 'yok'
try('yol çiz', FT.DrawVia, 1429)
try('yol temizle', FT.ClearVia)
local savedGetMapInfo = C_Map.GetMapInfo
C_Map.GetMapInfo = function(id) if id == 1429 then return {mapType = 3, parentMapID = 1415} end if id == 1415 then return {mapType = 2, parentMapID = 947} end return {mapType = 3, parentMapID = 407} end
DUNG = {}
FT.ResetDungeonFilter()
for id, d in pairs(FT.DBDungeons or {}) do if d[1] == 'Darkmoon Faire Island' or d[1] == 'Utgarde Keep' or d[1] == 'The Deadmines' then DUNG[#DUNG + 1] = d[1] .. '=' .. tostring(FT.DungeonAllowed(id, d)) end end
C_Map.GetMapInfo = savedGetMapInfo
FT.ResetDungeonFilter()
try('yazı tipi yaması', FT.PatchGameFonts)
fire('ADDON_ACTION_FORBIDDEN', 'ForeverTrail', 'SetRaidTarget()')
FORB = 0; for i = #(FT.errors or {}), 1, -1 do if tostring(FT.errors[i]):find('engellendi') then FORB = FORB + 1; table.remove(FT.errors, i) end end
-- Questie görünümü
for _, st in ipairs({'kutu', 'seffaf', 'questie'}) do ForeverTrailSettings.c_trackerStyle = st; try('kutu stili ' .. st, FT.RefreshTracker) end
ForeverTrailSettings.c_trackerStyle = nil
for _, st in ipairs({'sade', 'renkli', 'questie'}) do ForeverTrailSettings.c_iconStyle = st; FT.BumpLayers(); try('harita stili ' .. st, FT.RefreshMap) end
ForeverTrailSettings.c_iconStyle = nil
QSTYLE = FT.TrackerStyle() .. '/' .. FT.IconStyle() .. ' başlık=' .. tostring(ForeverTrailTracker and select(1, ForeverTrailTracker:GetRegions()) and '' or '')
-- Questie arayüzü
try('questie ayarlar', FT.OpenQuestieOptions, 'simge')
try('hub ayarlar yönlendirme', FT.OpenHub, 'ayarlar')
QOPT = ForeverTrailOptionsWindow and ForeverTrailOptionsWindow:IsShown()
try('kasaba işaretleri', FT.DrawTownsfolk, 1429)
TOWN = 0; for _, d in ipairs(FT.townDots or {}) do if d:IsShown() then TOWN = TOWN + 1 end end
try('yetenek paneli', FT.ShowTalentPanel)
TPAN = ForeverTrailTalentPanel and ForeverTrailTalentPanel:IsShown()
-- Nadir görsel, harita taşıma, sınıf eğitmeni
try('nadir kart', FT.ShowRareCard, {id = 99, name = 'Gruff Swiftbite', level = 12, map = 1429, x = 0.5, y = 0.5}, 80)
RCARD = ForeverTrailRareCard and ForeverTrailRareCard:IsShown()
try('nadir harita', FT.DrawRares, 1429)
RDOTS = 0; for _, d in ipairs(FT.rareDots or {}) do if d:IsShown() then RDOTS = RDOTS + 1 end end
try('nadir görsel', FT.ShowTooltipModel, 99)
OTHER = tostring(FT.IsOtherClassTrainer('Mage Trainer')) .. '/' .. tostring(FT.IsOtherClassTrainer('Warrior Trainer')) .. '/' .. tostring(FT.IsOtherClassTrainer('Mining Trainer'))
local tr = 0; for _, e in ipairs(FT.MapServices(1429)) do if e.sub and e.sub:find(' Trainer') and FT.IsOtherClassTrainer(e.sub) then tr = tr + 1 end end
OTHERCOUNT = tr
WorldMapFrame:Show()
local dr, dg, db = FT.DiffColor(5)
DESIGN = ('teslim(7)=%s, zorluk(5)=%.2f/%.2f/%.2f, uzaklık(6)=%s'):format(FT.TurnInName(7), dr, dg, db, tostring(FT.QuestDistance(6))); runTimers()

-- Kullanıcı eylemleri
for _, page in ipairs({'rehber', 'gorevler', 'yerler', 'ansiklopedi', 'araclar', 'ayarlar'}) do try('hub ' .. page, FT.OpenHub, page) end
for _, tab in ipairs({'gorev', 'yol', 'canta', 'uyari', 'gorunum', 'ozel'}) do try('ayar sekmesi ' .. tab, FT.SettingsTab, tab) end
for _, key in ipairs(FT.themeOrder or {}) do try('tema ' .. key, FT.ApplyTheme, key) end
try('görev penceresi', function()
 -- eski takip kutusu pencere kurulmadan önce satır çizmiş olabilir: böyle bir satırı elle oluşturup göster
 local legacy = CreateFrame('Button', nil, FT.tracker)
 legacy:Show()
 table.insert(FT.tracker.legacyRows[1], legacy)
 assert(legacy:IsShown(), 'ön koşul: eski satır görünür olmalı')
 assert(FT.BuildQuestDock(), 'görev penceresi kurulamadı: ' .. tostring(FT.questDockError))
 assert(FT.questDock and FT.QuestFrame() == FT.questDock, 'QuestFrame pencereyi döndürmeli')
 for kind, scale in pairs(FT.QuestDockChildScales()) do assert(scale == 1, 'kutunun kendi ölçeği 1 olmalı: ' .. kind .. '=' .. tostring(scale)) end
 FT.tracker:SetScale(0.9); for kind, scale in pairs(FT.QuestDockChildScales()) do assert(scale == 1, 'sonradan SetScale çağrısı pencereyi ölçeklemeli, kutuyu değil: ' .. kind) end
 ForeverTrailSettings.dockTab = 'avail'; FT.RefreshQuestDock()
 assert(FT.questDock.activeTab == 'avail' or not FT.availableBox:IsShown(), 'alınabilir sekmesi')
 ForeverTrailSettings.dockTab = 'tracker'; FT.RefreshQuestDock()
 assert(FT.questDock.activeTab == 'tracker', 'görevlerim sekmesi')
 FT.tracker:Hide(); assert(not FT.tracker:IsShown(), 'Hide istenen görünürlüğü kapatmalı'); FT.tracker:Show(); assert(FT.tracker:IsShown(), 'Show açmalı')
 ForeverTrailSettings.dockCollapsed = true; FT.RefreshQuestDock(); ForeverTrailSettings.dockCollapsed = nil; FT.RefreshQuestDock()
 FT.RefreshTracker(); FT.RefreshAvailableBox()
 -- eski takip kutusunun satırları (görev penceresi kurulmadan önce çizilmiş olabilir) yeni listede görünmemeli
 for _, pool in ipairs(FT.tracker.legacyRows or {}) do
  for _, row in ipairs(pool) do assert(not (row.IsShown and row:IsShown()), 'eski takip satırı hâlâ görünür') end
 end
 -- Alınabilir: eski kutunun satırları yeni listede görünmemeli (eski satırı elle oluşturup göster)
 do
  local legacyRow = CreateFrame('Button', nil, FT.availableBox)
  legacyRow:Show()
  table.insert(FT.availableBox.legacyRows[1], legacyRow)
  assert(legacyRow:IsShown(), 'ön koşul: eski alınabilir satırı görünür olmalı')
  FT.RefreshAvailableBox()
  assert(not legacyRow:IsShown(), 'eski alınabilir satırı hâlâ görünür')
  assert((FT.availRenders or 0) > 0, 'alınabilir listesi (AvailList) çizilmeli')
  -- boyutlandırma: kayıtlı genişlik ve yükseklik pencereye uygulanır, çift tıklama otomatik boyuta döndürür
  assert(FT.questDock.grip, 'boyutlandırma tutamacı')
  ForeverTrailSettings.dockW, ForeverTrailSettings.dockH = 440, 520
  FT.RefreshTracker(); FT.RefreshAvailableBox()
  assert(FT.QuestDockWidth() == 440 and FT.QuestDockViewHeight(70) == 520 - 36 - 70 - 10, 'kayıtlı boyut')
  ForeverTrailSettings.dockW = 99999; assert(FT.QuestDockWidth() <= 640, 'genişlik üst sınırı')
  ForeverTrailSettings.dockW = 10; assert(FT.QuestDockWidth() >= 300, 'genişlik alt sınırı')
  FT.questDock.grip:GetScript('OnDoubleClick')(FT.questDock.grip)
  assert(ForeverTrailSettings.dockW == nil and ForeverTrailSettings.dockH == nil and FT.QuestDockViewHeight(70) == nil, 'çift tık otomatik boyuta dönmeli')
 end
 local blocks0 = FT.QuestListInfo()
 assert(blocks0 >= 1, 'görev listesi en az bir blok çizmeli: ' .. tostring(blocks0))
 for _, sort in ipairs({'durum', 'bolge', 'yakin', 'seviye', 'yuzde'}) do
  ForeverTrailSettings.c_trackerSort = sort; FT.RefreshTracker()
  assert(FT.QuestListInfo() >= 1, 'sıralama ' .. sort)
 end
 for _, view in ipairs({'liste', 'tablo', 'detay'}) do ForeverTrailSettings.c_trackerView = view; FT.RefreshTracker() end
 ForeverTrailSettings.c_trackerSort = nil; ForeverTrailSettings.c_trackerView = nil; FT.RefreshTracker()
 for _, kind in ipairs({'tracker', 'avail'}) do FT.ToggleViewOptions(kind); FT.ToggleViewOptions(kind) end
 assert(ForeverTrailSettings.availbox ~= false, 'eski "alınabilir kutusunu kapat" ayarı temizlenmeli')
 FT.RefreshAvailableBox(); assert(FT.availableBox:IsShown(), 'alınabilir sekmesi görünür olmalı')
 local tip = FT.Kit.Tooltip()
 tip:SetOwner(UIParent, 'ANCHOR_LEFT'); tip:SetText('[5] Test', 1, 1, 0); tip:AddLine('açıklama', 1, 1, 1); tip:AddLine(' ')
 tip:AddDoubleLine('Ödül', '100 XP', 0.6, 0.6, 0.6, 1, 1, 1); tip:AddBar('hedef', 1, 3, 0.5, 0.9, 0.5); tip:AddRule(); tip:Show(); tip:Hide()
 FT.QuestRowTip(FT.questDock, 1); FT.QuestInfoTip(FT.Kit.Tooltip(), 1, nil, 100); FT.Kit.HideTips()
end)
try('ortak bileşenler', function()
 local Kit = FT.Kit
 assert(Kit and Kit.RAIL_W == 84, 'Kit yok')
 FT.ApplyTheme('g_gece'); local a = Kit.Color('mid')
 FT.ApplyTheme('g_orman'); local b = Kit.Color('mid')
 assert(a[2] ~= b[2] or a[1] ~= b[1], 'zemin rengi temayla değişmeli')
 for _, role in ipairs({'rail', 'mid', 'panel', 'card', 'line', 'deep', 'accent', 'text', 'muted'}) do assert(#Kit.Color(role) == 4, 'rol ' .. role) end
 assert(Kit.Color('rail')[1] < Kit.Color('panel')[1], 'şerit paneli koyu olmalı')
 local btn = Kit.Button(UIParent, 'Tamam', 80, 24, 'primary')
 assert(btn:GetFontString() and btn:GetText() == 'Tamam', 'Kit düğmesi yazısı'); btn:Disable(); btn:Enable()
 local got; local chk = Kit.Check(UIParent, 'x', function() return true end, function(v) got = v end)
 assert(chk:GetChecked() == true, 'onay kutusu başlangıcı'); chk:GetScript('OnClick')(chk); assert(got == false and chk:GetChecked() == false, 'onay kutusu değişimi')
 assert(FT.panel.activate and FT.panel.resume and FT.panel.prevButton and FT.panel.nextButton, 'rehber paneli düğmeleri')
 assert(FT.panel.journeyRows and #FT.panel.journeyRows == 6 and FT.panel.journeyHead, 'yolculuk bölümü')
 -- yeni Rehber paneli: bölümler, kart yüksekliği içeriğe göre, küçük panel geçişi
 do
  local f = FT.panel
  assert(f.stepCard and f.body and f.typeChip and f.counter and f.stepText and f.guideSub and f.pct, 'Rehber paneli bölümleri')
  FT.Refresh()
  local counter = f.counter:GetText()
  assert(type(counter) == 'string' and (counter:match('^%d+ / %d+$') or counter == 'Görev günlüğü'), 'adım sayacı: ' .. tostring(counter))
  assert(type(f.instruction:GetText()) == 'string', 'adım başlığı')
  f.instruction.GetStringHeight = function() return 40 end; FT.LayoutPanel(); local h1 = f.fullH
  f.instruction.GetStringHeight = function() return 60 end; FT.LayoutPanel(); local h2 = f.fullH
  assert(h2 - h1 == 20, 'kart yüksekliği başlık yüksekliğiyle artmalı: ' .. tostring(h2 - h1))
  assert(f.fullH > f.compactH, 'tam panel küçük panelden yüksek olmalı')
  f.instruction.GetStringHeight = nil
  FT.SetCompact(true); FT.SetCompact(false); FT.Refresh()
 end
 do -- yolculuk adımı ayrıştırma ve sınıflandırma
  local clean, seconds = FT.JourneySplitTime('Uçuş: A → B (1:28)')
  assert(clean == 'Uçuş: A → B' and seconds == 88, 'süre ayrıştırma: ' .. tostring(clean) .. '/' .. tostring(seconds))
  local c2, s2 = FT.JourneySplitTime('Bulunduğun yerden dışarı çık.')
  assert(c2 == 'Bulunduğun yerden dışarı çık.' and s2 == nil, 'süresiz adım')
  local cases = {{'Uçuş: A → B', false, 'UÇUŞ'}, {'Bulunduğun yerden dışarı çık.', false, 'ÇIKIŞ'}, {'Zeplin ustasına git', false, 'ZEPLİN'},
   {'Alliance için gemi tarifi', false, 'GEMİ'}, {'Elwynn bölgesine yürüyerek ya da binekle git.', false, 'YÜRÜ'}, {'Deadmines girişine git', false, 'GİRİŞ'},
   {'Elwynn: Test (30.0, 60.0)', true, 'VARIŞ'}, {'başka bir şey', false, 'ADIM'}}
  for _, c in ipairs(cases) do
   local label = FT.JourneyClassify(c[1], c[2])
   assert(label == c[3], 'sınıflandırma: ' .. c[1] .. ' -> ' .. tostring(label) .. ' (beklenen ' .. c[3] .. ')')
  end
 end
 FT.RefreshJourney(); ForeverTrailSettings.journeyOpen = false; FT.RefreshJourney(); ForeverTrailSettings.journeyOpen = nil; FT.RefreshJourney()
 FT.OpenHub('rehber'); assert(FT.hub.rail and FT.hub.pageTitle:GetText() == 'Rehber', 'hub başlığı')
 FT.OpenHub('gorevler'); assert(FT.hub.pageDesc:GetText() ~= '', 'hub açıklaması')
 local w0, h0
 for _, page in ipairs({'rehber', 'gorevler', 'ansiklopedi', 'sinif', 'meslek', 'yerler', 'araclar', 'ayarlar'}) do
  FT.OpenHub(page)
  local w, h = FT.hub:GetWidth(), FT.hub:GetHeight()
  w0, h0 = w0 or w, h0 or h
  assert(w == w0 and h == h0, 'hub boyutu sayfalar arasında sabit olmalı: ' .. page)
 end
 assert(#FT.settings.tabButtons == #FT.SettingsTabs, 'ayarlar kategori sekmeleri')
 FT.ApplyTheme('g_gece')
end)
try('renk şemaları', function()
 assert(FT.defaultTheme == 'g_gece' and FT.Themes.g_gece, 'varsayılan şema')
 local shown = {}
 for _, k in ipairs(FT.themeOrder) do shown[k] = true; local t = FT.Themes[k]; assert(t and t.bg and t.border and t.band and t.accent, 'şema alanları ' .. k) end
 for _, k in ipairs({'g_gece', 'g_grafit', 'g_orman', 'g_erik'}) do assert(shown[k], 'menüde yok: ' .. k) end
 for old in pairs(FT.legacyThemes) do assert(FT.Themes[old] and not shown[old], 'eski tema kodda durmalı ama menüde olmamalı: ' .. old) end
 FT.ApplyTheme('g_erik'); assert(ForeverTrailSettings.theme == 'g_erik', 'şema uygulanmadı')
 FT.ApplyTheme('yok'); assert(ForeverTrailSettings.theme == 'g_gece', 'bilinmeyen şema varsayılana dönmeli')
end)
for _, name in ipairs({'SuggestNext', 'ShowMissedQuests', 'ShowSetupWizard', 'ShowSummary', 'ShowProfessionGuide', 'ShowTalentAdvice',
 'ShowLogCleanup', 'ShowDungeonQuests', 'ToggleDataWindow', 'ToggleRecorder', 'ToggleTransfer', 'BuildRoute', 'SelectNearest',
 'ScanUpgrades', 'ShareStep', 'ToggleCard', 'ToggleTracker', 'ToggleArrow', 'ToggleDock', 'ToggleLock', 'ResetLayout', 'CycleFont',
 'OpenMap', 'Plan', 'CycleMapMode', 'RefreshEncyclopedia', 'ShowRoutePlan', 'UpdateInfoBar', 'ApplyCamera', 'TrainerCheck', 'ToggleAutoRoute', 'ToggleProfiles', 'SaveProfile', 'OpenAskRoute', 'ShowGearFinder', 'ShowDungeonGuide', 'ShowWeaponMasters', 'ShowJourney', 'RefreshTracker', 'RefreshTarget', 'ApplySimple', 'ApplyUIScale', 'ShowChainOnMap', 'SortBags', 'SellJunk'}) do
 if FT[name] then try(name, FT[name]) else errors[#errors + 1] = 'eksik fonksiyon: FT.' .. name end
end
WorldMapFrame:Show(); try('RefreshMap', FT.RefreshMap); try('RefreshMapRoute', FT.RefreshMapRoute); try('RefreshCustomizePage', FT.RefreshCustomizePage); tick(8)
UnitFactionGroup = function() return 'Alliance' end
for _, cmd in ipairs({'', 'yardim', 'test', 'debug', 'seviye', 'gecmis', 'plan', 'yerler', 'sonraki', 'veri', 'ozet', 'meslek', 'kurulum', 'kilit', 'hata'}) do
 try('/ftrail ' .. cmd, SlashCmdList.FOREVERTRAIL, cmd)
end
try('profil yükle', FT.LoadProfile, 'Test'); try('tuş', FT_ForeverTrailCall, 'SuggestNext'); for _, e in ipairs({'arrive','progress','complete','warn'}) do try('ses '..e, FT.PlayEventSound, e) end
fire('QUEST_TURNED_IN', 7); runTimers()
fire('CONFIRM_SUMMON'); fire('RESURRECT_REQUEST'); fire('DUEL_REQUESTED', 'Biri'); fire('TRAINER_SHOW')
QuestFrame = UIParent; fire('PLAYER_XP_UPDATE'); fire('QUEST_DETAIL'); runTimers(); fire('QUEST_COMPLETE'); fire('GOSSIP_SHOW'); fire('MERCHANT_SHOW'); fire('BAG_UPDATE_DELAYED')
fire('PLAYER_LEVEL_UP', 11); fire('PLAYER_TARGET_CHANGED'); fire('ZONE_CHANGED_NEW_AREA'); fire('LOOT_READY')
runTimers(); tick(20)
if FT.errors then for _, e in ipairs(FT.errors) do errors[#errors + 1] = 'eklenti hata kaydı: ' .. tostring(e) end end

-- Türkçe yazı tipi denetimi: eklentinin yazılarında Türkçe harf desteklemeyen yazı tipi kalmamalı
FT.ApplyFont()
local bad, total = 0, 0
local function rootName(f) local guard = 0 while f and guard < 20 do local n = rawget(f, '__name') if n and n:find('^ForeverTrail') then return n end f = rawget(f, '__parent'); guard = guard + 1 end end
for _, f in ipairs(frames) do
 if f.__kind == 'FontString' and rootName(f) and (f.__text or '') ~= '' then
  total = total + 1
  local font = f.__font or 'Fonts\\FRIZQT__.TTF'
  if font:find('FRIZQT') then bad = bad + 1; if bad <= 5 then print('Türkçe desteklemeyen yazı:', rootName(f), f.__text) end end
 end
end
print(('Yazı tipi denetimi: %d yazıdan %d tanesi Türkçe desteklemiyor'):format(total, bad))
if bad > 0 then errors[#errors + 1] = 'Türkçe yazı tipi uygulanmamış yazılar var' end
do
 local total, worst, ticks = 0, 0, 56
 for f, t in pairs(PERF) do total = total + t; if t > worst then worst = t end end
 print(('Performans: yükleme %.2f sn, veri belleği %.1f MB, OnUpdate ortalama %.2f ms/kare (en ağır çerçeve %.2f ms/kare)'):format(PERF_LOAD[1], PERF_LOAD[2] / 1024, total / ticks * 1000, worst / ticks * 1000))
end
if BENCH then
 WorldMapFrame:Show(); FT.OpenMap()
 PROF = {}
 for name, fn in pairs(PROFILE and FT or {}) do
  if type(fn) == 'function' then
   FT[name] = function(...)
    local c = os.clock()
    local r = {fn(...)}
    local p = PROF[name] or {0, 0}; p[1] = p[1] + (os.clock() - c); p[2] = p[2] + 1; PROF[name] = p
    return unpack(r)
   end
  end
 end
 local avail = FT.Module('AvailableQuests')
 for f in pairs(PERF) do PERF[f] = 0 end
 APICALLS = 0
 local c0 = os.clock()
 tick(40)
 local worstTick = 0
 for i = 1, 40 do local c = os.clock(); tick(1); worstTick = math.max(worstTick, os.clock() - c) end
 local elapsed = os.clock() - c0
 local list = {}
 for name, p in pairs(PROF) do list[#list + 1] = {name, p[1], p[2]} end
 table.sort(list, function(a, b) return a[2] > b[2] end)
 for i = 1, 30 do local e = list[i] if e then print(('  profil: %-24s %7.1f ms toplam, %5d çağrı'):format(e[1], e[2] * 1000, e[3])) end end
 print(('AĞIR SENARYO (20 görev, sv30, harita açık, 20 sn): kare başı ortalama %.2f ms, en kötü kare %.1f ms, görev API çağrısı %d/sn'):format(elapsed / 80 * 1000, worstTick * 1000, APICALLS / 20))
end
if DESIGN then print(DESIGN, 'solda kutu:', tostring(AVAIL), 'kurulum:', tostring(WIZ))
print('sınıf: plan', tostring(TPLAN), 'sıradaki', TNEXT, 'sınıf görevi', CQ, 'evcil', tostring(TAME), 'maden eğitmeni', PROF, PADV)
print('rota:', tostring(ROUTE2), tostring(RSUM), 'bölge:', tostring(ZFIT), '| daha iyi:', tostring(ZBETTER), 'sessiz:', tostring(SIL), 'sıra:', tostring(TORDER))
print('janti ekran:', tostring(JSHOWN), 'sonra kayboldu:', tostring(JHIDDEN), 'kapalı:', tostring(JOFF)); for _, m in ipairs(JSHOW) do print('  ', m) end
print('yol çizme: eklenen', PATH, 'geri sonrası', PATH2, 'geçilen', PASSED, 'son hedef', PEND, '| zindan', table.concat(DUNG, ' '), '| engellendi kaydı', FORB)
print('nadir kart:', tostring(RCARD), 'haritada nadir:', RDOTS, 'büyücü/savaşçı/maden eğitmeni başka sınıf mı:', OTHER, 'listede başka sınıf eğitmeni:', OTHERCOUNT)
print('varsayılan stil:', QSTYLE, 'questie ayarlar:', tostring(QOPT), 'kasaba:', TOWN, 'yetenek paneli:', tostring(TPAN))
print('yol sor:', table.concat(ROUTE, ' '))
print('eşya:', tostring(UPSHOWN), SCORE, 'takılan:', tostring(EQUIPPED), 'atılan:', tostring(SWAPPED)) end
if #errors == 0 then print('Oyun benzetimi: hata yok') else
 local seen = {}
 for _, e in ipairs(errors) do if not seen[e] then seen[e] = true; print('HATA', e) end end
 os.exit(1)
end
