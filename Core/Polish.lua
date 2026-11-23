local _, FT = ...

-- Tasarım cilası: görev eşyası düğmeleri, +1 efekti, görev tamamlandı afişi, minimap kenar okları,
-- yüzde halkası, satır sıklığı, can barı rengi, pencere geçişleri, sınıf rengi teması.

local function on(key) return not ForeverTrailSettings or ForeverTrailSettings[key] ~= false end
local function db() return FT.Module and FT.Module('QuestieDB') end
local function font(fs, size, flags)
 if fs:SetFont(FT.FontPath and FT.FontPath() or 'Fonts\\ARIALN.TTF', size, flags or '') == false then fs:SetFont('Fonts\\ARIALN.TTF', size, flags or '') end
 fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.9)
end
local BLOB = 'Interface\\CHARACTERFRAME\\TempPortraitAlphaMask'

----------------------------------------------------------------------
-- Küçük animasyon sürücüsü
----------------------------------------------------------------------
local anims = {}
local driver = CreateFrame('Frame')
driver:SetScript('OnUpdate', function(_, dt)
 for i = #anims, 1, -1 do
  local a = anims[i]
  a.t = a.t + dt
  local p = math.min(1, a.t / a.dur)
  local ok = pcall(a.step, p)
  if p >= 1 or not ok then table.remove(anims, i); if a.done then pcall(a.done) end end
 end
end)
function FT.Animate(dur, step, done)
 anims[#anims + 1] = {t = 0, dur = dur, step = step, done = done}
end

----------------------------------------------------------------------
-- Sınıf rengi teması
----------------------------------------------------------------------
do
 local _, class = UnitClass and UnitClass('player')
 local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
 if c and FT.Themes then
  FT.Themes.sinif = {name = 'Sınıf rengi', bg = {0.05, 0.05, 0.07, 0.95}, border = {c.r * 0.45, c.g * 0.45, c.b * 0.45, 1},
   band = {c.r * 0.30, c.g * 0.30, c.b * 0.30, 0.90}, accent = {c.r, c.g, c.b}}
  table.insert(FT.themeOrder, 'sinif')
 end
end

----------------------------------------------------------------------
-- Görev kutusu: satır sıklığı, yüzde halkası, +1 efekti, görev eşyası düğmesi
----------------------------------------------------------------------
function FT.TrackerSteps()
 local d = ForeverTrailSettings and ForeverTrailSettings.c_trackerDensity or 'normal'
 if d == 'sikisik' then return 16, 16, false end
 if d == 'ferah' then return 22, 27, true end
 return 19, 18, false
end

local RING = 12
function FT.QuestPercent(questId)
 local q = C_QuestLog
 if q.IsComplete and q.IsComplete(questId) then return 1 end
 local ok, list = pcall(q.GetQuestObjectives, questId)
 local have, need = 0, 0
 for _, o in ipairs(ok and type(list) == 'table' and list or {}) do
  if (o.numRequired or 0) > 0 then have = have + math.min(o.numFulfilled or 0, o.numRequired); need = need + o.numRequired
  elseif o.finished then have, need = have + 1, need + 1 else need = need + 1 end
 end
 return need > 0 and have / need or 0
end

local function ring(row)
 if row.ftRing then return row.ftRing end
 local f = CreateFrame('Frame', nil, row)
 f:SetSize(14, 14); f:SetPoint('RIGHT', row, 'LEFT', -3, 0)
 f.dots = {}
 for i = 1, RING do
  local t = f:CreateTexture(nil, 'ARTWORK'); t:SetTexture(BLOB); t:SetSize(3, 3)
  local ang = (i - 1) / RING * 2 * math.pi
  t:SetPoint('CENTER', f, 'CENTER', math.sin(ang) * 6, math.cos(ang) * 6)
  f.dots[i] = t
 end
 f.num = f:CreateFontString(nil, 'OVERLAY'); font(f.num, 9, 'OUTLINE'); f.num:SetPoint('CENTER', 0, 0)
 row.ftRing = f
 return f
end

function FT.DecorateQuestRow(row, questId, ready)
 local r = ring(row)
 if not on('trkring') or (FT.TrackerStyle and FT.TrackerStyle() == 'questie') then r:Hide(); return end
 local n = on('routenums') and FT.RouteNumber and FT.RouteNumber[questId]
 r.num:SetText(n and tostring(n) or '')
 local pct = ready and 1 or FT.QuestPercent(questId)
 local lit = math.floor(pct * RING + 0.5)
 local cr, cg, cb = 0.4, 1, 0.4
 if FT.ProgressColor then cr, cg, cb = FT.ProgressColor(pct * 100, 100, ready) end
 for i, t in ipairs(r.dots) do
  if i <= lit then t:SetVertexColor(cr, cg, cb, 1) else t:SetVertexColor(1, 1, 1, 0.18) end
 end
 r:Show()
end

-- +1 efekti: sayaç artınca parlama ve yukarı kayan yazı
local last = {}
local floats = {}
local function floatText(anchor, text, r, g, b)
 local fs
 for _, f in ipairs(floats) do if not f.busy then fs = f; break end end
 if not fs then fs = UIParent:CreateFontString(nil, 'OVERLAY'); font(fs, 14, 'OUTLINE'); floats[#floats + 1] = fs end
 fs.busy = true
 fs:SetParent(anchor:GetParent() or UIParent)
 fs:SetText(text); fs:SetTextColor(r, g, b)
 fs:ClearAllPoints(); fs:SetPoint('RIGHT', anchor, 'LEFT', -4, 0); fs:SetAlpha(1); fs:Show()
 FT.Animate(1.1, function(p)
  fs:ClearAllPoints(); fs:SetPoint('RIGHT', anchor, 'LEFT', -4, p * 18); fs:SetAlpha(1 - p * p)
 end, function() fs:Hide(); fs.busy = false end)
end

function FT.ObjectiveProgress(o, questId, index, have, need)
 local key = questId .. ':' .. index
 local before = last[key]
 last[key] = have
 if not (before and have and have > before and on('trkfx')) then return end
 local r, g, b = FT.ProgressColor and FT.ProgressColor(have, need, need and need > 0 and have >= need)
 floatText(o.count, '+' .. (have - before), r or 0.4, g or 1, b or 0.4)
 FT.Animate(0.6, function(p)
  local s = 1 + 0.5 * math.sin(p * math.pi)
  o.count:SetTextColor(1, 1, 1 - p)
  pcall(o.count.SetTextHeight, o.count, 13 * s)
 end, function() pcall(o.count.SetTextHeight, o.count, 13); if r then o.count:SetTextColor(r, g, b) end end)
end

-- Görev eşyası düğmesi: kullanılabilir görev eşyası çantadaysa satırın solunda
local itemButtons = {}
local function questItem(questId)
 local d = db()
 if not d or not GetItemCount then return nil end
 local ids = {}
 local src = d.QueryQuestSingle(questId, 'sourceItemId')
 if src and src > 0 then ids[#ids + 1] = src end
 local obj = d.QueryQuestSingle(questId, 'objectives')
 for _, it in ipairs(type(obj) == 'table' and obj[3] or {}) do if type(it) == 'table' and it[1] then ids[#ids + 1] = it[1] end end
 for _, id in ipairs(ids) do
  if GetItemCount(id) > 0 and (not GetItemSpell or GetItemSpell(id)) then return id end
 end
end

function FT.TrackerItemButton(index, row, questId, place)
 if InCombatLockdown and InCombatLockdown() then return end
 local b = itemButtons[index]
 local id = on('trkitems') and questId and questItem(questId)
 if not id then if b then b:Hide() end return end
 if not b then
  b = CreateFrame('Button', 'ForeverTrailTrackerItem' .. index, UIParent, 'SecureActionButtonTemplate')
  b:SetSize(20, 20)
  b:RegisterForClicks('AnyUp', 'AnyDown')
  b.icon = b:CreateTexture(nil, 'ARTWORK'); b.icon:SetAllPoints(); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square', 'ADD')
  b:SetScript('OnEnter', function(self) GameTooltip:SetOwner(self, 'ANCHOR_LEFT'); pcall(GameTooltip.SetItemByID, GameTooltip, self.itemId); GameTooltip:Show() end)
  b:SetScript('OnLeave', function() GameTooltip:Hide() end)
  itemButtons[index] = b
 end
 b.itemId = id
 b:SetAttribute('type', 'item')
 b:SetAttribute('item', 'item:' .. id)
 b.icon:SetTexture((GetItemIcon and GetItemIcon(id)) or 'Interface\\Icons\\INV_Misc_QuestionMark')
 b:SetFrameStrata('HIGH')
 if place then place(b) else b:ClearAllPoints(); b:SetPoint('RIGHT', row, 'LEFT', -20, 0) end
 b:Show()
end

function FT.HideTrackerItems(from)
 if InCombatLockdown and InCombatLockdown() then return end
 for i = from, #itemButtons do itemButtons[i]:Hide() end
end

----------------------------------------------------------------------
-- Görev tamamlandı afişi
----------------------------------------------------------------------
local banner
local function showBanner(questId)
 if not on('donebanner') or (FT.IsSilent and FT.IsSilent()) then return end
 if not banner then
  banner = CreateFrame('Frame', 'ForeverTrailDoneBanner', UIParent)
  banner:SetSize(420, 64); banner:SetPoint('TOP', UIParent, 'TOP', 0, -170); banner:SetFrameStrata('HIGH')
  banner.bg = banner:CreateTexture(nil, 'BACKGROUND'); banner.bg:SetAllPoints(); banner.bg:SetColorTexture(1, 1, 1, 1)
  if FT.PaintBand then FT.PaintBand(banner.bg, {0, 0, 0, 0.7}) end
  banner.line = banner:CreateTexture(nil, 'ARTWORK'); banner.line:SetHeight(2)
  banner.line:SetPoint('BOTTOMLEFT'); banner.line:SetPoint('BOTTOMRIGHT')
  banner.title = banner:CreateFontString(nil, 'OVERLAY'); font(banner.title, 20, 'OUTLINE'); banner.title:SetPoint('TOP', 0, -8)
  banner.sub = banner:CreateFontString(nil, 'OVERLAY'); font(banner.sub, 13, ''); banner.sub:SetPoint('TOP', banner.title, 'BOTTOM', 0, -4)
 end
 local a = FT.Style.accent
 banner.line:SetColorTexture(a[1], a[2], a[3], 1)
 banner.title:SetText('Görev tamamlandı'); banner.title:SetTextColor(0.45, 1, 0.45)
 local ender = FT.TurnInName and FT.TurnInName(questId)
 banner.sub:SetText((FT.QuestTitle and FT.QuestTitle(questId) or '') .. (ender and ('  —  Teslim: ' .. ender) or ''))
 banner.sub:SetTextColor(1, 0.94, 0.82)
 banner:SetAlpha(0); banner:Show()
 FT.Animate(3.2, function(p)
  local alpha = p < 0.12 and p / 0.12 or (p > 0.75 and (1 - p) / 0.25 or 1)
  banner:SetAlpha(alpha)
  banner:SetPoint('TOP', UIParent, 'TOP', 0, -170 + (p < 0.12 and (1 - p / 0.12) * 12 or 0))
 end, function() banner:Hide() end)
end
FT.ShowDoneBanner = showBanner

local wasDone = {}
local function scanDone(initial)
 local q = C_QuestLog
 if not (q and q.GetNumQuestLogEntries and q.GetInfo and q.IsComplete) then return end
 for i = 1, q.GetNumQuestLogEntries() do
  local info = q.GetInfo(i)
  local id = info and not info.isHeader and info.questID
  if id and id > 0 then
   local done = q.IsComplete(id) and true or false
   if done and wasDone[id] == false and not initial then showBanner(id) end
   wasDone[id] = done
  end
 end
end

----------------------------------------------------------------------
-- Minimap kenar okları: minimapin dışında kalan görev hedefleri
----------------------------------------------------------------------
local edge = {}
local OUTDOOR = {[0] = 233.33, 200, 166.67, 133.33, 100, 66.67}
local INDOOR = {[0] = 150, 125, 100, 75, 50, 37.5}
local function updateEdges()
 for _, e in ipairs(edge) do e:Hide() end
 if not (on('mmedge') and Minimap and Minimap:IsVisible() and C_Map and FT.ObjectiveAreas) then return end
 local map = C_Map.GetBestMapForUnit('player')
 local pos = map and C_Map.GetPlayerMapPosition(map, 'player')
 if not pos then return end
 local px, py = pos:GetXY()
 local ok, ww, wh = pcall(C_Map.GetMapWorldSize, map)
 if not ok or not ww or ww <= 0 then return end
 local radius = FT.MinimapRadius and FT.MinimapRadius() or ((IsIndoors and IsIndoors()) and INDOOR or OUTDOOR)[Minimap:GetZoom() or 0] or 150
 local rotate = GetCVar and GetCVar('rotateMinimap') == '1'
 local facing = GetPlayerFacing and GetPlayerFacing()
 local half = Minimap:GetWidth() / 2
 local used = 0
 local okA, areas = pcall(FT.ObjectiveAreas, map)
 for _, a in ipairs(okA and areas or {}) do
  if used >= 8 then break end
  if not (FT.focusQuest and FT.focusQuest ~= a.o.questId) then
   local best, bd
   for _, g in ipairs(a.groups or {}) do
    local dx, dy = (g.x - px) * ww, (g.y - py) * wh
    local dd = dx * dx + dy * dy
    if not bd or dd < bd then best, bd = {dx, dy}, dd end
   end
   if best and bd > radius * radius then
    local nx, ny = FT.MinimapOffset(best[1], best[2], facing, rotate, radius)
    local len = math.sqrt(nx * nx + ny * ny)
    if len > 0 then
     used = used + 1
     local e = edge[used]
     if not e then
      e = CreateFrame('Frame', nil, Minimap); e:SetSize(14, 14)
      e:SetFrameStrata('MEDIUM'); e:SetFrameLevel(Minimap:GetFrameLevel() + 7)
      e.t = e:CreateTexture(nil, 'OVERLAY'); e.t:SetAllPoints(); e.t:SetTexture('Interface\\Minimap\\MinimapArrow')
      edge[used] = e
     end
     local c = a.o.color or {1, 0.82, 0}
     e.t:SetVertexColor(c[1], c[2], c[3])
     if e.t.SetRotation then e.t:SetRotation(math.atan2(-nx, ny)) end
     local r = half - 7
     e:ClearAllPoints(); e:SetPoint('CENTER', Minimap, 'CENTER', nx / len * r, ny / len * r)
     e:Show()
    end
   end
  end
 end
end

----------------------------------------------------------------------
-- İsim plakası: görev yaratığının can barı görev renginde
----------------------------------------------------------------------
function FT.TintPlate(plate, o)
 local uf = plate and plate.UnitFrame
 local bar = uf and (uf.healthBar or uf.HealthBar)
 if not (bar and bar.SetStatusBarColor) then return end
 if o and on('platecolor') then
  local c = o.color or {1, 0.82, 0.3}
  bar:SetStatusBarColor(c[1], c[2], c[3]); plate.ftTinted = true
 elseif plate.ftTinted then
  plate.ftTinted = nil
  if CompactUnitFrame_UpdateHealthColor then pcall(CompactUnitFrame_UpdateHealthColor, uf) end
 end
end

----------------------------------------------------------------------
-- Pencere geçişleri: açılırken yumuşak belirme ve hafif kayma
----------------------------------------------------------------------
local hooked = {}
function FT.AddShowAnim(frame)
 if not frame or hooked[frame] then return end
 hooked[frame] = true
 frame:HookScript('OnShow', function(self)
  if not on('anims') then return end
  self:SetAlpha(0)
  FT.Animate(0.18, function(p) self:SetAlpha(p) end)
 end)
end

----------------------------------------------------------------------
-- Olaylar
----------------------------------------------------------------------
local ev = CreateFrame('Frame')
for _, e in ipairs({'PLAYER_LOGIN', 'QUEST_LOG_UPDATE', 'QUEST_ACCEPTED', 'PLAYER_REGEN_ENABLED'}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript('OnEvent', function(_, event)
 if event == 'PLAYER_LOGIN' then
  scanDone(true)
  for _, f in ipairs({FT.hub, FT.settings, FT.availableBox, FT.tracker}) do FT.AddShowAnim(f) end
 elseif event == 'PLAYER_REGEN_ENABLED' then
  if FT.RefreshTracker then pcall(FT.RefreshTracker) end
 else
  scanDone(event == 'QUEST_ACCEPTED')
 end
end)
local acc = 0
ev:SetScript('OnUpdate', function(_, dt)
 acc = acc + dt
 if acc < 1 then return end
 acc = 0
 local ok, err = pcall(updateEdges)
 if not ok and FT.errors and #FT.errors < 20 then FT.errors[#FT.errors + 1] = 'polish: ' .. tostring(err) end
end)
