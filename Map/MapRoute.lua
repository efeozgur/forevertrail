local _, FT = ...

-- Dünya haritasının yanında "Yol sor" paneli: baktığın haritadaki hizmet NPC'leri (gömülü veriden) ve kayıtlı yerler.
-- Çip şeridi (sonuç sayılı), "en yakın" hızlı şeridi, kaydırılabilir liste (yakın/ad/tür sıralaması, favori yıldızı),
-- yerinde açılan satır, haritada işaretler ve aktif hedef kartı. Bir satıra tıklayınca ok, harita güzergahı ve minimap oraya döner.

local FLAGS = {vendor=4, flight=8, trainer=16, inn=128, bank=256, auction=4096, stable=8192, repair=16384}
local CATS = {
 {key='hepsi', label='Hepsi', tip='Bu haritadaki tüm hizmetler ve kayıtlı yerlerin hepsi.'},
 {key='gorev', label='Görev al', tip='Yeni görev alabileceğin yaratıklar ve nesneler (! işareti).'},
 {key='teslim', label='Teslim', tip='Görevini teslim edebileceğin yerler (? işareti).'},
 {key='repair', label='Tamirci', tip='Eşyalarını tamir ettiren tamirciler.'},
 {key='vendor', label='Satıcı', tip='Eşya alıp satabileceğin satıcılar.'},
 {key='inn', label='Han', tip='Han: dinlenme yeri ve ev taşını bağlama noktası.'},
 {key='bank', label='Banka', tip='Eşyalarını saklayabileceğin banka.'},
 {key='flight', label='Uçuş', tip='Uçuş ustası: başka kasabalara hızlıca uçmak için.'},
 {key='trainer', label='Eğitmen', tip='Yeni beceri ve büyü öğreten eğitmenler.'},
 {key='sinif', label='Sınıfım', tip='Kendi sınıfının eğitmenleri ve sınıf görevleri.'},
 {key='meslek', label='Meslek', tip='Meslek eğitmenleri (demircilik, simya, balıkçılık...).'},
 {key='auction', label='Müzayede', tip='Müzayede evi: oyuncularla eşya alıp satmak için.'},
 {key='stable', label='Ahır', tip='Ahır: avcıların evcil hayvanlarını bıraktığı yer.'},
 {key='evcil', label='Evcil', tip='Avcılar için evcil hayvan olarak evcilleştirilebilecek yaratıklar.'},
 {key='zindan', label='Zindan', tip='Zindan girişleri.'},
 {key='nadir', label='Nadir', tip='Nadir (güçlü) yaratıklar; iyi eşya düşürebilirler.'},
 {key='posta', label='Posta', tip='Posta kutuları.'},
 {key='kayit', label='Kayıtlarım', tip='Daha önce "Kaydet" ile eklediğin yerler.'},
}
local CAT_COLOR = {gorev={1,0.82,0.1}, teslim={0.35,0.9,0.4}, repair={0.9,0.55,0.2}, vendor={0.9,0.8,0.5}, inn={0.8,0.6,0.9}, bank={0.9,0.85,0.3},
 flight={0.4,0.75,1}, trainer={0.5,0.85,0.9}, sinif={0.95,0.5,0.5}, meslek={0.6,0.9,0.6}, auction={0.9,0.8,0.3}, stable={0.7,0.55,0.4},
 evcil={0.7,0.55,0.4}, zindan={0.85,0.4,0.4}, nadir={0.8,0.55,1}, posta={0.7,0.7,0.9}, kayit={0.6,0.9,0.9}, npc={0.75,0.75,0.75}}

local CAT_ORDER = {'repair', 'flight', 'inn', 'bank', 'auction', 'stable', 'trainer', 'vendor'}
local CAT_LABEL = {vendor='Satıcı', flight='Uçuş ustası', trainer='Eğitmen', inn='Han', bank='Banka', auction='Müzayede', stable='Ahır', repair='Tamirci'}

local function hasFlag(mask, flag) return type(mask) == 'number' and math.floor(mask / flag) % 2 == 1 end

local function faction()
 local f = UnitFactionGroup and UnitFactionGroup('player')
 return f == 'Horde' and 'H' or 'A'
end

-- Harita başına hizmet listesi (önbellekli)
-- Sınıfı otomatik tanı: başka sınıfların eğitmenlerini gösterme
local CLASS_WORD = {Warrior = 'WARRIOR', Paladin = 'PALADIN', Hunter = 'HUNTER', Rogue = 'ROGUE', Priest = 'PRIEST', Shaman = 'SHAMAN',
 Mage = 'MAGE', Warlock = 'WARLOCK', Druid = 'DRUID', Pet = 'HUNTER', Portal = 'MAGE', Demon = 'WARLOCK'}
function FT.IsOtherClassTrainer(sub)
 if type(sub) ~= 'string' then return false end
 local word = sub:match('^(%a+) Trainer$')
 local cls = word and CLASS_WORD[word]
 if not cls then return false end
 local mine = UnitClass and select(2, UnitClass('player'))
 return mine ~= nil and cls ~= mine
end

local cache = {}
FT.liveListeners = FT.liveListeners or {}
FT.liveListeners[#FT.liveListeners + 1] = function() cache = {} end
local function servicesOn(mapID)
 if cache[mapID] then return cache[mapID] end
 local out = {}
 local z = FT.Module and FT.Module('ZoneDB')
 local mine = faction()
 for id, n in pairs(FT.DBN or {}) do
  local flags = n[12]
  if type(flags) == 'number' and flags > 0 and (not n[10] or n[10]:find(mine, 1, true)) and type(n[5]) == 'table' and not FT.IsOtherClassTrainer(n[11]) then
   local cat
   for _, key in ipairs(CAT_ORDER) do if hasFlag(flags, FLAGS[key]) then cat = key; break end end
   if cat then
    for area, list in pairs(n[5]) do
     if z and z:GetUiMapIdByAreaId(area) == mapID and list[1] then
      out[#out + 1] = {name=n[1], sub=n[11], cat=cat, flags=flags, map=mapID, x=list[1] / 1000, y=list[2] / 1000}
      break
     end
    end
   end
  end
 end
 cache[mapID] = out
 return out
end

local function classTrainersOn(mapID)
 local _, token = UnitClass('player')
 local want = token and (token:sub(1, 1) .. token:sub(2):lower() .. ' Trainer') or ''
 local out = {}
 for _, e in ipairs(servicesOn(mapID)) do if e.sub == want then out[#out + 1] = {name=e.name, sub=e.sub, cat='sinif', map=e.map, x=e.x, y=e.y} end end
 return out
end

local function professionTrainersOn(mapID)
 local out = {}
 for _, e in ipairs(servicesOn(mapID)) do
  if e.sub and hasFlag(e.flags, FLAGS.trainer) then
   for _, p in ipairs(FT.Professions or {}) do
    local hit = false
    for _, w in ipairs(p.words) do if e.sub:find(w, 1, true) then hit = true; break end end
    if hit then out[#out + 1] = {name=e.name, sub=p.tr .. ' — ' .. e.sub, cat='meslek', map=e.map, x=e.x, y=e.y}; break end
   end
  end
 end
 return out
end

local function extraOn(cat, mapID)
 local out = {}
 if cat == 'gorev' or cat == 'teslim' then
  local want = cat == 'gorev' and '!' or '?'
  local seen = {}
  for _, m in ipairs(FT.QuestMarks and FT.QuestMarks(mapID) or {}) do
   if m.kind == want and not seen[m.questId] then
    seen[m.questId] = true
    out[#out + 1] = {name=('[%s] %s'):format(m.level or '?', FT.QuestTitle and FT.QuestTitle(m.questId) or m.questId), sub=(want == '!' and 'Veren: ' or 'Teslim: ') .. (m.giver or '?'), cat=cat, map=m.map, x=m.x, y=m.y, questId=m.questId}
   end
  end
 elseif cat == 'sinif' then
  out = classTrainersOn(mapID)
  local level = UnitLevel('player') or 1
  for _, q in ipairs(FT.ClassQuests and FT.ClassQuests() or {}) do
   if not q.done and q.level <= level + 2 and FT.GiverPoints then
    for _, p in ipairs(FT.GiverPoints(q.id, mapID, false)) do
     out[#out + 1] = {name=('[%d] %s'):format(q.level, q.title), sub=(q.hint and (q.hint .. ' — ') or 'Sınıf görevi — ') .. (p.name or ''), cat='sinif', map=p.map, x=p.x, y=p.y, questId=q.id}
     break
    end
   end
  end
 elseif cat == 'meslek' then
  out = professionTrainersOn(mapID)
 elseif cat == 'zindan' then
  local z = FT.Module and FT.Module('ZoneDB')
  for id, d in pairs(FT.DBDungeons or {}) do
   for _, loc in ipairs((not FT.DungeonAllowed or FT.DungeonAllowed(id, d)) and d[4] or {}) do
    if z and z:GetUiMapIdByAreaId(loc[1]) == mapID then out[#out + 1] = {name=d[1], sub='Zindan girişi', cat='zindan', map=mapID, x=loc[2] / 100, y=loc[3] / 100} end
   end
  end
 elseif cat == 'nadir' then
  local seen = {}
  for _, r in ipairs(FT.RaresOn and FT.RaresOn(mapID) or {}) do
   if not seen[r.id] then seen[r.id] = true; out[#out + 1] = {name=r.name, sub=('Nadir yaratık, seviye %s'):format(r.level or '?'), cat='nadir', map=mapID, x=r.x, y=r.y, npcId=r.id} end
  end
 elseif cat == 'evcil' then
  local _, token = UnitClass('player')
  if token == 'HUNTER' and FT.TameableOn then
   for _, p in ipairs(FT.TameableOn(mapID)) do out[#out + 1] = {name=(p.rare and '★ ' or '') .. p.name .. ' (sv ' .. (p.level or '?') .. ')', sub=p.note, cat='evcil', map=p.map, x=p.x, y=p.y} end
  end
  if FT.ClassQuests then
   local level = UnitLevel('player') or 1
   for _, q in ipairs(FT.ClassQuests()) do
    if not q.done and q.hint and q.level <= level + 2 and FT.GiverPoints then
     local p = FT.GiverPoints(q.id, mapID, false)[1]
     if p then out[#out + 1] = {name=('[%d] %s'):format(q.level, q.title), sub=q.hint, cat='evcil', map=p.map, x=p.x, y=p.y, questId=q.id} end
    end
   end
  end
  for _, e in ipairs(servicesOn(mapID)) do if hasFlag(e.flags, FLAGS.stable) then out[#out + 1] = {name=e.name, sub='Ahır', cat='evcil', map=e.map, x=e.x, y=e.y} end end
 end
 return out
end

-- Her yerde ara: NPC adı/unvanı ve zindanlar, tüm haritalarda
local function globalSearch(text)
 local out = {}
 local z = FT.Module and FT.Module('ZoneDB')
 if not z or #text < 3 then return out end
 for _, n in pairs(FT.DBN or {}) do
  local name, sub = n[1], n[11]
  if type(name) == 'string' and (name:lower():find(text, 1, true) or (type(sub) == 'string' and sub:lower():find(text, 1, true))) and type(n[5]) == 'table' then
   for area, list in pairs(n[5]) do
    local ui = z:GetUiMapIdByAreaId(area)
    if ui and list[1] then
     out[#out + 1] = {name=name, sub=sub, cat='npc', map=ui, x=list[1] / 1000, y=list[2] / 1000, friendly=n[10] ~= nil}
     break
    end
   end
   if #out >= 80 then break end
  end
 end
 for id, d in pairs(FT.DBDungeons or {}) do
  if d[1]:lower():find(text, 1, true) and (not FT.DungeonAllowed or FT.DungeonAllowed(id, d)) then
   local loc = d[4] and d[4][1]
   local ui = loc and z:GetUiMapIdByAreaId(loc[1])
   if ui then out[#out + 1] = {name=d[1], sub='Zindan girişi', cat='zindan', map=ui, x=loc[2] / 100, y=loc[3] / 100} end
  end
 end
 return out
end

----------------------------------------------------------------------
-- Arayüz: düz (Kit) görünüm; çip şeridi, kaydırılabilir liste, yerinde açılan satır, aktif hedef kartı
----------------------------------------------------------------------
local PANEL_W, HEAD_H = 300, 30
local ROW_H, EXP_H, MAXSHOW = 42, 112, 60
local CHIP_H = 22
local PRIMARY = {hepsi = true, gorev = true, teslim = true, repair = true, vendor = true, inn = true}
local GLYPH = {gorev = '!', teslim = '?', repair = 'T', vendor = 'S', inn = 'H', bank = 'B', flight = 'U', trainer = 'E', sinif = 'S',
 meslek = 'M', auction = 'M', stable = 'A', evcil = 'E', zindan = 'Z', nadir = 'N', posta = 'P', kayit = '*', npc = '•'}
local QUICK = {{'repair', 'Tamirci'}, {'inn', 'Han'}, {'flight', 'Uçuş'}, {'bank', 'Banka'}}
local SORTS = {{'yakin', 'Yakın'}, {'ad', 'Ad'}, {'tur', 'Tür'}}

local panel, body, sf, list, rows, chipFrame, chips, searchBox, searchHint, sortSeg, countText, emptyText, moreText
local card, ping, pins, switchEverywhere, headerButtons
local category, filtered, selectedKey = 'hepsi', {}, nil
local counts = {}
local favSet = {}

local function S() return ForeverTrailSettings or {} end
local function kit() return FT.Kit end

local function playerDistance(e)
 if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
 local map = C_Map.GetBestMapForUnit('player')
 if map ~= e.map then return nil end
 local pos = C_Map.GetPlayerMapPosition(map, 'player')
 if not pos then return nil end
 local px, py = pos:GetXY()
 local ok, w, h = pcall(C_Map.GetMapWorldSize, map)
 if not ok or not w then return nil end
 local dx, dy = (e.x - px) * w, (e.y - py) * h
 return math.sqrt(dx * dx + dy * dy)
end

local function etaText(d)
 if not d then return '' end
 local ok, text = pcall(function() return FT.FormatETA and FT.FormatETA(d / 7) or '' end)
 return ok and text or ''
end

local function keyOf(e) return ('%s:%s:%d:%d'):format(tostring(e.map), tostring(e.name), math.floor((e.x or 0) * 1000 + 0.5), math.floor((e.y or 0) * 1000 + 0.5)) end

local function buildFavSet()
 favSet = {}
 for _, p in ipairs(S().places or {}) do favSet[keyOf(p)] = true end
end

local function matches(e, text)
 if text == '' then return true end
 local name = type(e.name) == 'string' and e.name:lower() or ''
 if name:find(text, 1, true) then return true end
 return type(e.sub) == 'string' and e.sub:lower():find(text, 1, true) ~= nil
end

-- Bir tür için, bu haritadaki yerler (mesafe/sıralama yok)
local function collect(cat, mapID, text, everywhere)
 local out = {}
 if not mapID then return out end
 if (cat == 'posta' or cat == 'hepsi') and FT.MailboxesOn then
  for _, e in ipairs(FT.MailboxesOn(mapID)) do if matches(e, text) then out[#out + 1] = e end end
 end
 if FLAGS[cat] or cat == 'hepsi' then
  for _, e in ipairs(servicesOn(mapID)) do
   if (cat == 'hepsi' or hasFlag(e.flags, FLAGS[cat])) and matches(e, text) then out[#out + 1] = e end
  end
 end
 for _, e in ipairs(extraOn(cat, mapID)) do if matches(e, text) then out[#out + 1] = e end end
 if everywhere and #text >= 3 then
  local seen = {}
  for _, e in ipairs(out) do seen[e.name] = true end
  for _, e in ipairs(globalSearch(text)) do if not seen[e.name] then out[#out + 1] = e end end
 end
 if cat == 'hepsi' or cat == 'kayit' then
  local have = {}
  for _, e in ipairs(out) do have[keyOf(e)] = true end
  for _, p in ipairs(S().places or {}) do
   if p.map == mapID and matches(p, text) and (cat == 'kayit' or not have[keyOf(p)]) then
    out[#out + 1] = {name = p.name, sub = p.cat, cat = 'kayit', map = p.map, x = p.x, y = p.y, saved = true}
   end
  end
 end
 return out
end

local function buildCounts(mapID)
 if not mapID then return end
 local c = {}
 for _, def in ipairs(CATS) do
  local ok, result = pcall(collect, def.key, mapID, '', false)
  c[def.key] = ok and #result or 0
 end
 counts[mapID] = c
end
FT.liveListeners[#FT.liveListeners + 1] = function() counts = {} end

local function attachTip(button, title, text)
 button:HookScript('OnEnter', function(self)
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, 'ANCHOR_TOP'); GameTooltip:SetText(title, 1, 0.82, 0)
  if text and text ~= '' then GameTooltip:AddLine(text, 0.9, 0.9, 0.9, true) end
  GameTooltip:Show()
 end)
 button:HookScript('OnLeave', function() if GameTooltip then GameTooltip:Hide() end end)
end

local function goTo(e)
 if not e then return end
 if e.questId and FT.GoToQuest then FT.GoToQuest(e.questId) else FT.SetCustomTarget(e.map, e.x, e.y, e.name) end
 if FT.RefreshMapRoute then FT.RefreshMapRoute() end
end

-- Haritada vurgu: listedeki yerler için bizim kendi işaretlerimiz (başka eklentilerin işaretlerine dokunulmaz)
local function hidePins()
 for _, p in ipairs(pins or {}) do p:Hide() end
 if ping then ping:Hide() end
end

local function drawPins(mapID)
 local overlay = FT.mapParts and FT.mapParts.overlay
 pins = pins or {}
 if not overlay or not panel or not panel:IsShown() or S().routeHighlight == false then
  for _, p in ipairs(pins) do p:Hide() end
  return
 end
 local used = 0
 for _, e in ipairs(filtered) do
  if e.map == mapID and used < 40 then
   used = used + 1
   local p = pins[used]
   if not p then
    p = overlay:CreateTexture(nil, 'OVERLAY')
    p:SetTexture('Interface\\Cooldown\\star4'); p:SetBlendMode('ADD')
    pins[used] = p
   end
   local c = CAT_COLOR[e.cat] or CAT_COLOR.npc
   local chosen = selectedKey and keyOf(e) == selectedKey
   p:SetSize(chosen and 40 or 22, chosen and 40 or 22)
   p:SetVertexColor(c[1], c[2], c[3], chosen and 1 or 0.85)
   p:ClearAllPoints(); p:SetPoint('CENTER', overlay, 'TOPLEFT', e.x * overlay:GetWidth(), -e.y * overlay:GetHeight())
   p:Show()
  end
 end
 for i = used + 1, #pins do pins[i]:Hide() end
end

local function showPing(e)
 local overlay = FT.mapParts and FT.mapParts.overlay
 if not overlay then return end
 if not ping then
  ping = overlay:CreateTexture(nil, 'OVERLAY')
  ping:SetTexture('Interface\\Cooldown\\star4'); ping:SetBlendMode('ADD'); ping:SetSize(54, 54)
 end
 if not e or e.map ~= WorldMapFrame:GetMapID() then ping:Hide(); return end
 local a = FT.Style.accent
 ping:SetVertexColor(a[1], a[2], a[3], 1)
 ping:ClearAllPoints(); ping:SetPoint('CENTER', overlay, 'TOPLEFT', e.x * overlay:GetWidth(), -e.y * overlay:GetHeight())
 ping:Show()
end

local function nearestFlight(e)
 local best, bd
 for _, f in ipairs(servicesOn(e.map)) do
  if hasFlag(f.flags, FLAGS.flight) then
   local d = (f.x - e.x) ^ 2 + (f.y - e.y) ^ 2
   if not bd or d < bd then best, bd = f, d end
  end
 end
 return best
end

local function detailText(e)
 local lines = {}
 local zone = FT.MapName and FT.MapName(e.map) or ''
 lines[#lines + 1] = ('%s  %.1f, %.1f'):format(zone, (e.x or 0) * 100, (e.y or 0) * 100)
 local f = nearestFlight(e)
 if f and f.name ~= e.name then lines[#lines + 1] = 'En yakın uçuş: ' .. f.name end
 if e.questId and FT.QuestStatus then lines[#lines + 1] = FT.QuestStatus(e.questId) end
 return table.concat(lines, '\n')
end

local function toggleFav(e)
 local places = S().places
 if not places then ForeverTrailSettings.places = {}; places = ForeverTrailSettings.places end
 local key = keyOf(e)
 local removed = false
 for i = #places, 1, -1 do
  if keyOf(places[i]) == key then table.remove(places, i); removed = true end
 end
 if not removed then
  table.insert(places, {name = e.name, cat = e.sub or CAT_LABEL[e.cat] or 'Kayıtlı', map = e.map, x = e.x, y = e.y})
  FT.Print('Favorilere eklendi: ' .. tostring(e.name))
 end
 counts = {}
end

----------------------------------------------------------------------
-- Çipler
----------------------------------------------------------------------
local function paintChip(c)
 local K = kit()
 local on = c.key == category
 local fill = K.Color(on and 'accent' or (c.hover and 'panel' or 'card'))
 local text = K.Color(on and 'deep' or (c.hover and 'accent' or 'text'))
 c.fill:SetColorTexture(fill[1], fill[2], fill[3], 1)
 c.label:SetTextColor(text[1], text[2], text[3])
 c:SetAlpha(c.empty and not on and 0.5 or 1)
end

local function newChip()
 local K = kit()
 local c = CreateFrame('Button', nil, chipFrame)
 c:SetHeight(CHIP_H)
 c.edge = c:CreateTexture(nil, 'BACKGROUND', nil, 0); c.edge:SetAllPoints(); K.Fill(c.edge, 'line')
 c.fill = c:CreateTexture(nil, 'BACKGROUND', nil, 1); c.fill:SetPoint('TOPLEFT', 1, -1); c.fill:SetPoint('BOTTOMRIGHT', -1, 1)
 c.dot = c:CreateTexture(nil, 'ARTWORK'); c.dot:SetSize(6, 6); c.dot:SetPoint('LEFT', 7, 0)
 c.label = c:CreateFontString(nil, 'OVERLAY'); K.Font(c.label, 11); c.label:SetPoint('LEFT', 17, 0)
 c:SetScript('OnEnter', function(self)
  self.hover = true; paintChip(self)
  if not (GameTooltip and self.tipTitle) then return end
  GameTooltip:SetOwner(self, 'ANCHOR_TOP'); GameTooltip:SetText(self.tipTitle, 1, 0.82, 0)
  if self.tipText and self.tipText ~= '' then GameTooltip:AddLine(self.tipText, 0.9, 0.9, 0.9, true) end
  GameTooltip:Show()
 end)
 c:SetScript('OnLeave', function(self) self.hover = false; paintChip(self); if GameTooltip then GameTooltip:Hide() end end)
 c:SetScript('OnClick', function(self)
  if self.key == '_more' then
   ForeverTrailSettings.routeChipsOpen = not S().routeChipsOpen
   FT.RouteRelayout()
  else
   category = self.key; ForeverTrailSettings.routeCat = category
   FT.RefreshMapRoute()
  end
 end)
 return c
end

-- Çipleri dizer ve çip alanının yüksekliğini döndürür
local function layoutChips(mapID)
 local K = kit()
 local width = PANEL_W - 20
 local c = counts[mapID] or {}
 local open = S().routeChipsOpen
 local order = {}
 for _, def in ipairs(CATS) do
  if PRIMARY[def.key] or (open and ((c[def.key] or 0) > 0 or def.key == category)) then order[#order + 1] = def end
 end
 local x, y, rowsUsed = 0, 0, 1
 local function place(chip, w)
  if x > 0 and x + w > width then x = 0; y = y + CHIP_H + 4; rowsUsed = rowsUsed + 1 end
  chip:ClearAllPoints(); chip:SetPoint('TOPLEFT', chipFrame, 'TOPLEFT', x, -y); chip:SetWidth(w); chip:Show()
  x = x + w + 4
 end
 local used = 0
 for _, def in ipairs(order) do
  used = used + 1
  local chip = chips[used] or newChip(); chips[used] = chip
  local n = c[def.key]
  chip.key = def.key
  chip.empty = (n or 0) == 0 and def.key ~= 'hepsi'
  chip.label:SetText(def.label .. ((n and n > 0) and (' ' .. n) or ''))
  local cc = CAT_COLOR[def.key] or CAT_COLOR.npc
  chip.dot:SetColorTexture(cc[1], cc[2], cc[3], 1); chip.dot:Show()
  chip.tipTitle, chip.tipText = def.label, def.tip
  place(chip, 22 + #def.label * 6 + ((n and n > 0) and ((#tostring(n) + 1) * 6) or 0))
  paintChip(chip)
 end
 -- "Diğer" düğmesi
 used = used + 1
 local more = chips[used] or newChip(); chips[used] = more
 more.key = '_more'; more.empty = false; more.dot:Hide()
 local hidden = 0
 for _, def in ipairs(CATS) do if not PRIMARY[def.key] and (c[def.key] or 0) > 0 then hidden = hidden + 1 end end
 more.label:SetText(open and 'Daha az' or ('Diğer ' .. hidden))
 more.label:ClearAllPoints(); more.label:SetPoint('CENTER', 0, 0)
 more.tipTitle, more.tipText = 'Diğer türler', 'Satıcı, banka, uçuş ve diğer türleri göster ya da gizle. Yalnızca bu haritada sonucu olanlar listelenir.'
 place(more, open and 66 or 66)
 paintChip(more)
 for i = used + 1, #chips do chips[i]:Hide() end
 local height = rowsUsed * CHIP_H + (rowsUsed - 1) * 4
 chipFrame:SetHeight(height)
 return height
end

----------------------------------------------------------------------
-- Satırlar
----------------------------------------------------------------------
local function paintRowStar(r)
 local K = kit()
 local e = r.entry
 local on = e and (e.saved or favSet[keyOf(e)])
 local c = K.Color(on and 'accent' or 'muted')
 r.star.text:SetTextColor(c[1], c[2], c[3])
 r.star:SetAlpha(on and 1 or 0.55)
end

local function newRow(i)
 local K = kit()
 local r = CreateFrame('Button', nil, list)
 r:SetHeight(ROW_H)
 r.bg = r:CreateTexture(nil, 'BACKGROUND'); r.bg:SetAllPoints(); K.Fill(r.bg, 'card', 0.7)
 r.hl = r:CreateTexture(nil, 'BORDER'); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 1, 1, 0.06); r.hl:Hide()
 r.bar = r:CreateTexture(nil, 'ARTWORK'); r.bar:SetWidth(3); r.bar:SetPoint('TOPLEFT', 0, 0); r.bar:SetPoint('BOTTOMLEFT', 0, 0)
 r.badge = r:CreateTexture(nil, 'ARTWORK'); r.badge:SetSize(24, 24); r.badge:SetPoint('TOPLEFT', 10, -9)
 r.glyph = K.Text(r, 13, 'text'); r.glyph:SetPoint('CENTER', r.badge, 'CENTER', 0, 0)
 r.name = K.Text(r, 12, 'text'); r.name:SetPoint('TOPLEFT', 42, -7); r.name:SetWidth(PANEL_W - 20 - 42 - 86); r.name:SetJustifyH('LEFT'); r.name:SetWordWrap(false)
 r.sub = K.Text(r, 10, 'muted'); r.sub:SetPoint('TOPLEFT', 42, -23); r.sub:SetWidth(PANEL_W - 20 - 42 - 86); r.sub:SetJustifyH('LEFT'); r.sub:SetWordWrap(false)
 r.dist = K.Text(r, 11, 'text'); r.dist:SetPoint('TOPRIGHT', -30, -7); r.dist:SetJustifyH('RIGHT')
 r.eta = K.Text(r, 10, 'muted'); r.eta:SetPoint('TOPRIGHT', -30, -23); r.eta:SetJustifyH('RIGHT')
 r.star = CreateFrame('Button', nil, r); r.star:SetSize(22, 22); r.star:SetPoint('TOPRIGHT', -4, -5)
 r.star.text = K.Text(r.star, 15, 'muted'); r.star.text:SetPoint('CENTER', 0, 0); r.star.text:SetText('★')
 r.star:SetScript('OnClick', function()
  if r.entry then toggleFav(r.entry); FT.RefreshMapRoute() end
 end)
 r.star:SetScript('OnEnter', function(self)
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, 'ANCHOR_LEFT'); GameTooltip:SetText('Favori', 1, 0.82, 0)
  GameTooltip:AddLine('Favori yerler listenin en üstünde durur ("Kayıtlarım" türünde de bulunur).', 0.9, 0.9, 0.9, true); GameTooltip:Show()
 end)
 r.star:SetScript('OnLeave', function() if GameTooltip then GameTooltip:Hide() end end)
 -- açılan bölüm
 r.detail = K.Text(r, 10, 'muted'); r.detail:SetPoint('TOPLEFT', 42, -46); r.detail:SetWidth(PANEL_W - 20 - 52); r.detail:SetJustifyH('LEFT'); r.detail:SetJustifyV('TOP'); r.detail:SetHeight(34)
 r.mapBtn = K.Button(r, 'Haritada gör', 96, 22); r.mapBtn:SetPoint('BOTTOMLEFT', 42, 8)
 r.mapBtn:SetScript('OnClick', function()
  local e = r.entry
  if e and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(e.map); showPing(e) end
 end)
 r.goBtn = K.Button(r, 'Yol göster', 84, 22, 'primary'); r.goBtn:SetPoint('LEFT', r.mapBtn, 'RIGHT', 6, 0)
 r.goBtn:SetScript('OnClick', function() goTo(r.entry) end)
 r:SetScript('OnEnter', function(self)
  self.hl:Show(); showPing(self.entry)
  local e = self.entry
  if e and e.npcId and FT.ShowTooltipModel then
   GameTooltip:SetOwner(self, 'ANCHOR_LEFT'); GameTooltip:SetText(e.name, 0.8, 0.55, 1); GameTooltip:AddLine(e.sub or '', 1, 1, 1)
   if FT.ShowTip then FT.ShowTip(GameTooltip) else GameTooltip:Show() end
   pcall(FT.ShowTooltipModel, e.npcId)
  end
 end)
 r:SetScript('OnLeave', function(self) self.hl:Hide(); showPing(nil); if GameTooltip then GameTooltip:Hide() end end)
 r:SetScript('OnClick', function(self)
  local e = self.entry
  if not e then return end
  local k = keyOf(e)
  selectedKey = (selectedKey == k) and nil or k
  if selectedKey then
   goTo(e)
   FT.Print(('Yol: %s%s'):format(e.name, e.dist and (' (' .. math.floor(e.dist + 0.5) .. ' yd)') or ''))
  end
  FT.RefreshMapRoute()
 end)
 rows[i] = r
 return r
end

local function updateTargetCard()
 if not card then return end
 local t = FT.customTarget
 if not t then card:Hide(); return false end
 local d = t.uiMapID and playerDistance({map = t.uiMapID, x = t.x, y = t.y}) or nil
 card.name:SetText(tostring(t.questTitle or t.text or 'Seçtiğin nokta'))
 if d then card.info:SetText(('%d yd  ·  %s'):format(math.floor(d + 0.5), etaText(d)))
 else card.info:SetText((FT.MapName and t.uiMapID and FT.MapName(t.uiMapID) or 'Başka bölge') .. '  ·  başka bölgede') end
 card:Show()
 return true
end

-- Yalnızca mesafe yazılarını tazeler (sıralama değişmez); saniyede bir
local function updateDistances()
 if not (panel and panel:IsShown()) then return end
 for _, r in ipairs(rows) do
  local e = r:IsShown() and r.entry
  if e then
   e.dist = playerDistance(e)
   if e.dist then r.dist:SetText(('%d yd'):format(e.dist + 0.5)); r.eta:SetText(etaText(e.dist)) end
  end
 end
 updateTargetCard()
end

local function sortList(mode)
 local rank = {}
 for i, def in ipairs(CATS) do rank[def.key] = i end
 table.sort(filtered, function(a, b)
  local fa, fb = (a.saved or favSet[keyOf(a)]) and true or false, (b.saved or favSet[keyOf(b)]) and true or false
  if fa ~= fb then return fa end
  if mode == 'ad' then
   if a.name ~= b.name then return tostring(a.name) < tostring(b.name) end
  elseif mode == 'tur' then
   local ra, rb = rank[a.cat] or 99, rank[b.cat] or 99
   if ra ~= rb then return ra < rb end
  end
  if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
  if a.dist and b.dist and a.dist ~= b.dist then return a.dist < b.dist end
  if a.name ~= b.name then return tostring(a.name) < tostring(b.name) end
  return (a.x or 0) < (b.x or 0)
 end)
end

local function refresh()
 if not panel or not panel:IsShown() then return end
 local s = S()
 buildFavSet()
 local mapID = WorldMapFrame and WorldMapFrame:GetMapID()
 if mapID and not counts[mapID] then buildCounts(mapID) end
 local text = (searchBox:GetText() or ''):lower()
 filtered = collect(category, mapID, text, s.routeEverywhere and #text >= 3)
 for _, e in ipairs(filtered) do e.dist = playerDistance(e) end
 sortList(s.routeSort or 'yakin')
 -- çipler (yükseklik değişirse liste alanı yeniden yerleşir)
 local ch = layoutChips(mapID)
 if ch ~= panel.chipH then panel.chipH = ch; FT.RouteRelayout(true) end
 -- liste
 local shown = math.min(#filtered, MAXSHOW)
 local y = 0
 local K = kit()
 for i = 1, shown do
  local e = filtered[i]
  local r = rows[i] or newRow(i)
  r.entry = e
  local open = selectedKey and keyOf(e) == selectedKey
  r:ClearAllPoints(); r:SetPoint('TOPLEFT', list, 'TOPLEFT', 0, -y); r:SetWidth(PANEL_W - 28)
  r:SetHeight(open and EXP_H or ROW_H)
  local c = CAT_COLOR[e.cat] or CAT_COLOR.npc
  r.bar:SetColorTexture(c[1], c[2], c[3], 1)
  r.badge:SetColorTexture(c[1], c[2], c[3], 0.22)
  r.glyph:SetText(GLYPH[e.cat] or '•'); r.glyph:SetTextColor(c[1], c[2], c[3])
  r.name:SetText(tostring(e.name))
  r.sub:SetText(e.sub or CAT_LABEL[e.cat] or '')
  if e.dist then r.dist:SetText(('%d yd'):format(e.dist + 0.5)); r.eta:SetText(etaText(e.dist))
  elseif e.map ~= mapID then r.dist:SetText(''); r.eta:SetText('|cff9aa0a6' .. (FT.MapName and FT.MapName(e.map) or '') .. '|r')
  else r.dist:SetText(''); r.eta:SetText(('%.0f, %.0f'):format((e.x or 0) * 100, (e.y or 0) * 100)) end
  paintRowStar(r)
  r.detail:SetShown(open and true or false); r.mapBtn:SetShown(open and true or false); r.goBtn:SetShown(open and true or false)
  if open then r.detail:SetText(detailText(e)) end
  r:Show()
  y = y + (open and EXP_H or ROW_H) + 2
 end
 for i = shown + 1, #rows do rows[i]:Hide(); rows[i].entry = nil end
 if #filtered > MAXSHOW then
  moreText:ClearAllPoints(); moreText:SetPoint('TOPLEFT', list, 'TOPLEFT', 4, -(y + 4))
  moreText:SetText(('+%d yer daha: aramayı daralt'):format(#filtered - MAXSHOW)); moreText:Show(); y = y + 24
 else moreText:Hide() end
 list:SetHeight(math.max(1, y)); list:SetWidth(PANEL_W - 28)
 -- başlık satırı ve boş durum
 local name = mapID and FT.MapName and FT.MapName(mapID) or ''
 countText:SetText(('%s  ·  %d yer'):format(name ~= '' and name or 'Harita', #filtered))
 if #filtered == 0 then
  emptyText:SetText('Burada sonuç yok.\nBaşka bir tür seç, aramayı değiştir ya da haritada başka bir bölgeye geç.\nTüm dünyada aramak için "Her yer" anahtarını aç.')
  emptyText:Show()
 else emptyText:Hide() end
 if sortSeg then sortSeg:SetValue(s.routeSort or 'yakin') end
 if switchEverywhere then switchEverywhere:SetChecked(s.routeEverywhere and true or false) end
 if headerButtons then headerButtons.mark:SetText(s.routeHighlight == false and 'İşaret: kapalı' or 'İşaret: açık') end
 local hasCard = updateTargetCard() and true or false
 if hasCard ~= (panel.hadCard == true) then panel.hadCard = hasCard; FT.RouteRelayout(true) end
 drawPins(mapID)
end
FT.RefreshMapRoute = refresh
function FT.RouteCategory(c) category = c; ForeverTrailSettings.routeCat = c; refresh() end
function FT.RouteSearch(t) if searchBox then searchBox:SetText(t or '') end; refresh() end
function FT.RouteCount() return #filtered end
function FT.RouteEntries() return filtered end -- test ve tanı için
FT.MapServices = servicesOn

----------------------------------------------------------------------
-- Yerleşim
----------------------------------------------------------------------
local sideButton

local function layout()
 if not (panel and body) then return end
 local mapHeight = WorldMapFrame and WorldMapFrame.GetHeight and WorldMapFrame:GetHeight() or 700
 local h = math.max(560, math.min(840, mapHeight))
 local scale = (WorldMapFrame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
 local right, left = WorldMapFrame:GetRight(), WorldMapFrame:GetLeft()
 local screen = UIParent:GetWidth() or 1920
 local wantLeft = S().routeSide == 'left'
 local roomRight = right and (right * scale + PANEL_W + 6) <= screen
 local roomLeft = left and (left * scale - PANEL_W - 6) >= 0
 panel:ClearAllPoints()
 if (wantLeft and roomLeft) or (not roomRight and roomLeft) then
  panel:SetPoint('TOPRIGHT', WorldMapFrame, 'TOPLEFT', -4, 0)
 elseif roomRight then
  panel:SetPoint('TOPLEFT', WorldMapFrame, 'TOPRIGHT', 4, 0)
 else
  panel:SetPoint('TOPRIGHT', WorldMapFrame, 'TOPRIGHT', -8, -40); h = h - 60
 end
 local collapsed = S().routeCollapsed
 panel:SetSize(PANEL_W, collapsed and HEAD_H or h)
 body:SetShown(not collapsed)
 if sideButton then sideButton:SetText(wantLeft and '>' or '<') end
 -- gövde: arama, hızlı şerit, çipler, başlık satırı, liste, hedef kartı
 local chipH = panel.chipH or CHIP_H
 chipFrame:ClearAllPoints(); chipFrame:SetPoint('TOPLEFT', body, 'TOPLEFT', 10, -88); chipFrame:SetSize(PANEL_W - 20, chipH)
 local rowY = 88 + chipH + 8
 countText:ClearAllPoints(); countText:SetPoint('TOPLEFT', body, 'TOPLEFT', 12, -(rowY + 6))
 sortSeg:ClearAllPoints(); sortSeg:SetPoint('TOPRIGHT', body, 'TOPRIGHT', -10, -rowY)
 sf:ClearAllPoints()
 sf:SetPoint('TOPLEFT', body, 'TOPLEFT', 10, -(rowY + 28))
 sf:SetPoint('BOTTOMRIGHT', body, 'BOTTOMRIGHT', -18, (FT.customTarget and 70 or 10))
 emptyText:ClearAllPoints(); emptyText:SetPoint('TOPLEFT', body, 'TOPLEFT', 14, -(rowY + 40))
 card:ClearAllPoints(); card:SetPoint('BOTTOMLEFT', body, 'BOTTOMLEFT', 10, 10); card:SetPoint('BOTTOMRIGHT', body, 'BOTTOMRIGHT', -10, 10)
end

function FT.RouteRelayout(skipRefresh)
 layout()
 if not skipRefresh then refresh() end
end

-- Hızlı şerit: oyuncunun bulunduğu bölgedeki en yakın hizmet
local function quickGo(key, label)
 local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit('player')
 local best, bd
 if map then
  for _, e in ipairs(servicesOn(map)) do
   if hasFlag(e.flags, FLAGS[key]) then
    local d = playerDistance(e)
    if d and (not bd or d < bd) then best, bd = e, d end
   end
  end
 end
 if not best then
  category = key; ForeverTrailSettings.routeCat = key
  FT.Print(('Bu bölgede %s bulunamadı; listeyi gözden geçir.'):format(label:lower()))
  refresh()
  return
 end
 best.dist = bd
 selectedKey = keyOf(best)
 if WorldMapFrame and WorldMapFrame.SetMapID and WorldMapFrame:GetMapID() ~= map then WorldMapFrame:SetMapID(map) end
 goTo(best)
 FT.Print(('En yakın %s: %s (%d yd)'):format(label:lower(), best.name, math.floor(bd + 0.5)))
end

local function create()
 local K = kit()
 panel = FT.NewWindow('ForeverTrailMapRoute', WorldMapFrame)
 FT.mapRoute = panel
 panel:SetSize(PANEL_W, 700)
 panel:SetClampedToScreen(true)
 panel:SetFrameStrata(WorldMapFrame:GetFrameStrata())
 panel:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 20)
 rows, chips = {}, {}
 category = S().routeCat or 'hepsi'

 -- başlık şeridi
 local title = panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 title:SetPoint('TOPLEFT', 12, -8); title:SetText('Yol sor')
 if FT.StyleTitle then FT.StyleTitle(title) end
 headerButtons = {}
 local collapse = K.Button(panel, '–', 22, 20); collapse:SetPoint('TOPRIGHT', -34, -5)
 collapse:SetScript('OnClick', function() ForeverTrailSettings.routeCollapsed = not S().routeCollapsed; FT.RouteRelayout() end)
 attachTip(collapse, 'Daralt', 'Paneli yalnızca başlık satırına küçültür.')
 sideButton = K.Button(panel, '<', 22, 20); sideButton:SetPoint('RIGHT', collapse, 'LEFT', -3, 0)
 sideButton:SetScript('OnClick', function() ForeverTrailSettings.routeSide = S().routeSide == 'left' and 'right' or 'left'; layout() end)
 attachTip(sideButton, 'Panelin yeri', 'Paneli haritanın soluna ya da sağına taşır. Yer yoksa harita içinde açılır.')
 headerButtons.mark = K.Button(panel, 'İşaret: açık', 86, 20); headerButtons.mark:SetPoint('RIGHT', sideButton, 'LEFT', -3, 0)
 headerButtons.mark:SetScript('OnClick', function() ForeverTrailSettings.routeHighlight = S().routeHighlight == false and true or false; refresh() end)
 attachTip(headerButtons.mark, 'Haritada işaretle', 'Listedeki yerleri haritada parlayan işaretlerle gösterir (başka eklentilerin işaretlerine dokunmaz).')

 body = CreateFrame('Frame', nil, panel)
 body:SetPoint('TOPLEFT', 0, -HEAD_H); body:SetPoint('BOTTOMRIGHT', 0, 0)

 -- arama + her yer anahtarı
 searchBox = K.Input(body)
 searchBox:SetSize(178, 22); searchBox:SetPoint('TOPLEFT', 10, -8)
 searchHint = K.Text(body, 11, 'muted'); searchHint:SetPoint('LEFT', searchBox, 'LEFT', 9, 0); searchHint:SetText('Ara: han, tamirci, uçuş...')
 searchBox:HookScript('OnEditFocusGained', function() searchHint:Hide() end)
 searchBox:HookScript('OnEditFocusLost', function(self) if (self:GetText() or '') == '' then searchHint:Show() end end)
 searchBox:SetScript('OnTextChanged', function(self)
  if (self:GetText() or '') ~= '' then searchHint:Hide() end
  refresh()
 end)
 local everyLabel = K.Text(body, 10, 'muted'); everyLabel:SetPoint('LEFT', searchBox, 'RIGHT', 8, 0); everyLabel:SetText('Her yer')
 switchEverywhere = K.Switch(body); switchEverywhere:SetPoint('LEFT', everyLabel, 'RIGHT', 4, 0)
 switchEverywhere:SetScript('OnClick', function(self) ForeverTrailSettings.routeEverywhere = self:GetChecked() and true or nil; refresh() end)
 attachTip(switchEverywhere, 'Her yerde ara', 'Kapalıyken yalnızca baktığın haritada aranır. Açıkken tüm dünyada aranır (en az 3 harf yaz).')

 -- hızlı şerit: en yakın tamirci / han / uçuş / banka
 local qLabel = K.Text(body, 10, 'muted'); qLabel:SetPoint('TOPLEFT', 12, -40); qLabel:SetText('En yakın')
 local qx = 10
 for _, q in ipairs(QUICK) do
  local b = K.Button(body, q[2], 66, 22); b:SetPoint('TOPLEFT', qx, -56)
  b:SetScript('OnClick', function() quickGo(q[1], q[2]) end)
  attachTip(b, 'En yakın ' .. q[2]:lower(), 'Bulunduğun bölgedeki en yakın yeri hedef yapar; ok ve harita oraya döner.')
  qx = qx + 70
 end

 -- çipler
 chipFrame = CreateFrame('Frame', nil, body); chipFrame:SetSize(PANEL_W - 20, CHIP_H)
 panel.chipH = CHIP_H

 -- liste başlığı: yer sayısı + sıralama
 countText = K.Text(body, 11, 'muted'); countText:SetJustifyH('LEFT')
 sortSeg = K.Segmented(body, SORTS, 126, 22, function(key) ForeverTrailSettings.routeSort = key; refresh() end)

 -- kaydırılabilir liste
 sf = K.Scroll(body)
 list = CreateFrame('Frame', nil, sf); list:SetSize(PANEL_W - 28, 10)
 sf:SetScrollChild(list)
 moreText = K.Text(list, 10, 'muted'); moreText:Hide()
 emptyText = K.Text(body, 12, 'muted'); emptyText:SetWidth(PANEL_W - 28); emptyText:SetJustifyH('LEFT'); emptyText:SetJustifyV('TOP'); emptyText:Hide()

 -- aktif hedef kartı
 card = CreateFrame('Frame', nil, body); card:SetHeight(54)
 K.Skin(card, 'card', 'line')
 card.name = K.Text(card, 12, 'accent'); card.name:SetPoint('TOPLEFT', 10, -8); card.name:SetPoint('RIGHT', card, 'RIGHT', -34, 0); card.name:SetJustifyH('LEFT'); card.name:SetWordWrap(false)
 card.info = K.Text(card, 10, 'muted'); card.info:SetPoint('TOPLEFT', 10, -26); card.info:SetJustifyH('LEFT')
 card.close = K.CloseButton(card, function() if FT.ClearCustomTarget then FT.ClearCustomTarget() end; refresh() end)
 card.close:SetPoint('TOPRIGHT', -2, -2)
 attachTip(card.close, 'Hedefi kaldır', 'Okun gösterdiği özel hedefi siler; ok görev rehberine döner.')
 local plan = K.Button(card, 'Rota planı', 74, 20); plan:SetPoint('BOTTOMRIGHT', -8, 6)
 plan:SetScript('OnClick', function() if FT.ShowRoutePlan then FT.ShowRoutePlan() end end)
 attachTip(plan, 'Rota planı', 'Hedeflerini ve görevlerini en verimli sırayla listeler.')
 card:Hide()

 K.Track(function() if panel then for _, c in ipairs(chips) do pcall(paintChip, c) end end end)
 panel:SetScript('OnShow', function() layout(); counts = {}; refresh() end)
 panel:SetScript('OnHide', function() hidePins() end)
 local acc = 0
 panel:SetScript('OnUpdate', function(_, dt)
  acc = acc + dt
  if acc >= 1 then acc = 0; updateDistances() end
 end)
 panel:Hide()
 layout()
 if FT.FixFonts then FT.FixFonts(panel) end
end

local toggle
local function install()
 if toggle or not WorldMapFrame then return end
 create()
 toggle = FT.NewButton(WorldMapFrame, 'Yol sor', 72, 22)
 toggle:SetFrameStrata(WorldMapFrame:GetFrameStrata())
 toggle:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 25)
 toggle:SetPoint('TOPRIGHT', WorldMapFrame, 'TOPRIGHT', -60, -2)
 toggle:SetScript('OnClick', function()
  if panel:IsShown() then panel:Hide(); ForeverTrailSettings.mapRouteOpen = false
  else panel:Show(); ForeverTrailSettings.mapRouteOpen = true end
 end)
 WorldMapFrame:HookScript('OnShow', function()
  if ForeverTrailSettings.mapRouteOpen ~= false and ForeverTrailSettings.mapRoute ~= false then panel:Show() end
 end)
 WorldMapFrame:HookScript('OnSizeChanged', function() layout(); if panel:IsShown() then refresh() end end)
 if hooksecurefunc then pcall(hooksecurefunc, WorldMapFrame, 'SetMapID', function() if panel:IsShown() then refresh() end end) end
 local mode = FT.NewButton(WorldMapFrame, 'Görünüm', 120, 22)
 mode:SetFrameStrata(WorldMapFrame:GetFrameStrata()); mode:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 25)
 mode:SetPoint('RIGHT', toggle, 'LEFT', -4, 0)
 local function label() for _, m in ipairs(FT.MapModes or {}) do if m.key == (FT.MapMode and FT.MapMode()) then mode:SetText(m.label) end end end
 mode:SetScript('OnClick', function() if FT.CycleMapMode then FT.CycleMapMode() end label() end)
 mode:SetScript('OnShow', label); label()
 if FT.FixFonts then FT.FixFonts(toggle); FT.FixFonts(mode) end
end

local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent', function()
 local ok, err = pcall(install)
 if not ok and FT.errors then FT.errors[#FT.errors + 1] = 'maproute: ' .. tostring(err) end
end)
