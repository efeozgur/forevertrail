-- ForeverTrail ayarlarını Questie ayar penceresine sekme olarak ve
-- ESC > Seçenekler > AddOns paneline kategori olarak ekler.
local _, FT = ...

local function esc(s) return s and (tostring(s):gsub('%%', '%%%%')) end

local function openFTWindow(tab)
 if FT.OpenFTOptions then return FT.OpenFTOptions(tab) end
 if FT.ToggleHub then FT.ToggleHub('ayarlar') end
end

local function itemsFor(tabs, seen)
 local out = {}
 for _, it in ipairs(FT.SettingsItems or {}) do
  if tabs[it.tab] and not seen[it.key] then
   seen[it.key] = true
   out[#out + 1] = {type = 'check', key = it.key, label = it.label, apply = it.apply}
  end
 end
 return out
end

-- Sekme grupları: hem Questie penceresi hem Blizzard paneli bunları kullanır
function FT.BridgeGroups()
 local P = FT.QuestiePageDefs or {}
 local groups = {
  {key = 'ft_rehber', title = 'ForeverTrail', sub = 'Rehber, ok, rota, harita ve yolculuk', icon = 'Interface\\Icons\\Ability_Hunter_Pathfinding',
   pages = {'q_genel', 'q_harita'}, tabs = {gorev = true, yol = true, harita = true}},
  {key = 'ft_simge', title = 'FT Simgeler', sub = 'ForeverTrail harita ve mini harita simgeleri', icon = 'Interface\\Icons\\INV_Misc_Map_01',
   pages = {'q_simge'}, tabs = {simge = true}},
  {key = 'ft_sinif', title = 'Sınıf ve Eşya', sub = 'Yetenek planı, eşya karşılaştırma, meslek, çanta ve satıcı', icon = 'Interface\\Icons\\INV_Misc_Book_11',
   pages = {'q_oto'}, tabs = {sinifm = true, canta = true}},
  {key = 'ft_uyari', title = 'Uyarılar', sub = 'Uyarılar, nadir yaratıklar, sesler ve Janti şakaları', icon = 'Interface\\Icons\\Spell_Holy_SealOfWisdom',
   pages = {}, tabs = {uyari = true}},
  {key = 'ft_gorunum', title = 'FT Görünüm', sub = 'Görev kutusu, pencereler, profiller ve araçlar', icon = 'Interface\\Icons\\INV_Misc_Note_01',
   pages = {'q_takip', 'q_plaka', 'q_profil', 'q_gelismis'}, tabs = {kutu = true, gorunum = true}},
 }
 for _, g in ipairs(groups) do
  local defs, seen = {}, {}
  if g.key == 'ft_rehber' then
   local ov = FT.ActiveOverlaps
   if ov then
    defs[#defs + 1] = {type = 'header', text = FT.QuestonActive and 'Queston Forever ile çakışan katmanlar' or 'Questie ile çakışan katmanlar'}
    for _, o in ipairs(ov) do
     seen[o.key] = true
     defs[#defs + 1] = {type = 'check', key = o.key, label = o.label, overlap = true, apply = function(v)
      if o.key == 'card' and FT.card then if v then FT.card:Show() else FT.card:Hide() end end
      if o.key == 'tracker' and FT.tracker then if v then FT.tracker:Show() else FT.tracker:Hide() end end
      if FT.BumpLayers then FT.BumpLayers() end
     end}
    end
   end
  end
  for _, pk in ipairs(g.pages) do
   for _, d in ipairs(P[pk] or {}) do
    if d.key and seen[d.key] then
    else
     if d.key then seen[d.key] = true end
     if d.type ~= 'buttons' then defs[#defs + 1] = d end
    end
   end
  end
  local extra = itemsFor(g.tabs, seen)
  if #extra > 0 then
   defs[#defs + 1] = {type = 'header', text = 'Diğer'}
   for _, d in ipairs(extra) do defs[#defs + 1] = d end
  end
  if g.key == 'ft_uyari' then
   defs[#defs + 1] = {type = 'header', text = 'Janti şakaları'}
   defs[#defs + 1] = {type = 'check', key = 'janti', label = 'Ekranın ortasında şaka mesajları (/janti on|off)'}
   defs[#defs + 1] = {type = 'choice', key = 'c_rareRepeat', default = '10', label = 'Nadir uyarısı tekrar', list = {{'5', '5 dk'}, {'10', '10 dk'}, {'15', '15 dk'}, {'30', '30 dk'}, {'once', 'Bir kez'}}}
  end
  if g.key == 'ft_gorunum' and not FT.QuestonActive then
   defs[#defs + 1] = {type = 'header', text = 'Tema ve renkler'}
   defs[#defs + 1] = {type = 'buttons', list = {
    {'Özelleştir (tema, renk)', function() openFTWindow('ozel') end},
    {'Görünüm ayarları', function() openFTWindow('gorunum') end},
   }}
  end
  if FT.QuestonActive and FT.QuestonDup then
   local kept, pendingHeader = {}, nil
   for _, d in ipairs(defs) do
    if d.type == 'header' then pendingHeader = d
    elseif not (d.key and FT.QuestonDup[d.key] and not d.overlap) then
     if pendingHeader then kept[#kept + 1] = pendingHeader; pendingHeader = nil end
     kept[#kept + 1] = d
    end
   end
   defs = kept
  end
  g.defs = defs
 end
 -- Araçlar: rehber merkezindeki araçlarla aynı liste, ayar penceresinde tek sayfa
 if FT.ToolDefs then
  local defs = {}
  for _, sec in ipairs(FT.ToolDefs()) do
   if #sec.list > 0 then
    defs[#defs + 1] = {type = 'header', text = sec.title}
    local list = {}
    for _, d in ipairs(sec.list) do list[#list + 1] = {d[1], d[2]} end
    defs[#defs + 1] = {type = 'buttons', list = list}
   end
  end
  groups[#groups + 1] = {key = 'ft_araclar', title = 'Araçlar', sub = 'ForeverTrail pencereleri ve araçları', icon = 'Interface\\Icons\\Trade_Engineering', pages = {}, tabs = {}, defs = defs}
 end
 local out = {}
 for _, g in ipairs(groups) do if #g.defs > 0 then out[#out + 1] = g end end
 return out
end

-- FT tanımlarını Questie motorunun öğe biçimine çevir
local function toQuestieItems(defs)
 local out, n = {}, 0
 local function add(t) n = n + 1; t.order = n; out['i' .. n] = t end
 local after = function() if FT.SettingsAfterChange then FT.SettingsAfterChange() end end
 for _, d in ipairs(defs) do
  if d.type == 'header' then
   add({type = 'divider', title = esc(d.text), width = 'full', newline = true})
  elseif d.type == 'check' then
   add({type = 'checkbox', title = esc(d.label), tooltip = esc(d.tip), width = (#(d.label or '') > 40) and 'full' or 'half',
    get = function() return FT.GetSetting and FT.GetSetting(d.key) end,
    set = function(_, v)
     v = v and true or false
     ForeverTrailSettings[d.key] = v
     if d.apply then pcall(d.apply, v) end
     after()
    end})
  elseif d.type == 'slider' then
   add({type = 'slider', title = esc(d.label), width = 'half', min = d.min, max = d.max, step = d.step,
    get = function() return FT.Scale and FT.Scale(d.key) or 1 end,
    set = function(_, v)
     ForeverTrailSettings['c_' .. d.key] = math.floor(v / d.step + 0.5) * d.step
     after()
    end})
  elseif d.type == 'choice' then
   local opts, order = {}, {}
   for _, it in ipairs(d.list) do opts[it[1]] = esc(it[2]); order[#order + 1] = it[1] end
   add({type = 'dropdown', title = esc(d.label), width = 'half', options = opts, sortOrder = order,
    get = function() return ForeverTrailSettings[d.key] or d.default end,
    set = function(k) ForeverTrailSettings[d.key] = k; after() end})
  elseif d.type == 'buttons' then
   for i, b in ipairs(d.list) do
    add({type = 'button', title = esc(b[1]), btnLabel = esc(b[1]), width = 'third', newline = (i == 1),
     func = function() pcall(b[2]) end})
   end
  end
 end
 return out
end

----------------------------------------------------------------------
-- 1) Questie ayar penceresine sekmeler
----------------------------------------------------------------------
local QOE = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule('QuestieOptionsEngine')
if QOE and QOE.tabs then
 for i, g in ipairs(FT.BridgeGroups()) do
  local key = g.key
  QOE.tabs[key] = {Initialize = function()
   local grp
   for _, x in ipairs(FT.BridgeGroups()) do if x.key == key then grp = x end end
   return {title = grp.title, subtitle = grp.sub, order = 20 + i, icon = grp.icon, noBlizzard = true, items = toQuestieItems(grp.defs)}
  end}
 end
end

local PAGE_TO_TAB = {q_genel = 'ft_rehber', q_harita = 'ft_rehber', q_simge = 'ft_simge', q_oto = 'ft_sinif', sinifm = 'ft_sinif',
 uyari = 'ft_uyari', q_takip = 'ft_gorunum', q_plaka = 'ft_gorunum', q_profil = 'ft_gorunum', q_gelismis = 'ft_gorunum', gorunum = 'ft_gorunum'}

local function selectQuestieTab(key)
 local tab = _G['QuestieStandaloneSettings_Tab_' .. key]
 if tab and tab.button then tab.button:Click() end
end

-- Eski pencere yedek olarak kalsın; ayarlar artık Questie penceresinde
FT.OpenFTOptions = FT.OpenFTOptions or FT.OpenQuestieOptions
if QOE and QOE.ShowFrame then
 FT.OpenQuestieOptions = function(tab)
  if QOE:IsShown() and not tab then QOE:HideFrame(); return end
  local ok = pcall(QOE.ShowFrame, QOE)
  if not ok or not QOE.popup then return FT.OpenFTOptions and FT.OpenFTOptions(tab) end
  selectQuestieTab(PAGE_TO_TAB[tab or ''] or (tab and tab:match('^ft_') and tab) or 'ft_rehber')
 end
 FT.ToggleSettings = function() FT.OpenQuestieOptions() end
end

----------------------------------------------------------------------
-- 2) ESC > Seçenekler > AddOns > ForeverTrail
----------------------------------------------------------------------
local function makeCanvas(group)
 local canvas = CreateFrame('Frame')
 canvas:Hide()
 canvas:SetScript('OnShow', function(self)
  if self.built then return end
  self.built = true
  local title = self:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
  title:SetPoint('TOPLEFT', 16, -16); title:SetText(group.title)
  local sub = self:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
  sub:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -6); sub:SetText(group.sub)
  local scroll = CreateFrame('ScrollFrame', nil, self, 'UIPanelScrollFrameTemplate')
  scroll:SetPoint('TOPLEFT', 16, -60); scroll:SetPoint('BOTTOMRIGHT', -32, 10)
  local child = CreateFrame('Frame', nil, scroll)
  local w = math.max(500, (self:GetWidth() or 620) - 60)
  child:SetSize(w, 10)
  scroll:SetScrollChild(child)
  local ok, endY = pcall(FT.BuildOptions, child, -4, w - 10, group.defs)
  child:SetHeight((ok and endY and -endY or 400) + 16)
 end)
 return canvas
end

local registered
local function registerBlizzard()
 if registered or not (Settings and Settings.RegisterCanvasLayoutCategory and FT.BuildOptions) then return end
 registered = true
 local groups = FT.BridgeGroups()
 local main
 for _, g in ipairs(groups) do
  local canvas = makeCanvas(g)
  if not main then
   main = Settings.RegisterCanvasLayoutCategory(canvas, 'ForeverTrail')
   Settings.RegisterAddOnCategory(main)
   FT.SettingsCategory = main
  else
   local sub = Settings.RegisterCanvasLayoutSubcategory(main, canvas, g.title)
   if Settings.RegisterAddOnCategory then pcall(Settings.RegisterAddOnCategory, sub) end
  end
 end
end

local ev = CreateFrame('Frame')
ev:RegisterEvent('PLAYER_LOGIN')
ev:SetScript('OnEvent', function() pcall(registerBlizzard) end)
