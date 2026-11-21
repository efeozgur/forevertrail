local data={
 [1]={name='First',nextQuestInChain=2},
 [2]={name='Current',preQuestSingle={1},childQuests={3,4}},
 [3]={name='Next',preQuestSingle={2}},
 [4]={name='Alternate',preQuestGroup={2}},
}
local modules={QuestieDB={QueryQuestSingle=function(id,key) return data[id] and data[id][key] end},AvailableQuests={__availableQuests={[3]=true}}}
QuestieLoader={ImportModule=function(_,name) return modules[name] end}
Questie={db={char={journey={{Event='Quest',SubType='Accept',Quest=2}}}}}
ForeverTrailCharacter={}
C_QuestLog={GetLogIndexForQuestID=function(id) return id==2 and 1 or 0 end,IsQuestFlaggedCompleted=function(id) return id==1 end}
local ft={}
assert(loadfile('Recommendations.lua'))('ForeverTrail',ft)
local rows,state=ft.GetQuestChain()
assert(state=='ok' and #rows==4 and rows[1].id==1 and rows[2].id==2 and rows[3].id==3 and rows[4].id==4, 'chain relations missing or incorrectly ordered')
assert(rows[1].chainStatus=='Tamamlandı' and rows[2].active and rows[3].chainStatus=='Alınabilir' and rows[4].chainStatus=='Kilitli', 'quest status incorrect')
ForeverTrailCharacter.lastAcceptedQuest=3
rows=ft.GetQuestChain()
assert(rows[3].id==3 and rows[3].chainCurrent, 'newly accepted quest must override history')
Questie=nil; ForeverTrailCharacter.lastAcceptedQuest=nil
rows,state=ft.GetQuestChain()
assert(#rows==0 and state=='noquest', 'must not guess the last quest')
print('Quest chain tests passed')
