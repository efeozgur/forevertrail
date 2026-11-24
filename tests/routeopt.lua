-- Rota sıralama (Guide/RouteOpt.lua): yakın durak önce, görev içi sıra korunur, konumsuz adımlar kaybolmaz
local ft = {}
assert(loadfile('Guide/RouteOpt.lua'))('ForeverTrail', ft)

-- çizgi üzerinde bir boyutlu mesafe; farklı harita çok uzak
local function dist(a, b)
 if a.map ~= b.map then return 4000 end
 return math.abs(a.x - b.x)
end
local function step(id, q, x, map) return {id = id, questId = q, uiMapID = x and (map or 1), x = x, y = x and 0 or nil} end
local function ids(list) local t = {} for i, s in ipairs(list) do t[i] = s.id end return table.concat(t, ',') end
local function opts() return {dist = dist} end

-- 1) yakın görev önce: A=0, B=100, C=10, D=110 → A, C, B, D
do
 local steps = {step('A', 1, 0), step('B', 2, 100), step('C', 3, 10), step('D', 4, 110)}
 local order, new, old = ft.RouteOrder(steps, {map = 1, x = 0, y = 0}, opts())
 assert(ids(order) == 'A,C,B,D', 'yakın görev önce gelmeli: ' .. ids(order))
 assert(new == 110 and old == 290, 'yol uzunlukları: ' .. new .. '/' .. old)
end

-- 2) en yakın komşunun yetmediği durum: yer değiştirme iyileştirmesi gerekir (62 → 49)
do
 local steps = {step('A', 1, 10), step('B', 2, -12), step('C', 3, 25)}
 local order, new = ft.RouteOrder(steps, {map = 1, x = 0, y = 0}, opts())
 assert(new == 49 and ids(order) == 'B,A,C', 'iyileştirme: ' .. ids(order) .. ' ' .. new)
end

-- 3) görev içi sıra korunur, farklı görevlerin durakları iç içe girer
do
 local steps = {step('Xa', 10, 0), step('Xt', 10, 100), step('Ya', 20, 5), step('Yt', 20, 95)}
 local order, new, old = ft.RouteOrder(steps, {map = 1, x = 0, y = 0}, opts())
 local at = {}
 for i, s in ipairs(order) do at[s.id] = i end
 assert(at.Xa < at.Xt and at.Ya < at.Yt, 'görev içi sıra bozulmamalı: ' .. ids(order))
 assert(new == 100 and old == 285, 'iç içe geçen rota: ' .. new .. '/' .. old)
 assert(ids(order) == 'Xa,Ya,Yt,Xt', 'iç içe sıra: ' .. ids(order))
end

-- 3b) kısıtsız en iyi sıra önceliği bozardı: teslim NPC'si başlangıca yakın, alma NPC'si uzak → önce almaya gidilir
do
 local steps = {step('Xa', 10, 100), step('Xt', 10, 0)}
 local order, new = ft.RouteOrder(steps, {map = 1, x = 0, y = 0}, opts())
 assert(ids(order) == 'Xa,Xt' and new == 200, 'teslim, almadan önce gelemez: ' .. ids(order) .. ' ' .. new)
end

-- 4) koordinatsız adım aynı görevin komşusundan konum ödünç alır; hiç konumu olmayan sona gider
do
 local steps = {step('Aa', 1, 0), step('Ao', 1, nil), step('At', 1, 50), step('M', nil, nil), step('B', 2, 5)}
 local order = ft.RouteOrder(steps, {map = 1, x = 0, y = 0}, opts())
 assert(#order == 5, 'hiçbir adım kaybolmamalı: ' .. #order)
 local at = {}
 for i, s in ipairs(order) do at[s.id] = i end
 assert(at.Aa < at.Ao and at.Ao < at.At, 'ödünç konumlu adım sırasını korumalı: ' .. ids(order))
 assert(order[#order].id == 'M', 'konumsuz adım sona: ' .. ids(order))
 assert(at.B < at.At, 'yakın B, uzak At\'tan önce: ' .. ids(order))
end

-- 5) başka haritadaki duraklar bir arada kalır; başlangıç noktası yoksa da çalışır
do
 local steps = {step('N1', 1, 5, 2), step('E1', 2, 0, 1), step('N2', 3, 6, 2), step('E2', 4, 1, 1)}
 local order = ft.RouteOrder(steps, {map = 1, x = 0, y = 0}, opts())
 assert(ids(order) == 'E1,E2,N1,N2', 'aynı haritadaki duraklar yan yana: ' .. ids(order))
 local order2 = ft.RouteOrder(steps, nil, opts())
 assert(#order2 == 4, 'başlangıçsız da çalışmalı')
end

-- 6) boş ve tek elemanlı girdiler
do
 local o, n = ft.RouteOrder({}, nil, opts())
 assert(#o == 0 and n == 0, 'boş liste')
 o = ft.RouteOrder({step('A', 1, 3)}, {map = 1, x = 0, y = 0}, opts())
 assert(#o == 1)
end
print('RouteOpt tests passed')
