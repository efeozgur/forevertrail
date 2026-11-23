local _, FT = ...
local turkishFont = "Interface\\AddOns\\WoWTR\\Assets\\Fonts\\frizquadrata_tr.ttf"

local function newWindow(name, parent)
 if FT.NewWindow then return FT.NewWindow(name, parent) end
 return CreateFrame('Frame', name, parent, 'BasicFrameTemplateWithInset')
end
local function applyFont(label)
 if not label then return end
 local path, size, flags = label:GetFont()
 if size and label:SetFont(turkishFont, size, flags or "") == false and path then
  label:SetFont(path, size, flags or "")
 end
end
local typeColor=FT.TypeColor or {accept={0.55,0.82,0.5},objective={0.98,0.8,0.4},turnin={0.55,0.72,0.95},location={0.75,0.62,0.95},manual={0.78,0.74,0.68}}
local statusColor={turned_in={0.62,0.78,0.6},ready={0.55,0.9,0.5},active={0.98,0.8,0.4},not_taken={0.95,0.6,0.5},unknown={0.78,0.72,0.64}}
local function hex(c) return ('%02x%02x%02x'):format(math.floor(c[1]*255+0.5),math.floor(c[2]*255+0.5),math.floor(c[3]*255+0.5)) end
local function solid(parent,layer,w,h,point,x,y,r,g,b,a)
 local t=parent:CreateTexture(nil,layer or 'ARTWORK')
 t:SetSize(w,h); t:SetPoint(point,x,y); t:SetColorTexture(r,g,b,a or 1)
 return t
end
local typeIcons={accept='Interface\\GossipFrame\\AvailableQuestIcon',objective='Interface\\GossipFrame\\IncompleteQuestIcon',turnin='Interface\\GossipFrame\\ActiveQuestIcon',location='Interface\\Icons\\INV_Misc_Map_01',manual='Interface\\Buttons\\UI-CheckBox-Check'}
local labels={accept='GÖREVİ AL',objective='HEDEF',turnin='TESLİM ET',location='KONUMA GİT',manual='ELLE ONAYLA'}
local status={unknown='Bilinmiyor',not_taken='Alınmamış',active='Aktif',ready='Teslim edilebilir',turned_in='Teslim edilmiş'}
local PANEL_W, FULL_H, COMPACT_H = 446, 376, 226
local EXTRA_Y = -228 -- bunun altındaki düğmeler "küçük panel"de gizlenir
local function button(parent,text,width,x,y,handler,help)
 local b=FT.NewButton and FT.NewButton(parent,text,width,24)
 if not b then b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate'); b:SetSize(width,24) end
 b:SetPoint('TOPLEFT',x,y); b:SetText(text); b:SetScript('OnClick',handler)
 if FT.panelExtras and parent==FT.panel and y<=EXTRA_Y then FT.panelExtras[#FT.panelExtras+1]=b end
 applyFont(b:GetFontString())
 -- her düğmenin üzerine gelince ne yaptığını anlatan açıklama
 if help and b.HookScript then
  b:HookScript('OnEnter',function(self)
   if not GameTooltip then return end
   GameTooltip:SetOwner(self,'ANCHOR_TOP'); GameTooltip:SetText(text,1,0.82,0); GameTooltip:AddLine(help,0.9,0.9,0.9,true); GameTooltip:Show()
  end)
  b:HookScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
 end
 return b
end
-- Bölüm başlığı (küçük gri büyük harf)
local function section(parent,text,y)
 local fs=parent:CreateFontString(nil,'OVERLAY','GameFontDisableSmall')
 fs:SetPoint('TOPLEFT',14,y); fs:SetText(text); fs:SetTextColor(0.62,0.6,0.56)
 applyFont(fs)
 if FT.panelExtras then FT.panelExtras[#FT.panelExtras+1]=fs end
 return fs
end
function FT.ResetPosition()
 ForeverTrailSettings.point=nil; FT.panel:ClearAllPoints(); FT.panel:SetPoint('CENTER',UIParent,'CENTER',0,0)
end
function FT.CreatePanel()
 local f=newWindow('ForeverTrailPanel',UIParent); FT.panel=f; FT.panelExtras={}
 f:SetSize(PANEL_W,FULL_H); f.barW=PANEL_W-24; f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart',function(self) self:StartMoving() end)
 f:SetScript('OnDragStop',function(self) self:StopMovingOrSizing(); local point,_,relative,x,y=self:GetPoint(); ForeverTrailSettings.point={point,relative,x,y} end)
 local p=ForeverTrailSettings.point
 if p and p[1] and p[2] and p[3] and p[4] then f:SetPoint(p[1],UIParent,p[2],p[3],p[4]) else FT.ResetPosition() end
 f.title=f:CreateFontString(nil,'OVERLAY','GameFontNormal'); f.title:SetPoint('TOP',0,-7); f.title:SetText('ForeverTrail')
 f.icon=f:CreateTexture(nil,'OVERLAY'); f.icon:SetSize(18,18); f.icon:SetPoint('TOPLEFT',9,-3); f.icon:SetTexture('Interface\\Icons\\INV_Misc_Map_01')
 local W=PANEL_W-24
 -- 1) rehber şeridi: hangi rehber açık + "Rehber seç"
 f.guideBg=solid(f,'ARTWORK',W,24,'TOPLEFT',12,-30,0.07,0.04,0.02,0.45)
 f.guide=f:CreateFontString(nil,'OVERLAY','GameFontNormal'); f.guide:SetPoint('TOPLEFT',18,-36); f.guide:SetWidth(W-122); f.guide:SetHeight(14); f.guide:SetJustifyH('LEFT'); f.guide:SetWordWrap(false)
 if FT.RegisterAccent then FT.RegisterAccent(solid(f,'ARTWORK',W,2,'TOPLEFT',12,-57,0.95,0.72,0.35,0.7),0.7) else solid(f,'ARTWORK',W,2,'TOPLEFT',12,-57,0.95,0.72,0.35,0.7) end
 -- 2) adım satırı ve ilerleme çubuğu
 f.typeIcon=f:CreateTexture(nil,'OVERLAY'); f.typeIcon:SetSize(16,16); f.typeIcon:SetPoint('TOPLEFT',14,-64)
 f.info=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); f.info:SetPoint('TOPLEFT',36,-67); f.info:SetWidth(W-30); f.info:SetJustifyH('LEFT')
 f.barBg=solid(f,'ARTWORK',W,6,'TOPLEFT',12,-86,0.05,0.03,0.01,0.7)
 f.barFill=solid(f,'ARTWORK',1,6,'TOPLEFT',12,-86,0.3,0.85,0.4,1)
 -- 3) şimdi ne yapılacak (büyük kart) ve durum
 f.boxBg=solid(f,'ARTWORK',W,70,'TOPLEFT',12,-98,0.07,0.04,0.02,0.5)
 f.boxBar=solid(f,'ARTWORK',4,70,'TOPLEFT',12,-98,1,0.82,0.2,1)
 f.instruction=f:CreateFontString(nil,'OVERLAY','GameFontHighlight'); f.instruction:SetPoint('TOPLEFT',24,-104); f.instruction:SetWidth(W-22); f.instruction:SetHeight(58); f.instruction:SetJustifyH('LEFT'); f.instruction:SetJustifyV('TOP')
 f.stateBg=solid(f,'ARTWORK',W,44,'TOPLEFT',12,-174,0.10,0.06,0.03,0.5)
 f.state=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); f.state:SetPoint('TOPLEFT',20,-179); f.state:SetWidth(W-16); f.state:SetHeight(36); f.state:SetJustifyH('LEFT'); f.state:SetJustifyV('TOP')
 -- 4) düğmeler: ADIMLAR / YOL VE GÖREVLER / DİĞER
 section(f,'ADIMLAR',-230)
 button(f,'Önceki',100,12,-244,function() FT.view=math.max(1,FT.view-1); FT.Refresh() end,'Bir önceki adımı incele (etkin adımı değiştirmez).')
 button(f,'Sonraki',100,116,-244,function() if FT.guide.live then FT.view=math.min(#FT.guide.steps,FT.view+1) elseif FT.view<FT.active then FT.view=FT.view+1 elseif not FT.complete then FT.Advance(); FT.Evaluate() end; FT.Refresh() end,'Bir sonraki adıma geç.')
 button(f,'Aktif yap',100,220,-244,function() if FT.view~=FT.active then FT.active=FT.view; FT.complete=false; FT.SaveStep() end; FT.Evaluate(); FT.OpenMap() end,'İncelediğin adımı etkin yap ve haritada göster; ok bu adıma yönelir.')
 local suggestions = newWindow(nil, f)
 suggestions:SetSize(420, 330); suggestions:SetPoint('TOPLEFT', f, 'TOPRIGHT', 4, 0)
 suggestions:SetFrameLevel(f:GetFrameLevel()+10)
 local heading=suggestions:CreateFontString(nil,'OVERLAY','GameFontNormal')
 heading:SetPoint('TOP',0,-10); heading:SetText('Seviyene uygun görevler'); applyFont(heading)
 if FT.RegisterAccent then FT.RegisterAccent(solid(suggestions,'ARTWORK',396,2,'TOPLEFT',12,-26,0.95,0.72,0.35,0.7),0.7) else solid(suggestions,'ARTWORK',396,2,'TOPLEFT',12,-26,0.95,0.72,0.35,0.7) end
 local details=suggestions:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 details:SetPoint('TOPLEFT',12,-62); details:SetWidth(395); details:SetJustifyH('LEFT'); applyFont(details)
 local rows, page, rowButtons, activeTab = {}, 1, {}, 'journal'
 local refreshSuggestions
 local journalTab, availableTab, nearbyTab, chainTab
 local chainState='ok'
 local function selectTab(tab)
  activeTab=tab; page=1
  journalTab:Enable(); availableTab:Enable(); nearbyTab:Enable(); chainTab:Enable()
  if tab=='journal' then journalTab:Disable() elseif tab=='available' then availableTab:Disable() elseif tab=='chain' then chainTab:Disable() else nearbyTab:Disable() end
  refreshSuggestions(true)
  if tab=='chain' then if FT.ShowChainOnMap then FT.ShowChainOnMap() end elseif FT.ClearChainPreview then FT.ClearChainPreview() end
 end
 journalTab=button(suggestions,'Günlüktekiler',98,12,-30,function() selectTab('journal') end)
 availableTab=button(suggestions,'Alınabilecekler',108,113,-30,function() selectTab('available') end)
 nearbyTab=button(suggestions,'Bulunduğum bölge',118,224,-30,function() selectTab('nearby') end)
 chainTab=button(suggestions,'Zincir',66,345,-30,function() selectTab('chain') end)
 for i=1,7 do
  local index=i
  rowButtons[i]=button(suggestions,'',395,12,-82-(i-1)*27,function()
   local row=rows[(page-1)*7+index]
   if not row then return end
   if row.active then
    for guideIndex, guide in ipairs(FT.validGuides) do
     if guide.live then
      FT.SelectGuide(guideIndex)
      for j,step in ipairs(guide.steps) do
       if step.questId==row.id then FT.active=j; FT.view=j; FT.SaveStep(); break end
      end
      break
     end
    end
   else
    FT.guide={guideId='recommendation',title=row.title,zone='Önerilen görev',version=1,steps={{stepId='recommendation-'..row.id,type='accept',questId=row.id,questTitle=row.title,text='Görevi al.'}}}
    FT.active=1; FT.view=1; FT.complete=false; FT.notice=nil
   end
   FT.Refresh(); FT.OpenMap()
  end)
 end
 local pageLabel=suggestions:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 pageLabel:SetPoint('BOTTOM',0,12); applyFont(pageLabel)
 button(suggestions,'Önceki',80,12,-287,function() if page>1 then page=page-1; refreshSuggestions(false) end end)
 button(suggestions,'Sonraki',80,327,-287,function() if page*7<#rows then page=page+1; refreshSuggestions(false) end end)
 refreshSuggestions=function(reload)
  local available
  if reload then
   local all
   all,available=FT.GetRecommendations()
   rows={}
   local locationReady=true
   if activeTab=='nearby' then rows,locationReady=FT.GetNearbyRecommendations(all)
   elseif activeTab=='chain' then
    if FT.GetQuestChain then
     local list,state=FT.GetQuestChain()
     chainState=state
     for _,r in ipairs(list) do rows[#rows+1]={id=r.id,title=r.title,level=r.level,active=r.active,ready=false,status=r.chainStatus,current=r.chainCurrent,zone=r.zone} end
     if FT.SetChainPreview then FT.SetChainPreview(rows) end
    else chainState='unavailable' end
   else
    for _,row in ipairs(all) do
     if (row.active and activeTab=='journal') or (not row.active and activeTab=='available') then rows[#rows+1]=row end
    end
   end
   page=math.min(page,math.max(1,math.ceil(#rows/7)))
   details:SetText(activeTab=='chain' and (chainState=='noquest' and 'Zincir için önce bir görev al.' or (chainState=='unavailable' and 'Görev verisi okunamıyor; zincir gösterilemiyor.' or 'Görev zinciri: önceki ve sonraki görevler (* = şu anki).')) or activeTab=='nearby' and not locationReady and 'Bölge veya görev konumları okunamıyor.' or (activeTab=='available' and not available and 'Görev verisi okunamıyor; alınabilecek görevler gösterilemiyor.' or (activeTab=='nearby' and 'Bu bölgedeki görevler; XP sırasıyla.' or 'XP yüksekten düşüğe sıralanır; seçerek haritada aç.')))
  end
  for i,b in ipairs(rowButtons) do
   local row=rows[(page-1)*7+i]
   if row then
    local xp=row.xp and (row.xp..' XP') or 'XP bilinmiyor'
    local level=type(row.level)=='number' and row.level>0 and tostring(row.level) or '?'
    if row.status then b:SetText(('[%s] %s | %s%s%s'):format(level,row.title,row.status,row.zone and (' | '..row.zone) or '',row.current and '  *' or ''))
    else b:SetText(('[%s] %s | %s | %s'):format(level,row.title,xp,row.active and (row.ready and 'Teslim' or 'Günlükte') or 'Alınabilir')) end
    local fs=b:GetFontString()
    if fs then
     if row.ready then fs:SetTextColor(0.6,0.92,0.55) elseif row.active then fs:SetTextColor(0.98,0.8,0.4) else fs:SetTextColor(1,0.94,0.82) end
    end
    b:Show()
   else b:Hide() end
  end
  pageLabel:SetText(#rows==0 and (activeTab=='chain' and 'Zincir bilgisi yok.' or activeTab=='journal' and 'Uygun günlük görevi yok.' or (activeTab=='nearby' and 'Bu bölgede bilinen uygun görev yok.' or 'Alınabilecek uygun görev yok.')) or ('%d / %d'):format(page,math.max(1,math.ceil(#rows/7))))
 end
 suggestions:Hide()
 FT.suggestions=suggestions
 local suggestionsElapsed=0
 suggestions:SetScript('OnUpdate',function(_,dt)
  suggestionsElapsed=suggestionsElapsed+dt
  if suggestionsElapsed>=3 then suggestionsElapsed=0; refreshSuggestions(true) end
 end)
 FT.ShowSuggestions=function() suggestionsElapsed=0; selectTab(activeTab); suggestions:Show() end
 section(f,'YOL VE GÖREVLER',-276)
 button(f,'Haritada göster',100,12,-290,FT.OpenMap,'Dünya haritasını aç; hedef ve yol çizgisi görünür.')
 button(f,'En yakın',100,116,-290,function() FT.SelectNearest() end,'Bulunduğun yere en yakın görev adımını seç ve haritada göster.')
 button(f,'Rota oluştur',100,220,-290,function() FT.BuildRoute() end,'Günlüğündeki görevlerden, en yakından başlayan bir rota çıkar.')
 button(f,'Öneriler',110,324,-290,function() if FT.OpenHub then return FT.OpenHub('gorevler') end if suggestions:IsShown() then suggestions:Hide() else suggestionsElapsed=0; selectTab(activeTab); suggestions:Show() end end,'Seviyene uygun görevler: günlükte olanlar, alınabilecekler, bulunduğun bölge, zincir.')
 local picker = newWindow(nil, f)
 picker:SetPoint('TOPLEFT', f, 'TOPLEFT', 12, -56)
 picker:SetSize(PANEL_W-24, 45 + 28 * #FT.validGuides)
 picker:SetFrameLevel(f:GetFrameLevel() + 10)
 picker:EnableMouse(true)
 local heading = picker:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 heading:SetPoint('TOP', 0, -5)
 heading:SetText('Rehber seç')
 applyFont(heading)
 for index, guide in ipairs(FT.validGuides) do
  button(picker, guide.title .. ' · ' .. guide.zone, PANEL_W-54, 15, -28 * index, function()
   FT.SelectGuide(index)
   picker:Hide()
   FT.notice = 'Rehber seçildi.'
   FT.Refresh()
  end)
 end
 picker:Hide()
 button(f,'Buradan sürdür',110,324,-244,FT.ResumeViewed,'Geri dönüp incelediğin adımdan devam et; sonraki adımlar yeniden etkinleşir.')
 local pick=button(f,'Rehber seç',104,PANEL_W-12-104,-30,function()
  if picker:IsShown() then picker:Hide() else picker:Show() end
 end,'Hangi rehberin izleneceğini seç (Görev günlüğü, bölge rehberleri...).')
 section(f,'DİĞER',-322)
 button(f,'Ayarlar',100,12,-336,function() if FT.ToggleSettings then FT.ToggleSettings() end end,'ForeverTrail ayarlarını aç.')
 local check=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate'); check:SetPoint('TOPLEFT',116,-335); check:SetChecked(ForeverTrailSettings.auto); check:SetScript('OnClick',function(self) ForeverTrailSettings.auto=self:GetChecked() and true or false; FT.Evaluate() end)
 local label=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); label:SetPoint('LEFT',check,'RIGHT',0,0); label:SetText('Otomatik ilerle')
 FT.panelExtras[#FT.panelExtras+1]=check; FT.panelExtras[#FT.panelExtras+1]=label
 for _, region in ipairs({f.title, f.guide, f.info, f.instruction, f.state, label}) do
  applyFont(region)
 end
 f.title:SetTextColor(1,0.82,0.45)
 f.guide:SetTextColor(1,0.88,0.6)
 f.info:SetTextColor(1,0.94,0.82)
 f.instruction:SetTextColor(1,0.96,0.88)
 for _, region in ipairs({f.title,f.guide,f.instruction}) do
  local path,size,flags=region:GetFont()
  if path and size then region:SetFont(path,size+1,flags or '') end
  region:SetShadowOffset(1,-1); region:SetShadowColor(0,0,0,0.8)
 end
 f:Show()
end
function FT.Refresh()
 FT.RefreshMap()
 if not FT.panel or not FT.guide then return end
 local f=FT.panel; local g=FT.guide; local s=g.steps[FT.view]
 if not s then FT.view=1; s=g.steps[1] end
 if not s then return end
 if FT.EnsureWaypoint then FT.EnsureWaypoint(s) end
 local state=FT.QuestState(s.questId,s.objectiveIndex)
 f.guide:SetText(g.title..'  |  '..g.zone..(g.levels and ('  |  '..g.levels) or ''))
 local tc=typeColor[s.type] or typeColor.manual
 f.typeIcon:SetTexture(typeIcons[s.type] or typeIcons.manual)
 f.boxBar:SetColorTexture(tc[1],tc[2],tc[3],1)
 f.barFill:SetColorTexture(tc[1],tc[2],tc[3],1)
 f.barFill:SetWidth(math.max(1,(f.barW or 366)*math.min(1,(FT.complete and FT.view==FT.active) and 1 or FT.view/math.max(1,#g.steps))))
 f.info:SetText(('Adım %d / %d  |cff%s[%s]|r%s'):format(FT.view,#g.steps,hex(tc),labels[s.type] or s.type, FT.view~=FT.active and '  |cffc8b89f(inceleme)|r' or ''))
 local record = type(QTR_QuestData) == 'table' and QTR_QuestData[tostring(s.questId)]
 local title = (record and record.Title) or s.questTitle
 local instruction = s.text
 if type(record) == 'table' and s.type == 'objective' and not s.objectiveIndex then
  local objective = record.Objectives
  if type(objective) == 'string' and objective ~= '' and not objective:find('[$]') then
   instruction = objective
  end
 end
 if type(title) == 'string' and title ~= '' then instruction = title .. ' — ' .. instruction end
 f.instruction:SetText(instruction)
 local message=FT.complete and FT.view==FT.active and 'Rehber tamamlandı.' or (status[state.status] or 'Bilinmiyor')
 if not g.live and state.objective and state.objective.text then message=message..' - '..state.objective.text end
 if s.questId and state.status=='not_taken' and s.type~='accept' then message=message..' - Görev günlükte yok. Görevi al adımına dön.' end
 if s.x and s.y then message=message..('  |  %.1f, %.1f'):format(s.x*100,s.y*100) end
 if s.uiMapID and C_Map and C_Map.GetBestMapForUnit then
  local okMap,playerMap=pcall(C_Map.GetBestMapForUnit,'player')
  if okMap and playerMap and playerMap~=s.uiMapID then message=message..'  |  Başka bölgede: '..tostring(FT.MapName and FT.MapName(s.uiMapID) or s.uiMapID) end
 end
 if FT.customTarget then message=message..'\nÖzel hedef aktif (kaldırmak için /ftrail iptal)' end
 if FT.notice then message=message..'\n'..FT.notice end
 if g.live and not s.questId then f.info:SetText('Görev günlüğü'); message='' end
 local sc=statusColor[FT.complete and FT.view==FT.active and 'turned_in' or state.status] or statusColor.unknown
 f.state:SetTextColor(sc[1],sc[2],sc[3])
 f.state:SetText(message)
 if FT.RefreshTarget then FT.RefreshTarget() end
 if FT.RefreshTracker then FT.RefreshTracker() end
 if FT.CheckProgress then pcall(FT.CheckProgress) end
end
local elapsed=0
local retargetElapsed=0
FT.eventFrame:SetScript('OnUpdate',function(_,dt)
 retargetElapsed=retargetElapsed+dt
 if retargetElapsed>=3 then retargetElapsed=0; if FT.ready and FT.guide and FT.Retarget then FT.Retarget() end end
 if FT.pending then
  FT.pending=FT.pending-dt
  if FT.pending<=0 then FT.pending=nil; FT.Evaluate() end
 end
 local step=FT.ready and FT.guide and FT.CurrentStep()
 if not step or FT.complete or not ForeverTrailSettings.auto or step.type~='location' then return end
 elapsed=elapsed+dt; if elapsed>=1 then elapsed=0; FT.Evaluate() end
end)




function FT.SetCompact(on)
 local f=FT.panel
 if not f then return end
 on = on and true or false
 ForeverTrailSettings.compact = on
 for _,widget in ipairs(FT.panelExtras or {}) do if on then widget:Hide() else widget:Show() end end
 f:SetHeight(on and COMPACT_H or FULL_H)
 if on then
  if FT.card then FT.card:Hide() end
  if FT.tracker then FT.tracker:Hide() end
 else
  if FT.card and ForeverTrailSettings.card ~= false then FT.card:Show() end
  if FT.tracker and ForeverTrailSettings.tracker ~= false then FT.tracker:Show() end
  FT.Refresh()
 end
end
