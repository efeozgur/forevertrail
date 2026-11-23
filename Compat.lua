-- WoW Forever uyumluluk katmanı.
-- Forever, Mainline (12.x) arayüz altyapısını kullanır: eski global beceri/yetenek/meslek API'leri
-- ya yok ya da farklı değer döndürür. Sınıf ve meslek özellikleri buradan okur.
local _, FT = ...

local C = {}
FT.Compat = C

-- "Gizli değer" (secret value): Forever bazı değerleri (birim adı, GUID, hız...) eklentinin
-- karşılaştırmasına, metin işlemesine ya da hesabına kapatır. Böyle değer gelirse nil sayılır.
function FT.Plain(value)
 if value ~= nil and issecretvalue and issecretvalue(value) then return nil end
 return value
end

local function try(fn, ...)
 if type(fn) ~= 'function' then return nil end
 local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
 if ok then return a, b, c, d, e, f, g, h, i, j end
end

----------------------------------------------------------------------
-- Beceri satırları (meslekler)
----------------------------------------------------------------------
function C.NumSkillLines()
 if C_SkillInfo and C_SkillInfo.GetNumSkillLines then return try(C_SkillInfo.GetNumSkillLines) or 0 end
 return try(GetNumSkillLines) or 0
end

-- name, isHeader, rank, maxRank
function C.SkillLine(i)
 if C_SkillInfo and C_SkillInfo.GetSkillLineInfo then
  local s = try(C_SkillInfo.GetSkillLineInfo, i)
  if type(s) ~= 'table' then return nil end
  return s.name or s.skillName, s.isHeader, s.rank or s.skillRank or 0, s.maxRank or s.skillMaxRank or s.max or s.maxSkillRank or 0, s.skillID
 end
 local name, header, _, rank, _, _, max = try(GetSkillLineInfo, i)
 return name, header, rank or 0, max or 0
end

function C.ExpandSkills()
 if C_SkillInfo and C_SkillInfo.ExpandSkillHeader and C_SkillInfo.GetSkillLineInfo then
  for i = C.NumSkillLines(), 1, -1 do
   local s = try(C_SkillInfo.GetSkillLineInfo, i)
   if type(s) == 'table' and s.isHeader and s.isCollapsed then try(C_SkillInfo.ExpandSkillHeader, i) end
  end
 elseif ExpandSkillHeader then
  try(ExpandSkillHeader, 0)
 end
end

----------------------------------------------------------------------
-- Yetenekler
----------------------------------------------------------------------
local SI = C_SpecializationInfo

function C.NumTalentTabs()
 local n = try(GetNumTalentTabs)
 if type(n) == 'number' and n > 0 then return n end
 n = SI and try(SI.GetNumSpecializations)
 if type(n) == 'number' and n > 0 then return n end
 return 3
end

function C.TalentTabName(tab)
 if SI and SI.GetSpecializationInfo then
  local a, b = try(SI.GetSpecializationInfo, tab)
  if type(b) == 'string' then return b end
  if type(a) == 'table' and a.name then return a.name end
 end
 local a, b = try(GetTalentTabInfo, tab)
 if type(a) == 'table' and a.name then return a.name end
 if type(a) == 'string' then return a end
 if type(b) == 'string' then return b end
 return 'Ağaç ' .. tab
end

-- {name, icon, tier, col, rank, max} ya da nil
function C.TalentInfo(tab, i)
 if SI and SI.GetTalentInfo then
  local r = try(SI.GetTalentInfo, {specializationIndex = tab, talentIndex = i})
  if type(r) == 'table' and r.name then
   return {name = r.name, icon = r.icon or r.fileID, tier = r.tier or r.row or 1, col = r.column or r.col or 1, rank = r.rank or r.currentRank or 0, max = r.maxRank or 1}
  end
 end
 local a, b, c, d, e, f = try(GetTalentInfo, tab, i)
 if type(a) == 'string' then
  -- Classic: name, icon, tier, column, rank, maxRank
  return {name = a, icon = b, tier = tonumber(c) or 1, col = tonumber(d) or 1, rank = tonumber(e) or 0, max = tonumber(f) or 1}
 end
 if type(a) == 'table' and a.name then
  return {name = a.name, icon = a.icon, tier = a.tier or 1, col = a.column or 1, rank = a.rank or 0, max = a.maxRank or 1}
 end
 return nil
end

function C.NumTalents(tab)
 local n = try(GetNumTalents, tab)
 if type(n) == 'number' and n > 0 then return n end
 if SI and SI.GetNumTalents then
  n = try(SI.GetNumTalents, tab)
  if type(n) == 'number' and n > 0 then return n end
 end
 local count = 0
 for i = 1, 40 do
  if C.TalentInfo(tab, i) then count = i else break end
 end
 return count
end

function C.SpentPoints()
 local spent = 0
 for tab = 1, C.NumTalentTabs() do
  for i = 1, C.NumTalents(tab) do
   local t = C.TalentInfo(tab, i)
   if t then spent = spent + (t.rank or 0) end
  end
 end
 return spent
end

function C.UnspentPoints()
 local p = try(UnitCharacterPoints, 'player')
 if type(p) == 'number' then return p end
 p = try(GetUnspentTalentPoints)
 if type(p) == 'number' then return p end
 if SI and SI.GetUnspentTalentPoints then
  p = try(SI.GetUnspentTalentPoints)
  if type(p) == 'number' then return p end
 end
 local level = UnitLevel and UnitLevel('player') or 1
 return math.max(0, level - 9 - C.SpentPoints())
end

function C.LearnTalent(tab, i)
 if LearnTalent then
  local ok = pcall(LearnTalent, tab, i)
  if ok then return true end
 end
 if SI and SI.LearnTalent then
  local ok = pcall(SI.LearnTalent, {specializationIndex = tab, talentIndex = i})
  if ok then return true end
  ok = pcall(SI.LearnTalent, tab, i)
  if ok then return true end
 end
 return false
end

-- Açık yetenek penceresi (Classic, Mainline ve Forever adlarıyla)
function C.TalentFrame()
 for _, n in ipairs({'TalentFrame', 'PlayerTalentFrame', 'PlayerSpellsFrame', 'ClassTalentFrame'}) do
  local f = _G[n]
  if f and f.IsShown then return f, n end
 end
end

----------------------------------------------------------------------
-- Meslek tarifleri (Mainline C_TradeSkillUI ya da eski global API)
----------------------------------------------------------------------
local DIFF = {[0] = 'optimal', [1] = 'medium', [2] = 'easy', [3] = 'trivial'}

-- liste: {id|i, name, kind, avail, missing, modern}
function C.Recipes()
 local out = {}
 local T = C_TradeSkillUI
 if T and T.GetAllRecipeIDs and T.GetRecipeInfo then
  local ids = try(T.GetAllRecipeIDs)
  if type(ids) == 'table' then
   for _, id in ipairs(ids) do
    local r = try(T.GetRecipeInfo, id)
    if type(r) == 'table' and r.learned ~= false and r.name then
     local kind = DIFF[r.relativeDifficulty] or r.difficulty or 'trivial'
     local missing = {}
     local sch = T.GetRecipeSchematic and try(T.GetRecipeSchematic, id, false)
     if type(sch) == 'table' and type(sch.reagentSlotSchematics) == 'table' then
      for _, slot in ipairs(sch.reagentSlotSchematics) do
       local rg = slot.reagents and slot.reagents[1]
       local need = slot.quantityRequired or 0
       if rg and rg.itemID and need > 0 then
        local have = (C_Item and C_Item.GetItemCount and try(C_Item.GetItemCount, rg.itemID)) or (GetItemCount and try(GetItemCount, rg.itemID)) or 0
        if have < need then
         local nm = (C_Item and C_Item.GetItemNameByID and try(C_Item.GetItemNameByID, rg.itemID)) or ('#' .. rg.itemID)
         missing[#missing + 1] = ('%s %d/%d'):format(nm, have, need)
        end
       end
      end
     end
     out[#out + 1] = {id = id, name = r.name, kind = kind, avail = r.numAvailable or 0, missing = missing, modern = true}
    end
   end
   return out, true
  end
 end
 return nil, false
end

function C.Craft(r, count)
 local T = C_TradeSkillUI
 if r.modern and T and T.CraftRecipe then
  return pcall(T.CraftRecipe, r.id, count or 1)
 end
end

function C.TradeSkillName()
 local T = C_TradeSkillUI
 if T and T.GetBaseProfessionInfo then
  local p = try(T.GetBaseProfessionInfo)
  if type(p) == 'table' and p.professionName then return p.professionName end
 end
 if T and T.GetTradeSkillLine then
  local a, b = try(T.GetTradeSkillLine)
  if type(a) == 'string' then return a end
  if type(b) == 'string' then return b end
 end
 return (GetTradeSkillLine and try(GetTradeSkillLine)) or (GetCraftDisplaySkillLine and try(GetCraftDisplaySkillLine)) or ''
end

function C.ProfessionFrame()
 for _, n in ipairs({'ProfessionsFrame', 'TradeSkillFrame', 'CraftFrame'}) do
  local f = _G[n]
  if f and f.IsShown and f:IsShown() then return f end
 end
end
