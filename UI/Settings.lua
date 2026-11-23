local _, FT = ...
local frame
local function newWindow(name, parent)
 if FT.NewWindow then return FT.NewWindow(name, parent) end
 return CreateFrame('Frame', name, parent, 'BasicFrameTemplateWithInset')
end
local turkishFont = 'Interface\\AddOns\\WoWTR\\Assets\\Fonts\\frizquadrata_tr.ttf'

local function applyFont(label)
 if not label then return end
 local path, size, flags = label:GetFont()
 if size and label:SetFont(turkishFont, size, flags or '') == false and path then label:SetFont(path, size, flags or '') end
end

local OFF_BY_DEFAULT = {hideContinent=true, qRaid=true, qareas=true, raidmarks=true, beep=true, autotalent=true, autoequip=true, trkAutoMin=true, trkCombat=true, trkInstance=true, autosummon=true, autorez=true, blockduels=true, maxcamera=true, noglow=true, autonext=true, auto=true, compact=true, banksort=true, autoreward=true, simple=true, announce=true, breadcrumbs=true, availHideLow=true}
local function get(key)
 if OFF_BY_DEFAULT[key] then return ForeverTrailSettings[key] == true end
 return ForeverTrailSettings[key] ~= false
end

local function show(widget, v) if widget then if v then widget:Show() else widget:Hide() end end end
-- Yazıyı ortak metin rengine boyar (düz görünüm)
local function tint(fs) local c = FT.Kit and FT.Kit.Color('text') or {1, 0.94, 0.82}; fs:SetTextColor(c[1], c[2], c[3]) end

-- Sayfalar: içeriği ayrı ayrı kurulan eski sayfalar. Kullanıcı bunları 6 kategorinin alt sekmesi olarak görür.
local PAGES = {
 {key='q_genel', label='Genel', icon='tracker_quests', desc='Genel ayarlar, sesler, grup ve rehber'},
 {key='q_simge', label='Simgeler', icon='fav', desc='Haritada ve mini haritada hangi simgelerin nasıl görüneceği'},
 {key='q_takip', label='Görev kutuları', icon='tracker_giver', desc='Görev takip kutusu ve alınabilir görevler'},
 {key='q_harita', label='Rota ve yolculuk', icon='node', desc='Rota, yol noktaları ve yolculuk'},
 {key='q_plaka', label='İsim plakası', icon='startend', desc='Görev yaratıklarının isim plakası simgeleri'},
 {key='q_oto', label='Otomatik', icon='tracker_clean', desc='Otomatik görev, çanta, satıcı ve kolaylıklar'},
 {key='sinifm', label='Sınıf / Meslek', icon='startend', desc='Yetenek planı, seviye kartı, sınıf görevleri, eşya ve meslek yardımcıları'},
 {key='uyari', label='Uyarılar', icon='tracker_close', desc='Uyarılar ve olay sesleri'},
 {key='gorunum', label='Pencereler ve tema', icon='tracker_database', desc='Pencereler, tema, saydamlık ve ölçek'},
 {key='ozel', label='Özelleştir', icon='tracker_settings', desc='Görev renkleri, rozet konumu ve canlı önizleme'},
 {key='q_profil', label='Profiller', icon='tracker_search', desc='Profiller, ayar aktarma ve yedekler'},
 {key='q_gelismis', label='Gelişmiş', icon='tracker_settings', desc='Yazı tipleri, ayar penceresi, testler ve araçlar'},
}
local PAGE_BY_KEY = {}
for _, p in ipairs(PAGES) do PAGE_BY_KEY[p.key] = p end

-- Kategoriler: kullanıcının ne yapmak istediğine göre. Kenar sekmeleri bunlardır (FT.SettingsTabs).
local GROUPS = {
 {key='g_genel', label='Genel', icon='tracker_quests', desc='Rehber, yön oku ve görev kutuları', pages={'q_genel', 'q_takip'}},
 {key='g_harita', label='Harita', icon='node', desc='Simgeler, rota, yolculuk ve isim plakaları', pages={'q_simge', 'q_harita', 'q_plaka'}},
 {key='g_oto', label='Otomatik ve uyarılar', icon='tracker_clean', desc='Otomatik görev, çanta ve satıcı işleri; uyarılar ve sesler', pages={'q_oto', 'uyari'}},
 {key='g_sinif', label='Sınıf ve meslek', icon='startend', desc='Yetenek planı, seviye kartı, eşya ve meslek yardımcıları', pages={'sinifm'}},
 {key='g_gorunum', label='Görünüm', icon='tracker_database', desc='Pencereler, tema, ölçek ve görev renkleri', pages={'gorunum', 'ozel'}},
 {key='g_gelismis', label='Profil ve gelişmiş', icon='tracker_settings', desc='Profiller, yedekler, testler ve araçlar', pages={'q_profil', 'q_gelismis'}},
}
local GROUP_BY_KEY, GROUP_OF_PAGE = {}, {}
for _, g in ipairs(GROUPS) do
 GROUP_BY_KEY[g.key] = g
 for _, pk in ipairs(g.pages) do GROUP_OF_PAGE[pk] = g end
end

FT.SettingsTabs = GROUPS
FT.SettingsPages = PAGES

-- Eski sayfa adları (gorev, yol, canta...) artık sayfa değil; ilgili yeni yere yönlendirilir.
local LEGACY_PAGE = {gorev='q_genel', yol='q_harita', canta='q_oto', simge='q_simge', kutu='q_takip', harita='q_harita'}
local function resolve(key)
 key = LEGACY_PAGE[key] or key
 local g = GROUP_BY_KEY[key]
 if g then
  local last = ForeverTrailSettings and ForeverTrailSettings.c_lastPage
  for _, pk in ipairs(g.pages) do if pk == last then return g, pk end end
  return g, g.pages[1]
 end
 if PAGE_BY_KEY[key] then return GROUP_OF_PAGE[key], key end
end
FT.SettingsGroupOf = function(key) local g = resolve(key); return g and g.key end

local items = {
 {tab='gorev', key='learn', label='Oynarken görev verisi topla (kendi veritabanımız)'},
 {tab='gorev', key='autonext', label='Sürekli rota: hedef bitince sıradakine geç'},
 {tab='gorev', key='auto', label='Otomatik ilerle', apply=function() FT.Evaluate() end},
 {tab='gorev', key='autoquest', label='Görevleri otomatik al / teslim et (Shift basılıyken kapalı)'},
 {tab='sinifm', key='rewardadvisor', label='Görev ödülü danışmanı'},
 {tab='sinifm', key='autoreward', label='Önerilen ödülü otomatik seç'},
 {tab='gorev', key='raidmarks', label='Görev NPC / yaratıklarına işaret koy (bazı istemcilerde "engellendi" uyarısı verir)'},
 {tab='sinifm', key='classquests', label='Sınıf görevi uyarısı'},
 {tab='gorev', key='reader', label='Türkçe görev okuma penceresi'},
 {tab='gorev', key='questitem', label='Görev eşyası düğmesi'},
 {tab='sinifm', key='talentpanel', label='Yetenek penceresinin (N) yanında yetenek planı paneli'},
 {tab='sinifm', key='levelcard', label='Seviye atlayınca kart: yetenek, eğitmen, sınıf görevi, evcil hayvan'},
 {tab='sinifm', key='talentglow', label='Yetenek penceresinde plandaki sıradaki yeteneği parlat'},
 {tab='sinifm', key='autotalent', label='Yetenek puanını plana göre sormadan ver'},
 {tab='sinifm', key='talentadvisor', label='Yetenek puanı hatırlatıcısı'},
 {tab='gorev', key='showLow', label='Seviyemin altındaki görevleri göster'},
 {tab='gorev', key='announce', label='İlerlemeyi gruba duyur'},
 {tab='gorev', key='breadcrumbs', label='Yol açan görevleri otomatik bırak'},
 {tab='gorev', key='groupsync', label='Grup görev ilerlemesi', apply=function() if FT.RefreshTracker then FT.RefreshTracker() end end},
 {tab='yol', key='arrow', label='Yön oku', apply=function() FT.UpdateArrow() end},
 {tab='yol', key='minimap', label='Mini harita işareti', apply=function() FT.UpdateMinimapPin() end},
 {tab='simge', key='objareas', label='Tüm görevlerin hedef bölgeleri (harita + minimap)', apply=function() if FT.RefreshMap then pcall(FT.RefreshMap) end end},
 {tab='yol', key='mapRoute', label='Haritada "Yol sor" paneli', apply=function(v) if FT.mapRoute and not v then FT.mapRoute:Hide() end end},
 {tab='yol', key='retarget', label='Hedefi konumuma göre güncelle'},
 {tab='yol', key='flightplan', label='Uçuş rotası öner'},
 {tab='simge', key='givers', label='Haritada ve minimapte ! / ? görev işaretleri', apply=function() if FT.RefreshMap then pcall(FT.RefreshMap) end end},
 {tab='yol', key='travel', label='Kıtalar arası yol tarifi (zeplin/gemi)'},
 {tab='simge', key='stations', label='Meslek istasyonlarını haritada göster', apply=function() if FT.RefreshMap then pcall(FT.RefreshMap) end end},
 {tab='yol', key='flighttimes', label='Uçuşta kalan süre çubuğu'},
 {tab='simge', key='dungeonicons', label='Haritada zindan girişleri', apply=function() if FT.RefreshMap then pcall(FT.RefreshMap) end end},
 {tab='yol', key='corpse', label='Ölünce cesede yol göster'},
 {tab='yol', key='hearth', label='Ocak taşı danışmanı'},
 {tab='yol', key='flightalert', label='Uçuş noktası uyarıları'},
 {tab='harita', key='npcpaths', label='Gezgin NPC yollarını haritada göster', apply=function() if FT.RefreshMap then pcall(FT.RefreshMap) end end},
 {tab='harita', key='partymap', label='Grubun görevlerini haritada göster', apply=function() if FT.RefreshMap then pcall(FT.RefreshMap) end end},
 {tab='simge', key='nodes', label='Meslek düğümlerini haritada göster', apply=function() if FT.RefreshMap then pcall(FT.RefreshMap) end end},
 {tab='sinifm', key='profhelper', label='Meslek penceresinin yanında "puan için ne yapmalı" listesi'},
 {tab='sinifm', key='profwarn', label='Meslek sınırına gelince eğitmen uyarısı'},
 {tab='canta', key='autoloot', label='Otomatik toplama'},
 {tab='canta', key='autosell', label='Satıcıda çöp eşyaları sat'},
 {tab='canta', key='autorepair', label='Satıcıda otomatik tamir'},
 {tab='canta', key='questItemGuard', label='Görev eşyalarını koru (satılmaz; yanlışlıkla satılırsa geri alınır)'},
 {tab='canta', key='goldmark', label='Satılacak eşyalara altın işareti', apply=function() if FT.UpdateBagMarks then pcall(FT.UpdateBagMarks) end end},
 {tab='sinifm', key='upgrades', label='Daha iyi eşya çıkınca karşılaştırıp sor (sınıfına göre stat puanı)', apply=function(v) if v and FT.ScanUpgrades then FT.ScanUpgrades() end end},
 {tab='canta', key='itemquests', label='Eşya ipucunda görev bilgisi'},
 {tab='canta', key='compare', label='Eşya karşılaştırma ipucu'},
 {tab='sinifm', key='swap', label='Çanta doluyken: daha değerli eşya için hangisi atılsın diye sor'},
 {tab='sinifm', key='autoequip', label='Daha iyi eşyayı sormadan tak (kuşanınca bağlananlar yine sorulur)'},
 {tab='canta', key='bagwarn', label='Çanta doluluk uyarısı'},
 {tab='canta', key='autosummon', label='Grup çağrısını otomatik kabul et'},
 {tab='canta', key='autorez', label='Dirilmeyi otomatik kabul et'},
 {tab='canta', key='blockduels', label='Lonca dışından düelloları engelle'},
 {tab='canta', key='maxcamera', label='Kamerayı daha uzağa çekebil', apply=function() if FT.ApplyCamera then FT.ApplyCamera() end end},
 {tab='canta', key='noglow', label='Ekran parlamasını kapat', apply=function() if FT.ApplyCamera then FT.ApplyCamera() end end},
 {tab='canta', key='banksort', label='Banka açılınca otomatik düzenle'},
 {tab='uyari', key='creaturewarn', label='Hedeflenen görev yaratığı uyarısı'},
 {tab='uyari', key='plateItemIcon', label='Eşya görevlerinde yaratığın üstünde istenen eşyanın resmi', apply=function() if FT.RefreshPlates then pcall(FT.RefreshPlates) end end},
 {tab='uyari', key='creaturenear', label='Yakından geçen görev yaratığı uyarısı'},
 {tab='uyari', key='danger', label='Güvenli mod: tehlikeli yaratık uyarısı'},
 {tab='uyari', key='elitewarn', label='Elit / zor hedef uyarısı'},
 {tab='uyari', key='trainerwarn', label='Meslek eğitmeni hatırlatıcısı'},
 {tab='uyari', key='supplies', label='Dayanıklılık ve ok/mermi uyarısı'},
 {tab='uyari', key='rarecard', label='Nadir yaratık yakında: 3B görselli kart'},
 {tab='harita', key='raremodel', label='Haritada nadir yaratık üzerine gelince görseli'},
 {tab='uyari', key='rares', label='Nadir yaratık uyarısı ve minimap simgesi'},
 {tab='uyari', key='trainerremind', label='Seviye atlayınca eğitmen hatırlatıcısı'},
 {tab='uyari', key='mobloot', label='Yaratık ipucunda düşürdüğü görev eşyaları'},
 {tab='uyari', key='sound', label='Sesler'},
 {tab='simge', key='iconglow', label='Simgelerin arkasında koyu parıltı (daha okunaklı)', apply=function() if FT.BumpLayers then FT.BumpLayers() end; if FT.RefreshMap then pcall(FT.RefreshMap) end end},
 {tab='simge', key='mmfade', label='Minimapte uzak simgeleri soldur'},
 {tab='simge', key='mmedge', label='Minimap kenarında uzak hedeflere ok'},
 {tab='simge', key='mmtips', label='Mini haritada simgenin üzerine gelince açıklama göster'},
 {tab='simge', key='focusbig', label='Odak görevin simgelerini büyüt', apply=function() if FT.BumpLayers then FT.BumpLayers() end; if FT.RefreshMap then pcall(FT.RefreshMap) end end},
 {tab='kutu', key='trkring', label='Görev başlığının yanında yüzde halkası', apply=function() if FT.RefreshTracker then FT.RefreshTracker() end end},
 {tab='kutu', key='trkfx', label='Hedef ilerleyince +1 efekti'},
 {tab='kutu', key='trkitems', label='Görev eşyası düğmesi satırın yanında', apply=function() if FT.RefreshTracker then FT.RefreshTracker() end end},
 {tab='uyari', key='donebanner', label='Görev bitince ekranda "Görev tamamlandı" afişi'},
 {tab='uyari', key='platecolor', label='Görev yaratığının can barı görev renginde'},
 {tab='gorunum', key='anims', label='Pencereler yumuşak açılsın'},
 {tab='kutu', key='availbox', label='Solda alınabilir görevler kutusu', apply=function() if FT.RefreshAvailableBox then FT.RefreshAvailableBox() end end},
 {tab='kutu', key='trkdiff', label='Görev seviyesini göster, başlığı zorluk renginde boya', apply=function() if FT.RefreshTracker then FT.RefreshTracker() end end},
 {tab='kutu', key='trkzones', label='Bölge başlıkları (tıkla: bölgeyi daralt)', apply=function() if FT.RefreshTracker then FT.RefreshTracker() end end},
 {tab='kutu', key='trkAutoMin', label='Biten görevleri otomatik daralt', apply=function() if FT.RefreshTracker then FT.RefreshTracker() end end},
 {tab='kutu', key='trkHideDoneObj', label='Tamamlanan hedefleri gizle', apply=function() if FT.RefreshTracker then FT.RefreshTracker() end end},
 {tab='kutu', key='trkCombat', label='Savaşta görev kutusunu daralt', apply=function() if FT.RefreshTracker then FT.RefreshTracker() end end},
 {tab='kutu', key='trkInstance', label='Zindanda görev kutusunu daralt', apply=function() if FT.RefreshTracker then FT.RefreshTracker() end end},
 {tab='harita', key='routenums', label='Haritada ve görev kutusunda rota numaraları ve süre'},
 {tab='harita', key='mapmove', label='Dünya haritasını taşı (üst kenardan ya da Alt+sürükle, sağ tık: sıfırla)'},
 {tab='harita', key='raremap', label='Dünya haritasında nadir yaratıklar', apply=function() if FT.BumpLayers then FT.BumpLayers() end end},
 {tab='harita', key='townsfolk', label='Haritada kasaba işaretleri (tamirci, han, uçuş, banka, posta...)', apply=function() if FT.BumpLayers then FT.BumpLayers() end end},
 {tab='harita', key='townprof', label='Kasaba işaretlerinde meslek eğitmenleri', apply=function() if FT.BumpLayers then FT.BumpLayers() end end},
 {tab='harita', key='qareas', label='Questie görünümünde de görev bölgesi alanlarını çiz'},
 {tab='harita', key='heatmap', label='Yaratığın yoğun olduğu yer haritada daha koyu'},
 {tab='yol', key='flightadvice', label='Hedef uzaksa uçuş öner'},
 {tab='yol', key='partyfirst', label='Rotada grupla ortak görevler önce'},
 {tab='yol', key='deathadvice', label='Ölünce: cesede koş mu, ruh iyileştirici mi?'},
 {tab='yol', key='beep', label='Hedefe yaklaşınca bip sesi'},
 {tab='gorev', key='dropadvisor', label='Görev günlüğü dolunca bırakılacak görevi öner'},
 {tab='gorev', key='zonefit', label='Bölgeye girince "bana uygun mu?" göstergesi'},
 {tab='uyari', key='objtips', label='Görev nesnelerinin (sandık, bitki) ipucunda görev ilerlemesi'},
 {tab='gorunum', key='optstyle', label='Ayarlar Questie penceresinde açılsın (kapalıysa ana pencerede)', apply=function(v) ForeverTrailSettings.c_optionsStyle = v and 'questie' or 'ft'; FT.Print('Değişikliğin tam uygulanması için /reload yaz.') end},
 {tab='gorunum', key='globalfonts', label='Oyunun yazılarında da Türkçe harfler (WoWTR yazı tipi, /reload)'},
 {tab='gorev', key='ctxauto', label='Savaşta ve zindanda gereksiz kutuları gizle'},
 {tab='gorev', key='sessionsummary', label='Girişte son oturum özeti'},
 {tab='gorunum', key='simple', label='Sade görünüm (yalnızca ok ve görev kutusu)', apply=function() if FT.ApplySimple then FT.ApplySimple() end end},
 {tab='kutu', key='tracker', label='Görev kutusu', apply=function(v) show(FT.tracker, v); if v and FT.RefreshTracker then FT.RefreshTracker() end end},
 {tab='gorunum', key='card', label='Hedef kartı', apply=function(v) show(FT.card, v); if v and FT.RefreshTarget then FT.RefreshTarget() end end},
 {tab='gorunum', key='dock', label='Düğme çubuğu', apply=function(v) show(FT.dock, v) end},
 {tab='gorunum', key='infobar', label='Üstte bilgi çubuğu (XP/saat, altın, dayanıklılık, çanta)', apply=function() if FT.UpdateInfoBar then FT.UpdateInfoBar() end end},
 {tab='gorunum', key='compact', label='Küçük panel', apply=function(v) if FT.SetCompact then FT.SetCompact(v) end end},
}

local WIDTH, HEIGHT = 616, 640
local SIDEW = 132
local CW = WIDTH - SIDEW - 24

function FT.CreateSettings()
 if frame then return end
 frame = newWindow('ForeverTrailOptions', UIParent)
 FT.settings = frame
 frame:SetSize(WIDTH, HEIGHT)
 frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 40)
 frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag('LeftButton')
 frame:SetScript('OnDragStart', function(self) self:StartMoving() end)
 frame:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
 frame:SetFrameStrata('DIALOG')
 local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 title:SetPoint('TOP', 0, -7); title:SetText('ForeverTrail ayarları'); applyFont(title)
 frame.title = title
 frame.pages, frame.tabButtons, frame.checks = {}, {}, {}
 -- Questie gibi: solda kategori listesi, sağda başlık + açıklama + içerik
 local side = frame:CreateTexture(nil, 'BACKGROUND', nil, 2)
 side:SetPoint('TOPLEFT', 8, -28); side:SetPoint('BOTTOMLEFT', 8, 8); side:SetWidth(SIDEW - 8)
 if FT.Kit then FT.Kit.Fill(side, 'rail') else side:SetColorTexture(0, 0, 0, 0.22) end
 frame.sideBg = side
 frame.pageTitle = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
 frame.pageTitle:SetPoint('TOPLEFT', SIDEW + 12, -32); applyFont(frame.pageTitle)
 frame.pageDesc = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 frame.pageDesc:SetPoint('TOPLEFT', frame.pageTitle, 'BOTTOMLEFT', 0, -4); frame.pageDesc:SetWidth(CW); frame.pageDesc:SetJustifyH('LEFT')
 applyFont(frame.pageDesc); do local m = FT.Kit and FT.Kit.Color('muted') or {0.75, 0.71, 0.64}; frame.pageDesc:SetTextColor(m[1], m[2], m[3]) end
 local headLine = frame:CreateTexture(nil, 'ARTWORK'); headLine:SetHeight(1)
 headLine:SetPoint('TOPLEFT', SIDEW + 12, -70); headLine:SetPoint('TOPRIGHT', -12, -70); headLine:SetColorTexture(1, 1, 1, 1)
 if FT.RegisterAccent then FT.RegisterAccent(headLine, 0.4) end
 frame.headLine = headLine
 for _, t in ipairs(PAGES) do
  local page
  if t.key:sub(1, 2) == 'q_' then
   page = CreateFrame('Frame', nil, frame)
   page:SetPoint('TOPLEFT', SIDEW + 12, -80); page:SetPoint('BOTTOMRIGHT', -12, 10)
  else
   -- uzun sayfalar pencereden taşmasın: kaydırılabilir kap
   local holder = (FT.Kit and FT.Kit.Scroll(frame) or CreateFrame('ScrollFrame', nil, frame, 'UIPanelScrollFrameTemplate'))
   holder:SetPoint('TOPLEFT', SIDEW + 12, -80); holder:SetPoint('BOTTOMRIGHT', -30, 10)
   page = CreateFrame('Frame', nil, holder)
   page:SetSize(CW - 18, 1200)
   holder:SetScrollChild(page)
   page.holder = holder
   holder:Hide()
   holder:SetScript('OnShow', function()
    local function fit()
     local top = page:GetTop()
     if not top then return end
     local low = top
     local function scan(obj)
      local b = obj.GetBottom and obj:GetBottom()
      if b and obj:IsShown() and b < low then low = b end
     end
     for _, c in ipairs({page:GetChildren()}) do scan(c) end
     for _, r in ipairs({page:GetRegions()}) do scan(r) end
     page:SetHeight(math.max(10, top - low + 16))
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, fit) else fit() end
   end)
  end
  page:Hide()
  frame.pages[t.key] = page
 end
 for i, t in ipairs(GROUPS) do
  local b = CreateFrame('Button', nil, frame)
  b:SetSize(SIDEW - 8, 30); b:SetPoint('TOPLEFT', 8, -30 - (i - 1) * 32)
  b.bg = b:CreateTexture(nil, 'BACKGROUND', nil, 3); b.bg:SetAllPoints()
  b.bar = b:CreateTexture(nil, 'ARTWORK'); b.bar:SetPoint('TOPLEFT'); b.bar:SetPoint('BOTTOMLEFT'); b.bar:SetWidth(3)
  b.icon = b:CreateTexture(nil, 'ARTWORK'); b.icon:SetSize(16, 16); b.icon:SetPoint('LEFT', 9, 0)
  b.icon:SetTexture('Interface\\AddOns\\ForeverTrail\\Media\\' .. t.icon); b.icon:SetDesaturated(true)
  b.text = b:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight'); b.text:SetPoint('LEFT', b.icon, 'RIGHT', 7, 0)
  b.text:SetText(t.label); applyFont(b.text)
  b:SetHighlightTexture('Interface\\Buttons\\WHITE8X8'); b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
  b:SetScript('OnClick', function() FT.SettingsTab(t.key) end)
  b.key, b.def = t.key, t
  frame.tabButtons[i] = b
 end
 if FT.BuildSettingsNav then FT.BuildSettingsNav(frame) end
 local rowsUsed = {}
 for i, item in ipairs(items) do
  local page = frame.pages[item.tab]
  if page then
  local row = rowsUsed[item.tab] or 0
  rowsUsed[item.tab] = row + 1
  local check = (FT.Kit and FT.Kit.CheckBox(page) or CreateFrame('CheckButton', nil, page, 'UICheckButtonTemplate'))
  check:SetPoint('TOPLEFT', 0, -row * 26)
  local label = page:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  label:SetPoint('LEFT', check, 'RIGHT', 4, 0); label:SetWidth(CW - 40); label:SetJustifyH('LEFT')
  label:SetText(item.label); applyFont(label); tint(label)
  check:SetScript('OnClick', function(self)
   local value = self:GetChecked() and true or false
   ForeverTrailSettings[item.key] = value
   if FT.BumpLayers then FT.BumpLayers() end
   if item.apply then item.apply(value) end
   if FT.RefreshDock then pcall(FT.RefreshDock) end
  end)
  check.key = item.key
  frame.checks[#frame.checks + 1] = check
  end
 end
 -- Görünüm sayfası: kaydırıcılar, tema ve araçlar
 local look = frame.pages.gorunum
 local y = -(rowsUsed.gorunum or 0) * 30 - 10
 local function slider(name, labelText, minValue, maxValue, step, getValue, onChange)
  local text = look:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  text:SetPoint('TOPLEFT', 4, y); text:SetText(labelText); applyFont(text)
  local s = (FT.Kit and FT.Kit.Slider(look, name) or CreateFrame('Slider', name, look, 'OptionsSliderTemplate'))
  s:SetPoint('TOPLEFT', 6, y - 18); s:SetWidth(CW - 16)
  s:SetMinMaxValues(minValue, maxValue); s:SetValueStep(step); s:SetValue(getValue())
  s:SetScript('OnValueChanged', function(_, value) onChange(math.floor(value / step + 0.5) * step) end)
  y = y - 46
  return s
 end
 frame.slider = slider('ForeverTrailArrowScale', 'Yön oku boyutu', 0.6, 1.6, 0.1,
  function() return ForeverTrailSettings.arrowScale or 1 end,
  function(v) ForeverTrailSettings.arrowScale = v; if FT.arrow then FT.arrow:SetScale(v) end end)
 frame.alphaSlider = slider('ForeverTrailTrackerAlpha', 'Görev kutusu saydamlığı', 0.2, 1, 0.05,
  function() return ForeverTrailSettings.trackerAlpha or 1 end,
  function(v) ForeverTrailSettings.trackerAlpha = v; if FT.ApplyTrackerAlpha then FT.ApplyTrackerAlpha() end end)
 frame.uiScale = slider('ForeverTrailUIScale', 'Arayüz ölçeği (görev kutusu, kart, şerit, panel)', 0.7, 1.4, 0.05,
  function() return ForeverTrailSettings.uiScale or 1 end,
  function(v) ForeverTrailSettings.uiScale = v; if FT.ApplyUIScale then FT.ApplyUIScale() end end)
 local themeLabel = look:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 themeLabel:SetPoint('TOPLEFT', 4, y); themeLabel:SetText('Renk teması'); applyFont(themeLabel)
 y = y - 18
 local perRow, bw = 5, math.floor(CW / 5) - 4
 for index, key in ipairs(FT.themeOrder or {}) do
  local b = FT.NewButton and FT.NewButton(look, FT.Themes[key].name, bw, 20)
  b:SetPoint('TOPLEFT', ((index - 1) % perRow) * (bw + 4), y - math.floor((index - 1) / perRow) * 24)
  applyFont(b:GetFontString())
  b:SetScript('OnClick', function() FT.ApplyTheme(key) end)
 end
 y = y - math.ceil(#(FT.themeOrder or {}) / perRow) * 24 - 6
 if FT.BuildThemeEditor then y = FT.BuildThemeEditor(look, y, CW) end
 local tools = {
  {'Yazı tipi', function() if FT.CycleFont then FT.CycleFont() end end},
  {'Konumları sıfırla', function() if FT.ResetLayout then FT.ResetLayout() end end},
  {'Kilit aç/kapat', function() if FT.ToggleLock then FT.ToggleLock() end end},
  {'Ayarları aktar', function() if FT.ToggleTransfer then FT.ToggleTransfer() end end},
 }
 local tw = math.floor(CW / 4) - 4
 for i, t in ipairs(tools) do
  local b = FT.NewButton and FT.NewButton(look, t[1], tw, 22)
  b:SetPoint('TOPLEFT', (i - 1) * (tw + 4), y)
  applyFont(b:GetFontString())
  b:SetScript('OnClick', t[2])
 end
 if FT.BuildCustomizePage then FT.BuildCustomizePage(frame.pages.ozel, CW) end
 if FT.BuildQuestiePages then FT.BuildQuestiePages(frame, CW) end
 FT.BuildOptions(frame.pages.simge, -(rowsUsed.simge or 0) * 26 - 8, CW, FT.IconOptionDefs)
 FT.BuildOptions(frame.pages.kutu, -(rowsUsed.kutu or 0) * 26 - 8, CW, FT.TrackerOptionDefs)
 local soundY = FT.BuildSoundRows and FT.BuildSoundRows(frame.pages.uyari, -(rowsUsed.uyari or 0) * 26 - 10, CW)
 FT.BuildOptions(frame.pages.uyari, (soundY or -(rowsUsed.uyari or 0) * 26 - 10) - 4, CW, {
  {type='choice', key='c_rareRepeat', default='10', label='Nadir uyarısını tekrarla', list={{'5', '5 dk'}, {'10', '10 dk'}, {'15', '15 dk'}, {'30', '30 dk'}, {'once', 'Bir kez'}}},
 })
 frame:SetScript('OnShow', function(self)
  if FT.RefreshCustomizePage then FT.RefreshCustomizePage() end
  if FT.RefreshOptions then FT.RefreshOptions() end
  for _, check in ipairs(self.checks) do check:SetChecked(get(check.key)) end
  self.slider:SetValue(ForeverTrailSettings.arrowScale or 1)
  self.alphaSlider:SetValue(ForeverTrailSettings.trackerAlpha or 1)
  self.uiScale:SetValue(ForeverTrailSettings.uiScale or 1)
  local last = ForeverTrailSettings.c_lastPage
  FT.SettingsTab(self.current or (PAGE_BY_KEY[last] and last) or 'q_genel')
 end)
 frame:Hide()
end

-- Kenar düğmelerini boyar; on = açık kategorinin anahtarı (arama sonuçlarında nil: hiçbiri açık değil)
local function paintNav(on)
 local a = FT.Style.accent
 for _, b in ipairs(frame.tabButtons) do
  local sel = on ~= nil and b.key == on
  b.bar:SetShown(sel); b.bar:SetColorTexture(a[1], a[2], a[3], 1)
  b.bg:SetColorTexture(1, 1, 1, sel and 0.09 or 0)
  if sel then b.text:SetTextColor(a[1], a[2], a[3]); b.icon:SetVertexColor(a[1], a[2], a[3])
  else local m = FT.Kit and FT.Kit.Color('muted') or {0.8, 0.78, 0.72}; b.text:SetTextColor(m[1], m[2], m[3]); b.icon:SetVertexColor(m[1], m[2], m[3]) end
 end
end

-- key: kategori (g_...), sayfa (q_..., sinifm...) ya da eski sayfa adı. Kategori verilirse en son bakılan alt sekme açılır.
function FT.SettingsTab(key)
 if not frame then return end
 local g, pk = resolve(key)
 if not g then return end
 frame.current = pk
 if ForeverTrailSettings then ForeverTrailSettings.c_lastPage = pk end
 if frame.searchBox and frame.searchBox:GetText() ~= '' then
  frame.searchQuiet = true; frame.searchBox:SetText(''); frame.searchQuiet = false
  if frame.searchHint then frame.searchHint:Show() end
 end
 for k, page in pairs(frame.pages) do
  if k == pk then page:Show() else page:Hide() end
  if page.holder then page.holder:SetShown(k == pk) end
 end
 paintNav(g.key)
 local a = FT.Style.accent
 frame.pageTitle:SetText(g.label); frame.pageTitle:SetTextColor(a[1], a[2], a[3])
 local multi = #g.pages > 1
 frame.pageDesc:SetText(multi and '' or PAGE_BY_KEY[pk].desc)
 for gk, bar in pairs(frame.subBars or {}) do
  for _, b in ipairs(bar) do
   if gk == g.key then b:Show(); if b.pageKey == pk then b:Disable() else b:Enable() end else b:Hide() end
  end
 end
end

function FT.ToggleSettings()
 if not frame then return end
 if frame:IsShown() then frame:Hide() else frame:Show() end
end


----------------------------------------------------------------------
-- Özelleştir sayfası: simge boyutları, bölge belirginliği, rozet konumu, renk paleti, ok rengi, canlı önizleme
----------------------------------------------------------------------
local custom
local SLIDERS = {
 {key='areaAlpha', label='Görev bölgesi belirginliği', min=0.3, max=2.5, step=0.1},
 {key='plate', label='Yaratık rozeti boyutu', min=0.6, max=1.8, step=0.05},
 {key='plateX', label='Rozet konumu (yatay)', min=-40, max=40, step=1},
 {key='plateY', label='Rozet konumu (dikey)', min=-30, max=30, step=1},
 {key='fontScale', label='Yazı boyutu', min=0.8, max=1.4, step=0.05},
}

local function refreshWorld()
 if FT.BumpLayers then FT.BumpLayers() end
 if FT.RefreshMap and WorldMapFrame and WorldMapFrame:IsShown() then pcall(FT.RefreshMap) end
 if FT.ApplyUIScale then pcall(FT.ApplyUIScale) end
 if FT.RefreshTracker then pcall(FT.RefreshTracker) end
 if FT.ApplyFontScale then pcall(FT.ApplyFontScale) end
end

local function updatePreview()
 if not custom then return end
 local p = custom.preview
 local plate = FT.Scale('plate')
 p.badge:SetScale(plate)
 p.badge:ClearAllPoints(); p.badge:SetPoint('LEFT', p.bar, 'RIGHT', 4 + FT.Scale('plateX'), FT.Scale('plateY'))
 local c1 = FT.QuestColor(1)
 p.badge.ring:SetVertexColor(c1[1], c1[2], c1[3]); p.badge.count:SetTextColor(c1[1], c1[2], c1[3])
 local mi = FT.Scale('mapIcons')
 for i, dot in ipairs(p.dots) do
  local c = FT.QuestColor(i)
  dot:SetSize(18 * mi, 18 * mi); dot.bg:SetSize(24 * mi, 24 * mi)
  if FT.SetObjectiveIcon then FT.SetObjectiveIcon(dot.icon, dot.bg, dot.kind, c, 1) else dot.bg:SetVertexColor(c[1], c[2], c[3], 0.95) end
  dot.area:SetVertexColor(c[1], c[2], c[3], math.min(0.6, 0.16 * FT.Scale('areaAlpha')))
 end
 for _, b in ipairs(custom.paletteButtons) do if b.key == (ForeverTrailSettings.c_palette or 'canli') then b:Disable() else b:Enable() end end
 for _, b in ipairs(custom.arrowButtons) do if b.key == (ForeverTrailSettings.c_arrowColor or 'yon') then b:Disable() else b:Enable() end end
end

function FT.RefreshCustomizePage()
 if not custom then return end
 for _, s in ipairs(custom.sliders) do s:SetValue(FT.Scale(s.key)) end
 updatePreview()
end

function FT.BuildCustomizePage(page, width)
 if custom or not page then return end
 custom = {sliders = {}, paletteButtons = {}, arrowButtons = {}}
 local y = 0
 for i, def in ipairs(SLIDERS) do
  local col = (i - 1) % 2
  local sx = col * (width / 2)
  local text = page:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  text:SetPoint('TOPLEFT', sx + 4, y); text:SetText(def.label); applyFont(text)
  local s = (FT.Kit and FT.Kit.Slider(page, 'ForeverTrailCustom' .. def.key) or CreateFrame('Slider', 'ForeverTrailCustom' .. def.key, page, 'OptionsSliderTemplate'))
  s:SetPoint('TOPLEFT', sx + 6, y - 16); s:SetWidth(width / 2 - 20)
  s:SetMinMaxValues(def.min, def.max); s:SetValueStep(def.step)
  local low, high = _G[s:GetName() .. 'Low'], _G[s:GetName() .. 'High']
  if low then low:SetText('') end
  if high then high:SetText('') end
  s.key = def.key
  s:SetScript('OnValueChanged', function(_, value)
   value = math.floor(value / def.step + 0.5) * def.step
   ForeverTrailSettings['c_' .. def.key] = value
   updatePreview(); refreshWorld()
  end)
  custom.sliders[#custom.sliders + 1] = s
  if col == 1 then y = y - 40 end
 end
 y = y - 44
 local function row(label, list, store, key)
  local text = page:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  text:SetPoint('TOPLEFT', 4, y); text:SetText(label); applyFont(text)
  local bw = math.floor((width - 110) / #list) - 4
  for i, item in ipairs(list) do
   local b = FT.NewButton(page, item[2], bw, 20)
   b:SetPoint('TOPLEFT', 110 + (i - 1) * (bw + 4), y + 3)
   b.key = item[1]
   b:SetScript('OnClick', function() ForeverTrailSettings[key] = item[1]; updatePreview(); refreshWorld() end)
   store[#store + 1] = b
  end
  y = y - 26
 end
 local palettes = {}
 for _, k in ipairs(FT.paletteOrder) do palettes[#palettes + 1] = {k, FT.Palettes[k].name} end
 row('Görev renkleri', palettes, custom.paletteButtons, 'c_palette')
 row('Yön oku rengi', {{'yon', 'Yöne göre'}, {'tema', 'Tema'}, {'tur', 'Adım türü'}}, custom.arrowButtons, 'c_arrowColor')
 -- Canlı önizleme
 local p = CreateFrame('Frame', nil, page)
 p:SetPoint('TOPLEFT', 0, y - 6); p:SetSize(width, 74)
 local bg = p:CreateTexture(nil, 'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(0.18, 0.24, 0.14, 0.9)
 local label = p:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall'); label:SetPoint('TOPLEFT', 6, -4); label:SetText('Önizleme'); applyFont(label)
 p.bar = p:CreateTexture(nil, 'ARTWORK'); p.bar:SetColorTexture(0.75, 0.12, 0.1, 1); p.bar:SetSize(90, 8); p.bar:SetPoint('LEFT', 16, -6)
 local blob = 'Interface\\CHARACTERFRAME\\TempPortraitAlphaMask'
 local badge = CreateFrame('Frame', nil, p); badge:SetSize(26, 26)
 badge.ring = badge:CreateTexture(nil, 'BORDER'); badge.ring:SetTexture(blob); badge.ring:SetAllPoints()
 badge.inner = badge:CreateTexture(nil, 'ARTWORK'); badge.inner:SetTexture(blob); badge.inner:SetSize(22, 22); badge.inner:SetPoint('CENTER'); badge.inner:SetVertexColor(0, 0, 0, 0.75)
 badge.icon = badge:CreateTexture(nil, 'OVERLAY'); badge.icon:SetSize(16, 16); badge.icon:SetPoint('CENTER'); badge.icon:SetTexture('Interface\\Icons\\INV_Sword_04'); badge.icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
 badge.count = badge:CreateFontString(nil, 'OVERLAY'); badge.count:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', 11, 'OUTLINE'); badge.count:SetPoint('LEFT', badge, 'RIGHT', 2, 0); badge.count:SetText('3/8')
 p.badge = badge
 p.dots = {}
 local icons = {'Interface\\Icons\\INV_Sword_04', 'Interface\\Icons\\INV_Misc_Bag_08', 'Interface\\Icons\\INV_Misc_Gear_01', 'Interface\\Icons\\INV_Sword_04'}
 for i = 1, 4 do
  local d = CreateFrame('Frame', nil, p)
  d:SetPoint('CENTER', p, 'LEFT', width - 230 + i * 50, -6)
  d.area = d:CreateTexture(nil, 'BACKGROUND'); d.area:SetTexture(blob); d.area:SetSize(48, 48); d.area:SetPoint('CENTER')
  d.bg = d:CreateTexture(nil, 'BORDER'); d.bg:SetTexture(blob); d.bg:SetPoint('CENTER')
  d.icon = d:CreateTexture(nil, 'ARTWORK'); d.icon:SetAllPoints(); d.icon:SetTexture(icons[i]); d.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
  d.kind = ({'kill', 'loot', 'object', 'kill'})[i]
  p.dots[i] = d
 end
 custom.preview = p
 y = y - 86
 local reset = FT.NewButton(page, 'Varsayılana dön', 130, 22)
 reset:SetPoint('TOPLEFT', 0, y)
 reset:SetScript('OnClick', function()
  for _, def in ipairs(SLIDERS) do ForeverTrailSettings['c_' .. def.key] = nil end
  ForeverTrailSettings.c_palette, ForeverTrailSettings.c_arrowColor, ForeverTrailSettings.c_iconStyle, ForeverTrailSettings.c_trackerSort, ForeverTrailSettings.c_trackerBg = nil, nil, nil, nil, nil
  FT.RefreshCustomizePage(); refreshWorld()
 end)
 applyFont(reset:GetFontString())
end


-- Uyarılar sekmesi: her olay için ses seçimi (tıklayınca sıradaki ses) ve dinleme
function FT.BuildSoundRows(page, y, width)
 if not (page and FT.SoundEvents) then return end
 local head = page:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 head:SetPoint('TOPLEFT', 4, y); head:SetText('Sesler'); applyFont(head)
 y = y - 20
 local function nameOf(key)
  for _, s in ipairs(FT.SoundChoices) do if s.key == key then return s.name end end
  return key
 end
 for _, e in ipairs(FT.SoundEvents) do
  local label = page:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  label:SetPoint('TOPLEFT', 4, y - 4); label:SetText(e.label); applyFont(label)
  local b = FT.NewButton(page, '', 130, 20)
  b:SetPoint('TOPLEFT', 190, y)
  local function show() b:SetText(nameOf(ForeverTrailSettings['snd_' .. e.key] or e.default)) end
  b:SetScript('OnClick', function()
   local cur = ForeverTrailSettings['snd_' .. e.key] or e.default
   local idx = 1
   for i, s in ipairs(FT.SoundChoices) do if s.key == cur then idx = i end end
   ForeverTrailSettings['snd_' .. e.key] = FT.SoundChoices[idx % #FT.SoundChoices + 1].key
   show(); FT.PlayEventSound(e.key)
  end)
  local test = FT.NewButton(page, 'Dinle', 60, 20)
  test:SetPoint('LEFT', b, 'RIGHT', 6, 0)
  test:SetScript('OnClick', function() FT.PlayEventSound(e.key) end)
  page:HookScript('OnShow', show); show()
  y = y - 24
 end
 return y
end


----------------------------------------------------------------------
-- Bölümlü seçenek sayfaları (Simgeler, Görev kutusu): başlık, kaydırıcı, seçim düğmeleri
----------------------------------------------------------------------
local optionWidgets = {}
local afterChange
afterChange = function()
 if FT.BumpLayers then FT.BumpLayers() end
 if FT.RefreshMap and WorldMapFrame and WorldMapFrame:IsShown() then pcall(FT.RefreshMap) end
 if FT.ApplyUIScale then pcall(FT.ApplyUIScale) end
 if FT.ApplyTrackerAlpha then pcall(FT.ApplyTrackerAlpha) end
 if FT.RefreshTracker then pcall(FT.RefreshTracker) end
 if FT.RefreshAvailableBox then pcall(FT.RefreshAvailableBox) end
end

function FT.RefreshOptions()
 for _, w in ipairs(optionWidgets) do
  if w.check then w.check:SetChecked(get(w.key))
  elseif w.slider then w.slider:SetValue(FT.Scale(w.key))
  elseif w.buttons then
   local cur = ForeverTrailSettings[w.key] or w.default
   for _, b in ipairs(w.buttons) do if b.key == cur then b:Disable() else b:Enable() end end
  end
 end
end

function FT.BuildOptions(page, y, width, defs)
 if not (page and defs) then return end
 local col, sliderN = 0, 0
 for _, def in ipairs(defs) do
  if def.type == 'header' then
   if col == 1 then y = y - 40; col = 0 end
   y = y - 6
   local text = page:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
   text:SetPoint('TOPLEFT', 2, y); text:SetText(def.text); applyFont(text)
   local a = FT.Style.accent; text:SetTextColor(a[1], a[2], a[3])
   local line = page:CreateTexture(nil, 'ARTWORK'); line:SetHeight(1)
   line:SetPoint('LEFT', text, 'RIGHT', 6, 0); line:SetPoint('RIGHT', page, 'RIGHT', -4, 0)
   line:SetColorTexture(1, 1, 1, 1)
   if FT.RegisterAccent then FT.RegisterAccent(line, 0.35) end
   y = y - 20
  elseif def.type == 'slider' then
   sliderN = sliderN + 1
   local sx = col * (width / 2)
   local text = page:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
   text:SetPoint('TOPLEFT', sx + 4, y); text:SetText(def.label); applyFont(text)
   local name = 'ForeverTrailOpt' .. def.key
   local s = (FT.Kit and FT.Kit.Slider(page, name) or CreateFrame('Slider', name, page, 'OptionsSliderTemplate'))
   s:SetPoint('TOPLEFT', sx + 6, y - 16); s:SetWidth(width / 2 - 20)
   s:SetMinMaxValues(def.min, def.max); s:SetValueStep(def.step)
   local low, high = _G[name .. 'Low'], _G[name .. 'High']
   if low then low:SetText('') end
   if high then high:SetText('') end
   s:SetScript('OnValueChanged', function(_, value)
    ForeverTrailSettings['c_' .. def.key] = math.floor(value / def.step + 0.5) * def.step
    afterChange()
   end)
   optionWidgets[#optionWidgets + 1] = {slider = s, key = def.key}
   if col == 1 then y = y - 40; col = 0 else col = 1 end
  elseif def.type == 'check' then
   if col == 1 then y = y - 40; col = 0 end
   local c = (FT.Kit and FT.Kit.CheckBox(page) or CreateFrame('CheckButton', nil, page, 'UICheckButtonTemplate'))
   c:SetPoint('TOPLEFT', 0, y + 1); c:SetSize(18, 18)
   local label = page:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
   label:SetPoint('LEFT', c, 'RIGHT', 4, 0); label:SetWidth(width - 40); label:SetJustifyH('LEFT')
   label:SetText(def.label); applyFont(label); tint(label)
   c:SetChecked(get(def.key))
   c:SetScript('OnClick', function(self)
    local v = self:GetChecked() and true or false
    ForeverTrailSettings[def.key] = v
    if def.apply then pcall(def.apply, v) end
    afterChange()
   end)
   if def.tip then
    c:SetScript('OnEnter', function(self) GameTooltip:SetOwner(self, 'ANCHOR_RIGHT'); GameTooltip:SetText(def.label, 1, 0.82, 0); GameTooltip:AddLine(def.tip, 1, 1, 1, true); if FT.ShowTip then FT.ShowTip(GameTooltip) else GameTooltip:Show() end end)
    c:SetScript('OnLeave', function() GameTooltip:Hide() end)
   end
   optionWidgets[#optionWidgets + 1] = {check = c, key = def.key}
   y = y - 24
  elseif def.type == 'buttons' then
   if col == 1 then y = y - 40; col = 0 end
   local bw = math.floor(width / 3) - 6
   for i, item in ipairs(def.list) do
    local b = FT.NewButton(page, item[1], bw, 22)
    b:SetPoint('TOPLEFT', ((i - 1) % 3) * (bw + 6), y - math.floor((i - 1) / 3) * 26)
    applyFont(b:GetFontString())
    b:SetScript('OnClick', function() pcall(item[2]) end)
   end
   y = y - math.ceil(#def.list / 3) * 26 - 4
  elseif def.type == 'choice' then
   if col == 1 then y = y - 40; col = 0 end
   local text = page:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
   text:SetPoint('TOPLEFT', 4, y); text:SetWidth(104); text:SetJustifyH('LEFT'); text:SetText(def.label); applyFont(text)
   local list, store = def.list, {}
   local bw = math.floor((width - 110) / #list) - 4
   for i, item in ipairs(list) do
    local b = FT.NewButton(page, item[2], bw, 20)
    b:SetPoint('TOPLEFT', 110 + (i - 1) * (bw + 4), y + 3)
    applyFont(b:GetFontString())
    b.key = item[1]
    b:SetScript('OnClick', function() ForeverTrailSettings[def.key] = item[1]; afterChange(); FT.RefreshOptions() end)
    store[#store + 1] = b
   end
   optionWidgets[#optionWidgets + 1] = {buttons = store, key = def.key, default = def.default}
   y = y - 26
  end
 end
 if col == 1 then y = y - 40 end
 return y
end

FT.IconOptionDefs = {
 {type='header', text='Simge stili'},
 {type='choice', key='c_iconStyle', default='questie', label='Simgeler', list={{'questie', 'Questie'}, {'sade', 'Sade (görev renginde)'}, {'renkli', 'Renkli ikon'}}},
 {type='header', text='Simge boyutları'},
 {type='slider', key='mapIcons', label='Harita (hepsi)', min=0.6, max=1.8, step=0.05},
 {type='slider', key='mmIcons', label='Minimap (hepsi)', min=0.6, max=1.8, step=0.05},
 {type='slider', key='iconGiver', label='Görev veren ! ?', min=0.5, max=2, step=0.05},
 {type='slider', key='iconKill', label='Öldürme hedefi', min=0.5, max=2, step=0.05},
 {type='slider', key='iconLoot', label='Toplama hedefi', min=0.5, max=2, step=0.05},
 {type='slider', key='iconObject', label='Nesne hedefi', min=0.5, max=2, step=0.05},
 {type='header', text='Minimap'},
 {type='slider', key='mmFadeStart', label='Soldurma başlangıcı', min=0.2, max=1, step=0.05},
}

FT.TrackerOptionDefs = {
 {type='header', text='Düzen'},
 {type='choice', key='c_trackerSort', default='durum', label='Sıralama', list={{'durum', 'Durum'}, {'bolge', 'Bölge'}, {'yakin', 'Yakınlık'}, {'seviye', 'Seviye'}, {'yuzde', '% bitmiş'}}},
 {type='choice', key='c_trackerStyle', default='questie', label='Görünüm', list={{'questie', 'Questie'}, {'kutu', 'Kutulu'}, {'seffaf', 'Kutulu, şeffaf'}}},
 {type='choice', key='c_objColor', default='beyaz', label='Hedef rengi', list={{'beyaz', 'Beyaz>Yeşil'}, {'kirmizi', 'Kırmızı>Yeşil'}, {'sade', 'Beyaz'}}},
 {type='choice', key='c_sessionGoal', default='yok', label='Oturum hedefi', list={{'yok', 'Yok'}, {'yarim', 'Yarım sv'}, {'bir', '1 seviye'}, {'iki', '2 seviye'}}},
 {type='choice', key='c_trackerDensity', default='normal', label='Satır sıklığı', list={{'sikisik', 'Sıkışık'}, {'normal', 'Normal'}, {'ferah', 'Ferah'}}},
 {type='header', text='Boyut'},
 {type='slider', key='trackerScale', label='Görev kutusu boyutu', min=0.7, max=1.5, step=0.05},
 {type='slider', key='trackerFont', label='Görev kutusu yazı boyutu', min=10, max=18, step=1},
}


----------------------------------------------------------------------
-- Questie ayar düzeni: Genel, Simgeler, Takip, Harita, İsim plakası, Otomatik, Profiller, Gelişmiş
-- Her sayfa kaydırılabilir; bölüm başlıkları, onay kutuları, kaydırıcılar ve seçimler
----------------------------------------------------------------------
local function C(key, label, tip, apply) return {type='check', key=key, label=label, tip=tip, apply=apply} end
local function H(text) return {type='header', text=text} end
local function S(key, label, min, max, step) return {type='slider', key=key, label=label, min=min, max=max, step=step} end
local function bump() if FT.BumpLayers then FT.BumpLayers() end end

FT.QuestiePageDefs = {
 q_genel = {
  H('Genel'),
  C('sound', 'Sesler (hedef ve görev tamamlanınca)'),
  C('announce', 'İlerlemeyi gruba duyur'),
  C('groupsync', 'Grup üyelerinin görev ilerlemesi'),
  C('showLow', 'Düşük seviyeli (gri) görevleri göster', nil, bump),
  C('reader', 'Türkçe görev okuma penceresi'),
  C('learn', 'Oynarken görev verisi topla'),
  H('Rehber ve ok'),
  C('arrow', 'Yön oku', nil, function() if FT.UpdateArrow then FT.UpdateArrow() end end),
  C('minimap', 'Mini haritada hedef işareti'),
  C('auto', 'Otomatik ilerle'),
  C('autonext', 'Sürekli rota: hedef bitince sıradakine geç'),
  C('retarget', 'Hedefi konumuma göre güncelle'),
  H('Danışmanlar'),
  C('dropadvisor', 'Görev günlüğü dolunca bırakılacak görevi öner'),
  C('zonefit', 'Bölgeye girince "bana uygun mu?" göstergesi'),
  C('sessionsummary', 'Girişte son oturum özeti'),
  C('ctxauto', 'Savaşta ve zindanda gereksiz kutuları gizle'),
 },
 q_simge = {
  H('Simgeler'),
  C('givers', 'Simgeleri etkinleştir (! ve ?)', nil, bump),
  {type='choice', key='c_iconStyle', default='questie', label='Hedef simge teması', list={{'questie', 'Questie'}, {'sade', 'Sade'}, {'renkli', 'Renkli'}}},
  H('Şunlar için simge göster'),
  C('giversDone', 'Tamamlanan görevler (?)', nil, bump),
  C('qRepeat', 'Tekrarlanabilir görevler', nil, bump),
  C('qEvent', 'Etkinlik görevleri', nil, bump),
  C('qPvP', 'PvP görevleri', nil, bump),
  C('qDungeon', 'Zindan görevleri', nil, bump),
  C('qRaid', 'Baskın görevleri', nil, bump),
  C('objareas', 'Görev hedefleri', nil, bump),
  H('Diğer simgeler'),
  C('townsfolk', 'Kasaba (tamirci, han, uçuş, banka, posta, sınıf eğitmeni)', nil, bump),
  C('townprof', 'Meslek eğitmenleri', nil, bump),
  C('stations', 'Meslek istasyonları', nil, bump),
  C('nodes', 'Meslek düğümleri (maden, bitki)', nil, bump),
  C('dungeonicons', 'Zindan girişleri', nil, bump),
  C('raremap', 'Nadir yaratıklar', nil, bump),
  H('Harita simgeleri'),
  C('iconglow', 'Harita simgesi parıltısı', nil, bump),
  C('hideContinent', 'Kıta haritasında simgeleri gizle', nil, bump),
  C('focusbig', 'Odak görevin simgelerini büyüt', nil, bump),
  C('qareas', 'Görev bölgesi alanlarını çiz', nil, bump),
  C('heatmap', 'Yoğun yerler daha koyu', nil, bump),
  H('Mini harita simgeleri'),
  C('mmfade', 'Uzak simgeleri soldur'),
  S('mmFadeStart', 'Soldurma başlangıcı', 0.2, 1, 0.05),
  C('mmedge', 'Kenarda uzak hedeflere ok'),
  H('Simge boyutları'),
  S('mapIcons', 'Harita simgeleri', 0.6, 1.8, 0.05), S('mmIcons', 'Mini harita simgeleri', 0.6, 1.8, 0.05),
  S('iconGiver', 'Görev simgeleri', 0.5, 2, 0.05), S('iconKill', 'Öldürme hedefleri', 0.5, 2, 0.05),
  S('iconLoot', 'Toplama hedefleri', 0.5, 2, 0.05), S('iconObject', 'Nesne hedefleri', 0.5, 2, 0.05),
 },
 q_takip = {
  H('Takip'),
  C('tracker', 'Görev takibini etkinleştir', nil, function(v) if FT.tracker then if v then FT.tracker:Show() else FT.tracker:Hide() end end end),
  C('availbox', 'Solda alınabilir görevler kutusu'),
  {type='choice', key='c_trackerStyle', default='questie', label='Görünüm', list={{'questie', 'Questie'}, {'kutu', 'Kutulu'}, {'seffaf', 'Şeffaf'}}},
  {type='choice', key='c_trackerSort', default='bolge', label='Sıralama', list={{'bolge', 'Bölge'}, {'durum', 'Durum'}, {'yakin', 'Yakınlık'}, {'seviye', 'Seviye'}, {'yuzde', '% bitmiş'}}},
  {type='choice', key='c_trackerView', default='detay', label='Gösterim', list={{'detay', 'Ayrıntılı'}, {'liste', 'Liste'}, {'tablo', 'Tablo'}}},
  {type='choice', key='c_trackerMax', default='12', label='Görev sayısı', list={{'6', '6'}, {'8', '8'}, {'12', '12'}, {'20', '20'}}},
  C('trkColDist', 'Tablo görünümünde mesafe sütunu'),
  H('Alınabilir görevler kutusu'),
  {type='choice', key='c_availView', default='kart', label='Gösterim', list={{'kart', 'Kart'}, {'liste', 'Liste'}, {'tablo', 'Tablo'}}},
  {type='choice', key='c_availSort', default='yakin', label='Sıralama', list={{'yakin', 'Yakınlık'}, {'seviye', 'Seviye'}, {'ad', 'Ad'}}},
  {type='choice', key='c_availMax', default='7', label='Görev sayısı', list={{'5', '5'}, {'7', '7'}, {'10', '10'}, {'15', '15'}}},
  C('availShowGiver', 'Kart görünümünde görev vereni'),
  C('availHideLow', 'Düşük seviyeli (gri) görevleri gizle'),
  H('Görevler'),
  C('trkdiff', 'Görev seviyesini göster'),
  C('trkAutoMin', 'Tamamlanan görevleri otomatik küçült'),
  C('trkzones', 'Bölge başlıkları'),
  C('trkitems', 'Görev eşyası düğmeleri'),
  C('questitem', 'Ok altında görev eşyası düğmesi'),
  H('Hedefler'),
  C('trkHideDoneObj', 'Tamamlanan hedefleri gizle'),
  {type='choice', key='c_objColor', default='beyaz', label='Hedef rengi', list={{'sade', 'Beyaz'}, {'beyaz', 'Beyaz > yeşil'}, {'kirmizi', 'Kırmızı > yeşil'}}},
  C('trkfx', 'İlerleyince +1 efekti'),
  C('trkring', 'Yüzde halkası (Kutulu görünümde)'),
  H('Davranış'),
  C('trkCombat', 'Savaşta küçült'),
  C('trkInstance', 'Zindanda küçült'),
  {type='choice', key='c_trackerDensity', default='normal', label='Satır sıklığı', list={{'sikisik', 'Sıkışık'}, {'normal', 'Normal'}, {'ferah', 'Ferah'}}},
  {type='choice', key='c_sessionGoal', default='yok', label='Oturum hedefi', list={{'yok', 'Yok'}, {'yarim', 'Yarım'}, {'bir', '1 sv'}, {'iki', '2 sv'}}},
  H('Boyut'),
  S('trackerScale', 'Görev kutusu boyutu', 0.7, 1.5, 0.05), S('trackerFont', 'Yazı boyutu', 10, 18, 1),
 },
 q_harita = {
  H('Rota ve yol noktaları'),
  C('routenums', 'Rota numaraları ve süre', nil, bump),
  C('partyfirst', 'Grupla ortak görevler önce'),
  C('npcpaths', 'Gezgin NPC yolları', nil, bump),
  C('partymap', 'Grubun görevleri haritada', nil, bump),
  C('mapRoute', 'Haritada "Yol sor" paneli', nil, function(v) if FT.mapRoute and not v then FT.mapRoute:Hide() end end),
  C('mapmove', 'Dünya haritasını taşı (üst kenardan sürükle)'),
  C('raremodel', 'Nadir yaratık üzerine gelince 3B görsel'),
  H('Yolculuk'),
  C('flightplan', 'Uçuş rotası öner'),
  C('flightadvice', 'Hedef uzaksa uçuş öner'),
  C('travel', 'Kıtalar arası yol tarifi'),
  C('flighttimes', 'Uçuşta kalan süre çubuğu'),
  C('flightalert', 'Uçuş noktası uyarıları'),
  C('hearth', 'Ocak taşı danışmanı'),
  C('corpse', 'Ölünce cesede yol göster'),
  C('deathadvice', 'Ölünce: cesede koş mu, ruh iyileştirici mi?'),
  C('beep', 'Hedefe yaklaşınca bip sesi'),
 },
 q_plaka = {
  H('İsim plakası'),
  C('plateicons', 'Görev yaratıklarında simge ve sayaç'),
  C('plateItemIcon', 'Eşya görevlerinde yaratığın üstünde istenen eşyanın resmi'),
  C('platecolor', 'Can barı görev renginde'),
  C('creaturewarn', 'Hedeflenen görev yaratığı uyarısı'),
  C('creaturenear', 'Yakından geçen görev yaratığı uyarısı'),
  C('raidmarks', 'Görev NPC / yaratıklarına işaret koy', 'Bazı istemcilerde "engellendi" uyarısı verir.'),
  H('Simge'),
  S('plate', 'Simge boyutu', 0.6, 1.8, 0.05), S('plateX', 'Yatay konum', -40, 40, 1),
  S('plateY', 'Dikey konum', -30, 30, 1),
 },
 q_oto = {
  H('Görevler'),
  C('autoquest', 'Görevleri otomatik al / teslim et (Shift: dur)'),
  C('autoreward', 'Önerilen ödülü otomatik seç'),
  C('breadcrumbs', 'Yol açan görevleri otomatik bırak'),
  H('Çanta ve satıcı'),
  C('autoloot', 'Otomatik toplama'),
  C('autosell', 'Satıcıda çöp eşyaları sat'),
  C('autorepair', 'Satıcıda otomatik tamir'),
  C('questItemGuard', 'Görev eşyalarını koru (satılmaz; satılırsa geri alınır) — liste: /ftrail gorevesya'),
  C('goldmark', 'Satılacak eşyalara altın işareti'),
  C('bagwarn', 'Çanta doluluk uyarısı'),
  C('banksort', 'Banka açılınca otomatik düzenle'),
  C('itemquests', 'Eşya ipucunda görev bilgisi'),
  C('compare', 'Eşya karşılaştırma ipucu'),
  H('Sosyal'),
  C('autosummon', 'Grup çağrısını otomatik kabul et'),
  C('autorez', 'Dirilmeyi otomatik kabul et'),
  C('blockduels', 'Lonca dışından düelloları engelle'),
  H('Kamera'),
  C('maxcamera', 'Kamerayı daha uzağa çekebil', nil, function() if FT.ApplyCamera then FT.ApplyCamera() end end),
  C('noglow', 'Ekran parlamasını kapat', nil, function() if FT.ApplyCamera then FT.ApplyCamera() end end),
 },
 q_profil = {
  H('Kullanım düzeyi: Sade / Standart / Tam'),
  {type='buttons', list={
   {'Sade', function() FT.ApplyUsageLevel('sade') end},
   {'Standart', function() FT.ApplyUsageLevel('standart') end},
   {'Tam', function() FT.ApplyUsageLevel('tam') end},
  }},
  H('Profiller'),
  {type='buttons', list={{'Profiller', function() FT.ToggleProfiles() end}, {'Ayarları aktar', function() FT.ToggleTransfer() end}}},
  H('Yedekler'),
  {type='buttons', list={{'Ayar yedekleri', function() FT.ShowBackups() end}, {'Şimdi yedekle', function() FT.BackupNow() end}}},
 },
 q_gelismis = {
  H('Gelişmiş'),
  C('globalfonts', 'Oyunun yazılarında Türkçe harfler (WoWTR, /reload)'),
  C('optstyle', 'Ayarlar Questie penceresinde açılsın (/reload)', nil, function(v) ForeverTrailSettings.c_optionsStyle = v and 'questie' or 'ft' end),
  H('Araçlar'),
  {type='buttons', list={
   {'Uyumluluk testi', function() FT.SelfTest() end}, {'Hata kaydı', function() FT.PrintErrors() end}, {'Kurulum sihirbazı', function() FT.ShowSetupWizard() end},
   {'Düzen modu', function() FT.ToggleEditMode() end}, {'Konumları sıfırla', function() FT.ResetLayout() end}, {'Sessiz mod', function() FT.ToggleSilent() end},
  }},
 },
}

function FT.BuildQuestiePages(frame, width)
 for key, defs in pairs(FT.QuestiePageDefs) do
  local page = frame.pages[key]
  if page and not page.ftBuilt then
   page.ftBuilt = true
   local scroll = (FT.Kit and FT.Kit.Scroll(page) or CreateFrame('ScrollFrame', nil, page, 'UIPanelScrollFrameTemplate'))
   scroll:SetPoint('TOPLEFT', 0, 0); scroll:SetPoint('BOTTOMRIGHT', -24, 0)
   local child = CreateFrame('Frame', nil, scroll)
   child:SetSize(width - 26, 10)
   scroll:SetScrollChild(child)
   local endY = FT.BuildOptions(child, -4, width - 30, defs) or -400
   child:SetHeight(-endY + 16)
   page.scroll, page.child = scroll, child
  end
 end
end

-- Questie penceresi ve Blizzard ayar paneli için dışa açılanlar
FT.GetSetting = get
FT.SettingsItems = items
FT.SettingsAfterChange = function() pcall(afterChange) end


----------------------------------------------------------------------
-- Gezinme: alt sekmeler ve arama
----------------------------------------------------------------------
local FOLD = {['\195\167']='c', ['\195\135']='c', ['\196\159']='g', ['\196\158']='g', ['\196\177']='i', ['\196\176']='i',
 ['\195\182']='o', ['\195\150']='o', ['\197\159']='s', ['\197\158']='s', ['\195\188']='u', ['\195\156']='u'}
-- Türkçe harfleri sadeleştirip küçültür: "Görev" araması "gorev" yazınca da bulunur
local function fold(text)
 text = tostring(text or '')
 for from, to in pairs(FOLD) do text = text:gsub(from, to) end
 return text:lower()
end
FT.FoldText = fold

local searchIndex
local function buildSearchIndex()
 searchIndex = {}
 local seen = {}
 local function add(label, pk, section)
  if not label or label == '' or not PAGE_BY_KEY[pk] then return end
  local id = pk .. '|' .. label
  if seen[id] then return end
  seen[id] = true
  local g, page = GROUP_OF_PAGE[pk], PAGE_BY_KEY[pk]
  searchIndex[#searchIndex + 1] = {label = label, page = pk, section = section or '', path = g.label .. ' > ' .. page.label,
   name = fold(label), hay = fold(label .. ' ' .. (section or '') .. ' ' .. g.label .. ' ' .. page.label)}
 end
 for _, page in ipairs(PAGES) do
  local defs = FT.QuestiePageDefs and FT.QuestiePageDefs[page.key]
  if defs then
   local section = ''
   for _, d in ipairs(defs) do
    if d.type == 'header' then section = d.text
    elseif d.type == 'buttons' then for _, it in ipairs(d.list) do add(it[1], page.key, section) end
    else add(d.label, page.key, section) end
   end
  end
 end
 for _, it in ipairs(items) do if PAGE_BY_KEY[it.tab] then add(it.label, it.tab) end end
 for _, sl in ipairs(SLIDERS) do add(sl.label, 'ozel') end
 for _, label in ipairs({'Yön oku boyutu', 'Görev kutusu saydamlığı', 'Arayüz ölçeği', 'Renk teması', 'Yazı tipi', 'Konumları sıfırla', 'Kilit aç/kapat', 'Ayarları aktar'}) do
  add(label, 'gorunum')
 end
end

-- Arama: sözcüklerin hepsi ad, bölüm ya da sayfa adında geçmeli; ada uyanlar önce gelir.
local MAX_RESULTS = 14
function FT.SettingsSearch(query)
 if not searchIndex then buildSearchIndex() end
 local words = {}
 for w in fold(query):gmatch('%S+') do words[#words + 1] = w end
 local out = {}
 if #words == 0 then return out end
 for order, e in ipairs(searchIndex) do
  local score = 0
  for _, w in ipairs(words) do
   if e.name:find(w, 1, true) then score = score + 2
   elseif e.hay:find(w, 1, true) then score = score + 1
   else score = nil; break end
  end
  if score then out[#out + 1] = {entry = e, score = score, order = order} end
 end
 table.sort(out, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.order < b.order end)
 local list = {}
 for i = 1, math.min(#out, MAX_RESULTS) do list[i] = out[i].entry end
 return list, #out
end

local function showSearch(query)
 local list, total = FT.SettingsSearch(query)
 for k, page in pairs(frame.pages) do
  page:SetShown(k == 'zz_search')
  if page.holder then page.holder:Hide() end
 end
 for _, bar in pairs(frame.subBars or {}) do for _, b in ipairs(bar) do b:Hide() end end
 paintNav(nil)
 local a = FT.Style.accent
 frame.pageTitle:SetText('Arama'); frame.pageTitle:SetTextColor(a[1], a[2], a[3])
 frame.pageDesc:SetText(#list == 0 and 'Sonuç yok. Başka bir sözcük dene.' or ('%d sonuç. Birine tıklayınca ayarın sayfası açılır.'):format(total or #list))
 local res = frame.pages.zz_search
 for i, row in ipairs(res.rows) do
  local e = list[i]
  if e then
   row.entry = e; row.name:SetText(e.label); row.path:SetText(e.path); row:Show()
  else row.entry = nil; row:Hide() end
 end
end

function FT.BuildSettingsNav(f)
 f.subBars = {}
 for _, g in ipairs(GROUPS) do
  if #g.pages > 1 then
   local bar = {}
   for i, pk in ipairs(g.pages) do
    local b = FT.NewButton(f, PAGE_BY_KEY[pk].label, 112, 18)
    b:SetPoint('TOPLEFT', f.pageTitle, 'BOTTOMLEFT', (i - 1) * 116, -4)
    applyFont(b:GetFontString())
    b.pageKey = pk
    b:SetScript('OnClick', function() FT.SettingsTab(pk) end)
    b:Hide()
    bar[i] = b
   end
   f.subBars[g.key] = bar
  end
 end
 -- arama kutusu
 local box = (FT.Kit and FT.Kit.Input(f) or CreateFrame('EditBox', nil, f, 'InputBoxTemplate'))
 box:SetSize(150, 20); box:SetPoint('TOPRIGHT', f, 'TOPRIGHT', -36, -32); box:SetAutoFocus(false)
 if box.SetMaxLetters then box:SetMaxLetters(40) end
 local hint = box:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
 hint:SetPoint('LEFT', box, 'LEFT', 4, 0); hint:SetText('Ayarlarda ara...'); applyFont(hint)
 box:SetScript('OnTextChanged', function(self)
  if f.searchQuiet then return end
  local q = self:GetText() or ''
  hint:SetShown(q == '')
  if q:match('%S') then showSearch(q) else FT.SettingsTab(f.current or 'q_genel') end
 end)
 box:SetScript('OnEscapePressed', function(self) self:SetText(''); self:ClearFocus() end)
 box:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
 f.searchBox, f.searchHint = box, hint
 -- sonuç sayfası
 local res = CreateFrame('Frame', nil, f)
 res:SetPoint('TOPLEFT', SIDEW + 12, -80); res:SetPoint('BOTTOMRIGHT', -12, 10)
 res:Hide()
 res.rows = {}
 for i = 1, MAX_RESULTS do
  local row = CreateFrame('Button', nil, res)
  row:SetSize(CW, 26); row:SetPoint('TOPLEFT', 0, -(i - 1) * 28)
  row:SetHighlightTexture('Interface\Buttons\WHITE8X8'); row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
  row.name = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  row.name:SetPoint('LEFT', 6, 6); row.name:SetWidth(CW - 12); row.name:SetJustifyH('LEFT'); applyFont(row.name)
  row.path = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  row.path:SetPoint('LEFT', 6, -7); row.path:SetWidth(CW - 12); row.path:SetJustifyH('LEFT'); applyFont(row.path)
  row.path:SetTextColor(0.62, 0.6, 0.55)
  row:SetScript('OnClick', function(self) if self.entry then FT.SettingsTab(self.entry.page) end end)
  row:Hide()
  res.rows[i] = row
 end
 f.pages.zz_search = res
end
