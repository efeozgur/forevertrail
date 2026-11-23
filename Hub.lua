local _, FT = ...

-- Tek ana pencere: solda menü (Rehber, Görevler, Yerler, Araçlar, Ayarlar), sağda içerik.
-- Var olan pencereler bu pencerenin içine taşınır; ekranda yalnızca yön oku, görev kutusu ve ikon şeridi kalır.

local hub, holders, nav, current = nil, {}, {}, nil
local WIDTH, HEIGHT, SIDE = 590, 700, 128

local PAGES = {
 {key='rehber', label='Rehber', icon='Interface\\Icons\\INV_Misc_Book_09', flat='tracker_quests'},
 {key='gorevler', label='Görevler', icon='Interface\\Icons\\INV_Misc_Note_01', flat='tracker_giver'},
 {key='ansiklopedi', label='Ansiklopedi', icon='Interface\\Icons\\INV_Misc_Book_11', flat='tracker_database'},
 {key='sinif', label='Sınıf', icon='Interface\\Icons\\INV_Misc_Book_09', flat='startend'},
 {key='meslek', label='Meslekler', icon='Interface\\Icons\\Trade_Engineering', flat='tracker_clean'},
 {key='yerler', label='Yerler', icon='Interface\\Icons\\Ability_Mount_Gryphon_01', flat='fav'},
 {key='araclar', label='Araçlar', icon='Interface\\Icons\\Trade_Engineering', flat='tracker_search'},
 {key='ayarlar', label='Ayarlar', icon='Interface\\Icons\\INV_Misc_Gear_01', flat='tracker_settings'},
}

local function font(fs, size, flags)
 local path = FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF'
 if fs:SetFont(path, size, flags or '') == false then fs:SetFont('Fonts\\ARIALN.TTF', size, flags or '') end
 fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.85)
end

-- Bir pencereyi sayfanın içine al: kendi çerçevesini, başlığını, kapatma düğmesini gizle, taşınmasını kapat
local adopted = {}
local function adopt(frame, page, x, y)
 if not frame or adopted[frame] == page then return end
 adopted[frame] = page
 frame:SetParent(holders[page])
 frame:ClearAllPoints()
 frame:SetPoint('TOPLEFT', holders[page], 'TOPLEFT', x or 0, y or 0)
 frame:SetFrameStrata(hub:GetFrameStrata())
 frame:SetFrameLevel(holders[page]:GetFrameLevel() + 2)
 if frame.close then frame.close:Hide() end
 if frame.softBg then frame.softBg:Hide() end
 if frame.title then frame.title:Hide() end
 frame:SetMovable(false)
 frame:SetScript('OnDragStart', nil)
 frame:SetScript('OnDragStop', nil)
end

local function refreshNav()
 local a = FT.Style.accent
 for _, b in ipairs(nav) do
  local on = b.key == current
  b.bar:SetShown(on)
  b.bar:SetColorTexture(a[1], a[2], a[3], 1)
  if b.flat then if on then b.icon:SetVertexColor(a[1], a[2], a[3]) else b.icon:SetVertexColor(0.8, 0.78, 0.72) end end
  b.bg:SetColorTexture(1, 1, 1, on and 0.08 or 0)
  if on then b.text:SetTextColor(a[1], a[2], a[3]) else b.text:SetTextColor(0.85, 0.82, 0.76) end
  b.icon:SetDesaturated(not on)
 end
end

FT.RefreshHub = function() if hub then refreshNav() end end

local function fill(page)
 if page == 'rehber' and FT.panel then
  adopt(FT.panel, 'rehber', 0, 0)
  FT.panel:Show()
  if FT.card then FT.card:ClearAllPoints(); FT.card:SetPoint('TOPLEFT', hub, 'TOPRIGHT', 4, 0) end
 elseif page == 'gorevler' and FT.suggestions then
  adopt(FT.suggestions, 'gorevler', 0, 0)
  if FT.ShowSuggestions then FT.ShowSuggestions() else FT.suggestions:Show() end
 elseif page == 'yerler' and FT.EnsurePlacesWindow then
  local w = FT.EnsurePlacesWindow()
  adopt(w, 'yerler', 0, 0); w:Show()
 elseif page == 'ayarlar' and FT.settings then
  adopt(FT.settings, 'ayarlar', 0, 0); FT.settings:Show()
 elseif page == 'araclar' and FT.infoWindow then
  adopt(FT.infoWindow, 'araclar', 0, -hub.toolsHeight)
 end
end

local opening = false
function FT.OpenHub(page)
 if FT.QuestonActive and (page == 'araclar' or page == 'ayarlar') and FT.OpenQuestonSettings then if hub then hub:Hide() end if FT.OpenQuestonSettings(page == 'araclar' and 'ft_araclar' or 'ft_rehber') then return end end
 if page == 'ayarlar' and FT.QuestieOptionsOn and FT.QuestieOptionsOn() and FT.OpenQuestieOptions then if hub then hub:Hide() end return FT.OpenQuestieOptions() end
 if opening then return end
 opening = true
 local ok, err = pcall(function()
 if not hub then FT.CreateHub() end
 page = page or current or 'rehber'
 current = page
 for key, h in pairs(holders) do if key == page then h:Show() else h:Hide() end end
 local label = page
 for _, p in ipairs(PAGES) do if p.key == page then label = p.label end end
 hub.pageTitle:SetText(label)
 hub:SetWidth(page == 'ayarlar' and WIDTH + 170 or WIDTH)
 fill(page)
 hub:Show()
 refreshNav()
 end)
 opening = false
 if not ok then error(err, 0) end
end

function FT.ToggleHub(page)
 if hub and hub:IsShown() and (not page or page == current) then hub:Hide() else FT.OpenHub(page) end
end

-- Araçlar: rehber merkezi ve ayar penceresi aynı listeyi kullanır.
-- dup = Queston Forever açıkken onun yaptığı iş (orada listelenmez).
function FT.ToolDefs()
 local list = {
  {title = 'Ekranda göster / gizle', list = {
   {'Hedef kartı', function() FT.ToggleCard() end, dup = true},
   {'Görev kutusu', function() FT.ToggleTracker() end, dup = true},
   {'Yön oku', function() FT.ToggleArrow() end},
   {'İkon şeridi', function() FT.ToggleDock() end},
   {'Kilit aç/kapat', function() FT.ToggleLock() end},
   {'Konumları sıfırla', function() FT.ResetLayout() end},
   {'Düzen modu', function() FT.ToggleEditMode() end},
   {'Sessiz mod', function() FT.ToggleSilent() end},
  }},
  {title = 'Görev ve yol', list = {
   {'Görev yardımcısı', function() FT.ShowQuestHelper() end},
   {'Sıradaki görev', function() FT.SuggestNext() end},
   {'En yakın adım', function() FT.SelectNearest() end},
   {'Sürekli rota', function() FT.ToggleAutoRoute() end},
   {'Yol sor', function() FT.OpenAskRoute() end},
   {'Rota planı', function() FT.ShowRoutePlan() end, dup = true},
   {'Rota oluştur', function() FT.BuildRoute() end, dup = true},
   {'Görev geçmişi', function() FT.ShowJourney() end, dup = true},
   {'Kaçırılan görevler', function() FT.ShowMissedQuests() end},
   {'Günlük temizliği', function() FT.ShowLogCleanup() end},
   {'Gruba paylaş', function() FT.ShareStep() end, dup = true},
   {'Oturum özeti', function() FT.ShowSessionCard() end},
  }},
  {title = 'Sınıf, meslek ve ekipman', list = {
   {'Yetenek planı', function() FT.OpenHub('sinif') end},
   {'Sınıf eğitmeni', function() local t = FT.ClassTrainer() if t then FT.SetCustomTarget(t.map, t.x, t.y, t.name) else FT.Print('Sınıf eğitmeni bulunamadı.') end end},
   {'Meslek rehberi', function() FT.ShowProfessionGuide() end},
   {'Silah ustaları', function() FT.ShowWeaponMasters() end},
   {'Ekipman bulucu', function() FT.ShowGearFinder() end, dup = true},
   {'Daha iyi eşya ara', function() FT.ScanUpgrades() end, dup = true},
   {'Zindan rehberi', function() FT.ShowDungeonGuide() end, dup = true},
   {'Zindan görevleri', function() FT.ShowDungeonQuests() end, dup = true},
  }},
  {title = 'Ayarlar ve veri', list = {
   {'Profiller', function() FT.ToggleProfiles() end},
   {'Ayarları aktar', function() FT.ToggleTransfer() end},
   {'Ayar yedekleri', function() FT.ShowBackups() end},
   {'Şimdi yedekle', function() FT.BackupNow() end},
   {'Kurulum sihirbazı', function() FT.ShowSetupWizard() end, dup = true},
   {'Uyumluluk testi', function() FT.SelfTest() end},
   {'Hata kaydı', function() FT.PrintErrors() end},
   {'Görev verisi', function() FT.ToggleDataWindow() end},
   {'Rehber kaydı', function() FT.ToggleRecorder() end},
  }},
 }
 if FT.QuestonActive then
  for _, sec in ipairs(list) do
   local kept = {}
   for _, d in ipairs(sec.list) do if not d.dup then kept[#kept + 1] = d end end
   sec.list = kept
  end
 end
 return list
end

local function toolsPage(holder)
 local y = 0
 local function heading(text)
  local fs = holder:CreateFontString(nil, 'OVERLAY'); font(fs, 13, 'OUTLINE')
  fs:SetPoint('TOPLEFT', 2, y); fs:SetText(text)
  fs:SetTextColor(FT.Style.accent[1], FT.Style.accent[2], FT.Style.accent[3])
  y = y - 20
 end
 local function grid(list)
  local cols, w = 4, 106
  for i, def in ipairs(list) do
   local b = FT.NewButton(holder, def[1], w, 24)
   b:SetPoint('TOPLEFT', ((i - 1) % cols) * (w + 4), y - math.floor((i - 1) / cols) * 28)
   b:SetScript('OnClick', function()
    local ok, err = pcall(def[2])
    if not ok then FT.Print('Hata: ' .. tostring(err)) end
   end)
  end
  y = y - math.ceil(#list / cols) * 28 - 8
 end
 for _, sec in ipairs(FT.ToolDefs()) do
  heading(sec.title)
  grid(sec.list)
 end
 hub.toolsHeight = -y + 4
 local hint = holder:CreateFontString(nil, 'OVERLAY'); font(hint, 11)
 hint:SetPoint('TOPLEFT', 2, y); hint:SetTextColor(0.6, 0.58, 0.54)
 hint:SetText('Özet, meslek, yetenek, temizlik ve zindan sonuçları burada, aşağıda görünür.')
end

function FT.CreateHub()
 if hub then return hub end
 hub = FT.NewWindow('ForeverTrailHub', UIParent)
 FT.hub = hub
 if FT.AddShowAnim then FT.AddShowAnim(hub) end
 hub:SetSize(WIDTH, HEIGHT)
 hub:SetFrameStrata('HIGH')
 hub:SetClampedToScreen(true)
 hub:SetMovable(true); hub:EnableMouse(true); hub:RegisterForDrag('LeftButton')
 hub:SetScript('OnDragStart', function(self) self:StartMoving() end)
 hub:SetScript('OnDragStop', function(self)
  self:StopMovingOrSizing()
  local point, _, relative, x, y = self:GetPoint()
  ForeverTrailSettings.hubPoint = {point, relative, x, y}
 end)
 local p = ForeverTrailSettings.hubPoint
 if p and p[1] then hub:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else hub:SetPoint('CENTER', UIParent, 'CENTER', 60, 40) end
 tinsert(UISpecialFrames, 'ForeverTrailHub')

 local title = hub:CreateFontString(nil, 'OVERLAY'); font(title, 14, 'OUTLINE')
 title:SetPoint('TOPLEFT', 14, -8); title:SetText('ForeverTrail')
 if FT.StyleTitle then FT.StyleTitle(title) end
 hub.pageTitle = hub:CreateFontString(nil, 'OVERLAY'); font(hub.pageTitle, 13)
 hub.pageTitle:SetPoint('TOPLEFT', SIDE + 12, -9); hub.pageTitle:SetTextColor(0.9, 0.86, 0.78)

 -- Sol menü
 local side = hub:CreateTexture(nil, 'BACKGROUND', nil, 1)
 side:SetPoint('TOPLEFT', 5, -30); side:SetPoint('BOTTOMLEFT', 5, 5); side:SetWidth(SIDE - 8)
 side:SetColorTexture(0, 0, 0, 0.25)
 for i, pdef in ipairs(PAGES) do
  local b = CreateFrame('Button', nil, hub)
  b:SetSize(SIDE - 8, 34); b:SetPoint('TOPLEFT', 5, -34 - (i - 1) * 36)
  b.key = pdef.key
  b.bg = b:CreateTexture(nil, 'BACKGROUND', nil, 2); b.bg:SetAllPoints()
  b.bar = b:CreateTexture(nil, 'ARTWORK'); b.bar:SetPoint('TOPLEFT'); b.bar:SetPoint('BOTTOMLEFT'); b.bar:SetWidth(3)
  b.icon = b:CreateTexture(nil, 'ARTWORK'); b.icon:SetSize(22, 22); b.icon:SetPoint('LEFT', 10, 0)
  b.flat = pdef.flat
  if pdef.flat then b.icon:SetTexture('Interface\\AddOns\\ForeverTrail\\Media\\' .. pdef.flat); b.icon:SetSize(18, 18)
  else b.icon:SetTexture(pdef.icon); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  b.text = b:CreateFontString(nil, 'OVERLAY'); font(b.text, 13)
  b.text:SetPoint('LEFT', b.icon, 'RIGHT', 8, 0); b.text:SetText(pdef.label)
  b:SetHighlightTexture('Interface\\Buttons\\WHITE8X8'); b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.05)
  b:SetScript('OnClick', function() FT.OpenHub(pdef.key) end)
  nav[i] = b
  local holder = CreateFrame('Frame', nil, hub)
  holder:SetPoint('TOPLEFT', SIDE + 8, -34); holder:SetPoint('BOTTOMRIGHT', -8, 8)
  holder:Hide()
  holders[pdef.key] = holder
 end
 local version = hub:CreateFontString(nil, 'OVERLAY'); font(version, 10)
 version:SetPoint('BOTTOMLEFT', 12, 12); version:SetTextColor(0.5, 0.48, 0.45)
 local q = FT.DBStats and FT.DBStats() or 0
 version:SetText(('Görev verisi: %d görev'):format(q))
 toolsPage(holders.araclar)
 if FT.BuildEncyclopedia then FT.BuildEncyclopedia(holders.ansiklopedi) end
 if FT.BuildClassPage then FT.BuildClassPage(holders.sinif) end
 if FT.BuildProfessionPage then FT.BuildProfessionPage(holders.meslek) end
 hub:Hide()
 return hub
end

-- Eski aç/kapat çağrılarını ana pencereye yönlendir
local function install()
 FT.CreateHub()
 FT.ToggleSettings = function() FT.ToggleHub('ayarlar') end
 FT.TogglePlaces = function() FT.ToggleHub('yerler') end
 local info = FT.InfoWindow
 FT.InfoWindow = function(title, lines)
  info(title, lines)
  if FT.infoWindow then FT.OpenHub('araclar') end
 end
 -- Panel kendi başına açılırsa (eski kod yolu) ana pencereyi aç
 if FT.panel then
  FT.panel:HookScript('OnShow', function() if hub and not hub:IsShown() then FT.OpenHub('rehber') end end)
  FT.panel:Hide()
 end
 if FT.ApplyFont then pcall(FT.ApplyFont) end
end

local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent', function()
 if C_Timer and C_Timer.After then C_Timer.After(0.5, function() local ok, err = pcall(install); if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'hub: ' .. tostring(err) end end)
 else pcall(install) end
end)
