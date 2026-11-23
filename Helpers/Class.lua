local _, FT = ...

-- Sınıf rehberi: yetenek planı (WoW Forever seviye dizileri), seviye atlama kartı,
-- sınıf görevleri (iblis, evcil hayvan, form, totem, binek...) ve avcı için evcilleştirilebilir hayvanlar.

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function optedIn(key) return ForeverTrailSettings and ForeverTrailSettings[key] == true end
local function char()
 ForeverTrailCharacter = ForeverTrailCharacter or {}
 return ForeverTrailCharacter
end
local function classToken() local _, t = UnitClass('player'); return t end
local function after(s, fn) if C_Timer and C_Timer.After then C_Timer.After(s, fn) else fn() end end
local function font(fs, size, flags)
 if fs:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', size, flags or '') == false then fs:SetFont('Fonts\\ARIALN.TTF', size, flags or '') end
 fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.9)
end
local function text(parent, size, flags, justify)
 local fs = parent:CreateFontString(nil, 'OVERLAY'); font(fs, size, flags); fs:SetJustifyH(justify or 'LEFT'); return fs
end
local function combat() return InCombatLockdown and InCombatLockdown() end

----------------------------------------------------------------------
-- 1) Yetenek planı: çözümleme ve oyundaki ağaçla eşleştirme
----------------------------------------------------------------------
local ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
local function decode(o)
 local list = {}
 o = (o or ''):gsub('^s', '')
 for ch in o:gmatch('.') do
  local g = ALPHA:find(ch, 1, true)
  if g then g = g - 1; list[#list + 1] = {tree = math.floor(g / 20) + 1, idx = g % 20} end
 end
 return list
end
FT.DecodeTalentOrder = decode

local function tabName(tab)
 return FT.Compat.TalentTabName(tab)
end
FT.TalentTabName = tabName

local function talentsOf(tab, sorted)
 local out = {}
 local n = FT.Compat.NumTalents(tab)
 for i = 1, n do
  local t = FT.Compat.TalentInfo(tab, i)
  if t then out[#out + 1] = {tab = tab, i = i, name = t.name, icon = t.icon, tier = tonumber(t.tier) or 1, col = tonumber(t.col) or 1, max = tonumber(t.max) or 1} end
 end
 if sorted then table.sort(out, function(a, b) if a.tier ~= b.tier then return a.tier < b.tier end return a.col < b.col end) end
 return out
end

local function rankOf(t)
 local x = FT.Compat.TalentInfo(t.tab, t.i)
 return x and tonumber(x.rank) or 0
end

-- Sıra listesini oyundaki yeteneklere çevir; kurallara uymuyorsa diğer sıralamayı dene
local function resolve(order)
 local tries = {true, false}
 local lastErr
 for _, sorted in ipairs(tries) do
  local trees = {talentsOf(1, sorted), talentsOf(2, sorted), talentsOf(3, sorted)}
  local steps, count, inTree, ok = {}, {}, {0, 0, 0}, true
  for n, e in ipairs(order) do
   local t = trees[e.tree] and trees[e.tree][e.idx + 1]
   if not t then ok = false; lastErr = ('%d. puan: ağaçta yetenek yok'):format(n); break end
   count[t] = (count[t] or 0) + 1
   if count[t] > t.max then ok = false; lastErr = ('%s en fazla %d puan alır'):format(t.name, t.max); break end
   if inTree[e.tree] < (t.tier - 1) * 5 then ok = false; lastErr = ('%s için ağaçta %d puan gerekir'):format(t.name, (t.tier - 1) * 5); break end
   inTree[e.tree] = inTree[e.tree] + 1
   steps[#steps + 1] = {level = 9 + n, talent = t, rank = count[t]}
  end
  if ok and #steps > 0 then return steps end
 end
 return nil, lastErr
end

function FT.TalentBuildsForClass()
 return (FT.TalentBuilds or {})[classToken() or ''] or {}
end

function FT.CurrentBuild()
 local c = char()
 if c.talentCustom and c.talentBuild == 'ozel' then return c.talentCustom end
 for _, b in ipairs(FT.TalentBuildsForClass()) do if b.key == c.talentBuild then return b end end
 for _, b in ipairs(FT.TalentBuildsForClass()) do if b.recommended then return b end end
 return FT.TalentBuildsForClass()[1]
end

-- Forever'da klasik yetenek API'si yok (ağaçlar C_Traits ile): plan OneForAll'ın "Yetenek Ağaçları" sekmesine bırakılır.
FT.TALENT_EXTERNAL = 'Bu istemcide yetenek ağacı ForeverTrail tarafından okunamıyor. Plan için OneForAll > Yetenek Ağaçları kullanılır (/ftrail yetenek).'
function FT.TalentTreeReadable() return (FT.Compat.NumTalents(1) or 0) > 0 end
function FT.TalentPlannerAvailable() return type(_G.OneForAll_Binding) == 'function' end
function FT.OpenTalentPlanner()
 if not FT.TalentPlannerAvailable() then
  FT.Print('Yetenek planı için OneForAll eklentisi gerekir (kurulu ve etkin değil).')
  return false
 end
 local ok, err = pcall(_G.OneForAll_Binding, 'talents')
 if not ok then FT.Print('OneForAll yetenek sekmesi açılamadı: ' .. tostring(err)); return false end
 return true
end
-- Arayüz satırı: dış planlayıcıya yönlendirme ya da gerçek eşleşme hatası
function FT.TalentPlanMessage(err)
 if err == FT.TALENT_EXTERNAL then
  return '|cffffd060' .. err .. (FT.TalentPlannerAvailable() and '' or ' (OneForAll kurulu değil)') .. '|r'
 end
 return '|cffff7070Plan oyundaki ağaçla uyuşmadı:|r ' .. tostring(err or 'bu sınıf için plan yok')
end

local planCache, planKey
function FT.TalentPlan()
 local b = FT.CurrentBuild()
 if not b then return nil, 'Bu sınıf için plan yok' end
 if not FT.TalentTreeReadable() then return nil, FT.TALENT_EXTERNAL end
 local key = b.o .. FT.Compat.NumTalents(1)
 if planKey == key and planCache then return planCache end
 local steps, err = resolve(decode(b.o))
 if not steps then return nil, err end
 planCache, planKey = steps, key
 return steps
end

function FT.SetTalentBuild(key)
 char().talentBuild = key
 planCache, planKey = nil, nil
 if FT.RefreshClassPage then pcall(FT.RefreshClassPage) end
end

-- Sıradaki adım ve plandan sapma
function FT.NextTalent()
 local steps = FT.TalentPlan()
 if not steps then return nil end
 local need, ranks = {}, {}
 for n, s in ipairs(steps) do
  local t = s.talent
  need[t] = (need[t] or 0) + 1
  ranks[t] = ranks[t] or rankOf(t)
  if ranks[t] < need[t] then return s, n end
 end
end

function FT.TalentDeviation()
 local steps = FT.TalentPlan()
 if not steps then return {} end
 local planned = {}
 for _, s in ipairs(steps) do planned[s.talent.tab .. ':' .. s.talent.i] = (planned[s.talent.tab .. ':' .. s.talent.i] or 0) + 1 end
 local off = {}
 for tab = 1, 3 do
  for _, t in ipairs(talentsOf(tab, false)) do
   local r = rankOf(t)
   if r > (planned[tab .. ':' .. t.i] or 0) then off[#off + 1] = t.name end
  end
 end
 return off
end

function FT.LearnNextTalent()
 if not FT.TalentTreeReadable() then return FT.OpenTalentPlanner() end
 if combat() then return FT.Print('Savaşta yetenek öğrenilemez.') end
 local s = FT.NextTalent()
 local pts = FT.Compat.UnspentPoints()
 if not s then return FT.Print('Plan tamamlandı.') end
 if (pts or 0) <= 0 then return FT.Print('Harcanacak yetenek puanın yok.') end
 FT.Compat.LearnTalent(s.talent.tab, s.talent.i)
 FT.Print(('Öğrenildi: %s %d/%d (%s)'):format(s.talent.name, s.rank, s.talent.max, tabName(s.talent.tab)))
 after(0.4, function() if FT.RefreshClassPage then pcall(FT.RefreshClassPage) end; if FT.RefreshLevelCard then pcall(FT.RefreshLevelCard) end end)
end

-- Önemli yetenekler (tek puanlık, 3. sıra ve üstü)
function FT.TalentMilestones(fromLevel, count)
 local out = {}
 for _, s in ipairs(FT.TalentPlan() or {}) do
  if s.level >= (fromLevel or 0) and s.talent.max == 1 and s.talent.tier >= 3 then
   out[#out + 1] = s
   if #out >= (count or 3) then break end
  end
 end
 return out
end

-- Kendi plan bağlantını yapıştır (kami-labs builder bağlantısı ya da yalnızca o= dizisi)
function FT.ImportTalentLink(link)
 link = link or ''
 local o = link:match('[?&]o=([%w]+)') or link:match('^s?[%w]+$') and link
 if not o or #o < 10 then return FT.Print('Bağlantıda yetenek sırası (o=) bulunamadı.') end
 local steps, err = resolve(decode(o))
 if not steps then return FT.Print(err == FT.TALENT_EXTERNAL and err or ('Plan oyundaki ağaçla uyuşmadı: ' .. (err or '?'))) end
 char().talentCustom = {key = 'ozel', name = 'Kendi planım', desc = 'Yapıştırdığın bağlantıdan', o = o, t = link:match('[?&]t=([%w%-]+)') or ''}
 FT.SetTalentBuild('ozel')
 FT.Print(('Kendi planın yüklendi: %d puan.'):format(#steps))
end

----------------------------------------------------------------------
-- 2) Sınıf görevleri
----------------------------------------------------------------------
local function hasBit(mask, bit)
 if type(mask) ~= 'number' or mask == 0 then return true end
 return math.floor(mask / 2 ^ bit) % 2 == 1
end
local HINTS = {
 {'Voidwalker', 'Hiçlik Yürüyeni — tank iblis'}, {'Succubus', 'Sukkubus — kontrol iblisi'}, {'Sayaad', 'Sayaad — kontrol iblisi'},
 {'Felhunter', 'Kötü Ruh Avcısı — büyü kesen iblis'}, {'Infernal', 'Cehennem iblisi'}, {'Doomguard', 'Kıyamet Muhafızı'},
 {'Felsteed', 'Büyücü bineği'}, {'Dreadsteed', 'Büyücü epik bineği'}, {'Imp', 'İmp'},
 {'Taming the Beast', 'Avcı: evcilleştirmeyi öğren'}, {'Training the Beast', 'Avcı: evcil hayvan eğitimi'}, {'Beast', 'Avcı: evcil hayvan'},
 {'Bear', 'Druid: ayı formu'}, {'Aquatic', 'Druid: su formu'}, {'Cat', 'Druid: kedi formu'}, {'Moonglow', 'Druid'},
 {'Earth', 'Şaman: Toprak totemi'}, {'Fire', 'Şaman: Ateş totemi'}, {'Water', 'Şaman: Su totemi'}, {'Air', 'Şaman: Hava totemi'},
 {'Charger', 'Paladin epik bineği'}, {'Warhorse', 'Paladin bineği'}, {'Redemption', 'Paladin: diriltme'},
 {'Defensive', 'Savaşçı: Savunma duruşu'}, {'Berserker', 'Savaşçı: Öfke duruşu'}, {'Bloodrage', 'Savaşçı'},
 {'Poison', 'Haydut: zehirler'}, {'Lockpick', 'Haydut: kilit açma'},
}
local function hintFor(title)
 for _, h in ipairs(HINTS) do if title:find(h[1], 1, true) then return h[2] end end
end

local cqCache, cqTime = nil, -100
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() cqCache = nil end
function FT.ClassQuests()
 if cqCache and GetTime() - cqTime < 5 then return cqCache end
 local out = {}
 local raceId = select(3, UnitRace('player')) or 0
 local classId = select(3, UnitClass('player')) or 0
 for id, q in pairs(FT.DBQ or {}) do
  if type(q[7]) == 'number' and q[7] > 0 and hasBit(q[7], classId - 1) and hasBit(q[6], raceId - 1) and q[2] then
   local title = FT.QuestTitle and FT.QuestTitle(id) or (type(q[1]) == 'string' and q[1]) or ('Görev ' .. id)
   local status = FT.QuestStatus and FT.QuestStatus(id) or ''
   out[#out + 1] = {id = id, title = title, level = q[4] or 1, qlevel = q[5] or q[4] or 1, status = status,
    done = status:find('Tamamlandı') ~= nil, hint = hintFor(type(q[1]) == 'string' and q[1] or title)}
  end
 end
 table.sort(out, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.id < b.id end)
 cqCache, cqTime = out, GetTime()
 return out
end

-- Bu seviyede/öncesinde alınabilir ama yapılmamış önemli sınıf görevleri
function FT.OpenClassQuests(limit)
 local level = UnitLevel('player') or 1
 local out = {}
 for _, q in ipairs(FT.ClassQuests()) do
  if not q.done and q.level <= level + 2 then out[#out + 1] = q; if #out >= (limit or 6) then break end end
 end
 return out
end

----------------------------------------------------------------------
-- 3) Avcı: evcilleştirilebilir hayvanlar
----------------------------------------------------------------------
local FAMILIES = {
 {'cat', {'Cat', 'Lynx', 'Panther', 'Tiger', 'Leopard', 'Jaguar', 'Sabercat', 'Prowler', 'Lion', 'Bobcat', 'Nightsaber', 'Shadowmaw', 'Frostsaber', 'Stalker'}, 'Kedi — en yüksek hasar, seviye atlamada en iyi'},
 {'boar', {'Boar', 'Bristleback'}, 'Yaban domuzu — hücum eder, sağlam'},
 {'bear', {'Bear', 'Grizzly', 'Ursa'}, 'Ayı — en dayanıklı tank'},
 {'wolf', {'Wolf', 'Worg', 'Coyote'}, 'Kurt — uluma ile grup hasarı'},
 {'raptor', {'Raptor'}, 'Raptor — iyi hasar'},
 {'gorilla', {'Gorilla', 'Silverback', 'Ape'}, 'Goril — toplu yaratıkta Gümbürtü'},
 {'crab', {'Crab', 'Clacker'}, 'Yengeç — çok sağlam'},
 {'turtle', {'Turtle', 'Snapjaw', 'Tortoise'}, 'Kaplumbağa — en sağlam'},
 {'croc', {'Crocolisk'}, 'Timsah — sağlam'},
 {'scorpid', {'Scorpid'}, 'Akrep — zehir'},
 {'spider', {'Spider', 'Tarantula', 'Widow', 'Recluse'}, 'Örümcek — ağ ile tutar'},
 {'owl', {'Owl'}, 'Baykuş — çığlık'}, {'bat', {'Bat'}, 'Yarasa — çığlık'},
 {'carrion', {'Vulture', 'Buzzard', 'Carrion'}, 'Leş kuşu'}, {'hyena', {'Hyena'}, 'Sırtlan'},
 {'strider', {'Strider'}, 'Uzunbacak — hızlı'}, {'serpent', {'Wind Serpent', 'Serpent'}, 'Rüzgar yılanı — şimşek nefesi'},
}
local tameCache = {}
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() tameCache = {} end
function FT.TameableOn(mapID)
 local level = UnitLevel('player') or 1
 local key = mapID .. ':' .. level
 if tameCache[key] then return tameCache[key] end
 local out = {}
 local z = FT.Module and FT.Module('ZoneDB')
 if z then
  for id, n in pairs(FT.DBN or {}) do
   local name = n[1]
   if type(name) == 'string' and not n[10] and (n[3] or 99) <= level and (n[3] or 0) >= level - 12 and type(n[5]) == 'table' and (n[4] == 0 or n[4] == 4 or n[4] == nil) then
    local fam
    for _, f in ipairs(FAMILIES) do
     for _, w in ipairs(f[2]) do if name:find(w, 1, true) then fam = f; break end end
     if fam then break end
    end
    if fam then
     for area, list in pairs(n[5]) do
      if z:GetUiMapIdByAreaId(area) == mapID and list[1] then
       out[#out + 1] = {id = id, name = name, level = n[3], rare = n[4] == 4, family = fam[1], note = fam[3], map = mapID, x = list[1] / 1000, y = list[2] / 1000}
       break
      end
     end
    end
   end
  end
 end
 local pref = {cat = 1, boar = 2, bear = 3, wolf = 4, raptor = 5}
 table.sort(out, function(a, b)
  if a.rare ~= b.rare then return a.rare end
  local pa, pb = pref[a.family] or 9, pref[b.family] or 9
  if pa ~= pb then return pa < pb end
  return (a.level or 0) > (b.level or 0)
 end)
 tameCache[key] = out
 return out
end

----------------------------------------------------------------------
-- 4) Seviye atlama kartı
----------------------------------------------------------------------
local card
local function trainerSpells(level)
 local list, cost = {}, 0
 for _, s in ipairs(char().trainer or {}) do
  if s.level and s.level > 0 and s.level <= level then
   list[#list + 1] = s.name .. (s.rank and s.rank ~= '' and (' (' .. s.rank .. ')') or '')
   cost = cost + (s.cost or 0)
  end
 end
 return list, cost
end

local function section(parent, y, title)
 local h = text(parent, 12, 'OUTLINE'); h:SetPoint('TOPLEFT', 14, y)
 local a = FT.Style.accent; h:SetTextColor(a[1], a[2], a[3]); h:SetText(title)
 return h
end

local function ensureCard()
 if card then return card end
 card = FT.NewWindow('ForeverTrailLevelCard', UIParent)
 card:SetSize(380, 360); card:SetPoint('TOP', UIParent, 'TOP', 0, -120); card:SetFrameStrata('DIALOG')
 card:SetMovable(true); card:EnableMouse(true); card:RegisterForDrag('LeftButton')
 card:SetScript('OnDragStart', function(self) self:StartMoving() end)
 card:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
 card.title = text(card, 18, 'OUTLINE', 'CENTER'); card.title:SetPoint('TOP', 0, -10)
 if FT.StyleTitle then FT.StyleTitle(card.title); font(card.title, 18, 'OUTLINE') end
 card.blocks = {}
 local function block(key, label, btnLabel, onClick)
  local b = CreateFrame('Frame', nil, card); b:SetSize(352, 56)
  b.head = text(b, 12, 'OUTLINE'); b.head:SetPoint('TOPLEFT', 0, 0); b.head:SetText(label)
  b.icon = b:CreateTexture(nil, 'ARTWORK'); b.icon:SetSize(30, 30); b.icon:SetPoint('TOPLEFT', 0, -18); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.body = text(b, 12, ''); b.body:SetPoint('TOPLEFT', 38, -18); b.body:SetWidth(220); b.body:SetJustifyV('TOP')
  b.body:SetTextColor(1, 0.94, 0.82)
  if btnLabel then
   b.btn = FT.NewButton(b, btnLabel, 86, 22); b.btn:SetPoint('TOPRIGHT', 0, -20)
   b.btn:SetScript('OnClick', function() onClick(b) end)
  end
  card.blocks[key] = b
  return b
 end
 block('talent', 'Yetenek puanı', 'Öğren', function() FT.LearnNextTalent() end)
 block('trainer', 'Eğitmen', 'Yol göster', function(b)
  local t = FT.ClassTrainer and FT.ClassTrainer()
  if t then FT.SetCustomTarget(t.map, t.x, t.y, t.name) else FT.Print('Sınıf eğitmeninin yeri bulunamadı.') end
 end)
 block('quest', 'Sınıf görevi', 'Yol göster', function(b) if b.questId and FT.GoToQuest then FT.GoToQuest(b.questId) end end)
 block('pet', 'Evcil hayvan', 'Yol göster', function(b) local p = b.pet; if p then FT.SetCustomTarget(p.map, p.x, p.y, p.name) end end)
 card.next = text(card, 11, '', 'CENTER'); card.next:SetPoint('BOTTOM', 0, 44); card.next:SetWidth(350); card.next:SetTextColor(0.75, 0.72, 0.65)
 local plan = FT.NewButton(card, 'Sınıf rehberi', 110, 24); plan:SetPoint('BOTTOMLEFT', 14, 12)
 plan:SetScript('OnClick', function() card:Hide(); if FT.OpenHub then FT.OpenHub('sinif') end end)
 local close = FT.NewButton(card, 'Kapat', 90, 24); close:SetPoint('BOTTOMRIGHT', -14, 12)
 close:SetScript('OnClick', function() card:Hide() end)
 if FT.AddShowAnim then FT.AddShowAnim(card) end
 card:Hide()
 if FT.RegisterPopup then FT.RegisterPopup(card) end
 return card
end

function FT.RefreshLevelCard(level)
 if not card or not card:IsShown() then return end
 level = level or card.level or UnitLevel('player') or 1
 card.level = level
 card.title:SetText(('Seviye %d!'):format(level))
 local y = -40
 local function place(b, show)
  if show then b:ClearAllPoints(); b:SetPoint('TOPLEFT', 14, y); b:Show(); y = y - 62 else b:Hide() end
 end
 -- yetenek
 local b = card.blocks.talent
 local s = FT.NextTalent()
 local pts = FT.Compat.UnspentPoints()
 if s and level >= 10 then
  b.icon:SetTexture(s.talent.icon)
  b.body:SetText(('%s %d/%d\n|cff9aa0a6%s ağacı · harcanmamış: %d|r'):format(s.talent.name, s.rank, s.talent.max, tabName(s.talent.tab), pts or 0))
  if (pts or 0) > 0 then b.btn:Enable() else b.btn:Disable() end
  place(b, true)
 else place(b, false) end
 -- eğitmen
 b = card.blocks.trainer
 local list, cost = trainerSpells(level)
 b.icon:SetTexture('Interface\\Icons\\INV_Misc_Book_09')
 if #list > 0 then
  b.body:SetText(('%d yeni büyü: %s\n|cff9aa0a6Toplam %s|r'):format(#list, table.concat(list, ', '):sub(1, 90), FT.MoneyText and FT.MoneyText(cost) or cost))
 else
  b.body:SetText('Eğitmenine uğra; yeni büyüler olabilir.\n|cff9aa0a6Bir kez uğrayınca liste hatırlanır.|r')
 end
 place(b, level % 2 == 0 or #list > 0)
 -- sınıf görevi
 b = card.blocks.quest
 local cq = FT.OpenClassQuests(1)[1]
 if cq then
  b.questId = cq.id
  b.icon:SetTexture('Interface\\GossipFrame\\AvailableQuestIcon')
  b.body:SetText(('[%d] %s\n|cff9aa0a6%s|r'):format(cq.level, cq.title, cq.hint or 'Sınıfına özel görev'))
  place(b, true)
 else place(b, false) end
 -- evcil hayvan (avcı)
 b = card.blocks.pet
 local pet
 if classToken() == 'HUNTER' and level >= 10 and C_Map and C_Map.GetBestMapForUnit then
  local map = C_Map.GetBestMapForUnit('player')
  pet = map and FT.TameableOn(map)[1]
 end
 if pet then
  b.pet = pet
  b.icon:SetTexture('Interface\\Icons\\Ability_Hunter_BeastTaming')
  b.body:SetText(('%s%s (sv %d)\n|cff9aa0a6%s|r'):format(pet.rare and '|cffffd100Nadir:|r ' or '', pet.name, pet.level or 0, pet.note))
  place(b, true)
 else place(b, false) end
 local ms = FT.TalentMilestones(level + 1, 2)
 local parts = {}
 for _, m in ipairs(ms) do parts[#parts + 1] = ('Seviye %d: %s'):format(m.level, m.talent.name) end
 card.next:SetText(#parts > 0 and ('Sırada önemli yetenekler — ' .. table.concat(parts, ' · ')) or '')
 card:SetHeight(-y + 80)
end

function FT.ShowLevelCard(level)
 if not on('levelcard') then return end
 ensureCard():Show()
 FT.RefreshLevelCard(level)
 if FT.FixFonts then pcall(FT.FixFonts, card) end
end

-- Eski eğitmen uyarısı yerine seviye kartı
local oldTrainerCheck = FT.TrainerCheck
FT.TrainerCheck = function(level)
 if on('levelcard') then return end
 if oldTrainerCheck then return oldTrainerCheck(level) end
end

----------------------------------------------------------------------
-- 5) Yetenek penceresinde sıradaki yeteneği parlat
----------------------------------------------------------------------
local glow
local function updateTalentGlow()
 local frame = FT.Compat.TalentFrame()
 if not (frame and frame:IsShown() and on('talentglow')) then if glow then glow:Hide() end return end
 local s = FT.NextTalent()
 if not s then if glow then glow:Hide() end return end
 local tab = (PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(frame)) or frame.selectedTab or 1
 local prefix = frame == _G.TalentFrame and 'TalentFrameTalent' or 'PlayerTalentFrameTalent'
 local button = _G[prefix .. s.talent.i]
 if not glow then
  glow = UIParent:CreateTexture(nil, 'OVERLAY')
  glow:SetTexture('Interface\\Buttons\\CheckButtonHilight'); glow:SetBlendMode('ADD')
 end
 if button and tab == s.talent.tab then
  glow:SetParent(button); glow:SetDrawLayer('OVERLAY', 7); glow:ClearAllPoints(); glow:SetPoint('TOPLEFT', -6, 6); glow:SetPoint('BOTTOMRIGHT', 6, -6)
  glow:SetVertexColor(0.3, 1, 0.3); glow:Show()
 else glow:Hide() end
 if not frame.ftHint then
  frame.ftHint = text(frame, 12, 'OUTLINE', 'CENTER'); frame.ftHint:SetPoint('BOTTOM', frame, 'TOP', 0, 2)
 end
 frame.ftHint:SetText(('Plan: sıradaki |cff55ff55%s %d/%d|r (%s)'):format(s.talent.name, s.rank, s.talent.max, tabName(s.talent.tab)))
end
FT.UpdateTalentGlow = updateTalentGlow

----------------------------------------------------------------------
-- 6) Sınıf sayfası (ana pencere)
----------------------------------------------------------------------
local page
function FT.BuildClassPage(holder)
 if page or not holder then return end
 page = holder
 local W = 440
 local h = section(holder, -2, 'Yetenek planı'); h:SetPoint('TOPLEFT', 2, -2)
 page.cards = {}
 for i = 1, 3 do
  local c = CreateFrame('Button', nil, holder)
  c:SetSize(142, 92); c:SetPoint('TOPLEFT', (i - 1) * 148, -20)
  c.border = c:CreateTexture(nil, 'BACKGROUND'); c.border:SetAllPoints()
  c.bg = c:CreateTexture(nil, 'BORDER'); c.bg:SetPoint('TOPLEFT', 1, -1); c.bg:SetPoint('BOTTOMRIGHT', -1, 1)
  if FT.Kit then FT.Kit.Fill(c.bg, 'card') else c.bg:SetColorTexture(0.06, 0.06, 0.08, 0.95) end
  c.name = text(c, 12, 'OUTLINE'); c.name:SetPoint('TOPLEFT', 6, -6); c.name:SetWidth(130)
  c.badge = text(c, 10, ''); c.badge:SetPoint('TOPLEFT', 6, -22); c.badge:SetTextColor(0.4, 1, 0.4)
  c.desc = text(c, 10, ''); c.desc:SetPoint('TOPLEFT', 6, -36); c.desc:SetWidth(130); c.desc:SetJustifyV('TOP'); c.desc:SetTextColor(0.8, 0.77, 0.7)
  c:SetScript('OnClick', function(self) if self.key then FT.SetTalentBuild(self.key) end end)
  page.cards[i] = c
 end
 page.nextIcon = holder:CreateTexture(nil, 'ARTWORK'); page.nextIcon:SetSize(30, 30); page.nextIcon:SetPoint('TOPLEFT', 0, -120)
 page.nextText = text(holder, 12, ''); page.nextText:SetPoint('TOPLEFT', 38, -121); page.nextText:SetWidth(232)
 page.learn = FT.NewButton(holder, 'Öğren', 90, 22); page.learn:SetPoint('TOPLEFT', 246, -122)
 page.learn:SetScript('OnClick', FT.LearnNextTalent)
 page.import = FT.NewButton(holder, 'Kendi planım', 98, 22); page.import:SetPoint('TOPLEFT', 342, -122)
 page.import:SetScript('OnClick', function()
  if not page.box then
   page.box = (FT.Kit and FT.Kit.Input(holder) or CreateFrame('EditBox', nil, holder, 'InputBoxTemplate')); page.box:SetSize(420, 20); page.box:SetPoint('TOPLEFT', 6, -152)
   page.box:SetAutoFocus(true)
   page.box:SetScript('OnEnterPressed', function(self) FT.ImportTalentLink(self:GetText()); self:Hide() end)
   page.box:SetScript('OnEscapePressed', function(self) self:Hide() end)
  end
  page.box:SetText(''); page.box:Show()
  FT.Print('kami-labs.fr builder bağlantısını yapıştırıp Enter\'a bas.')
 end)
 -- 51 adımlık ikon ızgarası
 page.cells = {}
 for n = 1, 51 do
  local c = CreateFrame('Frame', nil, holder); c:SetSize(24, 34)
  c:SetPoint('TOPLEFT', ((n - 1) % 17) * 26, -158 - math.floor((n - 1) / 17) * 38)
  c.icon = c:CreateTexture(nil, 'ARTWORK'); c.icon:SetSize(22, 22); c.icon:SetPoint('TOP'); c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  c.ring = c:CreateTexture(nil, 'OVERLAY'); c.ring:SetTexture('Interface\\Buttons\\CheckButtonHilight'); c.ring:SetBlendMode('ADD')
  c.ring:SetPoint('TOPLEFT', c.icon, -4, 4); c.ring:SetPoint('BOTTOMRIGHT', c.icon, 4, -4)
  c.lvl = text(c, 9, ''); c.lvl:SetPoint('BOTTOM', 0, 0)
  c:EnableMouse(true)
  c:SetScript('OnEnter', function(self)
   local s = self.step; if not s then return end
   GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
   GameTooltip:SetText(('Seviye %d: %s %d/%d'):format(s.level, s.talent.name, s.rank, s.talent.max), 1, 0.85, 0.5)
   GameTooltip:AddLine(tabName(s.talent.tab) .. ' ağacı', 0.8, 0.8, 0.8)
   if FT.ShowTip then FT.ShowTip(GameTooltip) else GameTooltip:Show() end
  end)
  c:SetScript('OnLeave', function() GameTooltip:Hide() end)
  page.cells[n] = c
 end
 page.milestones = text(holder, 11, ''); page.milestones:SetPoint('TOPLEFT', 0, -276); page.milestones:SetWidth(W); page.milestones:SetTextColor(0.8, 0.77, 0.7)
 page.warn = text(holder, 11, ''); page.warn:SetPoint('TOPLEFT', 0, -292); page.warn:SetWidth(W); page.warn:SetTextColor(1, 0.55, 0.35)
 -- sınıf görevleri
 page.qHead = section(holder, -312, 'Sınıf görevleri'); page.qHead:SetPoint('TOPLEFT', 2, -312)
 page.qrows = {}
 for i = 1, 7 do
  local r = CreateFrame('Button', nil, holder); r:SetSize(W, 22); r:SetPoint('TOPLEFT', 0, -330 - (i - 1) * 23)
  r:SetHighlightTexture('Interface\\Buttons\\WHITE8X8'); r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
  r.title = text(r, 12, ''); r.title:SetPoint('LEFT', 4, 0); r.title:SetWidth(250); r.title:SetWordWrap(false)
  r.hint = text(r, 10, ''); r.hint:SetPoint('LEFT', 258, 0); r.hint:SetWidth(120); r.hint:SetWordWrap(false); r.hint:SetTextColor(0.7, 0.68, 0.62)
  r.go = text(r, 11, '', 'RIGHT'); r.go:SetPoint('RIGHT', -4, 0)
  r:SetScript('OnClick', function(self) if self.q and FT.GoToQuest then FT.GoToQuest(self.q.id) end end)
  page.qrows[i] = r
 end
 -- evcil hayvanlar (avcı)
 page.petHead = section(holder, -496, 'Bu bölgede evcilleştirilebilir'); page.petHead:SetPoint('TOPLEFT', 2, -496)
 page.prows = {}
 for i = 1, 4 do
  local r = CreateFrame('Button', nil, holder); r:SetSize(W, 22); r:SetPoint('TOPLEFT', 0, -514 - (i - 1) * 23)
  r:SetHighlightTexture('Interface\\Buttons\\WHITE8X8'); r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
  r.title = text(r, 12, ''); r.title:SetPoint('LEFT', 4, 0); r.title:SetWidth(190); r.title:SetWordWrap(false)
  r.note = text(r, 10, ''); r.note:SetPoint('LEFT', 196, 0); r.note:SetWidth(230); r.note:SetWordWrap(false); r.note:SetTextColor(0.7, 0.68, 0.62)
  r:SetScript('OnClick', function(self) local p = self.pet; if p then FT.SetCustomTarget(p.map, p.x, p.y, p.name) end end)
  page.prows[i] = r
 end
 -- Yetenek ızgarası kullanılamıyorsa (bu istemcide ağaç okunamaz) alttaki bölümler boşluğu kapatmak için yukarı kayar
 page.lower = {}
 local function track(el, x, y) page.lower[#page.lower + 1] = {el = el, x = x, y = y} end
 track(page.milestones, 0, -276); track(page.warn, 0, -292); track(page.qHead, 2, -312)
 for i, r in ipairs(page.qrows) do track(r, 0, -330 - (i - 1) * 23) end
 track(page.petHead, 2, -496)
 for i, r in ipairs(page.prows) do track(r, 0, -514 - (i - 1) * 23) end
 holder:HookScript('OnShow', function() pcall(FT.RefreshClassPage) end)
end

function FT.RefreshClassPage()
 if not (page and page:IsShown()) then return end
 local a = FT.Style.accent
 local builds = FT.TalentBuildsForClass()
 local cur = FT.CurrentBuild()
 for i, c in ipairs(page.cards) do
  local b = builds[i]
  if b then
   c.key = b.key
   c.name:SetText(b.name)
   local split = {}
   for tr in ((b.t or ''):gsub('^s', '') .. '--'):gmatch('([^-]*)-') do
    local sum = 0; for d in tr:gmatch('%d') do sum = sum + tonumber(d) end; split[#split + 1] = sum
   end
   c.badge:SetText((b.recommended and '★ Önerilen  ' or '') .. ('|cff9aa0a6%d/%d/%d|r'):format(split[1] or 0, split[2] or 0, split[3] or 0))
   c.desc:SetText(b.desc or '')
   local sel = cur and cur.key == b.key
   local lc = FT.Kit and FT.Kit.Color('line') or {0.3, 0.3, 0.3}
   c.border:SetColorTexture(sel and a[1] or lc[1], sel and a[2] or lc[2], sel and a[3] or lc[3], 1)
   c:Show()
  else c:Hide() end
 end
 local steps, err = FT.TalentPlan()
 local shift = steps and 0 or 116
 if page.shift ~= shift then
  page.shift = shift
  for _, t in ipairs(page.lower) do t.el:ClearAllPoints(); t.el:SetPoint('TOPLEFT', t.x, t.y + shift) end
 end
 local s, idx = FT.NextTalent()
 local pts = FT.Compat.UnspentPoints()
 if s then
  page.nextIcon:SetTexture(s.talent.icon); page.nextIcon:Show()
  page.nextText:SetText(('Sıradaki (seviye %d): |cff55ff55%s %d/%d|r\n|cff9aa0a6%s ağacı · harcanmamış puan: %d|r'):format(s.level, s.talent.name, s.rank, s.talent.max, tabName(s.talent.tab), pts or 0))
 elseif steps then
  page.nextIcon:Hide(); page.nextText:SetText('|cff55ff55Plan tamamlandı.|r')
 else
  page.nextIcon:Hide(); page.nextText:SetText(FT.TalentPlanMessage(err))
 end
 if (pts or 0) > 0 and s then page.learn:Enable() else page.learn:Disable() end
 for n, c in ipairs(page.cells) do
  local st = steps and steps[n]
  c.step = st
  if st then
   c.icon:SetTexture(st.talent.icon)
   local done = idx and n < idx or (not idx and steps ~= nil)
   c.icon:SetDesaturated(not done and n ~= idx)
   c.icon:SetAlpha((done or n == idx) and 1 or 0.55)
   c.ring:SetShown(n == idx)
   c.lvl:SetText(st.level); c.lvl:SetTextColor(done and 0.4 or 0.8, done and 1 or 0.78, done and 0.4 or 0.7)
   c:Show()
  else c:Hide() end
 end
 local ms = FT.TalentMilestones((UnitLevel('player') or 1) + 1, 3)
 local parts = {}
 for _, m in ipairs(ms) do parts[#parts + 1] = ('sv %d %s'):format(m.level, m.talent.name) end
 page.milestones:SetText(#parts > 0 and ('Sıradaki önemli yetenekler: ' .. table.concat(parts, ', ')) or '')
 local off = FT.TalentDeviation()
 page.warn:SetText(#off > 0 and ('Plan dışı puanlar: ' .. table.concat(off, ', ') .. ' (sorun değil, plan kalan puanlarla devam eder)') or '')
 -- sınıf görevleri
 local level = UnitLevel('player') or 1
 local list = {}
 for _, q in ipairs(FT.ClassQuests()) do if not q.done and q.level <= level + 8 then list[#list + 1] = q end end
 for i, r in ipairs(page.qrows) do
  local q = list[i]
  r.q = q
  if q then
   local col = q.level <= level and '|cffffd100' or '|cff9aa0a6'
   r.title:SetText(('%s[%d]|r %s'):format(col, q.level, q.title))
   r.hint:SetText(q.hint or '')
   r.go:SetText(q.level <= level and '|cff55ff55Yol >|r' or ('sv ' .. q.level))
   r:Show()
  else r:Hide() end
 end
 if #list == 0 then page.qrows[1].q = nil; page.qrows[1].title:SetText('|cff9aa0a6Şu an yapılacak sınıf görevi yok.|r'); page.qrows[1].hint:SetText(''); page.qrows[1].go:SetText(''); page.qrows[1]:Show() end
 -- evcil hayvanlar
 local hunter = classToken() == 'HUNTER'
 page.petHead:SetShown(hunter)
 local pets = {}
 if hunter and C_Map and C_Map.GetBestMapForUnit then
  local map = C_Map.GetBestMapForUnit('player')
  pets = map and FT.TameableOn(map) or {}
 end
 for i, r in ipairs(page.prows) do
  local p = hunter and pets[i]
  r.pet = p
  if p then
   r.title:SetText(('%s%s |cff9aa0a6sv %d|r'):format(p.rare and '|cffffd100★|r ' or '', p.name, p.level or 0))
   r.note:SetText(p.note)
   r:Show()
  else r:Hide() end
 end
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local ev = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_LEVEL_UP', 'PLAYER_LOGIN', 'CHARACTER_POINTS_CHANGED', 'ADDON_LOADED', 'QUEST_TURNED_IN', 'TRAINER_SHOW'}) do pcall(ev.RegisterEvent, ev, e) end
local hooked = false
local function autoLearn()
 if not optedIn('autotalent') or combat() then return end
 local pts = FT.Compat.UnspentPoints()
 if (pts or 0) > 0 and FT.NextTalent() then FT.LearnNextTalent(); if pts > 1 then after(0.8, autoLearn) end end
end
ev:SetScript('OnEvent', function(_, event, a)
 local ok, err = pcall(function()
  if event == 'PLAYER_LEVEL_UP' then
   cqCache = nil; tameCache = {}
   after(2, function() autoLearn(); FT.ShowLevelCard(a) end)
  elseif event == 'CHARACTER_POINTS_CHANGED' then
   planCache = planCache; if FT.RefreshClassPage then pcall(FT.RefreshClassPage) end
   pcall(FT.RefreshLevelCard); pcall(updateTalentGlow)
  elseif event == 'PLAYER_LOGIN' then
   after(6, function()
    local pts = FT.Compat.UnspentPoints()
    if (pts or 0) > 0 and (UnitLevel('player') or 1) >= 10 then autoLearn(); if FT.Compat.UnspentPoints() > 0 then FT.ShowLevelCard() end end
   end)
  elseif event == 'QUEST_TURNED_IN' then cqCache = nil
  elseif event == 'ADDON_LOADED' and (a == 'Blizzard_TalentUI' or a == 'Blizzard_PlayerSpells' or a == 'Blizzard_ClassTalentUI') and not hooked then
   hooked = true
   local frame = FT.Compat.TalentFrame()
   if frame then frame:HookScript('OnShow', function() after(0.05, function() pcall(updateTalentGlow) end) end) end
   if TalentFrame_Update then hooksecurefunc('TalentFrame_Update', function() pcall(updateTalentGlow) end) end
   if PlayerTalentFrame_Update then hooksecurefunc('PlayerTalentFrame_Update', function() pcall(updateTalentGlow) end) end
  end
 end)
 if not ok and FT.errors and #FT.errors < 20 then FT.errors[#FT.errors + 1] = 'class: ' .. tostring(err) end
end)
