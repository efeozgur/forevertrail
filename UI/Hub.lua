local _, FT = ...

-- Tek ana pencere: solda menü (Rehber, Görevler, Yerler, Araçlar, Ayarlar), sağda içerik.
-- Var olan pencereler bu pencerenin içine taşınır; ekranda yalnızca yön oku, görev kutusu ve ikon şeridi kalır.

local hub, holders, nav, current = nil, {}, {}, nil
local WIDTH, HEIGHT, SIDE, HEADER = 554, 730, 84, 58

-- bottom = sol şeridin altında durur (Polestar'daki İçe aktar / Seçenekler gibi)
local PAGES = {
 {key='rehber', label='Rehber', icon='tracker_quests', desc='Şimdi ne yapman gerektiğini ve nereye gideceğini gösterir.'},
 {key='gorevler', label='Görevler', icon='tracker_giver', desc='Bulunduğun yerde alabileceğin ve önerilen görevler.'},
 {key='ansiklopedi', label='Ansiklopedi', icon='tracker_database', desc='Bütün görevlerde ara; durumunu ve yolunu gör.'},
 {key='sinif', label='Sınıf', icon='startend', desc='Yetenek planı, seviye kartı ve sınıf görevleri.'},
 {key='meslek', label='Meslekler', icon='tracker_clean', desc='Meslek önerileri, rütbeler ve eğitmenler.'},
 {key='yerler', label='Yerler', icon='fav', desc='Uçuş noktaları, hizmetler ve kayıtlı yerler.'},
 {key='araclar', label='Araçlar', icon='tracker_search', desc='Rota, çanta, sınıf ve veri araçları.', bottom=true},
 {key='ayarlar', label='Ayarlar', icon='tracker_settings', desc='Tüm ayarlar; üstte arama kutusu var.', bottom=true},
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
 if FT.Kit then FT.Kit.Unchrome(frame) end
 if frame.title then frame.title:Hide() end
 frame:SetMovable(false)
 frame:SetScript('OnDragStart', nil)
 frame:SetScript('OnDragStop', nil)
end

local function refreshNav()
 for _, b in ipairs(nav) do b:SetSelected(b.key == current) end
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
 if opening then return end
 opening = true
 local ok, err = pcall(function()
 if not hub then FT.CreateHub() end
 page = page or current or 'rehber'
 current = page
 for key, h in pairs(holders) do if key == page then h:Show() else h:Hide() end end
 local label, desc = page, ''
 for _, p in ipairs(PAGES) do if p.key == page then label, desc = p.label, p.desc or '' end end
 hub.pageTitle:SetText(label)
 hub.pageDesc:SetText(desc)
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
 local Kit = FT.Kit
 hub = CreateFrame('Frame', 'ForeverTrailHub', UIParent)
 Kit.Skin(hub, 'mid', 'line')
 FT.fontRoots[#FT.fontRoots + 1] = hub
 hub:HookScript('OnShow', function(self) if FT.FixFonts then FT.FixFonts(self) end end)
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

 -- Sol şerit
 local rail = Kit.Frame(hub, 'rail')
 rail:SetPoint('TOPLEFT', 1, -1); rail:SetPoint('BOTTOMLEFT', 1, 1); rail:SetWidth(SIDE)
 local railLine = Kit.Divider(rail)
 railLine:SetWidth(1)
 railLine:SetPoint('TOPRIGHT', rail, 'TOPRIGHT', 0, 0); railLine:SetPoint('BOTTOMRIGHT', rail, 'BOTTOMRIGHT', 0, 0)
 local brand = Kit.Text(rail, 11, 'accent', 'OUTLINE'); brand:SetPoint('TOP', 0, -12); brand:SetText('ForeverTrail')
 hub.rail = rail

 -- Üst başlık: sayfa adı ve ne işe yaradığı
 local header = Kit.Frame(hub, 'panel')
 header:SetPoint('TOPLEFT', SIDE + 1, -1); header:SetPoint('TOPRIGHT', -1, -1); header:SetHeight(HEADER)
 local headLine = Kit.Divider(header); headLine:SetPoint('BOTTOMLEFT', 0, 0); headLine:SetPoint('BOTTOMRIGHT', 0, 0)
 hub.pageTitle = Kit.Text(header, 20, 'text'); hub.pageTitle:SetPoint('TOPLEFT', 16, -9)
 hub.pageDesc = Kit.Text(header, 11, 'muted'); hub.pageDesc:SetPoint('BOTTOMLEFT', 16, 9)
 hub.close = Kit.CloseButton(header, function() hub:Hide() end); hub.close:SetPoint('TOPRIGHT', -6, -6)

 -- Düğmeler: üst grup yukarıdan, alt grup aşağıdan dizilir
 local top, bottom = 0, 0
 for i, pdef in ipairs(PAGES) do
  local b = Kit.RailButton(rail, pdef, function() FT.OpenHub(pdef.key) end)
  if pdef.bottom then
   b:SetPoint('BOTTOMLEFT', rail, 'BOTTOMLEFT', 0, 20 + bottom * 58); bottom = bottom + 1
  else
   b:SetPoint('TOPLEFT', rail, 'TOPLEFT', 0, -36 - top * 58); top = top + 1
  end
  nav[i] = b
  local holder = CreateFrame('Frame', nil, hub)
  holder:SetPoint('TOPLEFT', SIDE + 10, -(HEADER + 10)); holder:SetPoint('BOTTOMRIGHT', -10, 10)
  holder:Hide()
  holders[pdef.key] = holder
 end
 local version = Kit.Text(rail, 9, 'muted'); version:SetPoint('BOTTOM', 0, 6)
 local v = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata('ForeverTrail', 'Version')
 version:SetText(v and ('v' .. v) or '')
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
