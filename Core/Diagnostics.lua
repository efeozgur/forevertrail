local _, FT = ...
FT.errors = {}
local seen = {}

-- Hatayı yakalar, bir kez kaydeder; eklenti çalışmaya devam eder.
function FT.Guard(fn, label)
 return function(...)
  local ok, err = pcall(fn, ...)
  if not ok then
   local message = label .. ': ' .. tostring(err)
   if not seen[message] then
    seen[message] = true
    FT.errors[#FT.errors + 1] = message
    if #FT.errors > 20 then table.remove(FT.errors, 1) end
    if FT.Print then FT.Print('Hata kaydedildi (/ftrail hata): ' .. message) end
   end
  end
 end
end

function FT.GuardFrame(frame, script, label)
 if not (frame and frame.GetScript and frame.SetScript) then return end
 local fn = frame:GetScript(script)
 if fn then frame:SetScript(script, FT.Guard(fn, label)) end
end

function FT.GuardFrames()
 FT.GuardFrame(FT.eventFrame, 'OnEvent', 'olay')
 FT.GuardFrame(FT.eventFrame, 'OnUpdate', 'zamanlayıcı')
 FT.GuardFrame(FT.card, 'OnUpdate', 'kart')
 FT.GuardFrame(FT.arrowDriver, 'OnUpdate', 'ok')
 FT.GuardFrame(FT.minimapDriver, 'OnUpdate', 'mini harita')
end

if SlashCmdList and SlashCmdList.FOREVERTRAIL then
 SlashCmdList.FOREVERTRAIL = FT.Guard(SlashCmdList.FOREVERTRAIL, 'komut')
end

function FT.PrintErrors()
 if #FT.errors == 0 then return FT.Print('Kayıtlı hata yok.') end
 for index, message in ipairs(FT.errors) do FT.Print(index .. ') ' .. message) end
end

function FT.Help()
 local lines = {
  '/ftrail  panel   |  /ftrail ayar  ayarlar   |  /ftrail hizli  hızlı ayarlar   |  /ftrail kucuk  küçük mod',
  '/ftrail yakin  en yakın adım   |  /ftrail rota  otomatik rota',
  '/ftrail git 45.2 60.1  özel hedef   |  /ftrail iptal  özel hedefi kaldır (haritada Ctrl + sol tık da olur)',
  '/ftrail arrow  yön oku   |  /ftrail card  hedef kartı   |  /ftrail track  takip penceresi',
  '/ftrail kayit baslat <başlık>, /ftrail adim ..., /ftrail kayit yaz  rehber yazma',
  'Komut gerekmez: ekrandaki düğme çubuğu ve minimap düğmesi (sağ tık: çubuk) her şeyi açar. /ftrail cubuk  çubuğu aç/kapat',
  '/ftrail duzen  çantayı sırala  |  /ftrail banka  bankayı sırala  |  /ftrail sat  çöpleri sat  |  /ftrail esya  daha iyi eşya ara',
  'Haritada yol çiz: Alt + sol tık nokta ekle (noktaya tekrar Alt+tık: sil), Ctrl + sol tık son hedef  |  /ftrail geri  son noktayı geri al  |  /ftrail ara  yolu temizle',
  '/ftrail yerler  gidilecek yeri seç  |  /ftrail kaydet <ad>  bulunduğun yeri kaydet  (satıcı, banka, uçuş ustası, han vb. konumları otomatik öğrenilir)',
  '/ftrail kilit  yön okunu kilitle/aç (ok: sol tık harita, sağ tık en yakın adım)',
  '/ftrail plan  XP/saat planı   |  /ftrail aktar  ayarları dışa/içe aktar   |  /ftrail font  yazı tipini değiştir',
  '/ftrail seviye, gecmis, ceviri  bilgi   |  /ftrail test  uyumluluk testi   |  /ftrail hata  hata kaydı',
 }
 for _, line in ipairs(lines) do FT.Print(line) end
end

local function module(name)
 if FT.Module then local own = FT.Module(name) if own then return own end end
 if not (QuestieLoader and QuestieLoader.ImportModule) then return nil end
 local ok, result = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
 if ok then return result end
end

-- Oyun içi uyumluluk testi: eklentinin dayandığı arayüzlerin varlığını denetler.
function FT.SelfTest()
 local db = module('QuestieDB')
 local probeOK = pcall(CreateFrame, 'PlayerModel', nil, UIParent)
 local probeFrame = CreateFrame('Frame', nil, UIParent, BackdropTemplateMixin and 'BackdropTemplate' or nil)
 local checks = {
  {'Gömülü görev veritabanı', FT.DBQ ~= nil, true},
  {'Görev sorgu katmanı', db ~= nil, true},
  {'QuestieDB.QueryQuestSingle', db and db.QueryQuestSingle ~= nil, true},
  {'QuestieDB.QueryNPCSingle', db and db.QueryNPCSingle ~= nil, true},
  {'ZoneDB', module('ZoneDB') ~= nil, true},
  {'QuestXP', module('QuestXP') ~= nil, false},
  {'AvailableQuests', module('AvailableQuests') ~= nil, false},
  {'QuestieMap', module('QuestieMap') ~= nil, false},
  {'C_QuestLog.GetQuestObjectives', C_QuestLog and C_QuestLog.GetQuestObjectives ~= nil, true},
  {'C_QuestLog.GetNextWaypoint', C_QuestLog and C_QuestLog.GetNextWaypoint ~= nil, false},
  {'C_Map.GetBestMapForUnit', C_Map and C_Map.GetBestMapForUnit ~= nil, true},
  {'C_Map.GetPlayerMapPosition', C_Map and C_Map.GetPlayerMapPosition ~= nil, true},
  {'C_Map.GetMapWorldSize', C_Map and C_Map.GetMapWorldSize ~= nil, true},
  {'C_Map.GetMapInfo', C_Map and C_Map.GetMapInfo ~= nil, false},
  {'Dünya haritası tıklama (ScrollContainer)', WorldMapFrame and WorldMapFrame.ScrollContainer ~= nil, false},
  {'GetPlayerFacing (ok ve mini harita)', GetPlayerFacing ~= nil, false},
  {'PlayerModel (3B model)', probeOK, false},
  {'Çerçeve kenarlığı (Backdrop)', probeFrame.SetBackdrop ~= nil, false},
  {'WoWTR yazı tipi', WOWTR_Font2 ~= nil, false},
  {'WoWTR görev çevirileri', type(QTR_QuestData) == 'table', false},
 }
 FT.Print('Uyumluluk testi:')
 local missingRequired = 0
 for _, check in ipairs(checks) do
  local present = check[2] and true or false
  if not present and check[3] then missingRequired = missingRequired + 1 end
  local tag = present and '|cff55ff55[VAR]|r ' or (check[3] and '|cffff5555[YOK]|r ' or '|cffffd060[YOK, isteğe bağlı]|r ')
  FT.Print(tag .. check[1])
 end
 FT.Print(missingRequired == 0 and 'Gerekli her şey var.' or (missingRequired .. ' gerekli parça eksik; ilgili özellikler çalışmayabilir.'))
 if FT.TalentPlan then
  local ok, steps, err = pcall(FT.TalentPlan)
  local b = FT.CurrentBuild and FT.CurrentBuild()
  if ok and not steps and err == FT.TALENT_EXTERNAL then
   local have = FT.TalentPlannerAvailable()
   FT.Print((have and '|cff55ff55[VAR]|r' or '|cffffd060[YOK, isteğe bağlı]|r') .. ' Yetenek planı: bu istemcide OneForAll > Yetenek Ağaçları ile (' .. (have and 'OneForAll kurulu' or 'OneForAll kurulu değil') .. ')')
  elseif ok and steps then FT.Print(('|cff55ff55[VAR]|r Yetenek planı: %s, %d adım (N ile yetenek penceresi, yanında plan paneli; /ftrail yetenek)'):format(b and b.name or '?', #steps))
  else FT.Print('|cffff5555[YOK]|r Yetenek planı oyundaki ağaçla uyuşmadı: ' .. tostring(ok and err or steps) .. ' — bu satırı bana gönder.') end
 end
end

-- Blizzard ForeverTrail'in bir eylemini engellerse hangi fonksiyon olduğunu yaz ve kaydet
do
 local blocked = CreateFrame('Frame')
 pcall(blocked.RegisterEvent, blocked, 'ADDON_ACTION_FORBIDDEN')
 pcall(blocked.RegisterEvent, blocked, 'ADDON_ACTION_BLOCKED')
 blocked:SetScript('OnEvent', function(_, event, addon, fn)
  if addon ~= 'ForeverTrail' then return end
  local message = ('%s engellendi: %s'):format(event == 'ADDON_ACTION_FORBIDDEN' and 'Eylem' or 'Savaşta eylem', tostring(fn))
  if not seen[message] then
   seen[message] = true
   FT.errors[#FT.errors + 1] = message
   if #FT.errors > 20 then table.remove(FT.errors, 1) end
   if FT.Print then FT.Print('|cffff7070' .. message .. '|r (bunu bana bildir: /ftrail hata)') end
  end
 end)
end

-- /ftrail yetenekdebug: yetenek API'lerinin bu istemcide ne döndürdüğünü yazar (plan eşleşmezse bu çıktı gerekir)
function FT.TalentDebug()
 local function show(v)
  if type(v) == 'table' then
   local parts = {}
   for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. '=' .. tostring(x); if #parts >= 8 then break end end
   return '{' .. table.concat(parts, ',') .. '}'
  end
  return tostring(v)
 end
 local function call(label, fn, ...)
  if type(fn) ~= 'function' then FT.Print(label .. ': yok'); return end
  local r = {pcall(fn, ...)}
  for i = 1, #r do r[i] = show(r[i]) end
  FT.Print(label .. ': ' .. table.concat(r, ' | '))
 end
 local _, token = UnitClass and UnitClass('player')
 FT.Print('yetenek tanısı: sınıf=' .. tostring(token) .. ' seviye=' .. tostring(UnitLevel and UnitLevel('player')))
 call('GetNumTalentTabs', GetNumTalentTabs)
 for tab = 1, 3 do
  call('GetNumTalents(' .. tab .. ')', GetNumTalents, tab)
  call('GetTalentTabInfo(' .. tab .. ')', GetTalentTabInfo, tab)
  call('GetTalentInfo(' .. tab .. ',1)', GetTalentInfo, tab, 1)
 end
 local SI = C_SpecializationInfo
 FT.Print('C_SpecializationInfo=' .. tostring(SI ~= nil) .. ' C_ClassTalents=' .. tostring(C_ClassTalents ~= nil) .. ' C_Traits=' .. tostring(C_Traits ~= nil)
  .. ' Blizzard_TalentUI=' .. tostring(C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('Blizzard_TalentUI')))
 if SI then
  call('SI.GetNumSpecializations', SI.GetNumSpecializations)
  call('SI.GetNumTalents(1)', SI.GetNumTalents, 1)
  call('SI.GetTalentInfo(1,1)', SI.GetTalentInfo, {specializationIndex = 1, talentIndex = 1})
 end
 call('UnitCharacterPoints', UnitCharacterPoints, 'player')
 call('GetUnspentTalentPoints', GetUnspentTalentPoints)
 if FT.Compat then FT.Print(('Compat: sekme=%s yetenek1=%s yetenek2=%s yetenek3=%s'):format(tostring(FT.Compat.NumTalentTabs()), tostring(FT.Compat.NumTalents(1)), tostring(FT.Compat.NumTalents(2)), tostring(FT.Compat.NumTalents(3)))) end
end
