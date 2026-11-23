local _, FT = ...

-- Hızlı ayarlar: oynarken en sık değiştirilen birkaç ayar, küçük bir pencerede.
-- Ayarlar penceresindeki aynı tanımları kullanır (anahtar, uygulama işlevi); en altta "Tüm ayarlar" düğmesi vardır.

local win

-- Sırayla gösterilen ayarlar; label verilmezse ayar penceresindeki ad kullanılır.
local ROWS = {
 {key = 'arrow', label = 'Yön oku'},
 {key = 'tracker', label = 'Görev kutusu'},
 {key = 'availbox', label = 'Alınabilir görevler kutusu'},
 {key = 'autoquest', label = 'Görevleri otomatik al / teslim et'},
 {key = 'autosell', label = 'Satıcıda çöp eşyaları sat'},
 {key = 'autorepair', label = 'Satıcıda otomatik tamir'},
 {key = 'sound', label = 'Sesler'},
}
FT.QuickSettingRows = ROWS

local function findDef(key)
 for _, defs in pairs(FT.QuestiePageDefs or {}) do
  for _, d in ipairs(defs) do
   if d.type == 'check' and d.key == key then return d end
  end
 end
end

local function build()
 win = FT.NewWindow('ForeverTrailQuickSettings', UIParent)
 win:SetSize(300, 70 + #ROWS * 26)
 win:SetPoint('CENTER', UIParent, 'CENTER', 0, 60)
 win:SetFrameStrata('DIALOG')
 win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag('LeftButton')
 win:SetScript('OnDragStart', function(self) self:StartMoving() end)
 win:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
 local title = win:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 title:SetPoint('TOP', 0, -8); title:SetText('Hızlı ayarlar')
 if FT.StyleTitle then FT.StyleTitle(title) end
 win.title = title
 win.checks = {}
 for i, row in ipairs(ROWS) do
  local def = findDef(row.key)
  local check = (FT.Kit and FT.Kit.CheckBox(win) or CreateFrame('CheckButton', nil, win, 'UICheckButtonTemplate'))
  check:SetPoint('TOPLEFT', 14, -34 - (i - 1) * 26)
  local label = win:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  label:SetPoint('LEFT', check, 'RIGHT', 4, 0); label:SetWidth(240); label:SetJustifyH('LEFT')
  label:SetText(row.label or (def and def.label) or row.key)
  local c = FT.Kit and FT.Kit.Color('text') or {1, 0.94, 0.82}; label:SetTextColor(c[1], c[2], c[3])
  check.key = row.key
  check:SetScript('OnClick', function(self)
   local value = self:GetChecked() and true or false
   ForeverTrailSettings[row.key] = value
   if def and def.apply then pcall(def.apply, value) end
   if FT.SettingsAfterChange then FT.SettingsAfterChange() end
  end)
  win.checks[i] = check
 end
 local all = FT.NewButton(win, 'Tüm ayarlar...', 272, 24)
 all:SetPoint('BOTTOM', 0, 12)
 all:SetScript('OnClick', function() win:Hide(); if FT.ToggleSettings then FT.ToggleSettings() end end)
 win:SetScript('OnShow', function(self)
  for _, c in ipairs(self.checks) do c:SetChecked(FT.GetSetting and FT.GetSetting(c.key)) end
 end)
 if UISpecialFrames then tinsert(UISpecialFrames, 'ForeverTrailQuickSettings') end
 win:Hide()
end

function FT.ToggleQuickSettings()
 if not win then build() end
 if win:IsShown() then win:Hide() else win:Show() end
end
