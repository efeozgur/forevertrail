local _, FT = ...

-- Questie'nin görünümü birebir:
-- 1) Ayarlar penceresi: Blizzard portreli pencere, sağ kenarda simgeli yan sekmeler, kahverengi zemin
-- 2) Haritada kasaba işaretleri (tamirci, han, uçuş, banka, müzayede, ahır, posta, sınıf/meslek eğitmeni)
-- 3) Yetenek penceresinin yanında yetenek planı paneli

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function font(fs, size, flags)
 if fs:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', size, flags or '') == false then fs:SetFont('Fonts\\ARIALN.TTF', size, flags or '') end
 fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.9)
end
local function hasAtlas(name) return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil end

----------------------------------------------------------------------
-- 1) Questie tarzı ayarlar penceresi
----------------------------------------------------------------------
function FT.QuestieOptionsOn()
 return not ForeverTrailSettings or ForeverTrailSettings.c_optionsStyle ~= 'ft'
end

local TAB_ICONS = {
 gorev = 'Interface\\Icons\\INV_Misc_Book_09', sinifm = 'Interface\\Icons\\INV_Misc_Book_11', simge = 'Interface\\Icons\\INV_Misc_Map_01',
 kutu = 'Interface\\Icons\\INV_Misc_Note_01', harita = 'Interface\\Icons\\INV_Misc_Spyglass_03', yol = 'Interface\\Icons\\Ability_Hunter_Pathfinding', canta = 'Interface\\Icons\\INV_Misc_Bag_08',
 uyari = 'Interface\\Icons\\Ability_Warrior_BattleShout', gorunum = 'Interface\\Icons\\INV_Misc_Gem_Pearl_04', ozel = 'Interface\\Icons\\Trade_Engineering',
 g_genel = 'Interface\\Icons\\INV_Misc_Book_09', g_harita = 'Interface\\Icons\\INV_Misc_Map_01', g_oto = 'Interface\\Icons\\Ability_Hunter_Pathfinding',
 g_sinif = 'Interface\\Icons\\INV_Misc_Book_11', g_gorunum = 'Interface\\Icons\\INV_Misc_Gem_Pearl_04', g_gelismis = 'Interface\\Icons\\INV_Misc_Gear_01',
}

local win, sideTabs = nil, {}
local function selectTab(key)
 if FT.SettingsTab then FT.SettingsTab(key) end
 local group = FT.SettingsGroupOf and FT.SettingsGroupOf(key) or key
 for _, t in ipairs(sideTabs) do t.Selected:SetShown(t.key == group) end
end

local function buildWindow()
 if win then return win end
 local ok, w = pcall(CreateFrame, 'Frame', 'ForeverTrailOptionsWindow', UIParent, 'PortraitFrameTemplate')
 if not ok or not w then ok, w = pcall(CreateFrame, 'Frame', 'ForeverTrailOptionsWindow', UIParent, 'ButtonFrameTemplate') end
 if not ok or not w then w = FT.NewWindow('ForeverTrailOptionsWindow', UIParent) end
 win = w
 local h = math.floor((GetScreenHeight and GetScreenHeight() or 900) * 0.7)
 w:SetSize(675, math.max(700, h)); w:SetPoint('CENTER'); w:SetFrameStrata('HIGH')
 w:SetMovable(true); w:SetClampedToScreen(true); w:EnableMouse(true)
 if w.SetTitle then pcall(w.SetTitle, w, 'ForeverTrail') end
 if type(w.Bg) == 'table' and w.Bg.SetColorTexture then w.Bg:SetColorTexture(30 / 255, 23 / 255, 18 / 255, 0.85) end
 if w.SetPortraitToAsset then pcall(w.SetPortraitToAsset, w, 'Interface\\Icons\\INV_Misc_Map_01')
 elseif w.SetPortraitTextureRaw then pcall(w.SetPortraitTextureRaw, w, 'Interface\\Icons\\INV_Misc_Map_01')
 elseif type(w.portrait) == 'table' then w.portrait:SetTexture('Interface\\Icons\\INV_Misc_Map_01') end
 local drag = CreateFrame('Frame', nil, w)
 drag:SetPoint('TOPLEFT', 55, 0); drag:SetPoint('TOPRIGHT', -30, 0); drag:SetHeight(28); drag:EnableMouse(true)
 drag:SetScript('OnMouseDown', function() w:StartMoving() end)
 drag:SetScript('OnMouseUp', function() w:StopMovingOrSizing() end)
 w.canvas = CreateFrame('Frame', nil, w)
 w.canvas:SetPoint('TOPLEFT', 10, -30); w.canvas:SetPoint('BOTTOMRIGHT', -10, 10)
 if UISpecialFrames then tinsert(UISpecialFrames, 'ForeverTrailOptionsWindow') end
 -- sağ kenarda yan sekmeler (Questie / büyü kitabı tarzı)
 local forever = hasAtlas('common-sidetab')
 local prev
 for _, def in ipairs(FT.SettingsTabs or {}) do
  local tab = CreateFrame('Frame', nil, w)
  if not prev then tab:SetPoint('TOPLEFT', w, 'TOPRIGHT', forever and -1 or -2, -35)
  else tab:SetPoint('TOPLEFT', prev, 'BOTTOMLEFT', 0, forever and 0 or 10) end
  local bgT = tab:CreateTexture(nil, 'BACKGROUND'); bgT:SetPoint('TOPLEFT')
  if forever then bgT:SetAtlas('common-sidetab', true); tab:SetSize(bgT:GetSize())
  else bgT:SetTexture('Interface\\SpellBook\\SpellBook-SkillLineTab'); tab:SetSize(64, 64) end
  local icon = tab:CreateTexture(nil, 'ARTWORK')
  if forever then icon:SetPoint('CENTER', -1, 0); icon:SetSize(40, 40) else icon:SetPoint('TOPLEFT', 1, -9); icon:SetSize(36, 36) end
  icon:SetTexture(TAB_ICONS[def.key] or 'Interface\\Icons\\INV_Misc_QuestionMark')
  if forever and tab.CreateMaskTexture then
   local mask = tab:CreateMaskTexture(nil, 'ARTWORK'); mask:SetAtlas('common-sidetab-mask', true); mask:SetPoint('CENTER', -2, 0); mask:SetSize(40, 40)
   icon:AddMaskTexture(mask)
  end
  local sel = tab:CreateTexture(nil, 'OVERLAY')
  if forever then sel:SetAtlas('common-sidetab-selected', true); sel:SetPoint('TOPLEFT')
  else sel:SetTexture('Interface\\Buttons\\CheckButtonHilight'); sel:SetBlendMode('ADD'); sel:SetPoint('TOPLEFT', 1, -9); sel:SetSize(36, 36) end
  sel:Hide(); tab.Selected = sel
  local b = CreateFrame('Button', nil, tab)
  if forever then b:SetSize(50, 50); b:SetPoint('CENTER', -2, -1) else b:SetSize(36, 36); b:SetPoint('TOPLEFT', 1, -9) end
  local hl = b:CreateTexture(nil, 'HIGHLIGHT')
  if forever then hl:SetAtlas('common-sidetab-hover', true); hl:SetPoint('TOPLEFT', tab, 'TOPLEFT') else hl:SetTexture('Interface\\Buttons\\ButtonHilight-Square'); hl:SetAllPoints(b) end
  hl:SetBlendMode('ADD')
  b:SetScript('OnClick', function() selectTab(def.key) end)
  b:SetScript('OnEnter', function(self) GameTooltip:SetOwner(self, 'ANCHOR_RIGHT'); GameTooltip:SetText(def.label, 1, 0.82, 0); GameTooltip:AddLine(def.desc or '', 1, 1, 1, true); if FT.ShowTip then FT.ShowTip(GameTooltip) else GameTooltip:Show() end end)
  b:SetScript('OnLeave', function() GameTooltip:Hide() end)
  tab.key = def.key
  sideTabs[#sideTabs + 1] = tab
  prev = tab
 end
 w:Hide()
 return w
end

-- Ayarlar içeriğini pencereye al: kendi sol listesini gizle, sayfaları tuvale yerleştir
local function adopt(w)
 local s = FT.settings
 if not s then return end
 s:SetParent(w.canvas); s:ClearAllPoints(); s:SetAllPoints(w.canvas)
 s:SetFrameStrata(w:GetFrameStrata()); s:SetFrameLevel(w:GetFrameLevel() + 2)
 if s.softBg then s.softBg:Hide() end
 if s.title then s.title:Hide() end
 if s.close then s.close:Hide() end
 if s.sideBg then s.sideBg:Hide() end
 for _, b in ipairs(s.tabButtons or {}) do b:Hide() end
 if s.pageTitle then s.pageTitle:ClearAllPoints(); s.pageTitle:SetPoint('TOPLEFT', s, 'TOPLEFT', 60, -6) end
 if s.searchBox then s.searchBox:ClearAllPoints(); s.searchBox:SetPoint('TOPRIGHT', s, 'TOPRIGHT', -16, -10) end
 if s.headLine then s.headLine:ClearAllPoints(); s.headLine:SetPoint('TOPLEFT', s, 'TOPLEFT', 60, -44); s.headLine:SetPoint('TOPRIGHT', s, 'TOPRIGHT', -16, -44) end
 for _, page in pairs(s.pages or {}) do
  local box = page.holder or page
  box:ClearAllPoints(); box:SetPoint('TOPLEFT', s, 'TOPLEFT', 70, -54); box:SetPoint('BOTTOMRIGHT', s, 'BOTTOMRIGHT', page.holder and -34 or -16, 6)
 end
 s:SetMovable(false); s:SetScript('OnDragStart', nil); s:SetScript('OnDragStop', nil)
 s.ftQuestieAdopted = true
end

function FT.OpenQuestieOptions(tab)
 if not FT.settings and FT.CreateSettings then FT.CreateSettings() end
 local w = buildWindow()
 adopt(w)
 w:Show(); FT.settings:Show()
 selectTab(tab or FT.settings.current or 'q_genel')
 if FT.FixFonts then pcall(FT.FixFonts, w) end
end

----------------------------------------------------------------------
-- 2) Kasaba işaretleri (Questie'nin "Townsfolk" menüsü gibi)
----------------------------------------------------------------------
local TOWN = {
 {flag = 16384, icon = 'Interface\\Minimap\\Tracking\\Repair', name = 'Tamirci'},
 {flag = 128, icon = 'Interface\\Minimap\\Tracking\\Innkeeper', name = 'Han'},
 {flag = 8, icon = 'Interface\\Minimap\\Tracking\\FlightMaster', name = 'Uçuş ustası'},
 {flag = 256, icon = 'Interface\\Minimap\\Tracking\\Banker', name = 'Banka'},
 {flag = 4096, icon = 'Interface\\Minimap\\Tracking\\Auctioneer', name = 'Müzayede'},
 {flag = 8192, icon = 'Interface\\Minimap\\Tracking\\StableMaster', name = 'Ahır'},
}
local townDots = {}
FT.townDots = townDots
function FT.DrawTownsfolk(mapID)
 for _, d in ipairs(townDots) do d:Hide() end
 local overlay = FT.mapParts and FT.mapParts.overlay
 if not (overlay and mapID and on('townsfolk') and FT.MapServices) then return end
 local w, h = overlay:GetWidth(), overlay:GetHeight()
 local used = 0
 local _, token = UnitClass('player')
 local classTrainer = token and (token:sub(1, 1) .. token:sub(2):lower() .. ' Trainer')
 local function add(icon, x, y, title, sub)
  if used >= 80 then return end
  used = used + 1
  local d = townDots[used]
  if not d then d = overlay:CreateTexture(nil, 'OVERLAY'); townDots[used] = d end
  local sc = 14 * (FT.Scale and FT.Scale('mapIcons') or 1)
  d:SetSize(sc, sc); d:SetTexture(icon)
  d:ClearAllPoints(); d:SetPoint('CENTER', overlay, 'TOPLEFT', x * w, -y * h)
  d.step = {x = x, y = y, uiMapID = mapID, questTitle = title, text = sub or '', type = 'location'}
  d:Show()
 end
 for _, e in ipairs(FT.MapServices(mapID)) do
  local hit
  for _, t in ipairs(TOWN) do if type(e.flags) == 'number' and math.floor(e.flags / t.flag) % 2 == 1 then hit = t; break end end
  if hit then add(hit.icon, e.x, e.y, e.name, hit.name .. (e.sub and (' — ' .. e.sub) or ''))
  elseif e.sub == classTrainer then add('Interface\\Minimap\\Tracking\\Class', e.x, e.y, e.name, e.sub)
  elseif e.sub and e.sub:find('Trainer', 1, true) and on('townprof') then add('Interface\\Minimap\\Tracking\\Profession', e.x, e.y, e.name, e.sub) end
 end
 if FT.MailboxesOn then
  for _, m in ipairs(FT.MailboxesOn(mapID)) do add('Interface\\Minimap\\Tracking\\Mailbox', m.x, m.y, m.name or 'Posta kutusu', 'Posta') end
 end
end

----------------------------------------------------------------------
-- 3) Yetenek penceresinin yanında plan paneli
----------------------------------------------------------------------
local tp
local function ensureTalentPanel()
 if tp then return tp end
 tp = FT.NewWindow('ForeverTrailTalentPanel', UIParent)
 tp:SetSize(250, 420); tp:SetFrameStrata('HIGH')
 local t = tp:CreateFontString(nil, 'OVERLAY'); font(t, 14, 'OUTLINE'); t:SetPoint('TOP', 0, -10); t:SetText('Yetenek planı')
 if FT.StyleTitle then FT.StyleTitle(t) end
 tp.specs = {}
 for i = 1, 3 do
  local b = FT.NewButton(tp, '', 74, 20); b:SetPoint('TOPLEFT', 10 + (i - 1) * 77, -32)
  b:SetScript('OnClick', function(self) if self.key and FT.SetTalentBuild then FT.SetTalentBuild(self.key); FT.RefreshTalentPanel() end end)
  tp.specs[i] = b
 end
 tp.desc = tp:CreateFontString(nil, 'OVERLAY'); font(tp.desc, 10, ''); tp.desc:SetPoint('TOPLEFT', 12, -58); tp.desc:SetWidth(226); tp.desc:SetJustifyH('LEFT')
 tp.desc:SetTextColor(0.8, 0.77, 0.7)
 tp.icon = tp:CreateTexture(nil, 'ARTWORK'); tp.icon:SetSize(32, 32); tp.icon:SetPoint('TOPLEFT', 12, -92); tp.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
 tp.next = tp:CreateFontString(nil, 'OVERLAY'); font(tp.next, 12, ''); tp.next:SetPoint('TOPLEFT', 50, -92); tp.next:SetWidth(190); tp.next:SetJustifyH('LEFT')
 tp.learn = FT.NewButton(tp, 'Öğren', 110, 22); tp.learn:SetPoint('TOPLEFT', 12, -130)
 tp.learn:SetScript('OnClick', function() if FT.LearnNextTalent then FT.LearnNextTalent() end end)
 local all = FT.NewButton(tp, 'Tüm plan', 110, 22); all:SetPoint('TOPLEFT', 128, -130)
 all:SetScript('OnClick', function() if FT.OpenHub then FT.OpenHub('sinif') end end)
 tp.rows = {}
 for i = 1, 12 do
  local r = tp:CreateFontString(nil, 'OVERLAY'); font(r, 11, ''); r:SetPoint('TOPLEFT', 14, -162 - (i - 1) * 18); r:SetWidth(224); r:SetJustifyH('LEFT')
  tp.rows[i] = r
 end
 tp.warn = tp:CreateFontString(nil, 'OVERLAY'); font(tp.warn, 10, ''); tp.warn:SetPoint('BOTTOMLEFT', 12, 10); tp.warn:SetWidth(226); tp.warn:SetJustifyH('LEFT')
 tp.warn:SetTextColor(1, 0.55, 0.35)
 tp:Hide()
 return tp
end

function FT.RefreshTalentPanel()
 if not (tp and tp:IsShown()) then return end
 local builds = FT.TalentBuildsForClass and FT.TalentBuildsForClass() or {}
 local cur = FT.CurrentBuild and FT.CurrentBuild()
 for i, b in ipairs(tp.specs) do
  local d = builds[i]
  if d then
   b.key = d.key; b:SetText((d.recommended and '★' or '') .. (d.name:match('%((.-)%)') or d.name)); b:Show()
   if cur and cur.key == d.key then b:Disable() else b:Enable() end
  else b:Hide() end
 end
 tp.desc:SetText(cur and cur.desc or '')
 local steps, err = FT.TalentPlan and FT.TalentPlan()
 local s, idx = FT.NextTalent and FT.NextTalent()
 local pts = FT.Compat.UnspentPoints()
 if s then
  tp.icon:SetTexture(s.talent.icon); tp.icon:Show()
  tp.next:SetText(('Sıradaki (sv %d):\n|cff55ff55%s %d/%d|r\n|cff9aa0a6%s · puan: %d|r'):format(s.level, s.talent.name, s.rank, s.talent.max, FT.TalentTabName and FT.TalentTabName(s.talent.tab) or '', pts or 0))
 elseif steps then tp.icon:Hide(); tp.next:SetText('|cff55ff55Plan tamamlandı.|r')
 else tp.icon:Hide(); tp.next:SetText(FT.TalentPlanMessage(err)) end
 if not FT.TalentTreeReadable() then
  tp.learn:SetText('OneForAll'); if FT.TalentPlannerAvailable() then tp.learn:Enable() else tp.learn:Disable() end
 else
  tp.learn:SetText('Öğren'); if s and (pts or 0) > 0 then tp.learn:Enable() else tp.learn:Disable() end
 end
 for i, r in ipairs(tp.rows) do
  local st = steps and idx and steps[idx + i - 1]
  if st then
   r:SetText(('%s%d|r  %s %d/%d'):format(i == 1 and '|cff55ff55' or '|cff9aa0a6', st.level, st.talent.name, st.rank, st.talent.max))
  else r:SetText('') end
 end
 local off = FT.TalentDeviation and FT.TalentDeviation() or {}
 tp.warn:SetText(#off > 0 and ('Plan dışı: ' .. table.concat(off, ', ')) or '')
end

local function showTalentPanel()
 if not on('talentpanel') then return end
 local frame = FT.Compat.TalentFrame()
 local p = ensureTalentPanel()
 p:ClearAllPoints()
 if frame and frame:IsShown() then p:SetPoint('TOPLEFT', frame, 'TOPRIGHT', 4, -12) else p:SetPoint('LEFT', UIParent, 'LEFT', 40, 40) end
 p:Show()
 FT.RefreshTalentPanel()
 if FT.FixFonts then pcall(FT.FixFonts, p) end
end
FT.ShowTalentPanel = showTalentPanel

local function hideTalentPanel() if tp then tp:Hide() end end

local hooked = {}
local function hookTalentFrame()
 for _, name in ipairs({'TalentFrame', 'PlayerTalentFrame', 'PlayerSpellsFrame', 'ClassTalentFrame'}) do
  local f = _G[name]
  if f and not hooked[f] then
   hooked[f] = true
   f:HookScript('OnShow', function() if C_Timer then C_Timer.After(0.05, showTalentPanel) else showTalentPanel() end end)
   f:HookScript('OnHide', hideTalentPanel)
   if f:IsShown() then showTalentPanel() end
  end
 end
end

local ev = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_LOGIN', 'ADDON_LOADED', 'CHARACTER_POINTS_CHANGED', 'PLAYER_LEVEL_UP'}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript('OnEvent', function(_, event)
 local ok, err = pcall(function()
  if event == 'PLAYER_LOGIN' or event == 'ADDON_LOADED' then
   hookTalentFrame()
   if event == 'PLAYER_LOGIN' and ToggleTalentFrame and hooksecurefunc then
    hooksecurefunc('ToggleTalentFrame', function() hookTalentFrame() end)
   end
  else
   pcall(FT.RefreshTalentPanel)
  end
 end)
 if not ok and FT.errors and #FT.errors < 20 then FT.errors[#FT.errors + 1] = 'questieui: ' .. tostring(err) end
end)
