-- Görev gereksinimleri: ön koşul görevler (gerçek duruma göre), başka görevden gelen eşya, yönlendirme ve yola çıkarken uyarı
local clock = 0
GetTime = function() return clock end
local done, logged, bag, completeQ = {}, {}, {}, {}
C_QuestLog = {
 IsQuestFlaggedCompleted = function(id) return done[id] or false end,
 GetLogIndexForQuestID = function(id) return logged[id] and 1 or 0 end,
 IsComplete = function(id) return completeQ[id] or false end,
}
GetItemCount = function(id) return bag[id] or 0 end
ForeverTrailSettings = {}
-- çanta olayı için küçük bir çerçeve benzetimi: kayıt edilen OnEvent betiği testten tetiklenir; zamanlayıcı hemen çalışır
local bagFrame
CreateFrame = function() local f = {scripts = {}, RegisterEvent = function() end}; f.SetScript = function(self, k, fn) self.scripts[k] = fn end; bagFrame = f; return f end
C_Timer = {After = function(_, fn) fn() end}

local ft = {turnedIn = {}}
-- görev satırı: [4]=gereken seviye, [5]=seviye, [9]=hedefler, [10]=ön koşul grubu (hepsi), [11]=ön koşul (biri), [19]=alınca verilen eşya
local function Q(name, f)
 local t = {name, 1, 1, 1, f.lvl or 1}
 t[9], t[10], t[11], t[19] = f.obj, f.grp, f.one, f.src
 return t
end
ft.DBQ = {
 [1] = Q('Zincirin başı', {}),
 [2] = Q('Zincirin ikinci halkası', {grp = {1}}),         -- 1 yapılmalı (grup: hepsi)
 [3] = Q('İki yoldan biri', {one = {1, 7}}),               -- 1 ya da 7 yeterli (tekli)
 [4] = Q('Eşya isteyen görev', {obj = {nil, nil, {{900}}}}), -- hedef: 900 numaralı eşya (ödül olarak gelir)
 [5] = Q('Eşya veren görev', {src = 901}),                  -- görevi alınca 901 verir
 [6] = Q('Eşya isteyen görev 2', {obj = {nil, nil, {{901}}}}), -- hedef: 901 (görev 5 verir)
 [7] = Q('Alternatif başı', {}),
 [8] = Q('Düşen eşya isteyen', {obj = {nil, nil, {{902}}}}), -- 902 yaratıktan düşer: uyarı yok
 [9] = Q('Ödülle eşya veren', {}),
 [10] = Q('Tahta görevi', {}), [11] = Q('Eşya görevi', {}), [12] = Q('Bölge görevi', {}),
 [13] = Q('Tahtayı isteyen', {grp = {10}}), [14] = Q('Eşyayı isteyen', {grp = {11}}), [15] = Q('Bölgeyi isteyen', {grp = {12}}),
 [16] = Q('Mektup görevi', {}), [17] = Q('Mektubu isteyen', {grp = {16}}), -- 16: eşyayla başlar, eşya bir zindan patronundan düşer
}
ft.DBI = {
 [900] = {'Kayıp Mühür', nil, nil, nil, {9}},   -- npcDrops yok, görev 9'un ödülü
 [901] = {'Gizli Anahtar'},                      -- görev 5 verir
 [902] = {'Kurt Postu', {123}, nil, nil, {9}},       -- yaratıktan düşer (ödül de olabilir ama düşme kaynağı varken uyarı gereksiz)
}
ft.QuestTitle = function(id) return ft.DBQ[id] and ft.DBQ[id][1] or ('Görev ' .. id) end
ft.StepNpc = function(step) return (step.type == 'accept' and step.questId ~= 11 and step.questId ~= 12 and step.questId ~= 16) and ('Veren' .. step.questId) or nil end
ft.QuestGiverName = function(id) return id == 10 and 'Old Footlocker' or nil end                -- 10: nesneyle başlar
ft.QuestStartItem = function(id) return (id == 11 and {itemId = 800, name = 'Pençe'}) or (id == 16 and {itemId = 801, name = 'Mektup'}) or nil end   -- 11, 16: eşyayla başlar
ft.QuestZoneName = function(id) return (id == 12 and 'Durotar') or (id == 16 and 'Stormwind') or nil end   -- 12: yalnız bölge bilinir; 16: görevin teslim bölgesi
ft.TurnInName = function(id) return 'Teslimci' .. id end
ft.QuestSpot = function(id, kind) if id == 12 or id == 16 then return nil end return {map = 1, x = 0.1 * id, y = 0.2, text = 'Elwynn · ' .. id .. (kind == 'turnin' and ' (teslim)' or ' (al)')} end
local boss = {}; boss[1] = 'Patron'; boss[7] = 1581 -- NPC satırı: [1]=ad, [7]=bölge
ft.DBI[801] = {'Mektup', {101}}
ft.DBN = {[101] = boss}
ft.DBDungeons = {[1581] = {'The Deadmines'}}
assert(loadfile('Guide/Requirements.lua'))('ForeverTrail', ft)

local function kinds(list) local out = {} for i, e in ipairs(list) do out[i] = e.kind .. ':' .. (e.itemId or e.questId) end return table.concat(out, ',') end
local function fresh() clock = clock + 100 end

-- ön koşul yok / hepsi tamam: boş
assert(#ft.QuestRequirements(1) == 0, 'ön koşulsuz görev')
done[1] = true; fresh()
assert(#ft.QuestRequirements(2) == 0, 'ön koşul yapılmışsa uyarı yok')
done[1] = false; fresh()

-- grup ön koşulu: eksik görev, nerede alınır
local r2 = ft.QuestRequirements(2)
assert(#r2 == 1 and r2[1].kind == 'quest' and r2[1].questId == 1, 'eksik ön koşul görevi: ' .. kinds(r2))
assert(r2[1].text == 'Önce görev: Zincirin başı' and r2[1].detail == 'Görevi al: Veren1', 'metin: ' .. r2[1].text .. ' / ' .. r2[1].detail)
assert(r2[1].place and r2[1].where == 'Elwynn · 1 (al)', 'yer bilgisi: ' .. tostring(r2[1].where))

-- ön koşul günlükte (alınmış ama bitmemiş): nerede teslim edilecek
logged[1] = true; fresh()
r2 = ft.QuestRequirements(2)
assert(r2[1].logged and r2[1].detail:find('Teslimci1') and r2[1].where == 'Elwynn · 1 (teslim)', 'günlükteki ön koşul teslim yeriyle: ' .. r2[1].detail)
logged[1] = false; fresh()

-- tekli ön koşul: seçeneklerden biri yeter; biri yapıldıysa uyarı yok, yoksa tek öneri ve "başka N görev"
local r3 = ft.QuestRequirements(3)
assert(#r3 == 1 and r3[1].questId == 1 and r3[1].alternatives == 1, 'tekli ön koşul: ilk seçenek + 1 alternatif: ' .. kinds(r3))
done[7] = true; fresh()
assert(#ft.QuestRequirements(3) == 0, 'alternatiflerden biri yapıldıysa uyarı yok')
done[7] = false; logged[7] = true; fresh()
assert(ft.QuestRequirements(3)[1].questId == 7, 'günlükte olan seçenek öne çıkar')
logged[7] = false; fresh()

-- zaten günlükte olan görevin ön koşulu aranmaz (alınmış demek ki sağlanmış)
logged[2] = true; fresh()
assert(#ft.QuestRequirements(2) == 0, 'günlükteki görevde ön koşul uyarısı yok')
logged[2] = false; fresh()

-- hedef eşyası başka görevin ödülü: çantada yoksa uyar, varsa uyarma
local r4 = ft.QuestRequirements(4)
assert(#r4 == 1 and r4[1].kind == 'item' and r4[1].itemId == 900 and r4[1].questId == 9 and r4[1].how == 'ödül', 'ödül eşyası: ' .. kinds(r4))
assert(r4[1].text == 'Eşya gerekli: Kayıp Mühür' and r4[1].detail:find('Ödülle eşya veren', 1, true) and r4[1].detail:find('ödül', 1, true), 'eşya metni: ' .. r4[1].detail)
bag[900] = 1; fresh()
assert(#ft.QuestRequirements(4) == 0, 'eşya çantada: uyarı yok')
bag[900] = 0; done[9] = true; fresh()
assert(#ft.QuestRequirements(4) == 0, 'eşyayı veren görev yapılmışsa (eşya tüketilmiş olabilir) uyarı yok')
done[9] = false; fresh()

-- görevi alınca verilen eşya
local r6 = ft.QuestRequirements(6)
assert(#r6 == 1 and r6[1].itemId == 901 and r6[1].questId == 5 and r6[1].how == 'verir' and r6[1].detail:find('görevi alınca verilir', 1, true), 'alınca verilen eşya: ' .. kinds(r6))
-- günlükte olan görevde de eşya uyarısı sürer (kullanıcının yaşadığı durum: görevi aldı, eşya gerekiyormuş)
logged[6] = true; fresh()
assert(#ft.QuestRequirements(6) == 1, 'günlükteki görevde eşya uyarısı devam eder')
logged[6] = false; fresh()

-- yaratıktan düşen eşya normaldir: uyarı yok
assert(#ft.QuestRequirements(8) == 0, 'düşen eşyada uyarı yok')

-- teslim edilmiş görev, kimliksiz çağrı
done[4] = true; fresh()
assert(#ft.QuestRequirements(4) == 0, 'teslim edilmiş görevde uyarı yok')
assert(#ft.QuestRequirements(nil) == 0 and #ft.QuestRequirements(99999) == 0, 'bilinmeyen görev boş liste')
done[4] = false

-- yönlendirme: bağlantılı görevin NPC'sine özel hedef
local target
ft.SetCustomTarget = function(map, x, y, name, silent) target = {map = map, x = x, y = y, name = name} end
fresh()
assert(ft.GoToRequirement(ft.QuestRequirements(2)[1]) == true and target.map == 1 and target.name == 'Veren1', 'rota bağlantılı görevin NPC\'sine')
assert(ft.GoToRequirement({title = 'yersiz'}) == false and ft.GoToRequirement(nil) == false, 'yeri yoksa yönlendirme yok')

-- yola çıkarken uyarı: etkin adımın görevinde eksik varsa bir kez (görev başına) açılır
local popups = {}
ft.ShowChoice = function(title, icon, text, acceptText, onAccept) popups[#popups + 1] = {title = title, text = text, accept = acceptText, onAccept = onAccept}; return true end
ft.guide = {guideId = 'g', steps = {{stepId = 'a2', type = 'accept', questId = 2, questTitle = 'x'}, {stepId = 'a1', type = 'accept', questId = 1}, {stepId = 'o6', type = 'objective', questId = 6}, {stepId = 'l', type = 'location'}}}
ft.view, ft.active = 1, 1; fresh()
ft.StepRequirementWarning()
assert(#popups == 1 and popups[1].text:find('Zincirin ikinci halkası', 1, true) and popups[1].text:find('Önce görev: Zincirin başı', 1, true), 'ön koşul uyarısı açılmalı')
assert(popups[1].accept == 'Gerekene git', 'düğme yönlendirir')
target = nil; popups[1].onAccept(); assert(target and target.name == 'Veren1', 'düğme rotayı çizer')
ft.StepRequirementWarning(); assert(#popups == 1, 'aynı adım için tekrar açılmaz')
ft.view, ft.active = 2, 2; ft.StepRequirementWarning(); assert(#popups == 1, 'gereksinimi olmayan adımda uyarı yok')
ft.view, ft.active = 1, 1; ft.StepRequirementWarning(); assert(#popups == 1, 'aynı görev oturumda ikinci kez uyarılmaz')
ft.view, ft.active = 3, 3; fresh(); ft.StepRequirementWarning()
assert(#popups == 2 and popups[2].text:find('Eşya gerekli: Gizli Anahtar', 1, true), 'hedef adımında eşya uyarısı')
ft.view, ft.active = 4, 4; ft.StepRequirementWarning(); assert(#popups == 2, 'görevsiz adımda uyarı yok')
-- gözden geçirme (inceleme) modunda uyarı çıkmaz; ayar kapalıyken de çıkmaz
ft.guide.steps[5] = {stepId = 'a3', type = 'accept', questId = 3}
ft.view, ft.active = 5, 4; ft.StepRequirementWarning(); assert(#popups == 2, 'inceleme modunda uyarı yok')
ForeverTrailSettings.reqWarn = false; ft.view, ft.active = 5, 5; ft.StepRequirementWarning(); assert(#popups == 2, 'ayar kapalıyken uyarı yok')
ForeverTrailSettings.reqWarn = nil
-- pencere açıksa (ShowChoice false) sonra yeniden denenir, uyarılmış sayılmaz
ft.ShowChoice = function() return false end
ft.view, ft.active = 5, 5; fresh(); ft.guide.steps[5].stepId = 'a3b'; ft.StepRequirementWarning()
ft.ShowChoice = function(title, icon, text) popups[#popups + 1] = {text = text, accept = 'x'}; return true end
ft.guide.steps[5].stepId = 'a3c'; ft.StepRequirementWarning()
assert(#popups == 3, 'ilk deneme pencere açıkken kaçarsa sonraki adım değişiminde yine uyarılır: ' .. #popups)

-- bağlantılı görevin nasıl alınacağı: nesne, eşya, yalnız bölge
fresh()
local r13 = ft.QuestRequirements(13)
assert(r13[1].detail == 'Görevi al: Old Footlocker' and r13[1].npc == 'Old Footlocker' and r13[1].place, 'nesneyle başlayan: nesnenin adı ve yeri: ' .. r13[1].detail)
local r14 = ft.QuestRequirements(14)
assert(r14[1].detail == 'Eşyayla başlar: Pençe (düştüğü yerler)' and r14[1].startItem == 'Pençe' and r14[1].place, 'eşyayla başlayan: eşya adı ve düştüğü yerler: ' .. r14[1].detail)
local r15 = ft.QuestRequirements(15)
assert(r15[1].place == nil and r15[1].where == 'Durotar (tam konum verisi yok)' and r15[1].detail == 'Önce bu görevi al', 'tam nokta yoksa bölge yazılır: ' .. tostring(r15[1].where))
assert(ft.GoToRequirement(r15[1]) == false, 'tam nokta yoksa rota çizilmez')

-- eşyayla başlayan önkoşul: eşya çantaya girince "hazır" olur (uyarı sayılmaz), çıkınca uyarı geri gelir
fresh(); bag[800] = 0
local r14b = ft.QuestRequirements(14)
assert(#r14b == 1 and not r14b[1].ready and r14b[1].place and r14b[1].detail:find('düştüğü yerler', 1, true), 'eşya yokken: eksik uyarı ve düştüğü yerler')
assert(#ft.UnmetRequirements(14) == 1, 'eksik olan uyarı sayılır')
bag[800] = 1; fresh()
r14b = ft.QuestRequirements(14)
assert(#r14b == 1 and r14b[1].ready == true and r14b[1].place == nil and r14b[1].where == nil, 'eşya çantada: hazır, yer gerekmez')
assert(r14b[1].detail == 'Eşyan çantanda: Pençe — sağ tıkla, görevi başlat', 'hazır metni: ' .. r14b[1].detail)
assert(#ft.UnmetRequirements(14) == 0, 'hazır olan eksik sayılmaz (liste rozeti ve açılır uyarı çıkmaz)')
bag[800] = 0; fresh()
assert(#ft.UnmetRequirements(14) == 1, 'eşya gidince uyarı geri gelmeli')

-- günlükteki önkoşul görevi bittiyse yalnızca teslim kalmıştır: hazır
logged[1] = true; fresh()
local r2c = ft.QuestRequirements(2)
assert(r2c[1].logged and not r2c[1].ready and #ft.UnmetRequirements(2) == 1, 'günlükte ama bitmemiş: eksik')
completeQ[1] = true; fresh()
r2c = ft.QuestRequirements(2)
assert(r2c[1].ready and r2c[1].detail == 'Hazır: teslim et → Teslimci1' and #ft.UnmetRequirements(2) == 0, 'hedefleri bitmiş: hazır, yalnızca teslim: ' .. r2c[1].detail)
logged[1], completeQ[1] = false, nil

-- açılır uyarı yalnızca gerçekten eksik olanlar için çıkar
local before = #popups
ft.guide = {guideId = 'g2', steps = {{stepId = 'a14-hazir', type = 'accept', questId = 14}}}
ft.view, ft.active = 1, 1; bag[800] = 1; fresh(); ft.StepRequirementWarning()
assert(#popups == before, 'eşya çantadayken (hazır) uyarı açılmamalı')
ft.guide.steps[1].stepId = 'a14-eksik'; bag[800] = 0; fresh(); ft.StepRequirementWarning()
assert(#popups == before + 1 and popups[#popups].text:find('Eşyayla başlar', 1, true) == nil and popups[#popups].text:find('Önce görev', 1, true), 'eşya yokken uyarı açılır')

-- çantada izlenen eşya değişince önbellek atılır ve ekranlar kendiliğinden yenilenir (başka olay beklenmez)
bag[800] = 0; fresh()
assert(ft.QuestRequirements(14)[1].ready == nil, 'başlangıç: eksik')
local refreshed = 0
ft.Refresh = function() refreshed = refreshed + 1 end
ft.RefreshTracker, ft.RefreshAvailableBox = ft.Refresh, ft.Refresh
assert(ft.RequirementsBagChanged() == false and refreshed == 0, 'eşya sayısı değişmediyse yenileme yok')
bag[800] = 1 -- saat ilerlemedi: önbellek süresi dolmadı, yine de güncellenmeli
assert(ft.QuestRequirements(14)[1].ready == nil, 'önbellek süresi dolmadan eski sonuç döner (olay gelmeden)')
bagFrame.scripts.OnEvent()
assert(refreshed == 3, 'çanta olayı: Rehber, takip ve alınabilir kutusu bir kez yenilenmeli: ' .. refreshed)
assert(ft.QuestRequirements(14)[1].ready == true, 'olaydan sonra (saat ilerlemeden) hazır görünmeli')
bagFrame.scripts.OnEvent(); assert(refreshed == 3, 'aynı sayı: tekrar yenileme yok')
-- hedef eşyası (başka görevden gelen) de izlenir: çantaya girince uyarı hemen kalkar, çıkınca geri gelir
bag[900] = 0; fresh()
assert(#ft.QuestRequirements(4) == 1, 'hedef eşyası yokken uyarı')
bag[900] = 1; bagFrame.scripts.OnEvent()
assert(#ft.QuestRequirements(4) == 0, 'eşya çantaya girince uyarı hemen kalkmalı (olay gelince)')
bag[900] = 0; bagFrame.scripts.OnEvent()
assert(#ft.QuestRequirements(4) == 1, 'eşya çantadan çıkınca uyarı geri gelmeli')
bag[800] = 0

-- eşya numarası veritabanında ve oyunda farklıysa (Forever / Questie ayrışması) çanta adla da taranır
local slots = {}
C_Container = {
 GetContainerNumSlots = function(bagId) return bagId == 0 and 3 or 0 end,
 GetContainerItemInfo = function(bagId, slot) return slots[slot] end,
}
bag[900] = 0; slots = {}; fresh()
assert(#ft.QuestRequirements(4) == 1, 'çantada yok: uyarı')
slots = {[2] = {hyperlink = '|cffffffff|Hitem:99999:0|h[Kayıp Mühür]|h|r'}} -- aynı ad, FARKLI numara
fresh()
assert(#ft.QuestRequirements(4) == 0, 'numara farklı olsa da çantadaki aynı adlı eşya sayılmalı (uyarı gitmeli)')
slots = {[2] = {hyperlink = '|cffffffff|Hitem:99999:0|h[Başka Eşya]|h|r'}}; fresh()
assert(#ft.QuestRequirements(4) == 1, 'adı farklı eşya sayılmaz')
-- çanta olayında da aynı yedek kullanılır
slots = {}; bag[900] = 0; fresh(); ft.QuestRequirements(4)
local refreshed2 = 0; ft.Refresh = function() refreshed2 = refreshed2 + 1 end
slots = {[1] = {hyperlink = '|Hitem:99999:0|h[Kayıp Mühür]|h'}}
assert(ft.RequirementsBagChanged() == true and refreshed2 >= 1 and #ft.QuestRequirements(4) == 0, 'adla bulunan eşya da çanta değişimi olarak algılanmalı')
slots = {}; C_Container = nil

-- tanı çıktısı (/ftrail gereksinim): neden uyarı çıktığını gösterir
bag[900] = 0; fresh()
local lines = ft.RequirementsDebug(4)
local joined = table.concat(lines, '\n')
assert(joined:find('Görev 4', 1, true) and joined:find('hedef eşyası 900 "Kayıp Mühür"', 1, true) and joined:find('çantada(numarayla)=0', 1, true) and joined:find('Gereksinimler (1)', 1, true), 'tanı satırları: ' .. joined)
assert(ft.RequirementsDebug(nil)[1]:find('görev numarası ver', 1, true) or ft.RequirementsDebug(nil)[1]:find('Görev', 1, true), 'görev yoksa yönlendirme')
assert(#ft.RequirementsDebug(99999) >= 2, 'veritabanında olmayan görevde de çıktı verir')

-- eşyayla başlayan önkoşul, eşya bir zindan patronundan düşüyorsa: kimden, hangi zindan (görevin teslim bölgesi "yer" gibi gösterilmez)
fresh(); bag[801] = 0
local r17 = ft.QuestRequirements(17)
assert(#r17 == 1 and r17[1].kind == 'quest' and r17[1].dungeon == 'The Deadmines', 'zindan bilgisi: ' .. tostring(r17[1] and r17[1].dungeon))
assert(r17[1].detail == 'Eşyayla başlar: Mektup · düşer: Patron (The Deadmines zindanı)', 'zindan metni: ' .. r17[1].detail)
assert(r17[1].where == nil and r17[1].place == nil, 'görevin teslim bölgesi (Stormwind) eşyanın yeri gibi gösterilmemeli: ' .. tostring(r17[1].where))
-- eşya çantaya girince yine hazır olur (zindan metni yerini "çantanda" metnine bırakır)
bag[801] = 1; fresh()
r17 = ft.QuestRequirements(17)
assert(r17[1].ready and r17[1].detail:find('Eşyan çantanda: Mektup', 1, true) and r17[1].dungeon == nil, 'eşya alınınca hazır')
bag[801] = 0

print('Requirements tests passed')
