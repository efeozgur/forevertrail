local _, FT = ...

-- İlk girişte resimli kurulum (Questie'deki gibi): her adımda önizlemeli kartlar, tıkla seç.
-- 1) Ok ve rota  2) Yetenek puanları  3) Eşya  4) Renk teması  5) Çanta ve satıcı

local BLOB = 'Interface\\CHARACTERFRAME\\TempPortraitAlphaMask'
local M = 'Interface\\AddOns\\ForeverTrail\\Media\\'
local W, H, CARD_W, CARD_H = 580, 400, 170, 170
local win, current
local S = function() return ForeverTrailSettings end

local function font(fs, size, flags)
 if fs:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', size, flags or '') == false then fs:SetFont('Fonts\\ARIALN.TTF', size, flags or '') end
 fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.9)
end
local function tex(parent, layer, path)
 local t = parent:CreateTexture(nil, layer or 'ARTWORK')
 if path then t:SetTexture(path) else t:SetColorTexture(1, 1, 1, 1) end
 return t
end
local function text(parent, size, flags)
 local fs = parent:CreateFontString(nil, 'OVERLAY'); font(fs, size, flags); return fs
end

----------------------------------------------------------------------
-- Önizleme çizimleri
----------------------------------------------------------------------
local function drawObjectives(p, style, areaAlpha)
 local bg = tex(p, 'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(0.2, 0.26, 0.15, 1)
 local spots = {{0.32, 0.38, 1}, {0.7, 0.6, 2}, {0.45, 0.75, 3}}
 local kinds = {'kill', 'loot', 'object'}
 for i, sp in ipairs(spots) do
  local c = FT.QuestColor and FT.QuestColor(sp[3]) or {1, 0.8, 0.2}
  local area = tex(p, 'BORDER', BLOB); area:SetSize(70, 60)
  area:SetPoint('CENTER', p, 'TOPLEFT', sp[1] * CARD_W, -sp[2] * (CARD_H - 40))
  area:SetVertexColor(c[1], c[2], c[3], 0.3 * areaAlpha)
  local disc = tex(p, 'ARTWORK', BLOB); disc:SetSize(24, 24); disc:SetPoint('CENTER', area, 'CENTER')
  local icon = tex(p, 'OVERLAY'); icon:SetSize(18, 18); icon:SetPoint('CENTER', area, 'CENTER')
  if style == 'questie' and FT.QuestieIcons then
   icon:SetTexture(FT.QuestieIcons[kinds[i]]); disc:SetTexture(FT.QuestieMedia .. 'glow'); disc:SetVertexColor(c[1], c[2], c[3], 0.9)
  elseif style == 'sade' then
   icon:SetTexture(FT.MonoIcons and FT.MonoIcons[kinds[i]] or M .. 'slay_mono'); icon:SetVertexColor(c[1], c[2], c[3])
   disc:SetVertexColor(0, 0, 0, 0.55)
  else
   icon:SetTexture(FT.ColorIcons and FT.ColorIcons[kinds[i]] or 'Interface\\Icons\\INV_Sword_04'); icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
   disc:SetVertexColor(c[1], c[2], c[3], 0.9)
  end
 end
 local giver = tex(p, 'OVERLAY', (style == 'questie' and FT.QuestieMedia) and (FT.QuestieMedia .. 'available') or 'Interface\\GossipFrame\\AvailableQuestIcon'); giver:SetSize(16, 16)
 giver:SetPoint('CENTER', p, 'TOPLEFT', CARD_W * 0.82, -26)
end

local function drawLayout(p, mode)
 local bg = tex(p, 'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(0.12, 0.14, 0.18, 1)
 local a = FT.Style.accent
 local function box(x, y, w, h, alpha, label)
  local b = tex(p, 'ARTWORK'); b:SetSize(w, h); b:SetPoint('TOPLEFT', x, -y); b:SetColorTexture(a[1], a[2], a[3], alpha)
  if label then local t = text(p, 9, ''); t:SetPoint('CENTER', b, 'CENTER'); t:SetText(label); t:SetTextColor(1, 1, 1) end
 end
 box(CARD_W / 2 - 10, 8, 20, 12, 0.9, nil) -- ok
 local arrow = text(p, 9, ''); arrow:SetPoint('TOP', 0, -22); arrow:SetText('ok'); arrow:SetTextColor(0.8, 0.8, 0.8)
 if mode ~= 'ok' then box(CARD_W - 52, 34, 46, 70, 0.45, 'Görevler') end
 if mode == 'tam' then
  box(6, 34, 46, 56, 0.3, 'Alınabilir')
  box(6, CARD_H - 62, 70, 10, 0.6, nil)
  box(CARD_W / 2 - 30, CARD_H - 70, 60, 18, 0.25, 'Kart')
 end
end

local function drawTheme(p, key)
 local th = FT.Themes[key]
 local bg = tex(p, 'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(th.bg[1], th.bg[2], th.bg[3], 1)
 local border = tex(p, 'BORDER'); border:SetPoint('TOPLEFT', 10, -10); border:SetPoint('BOTTOMRIGHT', -10, 44)
 border:SetColorTexture(th.border[1], th.border[2], th.border[3], 0.9)
 local inner = tex(p, 'ARTWORK'); inner:SetPoint('TOPLEFT', 12, -12); inner:SetPoint('BOTTOMRIGHT', -12, 46)
 inner:SetColorTexture(th.bg[1], th.bg[2], th.bg[3], 1)
 local bar = tex(p, 'OVERLAY'); bar:SetHeight(2); bar:SetPoint('TOPLEFT', 16, -16); bar:SetPoint('TOPRIGHT', -16, -16)
 bar:SetColorTexture(th.accent[1], th.accent[2], th.accent[3], 1)
 local t = text(p, 12, 'OUTLINE'); t:SetPoint('TOPLEFT', 18, -24); t:SetText('Görevler'); t:SetTextColor(th.accent[1], th.accent[2], th.accent[3])
 local l = text(p, 10, ''); l:SetPoint('TOPLEFT', 22, -42); l:SetText('[5] Kurt avı  3/8'); l:SetTextColor(1, 0.94, 0.82)
end

local function drawList(p, lines)
 local bg = tex(p, 'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(0.12, 0.12, 0.14, 1)
 for i, l in ipairs(lines) do
  local mark = text(p, 12, 'OUTLINE'); mark:SetPoint('TOPLEFT', 12, -10 - (i - 1) * 22)
  mark:SetText(l[2] and '|cff55ff55+|r' or '|cffff5555-|r')
  local t = text(p, 11, ''); t:SetPoint('LEFT', mark, 'RIGHT', 6, 0); t:SetText(l[1]); t:SetTextColor(0.9, 0.88, 0.82)
 end
end

----------------------------------------------------------------------
-- Adımlar
----------------------------------------------------------------------
local AUTO = {'autosell', 'autorepair', 'autoloot'}
local function L(rows) return function(p) drawList(p, rows) end end
local STEPS = {
 {title = 'Nasıl kullanmak istersin?', hint = 'Tek tıkla başla. Ayrıntılar sonraki adımlarda; istemezsen Atla\'ya bas.', cards = {
  {label = 'Sade', draw = L({{'Yön oku ve görev kutusu', true}, {'Efektler (+1, görev afişi)', false}, {'Düğme çubuğu ve hedef kartı', false}, {'Nadir, tehlike ve bölge uyarıları', false}}),
   pick = function() FT.ApplyUsageLevel('sade') end, is = function() return S().usageLevel == 'sade' end},
  {label = 'Standart', draw = L({{'Yön oku ve görev kutusu', true}, {'Efektler (+1, görev afişi)', true}, {'Düğme çubuğu ve hedef kartı', true}, {'Nadir, tehlike ve bölge uyarıları', true}}),
   pick = function() FT.ApplyUsageLevel('standart') end, is = function() return S().usageLevel == nil or S().usageLevel == 'standart' end},
  {label = 'Tam', draw = L({{'Yön oku ve görev kutusu', true}, {'Her kutu ve çubuk açık', true}, {'Tüm uyarılar ve efektler', true}, {'Harita işaretleri (kasaba, nadir)', true}}),
   pick = function() FT.ApplyUsageLevel('tam') end, is = function() return S().usageLevel == 'tam' end},
 }},
 {title = 'Yön oku ve rota', cards = {
  {label = 'Ok + Yol sor', draw = L({{'Yön oku', true}, {'Haritada Yol sor', true}, {'Yol noktaları', true}}),
   pick = function() S().arrow = true; S().mapRoute = true end, is = function() return S().arrow ~= false and S().mapRoute ~= false end},
  {label = 'Sadece ok', draw = L({{'Yön oku', true}, {'Haritada Yol sor', false}, {'Yol noktaları', true}}),
   pick = function() S().arrow = true; S().mapRoute = false end, is = function() return S().arrow ~= false and S().mapRoute == false end},
  {label = 'Kapalı', draw = L({{'Yön oku', false}, {'Haritada Yol sor', false}, {'Yol noktaları', false}}),
   pick = function() S().arrow = false; S().mapRoute = false end, is = function() return S().arrow == false end},
 }},
 {title = 'Yetenek puanları', cards = {
  {label = 'Sorarak ver', draw = L({{'Seviye kartı', true}, {'Sıradakini öner', true}, {'Kendiliğinden ver', false}}),
   pick = function() S().levelcard = true; S().talentadvisor = true; S().autotalent = false end, is = function() return S().autotalent ~= true and S().levelcard ~= false end},
  {label = 'Otomatik ver', draw = L({{'Seviye kartı', true}, {'Sıradakini öner', true}, {'Kendiliğinden ver', true}}),
   pick = function() S().levelcard = true; S().talentadvisor = true; S().autotalent = true end, is = function() return S().autotalent == true end},
  {label = 'Sadece hatırlat', draw = L({{'Seviye kartı', false}, {'Sıradakini öner', true}, {'Kendiliğinden ver', false}}),
   pick = function() S().levelcard = false; S().talentadvisor = true; S().autotalent = false end, is = function() return S().levelcard == false end},
 }},
 {title = 'Daha iyi eşya çıkınca', cards = {
  {label = 'Sorarak tak', draw = L({{'Karşılaştır', true}, {'Sor', true}, {'Kendiliğinden tak', false}}),
   pick = function() S().upgrades = true; S().autoequip = false end, is = function() return S().upgrades ~= false and S().autoequip ~= true end},
  {label = 'Otomatik tak', draw = L({{'Karşılaştır', true}, {'Sor', false}, {'Kendiliğinden tak', true}}),
   pick = function() S().upgrades = true; S().autoequip = true end, is = function() return S().autoequip == true end},
  {label = 'Kapalı', draw = L({{'Karşılaştır', false}, {'Sor', false}, {'Kendiliğinden tak', false}}),
   pick = function() S().upgrades = false; S().autoequip = false end, is = function() return S().upgrades == false end},
 }},
 {title = 'Renk teması', themes = true},
 {title = 'Çanta ve satıcı', cards = {
  {label = 'Hepsi açık', draw = L({{'Çöp sat', true}, {'Tamir', true}, {'Otomatik toplama', true}}),
   pick = function() for _, k in ipairs(AUTO) do S()[k] = true end end, is = function() return S().autosell ~= false and S().autoloot ~= false end},
  {label = 'Sadece satıcı', draw = L({{'Çöp sat', true}, {'Tamir', true}, {'Otomatik toplama', false}}),
   pick = function() S().autosell = true; S().autorepair = true; S().autoloot = false end, is = function() return S().autoloot == false and S().autosell ~= false end},
  {label = 'Hepsi kapalı', draw = L({{'Çöp sat', false}, {'Tamir', false}, {'Otomatik toplama', false}}),
   pick = function() for _, k in ipairs(AUTO) do S()[k] = false end end, is = function() return S().autosell == false end},
 }},
 {title = 'Nereden ne yapılır?', tips = {
  '|cffffd060Hedef seçmek için|r  görev kutusunda bir göreve tıkla, ya da haritada Ctrl + sol tık yap.',
  '|cffffd060Yer bulmak için|r  haritayı aç (M), sağdaki "Yol sor" ile en yakın tamirci, han, uçuş ustası ve bankayı bul.',
  '|cffffd060Minimap düğmesi|r  sol tık: Rehber  |  sağ tık: Araçlar  |  Shift + sağ tık: Ayarlar.',
  '|cffffd060Ayarlar|r  /ftrail ayar  (üstte arama kutusu var)  |  en sık değişenler için  /ftrail hizli',
  '|cffffd060Yardım|r  /ftrail yardim komut listesini yazar; bu ekranı  /ftrail kurulum  ile yeniden açarsın.',
 }},
}

local function applyAll()
 if FT.ApplySimple then pcall(FT.ApplySimple) end
 if FT.tracker then if S().tracker == false then FT.tracker:Hide() else FT.tracker:Show() end end
 if FT.RefreshAvailableBox then pcall(FT.RefreshAvailableBox) end
 if FT.BumpLayers then FT.BumpLayers() end
 if FT.RefreshTracker then pcall(FT.RefreshTracker) end
end

-- Kullanım düzeyleri: yalnızca ekrandaki kutuları ve uyarı kalabalığını belirler. Standart = eklentinin varsayılanları (anahtar silinir).
local MANAGED = {'dock', 'card', 'infobar', 'rarecard', 'rares', 'raremap', 'townsfolk', 'trkfx', 'donebanner',
 'creaturenear', 'danger', 'elitewarn', 'zonefit', 'sessionsummary'}
local LEVELS = {
 sade = {dock = false, card = false, infobar = false, rarecard = false, rares = false, raremap = false, townsfolk = false,
  trkfx = false, donebanner = false, creaturenear = false, danger = false, elitewarn = false, zonefit = false, sessionsummary = false},
 standart = {},
 tam = {dock = true, card = true, infobar = true, rarecard = true, rares = true, raremap = true, townsfolk = true,
  trkfx = true, donebanner = true, creaturenear = true, danger = true, elitewarn = true, zonefit = true, sessionsummary = true},
}
FT.UsageLevels = {'sade', 'standart', 'tam'}

function FT.ApplyUsageLevel(name)
 local level = LEVELS[name]
 if not level then return false end
 for _, key in ipairs(MANAGED) do S()[key] = level[key] end
 S().usageLevel = name ~= 'standart' and name or nil
 if not S().simple then
  if FT.dock then FT.dock:SetShown(S().dock ~= false) end
  if FT.card then FT.card:SetShown(S().card ~= false) end
 end
 if FT.RefreshAvailableBox then pcall(FT.RefreshAvailableBox) end
 if FT.RefreshTracker then pcall(FT.RefreshTracker) end
 if FT.UpdateInfoBar then pcall(FT.UpdateInfoBar) end
 if FT.RefreshDock then pcall(FT.RefreshDock) end
 if FT.BumpLayers then FT.BumpLayers() end
 return true
end

local cardPool, chosen = {}, {}
local function newCard(i)
 local c = CreateFrame('Button', nil, win)
 c.border = tex(c, 'BACKGROUND'); c.border:SetPoint('TOPLEFT', -2, 2); c.border:SetPoint('BOTTOMRIGHT', 2, -2)
 c.label = text(c, 13, 'OUTLINE'); c.label:SetPoint('TOP', c, 'BOTTOM', 0, -6)
 c:SetHighlightTexture('Interface\\Buttons\\WHITE8X8'); c:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
 cardPool[i] = c
 return c
end

local function show(n)
 current = n
 for _, c in ipairs(cardPool) do c:Hide() end
 local st = STEPS[n]
 win.step:SetText(('%d / %d'):format(n, #STEPS))
 win.question:SetText(st.title)
 win.hint:SetText(st.hint or (st.tips and 'Bunları sonradan da bulabilirsin.' or 'Bir karta tıkla. Hepsi sonradan Ayarlar\'dan değiştirilebilir.'))
 win.tips:SetText(st.tips and table.concat(st.tips, '\n\n') or '')
 win.tips:SetShown(st.tips ~= nil)
 local cards = st.cards or {}
 if st.themes then
  cards = {}
  for _, key in ipairs(FT.themeOrder) do
   if #cards < 4 then
    cards[#cards + 1] = {label = FT.Themes[key].name, draw = function(p) drawTheme(p, key) end,
     pick = function() FT.ApplyTheme(key) end, is = function() return S().theme == key end}
   end
  end
 end
 -- kartlar her zaman pencereye sığsın
 local gap = 14
 local cw = math.min(CARD_W, math.floor((W - 40 - (#cards - 1) * gap) / #cards))
 local ch = math.min(CARD_H - 40, cw)
 local total = #cards * cw + (#cards - 1) * gap
 local a = FT.Style.accent
 for i, def in ipairs(cards) do
  local c = cardPool[i] or newCard(i)
  c:SetSize(cw, ch)
  c:ClearAllPoints(); c:SetPoint('TOPLEFT', win, 'TOP', -total / 2 + (i - 1) * (cw + gap), -96)
  c.previews = c.previews or {}
  local key = n .. ':' .. i
  if not c.previews[key] then
   local pv = CreateFrame('Frame', nil, c); pv:SetAllPoints()
   pcall(def.draw, pv)
   c.previews[key] = pv
  end
  for k, pv in pairs(c.previews) do if k == key then pv:Show() else pv:Hide() end end
  c.label:SetText(def.label)
  local sel = chosen[n] == i or (not chosen[n] and def.is and def.is())
  c.border:SetColorTexture(sel and a[1] or 0.3, sel and a[2] or 0.3, sel and a[3] or 0.3, 1)
  c.label:SetTextColor(sel and a[1] or 0.9, sel and a[2] or 0.88, sel and a[3] or 0.82)
  c:SetScript('OnClick', function()
   chosen[n] = i
   pcall(def.pick); applyAll()
   show(n)
   if C_Timer and n < #STEPS then C_Timer.After(0.35, function() if win:IsShown() and current == n then show(n + 1) end end) end
  end)
  c:Show()
 end
 for i, d in ipairs(win.dots) do d:SetVertexColor(i == n and a[1] or 0.4, i == n and a[2] or 0.4, i == n and a[3] or 0.4, 1) end
 win.back:SetShown(n > 1)
 win.next:SetText(n == #STEPS and 'Bitir' or 'İleri')
end

local function finish()
 ForeverTrailSettings.setupDone = true
 ForeverTrailSettings.setupVersion = 3
 win:Hide()
 applyAll()
 FT.Print('Kurulum tamam. Her şeyi Ayarlar\'dan değiştirebilirsin; bu ekranı /ftrail kurulum ile yeniden açarsın.')
end

function FT.ShowSetupWizard()
 if not win then
  win = FT.NewWindow('ForeverTrailWizard', UIParent)
  win:SetSize(W, H); win:SetPoint('CENTER', 0, 40); win:SetFrameStrata('DIALOG')
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag('LeftButton')
  win:SetScript('OnDragStart', function(self) self:StartMoving() end)
  win:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
  local title = text(win, 18, 'OUTLINE'); title:SetPoint('TOP', 0, -12); title:SetText('ForeverTrail\'e hoş geldin')
  if FT.StyleTitle then FT.StyleTitle(title); font(title, 18, 'OUTLINE') end
  win.step = text(win, 11, ''); win.step:SetPoint('TOPRIGHT', -16, -16); win.step:SetTextColor(0.6, 0.6, 0.6)
  win.question = text(win, 15, ''); win.question:SetPoint('TOP', 0, -50); win.question:SetTextColor(1, 0.94, 0.82)
  win.hint = text(win, 11, ''); win.hint:SetPoint('TOP', win.question, 'BOTTOM', 0, -6)
  win.hint:SetTextColor(0.65, 0.62, 0.56)
  win.tips = text(win, 12, ''); win.tips:SetPoint('TOPLEFT', 36, -96); win.tips:SetWidth(W - 72); win.tips:SetJustifyH('LEFT')
  win.tips:SetTextColor(0.9, 0.88, 0.82); win.tips:Hide()
  win.dots = {}
  for i = 1, #STEPS do
   local d = tex(win, 'ARTWORK', BLOB); d:SetSize(9, 9)
   d:SetPoint('BOTTOM', win, 'BOTTOM', (i - (#STEPS + 1) / 2) * 16, 50)
   win.dots[i] = d
  end
  win.back = FT.NewButton(win, 'Geri', 90, 24); win.back:SetPoint('BOTTOMLEFT', 16, 14)
  win.back:SetScript('OnClick', function() if current > 1 then show(current - 1) end end)
  local skip = FT.NewButton(win, 'Atla', 90, 24); skip:SetPoint('BOTTOM', 0, 14)
  skip:SetScript('OnClick', finish)
  win.next = FT.NewButton(win, 'İleri', 90, 24); win.next:SetPoint('BOTTOMRIGHT', -16, 14)
  win.next:SetScript('OnClick', function() if current < #STEPS then show(current + 1) else finish() end end)
  if FT.AddShowAnim then FT.AddShowAnim(win) end
 end
 chosen = {}
 show(1)
 win:Show()
 if FT.FixFonts then pcall(FT.FixFonts, win) end
end
