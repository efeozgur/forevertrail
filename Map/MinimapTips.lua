-- Küçük haritadaki ForeverTrail simgelerinin üzerine gelince ne olduğunu anlatan ipucu
local _, FT = ...

local KIND = {kill = 'Öldür', loot = 'Topla', object = 'Kullan / etkileşim', event = 'Olay', talk = 'Konuş'}

local function questTitle(id, fallback)
 return (FT.QuestTitle and FT.QuestTitle(id)) or fallback or ('Görev ' .. tostring(id))
end

local function header(tip, text, r, g, b, first)
 if first then tip:SetText(text, r, g, b) else tip:AddLine(' '); tip:AddLine(text, r, g, b) end
end

local function describe(tip, info, first)
 if info.kind == 'giver' then
  local m = info.mark
  local lvl = m.level
  local r, g, b = 1, 0.82, 0
  if FT.DiffColor then r, g, b = FT.DiffColor(lvl) end
  local t = (lvl and ('[' .. lvl .. '] ') or '') .. questTitle(m.questId)
  if m.kind == '?' then
   header(tip, '? Teslim: ' .. t, r, g, b, first)
   tip:AddLine('Görevin bitti, buradaki NPC\'ye teslim et.', 0.55, 1, 0.55, true)
  else
   header(tip, '! Görev: ' .. t, r, g, b, first)
   tip:AddLine(m.low and 'Seviyenin altında (gri görev, az XP).' or 'Buradan alabileceğin bir görev var.', 0.85, 0.85, 0.85, true)
  end
  if m.giver then tip:AddLine('NPC: ' .. m.giver, 1, 1, 1) end
 elseif info.kind == 'objective' then
  local o = info.o or {}
  header(tip, (KIND[o.kind] or 'Hedef') .. ': ' .. (FT.ParseObjective and FT.ParseObjective(o.text or '') or (o.text or '')), 1, 0.82, 0, first)
  tip:AddLine(questTitle(o.questId, o.title), 0.8, 0.8, 0.8)
  if o.need and o.need > 0 then
   local done = (o.have or 0) >= o.need
   tip:AddLine(('İlerleme: %d / %d'):format(o.have or 0, o.need), done and 0.3 or 1, done and 1 or 1, done and 0.3 or 1)
  end
  if o.kind == 'kill' then tip:AddLine('Bu bölgedeki yaratıkları öldür.', 0.7, 0.7, 0.7, true)
  elseif o.kind == 'loot' then tip:AddLine('Bu bölgedeki yaratıklardan veya yerden eşyayı topla.', 0.7, 0.7, 0.7, true)
  elseif o.kind == 'object' then tip:AddLine('Buradaki nesneye tıkla (sandık, bitki, kutu...).', 0.7, 0.7, 0.7, true) end
 elseif info.kind == 'rare' then
  local r = info.rare
  header(tip, 'Nadir yaratık: ' .. (r.name or '?'), 1, 0.5, 0.1, first)
  if r.level then tip:AddLine('Seviye ' .. r.level, 1, 1, 1) end
  tip:AddLine('İyi eşya düşürebilir. Tek başına zorsa grup bul.', 0.7, 0.7, 0.7, true)
 elseif info.kind == 'target' then
  local s = FT.customTarget or (FT.CurrentStep and FT.guide and FT.CurrentStep())
  header(tip, 'ForeverTrail hedefi', 1, 0.82, 0, first)
  if type(s) == 'table' then
   if s.questTitle or s.questId then tip:AddLine(questTitle(s.questId, s.questTitle), 1, 1, 1) end
   if s.text then tip:AddLine(s.text, 0.85, 0.85, 0.85, true) end
  end
  tip:AddLine('Ok seni buraya götürüyor.', 0.7, 0.7, 0.7, true)
 end
end

local function hovered()
 local cx, cy = GetCursorPosition()
 local scale = Minimap:GetEffectiveScale()
 cx, cy = cx / scale, cy / scale
 local found = {}
 local function test(pin)
  if pin and pin.ftInfo and pin:IsShown() and (pin:GetAlpha() or 0) > 0.15 then
   local x, y = pin:GetCenter()
   if x then
    local w = math.max(8, (pin:GetWidth() or 12) * 0.6)
    if math.abs(cx - x) <= w and math.abs(cy - y) <= w then found[#found + 1] = pin.ftInfo end
   end
  end
 end
 test(FT.minimapPin)
 for pin in pairs(FT.MinimapPins or {}) do test(pin) end
 return found
end

local owned, last, elapsed = false, '', 0
local function sig(list)
 local t = {}
 for i, f in ipairs(list) do t[i] = tostring(f.mark or f.o or f.rare or f.kind) end
 return table.concat(t, ',')
end

local function update()
 if ForeverTrailSettings and ForeverTrailSettings.mmtips == false then return end
 if not (Minimap and Minimap:IsVisible() and Minimap:IsMouseOver()) then
  if owned then owned = false; last = ''; if GameTooltip:GetOwner() == Minimap then GameTooltip:Hide() end end
  return
 end
 local list = hovered()
 if #list == 0 then
  if owned then owned = false; last = ''; if GameTooltip:GetOwner() == Minimap then GameTooltip:Hide() end end
  return
 end
 local s = sig(list)
 if owned and s == last and GameTooltip:IsShown() then return end
 last, owned = s, true
 GameTooltip:SetOwner(Minimap, 'ANCHOR_CURSOR')
 local seen = {}
 local n = 0
 for _, info in ipairs(list) do
  local key = tostring(info.mark and info.mark.questId or info.o and (tostring(info.o.questId) .. (info.o.text or '')) or info.rare and info.rare.id or info.kind)
  if not seen[key] then
   seen[key] = true
   n = n + 1
   if n > 4 then GameTooltip:AddLine('+ daha fazla', 0.6, 0.6, 0.6); break end
   describe(GameTooltip, info, n == 1)
  end
 end
 if FT.ShowTip then FT.ShowTip(GameTooltip) else GameTooltip:Show() end
end
FT.MinimapTipUpdate = update

if CreateFrame and Minimap then
 local f = CreateFrame('Frame')
 f:SetScript('OnUpdate', function(_, dt)
  elapsed = elapsed + dt
  if elapsed < 0.08 then return end
  elapsed = 0
  pcall(update)
 end)
end
