local _, FT = ...
FT.guides = {}
function FT.RegisterGuide(guide) FT.guides[#FT.guides + 1] = guide end
function FT.Print(message) print('|cff61d7b0ForeverTrail:|r ' .. tostring(message)) end
local frame = CreateFrame('Frame')
FT.eventFrame = frame
frame:RegisterEvent('ADDON_LOADED')
frame:RegisterEvent('PLAYER_LOGIN')
frame:RegisterEvent('QUEST_LOG_UPDATE')
frame:RegisterEvent('QUEST_ACCEPTED')
frame:RegisterEvent('QUEST_TURNED_IN')
frame:RegisterEvent('ZONE_CHANGED_NEW_AREA')
frame:RegisterEvent('ZONE_CHANGED')
frame:SetScript('OnEvent', function(_, event, a, b)
 if event == 'ADDON_LOADED' and a == 'ForeverTrail' then
  ForeverTrailSettings = ForeverTrailSettings or {auto = true}
  if ForeverTrailSettings.auto == nil then ForeverTrailSettings.auto = true end
  ForeverTrailCharacter = ForeverTrailCharacter or {}
  FT.Initialize()
 elseif event == 'PLAYER_LOGIN' then FT.ready = true; if FT.InstallMapClick then FT.InstallMapClick() end; FT.Evaluate()
 elseif FT.ready then
  if event == 'QUEST_ACCEPTED' then
   local id = type(b)=='number' and b>0 and b or a
   if type(id)=='number' and id>0 then ForeverTrailCharacter.lastAcceptedQuest=id; FT.turnedIn[id]=nil end
  end
  if event == 'QUEST_TURNED_IN' and type(a) == 'number' then FT.turnedIn[a] = true; if FT.RecordTurnIn then FT.RecordTurnIn(a, b) end end
  if event == 'QUEST_LOG_UPDATE' or event == 'ZONE_CHANGED' or event == 'ZONE_CHANGED_NEW_AREA' then
   FT.pending = FT.pending or 0.3
  else
   FT.pending = nil
   FT.Evaluate()
  end
 end
end)
SLASH_FOREVERTRAIL1 = '/ftrail'
BINDING_HEADER_FOREVERTRAIL = 'ForeverTrail'
BINDING_NAME_FOREVERTRAIL_TOGGLE = 'Paneli aç/kapat'
BINDING_NAME_FOREVERTRAIL_NEAREST = 'En yakın hedefi seç'
BINDING_NAME_FOREVERTRAIL_ROUTE = 'Otomatik rota oluştur'
BINDING_NAME_FOREVERTRAIL_ARROW = 'Yön okunu aç/kapat'
BINDING_NAME_FOREVERTRAIL_OPTIONS = 'Ayarlar'
SlashCmdList.FOREVERTRAIL = function(raw)
 raw = raw or ''
 local msg = raw:lower():match('^%s*(.-)%s*$')
 local cmd, rest = raw:match('^%s*(%S*)%s*(.-)%s*$')
 cmd = (cmd or ''):lower()
 if msg == 'resetui' then FT.ResetPosition()
 elseif msg == 'debug' then FT.Debug()
 elseif msg == 'arrow' then FT.ToggleArrow()
 elseif msg == 'card' then FT.ToggleCard()
 elseif msg == 'track' then FT.ToggleTracker()
 elseif msg == 'yakin' then FT.SelectNearest()
 elseif msg == 'rota' then FT.BuildRoute()
 elseif msg == 'ayar' then FT.ToggleSettings()
 elseif cmd == 'adim' or cmd == 'kayit' then FT.Record(cmd, rest)
 elseif msg == 'gecmis' then FT.PrintHistory()
 elseif msg == 'ceviri' then FT.PrintMissingTranslations()
 elseif msg == 'canli' then FT.LiveStatus()
 elseif msg == 'yetenekdebug' then FT.TalentDebug()
 elseif msg == 'test' then FT.SelfTest()
 elseif msg == 'hata' then FT.PrintErrors()
 elseif msg == 'gorev' or msg == 'yardimci' then FT.ShowQuestHelper()
 elseif msg == 'yardim' or msg == 'help' then FT.Help()
 elseif msg == 'kucuk' then FT.SetCompact(not ForeverTrailSettings.compact)
 elseif msg == 'iptal' then FT.ClearCustomTarget()
 elseif cmd == 'git' then
  local sx, sy = rest:match('^([%d%.]+)[%s,;]+([%d%.]+)$')
  local px, py = tonumber(sx), tonumber(sy)
  local ok, map = false, nil
  if C_Map and C_Map.GetBestMapForUnit then ok, map = pcall(C_Map.GetBestMapForUnit, 'player') end
  if px and py and px <= 100 and py <= 100 and ok and map then FT.SetCustomTarget(map, px / 100, py / 100)
  else FT.Print('Kullanım: /ftrail git 45.2 60.1 (bulunduğun haritada) veya haritada Ctrl + sol tık.') end
 elseif msg == 'kilit' then
  if FT.ToggleLock then FT.ToggleLock() end
 elseif msg == 'cubuk' then FT.ToggleDock()
 elseif msg == 'paylas' then FT.ShareStep()
 elseif msg == 'yetenek' then if FT.TalentTreeReadable and not FT.TalentTreeReadable() and FT.TalentPlannerAvailable() then FT.OpenTalentPlanner() else FT.ShowTalentAdvice() end
 elseif msg == 'kayitpencere' then FT.ToggleRecorder()
 elseif msg == 'ansiklopedi' then FT.OpenHub('ansiklopedi')
 elseif msg == 'planla' then FT.ShowRoutePlan()
 elseif msg == 'surekli' then FT.ToggleAutoRoute()
 elseif msg == 'profil' then FT.ToggleProfiles()
 elseif msg == 'gecmisim' then FT.ShowJourney()
 elseif msg == 'zindan' then FT.ShowDungeonGuide()
 elseif msg == 'ekipman' then FT.ShowGearFinder()
 elseif msg == 'silah' then FT.ShowWeaponMasters()
 elseif msg == 'sonraki' then FT.SuggestNext()
 elseif msg == 'kurulum' then FT.ShowSetupWizard()
 elseif msg == 'yerlesim' then FT.ToggleEditMode()
 elseif msg == 'sessiz' then FT.ToggleSilent()
 elseif msg == 'yedek' then FT.ShowBackups()
 elseif msg == 'oturum' then FT.ShowSessionCard()
 elseif msg == 'sinif' or msg == 'yetenek' then FT.OpenHub('sinif')
 elseif msg == 'veri' then FT.ToggleDataWindow()
 elseif msg == 'ozet' then FT.ShowSummary()
 elseif msg == 'meslek' then FT.ShowProfessionGuide()
 elseif msg == 'yerler' then FT.TogglePlaces()
 elseif cmd == 'kaydet' then FT.AddPlaceHere(rest ~= '' and rest or 'Kayıtlı yer', 'Kayıtlı')
 elseif msg == 'ara' then FT.ClearVia()
 elseif msg == 'geri' then FT.UndoVia()
 elseif msg == 'duzen' then FT.SortBags()
 elseif msg == 'banka' then FT.SortBank()
 elseif msg == 'sat' then FT.SellJunk(true)
 elseif msg == 'gorevesya' then FT.ToggleQuestItems()
 elseif msg == 'plaka' then FT.PlateDebug()
 elseif msg == 'esya' then FT.ScanUpgrades()
 elseif msg == 'plan' then FT.Plan()
 elseif msg == 'aktar' then FT.ToggleTransfer()
 elseif msg == 'font' then FT.CycleFont()
 elseif msg == 'seviye' then FT.Print(FT.LevelSummary())
 elseif FT.ToggleHub then FT.ToggleHub('rehber')
 elseif FT.panel then if FT.panel:IsShown() then FT.panel:Hide() else FT.panel:Show() end end
end
function FT.Debug()
 local version, build, date, interface = GetBuildInfo()
 local step = FT.CurrentStep()
 FT.Print(('client=%s build=%s date=%s interface=%s guide=%s step=%s status=%s mapError=%s journalError=%s'):format(tostring(version),tostring(build),tostring(date),tostring(interface),tostring(FT.guide and FT.guide.guideId),tostring(step and step.stepId),tostring(FT.lastStatus),tostring(FT.mapError),tostring(FT.journalError)))
 if FT.MapDebug then FT.Print(FT.MapDebug()) end
end
