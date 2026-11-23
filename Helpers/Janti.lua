local _, FT = ...

-- Janti: giriş, çöp satma, ölüm ve eşya giymede şaka mesajı. Ekranın ortasında büyük sarı yazı (boss uyarısı gibi),
-- 3 sn görünür, yavaşça kaybolur; yenisi eskisinin yerine geçer. Yalnızca sen görürsün.
-- /janti off  /janti on

local LINES = {
 login = {
  'Oo sen mi geldin toprağım, gözüm yollarda kaldı!',
  'O nasıl bi geliş, aklımız gitti!',
  'Oğlum bu ne hız, ışık hızını geçtin, hoş geldin!',
  'Gel bakalım şampiyon, dünya seni bekliyordu, bir de kahve.',
  'Yine mi sen? Peki, o zaman hepimiz hazırlanalım.',
  'Bu şehre yeni bir kral geldi, tacı yok ama ayağı var.',
 },
 sell = {
  'Yarenler, bu hurda değil, antika! Fiyatı da aynı, hurda.',
  'Çöpü pazarladık, ticaretin piri de bizmişiz.',
  'Üç kuruş eder ama biz yine de gurur duyuyoruz.',
  'Tüccar şaşırdı, biz ağladık, kader bu.',
  'Bu paraya ancak bir poğaça alınır, o da yarım.',
  'Çantayı boşalttın, şimdi sıra egoyu boşaltmada.',
 },
 death = {
  'Çöp mü takılı üstünde?',
  'Ula oğlum, ölüyorsan bari haber ver!',
  'Yatma kalk, dizi bitmedi daha!',
  'Kafa kafaya girdin, kafa kazandı.',
  'Öldün mü? Bak sen şu işe, hayret!',
  "Boss'a diyorum ki, bi dur lan, adam yeni geldi.",
 },
 equip = {
  'Bu ne şıklık be, düğüne mi, cenazeye mi?',
  'Yeni eşyayla yeni sen, ama aynı akıl.',
  'Giyindin kuşandın, savaşa mı gidiyon, pazara mı?',
  'Bu kombinle ancak film çekilir, o da komedi.',
  'Şapkayı taktın, ciddiyet seviyesi: %3.',
  'Hele bi dön bakalım, olmuş mu, olmamış mı… olmamış.',
 },
}
FT.JantiLines = LINES

local COOLDOWN = {sell = 5, equip = 5}
local lastIndex, lastTime = {}, {}
local loginTime = nil
local merchantOpen, lastMoney = false, nil

local function enabled() return not ForeverTrailSettings or ForeverTrailSettings.janti ~= false end
local function now() return GetTime and GetTime() or 0 end

-- Ekran yazısı: kendi çerçevemiz (Türkçe harfler bozulmasın diye)
local banner
local SHOW, FADE = 3, 1.5
local function ensureBanner()
 if banner then return banner end
 banner = CreateFrame('Frame', 'ForeverTrailJanti', UIParent)
 banner:SetSize(900, 60)
 banner:SetPoint('CENTER', UIParent, 'CENTER', 0, 170)
 banner:SetFrameStrata('HIGH')
 banner.text = banner:CreateFontString(nil, 'OVERLAY')
 local path = FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF'
 if banner.text:SetFont(path, 28, 'THICKOUTLINE') == false then banner.text:SetFont('Fonts\\ARIALN.TTF', 28, 'THICKOUTLINE') end
 banner.text:SetShadowOffset(2, -2); banner.text:SetShadowColor(0, 0, 0, 1)
 banner.text:SetPoint('CENTER'); banner.text:SetWidth(880); banner.text:SetJustifyH('CENTER')
 banner.text:SetTextColor(1, 0.86, 0.1)
 banner:SetScript('OnUpdate', function(self, dt)
  self.t = (self.t or 0) + dt
  if self.t <= SHOW then self:SetAlpha(1)
  elseif self.t <= SHOW + FADE then self:SetAlpha(1 - (self.t - SHOW) / FADE)
  else self:Hide() end
 end)
 banner:Hide()
 return banner
end

local function show(text)
 local b = ensureBanner()
 b.text:SetText(text)
 b.t = 0
 b:SetAlpha(1)
 b:Show()
end
FT.JantiShow = show

local COMBAT_GAP = 20
local lastAny = nil
local function inCombat() return (UnitAffectingCombat and UnitAffectingCombat('player')) or (InCombatLockdown and InCombatLockdown()) end

local function say(kind)
 if not enabled() then return end
 local list = LINES[kind]
 if not list then return end
 local t = now()
 if COOLDOWN[kind] and lastTime[kind] and t - lastTime[kind] < COOLDOWN[kind] then return end
 if kind ~= 'death' and inCombat() and lastAny and t - lastAny < COMBAT_GAP then return end
 local i = math.random(#list)
 if #list > 1 and i == lastIndex[kind] then i = i % #list + 1 end
 lastIndex[kind], lastTime[kind], lastAny = i, t, t
 show(list[i])
 return list[i]
end
FT.JantiSay = say

local ev = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_LOGIN', 'PLAYER_DEAD', 'PLAYER_EQUIPMENT_CHANGED', 'MERCHANT_SHOW', 'MERCHANT_CLOSED', 'PLAYER_MONEY'}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript('OnEvent', function(_, event)
 local ok, err = pcall(function()
  if event == 'PLAYER_LOGIN' then
   loginTime = now()
   lastMoney = GetMoney and GetMoney() or 0
   say('login')
  elseif event == 'PLAYER_DEAD' then
   say('death')
  elseif event == 'PLAYER_EQUIPMENT_CHANGED' then
   if loginTime and now() - loginTime >= 5 then say('equip') end
  elseif event == 'MERCHANT_SHOW' then
   merchantOpen = true
   lastMoney = GetMoney and GetMoney() or 0
  elseif event == 'MERCHANT_CLOSED' then
   merchantOpen = false
  elseif event == 'PLAYER_MONEY' then
   local money = GetMoney and GetMoney() or 0
   if merchantOpen and lastMoney and money > lastMoney then say('sell') end
   lastMoney = money
  end
 end)
 if not ok and FT.errors and #FT.errors < 20 then FT.errors[#FT.errors + 1] = 'janti: ' .. tostring(err) end
end)

SLASH_FORVERTRAILJANTI1 = '/janti'
SlashCmdList.FORVERTRAILJANTI = function(msg)
 ForeverTrailSettings = ForeverTrailSettings or {}
 msg = (msg or ''):lower():gsub('%s+', '')
 if msg == 'off' then ForeverTrailSettings.janti = false
 elseif msg == 'on' then ForeverTrailSettings.janti = true end
 local state = enabled() and 'açık' or 'kapalı'
 if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffff9a3c[Janti]|r şakalar ' .. state .. '. (/janti on, /janti off)') end
end
