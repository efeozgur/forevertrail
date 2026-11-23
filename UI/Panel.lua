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
local function solid(parent,layer,w,h,point,x,y,r,g,b,a)
 local t=parent:CreateTexture(nil,layer or 'ARTWORK')
 t:SetSize(w,h); t:SetPoint(point,x,y); t:SetColorTexture(r,g,b,a or 1)
 return t
end
local typeIcons={accept='Interface\\GossipFrame\\AvailableQuestIcon',objective='Interface\\GossipFrame\\IncompleteQuestIcon',turnin='Interface\\GossipFrame\\ActiveQuestIcon',location='Interface\\Icons\\INV_Misc_Map_01',manual='Interface\\Buttons\\UI-CheckBox-Check'}
local labels={accept='GÖREVİ AL',objective='HEDEF',turnin='TESLİM ET',location='KONUMA GİT',manual='ELLE ONAYLA'}
local status={unknown='Bilinmiyor',not_taken='Alınmamış',active='Aktif',ready='Teslim edilebilir',turned_in='Teslim edilmiş'}
local PANEL_W, FULL_H, COMPACT_H = ((FT.Kit and FT.Kit.CONTENT_W) or 450) - 4, 620, 300
local M = 16 -- kenar boşluğu
local BODY_H = 304 -- kartın altındaki bölümün (hızlı eylemler, otomatik ilerle, yolculuk) yüksekliği

-- Ortak bileşen katmanı (Core/Kit.lua) yüklenemediyse paneli yine de çalıştıran en yalın karşılıklar
local function fallbackKit()
 local k = {}
 function k.Color() return {1, 1, 1, 1} end
 function k.Fill() end
 function k.Track(fn) fn() end
 function k.Text(parent) return parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight') end
 function k.Divider(parent) return parent:CreateTexture(nil, 'ARTWORK') end
 function k.Frame(parent) return CreateFrame('Frame', nil, parent) end
 function k.Chip(parent)
  local c = CreateFrame('Frame', nil, parent)
  c.text = c:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  function c:Set(text) self.text:SetText(text) end
  return c
 end
 function k.Switch(parent) return CreateFrame('CheckButton', nil, parent, 'UICheckButtonTemplate') end
 return k
end

local function button(parent,text,width,x,y,handler,help,kind)
 local b=FT.Kit and FT.Kit.Button(parent,text,width,24,kind) or FT.NewButton and FT.NewButton(parent,text,width,24)
 if not b then b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate'); b:SetSize(width,24) end
 b:SetPoint('TOPLEFT',x,y); b:SetText(text); b:SetScript('OnClick',handler)
 applyFont(b:GetFontString())
 -- her düğmenin üzerine gelince ne yaptığını anlatan açıklama
 if help and b.HookScript then
  b:HookScript('OnEnter',function(self)
   local tip = FT.Kit and FT.Kit.Tooltip() or GameTooltip
   if not tip then return end
   tip:SetOwner(self,'ANCHOR_TOP')
   if FT.Kit then local a = FT.Kit.Color('accent'); tip:SetText(text,a[1],a[2],a[3]) else tip:SetText(text,1,0.82,0) end
   tip:AddLine(help,0.9,0.9,0.9,true); tip:Show()
  end)
  b:HookScript('OnLeave',function() if FT.Kit then FT.Kit.HideTips() elseif GameTooltip then GameTooltip:Hide() end end)
 end
 return b
end
function FT.ResetPosition()
 ForeverTrailSettings.point=nil; FT.panel:ClearAllPoints(); FT.panel:SetPoint('CENTER',UIParent,'CENTER',0,0)
end

-- Yerleşim: adım kartının yüksekliği içeriğine göre hesaplanır; altındaki bölüm karta bağlıdır, panel yüksekliği ona uyar
local function layout(f)
 local compact=ForeverTrailSettings.compact
 local textW=PANEL_W-2*M-70
 local y=16
 f.instruction:SetWidth(textW); f.instruction:ClearAllPoints(); f.instruction:SetPoint('TOPLEFT',f.stepCard,'TOPLEFT',52,-y)
 y=y+math.max(22,f.instruction:GetStringHeight() or 22)+6
 local stepText=f.stepText:GetText()
 if type(stepText)=='string' and stepText~='' then
  f.stepText:SetWidth(textW); f.stepText:ClearAllPoints(); f.stepText:SetPoint('TOPLEFT',f.stepCard,'TOPLEFT',52,-y); f.stepText:Show()
  y=y+math.max(16,f.stepText:GetStringHeight() or 16)+8
 else f.stepText:Hide() end
 local stateText=f.state:GetText()
 if type(stateText)=='string' and stateText~='' then
  f.state:SetWidth(textW); f.state:ClearAllPoints(); f.state:SetPoint('TOPLEFT',f.stepCard,'TOPLEFT',52,-y); f.state:Show()
  y=y+math.max(15,f.state:GetStringHeight() or 15)+10
 else f.state:Hide() end
 if not compact then
  y=y+4
  f.activate:ClearAllPoints(); f.activate:SetPoint('TOPLEFT',f.stepCard,'TOPLEFT',52,-y)
  f.resume:ClearAllPoints(); f.resume:SetPoint('LEFT',f.activate,'RIGHT',8,0)
  y=y+32+4
 end
 y=y+10
 f.stepCard:SetHeight(y)
 local top=122
 f.compactH=top+y+16
 f.fullH=top+y+14+BODY_H
 f:SetHeight(compact and f.compactH or f.fullH)
end
FT.LayoutPanel=function() if FT.panel then layout(FT.panel) end end

function FT.CreatePanel()
 local K=FT.Kit or fallbackKit()
 local f=newWindow('ForeverTrailPanel',UIParent); FT.panel=f; FT.panelExtras={}
 f:SetSize(PANEL_W,FULL_H); f.barW=PANEL_W-2*M; f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag('LeftButton')
 f:SetScript('OnDragStart',function(self) self:StartMoving() end)
 f:SetScript('OnDragStop',function(self) self:StopMovingOrSizing(); local point,_,relative,x,y=self:GetPoint(); ForeverTrailSettings.point={point,relative,x,y} end)
 local p=ForeverTrailSettings.point
 if p and p[1] and p[2] and p[3] and p[4] then f:SetPoint(p[1],UIParent,p[2],p[3],p[4]) else FT.ResetPosition() end
 f.title=f:CreateFontString(nil,'OVERLAY','GameFontNormal'); f.title:SetPoint('TOP',0,-7); f.title:SetText('ForeverTrail')
 f.icon=f:CreateTexture(nil,'OVERLAY'); f.icon:SetSize(18,18); f.icon:SetPoint('TOPLEFT',9,-3); f.icon:SetTexture('Interface\\Icons\\INV_Misc_Map_01')
 if FT.Kit then f.icon:Hide() end
 local W=PANEL_W-2*M

 -- 1) başlık: açık rehberin adı (büyük), altında bölge ve seviye aralığı (soluk); sağda "Rehber seç"
 f.guide=K.Text(f,16,'text'); f.guide:SetPoint('TOPLEFT',M,-14); f.guide:SetWidth(W-130); f.guide:SetJustifyH('LEFT'); f.guide:SetWordWrap(false)
 f.guideSub=K.Text(f,12,'muted'); f.guideSub:SetPoint('TOPLEFT',M,-38); f.guideSub:SetWidth(W-130); f.guideSub:SetJustifyH('LEFT'); f.guideSub:SetWordWrap(false)
 local headRule=K.Divider(f); headRule:SetPoint('TOPLEFT',0,-64); headRule:SetPoint('TOPRIGHT',0,-64)

 -- 2) gezinme: ‹ 7 / 15 ›, adım türü etiketi, ilerleme çubuğu ve yüzde
 local function previousStep() FT.view=math.max(1,FT.view-1); FT.Refresh() end
 local function nextStep() if FT.guide.live then FT.view=math.min(#FT.guide.steps,FT.view+1) elseif FT.view<FT.active then FT.view=FT.view+1 elseif not FT.complete then FT.Advance(); FT.Evaluate() end; FT.Refresh() end
 f.prevButton=button(f,'<',28,M,-76,previousStep,'Bir önceki adımı incele (etkin adımı değiştirmez).')
 f.prevButton:SetHeight(26)
 f.counter=K.Text(f,15,'text'); f.counter:SetPoint('TOPLEFT',M+32,-80); f.counter:SetWidth(76); f.counter:SetJustifyH('CENTER')
 f.info=f.counter -- eski ad
 f.nextButton=button(f,'>',28,M+32+76+2,-76,nextStep,'Bir sonraki adıma geç.')
 f.nextButton:SetHeight(26)
 f.typeChip=K.Chip(f); f.typeChip:SetPoint('TOPLEFT',M+32+76+2+28+14,-81)
 f.reviewText=K.Text(f,11,'muted'); f.reviewText:SetPoint('LEFT',f.typeChip,'RIGHT',8,0)
 f.pct=K.Text(f,12,'muted'); f.pct:SetPoint('TOPRIGHT',-M,-82); f.pct:SetJustifyH('RIGHT')
 f.barBg=f:CreateTexture(nil,'ARTWORK'); f.barBg:SetHeight(3); f.barBg:SetPoint('TOPLEFT',M,-110); f.barBg:SetWidth(W); K.Fill(f.barBg,'line')
 f.barFill=f:CreateTexture(nil,'OVERLAY'); f.barFill:SetHeight(3); f.barFill:SetPoint('TOPLEFT',M,-110); f.barFill:SetWidth(1); K.Fill(f.barFill,'accent')

 -- 3) adım kartı: görev adı (büyük), açıklama (soluk), durum, ana düğme. Yüksekliği içeriğe göre hesaplanır.
 f.stepCard=K.Frame(f,'card','line')
 f.stepCard:SetPoint('TOPLEFT',M,-122); f.stepCard:SetWidth(W); f.stepCard:SetHeight(150)
 f.boxBar=f.stepCard:CreateTexture(nil,'ARTWORK'); f.boxBar:SetWidth(4)
 f.boxBar:SetPoint('TOPLEFT',1,-1); f.boxBar:SetPoint('BOTTOMLEFT',1,1); f.boxBar:SetColorTexture(1,0.82,0.2,1)
 f.typeIcon=f.stepCard:CreateTexture(nil,'OVERLAY'); f.typeIcon:SetSize(22,22); f.typeIcon:SetPoint('TOPLEFT',20,-16)
 f.instruction=K.Text(f.stepCard,18,'text'); f.instruction:SetJustifyH('LEFT'); f.instruction:SetJustifyV('TOP')
 f.stepText=K.Text(f.stepCard,13,'muted'); f.stepText:SetJustifyH('LEFT'); f.stepText:SetJustifyV('TOP')
 f.state=K.Text(f.stepCard,12,'muted'); f.state:SetJustifyH('LEFT'); f.state:SetJustifyV('TOP')
 f.activate=button(f.stepCard,'Aktif yap',150,52,-120,function() if FT.view~=FT.active then FT.active=FT.view; FT.complete=false; FT.SaveStep() end; FT.Evaluate(); FT.OpenMap() end,'İncelediğin adımı etkin yap ve haritada göster; ok bu adıma yönelir.','primary')
 f.activate:SetHeight(32)
 f.resume=button(f.stepCard,'Buradan sürdür',150,210,-120,FT.ResumeViewed,'Geri dönüp incelediğin adımdan devam et; sonraki adımlar yeniden etkinleşir. Yalnızca başka bir adımı incelerken görünür.')
 f.resume:SetHeight(32)
 FT.panelExtras[#FT.panelExtras+1]=f.activate
 FT.panelExtras[#FT.panelExtras+1]=f.resume

 local suggestions = newWindow(nil, f)
 suggestions:SetSize(PANEL_W-26, 330); suggestions:SetPoint('TOPLEFT', f, 'TOPRIGHT', 4, 0)
 suggestions:SetFrameLevel(f:GetFrameLevel()+10)
 local heading=suggestions:CreateFontString(nil,'OVERLAY','GameFontNormal')
 heading:SetPoint('TOP',0,-10); heading:SetText('Seviyene uygun görevler'); applyFont(heading)
 if FT.RegisterAccent then FT.RegisterAccent(solid(suggestions,'ARTWORK',PANEL_W-50,2,'TOPLEFT',12,-26,0.95,0.72,0.35,0.7),0.7) else solid(suggestions,'ARTWORK',PANEL_W-50,2,'TOPLEFT',12,-26,0.95,0.72,0.35,0.7) end
 local details=suggestions:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 details:SetPoint('TOPLEFT',12,-62); details:SetWidth(PANEL_W-51); details:SetJustifyH('LEFT'); applyFont(details)
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
 local TW=math.floor((PANEL_W-26-24-3*4)/4)
 journalTab=button(suggestions,'Günlüktekiler',TW,12,-30,function() selectTab('journal') end)
 availableTab=button(suggestions,'Alınabilecekler',TW,12+(TW+4),-30,function() selectTab('available') end)
 nearbyTab=button(suggestions,'Bulunduğum bölge',TW,12+2*(TW+4),-30,function() selectTab('nearby') end)
 chainTab=button(suggestions,'Zincir',TW,12+3*(TW+4),-30,function() selectTab('chain') end)
 for i=1,7 do
  local index=i
  rowButtons[i]=button(suggestions,'',PANEL_W-50,12,-82-(i-1)*27,function()
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
 button(suggestions,'Sonraki',80,PANEL_W-26-12-80,-287,function() if page*7<#rows then page=page+1; refreshSuggestions(false) end end)
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
 local picker = newWindow(nil, f)
 picker:SetPoint('TOPLEFT', f, 'TOPLEFT', M, -64)
 picker:SetSize(PANEL_W-2*M, 45 + 28 * #FT.validGuides)
 picker:SetFrameLevel(f:GetFrameLevel() + 10)
 picker:EnableMouse(true)
 local pickerHeading = picker:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
 pickerHeading:SetPoint('TOP', 0, -5)
 pickerHeading:SetText('Rehber seç')
 applyFont(pickerHeading)
 for index, guide in ipairs(FT.validGuides) do
  button(picker, guide.title .. ' · ' .. guide.zone, PANEL_W-2*M-30, 15, -28 * index, function()
   FT.SelectGuide(index)
   picker:Hide()
   FT.notice = 'Rehber seçildi.'
   FT.Refresh()
  end)
 end
 picker:Hide()
 local pick=button(f,'Rehber seç',112,PANEL_W-M-112,-14,function()
  if picker:IsShown() then picker:Hide() else picker:Show() end
 end,'Hangi rehberin izleneceğini seç (Görev günlüğü, bölge rehberleri...).')
 pick:SetHeight(26)

 -- 4) kartın altı: hızlı eylemler, otomatik ilerle, yolculuk. Tek bir kapta durur; küçük panelde topluca gizlenir.
 f.body=CreateFrame('Frame',nil,f)
 f.body:SetSize(W,BODY_H); f.body:SetPoint('TOPLEFT',f.stepCard,'BOTTOMLEFT',0,-14)
 FT.panelExtras[#FT.panelExtras+1]=f.body
 local BW=math.floor((W-3*8)/4)
 button(f.body,'Haritada göster',BW,0,0,FT.OpenMap,'Dünya haritasını aç; hedef ve yol çizgisi görünür.')
 button(f.body,'En yakın',BW,BW+8,0,function() FT.SelectNearest() end,'Bulunduğun yere en yakın görev adımını seç ve haritada göster.')
 button(f.body,'Rota oluştur',BW,2*(BW+8),0,function() FT.BuildRoute() end,'Günlüğündeki görevlerden, en yakından başlayan bir rota çıkar.')
 button(f.body,'Öneriler',BW,3*(BW+8),0,function() if FT.OpenHub then return FT.OpenHub('gorevler') end if suggestions:IsShown() then suggestions:Hide() else suggestionsElapsed=0; selectTab(activeTab); suggestions:Show() end end,'Seviyene uygun görevler: günlükte olanlar, alınabilecekler, bulunduğun bölge, zincir.')
 -- otomatik ilerle: anahtar (switch)
 local autoLabel=K.Text(f.body,13,'text'); autoLabel:SetPoint('TOPLEFT',0,-46); autoLabel:SetText('Otomatik ilerle')
 local autoHint=K.Text(f.body,11,'muted'); autoHint:SetPoint('TOPLEFT',0,-64); autoHint:SetWidth(W-70); autoHint:SetJustifyH('LEFT'); autoHint:SetText('Tamamlanan adımları atlar ve güncel hedefi gösterir.')
 local auto=K.Switch(f.body)
 auto:SetPoint('TOPRIGHT',f.body,'TOPRIGHT',0,-46)
 auto:SetChecked(ForeverTrailSettings.auto)
 auto:SetScript('OnClick',function(self) ForeverTrailSettings.auto=self:GetChecked() and true or false; FT.Evaluate() end)
 f.autoCheck=auto
 -- yolculuk: seçili hedefe giden yol adım adım (Rota planı). Başlığa tıklayınca açılıp kapanır.
 local top=-100
 local rule=K.Divider(f.body); rule:SetPoint('TOPLEFT',0,top+8); rule:SetPoint('TOPRIGHT',0,top+8)
 local head=CreateFrame('Button',nil,f.body); head:SetSize(W,24); head:SetPoint('TOPLEFT',0,top)
 head.text=K.Text(head,14,'accent'); head.text:SetPoint('LEFT',0,0)
 head.hint=K.Text(head,11,'muted'); head.hint:SetPoint('RIGHT',0,0)
 head:SetScript('OnClick',function() ForeverTrailSettings.journeyOpen=not (ForeverTrailSettings.journeyOpen~=false); FT.RefreshJourney() end)
 f.journeyHead=head
 f.journeyRows={}
 for i=1,6 do
  local r=CreateFrame('Frame',nil,f.body); r:SetSize(W,26); r:SetPoint('TOPLEFT',0,top-32-(i-1)*28)
  r.bar=r:CreateTexture(nil,'ARTWORK'); r.bar:SetSize(3,22); r.bar:SetPoint('LEFT',0,0); K.Fill(r.bar,'accent')
  r.chip=K.Chip(r); r.chip:SetPoint('LEFT',12,0)
  r.time=K.Text(r,12,'muted'); r.time:SetPoint('RIGHT',-2,0); r.time:SetJustifyH('RIGHT')
  r.text=K.Text(r,13,'text'); r.text:SetPoint('LEFT',r.chip,'RIGHT',10,0); r.text:SetPoint('RIGHT',r.time,'LEFT',-10,0); r.text:SetJustifyH('LEFT'); r.text:SetWordWrap(false)
  r.num=r.chip -- eski ad
  f.journeyRows[i]=r
 end
 f.journeyEmpty=K.Text(f.body,12,'muted'); f.journeyEmpty:SetPoint('TOPLEFT',2,top-34); f.journeyEmpty:SetWidth(W-4); f.journeyEmpty:SetJustifyH('LEFT')
 applyFont(f.title)
 f:Show()
end

-- Yolculuk adımının türü: etiket ve renk. Süre varsa ("(1:28)") ayrılır.
local KINDS={
 {'Uçuş','UÇUŞ',{0.5,0.75,1}},{'uçuş','UÇUŞ',{0.5,0.75,1}},{'eplin','ZEPLİN',{0.5,0.75,1}},{'emi ','GEMİ',{0.5,0.75,1}},
 {'ıkış','ÇIKIŞ',{0.67,0.7,0.76}},{'dışarı','ÇIKIŞ',{0.67,0.7,0.76}},{'iriş','GİRİŞ',{0.75,0.62,0.95}},{'ürü','YÜRÜ',{0.67,0.7,0.76}},
}
local function classify(text,last)
 if last then return 'VARIŞ',{0.55,0.9,0.5} end
 for _,k in ipairs(KINDS) do if text:find(k[1],1,true) then return k[2],k[3] end end
 return 'ADIM',{0.67,0.7,0.76}
end
-- "Uçuş: A → B (1:28)" gibi bir adımı metin ve saniyeye ayırır: dönüş metin, saniye (süre yoksa nil)
local function splitTime(text)
 local m,s=text:match('%((%d+):(%d%d)%)%s*$')
 if not m then return text,nil end
 local clean=text:gsub('%s*%(%d+:%d%d%)%s*$','')
 return clean,tonumber(m)*60+tonumber(s)
end
FT.JourneySplitTime=splitTime
FT.JourneyClassify=classify

-- Yolculuk bölümü: hedefe giden adımlar (en çok 6); kapalıysa ya da küçük paneldeyse yalnızca başlık/hiçbiri görünür
function FT.RefreshJourney()
 local f=FT.panel
 if not (f and f.journeyRows) then return end
 local compact=ForeverTrailSettings.compact
 local open=ForeverTrailSettings.journeyOpen~=false
 local steps={}
 if open and not compact and FT.RoutePlan then
  local ok,list=pcall(FT.RoutePlan)
  if ok and type(list)=='table' then steps=list end
 end
 local total,shown=0,math.min(#steps,#f.journeyRows)
 for i,row in ipairs(f.journeyRows) do
  local text=steps[i]
  if text and open and not compact then
   local seconds
   text,seconds=splitTime(text)
   if seconds then total=total+seconds end
   local label,c=classify(text,i==#steps)
   row.chip:Set(label,c[1],c[2],c[3])
   row.text:SetText(text)
   row.time:SetText(seconds and ('%d:%02d'):format(math.floor(seconds/60),seconds%60) or '')
   row.bar:SetShown(i==1); row:Show()
  else row:Hide() end
 end
 f.journeyHead.text:SetText('Yolculuk')
 local summary=(#steps>0 and open) and (('%d adım'):format(#steps)..(total>0 and ('  ·  ~%d dk'):format(math.max(1,math.floor(total/60+0.5))) or '')..'  ·  ') or ''
 f.journeyHead.hint:SetText(summary..(open and 'gizle' or 'göster'))
 f.journeyEmpty:SetText('Bir hedef seçince oraya giden yol burada adım adım görünür.')
 f.journeyEmpty:SetShown(open and not compact and #steps==0)
 if compact then f.journeyHead:Hide() else f.journeyHead:Show() end
end
function FT.Refresh()
 FT.RefreshMap()
 if not FT.panel or not FT.guide then return end
 local f=FT.panel; local g=FT.guide; local s=g.steps[FT.view]
 if not s then FT.view=1; s=g.steps[1] end
 if not s then return end
 if FT.EnsureWaypoint then FT.EnsureWaypoint(s) end
 local state=FT.QuestState(s.questId,s.objectiveIndex)
 -- başlık
 f.guide:SetText(g.title)
 f.guideSub:SetText((g.zone or '')..(g.levels and ('  ·  '..g.levels) or ''))
 -- gezinme
 local tc=typeColor[s.type] or typeColor.manual
 f.typeIcon:SetTexture(typeIcons[s.type] or typeIcons.manual)
 f.boxBar:SetColorTexture(tc[1],tc[2],tc[3],1)
 f.typeChip:Set(labels[s.type] or s.type,tc[1],tc[2],tc[3])
 f.counter:SetText(('%d / %d'):format(FT.view,#g.steps))
 f.reviewText:SetText(FT.view~=FT.active and '(inceleme)' or '')
 local ratio=math.min(1,(FT.complete and FT.view==FT.active) and 1 or FT.view/math.max(1,#g.steps))
 local barColor=FT.Kit and FT.Kit.Color('accent') or tc
 f.barFill:SetColorTexture(barColor[1],barColor[2],barColor[3],1)
 f.barFill:SetWidth(math.max(1,(f.barW or 366)*ratio))
 f.pct:SetText(('%%%d'):format(math.floor(ratio*100+0.5)))
 if f.resume then f.resume:SetShown(FT.view~=FT.active and not ForeverTrailSettings.compact) end
 -- adım kartı: görev adı büyük, ne yapılacağı soluk
 local record = type(QTR_QuestData) == 'table' and QTR_QuestData[tostring(s.questId)]
 local title = (record and record.Title) or s.questTitle
 local instruction = s.text
 if type(record) == 'table' and s.type == 'objective' and not s.objectiveIndex then
  local objective = record.Objectives
  if type(objective) == 'string' and objective ~= '' and not objective:find('[$]') then
   instruction = objective
  end
 end
 if type(title) == 'string' and title ~= '' then
  f.instruction:SetText(title); f.stepText:SetText(instruction or '')
 else
  f.instruction:SetText(instruction or ''); f.stepText:SetText('')
 end
 local message=FT.complete and FT.view==FT.active and 'Rehber tamamlandı.' or (status[state.status] or 'Bilinmiyor')
 if not g.live and state.objective and state.objective.text then message=message..' - '..state.objective.text end
 if s.questId and state.status=='not_taken' and s.type~='accept' then message=message..' - Görev günlükte yok. Görevi al adımına dön.' end
 if s.x and s.y then message=message..('  ·  %.1f, %.1f'):format(s.x*100,s.y*100) end
 if s.uiMapID and C_Map and C_Map.GetBestMapForUnit then
  local okMap,playerMap=pcall(C_Map.GetBestMapForUnit,'player')
  if okMap and playerMap and playerMap~=s.uiMapID then message=message..'  ·  Başka bölgede: '..tostring(FT.MapName and FT.MapName(s.uiMapID) or s.uiMapID) end
 end
 if FT.customTarget then message=message..'\nÖzel hedef aktif (kaldırmak için /ftrail iptal)' end
 if FT.notice then message=message..'\n'..FT.notice end
 if g.live and not s.questId then f.counter:SetText('Görev günlüğü'); message='' end
 local sc=statusColor[FT.complete and FT.view==FT.active and 'turned_in' or state.status] or statusColor.unknown
 f.state:SetTextColor(sc[1],sc[2],sc[3])
 f.state:SetText(message)
 layout(f)
 if FT.RefreshTarget then FT.RefreshTarget() end
 if FT.RefreshTracker then FT.RefreshTracker() end
 if FT.CheckProgress then pcall(FT.CheckProgress) end
 pcall(FT.RefreshJourney)
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
 layout(f)
 if on then
  if FT.card then FT.card:Hide() end
  if FT.tracker then FT.tracker:Hide() end
 else
  if FT.card and ForeverTrailSettings.card ~= false then FT.card:Show() end
  if FT.tracker and ForeverTrailSettings.tracker ~= false then FT.tracker:Show() end
 end
 FT.Refresh()
end
