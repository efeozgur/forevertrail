local _, FT = ...

-- "Görevler" (takip kutusu) ve "Alınabilir" pencerelerine küçük "Ayar" düğmesi ve görünüm ayarları penceresi.
-- Biçim: Ayrıntılı / Liste / Tablo (görev kutusu), Kart / Liste / Tablo (alınabilir kutusu).
-- Tüm anahtarlar Settings.lua'daki seçeneklerle ortaktır; bu pencere yalnızca hızlı erişimdir.

local WIDTH = 420
local DEFS = {}

DEFS.tracker = {
 title = 'Görevler: görünüm ayarları',
 opts = {
  {type = 'header', text = 'Biçim'},
  {type = 'choice', key = 'c_trackerView', default = 'detay', label = 'Gösterim', list = {{'detay', 'Ayrıntılı'}, {'liste', 'Liste'}, {'tablo', 'Tablo'}}},
  {type = 'choice', key = 'c_trackerMax', default = '12', label = 'Görev sayısı', list = {{'6', '6'}, {'8', '8'}, {'12', '12'}, {'20', '20'}}},
  {type = 'choice', key = 'c_trackerSort', default = 'durum', label = 'Sıralama', list = {{'durum', 'Durum'}, {'bolge', 'Bölge'}, {'yakin', 'Yakınlık'}, {'seviye', 'Seviye'}, {'yuzde', '% bitmiş'}}},
  {type = 'choice', key = 'c_trackerDensity', default = 'normal', label = 'Satır sıklığı', list = {{'sikisik', 'Sıkışık'}, {'normal', 'Normal'}, {'ferah', 'Ferah'}}},
  {type = 'header', text = 'Neler görünsün'},
  {type = 'check', key = 'trkzones', label = 'Bölge başlıkları'},
  {type = 'check', key = 'trkdiff', label = 'Görev seviyesi ve zorluk rengi'},
  {type = 'check', key = 'trkShowDone', label = 'Tamamlanan görevler'},
  {type = 'check', key = 'trkHideDoneObj', label = 'Tamamlanan hedefleri gizle (Ayrıntılı)'},
  {type = 'check', key = 'trkColDist', label = 'Mesafe sütunu (Tablo)'},
 },
}

DEFS.avail = {
 title = 'Alınabilir görevler: görünüm ayarları',
 opts = {
  {type = 'header', text = 'Biçim'},
  {type = 'choice', key = 'c_availView', default = 'kart', label = 'Gösterim', list = {{'kart', 'Kart'}, {'liste', 'Liste'}, {'tablo', 'Tablo'}}},
  {type = 'choice', key = 'c_availMax', default = '7', label = 'Görev sayısı', list = {{'5', '5'}, {'7', '7'}, {'10', '10'}, {'15', '15'}}},
  {type = 'choice', key = 'c_availSort', default = 'yakin', label = 'Sıralama', list = {{'yakin', 'Yakınlık'}, {'seviye', 'Seviye'}, {'ad', 'Ad'}}},
  {type = 'header', text = 'Neler görünsün'},
  {type = 'check', key = 'availShowGiver', label = 'Görev vereni (Kart görünümünde)'},
  {type = 'check', key = 'availHideLow', label = 'Düşük seviyeli (gri) görevleri gizle'},
  {type = 'check', key = 'availbox', label = 'Alınabilir görevler kutusunu göster', apply = function() if FT.RefreshAvailableBox then FT.RefreshAvailableBox() end end},
 },
}

-- "Varsayılana dön": bu pencerenin anahtarlarını temizler
local function resetDefaults(kind)
 for _, d in ipairs(DEFS[kind].opts) do
  if d.type == 'choice' then ForeverTrailSettings[d.key] = nil
  elseif d.type == 'check' and d.key ~= 'availbox' then ForeverTrailSettings[d.key] = nil end
 end
 if FT.RefreshTracker then pcall(FT.RefreshTracker) end
 if FT.RefreshAvailableBox then pcall(FT.RefreshAvailableBox) end
 if FT.RefreshOptions then pcall(FT.RefreshOptions) end
end

local popups = {}

local function build(kind)
 local def = DEFS[kind]
 local f = FT.NewWindow('ForeverTrail' .. kind .. 'ViewOptions', UIParent)
 f:SetFrameStrata('DIALOG'); f:SetClampedToScreen(true)
 local title = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 title:SetPoint('TOPLEFT', 14, -10); title:SetText(def.title)
 if FT.StyleTitle then FT.StyleTitle(title) end
 local page = CreateFrame('Frame', nil, f)
 page:SetPoint('TOPLEFT', 14, -34); page:SetSize(WIDTH - 28, 10)
 local y = FT.BuildOptions(page, -2, WIDTH - 28, def.opts) or -200
 f:SetSize(WIDTH, math.max(160, -y + 84))
 local all = FT.NewButton(f, 'Tüm ayarlar', 104, 22); all:SetPoint('BOTTOMLEFT', 14, 12)
 all:SetScript('OnClick', function() if FT.ToggleSettings then FT.ToggleSettings() end end)
 local reset = FT.NewButton(f, 'Varsayılan', 96, 22); reset:SetPoint('LEFT', all, 'RIGHT', 6, 0)
 reset:SetScript('OnClick', function() resetDefaults(kind) end)
 local close = FT.NewButton(f, 'Kapat', 80, 22); close:SetPoint('BOTTOMRIGHT', -14, 12)
 close:SetScript('OnClick', function() f:Hide() end)
 if FT.FixFonts then pcall(FT.FixFonts, f) end
 f:Hide()
 return f
end

function FT.ToggleViewOptions(kind)
 local ref = kind == 'tracker' and FT.tracker or FT.availableBox
 if not (DEFS[kind] and ref and FT.BuildOptions and FT.NewWindow) then return end
 local f = popups[kind]
 if not f then
  local ok, made = pcall(build, kind)
  if not ok then FT.Print('Görünüm ayarları açılamadı: ' .. tostring(made)); return end
  f = made; popups[kind] = f
 end
 if f:IsShown() then f:Hide(); return end
 f:ClearAllPoints()
 if kind == 'tracker' then f:SetPoint('TOPRIGHT', ref, 'TOPLEFT', -6, 0) else f:SetPoint('TOPLEFT', ref, 'TOPRIGHT', 6, 0) end
 f:Show()
 if FT.RefreshOptions then pcall(FT.RefreshOptions) end
end

-- Pencerelerin başlık çubuğuna küçük "Ayar" düğmesi (+/- düğmesinin solu)
local function attach(frame, kind)
 if not frame or frame.viewGear then return end
 local b = FT.NewButton and FT.NewButton(frame, 'Ayar', 36, 18)
 if not b then b = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate'); b:SetSize(36, 18); b:SetText('Ayar') end
 b:SetPoint('TOPRIGHT', -32, -8)
 b:SetScript('OnClick', function() FT.ToggleViewOptions(kind) end)
 b:HookScript('OnEnter', function(self)
  if frame.hovering ~= nil then frame.hovering = true end
  if GameTooltip then
   GameTooltip:SetOwner(self, 'ANCHOR_BOTTOM'); GameTooltip:SetText('Görünüm ayarları', 1, 0.82, 0)
   GameTooltip:AddLine('Liste, tablo ve kart biçimi, sıralama ve görev sayısı.', 0.9, 0.9, 0.9, true)
   GameTooltip:Show()
  end
 end)
 b:HookScript('OnLeave', function() if GameTooltip then GameTooltip:Hide() end end)
 if FT.FixFonts then pcall(FT.FixFonts, b) end
 frame.viewGear = b
end

local function attachAll()
 attach(FT.tracker, 'tracker')
 attach(FT.availableBox, 'avail')
end
FT.AttachViewGears = attachAll

local ev = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD'}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript('OnEvent', function()
 attachAll()
 if C_Timer and C_Timer.After then C_Timer.After(1, attachAll); C_Timer.After(4, attachAll) end
end)
