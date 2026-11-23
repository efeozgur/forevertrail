-- ForeverTrail_Nav* (Polestar_Nav'ın değiştirilmiş GPL kopyası): bütünlük, bağımsızlık, atıf ve yükleme
local function read(path)
 local f = assert(io.open(path, 'rb'), 'dosya açılamadı: ' .. path)
 local s = f:read('*a'); f:close(); return s
end
local function exists(path) local f = io.open(path, 'rb'); if f then f:close(); return true end return false end
local function lines(s) local t = {}; for l in s:gmatch('[^\r\n]+') do t[#t + 1] = l end return t end

local ADDONS = {'ForeverTrail_Nav', 'ForeverTrail_Nav_EK', 'ForeverTrail_Nav_Kalimdor'}

-- TOC: dosya listesi, bağımlılık, lisans
local files = {}
for _, name in ipairs(ADDONS) do
 local toc = read(name .. '/' .. name .. '.toc')
 assert(toc:find('## LoadOnDemand: 1', 1, true), name .. ': isteğe bağlı yüklenmeli')
 assert(toc:find('## X-License: GPL-3.0-or-later', 1, true), name .. ': lisans başlığı')
 assert(not toc:find('Dependencies:%s*Polestar%f[^_%w]'), name .. ': Polestar bağımlılığı olmamalı')
 local dep = toc:match('## Dependencies:%s*([^\r\n]+)')
 if name == 'ForeverTrail_Nav' then assert(dep == nil, 'ana eklentinin bağımlılığı olmamalı')
 else assert(dep == 'ForeverTrail_Nav', name .. ': yalnızca ForeverTrail_Nav\'a bağlı olmalı: ' .. tostring(dep)) end
 local list = {}
 for _, l in ipairs(lines(toc)) do
  if not l:find('^#') and l:find('%.lua$') or l:find('%.xml$') then list[#list + 1] = (l:gsub('\\', '/')) end
 end
 assert(#list > 0, name .. ': dosya listesi boş')
 for _, f in ipairs(list) do
  assert(exists(name .. '/' .. f), name .. ': TOC dosyası eksik: ' .. f)
  files[#files + 1] = name .. '/' .. f
 end
end
-- Nav.xml'in listelediği betikler
local xml = read('ForeverTrail_Nav/Nav/Nav.xml')
for f in xml:gmatch('<Script file="([^"]+)"') do assert(exists('ForeverTrail_Nav/Nav/' .. f), 'Nav.xml dosyası eksik: ' .. f); files[#files + 1] = 'ForeverTrail_Nav/Nav/' .. f end

-- lisans ve atıf: LICENSE, CREDITS, NOTICE var; telif başlıkları silinmemiş
for _, f in ipairs({'LICENSE', 'CREDITS.md', 'NOTICE.md'}) do assert(exists('ForeverTrail_Nav/' .. f), 'eksik: ' .. f) end
assert(read('ForeverTrail_Nav/LICENSE'):find('GNU GENERAL PUBLIC LICENSE', 1, true), 'LICENSE GPL metni olmalı')
local notice = read('ForeverTrail_Nav/NOTICE.md')
for _, needle in ipairs({'Polestar_Nav 0.4.2.2', 'Cillian Berragan', 'Leffe', 'GPL-3.0'}) do assert(notice:find(needle, 1, true), 'NOTICE atıf içermeli: ' .. needle) end
for _, f in ipairs({'Path.lua', 'PathGrid.lua', 'PathJobs.lua'}) do
 local head = read('ForeverTrail_Nav/Routing/' .. f):sub(1, 1500)
 assert(head:find('Cillian Berragan', 1, true) and head:find('GPL', 1, true), f .. ': telif ve lisans başlığı korunmalı')
end
assert(read('ForeverTrail_Nav/Routing/Costs.lua'):sub(1, 400):find('The Polestar authors', 1, true), 'Costs.lua telif başlığı korunmalı')

-- bağımsızlık: kalan Polestar tanımlayıcısı ya da Polestar'a çalışma zamanı başvurusu yok
local bad = {'PolestarPathData', 'PolestarNavChokepoints', 'Polestar_Nav', 'PolestarNavCosts', 'Polestar%.Nav', 'Polestar and '}
local scanned = 0
for _, f in ipairs(files) do
 local src = read(f)
 scanned = scanned + 1
 for _, pat in ipairs(bad) do assert(not src:find(pat), f .. ': kalan Polestar başvurusu: ' .. pat) end
end
for _, f in ipairs({'ForeverTrail_Nav/API.lua', 'ForeverTrail_Nav/Routing/Path.lua'}) do
 assert(not read(f):find('[^%w_"\']_G%.Polestar%f[^_%w]'), f .. ': global Polestar kullanılmamalı')
end

-- parça adları gerçekten var olan klasörlere işaret eder
for map, name in pairs({['Nav0'] = 'ForeverTrail_Nav_EK', ['Nav1'] = 'ForeverTrail_Nav_Kalimdor'}) do
 assert(read('ForeverTrail_Nav/Nav/' .. map .. '.lua'):find('part = "' .. name .. '"', 1, true), map .. ': parça adı ' .. name)
 assert(exists(name .. '/' .. name .. '.toc'), 'parça eklentisi yok: ' .. name)
end
assert(read('ForeverTrail_Nav/API.lua'):find('ForeverTrail_NavEngine = Path', 1, true), 'API genel motoru ForeverTrail_NavEngine olarak açmalı')

-- tüm betikler derlenir (sözdizimi)
for _, f in ipairs(files) do
 if f:find('%.lua$') then local fn, err = loadfile(f); assert(fn, f .. ': derlenmedi: ' .. tostring(err)) end
end

-- yönlendirici yüklenir: ana eklentinin dosyaları sırayla çalıştırılır, global motor açılır
-- (veri çözme API'si olmayan istemcide haritalar bırakılır; motor yine de Find/Cancel sunar)
local ns = {}
_G.ForeverTrailPathData = nil
for _, f in ipairs(files) do
 if f:find('^ForeverTrail_Nav/') and f:find('%.lua$') and not f:find('/Nav/') then
  local fn = assert(loadfile(f))
  local ok, err = pcall(fn, 'ForeverTrail_Nav', ns)
  assert(ok, f .. ': yüklenirken hata: ' .. tostring(err))
 end
end
local P = _G.ForeverTrail_NavEngine
assert(type(P) == 'table' and type(P.Find) == 'function' and type(P.Cancel) == 'function' and type(P.Available) == 'function', 'motor Find/Cancel/Available sunmalı')
assert(P.Available(0) == false, 'veri yokken Available(0) false olmalı')
assert(_G.Polestar_NavEngine == nil, 'Polestar global\'i oluşturulmamalı')

print(('NavPack tests passed (%d dosya tarandı, 3 eklenti)'):format(scanned))
