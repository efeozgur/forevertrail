local _, FT = ...

-- Meslek rehberi: sınıfa göre öneri, mesleklerin ve rütbe sınırları, eğitmene yol,
-- meslek penceresinin yanında "puan için ne yapmalı" yardımcısı (turuncu/sarı tarifler, eksik malzeme, Yap düğmesi).

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function font(fs, size, flags)
 if fs:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', size, flags or '') == false then fs:SetFont('Fonts\\ARIALN.TTF', size, flags or '') end
 fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.9)
end
local function text(parent, size, flags, justify)
 local fs = parent:CreateFontString(nil, 'OVERLAY'); font(fs, size, flags); fs:SetJustifyH(justify or 'LEFT'); return fs
end
local function classToken() local _, t = UnitClass('player'); return t end

local PROFS = {
 {key = 'herb', en = 'Herbalism', tr = 'Bitki toplama', words = {'Herbalis'}, gather = true, icon = 'Interface\\Icons\\Trade_Herbalism'},
 {key = 'mining', en = 'Mining', tr = 'Madencilik', words = {'Mining', 'Miner'}, gather = true, icon = 'Interface\\Icons\\Trade_Mining'},
 {key = 'skin', en = 'Skinning', tr = 'Deri yüzme', words = {'Skinn'}, gather = true, icon = 'Interface\\Icons\\INV_Misc_Pelt_Wolf_01'},
 {key = 'tailor', en = 'Tailoring', tr = 'Terzilik', words = {'Tailor'}, icon = 'Interface\\Icons\\Trade_Tailoring'},
 {key = 'lw', en = 'Leatherworking', tr = 'Dericilik', words = {'Leatherwork'}, icon = 'Interface\\Icons\\Trade_LeatherWorking'},
 {key = 'bs', en = 'Blacksmithing', tr = 'Demircilik', words = {'Blacksmith'}, icon = 'Interface\\Icons\\Trade_BlackSmithing'},
 {key = 'eng', en = 'Engineering', tr = 'Mühendislik', words = {'Engineer'}, icon = 'Interface\\Icons\\Trade_Engineering'},
 {key = 'alch', en = 'Alchemy', tr = 'Simya', words = {'Alchem'}, icon = 'Interface\\Icons\\Trade_Alchemy'},
 {key = 'ench', en = 'Enchanting', tr = 'Efsunculuk', words = {'Enchant'}, icon = 'Interface\\Icons\\Trade_Engraving'},
 {key = 'cook', en = 'Cooking', tr = 'Aşçılık', words = {'Cook', 'Chef'}, secondary = true, icon = 'Interface\\Icons\\INV_Misc_Food_15'},
 {key = 'aid', en = 'First Aid', tr = 'İlk yardım', words = {'First Aid', 'Physician', 'Doctor', 'Surgeon'}, secondary = true, icon = 'Interface\\Icons\\Spell_Holy_SealOfSacrifice'},
 {key = 'fish', en = 'Fishing', tr = 'Balıkçılık', words = {'Fishing', 'Fisherman', 'Angler'}, secondary = true, icon = 'Interface\\Icons\\Trade_Fishing'},
}
local BY_KEY = {}
for _, p in ipairs(PROFS) do BY_KEY[p.key] = p end
FT.Professions = PROFS

local REC = {
 WARRIOR = {{'mining', 'bs', 'Kendi silah ve zırhını yaparsın; madenle para kazanırsın.'}, {'mining', 'eng', 'Bomba ve aletler; zor dövüşlerde kurtarır.'}},
 PALADIN = {{'mining', 'bs', 'Kendi zırh ve silahın.'}, {'herb', 'alch', 'İksirler ve para.'}},
 HUNTER = {{'skin', 'lw', 'Avladıklarının derisiyle kendi zırhın; çok kolay puan.'}, {'mining', 'eng', 'Dürbün ve mermi yaparsın.'}},
 ROGUE = {{'skin', 'lw', 'Deri zırh ve kolay puan.'}, {'mining', 'eng', 'Bomba ve aletler.'}},
 PRIEST = {{'tailor', 'ench', 'Kumaş zaten düşer; kendi giysin ve efsunların.'}, {'herb', 'alch', 'İksir ve para.'}},
 MAGE = {{'tailor', 'ench', 'Kumaş zaten düşer; kendi giysin ve efsunların.'}, {'herb', 'alch', 'İksir ve para.'}},
 WARLOCK = {{'tailor', 'ench', 'Kumaş zaten düşer; kendi giysin ve efsunların.'}, {'herb', 'alch', 'İksir ve para.'}},
 SHAMAN = {{'skin', 'lw', 'Deri, sonra zincir zırh.'}, {'herb', 'alch', 'İksir ve para.'}},
 DRUID = {{'skin', 'lw', 'Deri zırh; vahşi druid için ideal.'}, {'herb', 'alch', 'İksir ve para.'}},
}

-- Rütbeler: ad, sınır, gereken seviye, gereken beceri
local RANKS = {{'Çırak', 75, 5, 0}, {'Kalfa', 150, 10, 50}, {'Usta', 225, 20, 125}, {'Uzman', 300, 35, 200}}

function FT.MyProfessions()
 local out = {}
 if not FT.Compat then return out end
 for i = 1, FT.Compat.NumSkillLines() do
  local name, header, rank, max = FT.Compat.SkillLine(i)
  if name and not header then
   for _, p in ipairs(PROFS) do
    if name == p.en or name:find(p.en, 1, true) then out[p.key] = {def = p, rank = rank or 0, max = max or 0, name = name} end
   end
  end
 end
 return out
end

local trainerCache = {}
function FT.ProfessionTrainer(key)
 local p = BY_KEY[key]
 if not p then return nil end
 local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
 local cacheKey = key .. ':' .. tostring(map)
 if trainerCache[cacheKey] ~= nil then return trainerCache[cacheKey] or nil end
 local z = FT.Module and FT.Module('ZoneDB')
 local fac = (UnitFactionGroup and UnitFactionGroup('player') == 'Horde') and 'H' or 'A'
 local pos = map and C_Map.GetPlayerMapPosition(map, 'player')
 local px, py = 0.5, 0.5
 if pos then px, py = pos:GetXY() end
 local best, bd
 for _, n in pairs(FT.DBN or {}) do
  local sub = n[11]
  if type(sub) == 'string' and type(n[12]) == 'number' and math.floor(n[12] / 16) % 2 == 1 and (not n[10] or n[10]:find(fac, 1, true)) and type(n[5]) == 'table' then
   local match = false
   for _, w in ipairs(p.words) do if sub:find(w, 1, true) then match = true; break end end
   if match and z then
    for area, list in pairs(n[5]) do
     local ui = z:GetUiMapIdByAreaId(area)
     if ui and list[1] then
      local x, y = list[1] / 1000, list[2] / 1000
      local d = (ui == map) and ((x - px) ^ 2 + (y - py) ^ 2) or 10
      if not bd or d < bd then best, bd = {map = ui, x = x, y = y, name = n[1], sub = sub}, d end
     end
    end
   end
  end
 end
 trainerCache[cacheKey] = best or false
 return best
end

local function goTrainer(key)
 local t = FT.ProfessionTrainer(key)
 if t then FT.SetCustomTarget(t.map, t.x, t.y, t.name .. ' (' .. (t.sub or '') .. ')')
 else FT.Print('Bu meslek için eğitmen veride bulunamadı.') end
end
FT.GoProfessionTrainer = goTrainer

-- Bir mesleğin durumu: sınıra yakın mı, sonraki rütbe için seviye/beceri yeterli mi
function FT.ProfessionAdvice(entry)
 local level = UnitLevel('player') or 1
 local rank, max = entry.rank, entry.max
 for _, r in ipairs(RANKS) do
  if r[2] > max then
   if rank >= r[4] and level >= r[3] then
    return ('|cffffd100%s rütbesini öğrenebilirsin (sınır %d).|r'):format(r[1], r[2]), true
   elseif level < r[3] then
    return ('%s rütbesi için seviye %d gerekir.'):format(r[1], r[3]), false
   else
    return ('%s rütbesi için beceri %d gerekir (%d kaldı).'):format(r[1], r[4], r[4] - rank), false
   end
  end
 end
 if rank >= max then return '|cff55ff55En üst seviyede.|r', false end
 return ('Sınıra %d puan var.'):format(max - rank), false
end

----------------------------------------------------------------------
-- Meslek penceresi yanındaki yardımcı
----------------------------------------------------------------------
local helper
local ORDER = {optimal = 1, medium = 2, easy = 3, trivial = 4}
local COLOR = {optimal = '|cffff8040', medium = '|cffffff00', easy = '|cff40c040', trivial = '|cff808080'}

local function recipes()
 if FT.Compat and FT.Compat.ProfessionFrame and _G.ProfessionsFrame and _G.ProfessionsFrame:IsShown() then
  local list = FT.Compat.Recipes()
  if list then
   table.sort(list, function(a, b)
    local ka, kb = ORDER[a.kind] or 5, ORDER[b.kind] or 5
    if ka ~= kb then return ka < kb end
    if (a.avail > 0) ~= (b.avail > 0) then return a.avail > 0 end
    return a.name < b.name
   end)
   return list
  end
 end
 local out = {}
 if GetNumTradeSkills and GetTradeSkillInfo and TradeSkillFrame and TradeSkillFrame:IsShown() then
  for i = 1, GetNumTradeSkills() do
   local name, kind, avail = GetTradeSkillInfo(i)
   if name and kind ~= 'header' and ORDER[kind] then
    local missing = {}
    for j = 1, (GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0) do
     local rn, _, need, have = GetTradeSkillReagentInfo(i, j)
     if rn and (have or 0) < (need or 0) then missing[#missing + 1] = ('%s %d/%d'):format(rn, have or 0, need or 0) end
    end
    out[#out + 1] = {i = i, name = name, kind = kind, avail = avail or 0, missing = missing, craft = false}
   end
  end
 elseif GetNumCrafts and GetCraftInfo and CraftFrame and CraftFrame:IsShown() then
  for i = 1, GetNumCrafts() do
   local name, _, kind, avail = GetCraftInfo(i)
   if name and kind ~= 'header' and ORDER[kind] then
    local missing = {}
    for j = 1, (GetCraftNumReagents and GetCraftNumReagents(i) or 0) do
     local rn, _, need, have = GetCraftReagentInfo(i, j)
     if rn and (have or 0) < (need or 0) then missing[#missing + 1] = ('%s %d/%d'):format(rn, have or 0, need or 0) end
    end
    out[#out + 1] = {i = i, name = name, kind = kind, avail = avail or 0, missing = missing, craft = true}
   end
  end
 end
 table.sort(out, function(a, b)
  local ka, kb = ORDER[a.kind], ORDER[b.kind]
  if ka ~= kb then return ka < kb end
  if (a.avail > 0) ~= (b.avail > 0) then return a.avail > 0 end
  return a.name < b.name
 end)
 return out
end
FT.ProfessionRecipes = recipes

local RGB = {optimal = {1, 0.5, 0.25}, medium = {1, 1, 0.1}, easy = {0.25, 0.75, 0.25}, trivial = {0.5, 0.5, 0.5}}
local KIND_TR = {optimal = 'kesin puan', medium = 'çoğunlukla puan', easy = 'bazen puan', trivial = 'puan yok'}
local ROW_H, ROW_GAP, HEAD_H, FOOT_H = 36, 3, 52, 42

local function refreshHelper()
 if not (helper and helper:IsShown()) then return end
 local list = recipes()
 local rows = helper.rows
 local shown = 0
 for _, r in ipairs(list) do
  if r.kind ~= 'trivial' and shown < #rows then
   shown = shown + 1
   local row = rows[shown]
   row.r = r
   local c = RGB[r.kind] or RGB.trivial
   row.stripe:SetColorTexture(c[1], c[2], c[3], 1)
   row.bg:SetColorTexture(1, 1, 1, shown % 2 == 0 and 0.05 or 0.02)
   row.name:SetText(COLOR[r.kind] .. r.name .. '|r')
   if r.avail > 0 then
    row.info:SetText(('|cff55ff55%d kez yapılabilir|r  |cff8a8f98· %s|r'):format(r.avail, KIND_TR[r.kind] or ''))
    row.make:Enable(); row.all:Enable()
   else
    row.info:SetText(('|cffff7070Eksik: %s|r'):format(#r.missing > 0 and table.concat(r.missing, ', ') or 'malzeme'))
    row.make:Disable(); row.all:Disable()
   end
   row:Show()
  end
 end
 for i = shown + 1, #rows do rows[i]:Hide() end
 helper.empty:SetShown(shown == 0)
 helper.count:SetText(shown > 0 and ('%d tarif  ·  sürükleyerek taşı'):format(shown) or 'sürükleyerek taşı')
 -- yükseklik içeriğe göre: satırlar altındaki düğmeye binmesin
 local body = shown > 0 and (shown * (ROW_H + ROW_GAP)) or 56
 helper:SetHeight(HEAD_H + body + FOOT_H)
end

-- Meslek penceresinin dışına yerleştir: asla üstüne binmez (Yarat/Hepsini yarat düğmeleri açık kalır).
-- Önce sağ, sığmazsa sol; ikisi de sığmazsa daha geniş tarafa, küçülterek.
local GAP = 12
local function placeHelper(anchor)
 helper:ClearAllPoints()
 local us = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
 local es = (anchor.GetEffectiveScale and anchor:GetEffectiveScale()) or us
 local k = es / us -- çerçeve birimi -> ekran (UIParent) birimi
 local l, b, w, h
 if anchor.GetBoundsRect then -- alt öğeler dahil gerçek kapladığı alan
  local ok, a, b2, c, d = pcall(anchor.GetBoundsRect, anchor)
  if ok and type(a) == 'number' and type(c) == 'number' and c > 0 then l, b, w, h = a, b2, c, d end
 end
 if not l then
  l, w, h = anchor:GetLeft(), anchor:GetWidth(), anchor:GetHeight()
  b = anchor:GetBottom()
 end
 if type(l) ~= 'number' or type(w) ~= 'number' then
  helper:SetScale(1); helper:SetPoint('TOPLEFT', anchor, 'TOPRIGHT', GAP, -12); return
 end
 local left, right, top = l * k, (l + w) * k, ((b or 0) + (h or 0)) * k
 local screen = UIParent:GetWidth() or 1024
 local need = helper:GetWidth() + GAP
 local roomR, roomL = screen - right, left
 local s, x, point = 1, nil, nil
 if roomR >= need then x, point = right + GAP, 'TOPLEFT'
 elseif roomL >= need then x, point = left - GAP, 'TOPRIGHT'
 else
  -- iki yanda da yer yok: geniş tarafa, sığacak kadar küçülterek
  local room = math.max(roomR, roomL)
  s = math.max(0.55, (room - GAP) / helper:GetWidth())
  if roomR >= roomL then x, point = right + GAP, 'TOPLEFT' else x, point = left - GAP, 'TOPRIGHT' end
 end
 helper:SetScale(s)
 helper:SetPoint(point, UIParent, 'BOTTOMLEFT', x / s, (top - 12) / s)
end

local function ensureHelper(anchor)
 if not helper then
  helper = FT.NewWindow('ForeverTrailProfHelper', UIParent)
  helper:SetSize(330, 360); helper:SetFrameStrata('HIGH'); helper:SetClampedToScreen(true)
  -- bağımsız: sürükleyerek taşınır, konumu kaydedilir; sağ tık = varsayılan yere dön
  helper:SetMovable(true); helper:EnableMouse(true); helper:RegisterForDrag('LeftButton')
  helper:SetScript('OnDragStart', function(self) self:StartMoving() end)
  helper:SetScript('OnDragStop', function(self)
   self:StopMovingOrSizing()
   local point, _, relative, x, y = self:GetPoint()
   ForeverTrailSettings.profHelperPoint = {point, relative, x, y}
  end)
  helper:SetScript('OnMouseUp', function(self, button)
   if button == 'RightButton' then
    ForeverTrailSettings.profHelperPoint = nil
    if self.anchor then pcall(placeHelper, self.anchor) end
   end
  end)
  local t = text(helper, 14, 'OUTLINE', 'CENTER'); t:SetPoint('TOP', 0, -9); t:SetText('Puan için ne yapmalı?')
  if FT.StyleTitle then FT.StyleTitle(t) end
  local legend = text(helper, 10, '', 'CENTER'); legend:SetPoint('TOP', 0, -28)
  legend:SetText('|cffff8040Turuncu: kesin puan|r   |cffffff00Sarı: çoğunlukla|r   |cff40c040Yeşil: bazen|r')
  local rule = helper:CreateTexture(nil, 'ARTWORK'); rule:SetHeight(1); rule:SetPoint('TOPLEFT', 10, -44); rule:SetPoint('TOPRIGHT', -10, -44)
  rule:SetColorTexture(1, 1, 1, 0.12)
  helper.rows = {}
  for i = 1, 8 do
   local row = CreateFrame('Frame', nil, helper); row:SetSize(310, ROW_H); row:SetPoint('TOPLEFT', 10, -HEAD_H - (i - 1) * (ROW_H + ROW_GAP))
   row.bg = row:CreateTexture(nil, 'BACKGROUND'); row.bg:SetAllPoints()
   row.stripe = row:CreateTexture(nil, 'ARTWORK'); row.stripe:SetSize(3, ROW_H - 6); row.stripe:SetPoint('LEFT', 0, 0)
   row.name = text(row, 12, ''); row.name:SetPoint('TOPLEFT', 10, -4); row.name:SetWidth(210); row.name:SetWordWrap(false)
   row.info = text(row, 10, ''); row.info:SetPoint('TOPLEFT', 10, -20); row.info:SetWidth(210); row.info:SetWordWrap(false)
   row.make = FT.NewButton(row, 'Yap', 34, 22); row.make:SetPoint('RIGHT', -44, 0)
   row.make:SetScript('OnClick', function() local r = row.r; if r then if r.modern then FT.Compat.Craft(r, 1) elseif r.craft then if DoCraft then DoCraft(r.i) end else if DoTradeSkill then DoTradeSkill(r.i, 1) end end end end)
   row.all = FT.NewButton(row, 'Hepsi', 40, 22); row.all:SetPoint('RIGHT', -2, 0)
   row.all:SetScript('OnClick', function() local r = row.r; if r and r.modern and r.avail > 0 then FT.Compat.Craft(r, r.avail) elseif r and not r.craft and DoTradeSkill and r.avail > 0 then DoTradeSkill(r.i, r.avail) end end)
   helper.rows[i] = row
  end
  helper.empty = text(helper, 12, '', 'CENTER'); helper.empty:SetPoint('TOP', 0, -HEAD_H - 12); helper.empty:SetWidth(290)
  helper.empty:SetText('Puan getiren tarif yok.\nEğitmenden yeni tarif öğren.')
  local foot = helper:CreateTexture(nil, 'ARTWORK'); foot:SetHeight(1); foot:SetPoint('BOTTOMLEFT', 10, FOOT_H - 4); foot:SetPoint('BOTTOMRIGHT', -10, FOOT_H - 4)
  foot:SetColorTexture(1, 1, 1, 0.12)
  helper.count = text(helper, 11, '', 'LEFT'); helper.count:SetPoint('BOTTOMLEFT', 14, 17); helper.count:SetTextColor(0.62, 0.6, 0.56)
  helper.trainer = FT.NewButton(helper, 'Eğitmene yol', 120, 24); helper.trainer:SetPoint('BOTTOMRIGHT', -12, 10)
  helper.trainer:SetScript('OnClick', function()
   local name = FT.Compat.TradeSkillName() or ''
   for _, p in ipairs(PROFS) do if name:find(p.en, 1, true) then return goTrainer(p.key) end end
  end)
 end
 -- bağımsız pencere: kayıtlı konum varsa orası, yoksa ilk açılışta meslek penceresinin yanı
 local p = ForeverTrailSettings and ForeverTrailSettings.profHelperPoint
 if p and p[1] and p[3] and p[4] then
  helper:SetScale(1); helper:ClearAllPoints(); helper:SetPoint(p[1], UIParent, p[2] or p[1], p[3], p[4])
 elseif not helper.placed then
  placeHelper(anchor)
 end
 helper.placed = true
 helper.anchor = anchor
 helper:Show()
 refreshHelper()
end

local function hookFrame(frame)
 if not frame or frame.ftHooked then return end
 frame.ftHooked = true
 frame:HookScript('OnShow', function(self) if on('profhelper') then ensureHelper(self) end end)
 frame:HookScript('OnHide', function() if helper then helper:Hide() end end)
 if frame:IsShown() and on('profhelper') then ensureHelper(frame) end
end

----------------------------------------------------------------------
-- Meslek sayfası (ana pencere)
----------------------------------------------------------------------
local page
function FT.BuildProfessionPage(holder)
 if page or not holder then return end
 page = holder
 local a = FT.Style.accent
 local function head(y, s) local h = text(holder, 12, 'OUTLINE'); h:SetPoint('TOPLEFT', 2, y); h:SetTextColor(a[1], a[2], a[3]); h:SetText(s); return h end
 head(-2, 'Sınıfına göre öneri')
 page.recs = {}
 for i = 1, 3 do
  local r = text(holder, 12, ''); r:SetPoint('TOPLEFT', 4, -20 - (i - 1) * 34); r:SetWidth(436); r:SetJustifyV('TOP')
  page.recs[i] = r
 end
 head(-128, 'Mesleklerin')
 page.rows = {}
 for i = 1, 5 do
  local row = CreateFrame('Frame', nil, holder); row:SetSize(440, 44); row:SetPoint('TOPLEFT', 0, -146 - (i - 1) * 46)
  row.icon = row:CreateTexture(nil, 'ARTWORK'); row.icon:SetSize(28, 28); row.icon:SetPoint('TOPLEFT', 2, -2); row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = text(row, 12, 'OUTLINE'); row.name:SetPoint('TOPLEFT', 36, -2)
  row.barBg = row:CreateTexture(nil, 'BORDER'); row.barBg:SetPoint('TOPLEFT', 36, -18); row.barBg:SetSize(250, 6); row.barBg:SetColorTexture(1, 1, 1, 0.1)
  row.bar = row:CreateTexture(nil, 'ARTWORK'); row.bar:SetPoint('TOPLEFT', 36, -18); row.bar:SetHeight(6)
  row.note = text(row, 10, ''); row.note:SetPoint('TOPLEFT', 36, -28); row.note:SetWidth(300); row.note:SetWordWrap(false)
  row.go = FT.NewButton(row, 'Eğitmen', 70, 22); row.go:SetPoint('TOPRIGHT', -4, -6)
  row.go:SetScript('OnClick', function() if row.key then goTrainer(row.key) end end)
  page.rows[i] = row
 end
 head(-384, 'Yan meslekler (herkese faydalı)')
 page.side = text(holder, 11, ''); page.side:SetPoint('TOPLEFT', 4, -402); page.side:SetWidth(436); page.side:SetJustifyV('TOP')
 local gather = FT.NewButton(holder, 'Toplama rehberi', 120, 22); gather:SetPoint('TOPLEFT', 0, -470)
 gather:SetScript('OnClick', function() if FT.ShowProfessionGuide then FT.ShowProfessionGuide() end end)
 local tip = text(holder, 11, ''); tip:SetPoint('TOPLEFT', 0, -500); tip:SetWidth(440); tip:SetTextColor(0.7, 0.68, 0.62)
 tip:SetText('Meslek penceresini (K) açınca yanında "Puan için ne yapmalı?" listesi çıkar: turuncu tarifler kesin puan verir, eksik malzemeler yazılır, tek tıkla yaparsın.')
 holder:HookScript('OnShow', function() pcall(FT.RefreshProfessionPage) end)
end

function FT.RefreshProfessionPage()
 if not (page and page:IsShown()) then return end
 local mine = FT.MyProfessions()
 local recs = REC[classToken() or ''] or REC.WARRIOR
 for i, line in ipairs(page.recs) do
  local r = recs[i]
  if r then
   local p1, p2 = BY_KEY[r[1]], BY_KEY[r[2]]
   local has = (mine[r[1]] and mine[r[2]]) and ' |cff55ff55(sende var)|r' or ''
   line:SetText(('|cffffd100%s + %s|r%s\n|cffbdb6a8%s|r'):format(p1.tr, p2.tr, has, r[3]))
  elseif i == #page.recs then
   line:SetText('|cffffd100Para için:|r iki toplama mesleği (Bitki toplama + Madencilik ya da Deri yüzme).')
  else line:SetText('') end
 end
 local list = {}
 for _, p in ipairs(PROFS) do if mine[p.key] and not p.secondary then list[#list + 1] = mine[p.key] end end
 for _, p in ipairs(PROFS) do if mine[p.key] and p.secondary then list[#list + 1] = mine[p.key] end end
 for i, row in ipairs(page.rows) do
  local e = list[i]
  if e then
   row.key = e.def.key
   row.icon:SetTexture(e.def.icon)
   row.name:SetText(('%s  |cff9aa0a6%d / %d|r'):format(e.def.tr, e.rank, e.max))
   local frac = e.max > 0 and math.min(1, e.rank / e.max) or 0
   row.bar:SetWidth(math.max(1, 250 * frac))
   local hot = e.max > 0 and e.rank >= e.max - 10
   row.bar:SetColorTexture(hot and 1 or 0.4, hot and 0.6 or 0.85, hot and 0.2 or 0.4, 1)
   local advice = FT.ProfessionAdvice(e)
   row.note:SetText(advice)
   row:Show()
  elseif i == 1 then
   row.key = nil; row.icon:SetTexture('Interface\\Icons\\INV_Misc_QuestionMark'); row.name:SetText('Henüz mesleğin yok')
   row.bar:SetWidth(1); row.note:SetText('Yukarıdaki öneriden birini seç; eğitmene gitmek için önerinin adını Yol sor\'da ara.')
   row:Show()
  else row:Hide() end
 end
 local side = {}
 for _, k in ipairs({'cook', 'aid', 'fish'}) do
  local p, e = BY_KEY[k], mine[k]
  local why = ({cook = 'Kampta yemek bonusu verir; XP ve stat için önemli.', aid = 'Bandajla savaş sonrası hızlı can.', fish = 'Yemek için balık ve para.'})[k]
  side[#side + 1] = ('%s%s|r — %s%s'):format(e and '|cff55ff55' or '|cffffd100', p.tr, why, e and (' (' .. e.rank .. '/' .. e.max .. ')') or ' |cff9aa0a6(yok)|r')
 end
 page.side:SetText(table.concat(side, '\n'))
end

----------------------------------------------------------------------
-- Olaylar: sınır uyarısı ve meslek penceresi
----------------------------------------------------------------------
local warned = {}
local ev = CreateFrame('Frame')
for _, e in ipairs({'SKILL_LINES_CHANGED', 'TRADE_SKILL_SHOW', 'TRADE_SKILL_UPDATE', 'TRADE_SKILL_LIST_UPDATE', 'CRAFT_SHOW', 'CRAFT_UPDATE', 'BAG_UPDATE_DELAYED', 'ADDON_LOADED', 'PLAYER_LEVEL_UP'}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript('OnEvent', function(_, event, a)
 local ok, err = pcall(function()
  if event == 'ADDON_LOADED' then
   if a == 'Blizzard_TradeSkillUI' then hookFrame(_G.TradeSkillFrame) end
   if a == 'Blizzard_CraftUI' then hookFrame(_G.CraftFrame) end
   if a == 'Blizzard_Professions' then hookFrame(_G.ProfessionsFrame) end
  elseif event == 'TRADE_SKILL_SHOW' then hookFrame(_G.ProfessionsFrame or _G.TradeSkillFrame); refreshHelper()
  elseif event == 'CRAFT_SHOW' then hookFrame(_G.CraftFrame); refreshHelper()
  elseif event == 'TRADE_SKILL_UPDATE' or event == 'TRADE_SKILL_LIST_UPDATE' or event == 'CRAFT_UPDATE' or event == 'BAG_UPDATE_DELAYED' then refreshHelper()
  elseif (event == 'SKILL_LINES_CHANGED' or event == 'PLAYER_LEVEL_UP') and on('profwarn') then
   for key, e in pairs(FT.MyProfessions()) do
    local advice, canTrain = FT.ProfessionAdvice(e)
    local tag = key .. ':' .. e.max
    if canTrain and not warned[tag] and e.rank >= e.max - 5 then
     warned[tag] = true
     local t = FT.ProfessionTrainer(key)
     if FT.ShowChoice and FT.ShowChoice(e.def.tr .. ' sınırda', e.def.icon, ('%d/%d — %s\nEğitmen: %s'):format(e.rank, e.max, advice:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''), t and t.name or '?'), 'Yol göster', function() goTrainer(key) end) then return end
    end
   end
   if FT.RefreshProfessionPage then pcall(FT.RefreshProfessionPage) end
  end
 end)
 if not ok and FT.errors and #FT.errors < 20 then FT.errors[#FT.errors + 1] = 'prof: ' .. tostring(err) end
end)
