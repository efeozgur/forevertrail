local _, FT = ...
local kinds = {al='accept', hedef='objective', teslim='turnin', elle='manual', konum='location'}

function FT.ExportGuide(rec)
 local id = ((rec.title or 'custom'):lower():gsub('[^%w]+', '-'))
 if id == '' or id == '-' then id = 'custom' end
 local out = {'local _, FT = ...', 'FT.RegisterGuide({',
  (' guideId=%q, version=1, title=%q, zone=%q,'):format(id, rec.title or 'Özel rehber', rec.zone or 'Özel'),
  ' steps={'}
 for _, s in ipairs(rec.steps or {}) do
  local parts = {('stepId=%q'):format(s.stepId), ('type=%q'):format(s.type)}
  if s.uiMapID and s.x and s.y then
   parts[#parts+1] = ('uiMapID=%d'):format(s.uiMapID)
   parts[#parts+1] = ('x=%.3f'):format(s.x)
   parts[#parts+1] = ('y=%.3f'):format(s.y)
  end
  if s.questId then parts[#parts+1] = ('questId=%d'):format(s.questId) end
  parts[#parts+1] = ('text=%q'):format(s.text)
  out[#out+1] = '  {' .. table.concat(parts, ',') .. '},'
 end
 out[#out+1] = ' }'
 out[#out+1] = '})'
 return table.concat(out, '\n')
end

local win
local function showExport(text)
 if not win then
  win = FT.NewWindow and FT.NewWindow('ForeverTrailExport', UIParent) or CreateFrame('Frame', 'ForeverTrailExport', UIParent, 'BasicFrameTemplateWithInset')
  win:SetSize(520, 380); win:SetPoint('CENTER'); win:SetFrameStrata('DIALOG')
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag('LeftButton')
  win:SetScript('OnDragStart', function(self) self:StartMoving() end)
  win:SetScript('OnDragStop', function(self) self:StopMovingOrSizing() end)
  local scroll = CreateFrame('ScrollFrame', 'ForeverTrailExportScroll', win, 'UIPanelScrollFrameTemplate')
  scroll:SetPoint('TOPLEFT', 12, -30); scroll:SetPoint('BOTTOMRIGHT', -32, 12)
  local edit = CreateFrame('EditBox', nil, scroll)
  edit:SetMultiLine(true); edit:SetFontObject('ChatFontNormal'); edit:SetWidth(470); edit:SetAutoFocus(false)
  edit:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
  scroll:SetScrollChild(edit)
  win.edit = edit
 end
 win.edit:SetText(text)
 win:Show()
 win.edit:HighlightText()
 win.edit:SetFocus()
end

local function position()
 if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
 local ok, map = pcall(C_Map.GetBestMapForUnit, 'player')
 if not ok or not map then return end
 local good, pos = pcall(C_Map.GetPlayerMapPosition, map, 'player')
 if not good or not pos then return end
 local valid, x, y = pcall(function() return pos:GetXY() end)
 if valid and type(x) == 'number' and type(y) == 'number' and (x ~= 0 or y ~= 0) then return map, x, y end
end

function FT.Record(cmd, rest)
 rest = rest or ''
 local rec = ForeverTrailSettings.recording
 if cmd == 'kayit' then
  local sub, arg = rest:match('^(%S*)%s*(.-)$')
  sub = (sub or ''):lower()
  if sub == 'baslat' then
   ForeverTrailSettings.recording = {title = arg ~= '' and arg or 'Özel rehber', zone = GetZoneText and GetZoneText() or 'Özel', steps = {}}
   FT.Print('Kayıt başladı. Adım eklemek için: /ftrail adim [al|hedef|teslim|elle|konum] [görevNo] metin')
  elseif sub == 'sil' then
   ForeverTrailSettings.recording = nil
   FT.Print('Kayıt silindi.')
  elseif sub == 'yaz' then
   if not rec or #rec.steps == 0 then FT.Print('Yazılacak adım yok.') else showExport(FT.ExportGuide(rec)) end
  else
   FT.Print(rec and ('Kayıt: %s, %d adım. /ftrail kayit yaz ile dışa aktar.'):format(rec.title, #rec.steps) or 'Kayıt yok. /ftrail kayit baslat <başlık>')
  end
  return
 end
 if not rec then FT.Print('Önce /ftrail kayit baslat <başlık> yaz.'); return end
 local word, after = rest:match('^(%S*)%s*(.-)$')
 local kind = kinds[(word or ''):lower()]
 if kind then rest = after else kind = 'location' end
 local questId
 if kind == 'accept' or kind == 'objective' or kind == 'turnin' then
  local number, remainder = rest:match('^(%d+)%s*(.-)$')
  if not number then FT.Print('Görev numarası gerekli: /ftrail adim al 747 metin'); return end
  questId, rest = tonumber(number), remainder
 end
 if rest == '' then FT.Print('Adım metni boş.'); return end
 local step = {stepId = 'step-' .. (#rec.steps + 1), type = kind, text = rest, questId = questId}
 local map, x, y = position()
 if map then step.uiMapID, step.x, step.y = map, x, y end
 rec.steps[#rec.steps + 1] = step
 FT.Print(('Adım %d eklendi%s.'):format(#rec.steps, map and (' (%.1f, %.1f)'):format(x * 100, y * 100) or ' (konum alınamadı)'))
end
