-- Otopilot: rehberdeki görevler, atlama, bekleyen adımlar, uzaklaşınca yakına atlama, bölge önerisi
local clock = 100
GetTime = function() return clock end
ForeverTrailSettings = {auto = true}
ForeverTrailCharacter = {}
local level = 10
UnitLevel = function() return level end
InCombatLockdown = function() return false end
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end

-- görev günlüğü: id -> durum ('active' | 'ready' | 'done'); yoksa alınmamış
local log = {}
local logIndex = {}
C_QuestLog = {
 GetLogIndexForQuestID = function(id) return log[id] and log[id] ~= 'done' and (logIndex[id] or 1) or nil end,
 IsQuestFlaggedCompleted = function(id) return log[id] == 'done' end,
 IsComplete = function(id) return log[id] == 'ready' end,
}
-- oyuncu konumu: harita 1, 0-1 koordinat; dünya 1000x1000 yd
local player = {map = 1, x = 0.5, y = 0.5}
C_Map = {
 GetBestMapForUnit = function() return player.map end,
 GetPlayerMapPosition = function() return {GetXY = function() return player.x, player.y end} end,
 GetMapWorldSize = function() return 1000, 1000 end,
 GetMapInfo = function(map) return {parentMapID = map == 2 and 1 or nil} end,
}

local ft = {DBQ = {[1] = {'Bir', 1, 1, 1, 10}, [2] = {'Iki', 1, 1, 1, 10}, [3] = {'Uc', 1, 1, 1, 10}, [4] = {'Dort', 1, 1, 1, 10}, [9] = {'Yuksek', 1, 1, 40, 40}}}
assert(loadfile('Core/Engine.lua'))('ForeverTrail', ft)
assert(loadfile('Core/Quest.lua'))('ForeverTrail', ft)
ft.validGuides = {}
ft.SaveStep = function() end
ft.Refresh = function() end
ft.AtLocation = function() return false end
ft.ready = true
assert(loadfile('Guide/AutoPilot.lua'))('ForeverTrail', ft)

local function step(id, type, quest, x, y) return {stepId = id, type = type, questId = quest, text = id, uiMapID = 1, x = x, y = y} end
local function guide(steps) return {guideId = 'g', version = 1, title = 'G', zone = 'Z', steps = steps} end
local function use(g) ft.guide = g; ft.active, ft.view, ft.complete = 1, 1, false; ft.notice = nil; ForeverTrailCharacter.skipped = nil; ft.AutoPilotReset() end

-- 1) rehberdeki görevler: kısıt yalnızca hazır rehberde; canlı günlükte kısıt yok
use(guide({step('a1', 'accept', 1, .1, .1), step('t1', 'turnin', 1, .1, .1), step('a2', 'accept', 2, .2, .2)}))
assert(ft.GuideAllows(1, 'accept') == true and ft.GuideAllows(1, 'turnin') == true, 'rehber görevi izinli')
assert(ft.GuideAllows(2, 'turnin') == false, 'rehberde yalnızca alınan görev teslim için izinli değil')
assert(ft.GuideAllows(77, 'accept') == false, 'rehber dışı görev izinsiz')
assert(ft.GuideAllows(nil, 'accept') == false, 'kimliği bilinmeyen görev izinsiz')
assert(ft.GuideAllowsTitle('Bir', 'accept') == true and ft.GuideAllowsTitle('Baska', 'accept') == false, 'başlıkla eşleşme')
ft.guide.live = true; assert(ft.GuideAllows(77, 'accept') == nil, 'canlı günlükte kısıt olmamalı')
ft.guide.live = nil
ForeverTrailSettings.autoquestAll = true; assert(ft.GuideAllows(77, 'accept') == nil, 'autoquestAll açıkken kısıt olmamalı'); ForeverTrailSettings.autoquestAll = nil
ft.guide = nil; assert(ft.GuideAllows(1, 'accept') == nil, 'rehber yokken kısıt olmamalı')

-- 2) Atla: yapılmamış adım atlandı sayılır, tamamlanan (otomatik) sayılmaz
local g = guide({step('a1', 'accept', 1, .1, .1), step('a2', 'accept', 2, .2, .2), step('a3', 'accept', 3, .3, .3)})
use(g); ft.Advance()
assert(ft.active == 2 and ForeverTrailCharacter.skipped['g:a1'], 'elle ilerletilen yapılmamış adım atlandı olmalı')
log[2] = 'active'; ft.Advance(true)
assert(not ForeverTrailCharacter.skipped['g:a2'], 'otomatik ilerleme adımı atlandı saymamalı')
log[2] = nil

-- 3) bekleyen adım: rehber bitmeden yapılabilir geride kalan adıma dön; atlananlara dönme
use(guide({step('a1', 'accept', 1, .1, .1), step('a2', 'accept', 2, .2, .2), step('a3', 'accept', 3, .3, .3)}))
ft.active = 3; log[3] = 'active'   -- 3. adımdaki görev alındı; 1. ve 2. adım hâlâ yapılabilir
ft.Advance(true)
assert(not ft.complete and ft.active == 1, 'rehber bitince yapılabilir ilk geri kalan adıma dönülmeli: active=' .. ft.active .. ' complete=' .. tostring(ft.complete))
ForeverTrailCharacter.skipped = {['g:a1'] = true, ['g:a2'] = true}
ft.active = 3; ft.complete = false; ft.Advance(true)
assert(ft.complete, 'atlananlara dönülmemeli, rehber tamamlanmalı')
-- yapılamayan adım (seviye yetmiyor) bekleyen sayılmaz
use(guide({step('a9', 'accept', 9, .1, .1), step('a1', 'accept', 1, .1, .1)}))
ft.active = 2; log[1] = 'active'; ft.Advance(true)
assert(ft.complete, 'seviyesi yetmeyen görev bekleyen sayılmamalı')
-- ön koşulu sağlanmamış görev bekleyen sayılmaz; sağlanınca sayılır
ft.DBQ[5] = {'Bes', 1, 1, 1, 10, nil, nil, nil, nil, {3}}
use(guide({step('a5', 'accept', 5, .1, .1), step('a1', 'accept', 1, .1, .1)}))
ft.active = 2; log[1] = 'active'; ft.Advance(true)
assert(ft.complete, 'ön koşulu (3. görev) teslim edilmemiş görev bekleyen sayılmamalı')
use(guide({step('a5', 'accept', 5, .1, .1), step('a1', 'accept', 1, .1, .1)}))
ft.active = 2; log[3] = 'done'; ft.Advance(true)
assert(not ft.complete and ft.active == 1, 'ön koşulu tamamlanınca görev bekleyen olmalı')
log = {}
-- hedefi için gereken eşya (başka görevden gelen) çantada yoksa hedef adımı bekleyen sayılmaz (boşa gitme); eşya gelince sayılır
ft.QuestRequirements = function() return {{kind = 'item'}} end
use(guide({step('o1', 'objective', 1, .1, .1), step('a2', 'accept', 2, .2, .2)}))
ft.active = 2; log[1] = 'active'; log[2] = 'active'; ft.Advance(true)
assert(ft.complete, 'eşyası eksik hedef adımı bekleyen sayılmamalı')
ft.QuestRequirements = function() return {} end
use(guide({step('o1', 'objective', 1, .1, .1), step('a2', 'accept', 2, .2, .2)}))
ft.active = 2; log[1] = 'active'; log[2] = 'active'; ft.Advance(true)
assert(not ft.complete and ft.active == 1, 'eşya tamamsa hedef adımı bekleyen sayılmalı: active=' .. ft.active)
ft.QuestRequirements = nil; log = {}

-- 4) uzaklaşınca yakındaki yapılabilir adıma atla
local steps = {step('a1', 'accept', 1, .10, .10), step('a2', 'accept', 2, .90, .90), step('a3', 'accept', 3, .12, .10)}
use(guide(steps)); ft.active = 2; ft.view = 2
player.x, player.y = .11, .10                     -- 1. adımın yanındayım, şimdiki adım (2) 1100 yd uzakta
assert(ft.AutoPilotStep(clock) == 1, 'yakındaki yapılabilir adıma atlanmalı')
assert(ft.active == 1 and ft.view == 1 and ft.notice, 'atlama sonrası etkin adım ve bildirim')
-- hız sınırı: hemen ardından tekrar atlamaz
ft.active, ft.view = 2, 2
assert(ft.AutoPilotStep(clock + 5) == nil and ft.active == 2, 'atlamalar arası bekleme olmalı')
assert(ft.AutoPilotStep(clock + 20) == 1, 'bekleme sonrası yeniden atlanabilmeli')
-- şimdiki adıma yakınsam atlamam
use(guide(steps)); ft.active = 2; player.x, player.y = .88, .90
assert(ft.AutoPilotStep(clock + 100) == nil and ft.active == 2, 'şimdiki adıma yakınken atlama olmamalı')
-- şimdiki adım uzak ama STRAY'in içindeyse (rehber sırası izlenir) yakındaki adıma atlama
use(guide({step('a1', 'accept', 1, .10, .10), step('a2', 'accept', 2, .40, .10), step('a3', 'accept', 3, .90, .90)})); ft.active = 2
player.x, player.y = .11, .10
assert(ft.AutoPilotStep(clock + 150) == nil and ft.active == 2, 'şimdiki adım 290 yd uzaktayken (<400) rehber sırası izlenmeli')
-- yakındaki adım yapılamıyorsa (günlükte zaten var) atlamam
use(guide(steps)); ft.active = 2; player.x, player.y = .11, .10; log[1] = 'active'
assert(ft.AutoPilotStep(clock + 200) == 3, 'günlükte zaten olan görevin alma adımına değil, yapılabilir yakındaki adıma (3) atlanmalı')
log = {}
-- ayarlar kapatır
use(guide(steps)); ft.active = 2; player.x, player.y = .11, .10
ForeverTrailSettings.autopilot = false; assert(ft.AutoPilotStep(clock + 400) == nil, 'autopilot=false atlamamalı'); ForeverTrailSettings.autopilot = nil
ForeverTrailSettings.auto = false; assert(ft.AutoPilotStep(clock + 400) == nil, 'otomatik ilerleme kapalıyken atlamamalı'); ForeverTrailSettings.auto = true
InCombatLockdown = function() return true end; assert(ft.AutoPilotStep(clock + 400) == nil, 'savaşta atlamamalı'); InCombatLockdown = function() return false end
-- başka haritadayım: yakın adım yok -> atlama yok
player.map = 5; assert(ft.AutoPilotStep(clock + 400) == nil, 'başka haritada atlama olmamalı'); player.map = 1

-- 5) bölge önerisi
local windows = {}
ft.AutoGuide = {Zones = function(map) local out = {}; for _, z in ipairs(windows) do if z.map == map then out[#out + 1] = z end end return out end,
 Select = function(map, lo, hi) ft.selected = {map, lo, hi}; ft.guide = {guideId = ('auto-%d-%d-%d'):format(map, lo, hi), auto = true, steps = {{stepId = 'x', type = 'manual', text = 'x'}}}; return true end}
local asked
ft.ShowChoice = function(title, icon, text, accept, onAccept, onDecline) asked = {title = title, text = text, accept = onAccept, decline = onDecline}; return true end
windows = {{map = 1, name = 'Darkshore', lo = 10, hi = 20, count = 50, steps = 150, key = '1:10:20', recommended = true},
 {map = 1, name = 'Darkshore', lo = 21, hi = 30, count = 90, steps = 200, key = '1:21:30', recommended = false}}
ft.guide = {guideId = 'character-log', live = true, steps = {{stepId = 'w', type = 'manual', text = 'w'}}}
ft.complete = false
assert(ft.SuggestGuide() == 'asked' and asked and asked.text:find('Darkshore') and asked.text:find('10%-20'), 'canlı günlükteyken öneri sorulmalı')
assert(not asked.text:find('21'), 'seviyene uymayan pencere önerilmemeli')
asked.accept()
assert(ft.selected and ft.selected[1] == 1 and ft.selected[2] == 10, 'onaylayınca rehber seçilmeli')
assert(ForeverTrailSettings.dockTab == 'guide', 'onaylayınca Rehber sekmesi açılmalı')
-- aynı pencerenin rehberindeyken sormaz
asked = nil; assert(ft.SuggestGuide() == nil and asked == nil, 'zaten o rehberdeyken sorulmamalı')
-- reddedince bu oturumda sormaz; iki ret kalıcı olur
ft.guide = {guideId = 'character-log', live = true, steps = {{stepId = 'w', type = 'manual', text = 'w'}}}
ft.SuggestGuide(); asked.decline(); asked = nil
assert(ft.SuggestGuide() == nil and asked == nil, 'reddedilince aynı oturumda tekrar sorulmamalı')
ft.SuggestGuideReset(); ft.SuggestGuide(); asked.decline(); ft.SuggestGuideReset(); asked = nil
assert(ft.SuggestGuide() == nil and asked == nil, 'iki ret sonrası kalıcı olarak sorulmamalı')
ForeverTrailCharacter.guideDeclines = nil; ft.SuggestGuideReset()
-- hazır (canlı olmayan, otomatik olmayan) rehber sürerken rahatsız etmez
ft.guide = {guideId = 'elle', steps = {{stepId = 'w', type = 'manual', text = 'w'}}}; asked = nil
assert(ft.SuggestGuide() == nil and asked == nil, 'elle seçilmiş rehber sürerken önerilmemeli')
-- ayar kapatır, savaşta ve başka pencere açıkken
ft.guide = {guideId = 'character-log', live = true, steps = {{stepId = 'w', type = 'manual', text = 'w'}}}
ForeverTrailSettings.guideSuggest = false; assert(ft.SuggestGuide() == nil, 'guideSuggest=false sormamalı'); ForeverTrailSettings.guideSuggest = nil
ft.ShowChoice = function() return false end; assert(ft.SuggestGuide() == 'busy', 'başka pencere açıkken ertelenmeli')
ft.ShowChoice = function(...) asked = {accept = select(5, ...)}; return true end
-- alt bölgedeyken üst harita için öner (harita 2'nin üstü harita 1)
player.map = 2; ft.SuggestGuideReset(); asked = nil
assert(ft.SuggestGuide() == 'asked', 'alt bölgedeyken üst bölgenin rehberi önerilmeli')

print('AutoPilot tests passed')
