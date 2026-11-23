local _, FT = ...

-- WoW Forever seviye atlama yetenek dizileri (seviye 10-60, 51 puan).
-- Kaynak: kami-labs.fr 'WoW Forever Leveling Builds' (t = dağılım, o = sıra; her harf bir yetenek, ağaç başına 20 yer).
FT.TalentBuilds = {
 WARRIOR = {
  {key='arms', name='Silah (Arms)', desc='İki elli silah; Ölümcül Vuruş ile güçlü tek hedef. Tek başına ve grupla rahat.', recommended=true, t='s05320203132215201-0525010501', o='sCCCBBFFDDBHHHBBIJJJKMLLKNONNNNQOVVVVVXXXXXbbbbbZdWW'},
  {key='fury', name='Öfke (Fury)', desc='Çift silah; yüksek hasar ama daha çok yemek/iyileşme ister.', recommended=false, t='s0500321-050530355122120231', o='sVVVVVXXXXXbbaaadccccghhcbkkkjjlbbYYYBBBBBeeffFFEEEG'},
  {key='prot', name='Koruma (Prot)', desc='Kalkan; çok sağlam, toplu yaratık çekip öldürür. Tek başına en güvenli savaşçı.', recommended=false, t='s023-05500005-250033120301011351', o='spppppsssttvvutxzxxoo23331444445VVVVVWWWWWbbbbbCCCBB'},
 },
 PALADIN = {
  {key='holy', name='Kutsal (Holy)', desc='İyileştirici; grup ve zindan için. Tek başına yavaş.', recommended=false, t='s50322015202121251-5-052300002', o='sppppprrrqqwwAAAAADDCCCHHHHHLKKIINOOGMPPPPPQUUUUUMEE'},
  {key='prot', name='Koruma (Prot)', desc='Kalkanla toplu yaratık; zindan tankı.', recommended=false, t='s-05302102313501531-05233000201', o='sppppprrrqqwwVVVVVWWWYYbbZccdeeefhiiiiijjjfkfffsssyc'},
  {key='ret', name='İntikam (Ret)', desc='İki elli silah; tek başına en hızlı paladin.', recommended=true, t='s05025-503-51233001201301351', o='sooooorrrqqwwvsszzzys2221p333334BBBBBDDEEEEEUUUUUWWW'},
 },
 HUNTER = {
  {key='bm', name='Hayvan Ustalığı (BM)', desc='Güçlü evcil hayvan; en kolay ve en hızlı seviye atlama.', recommended=true, t='s5120221405101241-30500520014', o='sAAAAACCEEBFFGHHKHHJJMNNJJJOOOOPWWWWWZZZZZaaUUUdeeee'},
  {key='mm', name='Nişancılık (MM)', desc='Menzilli hasar ve kritik; grupla iyi.', recommended=false, t='s51202215001-0053052001523051', o='sWWWWWZZZZZaaXXXdeeeeffeggiiiiijAAAAACCEEBFFGgHHKHHH'},
  {key='surv', name='Hayatta Kalma (Surv)', desc='Çeviklik ve kaçış; deneyimli oyuncu için.', recommended=false, t='s-00531500102-500230230250122151', o='sWWWWWooooorrsssvvvuuyyyyy311224444450xxZZZZZcXXXYee'},
 },
 ROGUE = {
  {key='assa', name='Suikast (Assa)', desc='Zehir ve kritik; yüksek patlama hasarı.', recommended=false, t='s02530320031551031-023033001-005', o='sBBVVCCCFFFCCGGDDDKLLLLNMMMMPPPMLQWWWYYYZZcZqqqqqJJJ'},
  {key='combat', name='Dövüş (Combat)', desc='En dengeli ve en hızlı haydut; Bıçak Fırtınası erken gelir.', recommended=true, t='s02500321201-3210330210012321551', o='sBBVVUUUYYYZZcZbbWgghhhjiikklllllmkkkCCCFFFCCGGHIIKf'},
  {key='sub', name='Gizlilik (Sub)', desc='Pusu ve açılış vuruşları; daha zor.', recommended=false, t='s023001-3200330012-305210031321021151', o='sBBoooqqrrqqqxxxwvzvvyy3211s444445VVUUUYYYZZcZddCCCF'},
 },
 PRIEST = {
  {key='disc', name='Disiplin (Disc)', desc='Kalkan ve mana; grup iyileştirme.', recommended=false, t='s520005031330011531-30505-005', o='sBBqqqqqUUUAAAAAFFFKKKFFJJJNHOPPPPQPQQHRWWWWWYYYYYHI'},
  {key='holy', name='Kutsal (Holy)', desc='Zindan iyileştiricisi.', recommended=false, t='s02300500103-33205101032021531-005', o='sBBqqqqqUUUVVVCCCFFFFFKKKYYYYZbYWWeedddhggiijjjiikiI'},
  {key='shadow', name='Gölge (Shadow)', desc='Tek başına en güçlü rahip; Ruh Musluğu ile az içersin.', recommended=true, t='s02500400103-3-50512201201312251', o='sBBqqqqqssttovwwooyzzzo011or22333433UUUCCCCCFFFKKKIF'},
 },
 SHAMAN = {
  {key='ele', name='Element (Ele)', desc='Uzaktan büyü hasarı.', recommended=false, t='s5500331023101351-052-053002001', o='sBBBBBEEEFFGFAAAKIIJJMNNNJOOOOOPpppppqqqttwVVVVVAAWW'},
  {key='enh', name='Geliştirme (Enh)', desc='Yakın dövüş ve Fırtına Vuruşu; tek başına en rahat şaman.', recommended=true, t='s04-055030310051212251-053020001', o='sVVVVVYYYWWbaaaWfggeejjpppppqqqsswiiekkkkklheeWWBBBB'},
  {key='resto', name='Onarım (Resto)', desc='İyileştirici; grup için.', recommended=false, t='s-055-5530003315513151', o='spppppqqqoowooovzxxxx1000x222223vvuuuVVVVVyyyyyWWWWW'},
 },
 MAGE = {
  {key='arcane', name='Gizem (Arcane)', desc='Mana ve patlama hasarı.', recommended=false, t='s050225223100311531-550000002-003', o='sBBBBBGGDDFJqqqFFFFNMMMIOPPPPQQQPIRIUUUUUVVVVVccHHEE'},
  {key='fire', name='Ateş (Fire)', desc='Yüksek hasar, daha riskli.', recommended=false, t='s0502052001002-15520301200133131-003', o='sVVVVVqqqWWWWWbZZZcfcgggihhhXjjjXUkBBBBBGFFFFFGDDJMM'},
  {key='frost', name='Buz (Frost)', desc='Yavaşlatma ve güvenlik; seviye atlamada en iyisi.', recommended=true, t='s0502041--053530033101331251', o='spppppqqqssxrrrrz000r332114444451svvvwwwBBBBBGDDFFFF'},
 },
 WARLOCK = {
  {key='affli', name='Lanet (Affli)', desc='Sürekli hasar ve can emme; tek başına en hızlı büyücü.', recommended=true, t='s04522323132211351--05500001', o='sCCCCCBBBBFFFHHHEELLDNOOODPPPPPQGGJJJIMKKpppppqqqqqv'},
  {key='demo', name='İblis (Demo)', desc='Güçlü iblis; sağlam ama yavaş.', recommended=false, t='s05500020035-0015003231201301351', o='sCXXXXXbbaaaeeccchhhgdjkkkWlllllmCCCCBBBBBJJJGGKKKKK'},
  {key='destro', name='Yıkım (Destro)', desc='Ateş ve patlama hasarı.', recommended=false, t='s255-00050001-0050355103101351', o='sBBBBqqqqqtttttvuuuuyuxxx1110s222223ssCCCCCBAAXXXXXb'},
 },
 DRUID = {
  {key='balance', name='Denge (Balance)', desc='Uzaktan büyü; mana tüketir.', recommended=false, t='s2532223115501351--505', o='sAABBBBBCCCFFEEHIDDGGGMNNNJJJJJPKKKKKOOOOOoooooqqqqq'},
  {key='feral', name='Vahşi (Feral)', desc='Kedi/ayı formu; tek başına en hızlı ve en sağlam druid.', recommended=true, t='s050022-5423030212310212051-05', o='sVVVVUWUUUXddcbbhhXXeijjeBBBBBEEFFpppppWlllllmfUZZZe'},
  {key='resto', name='Onarım (Resto)', desc='İyileştirici; grup için.', recommended=false, t='s543022011--5053005103113051', o='sAAAAAooooorrrFFEECHCCBBIqqvqqquyuuuuz000xxx222223BB'},
 },
}
