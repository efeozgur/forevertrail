# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ForeverTrail is a WoW addon (Lua, Interface 16001, client 1.60.1 "World of Warcraft: Forever") — a quest guide with tracker, map/arrow routing, journal, gear/profession helpers, etc. This repo is linked into the game via a junction (`AddOnsForeverTrail` -> this folder; the old install is kept as `ForeverTrail.bak`), so edits take effect on `/reload` (new files need a full game restart). All user-facing text and the README are in Turkish; keep new UI strings Turkish. There is no build step. Development happens on the `v0.2-dev` branch.

## Commands

- Run a test (plain Lua 5.1+, from the addon root, no WoW client needed): `lua tests/engine.lua` (likewise `tests/map.lua`, `tests/owndb.lua`, etc. — one file per module, each prints/asserts on its own). There is no aggregate runner or linter; run the relevant `tests/*.lua` for the module you changed.
- Tests load modules via `assert(loadfile('Engine.lua'))('ForeverTrail', ns)` with stubbed WoW globals (`C_QuestLog`, etc.), so modules must be loadable with a bare `ns` table. `tests/ingame_sim.lua` simulates a wider client.
- In-game: `/ftrail debug` (client build info + state), `/ftrail test` (self-test), `/ftrail hata` (captured errors), `/ftrail yardim` (command list). Real-client behavior is largely unverified (see README "Doğrulama").

## Folder layout

Lua files live in folders; `ForeverTrail.toc` lists each by path (load order is unchanged). `Media/` and `Bindings.xml` stay at the root, and `tests/` loads modules by the same paths (e.g. `loadfile('Core/Engine.lua')`).

- `Core/`: Core, Compat, Diagnostics, Engine, Quest, Style, Kit (shared flat UI components: tiered fills from the theme, rail button, divider), Design, Polish, Layout
- `Data/`: generated `Data*.lua` tables, `OwnDB`, `OwnData`, `LiveSync`
- `Guide/`: Guides, Guide2, Journal, Recommendations, Recorder, Flow, Journey
- `Map/`: Map, MapRoute, Minimap, MinimapTips, Atlas, Discovery, Objectives, Places, Rares
- `UI/`: Panel, Hub, Tracker, Available, ViewOptions, Target, Arrow, Settings, Features, Toolbox, Extras, Wizard, QuestInfo
- `Helpers/`: Assist, Advisor, Focus, Helpers, Gear, Upgrade, Class, Professions, QuestHelper, QuestItems, Janti
- `Integration/`: Questie*/Queston* bridges

## Architecture

- **No modules/requires.** `ForeverTrail.toc` is the load order and the only wiring: every file starts with `local _, FT = ...` and shares the single addon namespace table `FT`. Adding a file means adding it to the TOC, in a position after anything it uses at load time. Functions are mostly looked up lazily at call time and guarded (`if FT.Foo then ...`), which is how optional modules and the bridges stay decoupled.
- **Entry/events:** `Core/Core.lua` owns the event frame (`QUEST_LOG_UPDATE`, `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, zone changes), debounces to `FT.Evaluate()`, and holds the `/ftrail` slash dispatcher (add new subcommands there, Turkish keywords).
- **Guide engine:** `Guides.lua`/`Guide2.lua`/`OwnData.lua` register guides via `FT.RegisterGuide`; `Engine.lua` validates them (`FT.ValidateGuide`) and decides step completion (`FT.IsStepDone`) from `FT.QuestState` (`Quest.lua`). Step types: `accept|objective|turnin|location|manual`; `stepId`s must be stable across versions because progress is saved by id. Coordinates are normalized 0–1 with `uiMapID`. Guide format is documented in README.md.
- **Embedded quest database (`Data*.lua`, `OwnDB.lua`):** `DataQuests/Npcs/Objects/Items/Zones.lua` are large generated Questie-derived tables (MBs; coordinates stored as x10 integers; fields indexed via the `QK/NK/OK/IK` key maps in `OwnDB.lua`). `OwnDB.lua` is the query layer — don't read the Data files whole; query through it. `DataNewQuests`, `DataStations`, `DataDungeons`, `DataTalents`, and `Data.lua` (`FT.SeedData`, in-game-recorded data exported via Veri > Dışa aktar) are ForeverTrail's own additions.
- **Live data (`LiveSync.lua`):** at `PLAYER_LOGIN`, if the standalone `QuestieDB` addon (global `LibQuestieDB`, contract 4) is installed, its quest/NPC/object/item rows are converted (by field name, coords → x10 flat) and written over `FT.DBQ/DBN/DBO/DBI` in time-sliced `OnUpdate` batches. Embedded rows are the fallback; ids absent from QuestieDB (own additions) are kept. Many modules iterate those raw tables with positional indexes, so keep the embedded row layout (`QK/NK/OK/IK` in `OwnDB.lua`, column lists in `LiveSync.lua`) in sync. `/ftrail canli` shows status; `ForeverTrailSettings.noLive=true` disables. `ZoneDB`/`QuestXP` in `OwnDB.lua` ask Questie's modules (`QuestieLoader:ImportModule`, pcall-guarded) first and fall back to embedded data. Modules that cache results derived from `FT.DB*` register a reset in `FT.liveListeners`, which `LiveSync` runs when sync finishes — add one for any new cache. Tests: `tests/livesync.lua`, `tests/livezone.lua`.
- **Talent plan:** Forever has no classic talent API (trees are `C_Traits`), so `FT.TalentPlan` returns `FT.TALENT_EXTERNAL` when `FT.Compat.NumTalents(1)==0` and the UI hands off to OneForAll's Talent Trees tab via its global `OneForAll_Binding('talents')` (`FT.OpenTalentPlanner`). `/ftrail yetenekdebug` dumps the talent API state.
- **View modes:** the tracker (`Tracker.lua`) supports `c_trackerView` = detay/liste/tablo and `c_trackerMax`; the available-quests box (`Available.lua`) supports `c_availView` = kart/liste/tablo plus `c_availSort`, `c_availMax`, `availShowGiver`, `availHideLow`. `ViewOptions.lua` adds an "Ayar" button to both windows and a popup built with `FT.BuildOptions` (Settings.lua); the same keys also appear on the Settings `q_takip` page. Defaults keep the old look (detay / kart). Tests: `tests/views.lua`, `tests/viewoptions.lua`.
- **Quest info:** `QuestInfo.lua` provides `FT.QuestXPInfo/QuestXPText` (exact XP from Questie's QuestXP module or the embedded `FT.DBXP`, else a per-level median marked "tahmini") and `FT.QuestInfoTip` (the rich tooltip used by the Available box). `DataXP.lua` is generated from QuestieDB's `xpDB-traces.lua` and overrides `FT.DBXP` (it is what covers Forever-only quests). Test: `tests/questinfo.lua`.
- **Quest-item guard:** `QuestItems.lua` — `FT.IsProtectedItem(itemID, classID)` (quest class, objective/source items of logged quests via QuestieDB, or `ForeverTrailSettings.lockedItems`) is checked by `isJunk` in `Gear.lua`; on `MERCHANT_UPDATE` it also buys protected items back from the vendor buyback list. `FT.ToggleQuestItems` / `/ftrail gorevesya` is the bag-item window. Setting `questItemGuard` (default on). Test: `tests/questitems.lua`.
- **UI layers** (Panel, Tracker, Map/MapRoute/Arrow/Minimap, Hub, Settings, Journal/Journey, Atlas, Layout/Design/Style/Polish, Wizard, etc.) are independent feature modules hanging off `FT`; settings live in `ForeverTrailSettings` (account), `ForeverTrailCharacter` (per-char guide/step), `ForeverTrailData`, `ForeverTrailBackup`.
- **Companion-addon integration:** `QuestieMerge.lua` detects an embedded/loaded Questie and exposes `FT.QuestieOverlaps` / `FT.QuestonOverlaps` — lists of ForeverTrail features (tracker, ! / ? icons, auto-quest, plate icons, …) that get disabled when Questie or Queston provides the same thing, to avoid duplicates. `QuestieBridge.lua`, `QuestonBridge.lua`, `QuestieUI.lua`, `QuestonTR1/2.lua` add ForeverTrail's settings into those addons' option windows and load Turkish locale via their public APIs without modifying their files. Optional WoWTR dependency supplies Turkish quest titles/objectives.
- **Vendored third-party trees:** `Questie/` and `QuestieDB/` (GPL-3.0, with their own licenses/Libs) are bundled upstream code. Treat them as vendored: don't refactor them; ForeverTrail's own code is the top-level `*.lua` files (MIT, see `LICENSE`). Neither tree is listed in `ForeverTrail.toc`.

## Conventions

- Third-party code/data must not be copied into ForeverTrail's own files except the already-bundled GPL Questie data; the README documents that Zygor etc. were only consulted for workflow, not copied.
- Protected-API safety: `C_Map` and other client calls are wrapped in `pcall` and nil-checked because they are not live-verified on this client; keep that pattern. Never modify or delete another addon's map pins/waypoints.
- Location-step checks are throttled (~1s); don't scan the quest log per frame.
