local _, FT = ...

-- Görevler sayfası: günlüktekiler, alınabilecekler, bulunduğun bölge ve zincir önerileri.
-- Hub'ın "Görevler" sayfasında durur (FT.suggestions); sekmeli, kaydırılabilir, iki satırlı liste.

local PAD, ROW_H, MAX_ROWS = 6, 46, 200
local TABS = {{'journal', 'Günlüktekiler'}, {'available', 'Alınabilecekler'}, {'nearby', 'Bulunduğum bölge'}, {'chain', 'Zincir'}}
local HINT = {
 journal = 'Günlüğündeki görevler, XP değeri yüksek olan başta. Seçince haritada açılır.',
 available = 'Seviyene uygun, alabileceğin görevler. Seçince haritada açılır.',
 nearby = 'Bulunduğun bölgede alınabilecek ya da yapılabilecek görevler.',
 chain = 'Görev zinciri: önceki ve sonraki görevler.',
}
local EMPTY = {
 journal = 'Uygun günlük görevi yok.',
 available = 'Alınabilecek uygun görev yok.',
 nearby = 'Bu bölgede bilinen uygun görev yok.',
 chain = 'Zincir bilgisi yok.',
}
local GREEN, AMBER = {0.6, 0.92, 0.55}, {0.98, 0.8, 0.4}

local win, seg, scroll, content, hint, count, empty
local pool = {}
local rows, activeTab, chainState = {}, 'journal', 'ok'
local elapsed = 0

local function openRow(row)
 if not row then return end
 if row.active then
  for guideIndex, guide in ipairs(FT.validGuides) do
   if guide.live then
    FT.SelectGuide(guideIndex)
    for j, step in ipairs(guide.steps) do
     if step.questId == row.id then FT.active = j; FT.view = j; FT.SaveStep(); break end
    end
    break
   end
  end
 else
  FT.guide = {guideId = 'recommendation', title = row.title, zone = 'Önerilen görev', version = 1,
   steps = {{stepId = 'recommendation-' .. row.id, type = 'accept', questId = row.id, questTitle = row.title, text = 'Görevi al.'}}}
  FT.active = 1; FT.view = 1; FT.complete = false; FT.notice = nil
 end
 FT.Refresh(); if FT.OpenMap then FT.OpenMap() end
end

local function newRow(i)
 local K = FT.Kit
 local b = CreateFrame('Button', nil, content)
 b:SetHeight(ROW_H)
 b.hl = b:CreateTexture(nil, 'BACKGROUND'); b.hl:SetAllPoints(); K.Fill(b.hl, 'card', 0.9); b.hl:Hide()
 b.sep = b:CreateTexture(nil, 'ARTWORK'); b.sep:SetHeight(1); b.sep:SetPoint('TOPLEFT', 0, 0); b.sep:SetPoint('TOPRIGHT', 0, 0); K.Fill(b.sep, 'line', 0.55)
 b.dot = b:CreateTexture(nil, 'ARTWORK'); b.dot:SetSize(3, 24); b.dot:SetPoint('LEFT', 2, 0)
 b.title = K.Text(b, 13, 'text'); b.title:SetPoint('TOPLEFT', 14, -8); b.title:SetPoint('RIGHT', b, 'RIGHT', -130, 0); b.title:SetJustifyH('LEFT'); b.title:SetWordWrap(false)
 b.sub = K.Text(b, 11, 'muted'); b.sub:SetPoint('TOPLEFT', 14, -27); b.sub:SetPoint('RIGHT', b, 'RIGHT', -130, 0); b.sub:SetJustifyH('LEFT'); b.sub:SetWordWrap(false)
 b.state = K.Text(b, 12, 'muted'); b.state:SetPoint('RIGHT', -10, 0); b.state:SetJustifyH('RIGHT')
 b:SetScript('OnEnter', function(self)
  self.hl:Show()
  if self.row and FT.QuestInfoTip and self.row.id then
   local tip = FT.Kit.Tooltip()
   if tip then tip:SetOwner(self, 'ANCHOR_RIGHT'); pcall(FT.QuestInfoTip, tip, self.row.id, {level = self.row.level}, nil); tip:Show() end
  end
 end)
 b:SetScript('OnLeave', function(self) self.hl:Hide(); FT.Kit.HideTips() end)
 b:SetScript('OnClick', function(self) openRow(self.row) end)
 pool[i] = b
 return b
end

local function draw(keepScroll)
 local offset = keepScroll and scroll.GetVerticalScroll and scroll:GetVerticalScroll() or 0
 local shown = math.min(#rows, MAX_ROWS)
 for i = 1, shown do
  local row = rows[i]
  local b = pool[i] or newRow(i)
  b:ClearAllPoints(); b:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, -(i - 1) * ROW_H); b:SetPoint('RIGHT', content, 'RIGHT', 0, 0)
  b.sep:SetShown(i > 1)
  local level = type(row.level) == 'number' and row.level > 0 and tostring(row.level) or '?'
  b.title:SetText(('[%s] %s'):format(level, row.title or '?'))
  local color, label, sub
  if row.status then
   -- zincir: durum ve bölge
   label = row.status
   sub = (row.zone or '') .. (row.current and ((row.zone and '  ·  ' or '') .. 'şu anki görev') or '')
   color = row.current and AMBER or nil
  else
   sub = row.xp and (row.xp .. ' XP') or 'XP bilinmiyor'
   if row.zone then sub = sub .. '  ·  ' .. row.zone end
   if row.ready then color, label = GREEN, 'Teslim'
   elseif row.active then color, label = AMBER, 'Günlükte'
   else label = 'Alınabilir' end
  end
  local K = FT.Kit
  local dot = color or K.Color('line')
  b.dot:SetColorTexture(dot[1], dot[2], dot[3], 1)
  b.state:SetText(label or '')
  if color then b.state:SetTextColor(color[1], color[2], color[3]) else local m = K.Color('muted'); b.state:SetTextColor(m[1], m[2], m[3]) end
  b.sub:SetText(sub)
  b.row = row; b:Show()
 end
 for i = shown + 1, #pool do pool[i].row = nil; pool[i]:Hide() end
 content:SetHeight(math.max(1, shown * ROW_H))
 count:SetText(#rows > 0 and ('%d görev'):format(#rows) or '')
 if #rows == 0 then
  local msg = EMPTY[activeTab]
  if activeTab == 'chain' then
   if chainState == 'noquest' then msg = 'Zincir için önce bir görev al.' elseif chainState == 'unavailable' then msg = 'Görev verisi okunamıyor; zincir gösterilemiyor.' end
  end
  empty:SetText(msg); empty:Show()
 else empty:Hide() end
 if scroll.SetVerticalScroll then scroll:SetVerticalScroll(offset) end
end

local function reload(keepScroll)
 local all = FT.GetRecommendations and FT.GetRecommendations() or {}
 rows = {}
 if activeTab == 'nearby' then
  rows = FT.GetNearbyRecommendations and FT.GetNearbyRecommendations(all) or {}
 elseif activeTab == 'chain' then
  if FT.GetQuestChain then
   local list, state = FT.GetQuestChain()
   chainState = state
   for _, r in ipairs(list) do rows[#rows + 1] = {id = r.id, title = r.title, level = r.level, active = r.active, ready = false, status = r.chainStatus, current = r.chainCurrent, zone = r.zone} end
   if FT.SetChainPreview then FT.SetChainPreview(rows) end
  else chainState = 'unavailable' end
 else
  for _, row in ipairs(all) do
   if (row.active and activeTab == 'journal') or (not row.active and activeTab == 'available') then rows[#rows + 1] = row end
  end
 end
 hint:SetText(HINT[activeTab] or '')
 draw(keepScroll)
end

local function selectTab(tab)
 activeTab = tab
 seg:SetValue(tab)
 reload(false)
 if tab == 'chain' then if FT.ShowChainOnMap then FT.ShowChainOnMap() end elseif FT.ClearChainPreview then FT.ClearChainPreview() end
end

function FT.BuildSuggestions(parent)
 if win then return win end
 local K = FT.Kit
 local PW = K.CONTENT_W
 win = FT.NewWindow(nil, parent or UIParent)
 FT.suggestions = win
 win:SetSize(PW, 620); win:SetPoint('TOPLEFT', parent or UIParent, 'TOPRIGHT', 4, 0)
 win:SetFrameLevel(((parent and parent:GetFrameLevel()) or 1) + 10)
 seg = K.Segmented(win, TABS, PW - PAD * 2, 28, selectTab)
 seg:SetPoint('TOPLEFT', PAD, -PAD)
 hint = K.Text(win, 12, 'muted'); hint:SetPoint('TOPLEFT', PAD + 2, -44); hint:SetJustifyH('LEFT')
 count = K.Text(win, 11, 'muted'); count:SetPoint('TOPRIGHT', -PAD - 2, -45); count:SetJustifyH('RIGHT')
 scroll = K.Scroll(win)
 scroll:SetPoint('TOPLEFT', PAD, -66); scroll:SetPoint('BOTTOMRIGHT', -PAD - 8, PAD)
 content = CreateFrame('Frame', nil, scroll)
 content:SetSize(PW - PAD * 2 - 8, 10)
 scroll:SetScrollChild(content)
 empty = K.Text(win, 12, 'muted'); empty:SetPoint('TOPLEFT', PAD + 8, -80); empty:SetWidth(PW - 40); empty:SetJustifyH('LEFT'); empty:SetJustifyV('TOP')
 seg:SetValue(activeTab)
 -- açıkken 3 saniyede bir yenilenir; kaydırma konumu korunur
 win:SetScript('OnUpdate', function(_, dt)
  elapsed = elapsed + dt
  if elapsed >= 3 then elapsed = 0; reload(true) end
 end)
 win:Hide()
 FT.ShowSuggestions = function() elapsed = 0; selectTab(activeTab); win:Show() end
 if FT.ApplyFont then pcall(FT.ApplyFont) end
 return win
end

-- Test ve tanı için
function FT.SuggestionRows()
 local out = {}
 for _, b in ipairs(pool) do if b:IsShown() then out[#out + 1] = b end end
 return out
end
function FT.SuggestionTab(tab) selectTab(tab) end
