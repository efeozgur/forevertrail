-- Öğrenen yol ağı: kayıt, bağlantı, A* rota, önbellek ve kayıt koşulları
local clock = 0
GetTime = function() return clock end
CreateFrame = function() return {SetScript = function() end} end
ForeverTrailSettings = {}
local ft = {}
assert(loadfile('Map/Roads.lua'))('ForeverTrail', ft)
assert(ft.RoadsRecord and ft.RoadRoute and ft.CurrentRoute and ft.RoadsTick, 'arayüz')

-- yürüyüş izi: (x1,y1) -> (x2,y2), 0.01 adımla
local function walk(map, x1, y1, x2, y2)
 local steps = math.max(math.abs(x2 - x1), math.abs(y2 - y1)) / 0.01
 for s = 0, steps do ft.RoadsRecord(map, x1 + (x2 - x1) * s / steps, y1 + (y2 - y1) * s / steps) end
end
local function len(points)
 local t = 0
 for i = 2, #points do t = t + math.sqrt((points[i][1] - points[i - 1][1]) ^ 2 + (points[i][2] - points[i - 1][2]) ^ 2) end
 return t
end

-- L biçimli yol: önce aşağı, sonra sağa
walk(1, 0.10, 0.10, 0.10, 0.80); walk(1, 0.10, 0.80, 0.90, 0.80)
local route = ft.RoadRoute(1, 0.10, 0.12, 0.90, 0.80, 3000, 2000)
assert(route and #route >= 3, 'L yolunda köşeli rota bulunmalı: ' .. tostring(route and #route))
assert(route[1][1] == 0.10 and route[1][2] == 0.12 and route[#route][1] == 0.90 and route[#route][2] == 0.80, 'rota oyuncudan hedefe uzanmalı')
for i = 2, #route - 1 do
 local p = route[i]
 assert(math.abs(p[1] - 0.10) < 0.02 or math.abs(p[2] - 0.80) < 0.02, 'ara noktalar yolun üzerinde olmalı: ' .. p[1] .. ',' .. p[2])
end
local straight = len({{0.10, 0.12}, {0.90, 0.80}})
assert(len(route) > straight * 1.1, 'rota düz çizgiden uzun (kıvrımlı) olmalı: ' .. len(route) .. ' / ' .. straight)

-- yola uzak başlangıç ya da hedef: rota yok
assert(ft.RoadRoute(1, 0.50, 0.50, 0.90, 0.80, 3000, 2000) == nil, 'yola uzak başlangıç için rota olmamalı')
assert(ft.RoadRoute(1, 0.10, 0.12, 0.60, 0.30, 3000, 2000) == nil, 'yola uzak hedef için rota olmamalı')
assert(ft.RoadRoute(99, 0.1, 0.1, 0.2, 0.2) == nil, 'bilinmeyen harita için rota olmamalı')

-- bağlantısız iki yol: biri diğerine bağlanamaz
ft.RoadsBreak()
walk(2, 0.10, 0.20, 0.30, 0.20); ft.RoadsBreak(); walk(2, 0.50, 0.20, 0.70, 0.20)
assert(ft.RoadRoute(2, 0.10, 0.20, 0.30, 0.20, 3000, 2000), 'aynı yol içinde rota bulunmalı')
assert(ft.RoadRoute(2, 0.10, 0.20, 0.70, 0.20, 3000, 2000) == nil, 'ayrı yollar arasında rota olmamalı')

-- zıplama (ışınlanma, hızlı yolculuk) bağlanmaz
ft.RoadsBreak(); ft.RoadsRecord(3, 0.10, 0.10); ft.RoadsRecord(3, 0.60, 0.60)
assert(ft.RoadRoute(3, 0.10, 0.10, 0.60, 0.60) == nil, 'uzak iki nokta bağlanmamalı')

-- önbellek: aynı çağrı aynı tabloyu verir, yeni yol öğrenilince yenilenir
local a = ft.CurrentRoute(1, 0.10, 0.12, 0.90, 0.80, 3000, 2000)
assert(a == ft.CurrentRoute(1, 0.10, 0.12, 0.90, 0.80, 3000, 2000), 'önbellek aynı rotayı döndürmeli')
walk(1, 0.90, 0.80, 0.90, 0.60)
assert(ft.CurrentRoute(1, 0.10, 0.12, 0.90, 0.80, 3000, 2000) ~= a, 'yeni yol öğrenilince rota yeniden hesaplanmalı')

-- kayıt koşulları: yalnızca yürürken, uçarken/binekteyken değil, ayar kapatılabilir
local pos = {0.2, 0.2}
C_Map = {GetBestMapForUnit = function() return 4 end, GetPlayerMapPosition = function() return {GetXY = function() return pos[1], pos[2] end} end}
local speed, taxi = 7, false
GetUnitSpeed = function() return speed end
UnitOnTaxi = function() return taxi end
local function nodes() local _, n = ft.RoadsStatus(); return n end
local before = nodes()
speed = 0; ft.RoadsTick(); assert(nodes() == before, 'durağanken kayıt olmamalı')
speed = 7; taxi = true; ft.RoadsTick(); assert(nodes() == before, 'uçuş yolunda kayıt olmamalı')
taxi = false; ForeverTrailSettings.roadsLearn = false; ft.RoadsTick(); assert(nodes() == before, 'ayar kapalıyken kayıt olmamalı')
ForeverTrailSettings.roadsLearn = nil; ft.RoadsTick(); assert(nodes() == before + 1, 'yürürken kayıt olmalı')
IsFlying = function() return true end; pos = {0.4, 0.4}; ft.RoadsTick(); assert(nodes() == before + 1, 'uçarken kayıt olmamalı')

-- Polestar_Nav arka ucu: sahte yönlendirici; arama eşzamansız, sonuç sonradan gelir
do
 local ww, wh = 3000, 2000
 -- dünya çerçevesi: x = 1000 * harita y, y = 1000 * harita x (UnitPosition: x kuzey, y batı gibi eksenler yer değiştirir)
 CreateVector2D = function(x, y) return {x = x, y = y, GetXY = function(self) return self.x, self.y end} end
 C_Map = {
  GetBestMapForUnit = function() return 7 end,
  GetPlayerMapPosition = C_Map.GetPlayerMapPosition,
  GetWorldPosFromMapPos = function(map, v) return 1, CreateVector2D(v.y * 1000, v.x * 1000) end,
  GetMapPosFromWorldPos = function(inst, v, map) return map, CreateVector2D(v.y / 1000, v.x / 1000) end,
 }
 local here = {0.20, 0.20}
 UnitPosition = function() return here[2] * 1000, here[1] * 1000, 0, 1 end
 UnitFactionGroup = function() return 'Alliance' end
 local asked, cancelled, pending, result = 0, 0, nil, nil
 Polestar_NavEngine = {
  Available = function(inst) return inst == 1 end,
  Cancel = function() cancelled = cancelled + 1 end,
  Find = function(inst, from, to, callback, opts)
   asked = asked + 1
   assert(inst == 1 and opts.walkLevel == 0 and opts.profile == 'Alliance', 'Find parametreleri')
   pending = function() callback(result, 100, {}) end
   return {}
  end,
 }
 ft.RoadsPolestarReset()
 -- kıvrımlı bir yol (harita 7): köşeli
 local function world(mx, my) return {x = my * 1000, y = mx * 1000} end
 result = {world(0.20, 0.20), world(0.20, 0.50), world(0.60, 0.50), world(0.80, 0.80)}

 -- ilk çağrı arar; sonuç gelene dek (öğrenilmiş yol yok) nil
 clock = 100
 assert(ft.CurrentRoute(7, 0.20, 0.20, 0.80, 0.80, ww, wh) == nil, 'sonuç gelmeden rota olmamalı')
 assert(asked == 1 and pending, 'ilk çağrı yönlendiriciyi sormalı')
 assert(ft.CurrentRoute(7, 0.20, 0.20, 0.80, 0.80, ww, wh) == nil and asked == 1, 'bekleyen aramada yeniden sorulmamalı')
 pending(); pending = nil
 local route = ft.CurrentRoute(7, 0.20, 0.20, 0.80, 0.80, ww, wh)
 assert(route and #route == 4, 'gelen yol çizilmeli: ' .. tostring(route and #route))
 assert(route[1][1] == 0.20 and route[1][2] == 0.20 and math.abs(route[4][1] - 0.80) < 1e-9 and math.abs(route[4][2] - 0.80) < 1e-9, 'oyuncudan hedefe')
 assert(ft.RoadsSource() == 'polestar', 'kaynak polestar olmalı')
 assert(asked == 1, 'yol geçerliyken yeniden sorulmamalı')

 -- yolda ilerleyince geride kalan noktalar atılır, ilk nokta oyuncu olur
 here = {0.20, 0.45}; clock = 101
 route = ft.CurrentRoute(7, 0.20, 0.45, 0.80, 0.80, ww, wh)
 assert(route[1][1] == 0.20 and route[1][2] == 0.45 and #route == 3, 'geride kalan nokta atılmalı: ' .. #route)

 -- yoldan uzaklaşınca (60 yd üstü) yeniden sorulur
 here = {0.40, 0.30}; clock = 110
 ft.CurrentRoute(7, 0.40, 0.30, 0.80, 0.80, ww, wh)
 assert(asked == 2 and cancelled == 0, 'yoldan uzaklaşınca yeniden sorulmalı: ' .. asked)

 -- yönlendirici yol bulamazsa: düz çizgiye düşülür ve 15 sn boyunca tekrar tekrar sorulmaz
 result = nil; pending(); pending = nil
 clock = 112
 assert(ft.CurrentRoute(7, 0.40, 0.30, 0.80, 0.80, ww, wh) == nil, 'bulunamayınca rota olmamalı')
 local before = asked
 clock = 118; ft.CurrentRoute(7, 0.40, 0.30, 0.80, 0.80, ww, wh)
 assert(asked == before, 'başarısız aramadan sonra 15 sn beklenmeli')
 clock = 140; ft.CurrentRoute(7, 0.40, 0.30, 0.80, 0.80, ww, wh)
 assert(asked == before + 1, 'beklemeden sonra yeniden sorulmalı')

 -- hedef değişince yeni arama; eski sonucun callback'i yok sayılır
 ft.RoadsPolestarReset(); asked = 0
 result = {world(0.20, 0.20), world(0.30, 0.30)}
 clock = 200; ft.CurrentRoute(7, 0.20, 0.20, 0.30, 0.30, ww, wh)
 local first = pending
 clock = 210; ft.CurrentRoute(7, 0.20, 0.20, 0.90, 0.90, ww, wh)
 assert(asked == 2, 'yeni hedef yeni arama başlatmalı')
 assert(cancelled >= 1, 'bekleyen eski arama iptal edilmeli')
 local second = pending
 result = {world(0.20, 0.20), world(0.90, 0.90)}
 second()
 first() -- eski aramanın sonucu geç gelir: yenisini ezmemeli
 assert(ft.CurrentRoute(7, 0.20, 0.20, 0.90, 0.90, ww, wh), 'yeni hedefin sonucu eskisinin geç gelmesiyle kaybolmamalı')

 -- kapatma ve yokluk
 ft.RoadsPolestarReset(); asked = 0
 ForeverTrailSettings.roadsPolestar = false; clock = 300
 ft.CurrentRoute(7, 0.20, 0.20, 0.80, 0.80, ww, wh)
 assert(asked == 0, 'roadsPolestar=false iken sorulmamalı')
 ForeverTrailSettings.roadsPolestar = nil
 InCombatLockdown = function() return true end
 ft.RoadsPolestarReset(); clock = 400
 ft.CurrentRoute(7, 0.20, 0.20, 0.80, 0.80, ww, wh)
 assert(asked == 0, 'savaşta sorulmamalı')
 InCombatLockdown = nil
 Polestar_NavEngine = nil; ft.RoadsPolestarReset(); clock = 500
 assert(ft.CurrentRoute(7, 0.20, 0.20, 0.80, 0.80, ww, wh) == nil and ft.RoadsSource() == nil, 'eklenti yokken sorunsuz nil')
end

print('Roads tests passed (' .. nodes() .. ' hücre)')
