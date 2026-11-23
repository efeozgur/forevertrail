-- Görevler ve Alınabilir pencereleri: Ayrıntılı/Liste/Tablo biçimleri hatasız çalışmalı (evrensel taslak nesnelerle)
local function stub()
 return setmetatable({}, {
  __index = function(_, k)
   if not tostring(k):match('^%u') then return nil end -- alanlar nil, yöntemler (büyük harf) işlev
   return function(_, ...)
    if k == 'GetText' then return '' end
    if k == 'IsShown' or k == 'IsMouseOver' then return true end
    if k == 'GetScale' then return 1 end
    if k == 'GetWidth' or k == 'GetHeight' then return 100 end
    return stub()
   end
  end,
  __call = function() return stub() end,
 })
end
CreateFrame = function() return stub() end
GameTooltip = stub()
UIParent = stub()
GetTime = function() return 100 end
UnitXP = function() return 10 end
UnitXPMax = function() return 100 end
GetXPExhaustion = function() return 0 end
UnitLevel = function() return 10 end
ForeverTrailSettings = {}
ForeverTrailCharacter = {}
C_Map = {GetBestMapForUnit = function() return 1429 end,
 GetPlayerMapPosition = function() return {GetXY = function() return .5, .5 end} end,
 GetMapWorldSize = function() return 1000, 1000 end}
local quests = {
 {title = 'Alfa', questID = 1, level = 5}, {title = 'Beta', questID = 2, level = 8}, {title = 'Gama', questID = 3, level = 12},
}
C_QuestLog = {
 GetNumQuestLogEntries = function() return #quests + 1 end,
 GetInfo = function(i) if i == 1 then return {isHeader = true, title = 'Elwynn'} end local q = quests[i - 1]; return {title = q.title, questID = q.questID, level = q.level} end,
 IsComplete = function(id) return id == 3 end,
 GetQuestObjectives = function(id) return {{text = 'Kurt 3/8', numRequired = 8, numFulfilled = 3, finished = false}} end,
}
local ft = {Print = function(m) print('PRINT', m) end, errors = {},
 NewButton = function() return stub() end, SoftBackdrop = function() return stub() end, FontPath = function() return 'Fonts\\ARIALN.TTF' end,
 Style = {accent = {1, 1, 1}}, QuestTitle = function(id) return 'Görev ' .. id end, DiffColor = function() return 1, 1, 1 end,
 QuestDistance = function(id) return id * 100 end,
 QuestMarks = function()
  return {
   {kind = '!', questId = 10, level = 5, giver = 'Ayşe', x = .51, y = .5, map = 1429, low = true},
   {kind = '!', questId = 11, level = 9, giver = 'Mehmet', x = .6, y = .5, map = 1429},
   {kind = '!', questId = 12, level = 7, giver = 'Zeynep', x = .52, y = .5, map = 1429},
  }
 end}
for _, f in ipairs({'UI/Available.lua', 'UI/Tracker.lua'}) do assert(loadfile(f))('ForeverTrail', ft) end

-- Alınabilir
ft.CreateAvailableBox()
for _, view in ipairs({'kart', 'liste', 'tablo', 'kart'}) do
 for _, sort in ipairs({'yakin', 'seviye', 'ad'}) do
  ForeverTrailSettings.c_availView, ForeverTrailSettings.c_availSort = view, sort
  ForeverTrailSettings.availHideLow = sort == 'ad'
  ForeverTrailSettings.availShowGiver = view ~= 'kart' or sort ~= 'seviye'
  ForeverTrailSettings.c_availMax = sort == 'yakin' and '2' or '7'
  ft.RefreshAvailableBox()
 end
end

-- Görevler
ft.CreateTracker()
for _, view in ipairs({'detay', 'liste', 'tablo', 'detay'}) do
 for _, dist in ipairs({true, false}) do
  ForeverTrailSettings.c_trackerView = view
  ForeverTrailSettings.trkColDist = dist
  ForeverTrailSettings.c_trackerMax = dist and '2' or '12'
  ft.RefreshTracker()
 end
end
assert(#ft.errors == 0, ft.errors[1])
print('Views smoke test passed')
