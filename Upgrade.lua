local _, FT = ...

-- Forever (Mainline altyapısı): eski global GetItemInfo olmayabilir; C_Item.GetItemInfo kullanılır
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)

-- Ekipman puanı (sınıfa göre stat ağırlıkları, Pawn mantığı) ve karşılaştırmalı sorma pencereleri:
-- 1) Daha iyi eşya: yeni / takılı yan yana, stat farkları, "Tak", "Şimdi değil", "Bir daha sorma"
-- 2) Çanta dolu: yerdeki eşya ile çantadaki en değersiz 3 eşya; hangisi atılsın seç

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end

local KEYS = {
 ITEM_MOD_STRENGTH = 'STR', ITEM_MOD_AGILITY = 'AGI', ITEM_MOD_STAMINA = 'STA', ITEM_MOD_INTELLECT = 'INT', ITEM_MOD_SPIRIT = 'SPI',
 ITEM_MOD_ATTACK_POWER = 'AP', ITEM_MOD_RANGED_ATTACK_POWER = 'RAP', ITEM_MOD_SPELL_POWER = 'SP', ITEM_MOD_SPELL_DAMAGE_DONE = 'SP',
 ITEM_MOD_SPELL_HEALING_DONE = 'HEAL', ITEM_MOD_CRIT_RATING = 'CRIT', ITEM_MOD_CRIT_SPELL_RATING = 'CRIT', ITEM_MOD_HIT_RATING = 'HIT',
 ITEM_MOD_HIT_SPELL_RATING = 'HIT', ITEM_MOD_DEFENSE_SKILL_RATING = 'DEF', ITEM_MOD_DODGE_RATING = 'DODGE', ITEM_MOD_MANA_REGENERATION = 'MP5',
 ITEM_MOD_DAMAGE_PER_SECOND = 'DPS', RESISTANCE0_NAME = 'ARMOR',
}
local LABEL = {STR = 'Güç', AGI = 'Çeviklik', STA = 'Dayanıklılık', INT = 'Zekâ', SPI = 'Ruh', AP = 'Saldırı gücü', RAP = 'Menzilli SG',
 SP = 'Büyü gücü', HEAL = 'İyileştirme', CRIT = 'Kritik', HIT = 'İsabet', DEF = 'Savunma', DODGE = 'Kaçınma', MP5 = 'Mana/5sn', DPS = 'Hasar/sn', ARMOR = 'Zırh'}
local ORDER = {'DPS', 'STR', 'AGI', 'STA', 'INT', 'SPI', 'AP', 'RAP', 'SP', 'HEAL', 'CRIT', 'HIT', 'MP5', 'DEF', 'DODGE', 'ARMOR'}

local WEIGHTS = {
 WARRIOR = {STR = 2.2, AGI = 1.2, STA = 0.8, AP = 1, CRIT = 1.2, HIT = 1.4, DEF = 0.6, DODGE = 0.6, ARMOR = 0.02, DPS = 8},
 PALADIN = {STR = 2, AGI = 0.9, STA = 0.8, INT = 0.8, SPI = 0.3, AP = 0.9, SP = 0.8, HEAL = 0.6, CRIT = 1, HIT = 1, MP5 = 1, ARMOR = 0.02, DPS = 7},
 HUNTER = {AGI = 2.2, STR = 0.3, STA = 0.7, INT = 0.6, SPI = 0.2, AP = 0.9, RAP = 1, CRIT = 1.2, HIT = 1.4, MP5 = 0.8, ARMOR = 0.01, DPS = 2},
 ROGUE = {AGI = 2.2, STR = 1, STA = 0.7, AP = 1, CRIT = 1.3, HIT = 1.5, DODGE = 0.5, ARMOR = 0.01, DPS = 8},
 PRIEST = {INT = 1.6, SPI = 1.4, STA = 0.7, SP = 1.8, HEAL = 1.2, CRIT = 0.6, MP5 = 1.6, ARMOR = 0.005, DPS = 0.4},
 MAGE = {INT = 1.8, SPI = 0.8, STA = 0.7, SP = 2, CRIT = 1, HIT = 1.2, MP5 = 1.2, ARMOR = 0.005, DPS = 0.4},
 WARLOCK = {INT = 1.5, SPI = 0.8, STA = 1, SP = 2, CRIT = 0.8, HIT = 1.2, MP5 = 1, ARMOR = 0.005, DPS = 0.4},
 DRUID = {INT = 1.2, SPI = 1, STA = 0.8, AGI = 1.2, STR = 1, AP = 0.6, SP = 1.2, HEAL = 0.8, CRIT = 0.8, MP5 = 1.2, ARMOR = 0.01, DPS = 1.5},
 SHAMAN = {INT = 1.3, SPI = 0.8, STA = 0.8, STR = 1.2, AGI = 0.8, AP = 0.8, SP = 1.2, HEAL = 0.8, CRIT = 1, MP5 = 1.3, ARMOR = 0.01, DPS = 5},
}
local RANGED = {INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true}

local function classToken() local _, t = UnitClass('player'); return t end

function FT.ItemStats(link)
 local out = {}
 if not (link and GetItemStats) then return out end
 local ok, raw = pcall(GetItemStats, link)
 if not ok or type(raw) ~= 'table' then return out end
 for k, v in pairs(raw) do
  local key = KEYS[(k:gsub('_SHORT$', ''))]
  if key and type(v) == 'number' then out[key] = (out[key] or 0) + v end
 end
 return out
end

local cache = {}
function FT.ItemScore(link)
 if not link then return -1 end
 if cache[link] then return cache[link] end
 local _, _, quality, ilvl, _, _, _, _, equipLoc = GetItemInfo(link)
 if not ilvl then return 0 end
 local w = WEIGHTS[classToken()] or WEIGHTS.WARRIOR
 local stats = FT.ItemStats(link)
 local score = (ilvl or 0) * 0.15 + (quality or 1) * 0.5
 for k, v in pairs(stats) do
  local wk = w[k] or 0
  if k == 'DPS' and classToken() == 'HUNTER' and RANGED[equipLoc] then wk = 6 end
  score = score + wk * v
 end
 cache[link] = score
 return score
end

function FT.StatDiff(newLink, oldLink)
 local a, b = FT.ItemStats(newLink), FT.ItemStats(oldLink)
 local lines = {}
 for _, k in ipairs(ORDER) do
  local d = (a[k] or 0) - (b[k] or 0)
  if math.abs(d) >= 0.05 then lines[#lines + 1] = {k = k, label = LABEL[k], d = d} end
 end
 return lines
end

----------------------------------------------------------------------
-- Ortak çizim yardımcıları
----------------------------------------------------------------------
local function font(fs, size, flags)
 if fs:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', size, flags or '') == false then fs:SetFont('Fonts\\ARIALN.TTF', size, flags or '') end
 fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.9)
end
local function text(parent, size, flags, justify)
 local fs = parent:CreateFontString(nil, 'OVERLAY'); font(fs, size, flags); fs:SetJustifyH(justify or 'LEFT'); return fs
end
local function money(c)
 c = math.floor(c or 0)
 local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
 if g > 0 then return ('%d|cffffd700a|r %d|cffc7c7cfg|r'):format(g, s) end
 if s > 0 then return ('%d|cffc7c7cfg|r %d|cffeda55fb|r'):format(s, k) end
 return ('%d|cffeda55fb|r'):format(k)
end
FT.MoneyText = money

local function itemCard(parent, x, y, w)
 local c = CreateFrame('Button', nil, parent)
 c:SetSize(w, 50); c:SetPoint('TOPLEFT', x, y)
 c.bg = c:CreateTexture(nil, 'BACKGROUND'); c.bg:SetAllPoints(); c.bg:SetColorTexture(0, 0, 0, 0.3)
 c.icon = c:CreateTexture(nil, 'ARTWORK'); c.icon:SetSize(38, 38); c.icon:SetPoint('LEFT', 6, 0); c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
 c.name = text(c, 12, ''); c.name:SetPoint('TOPLEFT', c.icon, 'TOPRIGHT', 8, -2); c.name:SetPoint('RIGHT', c, 'RIGHT', -6, 0); c.name:SetWordWrap(false)
 c.sub = text(c, 11, ''); c.sub:SetPoint('TOPLEFT', c.name, 'BOTTOMLEFT', 0, -4); c.sub:SetTextColor(0.75, 0.72, 0.65)
 c:SetScript('OnEnter', function(self)
  if not self.link then return end
  GameTooltip:SetOwner(self, 'ANCHOR_RIGHT'); pcall(GameTooltip.SetHyperlink, GameTooltip, self.link); GameTooltip:Show()
 end)
 c:SetScript('OnLeave', function() GameTooltip:Hide() end)
 return c
end
local function fillCard(c, link, sub)
 c.link = link
 if link then
  local name, _, quality, _, _, _, _, _, _, icon = GetItemInfo(link)
  c.icon:SetTexture(icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
  local r, g, b = 1, 1, 1
  if quality and GetItemQualityColor then r, g, b = GetItemQualityColor(quality) end
  c.name:SetText(name or link); c.name:SetTextColor(r, g, b)
 else
  c.icon:SetTexture('Interface\\PaperDoll\\UI-Backpack-EmptySlot'); c.name:SetText('Boş yuva'); c.name:SetTextColor(0.6, 0.6, 0.6)
 end
 c.sub:SetText(sub or '')
end

----------------------------------------------------------------------
-- Daha iyi eşya penceresi
----------------------------------------------------------------------
local up
local function ensureUp()
 if up then return up end
 up = FT.NewWindow('ForeverTrailUpgradeCompare', UIParent)
 FT.upgradeCompare = up
 up:SetSize(380, 300); up:SetPoint('TOP', UIParent, 'TOP', 0, -150); up:SetFrameStrata('DIALOG')
 up:SetMovable(true); up:EnableMouse(true); up:RegisterForDrag('LeftButton')
 up:SetScript('OnDragStart', function(self) self:StartMoving() end)
 up:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
 up.title = text(up, 15, 'OUTLINE', 'CENTER'); up.title:SetPoint('TOP', 0, -10)
 if FT.StyleTitle then FT.StyleTitle(up.title) end
 up.newLabel = text(up, 11, ''); up.newLabel:SetPoint('TOPLEFT', 16, -34); up.newLabel:SetText('Yeni'); up.newLabel:SetTextColor(0.45, 1, 0.45)
 up.new = itemCard(up, 14, -48, 352)
 up.oldLabel = text(up, 11, ''); up.oldLabel:SetPoint('TOPLEFT', 16, -104); up.oldLabel:SetText('Takılı'); up.oldLabel:SetTextColor(0.75, 0.72, 0.65)
 up.old = itemCard(up, 14, -118, 352)
 up.gain = text(up, 13, 'OUTLINE', 'CENTER'); up.gain:SetPoint('TOP', 0, -176)
 up.stats = text(up, 12, '', 'CENTER'); up.stats:SetPoint('TOP', up.gain, 'BOTTOM', 0, -6); up.stats:SetWidth(350)
 up.note = text(up, 11, '', 'CENTER'); up.note:SetPoint('BOTTOM', 0, 46); up.note:SetTextColor(1, 0.6, 0.3)
 local function btn(label, x, w, fn)
  local b = FT.NewButton(up, label, w, 24); b:SetPoint('BOTTOMLEFT', x, 14); b:SetScript('OnClick', fn); return b
 end
 up.equip = btn('Tak', 14, 110, function() local f = up.onEquip; up:Hide(); if f then f() end end)
 up.later = btn('Şimdi değil', 134, 110, function() local f = up.onLater; up:Hide(); if f then f() end end)
 up.never = btn('Bir daha sorma', 254, 112, function() local f = up.onNever; up:Hide(); if f then f() end end)
 up:Hide()
 if FT.RegisterPopup then FT.RegisterPopup(up) end
 return up
end

function FT.ShowUpgradeCompare(newLink, oldLink, onEquip, onLater, onNever, bindNote)
 local p = ensureUp()
 if p:IsShown() then return false end
 local ns, cs = FT.ItemScore(newLink), oldLink and FT.ItemScore(oldLink) or 0
 local _, _, _, nl = GetItemInfo(newLink)
 local ol = oldLink and select(4, GetItemInfo(oldLink))
 p.title:SetText('Daha iyi eşya')
 fillCard(p.new, newLink, ('ilvl %s · puan %.0f'):format(nl or '?', ns))
 fillCard(p.old, oldLink, oldLink and ('ilvl %s · puan %.0f'):format(ol or '?', cs) or 'Bu yuvada eşya yok')
 if cs > 0 then p.gain:SetText(('|cff55ff55%%%d daha iyi|r'):format(math.floor((ns - cs) / cs * 100 + 0.5)))
 else p.gain:SetText('|cff55ff55Boş yuvayı doldurur|r') end
 local parts = {}
 for _, l in ipairs(FT.StatDiff(newLink, oldLink)) do
  local v = l.k == 'DPS' and ('%.1f'):format(math.abs(l.d)) or tostring(math.floor(math.abs(l.d) + 0.5))
  parts[#parts + 1] = (l.d > 0 and '|cff55ff55+' or '|cffff5555-') .. v .. ' ' .. l.label .. '|r'
  if #parts >= 8 then break end
 end
 p.stats:SetText(#parts > 0 and table.concat(parts, '   ') or '|cff9aa0a6Stat farkı yok, eşya seviyesi daha yüksek|r')
 p.note:SetText(bindNote or '')
 p.onEquip, p.onLater, p.onNever = onEquip, onLater, onNever
 p:Show()
 if PlaySound and SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN then pcall(PlaySound, SOUNDKIT.IG_BACKPACK_OPEN) end
 return true
end

----------------------------------------------------------------------
-- Çanta dolu penceresi
----------------------------------------------------------------------
local sw
local function ensureSwap()
 if sw then return sw end
 sw = FT.NewWindow('ForeverTrailSwapCompare', UIParent)
 FT.swapCompare = sw
 sw:SetSize(380, 320); sw:SetPoint('TOP', UIParent, 'TOP', 0, -150); sw:SetFrameStrata('DIALOG')
 sw:SetMovable(true); sw:EnableMouse(true); sw:RegisterForDrag('LeftButton')
 sw:SetScript('OnDragStart', function(self) self:StartMoving() end)
 sw:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
 sw.title = text(sw, 15, 'OUTLINE', 'CENTER'); sw.title:SetPoint('TOP', 0, -10)
 if FT.StyleTitle then FT.StyleTitle(sw.title) end
 local l1 = text(sw, 11, ''); l1:SetPoint('TOPLEFT', 16, -34); l1:SetText('Yerde, alınamıyor'); l1:SetTextColor(0.45, 1, 0.45)
 sw.loot = itemCard(sw, 14, -48, 352)
 local l2 = text(sw, 11, ''); l2:SetPoint('TOPLEFT', 16, -106); l2:SetText('Hangisi atılıp yerine alınsın? (tıkla)'); l2:SetTextColor(0.75, 0.72, 0.65)
 sw.rows = {}
 for i = 1, 3 do
  local r = itemCard(sw, 14, -120 - (i - 1) * 54, 352)
  r.hl = r:CreateTexture(nil, 'HIGHLIGHT'); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 0.3, 0.3, 0.15)
  r:SetScript('OnClick', function(self) local f = sw.onPick; local v = self.victim; sw:Hide(); if f and v then f(v) end end)
  sw.rows[i] = r
 end
 local cancel = FT.NewButton(sw, 'Vazgeç', 110, 24); cancel:SetPoint('BOTTOM', 0, 12)
 cancel:SetScript('OnClick', function() sw:Hide() end)
 sw:Hide()
 if FT.RegisterPopup then FT.RegisterPopup(sw) end
 return sw
end

-- lootLink, değer (bakır, görev eşyası ise math.huge), adaylar {{bag,slot,link,value}}, onPick(aday)
function FT.ShowSwapCompare(lootLink, value, candidates, onPick)
 local p = ensureSwap()
 if p:IsShown() then return false end
 p.title:SetText('Çanta dolu')
 fillCard(p.loot, lootLink, value == math.huge and 'Görev eşyası' or ('Değeri: ' .. money(value)))
 for i, r in ipairs(p.rows) do
  local v = candidates[i]
  if v then
   r.victim = v
   fillCard(r, v.link, ('Değeri: %s%s'):format(money(v.value), v.count and v.count > 1 and (' (' .. v.count .. ' adet)') or ''))
   r:Show()
  else r:Hide() end
 end
 p:SetHeight(150 + #candidates * 54 + 20)
 p.onPick = onPick
 p:Show()
 return true
end
