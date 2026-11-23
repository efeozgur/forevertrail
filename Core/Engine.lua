local _, FT = ...
local types={accept=true,objective=true,turnin=true,location=true,manual=true}
function FT.ValidateGuide(g)
 if type(g)~='table' or type(g.guideId)~='string' or type(g.version)~='number' or type(g.title)~='string' or type(g.zone)~='string' or type(g.steps)~='table' or #g.steps==0 then return false,'invalid guide metadata' end
 local seen={}
 for i,s in ipairs(g.steps) do
  if type(s)~='table' then return false,tostring(i)..': invalid step' end
  local id=tostring(s.stepId or i)
  if type(s.stepId)~='string' or s.stepId=='' or seen[s.stepId] then return false,id..': duplicate or missing stepId' end
  seen[s.stepId]=true
  if not types[s.type] or type(s.text)~='string' then return false,id..': invalid type or text' end
  if (s.x~=nil or s.y~=nil) and (type(s.x)~='number' or type(s.y)~='number' or s.x<0 or s.x>1 or s.y<0 or s.y>1 or type(s.uiMapID)~='number') then return false,id..': invalid coordinates' end
 end
 return true
end
function FT.IsStepDone(step,state)
 if step.type=='manual' or step.type=='location' then return false end
 if state.status=='turned_in' then return true end
 if step.type=='accept' then return state.status=='active' or state.status=='ready' end
 if step.type=='objective' then
  if step.objectiveIndex then return state.objective and state.objective.finished == true or false end
  return state.status=='ready'
 end
 return false
end
function FT.CurrentStep() return FT.guide and FT.guide.steps[FT.active] end
function FT.SaveStep() if not FT.guide or not FT.CurrentStep() then return end; if FT.guide.live and FT.CurrentStep().questId then ForeverTrailCharacter.journalStep=FT.CurrentStep().stepId end; ForeverTrailCharacter.guideId=FT.guide.guideId; ForeverTrailCharacter.stepId=FT.CurrentStep().stepId; ForeverTrailCharacter.complete=FT.complete or nil end
function FT.SelectGuide(index)
 FT.guide=FT.validGuides[index]; if not FT.guide then return end
 if ForeverTrailCharacter.guideId ~= FT.guide.guideId then ForeverTrailCharacter.reviewHold = nil end
 FT.active=1; FT.view=1; FT.complete=false; FT.notice=nil
 if not FT.guide.live and ForeverTrailCharacter.guideId==FT.guide.guideId then
  local found=false
  for i,s in ipairs(FT.guide.steps) do if s.stepId==ForeverTrailCharacter.stepId then FT.active=i; FT.view=i; found=true; break end end
  if not found and ForeverTrailCharacter.stepId then FT.notice='Kayıtlı adım kaldırılmış. Rehber ilk adımdan başlatıldı.' end
  if found then FT.complete=ForeverTrailCharacter.complete == true end
 end
 FT.SaveStep(); FT.Evaluate()
end
function FT.Advance()
 if FT.complete then return end
 ForeverTrailCharacter.reviewHold = nil
 FT.notice = nil
 local follows=FT.view==FT.active
 if FT.active>=#FT.guide.steps then FT.complete=true else FT.active=FT.active+1 end
 if follows then FT.view=FT.active end
 FT.SaveStep()
end
function FT.ResumeViewed()
 if FT.view == FT.active and not FT.complete then
  FT.notice = 'Bu adım zaten etkin.'
  FT.Refresh()
  return
 end
 FT.active = FT.view
 FT.complete = false
 FT.SaveStep()
 local step = FT.CurrentStep()
 local done = FT.IsStepDone(step, FT.QuestState(step.questId, step.objectiveIndex))
 if step.type == 'location' then done = FT.AtLocation(step) end
 ForeverTrailCharacter.reviewHold = done and step.stepId or nil
 FT.notice = done and 'Bu adım tamamlanmış. Devam etmek için Sonraki’ye bas.' or 'Bu adımdan devam ediliyor.'
 FT.Evaluate()
end
function FT.Evaluate()
 if not FT.guide then return end
 if FT.guide.live then
  if FT.ready then FT.UpdateJournal() end
 elseif ForeverTrailSettings.auto and FT.ready then
  while not FT.complete and ForeverTrailCharacter.reviewHold ~= FT.CurrentStep().stepId do
   local s=FT.CurrentStep(); local state=FT.QuestState(s.questId,s.objectiveIndex)
   local done=FT.IsStepDone(s,state)
   if s.type=='location' then done=FT.AtLocation(s) end
   if not done then break end
   FT.Advance()
  end
 end
 local s=FT.CurrentStep(); if not s then return end
 FT.lastStatus=FT.QuestState(s.questId,s.objectiveIndex).status
 FT.Refresh()
end
function FT.Initialize()
 FT.validGuides={}
 for _,g in ipairs(FT.guides) do local ok,err=FT.ValidateGuide(g); if ok then FT.validGuides[#FT.validGuides+1]=g else FT.Print(tostring(g.guideId)..' / '..err) end end
 FT.CreatePanel()
 if FT.CreateArrow then FT.CreateArrow() end
 if FT.CreateTargetCard then FT.CreateTargetCard() end
 if FT.CreateTracker then FT.CreateTracker() end
 if FT.CreateMinimapPin then FT.CreateMinimapPin() end
 if FT.RestoreCustomTarget then FT.RestoreCustomTarget() end
 if FT.InstallMapClick then FT.InstallMapClick() end
 if FT.CreateSettings then FT.CreateSettings() end
 -- Questie görünümüne geçiş: eski görünüm seçimlerini bir kez sıfırla (simge stili, görev kutusu, ayar penceresi, tema)
 if (ForeverTrailSettings.designVersion or 0) < 3 then
  for _, k in ipairs({'c_iconStyle', 'c_trackerStyle', 'c_optionsStyle', 'c_trackerSort', 'c_objColor', 'c_trackerBg', 'c_trackerDensity'}) do ForeverTrailSettings[k] = nil end
  ForeverTrailSettings.designVersion = 3
 end
 -- Sabit görünüme geçiş (v0.2): eski temalardan biri kayıtlıysa ya da hiç seçilmediyse yeni varsayılan şema
 if ForeverTrailSettings.themeVersion ~= 3 then
  local t = ForeverTrailSettings.theme
  if not t or (FT.legacyThemes and FT.legacyThemes[t]) then ForeverTrailSettings.theme = FT.defaultTheme end
  ForeverTrailSettings.themeVersion = 3
 end
 if FT.ApplyTheme then FT.ApplyTheme(ForeverTrailSettings.theme) end
 if FT.card and FT.card.close then FT.card.close:HookScript('OnClick', function() ForeverTrailSettings.card = false end) end
 if FT.CreateDock then FT.CreateDock() end
 if FT.ApplyUIScale then FT.ApplyUIScale() end
 if ForeverTrailSettings.simple then if FT.card then FT.card:Hide() end end
 if FT.StyleTitle then
  for _, f in ipairs({FT.panel, FT.card, FT.settings}) do if f and f.title then FT.StyleTitle(f.title) end end
 end
 if FT.CreateMinimapButton then FT.CreateMinimapButton() end
 if FT.ApplyFont then FT.ApplyFont(ForeverTrailSettings.font) end
 if ForeverTrailSettings.compact and FT.SetCompact then FT.SetCompact(true) end
 if FT.GuardFrames then FT.GuardFrames() end
 local choice=1
 for i,g in ipairs(FT.validGuides) do if g.guideId==ForeverTrailCharacter.guideId then choice=i end end
 if not ForeverTrailCharacter.journalMigration then choice=1; ForeverTrailCharacter.journalMigration=true end
 FT.SelectGuide(choice)
end

