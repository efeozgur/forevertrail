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
 EnableMouse = function(self, v) self.__mouse = v end, IsMouseEnabled = function(self) return self.__mouse == true end,
 SetMovable = function(self, v) self.__movable = v end, IsMovable = function(self) return self.__movable == true end,
 SetTexture = function(self, t) self.__tex = t end, GetTexture = function(self) return self.__tex end,
 SetAlpha = function(self, a) self.__alpha = a end, GetAlpha = function(self) return self.__alpha or 1 end,
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
GetItemInfo = function(...) if ITEMINFO then return ITEMINFO(...) end return nil end; GetItemIcon = function() return nil end; GetItemCooldown = function() return 0, 0 end
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
ITEMINFO = function(l) local i = l and ITEMS[tostring(l):match('item:%d+')]; if not i then return nil end return i[1], l, i[2], i[3], i[4], '', '', 1, i[5], 'icon', i[6], i[7], i[8], i[9] end
GetItemStats = function(l) if l:find('200') then return {ITEM_MOD_STRENGTH_SHORT = 5, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 9.5} end return {ITEM_MOD_STRENGTH_SHORT = 2, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 7} end
INV = {[16] = 'item:100'}
GetInventoryItemLink = function(_, slot) return INV[slot] end
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end
C_Container.GetContainerItemInfo = function(bag, slot) if bag ~= 0 then return nil end return slot == 1 and {hyperlink = 'item:200', stackCount = 1} or {hyperlink = 'item:300', stackCount = 1} end
-- kuşanma yöntemleri sırayla denenir; testte hangisinin işe yaradığı ayarlanır
EQUIP_VIA = 'name'
EquipItemByName = function(l, slot) EQUIPPED = l; if EQUIP_VIA == 'name' then INV[slot] = l end end
C_Container.UseContainerItem = function(bag, slot) USED = (USED or 0) + 1; if EQUIP_VIA == 'use' then INV[16] = C_Container.GetContainerItemInfo(bag, slot).hyperlink end end
ForeverTrailSettings.upgrades = true
if FT.upgradePopup then FT.upgradePopup:Hide() end
try('eşya tarama', FT.ScanUpgrades)
UPSHOWN = FT.upgradeCompare and FT.upgradeCompare:IsShown()
assert(UPSHOWN, 'daha iyi eşya penceresi açılmalı')
try('tak', function() FT.upgradeCompare.equip:GetScript('OnClick')(FT.upgradeCompare.equip) end)
runTimers()
assert(INV[16] == 'item:200', 'Tak eşyayı gerçekten kuşanmalı: ' .. tostring(INV[16]))
assert(not FT.upgradeCompare:IsShown(), 'kuşanınca aynı pencere yeniden gelmemeli')
-- ilk yöntem sessizce başarısız olursa ikincisi denenir
INV[16] = 'item:100'; EQUIP_VIA = 'use'; USED = 0
try('eşya tarama 2', FT.ScanUpgrades); assert(FT.upgradeCompare:IsShown(), 'ikinci pencere')
FT.upgradeCompare.equip:GetScript('OnClick')(FT.upgradeCompare.equip); runTimers()
assert(INV[16] == 'item:200' and USED >= 1, 'ilk yöntem işe yaramazsa çanta sağ tık yöntemi denenmeli')
-- hiçbiri işe yaramazsa: aynı öneri sonsuza dek tekrar gelmemeli, kullanıcıya haber verilmeli
INV[16] = 'item:100'; EQUIP_VIA = 'none'
try('eşya tarama 3', FT.ScanUpgrades); assert(FT.upgradeCompare:IsShown(), 'üçüncü pencere')
FT.upgradeCompare.equip:GetScript('OnClick')(FT.upgradeCompare.equip); runTimers()
try('eşya tarama 4', FT.ScanUpgrades)
assert(not FT.upgradeCompare:IsShown(), 'kuşanılamayan eşya için pencere tekrar tekrar açılmamalı')
INV[16] = 'item:100'
SCORE = ('puan yeni %.1f / eski %.1f'):format(FT.ItemScore('item:200'), FT.ItemScore('item:100'))
try('çanta dolu', FT.ShowSwapCompare, 'item:400', 5000, {{bag = 0, slot = 2, link = 'item:300', value = 3, count = 1}}, function(v) SWAPPED = v.link end)
try('çanta seç', function() local r = FT.swapCompare.rows[1]; r:GetScript('OnClick')(r) end)
-- Ok: aynı kıtada başka haritadaki hedefe (şehir içi, komşu bölge) dünya koordinatından yön verir; kıta farklıysa "Başka bölge"
do
 local maps = {[1429] = {inst = 0, top = 1000, bottom = 0, left = 1000, right = 0}, [1431] = {inst = 0, top = 2000, bottom = 1000, left = 1000, right = 0},
  [1411] = {inst = 1, top = 1000, bottom = 0, left = 1000, right = 0}}
 local realW, realM, realV = C_Map.GetWorldPosFromMapPos, C_Map.GetMapPosFromWorldPos, CreateVector2D
 CreateVector2D = function(x, y) return {x = x, y = y, GetXY = function(self) return self.x, self.y end} end
 C_Map.GetWorldPosFromMapPos = function(map, v) local m = maps[map]; if not m then return nil end return m.inst, CreateVector2D(m.top + (m.bottom - m.top) * v.y, m.left + (m.right - m.left) * v.x) end
 C_Map.GetMapPosFromWorldPos = function(inst, v, map) local m = maps[map]; if not m or m.inst ~= inst then return nil end
  return map, CreateVector2D((v.y - m.left) / (m.right - m.left), (v.x - m.top) / (m.bottom - m.top)) end
 local savedTarget = FT.customTarget
 FT.customTarget = {stepId = 'proj', type = 'location', questTitle = 'Komşu', text = 'Komşu', uiMapID = 1431, x = 0.5, y = 0.5}
 FT.nav = nil; FT.UpdateArrow()
 assert(FT.nav and FT.nav.step and FT.nav.step.projected and FT.nav.step.uiMapID == 1429, 'aynı kıtada başka haritadaki hedefe yön verilmeli (ok başka bölge demeli değil)')
 assert(FT.nav.final == FT.customTarget and FT.nav.dist > 100, 'son hedef özgün adım olmalı, mesafe dünya koordinatından hesaplanmalı: ' .. tostring(FT.nav.dist))
 FT.customTarget = {stepId = 'far', type = 'location', questTitle = 'Uzak', text = 'Uzak', uiMapID = 1411, x = 0.5, y = 0.5}
 FT.nav = nil; FT.UpdateArrow()
 assert(FT.nav == nil, 'farklı kıtadaki hedefe projeksiyon yapılmamalı')
 FT.customTarget = savedTarget
 C_Map.GetWorldPosFromMapPos, C_Map.GetMapPosFromWorldPos, CreateVector2D = realW, realM, realV
 FT.nav = nil
end
-- En yakın adım (ok sağ tık): seçili bölge rehberinde kalır, günlük rehberine geçmez
do
 local saved = FT.guide
 local g = {guideId = 'yakin-testi', version = 1, title = 'Y', zone = 'Z', steps = {
  {stepId = 'a', type = 'accept', questId = 801, uiMapID = 1429, x = 0.10, y = 0.10, text = 'a'},
  {stepId = 'b', type = 'accept', questId = 802, uiMapID = 1429, x = 0.49, y = 0.42, text = 'b'},
  {stepId = 'c', type = 'accept', questId = 803, uiMapID = 1429, x = 0.90, y = 0.90, text = 'c'}}}
 FT.guide = g; FT.active, FT.view, FT.complete = 1, 1, false
 FT.SelectNearest()
 assert(FT.guide == g and FT.guide.guideId == 'yakin-testi', 'bölge rehberi seçiliyken günlük rehberine geçilmemeli: ' .. tostring(FT.guide and FT.guide.guideId))
 assert(FT.active == 2, 'en yakın adım seçilmeli: ' .. FT.active)
 -- elle atlanan adım aday olmaz
 ForeverTrailCharacter.skipped = {['yakin-testi:b'] = true}
 FT.active = 1; FT.SelectNearest()
 assert(FT.active ~= 2, 'atlanan adım en yakın olarak seçilmemeli')
 ForeverTrailCharacter.skipped = nil
 FT.guide = saved
end
-- NPC işlemleri: hazır rehber seçiliyken yalnızca rehberdeki görevler otomatik alınır/teslim edilir
do
 local QID, accepted, completed, rewards, selectedA, selectedT = nil, {}, {}, {}, {}, {}
 GetQuestID = function() return QID end
 AcceptQuest = function() accepted[#accepted + 1] = QID end
 ConfirmAcceptQuest = function() accepted[#accepted + 1] = 'c' .. tostring(QID) end
 IsQuestCompletable = function() return true end
 CompleteQuest = function() completed[#completed + 1] = QID end
 GetNumQuestChoices = function() return 1 end
 GetQuestReward = function() rewards[#rewards + 1] = QID end
 C_GossipInfo = {GetActiveQuests = function() return {{questID = 11, isComplete = true}, {questID = 99, isComplete = true}} end,
  GetAvailableQuests = function() return {{questID = 99}, {questID = 11}} end,
  SelectActiveQuest = function(id) selectedT[#selectedT + 1] = id end, SelectAvailableQuest = function(id) selectedA[#selectedA + 1] = id end}
 local savedGuide = FT.guide
 FT.guide = {guideId = 'npc-testi', version = 1, title = 'T', zone = 'Z', steps = {{stepId = 'a', type = 'accept', questId = 11, text = 'a'}, {stepId = 't', type = 'turnin', questId = 11, text = 't'}}}
 ForeverTrailSettings.autoquest, ForeverTrailSettings.autoquestAll = nil, nil
 QID = 11; fire('QUEST_DETAIL'); QID = 99; fire('QUEST_DETAIL')
 assert(#accepted == 1 and accepted[1] == 11, 'rehber görevi alınmalı, diğeri alınmamalı: ' .. table.concat(accepted, ','))
 QID = 11; fire('QUEST_ACCEPT_CONFIRM'); QID = 99; fire('QUEST_ACCEPT_CONFIRM')
 assert(accepted[2] == 'c11' and #accepted == 2, 'onay penceresi yalnızca rehber görevi için kabul edilmeli')
 QID = 11; fire('QUEST_PROGRESS'); QID = 99; fire('QUEST_PROGRESS')
 assert(#completed == 1 and completed[1] == 11, 'yalnızca rehber görevi tamamlanmalı')
 QID = 11; fire('QUEST_COMPLETE'); QID = 99; fire('QUEST_COMPLETE')
 assert(#rewards == 1 and rewards[1] == 11, 'yalnızca rehber görevi teslim edilmeli: ' .. table.concat(rewards, ','))
 fire('GOSSIP_SHOW')
 assert(selectedT[1] == 11 and #selectedT == 1, 'konuşmada yalnızca rehber görevinin teslimi seçilmeli')
 -- teslim edilecek bir şey kalmayınca (pencere yeniden açılır) alınabilir görevlerden yalnızca rehberdekini seç
 C_GossipInfo.GetActiveQuests = function() return {} end
 fire('GOSSIP_SHOW')
 assert(selectedA[1] == 11 and #selectedA == 1, 'konuşmada yalnızca rehber görevi alınmak üzere seçilmeli: ' .. table.concat(selectedA, ','))
 -- rehber dışı görevler de otomatik: eski davranış
 ForeverTrailSettings.autoquestAll = true
 QID = 99; fire('QUEST_DETAIL'); assert(accepted[#accepted] == 99, 'autoquestAll açıkken her görev alınmalı')
 ForeverTrailSettings.autoquestAll = nil
 -- canlı görev günlüğü rehberinde kısıt yok
 FT.guide = {guideId = 'character-log', live = true, version = 1, title = 'T', zone = 'Z', steps = {{stepId = 'w', type = 'manual', text = 'w'}}}
 local n = #accepted; QID = 77; fire('QUEST_DETAIL'); assert(#accepted == n + 1, 'canlı rehberde eski davranış: her görev alınmalı')
 -- ayar kapalıysa hiçbiri
 ForeverTrailSettings.autoquest = false; n = #accepted; QID = 77; fire('QUEST_DETAIL'); assert(#accepted == n, 'autoquest=false hiçbir şeyi otomatik almamalı')
 ForeverTrailSettings.autoquest = nil
 FT.guide = savedGuide
end
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
 do -- Rehber sekmesi: NPC, fiil + görev adı, yolculuk, sonra, gezinme, boyuta göre sıradaki adımlar
  assert(FT.guideBox, 'rehber kutusu kurulmalı')
  local savedGuide, savedView, savedActive, savedComplete = FT.guide, FT.view, FT.active, FT.complete
  local steps = {}
  for i = 1, 20 do steps[i] = {stepId = 's' .. i, type = 'manual', text = 'Adım ' .. i} end
  steps[2] = {stepId = 's2', type = 'accept', npc = 'Eleanor', questTitle = 'Camping 101', text = 'Görevi al.', uiMapID = 1429, x = 0.4, y = 0.5}
  steps[4] = {stepId = 's4', type = 'turnin', npc = 'Johaan', questTitle = 'Teslim 4', text = 'Teslim et.', uiMapID = 1429, x = 0.45, y = 0.5}
  FT.guide = {guideId = 'sekme-testi', version = 1, title = 'Sekme Testi', zone = 'Bölge', levels = '1-10', steps = steps}
  FT.view, FT.active, FT.complete = 1, 1, false
  FT.customTarget = nil
  ForeverTrailSettings.dockTab = 'guide'; ForeverTrailSettings.dockW, ForeverTrailSettings.dockH = nil, nil
  FT.RefreshQuestDock()
  local box = FT.guideBox
  assert(FT.questDock.activeTab == 'guide', 'rehber sekmesi seçilebilmeli')
  assert(box:GetParent() == FT.questDock, 'rehber kutusu pencerenin içinde olmalı')
  assert(box.title:GetText() == 'Sekme Testi', 'rehber adı: ' .. tostring(box.title:GetText()))
  assert(box.counter:GetText() == '1 / 20', 'sayaç: ' .. tostring(box.counter:GetText()))
  assert(box.stepLine:GetText() == 'Adım 1' and not box.npc:IsShown(), 'NPC\'siz adımda yalnızca adım metni görünmeli: ' .. tostring(box.stepLine:GetText()))
  assert(FT.GuideTabRows() == 0, 'pencere elle büyütülmedikçe sıradaki adım listesi gizli olmalı')
  -- NPC'li adım: büyük NPC adı, "Görevi al “ad”", sıradaki durak
  FT.view = 2; FT.RefreshGuideTab()
  assert(box.npc:IsShown() and box.npc:GetText() == 'Eleanor', 'NPC adı büyük başlıkta olmalı: ' .. tostring(box.npc:GetText()))
  assert(box.stepLine:GetText() == 'Görevi al “Camping 101”', 'fiil + görev adı: ' .. tostring(box.stepLine:GetText()))
  assert(box.then_:IsShown() and box.then_.name:GetText() == 'Johaan', 'sonraki durak: ' .. tostring(box.then_.name:GetText()))
  FT.Refresh()
  assert(FT.panel.instruction:GetText() == 'Eleanor' and tostring(FT.panel.stepText:GetText()):find('Görevi al', 1, true), 'Hub rehber kartı da NPC adını göstermeli: ' .. tostring(FT.panel.instruction:GetText()))
  assert(FT.GuideTabJourneyRows() == 1, 'aynı bölgede tek yolculuk satırı: ' .. FT.GuideTabJourneyRows())
  -- başka bölgedeki hedef: simgeli yolculuk adımları
  FT.customTarget = {stepId = 'custom', type = 'location', questTitle = 'Uzak', text = 'Uzak', uiMapID = 1426, x = 0.3, y = 0.3}
  FT.RefreshGuideTab()
  assert(FT.GuideTabJourneyRows() >= 2, 'başka bölgede yolculuk adımları listelenmeli: ' .. FT.GuideTabJourneyRows())
  FT.customTarget = nil
  -- gezinme: ">" etkin adımı ilerletir, "<" yalnızca inceler, "Atla" etkin adıma dönüp ilerletir
  FT.view = 1; FT.RefreshGuideTab()
  box.next:GetScript('OnClick')(box.next)
  assert(FT.active == 2 and FT.view == 2, 'ileri düğmesi adımı ilerletmeli: ' .. FT.active .. '/' .. FT.view)
  assert(box.counter:GetText() == '2 / 20', 'sayaç ilerlemeli: ' .. tostring(box.counter:GetText()))
  box.prev:GetScript('OnClick')(box.prev)
  assert(FT.view == 1 and FT.active == 2 and box.resume:IsShown(), 'geri düğmesi yalnızca incelemeli, "Buradan sürdür" görünmeli')
  box.skip:GetScript('OnClick')(box.skip)
  assert(FT.active == 3 and FT.view == 3, 'Atla etkin adıma dönüp ilerletmeli: ' .. FT.active .. '/' .. FT.view)
  -- Polestar tarzı ayrıntılar: açılır yolculuk, numaralı adımlar, hedef satırı, onay kutusu
  do
   FT.view, FT.active = 3, 3
   FT.customTarget = {stepId = 'custom2', type = 'location', questTitle = 'Uzak Hedef', text = 'Uzak', uiMapID = 1426, x = 0.3, y = 0.3}
   ForeverTrailSettings.gtJourneyOpen = nil; FT.RefreshGuideTab()
   assert(box.goal:IsShown() and box.goal.name:GetText() == 'Uzak Hedef', 'hedef satırı: ' .. tostring(box.goal.name:GetText()))
   assert(FT.GuideTabJourneyRows() >= 2, 'yolculuk varsayılan açık olmalı')
   box.journeyHead:GetScript('OnClick')(box.journeyHead)
   assert(ForeverTrailSettings.gtJourneyOpen == false and FT.GuideTabJourneyRows() == 0 and not box.goal:IsShown(), 'başlığa tıklayınca yolculuk kapanmalı')
   box.journeyHead:GetScript('OnClick')(box.journeyHead)
   assert(FT.GuideTabJourneyRows() >= 2 and box.goal:IsShown(), 'ikinci tıklama yeniden açmalı')
   FT.customTarget = nil; ForeverTrailSettings.gtJourneyOpen = nil
   -- onay kutusu: etkin adımı tamamlar, incelenen adımda işlem yapmaz
   FT.view, FT.active = 3, 3; FT.RefreshGuideTab()
   assert(not box.check.mark:IsShown(), 'etkin adımda kutu boş olmalı')
   box.check:GetScript('OnClick')(box.check)
   assert(FT.active == 4, 'onay kutusu adımı tamamlamalı: ' .. FT.active)
   FT.view = 2; FT.RefreshGuideTab()
   assert(box.check.mark:IsShown(), 'yapılmış adımda kutu dolu olmalı')
   box.check:GetScript('OnClick')(box.check)
   assert(FT.active == 4, 'incelenen adımda onay kutusu ilerletmemeli')
   -- seviye tahmini yoksa satır boş kalır
   assert(box.forecast:GetText() == '' or box.forecast:GetText():find('Bu gidişle', 1, true), 'tahmin satırı')
   FT.view, FT.active = 1, 1; FT.RefreshGuideTab()
  end
  -- Yapılacaklar kartı: görev satırları, XP çubuğu, seviye tahmini
  do
   local real = FT.TodoSummary
   FT.TodoSummary = function() return {
    rows = {{questId = 11, title = 'Hazır Görev', xp = 450, status = 'ready', npc = 'Johaan'}, {questId = 12, title = 'Süren Görev', xp = 300, status = 'active'}},
    readyCount = 1, readyXP = 450, activeCount = 1, activeXP = 300, futureCount = 2, futureXP = 900, totalXP = 1650,
    thisXP = 450, thisPct = 0.12, ready = {10, 0.4}, all = {11, 0.2, true}, estimated = true}
   end
   FT.view, FT.active = 1, 1; FT.RefreshGuideTab()
   local todo = box.todo
   assert(todo:IsShown() and todo.rows[1]:IsShown() and todo.rows[2]:IsShown(), 'yapılacaklar satırları görünmeli')
   assert(todo.rows[1].title:GetText() == 'Hazır Görev' and todo.rows[1].xp:GetText() == '+450 XP', 'satır: ' .. tostring(todo.rows[1].xp:GetText()))
   assert(todo.rows[1].sub:GetText() == 'Teslim: Johaan' and todo.rows[2].sub:GetText() == 'Devam ediyor', 'alt satır')
   assert(todo.head.right:GetText():find('4 görev', 1, true) and todo.head.right:GetText():find('1.650 XP', 1, true), 'başlık özeti: ' .. tostring(todo.head.right:GetText()))
   local texts = {}
   for _, fs in ipairs(todo.lines) do if fs:IsShown() then texts[#texts + 1] = fs:GetText() end end
   assert(#texts == 3 and texts[1]:find('Bu görev: +450 XP', 1, true), 'üç özet satırı: ' .. #texts)
   assert(texts[2]:find('Seviye 10', 1, true) and texts[3]:find('Seviye ~11', 1, true) and texts[3]:find('rehberde 2 görev', 1, true), 'seviye tahmini: ' .. tostring(texts[3]))
   FT.TodoSummary = function() return {rows = {}, readyCount = 0, readyXP = 0, activeCount = 0, activeXP = 0, futureCount = 0, futureXP = 0, totalXP = 0} end
   FT.RefreshGuideTab()
   assert(not box.todo:IsShown(), 'yapılacak yoksa kart gizli olmalı')
   FT.TodoSummary = real
   FT.RefreshGuideTab()
  end
  -- hedef listesi: bağımsız pencere; portre/simge, ad, sayaç, tıklama ve odak
  do
   local realObj, realSet, realOpen = FT.ActiveObjectives, FT.SetCustomTarget, FT.OpenMap
   steps[6] = {stepId = 's6', type = 'objective', questId = 999, questTitle = 'Av', text = 'Öldür', uiMapID = 1429, x = 0.4, y = 0.5}
   FT.guide = {guideId = 'sekme-testi', version = 1, title = 'Sekme Testi', zone = 'Bölge', levels = '1-10', steps = steps}
   FT.ActiveObjectives = function() return {
    {questId = 111, title = 'Başka', index = 1, kind = 'kill', npcs = {1}, objs = {}, have = 0, need = 1, done = false, color = {1, 0.8, 0.3}, text = 'Başka görev: 0/1'},
    {questId = 999, title = 'Av', index = 1, kind = 'kill', npcs = {299}, objs = {}, have = 0, need = 2, done = false, color = {1, 0.8, 0.3}, text = 'Outraged Pillager: 0/2'},
    {questId = 999, title = 'Av', index = 2, kind = 'loot', npcs = {}, objs = {}, itemId = 2589, have = 3, need = 3, done = true, color = {1, 0.8, 0.3}, text = 'Linen Cloth: 3/3'},
   } end
   FT.view, FT.active = 6, 6
   ForeverTrailSettings.targetList = nil; ForeverTrailSettings.targetListCollapsed = nil
   FT.RefreshTargetList(true)
   assert(FT.targetList and FT.targetList:IsShown(), 'hedef penceresi görünmeli')
   assert(FT.targetList:GetParent() == UIParent, 'hedef penceresi bağımsız olmalı (rehber kutusunun içinde değil)')
   local rs = FT.TargetListRows()
   assert(#rs == 2, 'tamamlanan hedef listelenmemeli: ' .. #rs)
   assert(rs[1].name:GetText() == 'Outraged Pillager' and rs[1].count:GetText() == '0/2', 'rehber görevi önce, ad ve sayaç: ' .. tostring(rs[1].name:GetText()))
   assert(rs[2].name:GetText() == 'Başka görev', 'diğer görev sonra: ' .. tostring(rs[2].name:GetText()))
   -- sağ tık: yalnızca o görevi izle; tekrar sağ tık: hepsi
   rs[1]:GetScript('OnClick')(rs[1], 'RightButton')
   assert(FT.TargetListFocus() == 999 and #FT.TargetListRows() == 1, 'sağ tık odaklanmalı: ' .. #FT.TargetListRows())
   FT.TargetListRows()[1]:GetScript('OnClick')(FT.TargetListRows()[1], 'RightButton')
   assert(FT.TargetListFocus() == nil and #FT.TargetListRows() == 2, 'ikinci sağ tık odağı kaldırmalı')
   -- sol tık: en yakın noktaya git; nokta yoksa harita açılır
   local set, opened = nil, 0
   FT.SetCustomTarget = function(map, x, y, name) set = {map = map, x = x, y = y, name = name} end
   FT.OpenMap = function() opened = opened + 1 end
   local realSpawn = FT.SpawnPoints
   FT.SpawnPoints = function() return {{map = 1429, x = 0.5, y = 0.5}, {map = 1429, x = 0.1, y = 0.1}} end
   rs = FT.TargetListRows(); rs[1]:GetScript('OnClick')(rs[1], 'LeftButton')
   assert(set and set.name == 'Outraged Pillager' and set.map == 1429, 'tık hedefi ayarlamalı: ' .. tostring(set and set.name))
   FT.SpawnPoints = function() return {} end
   set = nil; rs[1]:GetScript('OnClick')(rs[1], 'LeftButton')
   assert(not set and opened == 1, 'nokta yoksa harita açılmalı')
   FT.SpawnPoints = realSpawn
   -- başlığa tıklayınca daralır
   FT.targetList.head:GetScript('OnClick')(FT.targetList.head)
   assert(#FT.TargetListRows() == 0 and ForeverTrailSettings.targetListCollapsed == true, 'başlık tıklaması daraltmalı')
   FT.targetList.head:GetScript('OnClick')(FT.targetList.head)
   assert(#FT.TargetListRows() == 2, 'ikinci tıklama genişletmeli')
   -- ilerleme: sayaç artınca parlama; liste boşalınca pencere kapanır
   FT.ActiveObjectives = function() return {
    {questId = 999, title = 'Av', index = 1, kind = 'kill', npcs = {299}, objs = {}, have = 1, need = 2, done = false, color = {1, 0.8, 0.3}, text = 'Outraged Pillager: 1/2'},
   } end
   FT.RefreshTargetList(true)
   rs = FT.TargetListRows()
   assert(#rs == 1 and rs[1].count:GetText() == '1/2' and rs[1].flashT, 'ilerleyince satır parlamalı')
   FT.ActiveObjectives = function() return {} end
   FT.RefreshTargetList(true)
   assert(not FT.targetList:IsShown(), 'hedef kalmayınca pencere gizlenmeli')
   -- kapatma düğmesi ayarı kapatır
   FT.ActiveObjectives = function() return {{questId = 999, title = 'Av', index = 1, kind = 'kill', npcs = {}, objs = {}, have = 0, need = 1, done = false, color = {1, 0.8, 0.3}, text = 'X: 0/1'}} end
   FT.RefreshTargetList(true); assert(FT.targetList:IsShown())
   FT.targetList.close:GetScript('OnClick')(FT.targetList.close)
   assert(ForeverTrailSettings.targetList == false and not FT.targetList:IsShown(), 'kapat düğmesi pencereyi kapatmalı')
   ForeverTrailSettings.targetList = nil
   FT.ActiveObjectives, FT.SetCustomTarget, FT.OpenMap = realObj, realSet, realOpen
   FT.targetList:Hide()
   steps[6] = {stepId = 's6', type = 'manual', text = 'Adım 6'}
   FT.view, FT.active = 1, 1
  end
  -- karta tıklayınca harita açılır; sürükleme dock'a iletilir
  do
   local realOpen, opened = FT.OpenMap, 0
   FT.OpenMap = function() opened = opened + 1 end
   FT.view, FT.active = 1, 1
   box.card:GetScript('OnClick')(box.card)
   assert(opened == 1, 'karta tıklayınca harita açılmalı')
   FT.active, FT.view = 2, 1
   box.card:GetScript('OnClick')(box.card)
   assert(opened == 2 and FT.active == 1, 'inceleme modunda tıklamak o adımı etkin yapmalı: ' .. FT.active)
   FT.OpenMap = realOpen
   assert(box.card:GetScript('OnDragStart') and box.card:GetScript('OnDragStop'), 'kart sürüklemeyi pencereye iletmeli')
   FT.view, FT.active = 1, 1
  end
  -- pencere büyütülünce sıradaki adımlar listelenir; satıra tıklayınca o adım incelenir
  FT.view, FT.active = 1, 1; ForeverTrailSettings.dockH = 700; FT.RefreshGuideTab()
  assert(FT.GuideTabRows() > 3, 'büyük pencerede sıradaki adımlar görünmeli: ' .. FT.GuideTabRows())
  assert(FT.GuideTabRow(1).text:GetText() == 'Camping 101', 'ilk sıradaki adım: ' .. tostring(FT.GuideTabRow(1).text:GetText()))
  local row = FT.GuideTabRow(3)
  row:GetScript('OnClick')(row)
  assert(FT.view == 4, 'satıra tıklayınca o adım incelenmeli: ' .. FT.view)
  ForeverTrailSettings.dockH = nil
  -- rehber yokken sekme yine de açılır ve yönlendirir
  FT.guide = nil; FT.RefreshGuideTab()
  assert(FT.GuideTabRows() == 0 and box.empty:IsShown(), 'rehbersiz açıklama görünmeli')
  FT.guide, FT.view, FT.active, FT.complete = savedGuide, savedView, savedActive, savedComplete
  if FT.guide then FT.RefreshGuideTab() end
  ForeverTrailSettings.dockTab = 'tracker'; FT.RefreshQuestDock()
 end
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
 do -- görevin altında numaralı adımlar
  local function rowsOf(q) local out = {} for _, r in ipairs(FT.QuestListStepRows()) do if r.quest == q then out[#out + 1] = r end end return out end
  local savedMin = ForeverTrailCharacter.trkMin; ForeverTrailCharacter.trkMin = nil -- önceki adımlar görevleri küçültmüş olabilir
  ForeverTrailSettings.trkSteps = nil; ForeverTrailSettings.c_trackerView = 'detay'; FT.RefreshTracker()
  local r6 = rowsOf(6)
  assert(#r6 >= 2, 'sürmekte olan görevde hedef + teslim adımı olmalı: ' .. #r6)
  assert(r6[1].num == '1.' and (r6[1].text:find('^Topla: ') or r6[1].text:find('^Öldür: ') or r6[1].text:find('^Kullan: ') or r6[1].text == 'Görev hedefi'), 'ilk adım: ' .. tostring(r6[1].num) .. ' ' .. tostring(r6[1].text))
  assert(r6[1].place and r6[1].place:find('Elwynn Forest · %d+, %d+'), 'ilk adımın yeri (bölge · koordinat): ' .. tostring(r6[1].place))
  assert(r6[#r6].place and r6[#r6].place:find('%d+, %d+'), 'teslim adımının yeri: ' .. tostring(r6[#r6].place))
  assert(r6[#r6].num == tostring(#r6) .. '.' and (r6[#r6].text:find('Teslim') or r6[#r6].text:find('teslim')), 'son adım teslim: ' .. tostring(r6[#r6].text))
  FT.RefreshTracker(); assert(#rowsOf(6) == #r6, 'yeniden çizim adım sayısını değiştirmemeli')
  ForeverTrailSettings.c_trackerView = 'liste'; FT.RefreshTracker()
  assert(#FT.QuestListStepRows() == 0, 'kompakt görünümde adım yazılmaz')
  ForeverTrailSettings.c_trackerView = nil; ForeverTrailSettings.trkSteps = false; FT.RefreshTracker()
  assert(#FT.QuestListStepRows() == 0, 'ayar kapalıyken numaralı adım yok (eski hedef satırları)')
  ForeverTrailSettings.trkSteps = nil; FT.RefreshTracker()
  assert(#rowsOf(6) == #r6, 'ayar açılınca adımlar geri gelmeli')
  ForeverTrailCharacter.trkMin = {[6] = true}; FT.RefreshTracker()
  assert(#rowsOf(6) == 0, 'küçültülmüş görevde adım yazılmaz')
  ForeverTrailCharacter.trkMin = savedMin; FT.RefreshTracker()
 end
 for _, kind in ipairs({'tracker', 'avail'}) do FT.ToggleViewOptions(kind); FT.ToggleViewOptions(kind) end
 assert(ForeverTrailSettings.availbox ~= false, 'eski "alınabilir kutusunu kapat" ayarı temizlenmeli')
 FT.RefreshAvailableBox(); assert(FT.availableBox:IsShown(), 'alınabilir sekmesi görünür olmalı')
 local tip = FT.Kit.Tooltip()
 tip:SetOwner(UIParent, 'ANCHOR_LEFT'); tip:SetText('[5] Test', 1, 1, 0); tip:AddLine('açıklama', 1, 1, 1); tip:AddLine(' ')
 tip:AddDoubleLine('Ödül', '100 XP', 0.6, 0.6, 0.6, 1, 1, 1); tip:AddBar('hedef', 1, 3, 0.5, 0.9, 0.5); tip:AddRule(); tip:Show(); tip:Hide()
 FT.QuestRowTip(FT.questDock, 1); FT.QuestInfoTip(FT.Kit.Tooltip(), 1, nil, 100); FT.Kit.HideTips()
end)
try('rehber: bu görevde adımlar ve ayrıntılı ipucu', function()
 local g = FT.guide
 local idx
 for i, st in ipairs(g.steps) do if st.questId then idx = i; break end end
 assert(idx, 'rehberde görevli adım olmalı')
 local savedView, savedActive = FT.view, FT.active
 FT.view = idx; ForeverTrailSettings.gtPlan = nil; ForeverTrailSettings.gtPlanOpen = nil; FT.RefreshGuideTab()
 local rows = FT.GuideTabPlanRows()
 assert(#rows >= 2, 'görevli adımda numaralı adımlar olmalı: ' .. #rows)
 assert(rows[1].num == '1.' and rows[#rows].num == #rows .. '.' and rows[#rows].text:find('^Teslim'), 'numaralar ve son teslim adımı')
 assert(rows[1].place and rows[1].place:find('%d+, %d+'), 'ilk adımın yeri')
 ForeverTrailSettings.gtPlanOpen = false; FT.RefreshGuideTab()
 assert(#FT.GuideTabPlanRows() == 0 and FT.guideBox.planHead:IsShown(), 'kapalıyken satırlar yok, başlık var')
 ForeverTrailSettings.gtPlanOpen = nil; ForeverTrailSettings.gtPlan = false; FT.RefreshGuideTab()
 assert(#FT.GuideTabPlanRows() == 0 and not FT.guideBox.planHead:IsShown(), 'ayar kapalıyken bölüm yok')
 ForeverTrailSettings.gtPlan = nil; FT.RefreshGuideTab()
 assert(#FT.GuideTabPlanRows() == #rows, 'ayar açılınca bölüm geri gelmeli')
 -- adım kartının ipucu: görevin bütün ayrıntıları (tek ipucu, eski satır kalmaz)
 local card = FT.guideBox.card
 local tip = FT.Kit.Tooltip()
 card.__scripts.OnEnter(card)
 assert(tip.frame:IsShown() and tip:NumLines() >= 8, 'görev ayrıntı ipucu dolu olmalı: ' .. tip:NumLines())
 local parts = tip:ShownParts()
 card.__scripts.OnLeave(card); assert(not tip.frame:IsShown(), 'ayrılınca kapanmalı')
 card.__scripts.OnEnter(card); assert(select(1, tip:ShownParts()) == parts, 'tekrar açılışta aynı sayıda satır (birikme yok)')
 card.__scripts.OnLeave(card)
 -- görev kutusu satırı ve alınabilir görev ipucu da aynı ayrıntılı içeriği verir
 FT.QuestRowTip(FT.questDock, g.steps[idx].questId); assert(tip.frame:IsShown() and tip:NumLines() >= 8, 'görev satırı ipucu ayrıntılı olmalı: ' .. tip:NumLines())
 FT.Kit.HideTips(); tip:SetOwner(UIParent, 'ANCHOR_LEFT'); FT.QuestInfoTip(tip, g.steps[idx].questId, {level = 5, giver = 'Test NPC'}, 50); tip:Show()
 assert(tip:NumLines() >= 8, 'alınabilir görev ipucu ayrıntılı olmalı: ' .. tip:NumLines()); FT.Kit.HideTips()
 FT.view, FT.active = savedView, savedActive; FT.RefreshGuideTab()
end)
try('yerleşim kilidi: pencerede simge, Shift ile taşıma, bir kerelik sıfırlama, profil', function()
 local dock, s = FT.questDock, ForeverTrailSettings
 local function walk(f, fn) fn(f); for _, c in ipairs({f:GetChildren()}) do walk(c, fn) end end
 local btn
 walk(dock, function(f) if f.__kind == 'Button' and f.on and f.icon and f.__scripts.OnClick and not f.text then btn = f end end)
 assert(btn, 'görev penceresinde kilit düğmesi olmalı')
 local realPrint, realShift, realLocked = FT.Print, IsShiftKeyDown, s.locked
 local printed = {}; FT.Print = function(m) printed[#printed + 1] = m end
 -- her iki durumda da görünür; kilitliyken dolgulu ve parlak, açıkken soluk; tıklayınca buradan değişir
 s.locked = false; s.arrowLocked = false; FT.RefreshQuestDock()
 assert(btn:IsShown() and not btn.on:IsShown() and btn.icon:GetAlpha() < 1, 'açıkken görünür ama soluk ve dolgusuz')
 btn.__scripts.OnClick(btn)
 assert(s.locked == true and s.arrowLocked == true and btn.on:IsShown() and btn.icon:GetAlpha() == 1, 'tıklayınca kilitlenir, dolgulu ve parlak olur')
 btn.__scripts.OnEnter(btn); assert(FT.Kit.Tooltip().frame:IsShown(), 'kilit ipucu çıkmalı'); btn.__scripts.OnLeave(btn)
 btn.__scripts.OnClick(btn)
 assert(s.locked == false and not btn.on:IsShown() and btn.icon:GetAlpha() < 1, 'tekrar tıklayınca açılır, soluklaşır')
 -- kilitliyken Shift ile yine taşınır; Shift'siz taşınmaz ve nedeni söylenir
 local moved = 0; dock.StartMoving = function() moved = moved + 1 end
 s.locked = true; local shift = false; IsShiftKeyDown = function() return shift end
 printed = {} -- düğme tıklamalarının yazdığı 'kilitlendi/açıldı' satırlarını at
 dock.__scripts.OnDragStart(dock); assert(moved == 0 and #printed == 1 and printed[1]:find('Shift', 1, true), 'kilitli, Shift yok: taşınmaz ve Shift ipucu verilir: ' .. tostring(printed[1]))
 shift = true; dock.__scripts.OnDragStart(dock); assert(moved == 1, 'kilitliyken Shift basılıysa taşınmalı')
 assert(FT.CanDrag() == true, 'Shift ile CanDrag doğru döner'); shift = false
 s.locked = false; assert(FT.CanDrag() == true, 'kilitsizken her zaman sürüklenir')
 dock.StartMoving = nil; IsShiftKeyDown = realShift
 -- sekme iç boşluğu pencere daraldıkça küçülür (Ayar'ın altına binmesin), 24'ün altına inmez, 38'i aşmaz
 assert(FT.QuestDockTabPad(262, 169, 3) == 31 and FT.QuestDockTabPad(150, 169, 3) == 24 and FT.QuestDockTabPad(500, 100, 3) == 38 and FT.QuestDockTabPad(100, 0, 0) == 38, 'sekme boşluğu hesabı')
 -- bir kerelik sıfırlama: eskiden unutulup açık kalan kilit girişte kapanır; sonradan bilerek kilitlenen korunur
 local real = ForeverTrailSettings
 ForeverTrailSettings = {locked = true, arrowLocked = true}
 assert(FT.MigrateLayoutLock() == true and not ForeverTrailSettings.locked and not ForeverTrailSettings.arrowLocked and ForeverTrailSettings.lockVersion == 1, 'eski kilit kapanmalı')
 ForeverTrailSettings.locked = true
 assert(FT.MigrateLayoutLock() == false and ForeverTrailSettings.locked == true, 'sonradan bilerek konan kilit korunmalı')
 ForeverTrailSettings = {}
 assert(FT.MigrateLayoutLock() == false and ForeverTrailSettings.lockVersion == 1, 'kilit yoksa sürüm yine işaretlenir')
 ForeverTrailSettings = real
 -- kayıtlı profil kilidi geri getirmez (eski profillerdeki kilit de yok sayılır)
 local savedProfile = ForeverTrailCharacter and ForeverTrailCharacter.profile
 s.locked = true; FT.SaveProfile('kilittest')
 assert(s.profiles.kilittest and s.profiles.kilittest.locked == nil and s.profiles.kilittest.arrowLocked == nil, 'profil kilidi saklamamalı')
 s.profiles.eskiprofil = {locked = true, arrowLocked = true, ftTestAnahtar = 7}
 s.locked = false; s.arrowLocked = false
 FT.LoadProfile('eskiprofil')
 assert(not s.locked and not s.arrowLocked and s.ftTestAnahtar == 7, 'eski profilde kilit olsa da yüklenince pencereler kilitlenmemeli, diğer ayarlar yüklenmeli')
 s.profiles.kilittest, s.profiles.eskiprofil, s.ftTestAnahtar = nil, nil, nil
 if ForeverTrailCharacter then ForeverTrailCharacter.profile = savedProfile end
 FT.Print, s.locked = realPrint, realLocked
end)
try('görev penceresi: Rehber sekmesi küçülünce kırpılır ve kaydırılır', function()
 local dock, s = FT.questDock, ForeverTrailSettings
 assert(dock and FT.guideScroll and dock.guideScroll == FT.guideScroll and FT.guideScroll.ftDragThrough, 'Rehber içeriği kaydırma alanında olmalı ve sürüklemeyi iletmeli')
 assert(FT.guideScroll.barInset < 0, 'Rehber alanı tam genişlikte: kaydırma çubuğu pencerenin içinde kalmalı (dışına taşmamalı): ' .. tostring(FT.guideScroll.barInset))
 local plain = FT.Kit.Scroll(UIParent)
 assert(plain.barInset == 8 and plain.SetBarInset, 'kenar boşluklu listelerin çubuğu eskisi gibi dışarıda kalmalı')
 local saved = {tab = s.dockTab, h = s.dockH, w = s.dockW, c = s.dockCollapsed}
 local TAB_H = 36
 s.dockTab = 'guide'; s.dockCollapsed = nil; s.dockW = nil
 -- elle küçültülmüş: görünen alan pencerenin yüksekliğini aşmamalı (eskiden içerik pencerenin altından taşıyordu)
 for _, h in ipairs({420, 250, 150}) do
  s.dockH = h; FT.RefreshQuestDock()
  assert(dock.guideView == math.max(80, h - TAB_H - 6), 'elle yükseklik ' .. h .. ': görünen alan ' .. tostring(dock.guideView))
  assert(dock.totalH == h and FT.guideScroll:IsShown(), 'pencere yüksekliği elle ayarlanana eşit, alan görünür: ' .. tostring(dock.totalH))
  assert(dock.guideView + TAB_H + 6 <= h or dock.guideView == 80, 'içerik pencere sınırını aşmamalı')
 end
 -- çok küçük pencerede bile alan en az 80
 s.dockH = 100; FT.RefreshQuestDock(); assert(dock.guideView == 80, 'alt sınır 80: ' .. tostring(dock.guideView))
 -- otomatik yükseklik: içerik kadar ama ekranın %88'ini aşmaz
 s.dockH = nil; FT.RefreshQuestDock()
 local cap = math.floor(UIParent:GetHeight() / math.max(0.1, dock:GetScale()) * 0.88) - TAB_H - 6
 assert(dock.guideView and dock.guideView <= math.max(80, cap) and dock.totalH == TAB_H + dock.guideView + 6, 'otomatik yükseklik ekranla sınırlı: ' .. tostring(dock.guideView) .. ' <= ' .. cap)
 -- başka sekmede ya da daraltılmışken Rehber alanı görünmez
 s.dockTab = 'tracker'; FT.RefreshQuestDock()
 assert(not FT.guideScroll:IsShown() and dock.guideView == nil, 'başka sekmede Rehber alanı gizli olmalı')
 s.dockTab = 'guide'; s.dockCollapsed = true; FT.RefreshQuestDock()
 assert(not FT.guideScroll:IsShown() and dock.totalH == TAB_H, 'daraltılınca yalnızca sekme şeridi kalmalı: ' .. tostring(dock.totalH))
 s.dockTab, s.dockH, s.dockW, s.dockCollapsed = saved.tab, saved.h, saved.w, saved.c
 FT.RefreshQuestDock()
end)
try('oyunun kendi takipçisi ayarlardan açılıp kapanır', function()
 local s = ForeverTrailSettings
 local def
 for _, d in ipairs(FT.QuestiePageDefs.q_takip) do if d.key == 'blizzTracker' then def = d end end
 assert(def and def.type == 'check' and type(def.apply) == 'function' and def.label:find('Oyunun kendi'), 'Ayarlar > Görev kutuları sayfasında kutu olmalı')
 local frames = {}
 for _, name in ipairs({'ObjectiveTrackerFrame', 'QuestWatchFrame', 'WatchFrame'}) do frames[name] = CreateFrame('Frame', name, UIParent) end
 local realCombat = InCombatLockdown
 InCombatLockdown = function() return false end
 s.blizzTracker = nil
 assert(FT.ApplyBlizzTracker() == 3, 'hangi takipçi çerçeveleri varsa hepsi uygulanır')
 for name, f in pairs(frames) do assert(not f:IsShown(), name .. ' varsayılan olarak gizli olmalı') end
 -- oyun takipçiyi kendisi yeniden gösterirse (görev eklenince) kapalıyken hemen tekrar gizlenir
 for name, f in pairs(frames) do f:Show(); assert(not f:IsShown(), name .. ': oyunun yeniden göstermesi geri alınmalı') end
 -- ayar açılınca gösterilir
 s.blizzTracker = true; def.apply(true)
 for name, f in pairs(frames) do assert(f:IsShown(), name .. ' ayar açıkken görünmeli') end
 local one = frames.ObjectiveTrackerFrame; one:Hide(); one:Show(); assert(one:IsShown(), 'ayar açıkken oyunun gösterimi korunmalı')
 -- tekrar kapatınca gizlenir
 s.blizzTracker = false; def.apply(false)
 for name, fr in pairs(frames) do assert(not fr:IsShown(), name .. ' ayar kapanınca gizlenmeli') end
 -- savaşta çerçeveye dokunulmaz (korumalı eylem hatası olmasın), savaştan çıkınca uygulanır
 s.blizzTracker = true; InCombatLockdown = function() return true end
 for _, fr in pairs(frames) do fr:Hide() end
 FT.ApplyBlizzTracker(); for name, fr in pairs(frames) do assert(not fr:IsShown(), name .. ': savaşta dokunulmamalı') end
 InCombatLockdown = function() return false end
 FT.ApplyBlizzTracker(); for name, fr in pairs(frames) do assert(fr:IsShown(), name .. ': savaş bitince uygulanmalı') end
 s.blizzTracker = nil; FT.ApplyBlizzTracker()
 InCombatLockdown = realCombat
 for name in pairs(frames) do _G[name] = nil end
end)
try('görev penceresi: sekmelerden ve içerikten sürüklenir, kilit nedeni söylenir', function()
 local dock = FT.questDock
 assert(dock, 'görev penceresi')
 local function walk(f, fn) fn(f); for _, c in ipairs({f:GetChildren()}) do walk(c, fn) end end
 -- sekme adları (Rehber / Görevlerim / Alınabilir) sürüklemeyi pencereye iletmeli; tık yine sekmeyi seçer
 local tabs = {}
 walk(dock, function(f) if f.__kind == 'Button' and f.text and f.count and f.line then tabs[#tabs + 1] = f end end)
 assert(#tabs == 3, 'üç sekme düğmesi: ' .. #tabs)
 for _, t in ipairs(tabs) do assert(t.ftDragThrough and t.__scripts.OnDragStart and t.__scripts.OnClick, 'sekme sürüklemeyi iletmeli ve tıklanabilir kalmalı') end
 assert(FT.tracker.ftDragThrough and FT.availableBox.ftDragThrough, 'pencereye alınan kutular da sürüklemeyi iletmeli (altlarındaki boşluk pencereyi tutsun)')
 local realStart, realStop = dock.__scripts.OnDragStart, dock.__scripts.OnDragStop
 local calls = {}
 dock.__scripts.OnDragStart = function(w) calls.start = w end
 dock.__scripts.OnDragStop = function(w) calls.stop = w end
 tabs[1].__scripts.OnDragStart(tabs[1]); assert(calls.start == dock, 'sekmeden sürükleme pencereyi taşımaya başlamalı')
 tabs[1].__scripts.OnDragStop(tabs[1]); assert(calls.stop == dock, 'bırakınca pencere durmalı ve konumu kaydetmeli')
 dock.__scripts.OnDragStart, dock.__scripts.OnDragStop = realStart, realStop
 -- kilitliyken pencere taşınmaz AMA nedeni söylenir (sessiz "bozuk" görünmez); açılınca taşınır
 local moved, printed = 0, {}
 dock.StartMoving = function() moved = moved + 1 end
 local realPrint, realTime, realLocked = FT.Print, GetTime, ForeverTrailSettings.locked
 FT.Print = function(m) printed[#printed + 1] = m end
 local now = 5000; GetTime = function() return now end
 ForeverTrailSettings.locked = true
 dock.__scripts.OnDragStart(dock)
 assert(moved == 0, 'kilitliyken pencere taşınmamalı')
 assert(#printed == 1 and printed[1]:find('kilitli', 1, true) and printed[1]:find('/ftrail kilit', 1, true), 'kilit nedeni ve nasıl açılacağı söylenmeli: ' .. tostring(printed[1]))
 tabs[2].__scripts.OnDragStart(tabs[2]); assert(#printed == 1, 'ipucu 15 saniyede en çok bir kez (yazı yağmuru olmasın)')
 now = now + 16; tabs[2].__scripts.OnDragStart(tabs[2]); assert(#printed == 2 and moved == 0, 'süre geçince tekrar söylenir, sekmeden denense de taşınmaz')
 ForeverTrailSettings.locked = false
 dock.__scripts.OnDragStart(dock); assert(moved == 1, 'kilit açılınca taşınmalı')
 FT.Print, GetTime, ForeverTrailSettings.locked = realPrint, realTime, realLocked
 dock.StartMoving = nil
end)
try('hub: sürükleme her yerden pencereyi taşır', function()
 local hub, Kit = FT.hub, FT.Kit
 assert(hub and Kit.DragThrough and Kit.DragThroughTree and FT.HubDragScan, 'sürükleme iletme işlevleri')
 for _, page in ipairs({'rehber', 'gorevler', 'ansiklopedi', 'sinif', 'meslek', 'yerler', 'araclar', 'ayarlar'}) do FT.OpenHub(page) end
 FT.HubDragScan()
 local function walk(f, fn) fn(f); for _, c in ipairs({f:GetChildren()}) do walk(c, fn) end end
 -- hub'ın altındaki HER kaydırma alanı (fare tekeri = fareyi yakalar) sürüklemeyi iletmeli
 local scrolls, bad = 0, 0
 walk(hub, function(f)
  if f.__kind == 'ScrollFrame' then
   scrolls = scrolls + 1
   if not (f.ftDragThrough and f.__scripts.OnDragStart and f.__scripts.OnDragStop) then bad = bad + 1 end
  end
 end)
 assert(scrolls > 0 and bad == 0, 'her kaydırma alanı sürüklemeyi iletmeli: ' .. bad .. '/' .. scrolls)
 -- ileten çerçeve hub'ın kendi sürükleme işlevlerini çağırır (konum kaydı hub'da kalır)
 local calls = {}
 local realStart, realStop = hub.__scripts.OnDragStart, hub.__scripts.OnDragStop
 hub.__scripts.OnDragStart = function(w) calls.start = w end
 hub.__scripts.OnDragStop = function(w) calls.stop = w end
 local sf
 walk(hub, function(f) if not sf and f.__kind == 'ScrollFrame' then sf = f end end)
 sf.__scripts.OnDragStart(sf); assert(calls.start == hub, 'sürükleme başlayınca hub taşınmaya başlamalı')
 sf.__scripts.OnDragStop(sf); assert(calls.stop == hub and sf.ftDragWin == nil, 'bırakınca hub durmalı ve konumu kaydetmeli')
 -- sonradan oluşan satırlar (havuz) bir sonraki taramada kapsanır; küçük öğeler, kaydırıcı, yazı kutusu, boyut tutamağı dışarıda kalır
 local holder = CreateFrame('Frame', nil, hub)
 local row = CreateFrame('Button', nil, holder); row.GetWidth = function() return 300 end; row.GetHeight = function() return 30 end
 local tiny = CreateFrame('Button', nil, holder); tiny.GetWidth = function() return 28 end; tiny.GetHeight = function() return 28 end
 local slider, edit, check = CreateFrame('Slider', nil, holder), CreateFrame('EditBox', nil, holder), CreateFrame('CheckButton', nil, holder)
 local grip = CreateFrame('Button', nil, holder); grip.GetWidth = function() return 300 end; grip.GetHeight = function() return 30 end
 grip:SetScript('OnMouseDown', function() end)
 local late = CreateFrame('ScrollFrame', nil, holder)
 assert(FT.HubDragScan() >= 2, 'tarama yeni çerçeveleri bulmalı')
 assert(row.ftDragThrough and late.ftDragThrough, 'sonradan oluşan satır ve kaydırma alanı kapsanmalı')
 assert(not tiny.ftDragThrough, 'küçük düğme (kapat, simge) sürüklemeyi iletmemeli')
 assert(not slider.ftDragThrough and not edit.ftDragThrough and not check.ftDragThrough, 'kaydırıcı, yazı kutusu ve onay kutusu kendi fare işini yapar')
 assert(not grip.ftDragThrough, 'kendi fare işlevi olan (boyut tutamağı) dokunulmamalı')
 assert(FT.HubDragScan() == 0, 'ikinci tarama yeni bir şey bulmamalı (tekrar kurulmaz)')
 -- Kit.Scroll kuruluşta kendiliğinden iletir: yarın yazılacak her liste de pencereyi tutmayı engellemez
 local fresh = Kit.Scroll(holder)
 assert(fresh.ftDragThrough and fresh.__scripts.OnDragStart, 'Kit.Scroll sürüklemeyi kendiliğinden iletmeli')
 fresh.__scripts.OnDragStart(fresh); assert(calls.start == hub, 'yeni liste de hub\'ı taşır')
 -- taşınabilir bir pencerenin içinde olmayan kaydırma alanı hata vermez, bir şey de yapmaz
 local orphan = Kit.Scroll(CreateFrame('Frame', nil, UIParent))
 calls.start = nil
 assert(pcall(orphan.__scripts.OnDragStart, orphan) and calls.start == nil, 'taşınamaz pencerede sürükleme sessizce yok sayılmalı')
 hub.__scripts.OnDragStart, hub.__scripts.OnDragStop = realStart, realStop
end)
try('rehber: eksik ön koşul ve eşya uyarısı', function()
 local g = FT.guide
 local idx
 for i, st in ipairs(g.steps) do if st.questId then idx = i; break end end
 local qid = g.steps[idx].questId
 local savedView, savedActive, realReq, realTarget, realChoice = FT.view, FT.active, FT.QuestRequirements, FT.SetCustomTarget, FT.ShowChoice
 local fake = {
  {kind = 'quest', questId = 111, title = 'Önce bu', text = 'Önce görev: Önce bu', detail = 'Görevi al: Test NPC', place = {map = 1429, x = 0.3, y = 0.4, text = 'Elwynn Forest · 30, 40'}, where = 'Elwynn Forest · 30, 40', npc = 'Test NPC'},
  {kind = 'item', itemId = 900, name = 'Mühür', questId = 112, title = 'Mühür görevi', text = 'Eşya gerekli: Mühür', detail = '“Mühür görevi” görevinden gelir (ödül)'},
 }
 FT.view, FT.active = idx, idx
 -- gereksinim yokken blok görünmez
 FT.QuestRequirements = function() return {} end; FT.RefreshGuideTab()
 assert(#FT.GuideTabReqRows() == 0 and not FT.guideBox.reqHead:IsShown(), 'gereksinim yokken uyarı bloğu yok')
 local tip = FT.Kit.Tooltip()
 local card = FT.guideBox.card
 card.__scripts.OnEnter(card); local linesNone = tip:NumLines(); card.__scripts.OnLeave(card)
 -- gereksinim varken: kartta amber satırlar, tıklayınca bağlantılı görevin NPC'sine rota
 FT.QuestRequirements = function(id) return id == qid and fake or {} end; FT.RefreshGuideTab()
 local rows = FT.GuideTabReqRows()
 assert(#rows == 2 and FT.guideBox.reqHead:IsShown(), 'iki uyarı satırı ve başlık: ' .. #rows)
 assert(rows[1].text == 'Önce görev: Önce bu' and rows[1].detail:find('Test NPC', 1, true) and rows[1].detail:find('Elwynn Forest · 30, 40', 1, true), 'ilk satır metni: ' .. tostring(rows[1].detail))
 assert(rows[2].text == 'Eşya gerekli: Mühür', 'ikinci satır eşya')
 local target
 FT.SetCustomTarget = function(map, x, y, name) target = {map = map, x = x, y = y, name = name} end
 local btn
 for _, r in ipairs({FT.guideBox:GetChildren()}) do if r.req == fake[1] then btn = r end end
 assert(btn and btn.__scripts.OnClick, 'uyarı satırı tıklanabilir')
 btn.__scripts.OnClick(btn)
 assert(target and target.map == 1429 and target.x == 0.3 and target.name == 'Test NPC', 'tık: bağlantılı görevin NPC\'sine rota')
 FT.SetCustomTarget = realTarget
 -- hepsi hazırsa (eşya çantada, görev bitti) başlık "Hazır" der; biri eksikse "Dikkat" der
 fake[1].ready, fake[2].ready = true, true; FT.RefreshGuideTab()
 assert(FT.guideBox.reqHead.text:GetText():find('Hazır', 1, true), 'hepsi hazırken başlık Hazır demeli: ' .. tostring(FT.guideBox.reqHead.text:GetText()))
 fake[2].ready = nil; FT.RefreshGuideTab()
 assert(FT.guideBox.reqHead.text:GetText():find('Dikkat', 1, true), 'biri eksikken başlık Dikkat demeli')
 fake[1].ready = nil
 -- ayrıntılı ipucu da aynı uyarıları taşır (başlık + iki satır, her biri için ikişer satır)
 card.__scripts.OnEnter(card); local linesWith = tip:NumLines(); card.__scripts.OnLeave(card)
 assert(linesWith == linesNone + 4, 'ipucunda her gereksinim için iki satır eklenmeli: ' .. linesNone .. ' -> ' .. linesWith)
 -- yola çıkarken uyarı (bir kez), kapalıysa çıkmaz
 local popups = {}
 FT.ShowChoice = function(title, icon, text) popups[#popups + 1] = text; return true end
 ForeverTrailSettings.reqWarn = nil
 FT.view, FT.active = idx, idx
 FT.Refresh()
 FT.StepRequirementWarning()
 assert(#popups <= 1, 'yola çıkış uyarısı en fazla bir kez')
 FT.QuestRequirements, FT.ShowChoice = realReq, realChoice
 FT.view, FT.active = savedView, savedActive; FT.RefreshGuideTab()
end)
try('ayarlarda hedefler penceresi', function()
 -- Ayarlar > Görev kutuları sayfasında açma/kapama kutusu var ve pencereyi gerçekten açıp kapatıyor
 local def
 for _, d in ipairs(FT.QuestiePageDefs.q_takip) do if d.key == 'targetList' then def = d end end
 assert(def and def.type == 'check' and type(def.apply) == 'function' and def.label:find('Hedefler penceresi'), 'q_takip sayfasında hedefler penceresi kutusu')
 local real = FT.ActiveObjectives
 FT.ActiveObjectives = function() return {{questId = 999, title = 'Av', index = 1, kind = 'kill', npcs = {299}, objs = {}, have = 0, need = 2, done = false, color = {1, 0.8, 0.3}, text = 'Outraged Pillager: 0/2'}} end
 ForeverTrailSettings.targetList = nil; ForeverTrailSettings.targetListCollapsed = nil
 def.apply(true); FT.RefreshTargetList(true)
 assert(FT.targetList and FT.targetList:IsShown(), 'varsayılan açık: pencere görünmeli')
 ForeverTrailSettings.targetList = false; def.apply(false)
 assert(not FT.targetList:IsShown(), 'kutu kapatılınca pencere kapanmalı')
 ForeverTrailSettings.targetList = true; def.apply(true)
 assert(FT.targetList:IsShown(), 'kutu açılınca pencere geri gelmeli')
 -- pencerenin kendi kapat düğmesi ayarı kapatır; ayar sayfası aynı anahtarı okur
 FT.targetList.close:GetScript('OnClick')(FT.targetList.close)
 assert(ForeverTrailSettings.targetList == false and not FT.targetList:IsShown(), 'kapat düğmesi ayarı da kapatmalı')
 ForeverTrailSettings.targetList = nil; FT.RefreshTargetList(true)
 FT.ActiveObjectives = real
end)
try('ipucu yerleşimi', function()
 local P = FT.Kit.PlaceTip
 local W, H, SW, SH = 316, 200, 1920, 1080
 -- pencere solda: ipucu sağına açılır, satırın hizasında
 local x, top, side = P({l = 100, r = 460, t = 700, b = 100}, {l = 110, r = 450, t = 500, b = 470}, W, H, SW, SH, 'ANCHOR_LEFT')
 assert(side == 'right' and x == 468 and top == 500, 'sola sığmayınca sağa: ' .. tostring(side) .. ' ' .. tostring(x) .. ' ' .. tostring(top))
 -- pencere sağda: soldan istese de sığan taraf sol olur ve pencerenin dışında kalır
 x, top, side = P({l = 1500, r = 1860, t = 700, b = 100}, {l = 1510, r = 1850, t = 500, b = 470}, W, H, SW, SH, 'ANCHOR_RIGHT')
 assert(side == 'left' and x == 1500 - 8 - W and x + W <= 1500, 'sağa sığmayınca sola: ' .. tostring(side) .. ' ' .. tostring(x))
 x, top, side = P({l = 1500, r = 1860, t = 700, b = 100}, {l = 1510, r = 1850, t = 500, b = 470}, W, H, SW, SH, 'ANCHOR_LEFT')
 assert(side == 'left', 'sola sığıyorsa sol tercih edilir')
 -- iki yan da sığmıyor: geniş olan taraf, ekranın içinde
 x, top, side = P({l = 100, r = 500, t = 700, b = 100}, {l = 110, r = 490, t = 500, b = 470}, W, H, 640, SH, 'ANCHOR_LEFT')
 assert(x >= 4 and x + W <= 640 - 4, 'ekran dışına taşmamalı: ' .. tostring(x))
 -- dikeyde ekrana sığdır: satır ekranın dibindeyse ipucu yukarı kayar
 x, top = P({l = 100, r = 460, t = 700, b = 0}, {l = 110, r = 450, t = 90, b = 60}, W, H, SW, SH, 'ANCHOR_LEFT')
 assert(top - H >= 4, 'ipucu alttan taşmamalı: ' .. tostring(top))
 x, top = P({l = 100, r = 460, t = 1100, b = 0}, {l = 110, r = 450, t = 1090, b = 1060}, W, H, SW, SH, 'ANCHOR_LEFT')
 assert(top <= SH - 4, 'ipucu üstten taşmamalı: ' .. tostring(top))
 -- yatay şerit: altta durunca üstüne, en üstteyse altına açılır; simgenin üstünde ortalanır
 x, top, side = P({l = 10, r = 450, t = 60, b = 10}, {l = 200, r = 234, t = 54, b = 16}, W, H, SW, SH, 'ANCHOR_TOP')
 assert(side == 'top' and top == 60 + 8 + H and x == 217 - W / 2, 'şerit altta: ipucu üste, simgeye ortalı: ' .. tostring(side) .. ' ' .. tostring(top) .. ' ' .. tostring(x))
 x, top, side = P({l = 10, r = 450, t = 1070, b = 1020}, {l = 200, r = 234, t = 1064, b = 1026}, W, H, SW, SH, 'ANCHOR_TOP')
 assert(side == 'bottom' and top == 1020 - 8, 'şerit en üstte: ipucu alta: ' .. tostring(side) .. ' ' .. tostring(top))
 -- dikey şerit: ipucu yana
 x, top, side = P({l = 6, r = 58, t = 500, b = 60}, {l = 12, r = 52, t = 300, b = 266}, W, H, SW, SH, 'ANCHOR_RIGHT')
 assert(side == 'right' and x == 58 + 8, 'dikey şerit solda: ipucu sağa: ' .. tostring(side) .. ' ' .. tostring(x))
 -- gerçek ipucu: konum hesabı çalışırken hata vermemeli (benzetimde sol/sağ/üst/alt yoksa eski yerleşime düşer)
 local tip = FT.Kit.Tooltip(); tip:SetOwner(FT.questDock or UIParent, 'ANCHOR_LEFT'); tip:SetText('x', 1, 1, 1); tip:Show(); FT.Kit.HideTips()
end)
try('ipucu hayalet satır', function()
 local tip = FT.Kit.Tooltip()
 -- uzun bir ipucu, ardından kısa bir ipucu: ilkinin satırları kutuda ve dışında kalmamalı
 tip:SetOwner(UIParent, 'ANCHOR_LEFT'); tip:SetText('Uzun', 1, 1, 1)
 for i = 1, 8 do tip:AddLine('satır ' .. i, 1, 1, 1) end
 tip:AddRule(); tip:AddBar('çubuk', 1, 3, 0.5, 0.9, 0.5); tip:AddDoubleLine('sol', 'sağ', 1, 1, 1, 1, 1, 1)
 tip:AddMedia({npc = 1234, icons = {{texture = 'Interface\\Icons\\INV_Misc_Bag_08', count = 3}, {texture = 'Interface\\Icons\\INV_Misc_Bag_08'}}})
 tip:Show()
 local parts, tiles = tip:ShownParts()
 assert(parts >= 10 and tiles == 2, 'uzun ipucunda satırlar ve iki simge görünmeli: ' .. parts .. '/' .. tiles)
 tip:SetOwner(UIParent, 'ANCHOR_LEFT'); tip:SetText('Kısa', 1, 1, 1); tip:AddLine('tek satır', 1, 1, 1); tip:Show()
 parts, tiles = tip:ShownParts()
 assert(parts == 2, 'kısa ipucunda yalnızca kendi iki satırı görünmeli, eskiler gizlenmeli: ' .. parts)
 assert(tiles == 0, 'medya şeridi sonraki ipucuna taşmamalı: ' .. tiles)
 FT.Kit.HideTips()
end)
try('ikon şeridi', function()
 local dock = FT.dock
 assert(dock and dock.buttons and #dock.buttons == 11, 'şeritte 8 ana düğme + araçlar + kilit + yön düğmesi olmalı: ' .. tostring(dock and dock.buttons and #dock.buttons))
 for _, name in ipairs({'panel', 'map', 'nearest', 'places', 'silent', 'class', 'bag', 'settings', 'tools', 'lock', 'rotate'}) do
  local f = io.open('Media/dock_' .. name .. '.tga', 'rb'); assert(f, 'simge dosyası yok: dock_' .. name .. '.tga'); f:close()
 end
 for i, b in ipairs(dock.buttons) do
  assert(b.icon and b.mark and b.hover and b.Refresh, 'düğme ' .. i .. ' parçaları')
  assert(b.__scripts.OnClick and b.__scripts.OnEnter and b.__scripts.OnLeave, 'düğme ' .. i .. ' olayları')
 end
 local silent, lock, panel = dock.buttons[5], dock.buttons[10], dock.buttons[1]
 assert(not silent.mark:IsShown() and not FT.IsSilent(), 'başlangıçta sessiz kapalı')
 silent.__scripts.OnClick(silent); assert(FT.IsSilent() and silent.mark:IsShown(), 'sessiz açılınca düğme vurgulanmalı')
 silent.__scripts.OnClick(silent); assert(not FT.IsSilent() and not silent.mark:IsShown(), 'sessiz kapanınca vurgu kalkmalı')
 ForeverTrailSettings.locked = false
 lock.__scripts.OnClick(lock); assert(ForeverTrailSettings.locked and lock.mark:IsShown(), 'kilit vurgusu')
 lock.__scripts.OnClick(lock); assert(not ForeverTrailSettings.locked and not lock.mark:IsShown(), 'kilit açılınca vurgu kalkmalı')
 panel.__scripts.OnClick(panel)
 assert(panel.mark:IsShown() == (FT.hub and FT.hub:IsShown() and true or false), 'panel düğmesi pencere açıklığını izlemeli')
 panel.__scripts.OnClick(panel); FT.RefreshDock()
 assert(panel.mark:IsShown() == (FT.hub and FT.hub:IsShown() and true or false), 'panel düğmesi kapanışı izlemeli')
 -- yön: yatay <-> dikey (şeridin ucundaki küçük simge)
 do
  local items = {{size = 34}, {size = 34}, {divider = true}, {size = 28, pad = 2}}
  local offH, wH, hH = FT.DockMetrics(items, false)
  local offV, wV, hV = FT.DockMetrics(items, true)
  assert(wH == hV and hH == wV, 'dikeyde genişlik ve yükseklik yer değiştirmeli: ' .. wH .. 'x' .. hH .. ' / ' .. wV .. 'x' .. hV)
  assert(wH > hH and hV > wV, 'yatay şerit geniş, dikey şerit uzun olmalı')
  assert(offH[1] < offH[2] and offH[2] < offH[3] and offH[3] < offH[4], 'öğeler sırayla dizilmeli')
  for i = 1, #items do assert(offH[i] == offV[i], 'ana eksen konumları yöne bağlı olmamalı') end
  local rotate = dock.buttons[11]
  assert(rotate and not dock.vertical and ForeverTrailSettings.dockVertical ~= true, 'başlangıçta yatay')
  rotate.__scripts.OnClick(rotate)
  assert(dock.vertical == true and ForeverTrailSettings.dockVertical == true, 'tıklayınca dikey olmalı ve kaydedilmeli')
  rotate.__scripts.OnEnter(rotate); assert(FT.Kit.Tooltip().frame:IsShown(), 'dikeyde de ipucu çıkmalı'); rotate.__scripts.OnLeave(rotate)
  rotate.__scripts.OnClick(rotate)
  assert(dock.vertical == false and ForeverTrailSettings.dockVertical == false, 'tekrar tıklayınca yatay')
  ForeverTrailSettings.dockVertical = nil
 end
 FT.Kit.HideTips()
 panel.__scripts.OnEnter(panel); assert(panel.over and panel.hover:IsShown() and FT.Kit.Tooltip().frame:IsShown(), 'üzerine gelince zemin ve ipucu')
 panel.__scripts.OnLeave(panel); assert(not panel.over and not panel.hover:IsShown() and not FT.Kit.Tooltip().frame:IsShown(), 'ayrılınca ikisi de kapanmalı')
 FT.ApplyTheme('g_gece'); FT.ApplyTheme('g_orman'); FT.RefreshDock()
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
 do -- rehber seçici: liste dolu, bölge satırına tıklayınca otomatik rehber seçilir, global sızıntı yok
  assert(FT.ToggleGuidePicker(), 'seçici açılmalı')
  local rows0, heads0 = FT.GuidePickerInfo()
  assert(rows0 >= 5 and heads0 >= 2, 'seçici listesi dolu olmalı: ' .. rows0 .. '/' .. heads0)
  assert(rawget(_G, 'row_first') == nil, 'seçici global değişken sızdırmamalı')
  local picker = _G.ForeverTrailGuidePicker
  assert(picker and picker:IsShown(), 'seçici penceresi görünür olmalı')
  local row
  for i = 1, rows0 do
   local r = FT.GuidePickerRow(i)
   if r:IsShown() and tostring(r.title:GetText() or ''):find('%d+%-%d+$') then row = r; break end
  end
  assert(row, 'listede bölge satırı olmalı')
  row:GetScript('OnClick')(row)
  assert(FT.guide and FT.guide.auto, 'bölge satırı otomatik rehberi seçmeli')
  assert(not picker:IsShown(), 'seçimden sonra pencere kapanmalı')
  assert(ForeverTrailCharacter.autoGuide, 'seçim karakter kaydına yazılmalı')
  FT.ToggleGuidePicker(); assert(picker:IsShown(), 'ikinci açılış'); FT.ToggleGuidePicker()
 end
 do -- Yerler: sekmeler, kaydırılabilir iki satırlı liste, satıra tıklayınca hedef
  FT.AddPlace('Deneme Hancısı', 'Han', 1429, 0.4, 0.5, true); FT.AddPlace('Deneme Bankası', 'Banka', 1429, 0.5, 0.5, true)
  FT.OpenHub('yerler')
  local pw = FT.placesWindow
  assert(pw and pw:IsShown(), 'yerler penceresi açılmalı')
  FT.PlacesCategory('services')
  local shown = FT.PlacesRows()
  assert(#shown >= 2, 'hizmet satırları görünmeli: ' .. #shown)
  assert(not pw.empty:IsShown(), 'satır varken boş açıklaması gizli olmalı')
  local names = {}
  for _, b in ipairs(shown) do names[#names + 1] = tostring(b.left:GetText()) end
  assert(table.concat(names, '|'):find('Deneme Hancısı'), 'kayıtlı yer listede olmalı: ' .. table.concat(names, '|'))
  FT.customTarget = nil
  local first = shown[1]
  first:GetScript('OnClick')(first)
  assert(FT.customTarget and FT.customTarget.text == first.row.name, 'satıra tıklayınca yer hedef olmalı')
  -- aynı bölgedeki hedefe: mini haritada sarı rota çizgisi ve akan noktalar
  FT.SetCustomTarget(1429, 0.52, 0.5, 'Rota Testi', true)
  FT.UpdateArrow(); FT.UpdateMinimapPin()
  local route = FT.MinimapRouteInfo()
  assert(route.core and route.core:IsShown() and route.glow:IsShown(), 'mini haritada rota çizgisi görünmeli')
  assert(#route.dots >= 1 and route.dots[1]:IsShown(), 'rota üzerinde akan noktalar görünmeli')
  -- yol verisi varsa rota kıvrımlıdır: çok parçalı çizgi
  local realRoute = FT.CurrentRoute
  FT.CurrentRoute = function(map, px, py, gx, gy) return {{px, py}, {px + 0.01, py + 0.002}, {px + 0.012, py + 0.01}, {gx, gy}} end
  FT.UpdateMinimapPin()
  assert(FT.MinimapRouteInfo().segments >= 2, 'kıvrımlı rota birden çok parçadan oluşmalı: ' .. tostring(FT.MinimapRouteInfo().segments))
  FT.CurrentRoute = realRoute
  FT.UpdateMinimapPin()
  assert(FT.MinimapRouteInfo().segments == 1, 'yol verisi yokken düz çizgi (tek parça) olmalı: ' .. tostring(FT.MinimapRouteInfo().segments))
  ForeverTrailSettings.minimapRoute = false; FT.UpdateMinimapPin()
  assert(not route.core:IsShown() and not route.dots[1]:IsShown(), 'minimapRoute=false rotayı gizlemeli')
  ForeverTrailSettings.minimapRoute = nil
  -- başka bölgedeki yer: sohbete yazılmaz, yolculuk kartı simgeli adımlarla açılır
  do
   local printed, realPrint = {}, FT.Print
   FT.Print = function(m) printed[#printed + 1] = tostring(m) end
   FT.PlacesGo({name = 'Uzak Han', cat = 'Han', map = 1426, x = 0.3, y = 0.3})
   FT.Print = realPrint
   assert(#printed == 0, 'yerler seçimi sohbete yazmamalı: ' .. table.concat(printed, ' / '))
   assert(FT.customTarget and FT.customTarget.text == 'Uzak Han', 'hedef seçilmeli')
   local card = FT.routeCard
   assert(card and card:IsShown(), 'başka bölge hedefinde yolculuk kartı açılmalı')
   local rows = FT.RouteCardRows()
   assert(#rows >= 1, 'kartta adım olmalı')
   assert(rows[#rows].icon:GetTexture():find('route_flag'), 'son adım varış simgesi olmalı: ' .. tostring(rows[#rows].icon:GetTexture()))
   assert(card.title:GetText() == 'Uzak Han', 'kart hedef adını göstermeli')
   -- animasyon: açılışta saydam başlar, süre dolunca tam görünür
   card:GetScript('OnUpdate')(card, 0.05)
   assert(card:GetAlpha() < 1, 'açılışta kart yarı saydam başlamalı: ' .. card:GetAlpha())
   card:GetScript('OnUpdate')(card, 0.5)
   assert(card:GetAlpha() == 1, 'açılış animasyonu tamamlanmalı')
   -- aynı bölgeye gelince kart kapanır
   local realMap = C_Map.GetBestMapForUnit
   C_Map.GetBestMapForUnit = function() return 1426 end
   FT.RefreshRouteCard()
   assert(not card:IsShown(), 'hedefin bölgesine gelince kart kapanmalı')
   C_Map.GetBestMapForUnit = realMap
   FT.RefreshRouteCard(true); assert(card:IsShown(), 'başka bölgede yeniden açılmalı')
   -- kapat düğmesi bu hedef için kartı gizler, yeni hedefte yeniden açılır
   card.close:GetScript('OnClick')(card.close)
   assert(not card:IsShown(), 'kapat düğmesi kartı gizlemeli')
   FT.SetCustomTarget(1426, 0.5, 0.5, 'Başka Han', true)
   assert(card:IsShown(), 'yeni hedefte kart yeniden açılmalı')
   FT.customTarget = nil; FT.RefreshRouteCard()
   assert(not card:IsShown(), 'hedef yokken kart gizli olmalı')
  end
  FT.PlacesCategory('mine')
  assert(#FT.PlacesRows() == 0 and pw.empty:IsShown() and pw.empty:GetText() ~= '', 'boş sekmede açıklama görünmeli')
  FT.PlacesCategory('flight'); FT.OpenHub('rehber')
 end
 do -- Görevler sayfası: sekmeler ve iki satırlı liste
  FT.OpenHub('gorevler')
  assert(FT.suggestions and FT.suggestions:IsShown(), 'görevler sayfası açılmalı')
  local counts = {}
  for _, tab in ipairs({'journal', 'available', 'nearby', 'chain'}) do FT.SuggestionTab(tab); counts[tab] = #FT.SuggestionRows() end
  FT.SuggestionTab('journal')
  local rows = FT.SuggestionRows()
  assert(#rows >= 1, 'günlükte görev olan karakterde günlük sekmesi dolu olmalı: ' .. table.concat({counts.journal, counts.available, counts.nearby, counts.chain}, '/'))
  local r = rows[1]
  assert(r.title:GetText():find('^%[') and r.sub:GetText() ~= '' and r.state:GetText() ~= '', 'satır başlığı, alt satırı ve durumu dolu olmalı')
  r:GetScript('OnEnter')(r); r:GetScript('OnLeave')(r)
  FT.guide = nil
  r:GetScript('OnClick')(r)
  assert(FT.guide, 'satıra tıklayınca bir rehber seçilmeli')
  -- sabit öneri verisiyle sekme süzgeçleri ve tıklama davranışı
  local realRec, realNear = FT.GetRecommendations, FT.GetNearbyRecommendations
  FT.GetRecommendations = function() return {{id = 2, title = 'Yeni', level = 10, xp = 200}, {id = 1, title = 'Aktif', level = 10, xp = 100, active = true}}, true end
  FT.GetNearbyRecommendations = function(all) return all, true end
  local function titles() local t = {}; for _, b in ipairs(FT.SuggestionRows()) do t[#t + 1] = b.row.title end; return table.concat(t, ',') end
  FT.SuggestionTab('journal'); assert(titles() == 'Aktif', 'günlük sekmesi yalnızca aktifleri göstermeli: ' .. titles())
  FT.SuggestionTab('available'); assert(titles() == 'Yeni', 'alınabilir sekmesi yalnızca yenileri göstermeli: ' .. titles())
  local nb = FT.SuggestionRows()[1]
  FT.guide = nil; nb:GetScript('OnClick')(nb)
  assert(FT.guide and FT.guide.steps[1].type == 'accept' and FT.guide.steps[1].questId == 2, 'alınabilir görev seçilince "görevi al" adımı oluşmalı')
  FT.SuggestionTab('nearby'); assert(#FT.SuggestionRows() == 2, 'bölge sekmesi ikisini de göstermeli')
  FT.GetRecommendations, FT.GetNearbyRecommendations = realRec, realNear
  FT.SuggestionTab('journal')
  FT.OpenHub('rehber')
 end
 FT.RefreshJourney(); ForeverTrailSettings.journeyOpen = false; FT.RefreshJourney(); ForeverTrailSettings.journeyOpen = nil; FT.RefreshJourney()
 FT.OpenHub('rehber'); assert(FT.hub.rail and FT.hub.pageTitle:GetText() == 'Rehber', 'hub başlığı')
 for _, page in ipairs({'rehber', 'gorevler', 'yerler'}) do
  FT.OpenHub(page)
  local w = ({rehber = FT.panel, gorevler = FT.suggestions, yerler = FT.placesWindow})[page]
  assert(w and not w:IsMouseEnabled(), 'Hub sayfası fareyi yutmamalı (pencere sürüklenebilsin): ' .. page)
 end
 FT.OpenHub('rehber')
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
