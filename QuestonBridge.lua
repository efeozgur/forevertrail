-- Queston Forever ile birlikte çalışma (onun dosyalarına dokunmadan, yalnızca açık API'si ile):
--  * Türkçe çeviriyi Queston'un RegisterLocale API'siyle yükler
--  * ForeverTrail ayarlarını Queston'un ayar penceresine "ForeverTrail" grubu olarak ekler
--  * ForeverTrail'in ayar düğmeleri Queston'un ayar penceresini açar
-- ForeverTrail, Queston'dan önce yüklenir (klasör adı sırası); bu yüzden Queston kendini başlatmadan önce buradayız.
local _, FT = ...

local function enabled(name)
 if C_AddOns and C_AddOns.GetAddOnEnableState then
  local ok, state = pcall(C_AddOns.GetAddOnEnableState, name, UnitName and UnitName('player'))
  if ok and type(state) == 'number' then return state > 0 end
  ok, state = pcall(C_AddOns.GetAddOnEnableState, UnitName and UnitName('player'), name)
  if ok and type(state) == 'number' then return state > 0 end
 end
 if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) then return true end
 return false
end
FT.AddOnEnabled = enabled

local function settingsModule(Q)
 return Q and (rawget(Q, 'Settings') or (Q.modules and Q.modules.Settings) or Q.Settings)
end

----------------------------------------------------------------------
-- Ayar sayfaları
----------------------------------------------------------------------
local function after() if FT.SettingsAfterChange then FT.SettingsAfterChange() end end

local function addPages(opt)
 if not (opt and opt.AddGroup and opt.AddPage and opt.AddCustom and FT.BridgeGroups) then return end
 if opt.pageByID and opt.pageByID.ft_rehber then return end
 opt:AddGroup('forevertrail', 'ForeverTrail')
 for gi, g in ipairs(FT.BridgeGroups()) do
  opt:AddPage(g.key, g.title, g.sub)
  local sectioned = false
  for i, d in ipairs(g.defs) do
   local path = 'forevertrail.' .. g.key .. '.' .. (d.key or ('i' .. i))
   if d.type == 'header' then
    opt:AddSection(d.text); sectioned = true
   else
    if not sectioned then opt:AddSection(g.title); sectioned = true end
    if d.type == 'check' then
     opt:AddCustom('checkbox', path, d.label, d.tip, {
      getValue = function() return FT.GetSetting and FT.GetSetting(d.key) == true end,
      setValue = function(v)
       v = v == true
       ForeverTrailSettings[d.key] = v
       if d.apply then pcall(d.apply, v) end
       after()
      end})
    elseif d.type == 'slider' then
     opt:AddCustom('slider', path, d.label, d.tip, {
      minimum = d.min, maximum = d.max, step = d.step,
      getValue = function() return FT.Scale and FT.Scale(d.key) or 1 end,
      setValue = function(v) ForeverTrailSettings['c_' .. d.key] = math.floor(v / d.step + 0.5) * d.step; after() end})
    elseif d.type == 'choice' then
     local values = {}
     for _, it in ipairs(d.list) do values[#values + 1] = {it[1], it[2]} end
     opt:AddCustom('dropdown', path, d.label, d.tip, {
      values = values,
      getValue = function() return ForeverTrailSettings[d.key] or d.default end,
      setValue = function(v) ForeverTrailSettings[d.key] = v; after() end})
    elseif d.type == 'buttons' and opt.AddAction then
     for j, b in ipairs(d.list) do
      opt:AddAction('ft_' .. gi .. '_' .. i .. '_' .. j, b[1], b[1], function() pcall(b[2]) end)
     end
    end
   end
  end
 end
end
FT.AddQuestonPages = addPages

----------------------------------------------------------------------
-- Queston yüklenirken
----------------------------------------------------------------------
local ev = CreateFrame('Frame')
ev:RegisterEvent('ADDON_LOADED')
ev:SetScript('OnEvent', function(self, _, name)
 if name ~= 'QuestonForever' then return end
 self:UnregisterAllEvents()
 local Q = _G.QuestonForever
 if type(Q) ~= 'table' then return end
 FT.Queston = Q
 -- Türkçe: oyun İngilizce ise Queston'un İngilizce kataloğunun üstüne yazar
 if Q.RegisterLocale and FT.QuestonTR and not (ForeverTrailSettings and ForeverTrailSettings.questonTR == false) then
  pcall(Q.RegisterLocale, Q, 'enUS', FT.QuestonTR)
  if Q.locale and Q.locale ~= 'enUS' then pcall(Q.RegisterLocale, Q, Q.locale, FT.QuestonTR) end
 end
 -- ForeverTrail sayfaları: Queston ayarları kurulurken sona eklenir
 local opt = settingsModule(Q)
 if opt then
  if opt.initialized then
   pcall(addPages, opt)
  elseif type(opt.DefineNavigation) == 'function' then
   hooksecurefunc(opt, 'DefineNavigation', function(o) pcall(addPages, o) end)
  end
 end
 -- Ayarlar düğmeleri Queston'un penceresini açsın
 FT.OpenQuestonSettings = function(page)
  local o = settingsModule(Q)
  if o and o.Open then
   local ok = pcall(o.Open, o, page or 'ft_rehber')
   if ok then return true end
  end
 end
 FT.OpenFTOptions = FT.OpenFTOptions or FT.OpenQuestieOptions
 local PAGE = {q_genel = 'ft_rehber', q_harita = 'ft_rehber', q_simge = 'ft_simge', q_oto = 'ft_sinif', sinifm = 'ft_sinif',
  uyari = 'ft_uyari', q_takip = 'ft_gorunum', q_plaka = 'ft_gorunum', q_profil = 'ft_gorunum', q_gelismis = 'ft_gorunum', gorunum = 'ft_gorunum'}
 FT.OpenQuestieOptions = function(tab)
  if FT.OpenQuestonSettings(PAGE[tab or ''] or (tab and tab:match('^ft_') and tab) or 'ft_rehber') then return end
  if FT.OpenFTOptions then return FT.OpenFTOptions(tab) end
 end
 FT.ToggleSettings = function() FT.OpenQuestieOptions() end
end)
