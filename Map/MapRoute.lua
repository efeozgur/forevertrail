local _, FT = ...

-- Dünya haritasının yanında "Yol sor" paneli: baktığın haritadaki hizmet NPC'leri (gömülü veriden)
-- ve kayıtlı yerler. Bir satıra tıklayınca ok, harita güzergahı ve minimap oraya döner.

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

local panel, rows, catButtons, searchBox, hint, ping, everywhere, detail, selected, emptyText, pageText, searchHint, targetText, targetClear
local category, page, filtered = 'hepsi', 1, {}
local PER = 11

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

local function refresh()
 if not panel or not panel:IsShown() then return end
 local mapID = WorldMapFrame and WorldMapFrame:GetMapID()
 local text = (searchBox:GetText() or ''):lower()
 filtered = {}
 if mapID then
  if (category == 'posta' or category == 'hepsi') and FT.MailboxesOn then
   for _, e in ipairs(FT.MailboxesOn(mapID)) do filtered[#filtered + 1] = e end
  end
  if FLAGS[category] or category == 'hepsi' then
   for _, e in ipairs(servicesOn(mapID)) do
    if (category == 'hepsi' or hasFlag(e.flags, FLAGS[category])) and (text == '' or e.name:lower():find(text, 1, true) or (e.sub and e.sub:lower():find(text, 1, true))) then
     filtered[#filtered + 1] = e
    end
   end
  end
  for _, e in ipairs(extraOn(category, mapID)) do
   if text == '' or e.name:lower():find(text, 1, true) or (e.sub and e.sub:lower():find(text, 1, true)) then filtered[#filtered + 1] = e end
  end
  if ForeverTrailSettings.routeEverywhere and #text >= 3 then
   local seen = {}
   for _, e in ipairs(filtered) do seen[e.name] = true end
   for _, e in ipairs(globalSearch(text)) do if not seen[e.name] then filtered[#filtered + 1] = e end end
  end
  if category == 'hepsi' or category == 'kayit' then
   for _, p in ipairs(ForeverTrailSettings.places or {}) do
    if p.map == mapID and (text == '' or p.name:lower():find(text, 1, true)) then
     filtered[#filtered + 1] = {name=p.name, sub=p.cat, cat='kayit', map=p.map, x=p.x, y=p.y}
    end
   end
  end
 end
 for _, e in ipairs(filtered) do e.dist = playerDistance(e) end
 table.sort(filtered, function(a, b)
  if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
  if a.dist and b.dist then return a.dist < b.dist end
  return a.name < b.name
 end)
 page = math.max(1, math.min(page, math.ceil(math.max(1, #filtered) / PER)))
 for i, r in ipairs(rows) do
  local e = i <= PER and filtered[(page - 1) * PER + i] or nil
  r.entry = e
  if e then
   r.name:SetText(e.name)
   r.sub:SetText(e.sub or CAT_LABEL[e.cat] or '')
   local c = CAT_COLOR[e.cat] or CAT_COLOR.npc
   r.bar:SetColorTexture(c[1], c[2], c[3], 1)
   if e.dist then r.dist:SetText(('%d yd'):format(e.dist + 0.5))
   elseif e.map ~= mapID then r.dist:SetText('|cff9aa0a6' .. (FT.MapName and FT.MapName(e.map) or '') .. '|r')
   else r.dist:SetText(('%.0f, %.0f'):format(e.x * 100, e.y * 100)) end
   r:Show()
  else r:Hide() end
 end
 local name = mapID and FT.MapName and FT.MapName(mapID) or ''
 local pages = math.max(1, math.ceil(#filtered / PER))
 if #filtered == 0 then
  hint:SetText(name ~= '' and (name .. ' haritası') or '')
  emptyText:SetText('Burada sonuç yok.\nBaşka bir tür seç, aramayı değiştir ya da haritada başka bir bölgeye geç.\nTüm dünyada aramak için "Her yer" düğmesini aç.')
  emptyText:Show()
 else
  hint:SetText(('%s  ·  %d yer   (%d/%d)'):format(name, #filtered, page, pages))
  emptyText:Hide()
 end
 pageText:SetText(#filtered > PER and ('Sayfa %d / %d'):format(page, pages) or '')
 for _, b in ipairs(catButtons) do if b.key == category then b:Disable() else b:Enable() end end
 if everywhere then everywhere:SetText(ForeverTrailSettings.routeEverywhere and 'Her yer: açık' or 'Her yer: kapalı') end
 local t = FT.customTarget
 if t then
  targetText:SetText('|cff55ff55Ok şu an:|r ' .. tostring(t.questTitle or t.text or 'Seçtiğin nokta'))
  targetClear:Show()
 else
  targetText:SetText('|cff9aa0a6Henüz hedef seçmedin.|r')
  targetClear:Hide()
 end
end
FT.RefreshMapRoute = refresh
function FT.RouteCategory(c) category = c; page = 1; refresh() end
function FT.RouteSearch(t) if searchBox then searchBox:SetText(t or '') end; page = 1; refresh() end
function FT.RouteCount() return #filtered end
FT.MapServices = servicesOn

local function showPing(e)
 local parts = FT.mapParts
 local overlay = parts and parts.overlay
 if not overlay then return end
 if not ping then
  ping = overlay:CreateTexture(nil, 'OVERLAY')
  ping:SetTexture('Interface\\Cooldown\\star4'); ping:SetBlendMode('ADD'); ping:SetSize(46, 46)
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

local function showDetail(e)
 selected = e
 if not detail then return end
 if not e then
  detail.text:SetText(''); detail.empty:Show(); detail.go:Hide(); detail.map:Hide(); detail.save:Hide()
  return
 end
 detail.empty:Hide(); detail.go:Show(); detail.map:Show(); detail.save:Show()
 local lines = {('|cffffd100%s|r'):format(e.name)}
 if e.sub and e.sub ~= '' then lines[#lines + 1] = e.sub end
 local zone = FT.MapName and FT.MapName(e.map) or ''
 lines[#lines + 1] = ('%s  %.1f, %.1f%s'):format(zone, e.x * 100, e.y * 100, e.dist and ('  ·  ' .. math.floor(e.dist + 0.5) .. ' yd') or '')
 local f = nearestFlight(e)
 if f then lines[#lines + 1] = '|cff9aa0a6En yakın uçuş: ' .. f.name .. '|r' end
 if e.questId and FT.QuestStatus then lines[#lines + 1] = FT.QuestStatus(e.questId) end
 detail.text:SetText(table.concat(lines, '\n'))
 detail:Show()
end

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

-- Panel haritanın yanında dikey durur: varsayılan sağda; yer yoksa (ya da seçilirse) solda;
-- ikisi de sığmıyorsa (tam ekran harita) haritanın içinde sağ kenarda.
local PANEL_W, LIST_TOP, BOTTOM_H = 340, 252, 198
local sideButton

local function layout()
 if not (panel and rows) then return end
 local mapHeight = WorldMapFrame and WorldMapFrame.GetHeight and WorldMapFrame:GetHeight() or 700
 local h = math.max(600, math.min(840, mapHeight))
 local scale = (WorldMapFrame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
 local right, left = WorldMapFrame:GetRight(), WorldMapFrame:GetLeft()
 local screen = UIParent:GetWidth() or 1920
 local wantLeft = ForeverTrailSettings.routeSide == 'left'
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
 panel:SetSize(PANEL_W, h)
 PER = math.max(4, math.min(11, math.floor((h - BOTTOM_H - LIST_TOP) / 30)))
 for i, r in ipairs(rows) do
  r:ClearAllPoints()
  r:SetPoint('TOPLEFT', 10, -LIST_TOP - (i - 1) * 30)
  r:SetShown(i <= PER)
 end
 if sideButton then sideButton:SetText(wantLeft and 'Sağa al' or 'Sola al') end
end

local CAT_ROWS = 4

local function create()
 panel = FT.NewWindow('ForeverTrailMapRoute', WorldMapFrame)
 FT.mapRoute = panel
 panel:SetSize(PANEL_W, 700)
 panel:SetClampedToScreen(true)
 panel:SetFrameStrata(WorldMapFrame:GetFrameStrata())
 panel:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 20)

 -- Üst: başlık, ne yapılır, arama
 local title = panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 title:SetPoint('TOPLEFT', 12, -8); title:SetText('Yol sor')
 if FT.StyleTitle then FT.StyleTitle(title) end
 sideButton = FT.NewButton(panel, 'Sola al', 62, 18); sideButton:SetPoint('TOPRIGHT', -8, -6)
 sideButton:SetScript('OnClick', function()
  ForeverTrailSettings.routeSide = ForeverTrailSettings.routeSide == 'left' and 'right' or 'left'
  layout()
 end)
 attachTip(sideButton, 'Panelin yeri', 'Paneli haritanın soluna ya da sağına taşır. Yer yoksa harita içinde açılır.')
 local how = panel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 how:SetPoint('TOPLEFT', 12, -28); how:SetWidth(316); how:SetJustifyH('LEFT'); how:SetTextColor(0.8, 0.78, 0.72)
 how:SetText('Nereye gitmek istiyorsun?\n1) Bir tür seç ya da ara   2) Listeden bir yere tıkla\n3) Ok ve harita seni oraya götürür')
 searchBox = CreateFrame('EditBox', nil, panel, 'InputBoxTemplate')
 searchBox:SetSize(170, 20); searchBox:SetPoint('TOPLEFT', 20, -78); searchBox:SetAutoFocus(false)
 searchHint = panel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 searchHint:SetPoint('LEFT', searchBox, 'LEFT', 6, 0); searchHint:SetTextColor(0.5, 0.5, 0.5); searchHint:SetText('Ara: han, tamirci, uçuş...')
 searchBox:SetScript('OnEditFocusGained', function() searchHint:Hide() end)
 searchBox:SetScript('OnEditFocusLost', function(self) if (self:GetText() or '') == '' then searchHint:Show() end end)
 searchBox:SetScript('OnTextChanged', function(self)
  page = 1
  if (self:GetText() or '') ~= '' then searchHint:Hide() end
  refresh()
 end)
 searchBox:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
 everywhere = FT.NewButton(panel, 'Her yer: kapalı', 118, 20); everywhere:SetPoint('TOPLEFT', 204, -78)
 everywhere:SetScript('OnClick', function() ForeverTrailSettings.routeEverywhere = not ForeverTrailSettings.routeEverywhere; page = 1; refresh() end)
 attachTip(everywhere, 'Her yerde ara', 'Kapalıyken yalnızca baktığın haritada aranır. Açıkken tüm dünyada aranır (en az 3 harf yaz).')

 -- Türler: 4 sütun
 catButtons = {}
 for i, c in ipairs(CATS) do
  local b = FT.NewButton(panel, c.label, 76, 22)
  b:SetPoint('TOPLEFT', 10 + ((i - 1) % 4) * 80, -106 - math.floor((i - 1) / 4) * 25)
  b.key = c.key
  b:SetScript('OnClick', function() category = c.key; page = 1; refresh() end)
  attachTip(b, c.label, c.tip)
  catButtons[i] = b
 end

 -- Sonuç listesi
 hint = panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
 hint:SetPoint('TOPLEFT', 12, -(LIST_TOP - 18)); hint:SetWidth(316); hint:SetJustifyH('LEFT'); hint:SetWordWrap(false)
 emptyText = panel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
 emptyText:SetPoint('TOPLEFT', 14, -(LIST_TOP + 10)); emptyText:SetWidth(312); emptyText:SetJustifyH('LEFT'); emptyText:SetTextColor(0.8, 0.78, 0.72); emptyText:Hide()
 rows = {}
 for i = 1, 11 do
  local r = CreateFrame('Button', nil, panel)
  r:SetSize(320, 28); r:SetPoint('TOPLEFT', 10, -LIST_TOP - (i - 1) * 30)
  r.bg = r:CreateTexture(nil, 'BACKGROUND'); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)
  r.bar = r:CreateTexture(nil, 'ARTWORK'); r.bar:SetSize(3, 24); r.bar:SetPoint('LEFT', 1, 0)
  r:SetHighlightTexture('Interface\\Buttons\\WHITE8X8'); r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
  r.name = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight'); r.name:SetPoint('TOPLEFT', 9, -3); r.name:SetWidth(236); r.name:SetJustifyH('LEFT'); r.name:SetWordWrap(false)
  r.sub = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall'); r.sub:SetPoint('BOTTOMLEFT', 9, 3); r.sub:SetWidth(236); r.sub:SetJustifyH('LEFT'); r.sub:SetTextColor(0.65, 0.62, 0.56); r.sub:SetWordWrap(false)
  r.dist = r:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall'); r.dist:SetPoint('RIGHT', -6, 0); r.dist:SetWidth(70); r.dist:SetJustifyH('RIGHT'); r.dist:SetWordWrap(false)
  r:SetScript('OnEnter', function(self)
   showPing(self.entry)
   if self.entry then showDetail(self.entry) end
   if self.entry and self.entry.npcId and FT.ShowTooltipModel then
    GameTooltip:SetOwner(self, 'ANCHOR_LEFT'); GameTooltip:SetText(self.entry.name, 0.8, 0.55, 1); GameTooltip:AddLine(self.entry.sub or '', 1, 1, 1)
    if FT.ShowTip then FT.ShowTip(GameTooltip) else GameTooltip:Show() end
    pcall(FT.ShowTooltipModel, self.entry.npcId)
   end
  end)
  r:SetScript('OnLeave', function() showPing(nil); if GameTooltip then GameTooltip:Hide() end end)
  r:SetScript('OnClick', function(self)
   local e = self.entry
   if not e then return end
   showDetail(e)
   goTo(e)
   FT.Print(('Yol: %s%s'):format(e.name, e.dist and (' (' .. math.floor(e.dist + 0.5) .. ' yd)') or ''))
  end)
  rows[i] = r
 end

 -- Alt blok (aşağıdan yukarı): sayfa düğmeleri / rota planı, ipucu, hedef satırı, ayrıntı
 local prev = FT.NewButton(panel, '< Önceki', 70, 22); prev:SetPoint('BOTTOMLEFT', 10, 8)
 prev:SetScript('OnClick', function() page = page - 1; refresh() end)
 local nextB = FT.NewButton(panel, 'Sonraki >', 70, 22); nextB:SetPoint('LEFT', prev, 'RIGHT', 4, 0)
 nextB:SetScript('OnClick', function() page = page + 1; refresh() end)
 pageText = panel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 pageText:SetPoint('LEFT', nextB, 'RIGHT', 6, 0); pageText:SetTextColor(0.75, 0.72, 0.66)
 local plan = FT.NewButton(panel, 'Rota planı', 80, 22); plan:SetPoint('BOTTOMRIGHT', -8, 8)
 plan:SetScript('OnClick', function() if FT.ShowRoutePlan then FT.ShowRoutePlan() end end)
 attachTip(plan, 'Rota planı', 'Hedeflerini ve görevlerini en verimli sırayla listeler.')
 local tip = panel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 tip:SetPoint('BOTTOMLEFT', 12, 36); tip:SetWidth(316); tip:SetJustifyH('LEFT'); tip:SetTextColor(0.6, 0.58, 0.54)
 tip:SetText('İpucu: Haritada Ctrl+tıkla, istediğin noktaya ok koy.')
 targetText = panel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
 targetText:SetPoint('BOTTOMLEFT', 12, 66); targetText:SetWidth(214); targetText:SetJustifyH('LEFT'); targetText:SetWordWrap(false)
 targetClear = FT.NewButton(panel, 'Hedefi kaldır', 92, 20); targetClear:SetPoint('BOTTOMRIGHT', -8, 62)
 targetClear:SetScript('OnClick', function() if FT.ClearCustomTarget then FT.ClearCustomTarget() end; refresh() end)
 attachTip(targetClear, 'Hedefi kaldır', 'Okun gösterdiği özel hedefi siler; ok görev rehberine döner.')

 detail = CreateFrame('Frame', nil, panel); detail:SetSize(324, 104); detail:SetPoint('BOTTOMLEFT', 8, 90)
 detail.bg = detail:CreateTexture(nil, 'BACKGROUND'); detail.bg:SetAllPoints(); detail.bg:SetColorTexture(0, 0, 0, 0.3)
 detail.text = detail:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall'); detail.text:SetPoint('TOPLEFT', 8, -7); detail.text:SetWidth(308); detail.text:SetJustifyH('LEFT'); detail.text:SetJustifyV('TOP')
 detail.empty = detail:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall'); detail.empty:SetPoint('TOPLEFT', 8, -7); detail.empty:SetWidth(308); detail.empty:SetJustifyH('LEFT'); detail.empty:SetTextColor(0.7, 0.68, 0.62)
 detail.empty:SetText('Listede bir yerin üzerine gel:\nayrıntısı burada görünür, haritada yeri parlar.')
 local dGo = FT.NewButton(detail, 'Yol göster', 96, 22); dGo:SetPoint('BOTTOMLEFT', 6, 6)
 dGo:SetScript('OnClick', function() goTo(selected) end)
 attachTip(dGo, 'Yol göster', 'Ok ve harita seni bu yere yönlendirir.')
 local dMap = FT.NewButton(detail, 'Haritada gör', 100, 22); dMap:SetPoint('LEFT', dGo, 'RIGHT', 4, 0)
 dMap:SetScript('OnClick', function() local e = selected; if e and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(e.map); showPing(e) end end)
 attachTip(dMap, 'Haritada gör', 'Haritayı bu yerin olduğu bölgeye çevirir.')
 local dSave = FT.NewButton(detail, 'Kaydet', 84, 22); dSave:SetPoint('LEFT', dMap, 'RIGHT', 4, 0)
 dSave:SetScript('OnClick', function()
  local e = selected; if not e then return end
  ForeverTrailSettings.places = ForeverTrailSettings.places or {}
  table.insert(ForeverTrailSettings.places, {name=e.name, cat=e.sub or 'Kayıtlı', map=e.map, x=e.x, y=e.y})
  FT.Print('Kaydedildi: ' .. e.name .. ' ("Kayıtlarım" türünde bulursun)')
 end)
 attachTip(dSave, 'Yerlerime ekle', 'Bu yeri kaydeder; sonra "Kayıtlarım" türünden hızlıca bulursun.')
 detail.go, detail.map, detail.save = dGo, dMap, dSave
 dGo:Hide(); dMap:Hide(); dSave:Hide()

 panel:SetScript('OnShow', function() layout(); page = 1; refresh() end)
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
 if hooksecurefunc then pcall(hooksecurefunc, WorldMapFrame, 'SetMapID', function() if panel:IsShown() then page = 1; refresh() end end) end
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
