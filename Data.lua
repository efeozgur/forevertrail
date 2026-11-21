local _, FT = ...

-- ForeverTrail'in kendi görev verisi (eklentiyle gelen sabit tohum).
-- Oyunda toplanan veri "Veri > Dışa aktar" ile alınıp buraya eklenir; böylece güncellemelerden etkilenmez.
-- Biçim:
--  quests[id] = {t='Başlık', l=seviye, s={map,x,y,'NPC'}, f={map,x,y,'NPC'}, o={[i]={{map,x,y},...}}}
FT.SeedData = {
 version = 1,
 quests = {},
}
