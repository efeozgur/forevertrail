local buttons, widgets = {}, {}
local W = {}
local function widget()
 local w=setmetatable({shown=true}, {__index=function(_,k) return W[k] or function() end end})
 widgets[#widgets+1]=w
 return w
end
CreateFrame=widget
W.CreateFontString=widget; W.CreateTexture=widget; W.GetFontString=widget
W.GetFont=function() return 'font',12,'' end
W.GetFrameLevel=function() return 1 end
W.SetText=function(self,text) self.text=text; buttons[text]=self end
W.SetScript=function(self,event,fn) self[event]=fn end
W.Show=function(self) self.shown=true end
W.Hide=function(self) self.shown=false end
W.IsShown=function(self) return self.shown end
UIParent=widget()
ForeverTrailSettings={auto=false}; ForeverTrailCharacter={}
local journal={guideId='character-log',live=true,title='Journal',zone='Test',steps={{stepId='1:objective:1',questId=1,type='objective',text='Do it'}}}
local selected
local loaded=false
local ft
ft={validGuides={journal},guide=journal,active=1,view=1,eventFrame=widget(),
 GetRecommendations=function() if not loaded then return {{id=1,title='Active',level=10,xp=100,active=true}},true end; return {{id=2,title='New',level=10,xp=200},{id=1,title='Active',level=10,xp=100,active=true}},true end,
 GetNearbyRecommendations=function(all) return all,true end,
 SelectGuide=function() ft.guide=journal end,
 SaveStep=function() end, QuestState=function() return {status='active'} end,
 RefreshMap=function() end, OpenMap=function() selected=ft.guide.steps[ft.active].questId end,
 ResumeViewed=function() end, Evaluate=function() end}
assert(loadfile('UI/Panel.lua'))('ForeverTrail',ft)
ft.CreatePanel()
buttons['Öneriler'].OnClick()
assert(not buttons['[10] New | 200 XP | Alınabilir'])
assert(buttons['[10] Active | 100 XP | Günlükte'].shown)
loaded=true
for _,w in ipairs(widgets) do if w.OnUpdate and w.shown then w.OnUpdate(w,3) end end
assert(not buttons['[10] New | 200 XP | Alınabilir'], 'available quests must not appear in journal tab')
assert(buttons['Alınabilecekler'], 'available tab is missing')
buttons['Alınabilecekler'].OnClick()
assert(buttons['[10] New | 200 XP | Alınabilir'])
buttons['[10] New | 200 XP | Alınabilir'].OnClick()
assert(selected==2 and ft.guide.steps[1].type=='accept', 'available quest selection failed')
assert(buttons['Bulunduğum bölge'], 'nearby tab is missing')
buttons['Bulunduğum bölge'].OnClick()
assert(buttons['[10] New | 200 XP | Alınabilir'].shown and buttons['[10] Active | 100 XP | Günlükte'].shown, 'nearby tab must show both types')
buttons['Günlüktekiler'].OnClick()
buttons['[10] Active | 100 XP | Günlükte'].OnClick()
assert(selected==1 and ft.guide==journal, 'active quest selection failed')
print('Recommendation panel tests passed')
