local _, FT = ...

-- "Alınabilir" listesi (görev penceresinin ikinci sekmesi): "Görevlerim" ile aynı tasarım dili.
-- Veriyi (bulunduğun bölgedeki alınabilir görevler, sıralama, süzme) Available.lua toplar; burası yalnızca çizer.
-- Her görev tek ve bitişik bir bloktur: solda zorluk renginde seviye rozeti, büyük nötr görev adı, altında veren ve XP.

local PAD, WIDTH = 16, 360
local CW = WIDTH - PAD * 2
local state, blocks = {}, {}

local SORT_TEXT = {yakin = 'en yakından başlayarak', seviye = 'seviyeye göre', ad = 'ada göre'}
local KIND_CHIP = {['repeat'] = 'Tekrar', event = 'Etkinlik', pvp = 'PvP', dungeon = 'Zindan', raid = 'Baskın'}

-- Eski "Alınabilir" kutusunun çizimi (görev penceresi kurulmadan önce çizilmiş olabilir): her şeyi gizle
local function hideLegacy(box)
 for _, part in ipairs(box.legacyParts or {}) do part:Hide() end
 for _, pool in ipairs(box.legacyRows or {}) do
  for _, row in ipairs(pool) do row:Hide() end
 end
 if box.colHdr then box.colHdr:Hide() end
end

local function setup(box)
 if state.ready then return true end
 local K = FT.Kit
 if not K then return false end
 state.title = K.Text(box, 15, 'text'); state.title:SetPoint('TOPLEFT', PAD, -14); state.title:SetJustifyH('LEFT')
 state.title:SetText('Alınabilir görevler')
 state.count = K.Text(box, 13, 'accent'); state.count:SetPoint('TOPRIGHT', -PAD, -16); state.count:SetJustifyH('RIGHT')
 state.sub = K.Text(box, 11, 'muted'); state.sub:SetPoint('TOPLEFT', PAD, -38); state.sub:SetWidth(CW); state.sub:SetJustifyH('LEFT'); state.sub:SetWordWrap(false)
 state.rule = K.Divider(box)
 state.scroll = K.Scroll(box)
 state.scroll:SetWidth(CW)
 state.content = CreateFrame('Frame', nil, state.scroll)
 state.content:SetSize(CW, 10)
 state.scroll:SetScrollChild(state.content)
 state.empty = K.Text(state.content, 12, 'muted'); state.empty:SetJustifyH('LEFT')
 state.more = K.Text(state.content, 11, 'muted'); state.more:SetJustifyH('LEFT')
 state.ready = true
 return true
end

local function newBlock(i)
 local K = FT.Kit
 local b = CreateFrame('Button', nil, state.content)
 b:SetSize(CW, 40)
 b.hl = b:CreateTexture(nil, 'BACKGROUND'); b.hl:SetAllPoints(); K.Fill(b.hl, 'card', 0.9); b.hl:Hide()
 b.sep = b:CreateTexture(nil, 'ARTWORK'); b.sep:SetHeight(1)
 b.sep:SetPoint('TOPLEFT', 0, 0); b.sep:SetPoint('TOPRIGHT', 0, 0); K.Fill(b.sep, 'line', 0.55)
 b.badge = K.LevelBadge(b); b.badge:SetSize(28, 18)
 b.title = K.Text(b, 14, 'text'); b.title:SetJustifyH('LEFT'); b.title:SetWordWrap(false)
 b.dist = K.Text(b, 11, 'muted'); b.dist:SetJustifyH('RIGHT')
 b.giver = K.Text(b, 12, 'muted'); b.giver:SetJustifyH('LEFT'); b.giver:SetWordWrap(false)
 b.xp = K.Text(b, 11, 'muted'); b.xp:SetJustifyH('RIGHT')
 b.chips = {K.Chip(b), K.Chip(b)}
 b:SetScript('OnClick', function(self)
  local m = self.mark
  if m and FT.SetCustomTarget then FT.SetCustomTarget(m.map, m.x, m.y, FT.QuestTitle and FT.QuestTitle(m.questId) or m.giver) end
 end)
 b:SetScript('OnEnter', function(self)
  self.hl:Show()
  local m = self.mark
  if not (m and FT.Kit) then return end
  local tip = FT.Kit.Tooltip()
  tip:SetOwner(self, 'ANCHOR_LEFT')
  if FT.QuestInfoTip then FT.QuestInfoTip(tip, m.questId, m, self.distValue) end
  tip:Show()
 end)
 b:SetScript('OnLeave', function(self) self.hl:Hide(); if FT.Kit then FT.Kit.HideTips() end end)
 blocks[i] = b
 return b
end

-- list: Available.lua'nın sıraladığı {m = işaret, d = uzaklık} girdileri; ctx: görünüm ayarları
function FT.RenderAvailList(box, list, map, ctx)
 if not setup(box) then return end
 local K = FT.Kit
 CW = (FT.QuestDockWidth and FT.QuestDockWidth() or WIDTH) - PAD * 2 -- pencere boyutlandırılabilir
 FT.availRenders = (FT.availRenders or 0) + 1
 hideLegacy(box)
 state.sub:SetWidth(CW)
 local density = ForeverTrailSettings.c_trackerDensity or 'normal'
 local pad = density == 'sikisik' and 6 or (density == 'ferah' and 14 or 10)
 local twoLines = ctx.view == 'kart' and ctx.showGiver
 local mapName = map and FT.MapName and FT.MapName(map) or ''
 state.count:SetText(tostring(#list))
 state.sub:SetText((mapName ~= '' and (mapName .. '  ·  ') or '') .. (SORT_TEXT[ctx.sortBy] or ''))
 local sumH = 62
 for _, b in ipairs(blocks) do b:Hide() end
 state.empty:Hide(); state.more:Hide()
 local y, shown = 6, 0
 for i = 1, math.min(ctx.maxRows, #list) do
  local e = list[i]
  local m = e.m
  local b = blocks[i] or newBlock(i)
  shown = shown + 1
  b.mark = m; b.distValue = e.d
  b:SetWidth(CW)
  b:ClearAllPoints(); b:SetPoint('TOPLEFT', state.content, 'TOPLEFT', 0, -y)
  b.sep:SetShown(i > 1)
  -- seviye rozeti (zorluk renginde) ve görev adı
  local lr, lg, lb = 1, 0.82, 0
  if FT.DiffColor and m.level and m.level > 0 then lr, lg, lb = FT.DiffColor(m.level) end
  b.badge:ClearAllPoints(); b.badge:SetPoint('TOPLEFT', 0, -(pad + 1)); b.badge:SetLevel(m.level, lr, lg, lb)
  local title = FT.QuestTitle and FT.QuestTitle(m.questId) or ('Görev ' .. m.questId)
  b.title:ClearAllPoints(); b.title:SetPoint('TOPLEFT', 38, -pad); b.title:SetText(title)
  -- sağ üst: etiketler ve uzaklık
  b.dist:ClearAllPoints(); b.dist:SetPoint('TOPRIGHT', -2, -(pad + 2))
  b.dist:SetText(e.d and e.d < 1e9 and ('%d m'):format(math.floor(e.d + 0.5)) or '')
  local chips = {}
  local kind = FT.QuestKind and FT.QuestKind(m.questId)
  if kind and KIND_CHIP[kind] then chips[#chips + 1] = {KIND_CHIP[kind], 1, 0.62, 0.32} end
  if FT.IsNewQuest and FT.IsNewQuest(m.questId) then chips[#chips + 1] = {'Yeni', 0.55, 0.8, 1} end
  local x = (b.dist:GetStringWidth() or 0) + 10
  for c, chip in ipairs(b.chips) do
   local def = chips[c]
   if def then
    chip:Set(def[1], def[2], def[3], def[4])
    chip:ClearAllPoints(); chip:SetPoint('TOPRIGHT', b, 'TOPRIGHT', -x - 2, -(pad + 1)); chip:Show()
    x = x + chip:GetWidth() + 6
   else chip:Hide() end
  end
  b.title:SetWidth(math.max(60, CW - 38 - x - 8))
  b:SetAlpha(m.low and 0.55 or 1)
  -- ikinci satır: görev veren ve XP
  local h = pad + 22
  local xp, estimated = FT.QuestXPInfo and FT.QuestXPInfo(m.questId)
  if twoLines then
   b.giver:ClearAllPoints(); b.giver:SetPoint('TOPLEFT', 38, -h); b.giver:SetWidth(CW - 38 - 90)
   b.giver:SetText(m.giver or ''); b.giver:Show()
   b.xp:ClearAllPoints(); b.xp:SetPoint('TOPRIGHT', -2, -h); b.xp:SetText(xp and (('%s%d XP'):format(estimated and '~' or '', xp)) or '')
   local a = K.Color('accent'); b.xp:SetTextColor(a[1], a[2], a[3]); b.xp:Show()
   h = h + 20
  else b.giver:Hide(); b.xp:Hide(); h = h - 4 end
  b:SetHeight(h + pad)
  b:Show()
  y = y + b:GetHeight()
 end
 if #list > shown then
  state.more:ClearAllPoints(); state.more:SetPoint('TOPLEFT', 0, -(y + 8))
  state.more:SetText(('+%d görev daha  (Ansiklopedi)'):format(#list - shown)); state.more:Show(); y = y + 30
 elseif #list == 0 then
  state.empty:ClearAllPoints(); state.empty:SetPoint('TOPLEFT', 0, -(y + 12))
  state.empty:SetText('Bu bölgede alınabilir görev yok.'); state.empty:Show(); y = y + 40
 end
 state.content:SetHeight(math.max(10, y)); state.content:SetWidth(CW)
 local screen = UIParent and UIParent:GetHeight() or 800
 local fixed = FT.QuestDockViewHeight and FT.QuestDockViewHeight(sumH)
 local viewH = fixed or math.min(y, math.max(160, math.floor(screen * 0.58) - sumH))
 state.scroll:ClearAllPoints(); state.scroll:SetPoint('TOPLEFT', box, 'TOPLEFT', PAD, -sumH)
 state.scroll:SetSize(CW, viewH)
 state.rule:ClearAllPoints(); state.rule:SetPoint('TOPLEFT', box, 'TOPLEFT', 0, -(sumH - 4)); state.rule:SetPoint('TOPRIGHT', box, 'TOPRIGHT', 0, -(sumH - 4))
 local range = math.max(0, y - viewH)
 if (state.scroll:GetVerticalScroll() or 0) > range then state.scroll:SetVerticalScroll(range) end
 box:SetHeight(sumH + viewH + 10)
end

-- Test ve tanı için: görünen görev bloğu sayısı
function FT.AvailListInfo()
 local n = 0
 for _, b in ipairs(blocks) do if b:IsShown() then n = n + 1 end end
 return n
end
