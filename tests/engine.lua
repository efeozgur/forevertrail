local ns = {}
assert(loadfile('Engine.lua'))('ForeverTrail', ns)
assert(loadfile('Quest.lua'))('ForeverTrail', ns)
local g = {guideId='test', version=1, title='Test', zone='Zone', steps={
 {stepId='a', type='accept', text='Accept', questId=1},
 {stepId='b', type='objective', text='Objective', questId=1, objectiveIndex=1},
 {stepId='c', type='turnin', text='Turn in', questId=1},
 {stepId='d', type='manual', text='Confirm'} }}
assert(ns.ValidateGuide(g))
local state={status='not_taken'}
assert(not ns.IsStepDone(g.steps[1],state))
state.status='active'; assert(ns.IsStepDone(g.steps[1],state)); assert(not ns.IsStepDone(g.steps[2],state))
state.status='ready'; assert(not ns.IsStepDone(g.steps[2],state))
state.objective={finished=true}; assert(ns.IsStepDone(g.steps[2],state)); assert(not ns.IsStepDone(g.steps[3],state))
state.status='turned_in'; assert(ns.IsStepDone(g.steps[3],state)); assert(not ns.IsStepDone(g.steps[4],state))
g.steps[2].stepId='a'; assert(not ns.ValidateGuide(g)); g.steps[2].stepId='b'
g.steps[2].x=1.1; g.steps[2].y=0.5; g.steps[2].uiMapID=1; assert(not ns.ValidateGuide(g))
C_QuestLog={GetLogIndexForQuestID=function() return nil end, IsQuestFlaggedCompleted=function() return false end}
assert(ns.QuestState(1).status=='not_taken')
ns.turnedIn[1]=true; assert(ns.QuestState(1).status=='turned_in')
print('engine tests passed')
