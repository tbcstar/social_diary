--[[===========================================================================
  Capture/CoA.lua - the Conquest of Azeroth content tables this diary needs.

  Why this file exists: the addon was written against "WoW Forever" (retail
  data), and the client here is 3.3.5a running the CoA ruleset. Names the game
  returns (class names, battleground names, zone names) are English on an enUS
  client, and several classes/battlegrounds simply do not exist in the retail
  data the addon shipped with. These tables are the single place to fill in the
  CoA answer, so consumers never hardcode a list.

  Contract (fixed by the port lead, do not change the shape):
    ns.CoA.maxLevel            = 60
    ns.CoA.classes[id]         = { id=, name=, token=, resource=, zh=, src= }
    ns.CoA.dungeons            = { { map=, name=, kind=, minLevel=, maxLevel=, [lfgOff=], zh=, src= }, ... }
    ns.CoA.Dungeon(key)        = entry | nil    (key: instance/zone name, or Map.dbc id)
    ns.CoA.Reachable(entry)    = true | false   (level cap 60, Dungeon Finder lockouts)
    ns.CoA.battlegrounds[key]  = { name=, zh=, src= }
    every entry carries src = "client-dbc" | "server-sql" | "frameXML" |
    "server-conf" | "guess". Anything "guess" must stay out of the UI.

  zh is filled by the localisation owner (Locales/zhCN/Names.lua's CoA.zhNames
  is the same batch of translations -- one name, one spelling). An empty zh
  means "no Chinese name exists yet": CoA.Name then returns the English name
  and the entry is listed in that file's CoA.todoNames. Never invent one here.

  Load order: this file sits in Capture/, which the TOC loads after Core/ and
  after Locales/. So consumers must read ns.CoA lazily (function call time,
  not load time) and must tolerate it being nil. The helpers below are all
  lazy and nil safe.
===========================================================================]]--
local addonName, ns = ...

local CoA = {}
ns.CoA = CoA

-- 60, not 80: CoA caps characters at 60 (server side,
-- src/server/apps/worldserver/worldserver.conf.dist:2148 MaxPlayerLevel = 60).
-- Core/Journey.lua prefers GetMaxPlayerLevel() and then MAX_PLAYER_LEVEL, and
-- the 3.3.5 client still reports 80, so this table is the honest answer.
CoA.maxLevel = 60
CoA.maxLevelSrc = "server-conf"

-- Power type numbers, from the 3.3.5 ChrClasses layout.
CoA.Power = {
  [0] = "Mana",
  [1] = "Rage",
  [2] = "Focus",
  [3] = "Energy",
  [6] = "Runic Power",
}

--[[---------------------------------------------------------------------------
  Classes. Source: client DBC ChrClasses (ClassID, name_0, f55__str, powerType).
  f55__str is the class token the client hands to UnitClass as the second
  return, and CoA reuses stock tokens for custom classes, so the token is NOT
  the name: Templar is MONK, Venomancer is PROPHET, Bloodmage is SONOFARUGAL,
  Primalist is WILDWALKER, Runemaster is SPIRITMAGE, Felsworn is DEMONHUNTER,
  Knight of Xoroth is FLESHWARDEN. Match on the token, never on the name.
  Colours are not stored here: the client fills RAID_CLASS_COLORS for all of
  these tokens (Data/CharacterAdvancement.lua maps the custom ones), so
  CoA.ClassColor(token) reads the live table instead of duplicating it.
---------------------------------------------------------------------------]]--
CoA.classes = {
  [1] = { id = 1, name = 'Warrior', token = 'WARRIOR', resource = 1, zh = '战士', src = "client-dbc" },
  [2] = { id = 2, name = 'Paladin', token = 'PALADIN', resource = 0, zh = '圣骑士', src = "client-dbc" },
  [3] = { id = 3, name = 'Hunter', token = 'HUNTER', resource = 0, zh = '猎人', src = "client-dbc" },
  [4] = { id = 4, name = 'Rogue', token = 'ROGUE', resource = 3, zh = '潜行者', src = "client-dbc" },
  [5] = { id = 5, name = 'Priest', token = 'PRIEST', resource = 0, zh = '牧师', src = "client-dbc" },
  [6] = { id = 6, name = 'Death Knight', token = 'DEATHKNIGHT', resource = 6, zh = '死亡骑士', src = "client-dbc" },
  [7] = { id = 7, name = 'Shaman', token = 'SHAMAN', resource = 0, zh = '萨满祭司', src = "client-dbc" },
  [8] = { id = 8, name = 'Mage', token = 'MAGE', resource = 0, zh = '法师', src = "client-dbc" },
  [9] = { id = 9, name = 'Warlock', token = 'WARLOCK', resource = 0, zh = '术士', src = "client-dbc" },
  [10] = { id = 10, name = 'Hero', token = 'HERO', resource = 0, zh = '英雄', src = "client-dbc" },
  [11] = { id = 11, name = 'Druid', token = 'DRUID', resource = 0, zh = '德鲁伊', src = "client-dbc" },
  [12] = { id = 12, name = 'Barbarian', token = 'BARBARIAN', resource = 3, zh = '野蛮人', src = "client-dbc" },
  [13] = { id = 13, name = 'Witch Doctor', token = 'WITCHDOCTOR', resource = 0, zh = '巫医', src = "client-dbc" },
  [14] = { id = 14, name = 'Felsworn', token = 'DEMONHUNTER', resource = 3, zh = '魔誓者', src = "client-dbc" },
  [15] = { id = 15, name = 'Witch Hunter', token = 'WITCHHUNTER', resource = 0, zh = '猎巫人', src = "client-dbc" },
  [16] = { id = 16, name = 'Stormbringer', token = 'STORMBRINGER', resource = 0, zh = '风暴使者', src = "client-dbc" },
  [17] = { id = 17, name = 'Knight of Xoroth', token = 'FLESHWARDEN', resource = 1, zh = '克索罗斯骑士', src = "client-dbc" },
  [18] = { id = 18, name = 'Guardian', token = 'GUARDIAN', resource = 3, zh = '守卫者', src = "client-dbc" },
  [19] = { id = 19, name = 'Templar', token = 'MONK', resource = 3, zh = '圣堂武士', src = "client-dbc" },
  [20] = { id = 20, name = 'Bloodmage', token = 'SONOFARUGAL', resource = 1, zh = '血法师', src = "client-dbc" },
  [21] = { id = 21, name = 'Ranger', token = 'RANGER', resource = 2, zh = '游侠', src = "client-dbc" },
  [22] = { id = 22, name = 'Chronomancer', token = 'CHRONOMANCER', resource = 0, zh = '时空法师', src = "client-dbc" },
  [23] = { id = 23, name = 'Necromancer', token = 'NECROMANCER', resource = 6, zh = '死灵法师', src = "client-dbc" },
  [24] = { id = 24, name = 'Pyromancer', token = 'PYROMANCER', resource = 0, zh = '火法师', src = "client-dbc" },
  [25] = { id = 25, name = 'Cultist', token = 'CULTIST', resource = 0, zh = '邪教徒', src = "client-dbc" },
  [26] = { id = 26, name = 'Starcaller', token = 'STARCALLER', resource = 3, zh = '唤星者', src = "client-dbc" },
  [27] = { id = 27, name = 'Sun Cleric', token = 'SUNCLERIC', resource = 0, zh = '太阳牧师', src = "client-dbc" },
  [28] = { id = 28, name = 'Tinker', token = 'TINKER', resource = 0, zh = '机械师', src = "client-dbc" },
  [29] = { id = 29, name = 'Venomancer', token = 'PROPHET', resource = 0, zh = '毒术师', src = "client-dbc" },
  [30] = { id = 30, name = 'Reaper', token = 'REAPER', resource = 6, zh = '收割者', src = "client-dbc" },
  [31] = { id = 31, name = 'Primalist', token = 'WILDWALKER', resource = 0, zh = '原初者', src = "client-dbc" },
  [32] = { id = 32, name = 'Runemaster', token = 'SPIRITMAGE', resource = 0, zh = '符文师', src = "client-dbc" },
}

--[[---------------------------------------------------------------------------
  Battlegrounds and arenas. Source: client DBC BattlemasterList (type 3 =
  battleground, type 4 = arena). Pseudo rows ("Random Battleground", "All
  Arenas", "Clash Map Group 1-4") and the type 0 entries (Minigames, Brawler's
  Guild) are not real maps and are left out on purpose. Keyed by the English
  name the client reports, because that is what GetBattlefieldStatus and
  GetInstanceInfo return.

  50 of these are CoA's own maps and have no Chinese name yet: their
  zh is "" and they are listed in Locales/zhCN/Names.lua's CoA.todoNames.
---------------------------------------------------------------------------]]--
CoA.battlegrounds = {
  ['Alterac Valley'] = { name = 'Alterac Valley', kind = "battleground", zh = '奥特兰克山谷', src = "client-dbc" },
  ['Warsong Gulch'] = { name = 'Warsong Gulch', kind = "battleground", zh = '战歌峡谷', src = "client-dbc" },
  ['Arathi Basin'] = { name = 'Arathi Basin', kind = "battleground", zh = '阿拉希盆地', src = "client-dbc" },
  ['Nagrand Arena'] = { name = 'Nagrand Arena', kind = "arena", zh = '纳格兰竞技场', src = "client-dbc" },
  ['Blade\'s Edge Arena'] = { name = 'Blade\'s Edge Arena', kind = "arena", zh = '刀锋山竞技场', src = "client-dbc" },
  ['Eye of the Storm'] = { name = 'Eye of the Storm', kind = "battleground", zh = '风暴之眼', src = "client-dbc" },
  ['Ruins of Lordaeron'] = { name = 'Ruins of Lordaeron', kind = "arena", zh = '洛丹伦废墟', src = "client-dbc" },
  ['Strand of the Ancients'] = { name = 'Strand of the Ancients', kind = "battleground", zh = '远古海滩', src = "client-dbc" },
  ['Dalaran Sewers'] = { name = 'Dalaran Sewers', kind = "arena", zh = '达拉然下水道', src = "client-dbc" },
  ['The Ring of Valor'] = { name = 'The Ring of Valor', kind = "arena", zh = '勇气竞技场', src = "client-dbc" },
  ['FFA BG'] = { name = 'FFA BG', kind = "battleground", zh = '', src = "client-dbc" },
  ['Coliseum of Past Echoes Arena'] = { name = 'Coliseum of Past Echoes Arena', kind = "arena", zh = '', src = "client-dbc" },
  ['Maldraxxus Coliseum'] = { name = 'Maldraxxus Coliseum', kind = "arena", zh = '', src = "client-dbc" },
  ['Nagrand Arena HD'] = { name = 'Nagrand Arena HD', kind = "arena", zh = '', src = "client-dbc" },
  ['Blade\'s Edge Arena HD'] = { name = 'Blade\'s Edge Arena HD', kind = "arena", zh = '', src = "client-dbc" },
  ['Imperial Arena of Thakraj'] = { name = 'Imperial Arena of Thakraj', kind = "arena", zh = '', src = "client-dbc" },
  ['Isle of Conquest'] = { name = 'Isle of Conquest', kind = "battleground", zh = '征服之岛', src = "client-dbc" },
  ['Manastorm Brawl'] = { name = 'Manastorm Brawl', kind = "battleground", zh = '', src = "client-dbc" },
  ['Arathi Basin (Winter)'] = { name = 'Arathi Basin (Winter)', kind = "battleground", zh = '', src = "client-dbc" },
  ['Warsong Gulch (Winter)'] = { name = 'Warsong Gulch (Winter)', kind = "battleground", zh = '', src = "client-dbc" },
  ['Arathi Basin (HD)'] = { name = 'Arathi Basin (HD)', kind = "battleground", zh = '', src = "client-dbc" },
  ['Warsong Gulch (HD)'] = { name = 'Warsong Gulch (HD)', kind = "battleground", zh = '', src = "client-dbc" },
  ['Twin Peaks'] = { name = 'Twin Peaks', kind = "battleground", zh = '双子峰', src = "client-dbc" },
  ['The Tiger\'s Peak'] = { name = 'The Tiger\'s Peak', kind = "arena", zh = '', src = "client-dbc" },
  ['Southshore vs. Tarren Mill'] = { name = 'Southshore vs. Tarren Mill', kind = "battleground", zh = '', src = "client-dbc" },
  ['Temple of Kotmogu'] = { name = 'Temple of Kotmogu', kind = "battleground", zh = '寇魔古寺', src = "client-dbc" },
  ['Assault on Alcaz'] = { name = 'Assault on Alcaz', kind = "battleground", zh = '', src = "client-dbc" },
  ['Alterac Attack'] = { name = 'Alterac Attack', kind = "battleground", zh = '', src = "client-dbc" },
  ['Andorhal Assault'] = { name = 'Andorhal Assault', kind = "battleground", zh = '', src = "client-dbc" },
  ['The War of Zin-Malor'] = { name = 'The War of Zin-Malor', kind = "battleground", zh = '', src = "client-dbc" },
  ['The Battle of Bladespire Hold'] = { name = 'The Battle of Bladespire Hold', kind = "battleground", zh = '', src = "client-dbc" },
  ['The Battle of Booty Bay'] = { name = 'The Battle of Booty Bay', kind = "battleground", zh = '', src = "client-dbc" },
  ['Skirmish in the Steppes'] = { name = 'Skirmish in the Steppes', kind = "battleground", zh = '', src = "client-dbc" },
  ['Clash in The Cauldron'] = { name = 'Clash in The Cauldron', kind = "battleground", zh = '', src = "client-dbc" },
  ['Deatholme Deathmatch'] = { name = 'Deatholme Deathmatch', kind = "battleground", zh = '', src = "client-dbc" },
  ['Battle of Dire Maul'] = { name = 'Battle of Dire Maul', kind = "battleground", zh = '', src = "client-dbc" },
  ['Siege of Sardor Isle'] = { name = 'Siege of Sardor Isle', kind = "battleground", zh = '', src = "client-dbc" },
  ['Frostwhisper Fallout'] = { name = 'Frostwhisper Fallout', kind = "battleground", zh = '', src = "client-dbc" },
  ['Silverpine Showdown'] = { name = 'Silverpine Showdown', kind = "battleground", zh = '', src = "client-dbc" },
  ['Battle for Nagrand'] = { name = 'Battle for Nagrand', kind = "battleground", zh = '', src = "client-dbc" },
  ['Hellfire Havoc'] = { name = 'Hellfire Havoc', kind = "battleground", zh = '', src = "client-dbc" },
  ['War of The World Tree'] = { name = 'War of The World Tree', kind = "battleground", zh = '', src = "client-dbc" },
  ['Airstrip Assault'] = { name = 'Airstrip Assault', kind = "battleground", zh = '', src = "client-dbc" },
  ['Bloodshed in The Barrens'] = { name = 'Bloodshed in The Barrens', kind = "battleground", zh = '', src = "client-dbc" },
  ['Battle of North Gate Pass'] = { name = 'Battle of North Gate Pass', kind = "battleground", zh = '', src = "client-dbc" },
  ['Excavation of Ahn\'Qiraj'] = { name = 'Excavation of Ahn\'Qiraj', kind = "battleground", zh = '', src = "client-dbc" },
  ['Stonewatch Slaughter'] = { name = 'Stonewatch Slaughter', kind = "battleground", zh = '', src = "client-dbc" },
  ['Slaughter in Stromgarde'] = { name = 'Slaughter in Stromgarde', kind = "battleground", zh = '', src = "client-dbc" },
  ['Battle for Theramore'] = { name = 'Battle for Theramore', kind = "battleground", zh = '', src = "client-dbc" },
  ['Trouble in Tor\'Watha'] = { name = 'Trouble in Tor\'Watha', kind = "battleground", zh = '', src = "client-dbc" },
  ['Carnage in the Crater'] = { name = 'Carnage in the Crater', kind = "battleground", zh = '', src = "client-dbc" },
  ['Warsong Lumber War'] = { name = 'Warsong Lumber War', kind = "battleground", zh = '', src = "client-dbc" },
  ['War of Windshear Crag'] = { name = 'War of Windshear Crag', kind = "battleground", zh = '', src = "client-dbc" },
  ['The Inventor\'s Library'] = { name = 'The Inventor\'s Library', kind = "arena", zh = '', src = "client-dbc" },
  ['Amphitheater of Anguish'] = { name = 'Amphitheater of Anguish', kind = "arena", zh = '', src = "client-dbc" },
  ['Tol\'viron Arena'] = { name = 'Tol\'viron Arena', kind = "arena", zh = '', src = "client-dbc" },
  ['Ashamane\'s Fall'] = { name = 'Ashamane\'s Fall', kind = "arena", zh = '', src = "client-dbc" },
  ['Black Rook Hold Arena'] = { name = 'Black Rook Hold Arena', kind = "arena", zh = '黑鸦堡垒竞技场', src = "client-dbc" },
  ['Baradin Hold Arena'] = { name = 'Baradin Hold Arena', kind = "arena", zh = '', src = "client-dbc" },
  ['Obelisk of the Stars'] = { name = 'Obelisk of the Stars', kind = "arena", zh = '', src = "client-dbc" },
  ['Guardian\'s Hall'] = { name = 'Guardian\'s Hall', kind = "arena", zh = '', src = "client-dbc" },
  ['Spark of Creator'] = { name = 'Spark of Creator', kind = "arena", zh = '', src = "client-dbc" },
  ['The Twisting Nether'] = { name = 'The Twisting Nether', kind = "arena", zh = '扭曲虚空', src = "client-dbc" },
  ['Zanza\'s Isle'] = { name = 'Zanza\'s Isle', kind = "battleground", zh = '', src = "client-dbc" },
  ['Akhen City Ruins'] = { name = 'Akhen City Ruins', kind = "battleground", zh = '', src = "client-dbc" },
}

--[[---------------------------------------------------------------------------
  Dungeons (副本). Verified against the client's own LFGDungeons DBC, not
  guessed: dbc layer v20261104095559 (patch-M.MPQ), rows with TypeID 1
  (dungeon) or 2 (raid) that carry a real MapID, de-duplicated by MapID --
  103 rows, ids 33 (Shadowfang Keep) to 1912 (Tor'Watha). The list is data,
  not policy: filter with CoA.Reachable before offering any of it.

  Four caveats that matter for the code reading this:

  1. map is the Map.dbc id, which is NOT the WorldMapArea id that
     GetCurrentMapAreaID() / C_Map.GetBestMapForUnit() return (Mulgore is
     1412 there), and 3.3.5's GetInstanceInfo() returns no instance id at all.
     So in-game identity is the English NAME that GetInstanceInfo() and
     GetRealZoneText() return; CoA.Dungeon() normalises both sides and is the
     way to look an entry up. Never compare raw map ids against where.mapID.
  2. CoA caps players at 60, so every row with minLevel > 60 is stock TBC/WotLK
     content the client still carries and the player can never reach -- the
     70-80 raids/dungeons and the 81-81 "(PvE)" world bosses. CoA.Reachable()
     answers that question.
  3. Two dungeons exist but cannot be entered at all: the server cut them from
     the Dungeon Finder and neither has a non-LFG entrance
     (data/sql/updates/pending_db_world/rev_20260922_01_disable_inquisition_otherside_lfg.sql
     -- maps 936 Vaults of Inquisition and 937 Road to De Other Side). They
     stay in the list, marked lfgOff = true / src = "server-sql".
  4. Rows whose LFG range is 100-100 (Wailing Caverns, Uldaman, Gnomeregan,
     Scholomance, Magisters' Terrace) are LFG rows the client does not offer;
     the numbers are the DBC's own and Left as they are. Atal'Zul (890) is in
     the client DBC only -- no server SQL mentions it -- so it is listed
     client-side and stays unconfirmed (未确认) on the server side.
---------------------------------------------------------------------------]]--
CoA.dungeons = {
  { map = 33, name = "Shadowfang Keep", kind = "dungeon", minLevel = 15, maxLevel = 59 },
  { map = 34, name = "Stormwind Stockade", kind = "dungeon", minLevel = 15, maxLevel = 59 },
  { map = 36, name = "Deadmines", kind = "dungeon", minLevel = 15, maxLevel = 59 },
  { map = 43, name = "Wailing Caverns", kind = "dungeon", minLevel = 100, maxLevel = 100 },
  { map = 47, name = "Razorfen Kraul", kind = "dungeon", minLevel = 25, maxLevel = 59 },
  { map = 48, name = "Blackfathom Deeps", kind = "dungeon", minLevel = 15, maxLevel = 59 },
  { map = 70, name = "Uldaman", kind = "dungeon", minLevel = 100, maxLevel = 100 },
  { map = 90, name = "Gnomeregan", kind = "dungeon", minLevel = 100, maxLevel = 100 },
  { map = 109, name = "Sunken Temple", kind = "dungeon", minLevel = 45, maxLevel = 59 },
  { map = 129, name = "Razorfen Downs", kind = "dungeon", minLevel = 30, maxLevel = 59 },
  { map = 189, name = "Scarlet Monastery - Graveyard", kind = "dungeon", minLevel = 18, maxLevel = 59 },
  { map = 209, name = "Zul'Farrak", kind = "dungeon", minLevel = 35, maxLevel = 59 },
  { map = 229, name = "Lower Blackrock Spire", kind = "dungeon", minLevel = 60, maxLevel = 60 },
  { map = 230, name = "Blackrock Depths - Prison", kind = "dungeon", minLevel = 45, maxLevel = 60 },
  { map = 249, name = "Onyxia's Lair", kind = "raid", minLevel = 80, maxLevel = 80 },
  { map = 269, name = "The Black Morass", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 289, name = "Scholomance", kind = "dungeon", minLevel = 100, maxLevel = 100 },
  { map = 309, name = "Zul'Gurub", kind = "raid", minLevel = 56, maxLevel = 80 },
  { map = 329, name = "Stratholme - Main Gate", kind = "dungeon", minLevel = 45, maxLevel = 60 },
  { map = 349, name = "Maraudon - Orange Crystals", kind = "dungeon", minLevel = 35, maxLevel = 59 },
  { map = 389, name = "Ragefire Chasm", kind = "dungeon", minLevel = 15, maxLevel = 59 },
  { map = 409, name = "Molten Core", kind = "raid", minLevel = 60, maxLevel = 80 },
  { map = 429, name = "Dire Maul - East", kind = "dungeon", minLevel = 45, maxLevel = 60 },
  { map = 469, name = "Blackwing Lair", kind = "raid", minLevel = 60, maxLevel = 80 },
  { map = 509, name = "Ahn'Qiraj Ruins", kind = "raid", minLevel = 60, maxLevel = 80 },
  { map = 531, name = "Ahn'Qiraj Temple", kind = "raid", minLevel = 60, maxLevel = 80 },
  { map = 532, name = "Karazhan", kind = "raid", minLevel = 70, maxLevel = 80 },
  { map = 533, name = "Naxxramas", kind = "raid", minLevel = 80, maxLevel = 80 },
  { map = 534, name = "Hyjal Past", kind = "raid", minLevel = 70, maxLevel = 80 },
  { map = 535, name = "Naxxramas", kind = "raid", minLevel = 80, maxLevel = 80 },
  { map = 540, name = "Shattered Halls", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 542, name = "Blood Furnace", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 543, name = "Hellfire Ramparts", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 544, name = "Magtheridon's Lair", kind = "raid", minLevel = 70, maxLevel = 80 },
  { map = 545, name = "The Steamvault", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 546, name = "Underbog", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 547, name = "Slave Pens", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 548, name = "Serpentshrine Cavern", kind = "raid", minLevel = 70, maxLevel = 80 },
  { map = 550, name = "Tempest Keep", kind = "raid", minLevel = 70, maxLevel = 80 },
  { map = 552, name = "The Arcatraz", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 553, name = "The Botanica", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 554, name = "The Mechanar", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 555, name = "Shadow Labyrinth", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 556, name = "Sethekk Halls", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 557, name = "Mana-Tombs", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 558, name = "Auchenai Crypts", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 560, name = "The Escape From Durnholde", kind = "dungeon", minLevel = 58, maxLevel = 70 },
  { map = 564, name = "Black Temple", kind = "raid", minLevel = 70, maxLevel = 80 },
  { map = 565, name = "Gruul's Lair", kind = "raid", minLevel = 70, maxLevel = 80 },
  { map = 568, name = "Zul'Aman", kind = "raid", minLevel = 70, maxLevel = 80 },
  { map = 574, name = "Utgarde Keep", kind = "dungeon", minLevel = 71, maxLevel = 80 },
  { map = 575, name = "Utgarde Pinnacle", kind = "dungeon", minLevel = 77, maxLevel = 80 },
  { map = 576, name = "The Nexus", kind = "dungeon", minLevel = 71, maxLevel = 80 },
  { map = 578, name = "The Oculus", kind = "dungeon", minLevel = 77, maxLevel = 80 },
  { map = 580, name = "The Sunwell", kind = "raid", minLevel = 70, maxLevel = 80 },
  { map = 585, name = "Magisters' Terrace", kind = "dungeon", minLevel = 100, maxLevel = 100 },
  { map = 595, name = "The Culling of Stratholme", kind = "dungeon", minLevel = 77, maxLevel = 80 },
  { map = 599, name = "Halls of Stone", kind = "dungeon", minLevel = 75, maxLevel = 80 },
  { map = 600, name = "Drak'Tharon Keep", kind = "dungeon", minLevel = 72, maxLevel = 80 },
  { map = 601, name = "Azjol-Nerub", kind = "dungeon", minLevel = 71, maxLevel = 80 },
  { map = 602, name = "Halls of Lightning", kind = "dungeon", minLevel = 77, maxLevel = 80 },
  { map = 603, name = "Ulduar", kind = "raid", minLevel = 80, maxLevel = 80 },
  { map = 604, name = "Gundrak", kind = "dungeon", minLevel = 74, maxLevel = 80 },
  { map = 608, name = "Violet Hold", kind = "dungeon", minLevel = 73, maxLevel = 80 },
  { map = 615, name = "The Obsidian Sanctum", kind = "raid", minLevel = 80, maxLevel = 80 },
  { map = 616, name = "The Eye of Eternity", kind = "raid", minLevel = 80, maxLevel = 80 },
  { map = 619, name = "Ahn'kahet: The Old Kingdom", kind = "dungeon", minLevel = 71, maxLevel = 80 },
  { map = 624, name = "Vault of Archavon", kind = "raid", minLevel = 80, maxLevel = 80 },
  { map = 631, name = "Icecrown Citadel", kind = "raid", minLevel = 80, maxLevel = 80 },
  { map = 632, name = "The Forge of Souls", kind = "dungeon", minLevel = 80, maxLevel = 80 },
  { map = 645, name = "Blackrock Caverns", kind = "dungeon", minLevel = 35, maxLevel = 60 },
  { map = 649, name = "Trial of the Grand Crusader", kind = "raid", minLevel = 80, maxLevel = 80 },
  { map = 650, name = "Trial of the Champion", kind = "dungeon", minLevel = 80, maxLevel = 80 },
  { map = 658, name = "Pit of Saron", kind = "dungeon", minLevel = 80, maxLevel = 80 },
  { map = 668, name = "Halls of Reflection", kind = "dungeon", minLevel = 80, maxLevel = 80 },
  { map = 724, name = "Ruby Sanctum", kind = "raid", minLevel = 80, maxLevel = 80 },
  { map = 880, name = "Setis (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 881, name = "Azuregos (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 888, name = "Lethon (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 889, name = "Korrim Snowgrave (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 890, name = "Atal'Zul", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 891, name = "Kaldros Depthbreaker (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 908, name = "The Frozen Reach", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 936, name = "Vaults of Inquisition", kind = "dungeon", minLevel = 15, maxLevel = 59, lfgOff = true, src = "server-sql" },
  { map = 937, name = "Road to De Other Side", kind = "dungeon", minLevel = 15, maxLevel = 59, lfgOff = true, src = "server-sql" },
  { map = 973, name = "Emeriss (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 974, name = "Emeriss (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 975, name = "Emeriss (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 976, name = "Emeriss (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 986, name = "Taerar (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 987, name = "Taerar (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 988, name = "Taerar (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 989, name = "Taerar (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 990, name = "Ysondre (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 991, name = "Ysondre (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 992, name = "Ysondre (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 993, name = "Ysondre (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 994, name = "Lethon (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 995, name = "Lethon (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 996, name = "Lethon (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 997, name = "Lethon (PvE)", kind = "raid", minLevel = 81, maxLevel = 81 },
  { map = 1781, name = "Forgotten Mine", kind = "dungeon", minLevel = 25, maxLevel = 59 },
  { map = 1912, name = "Tor'Watha", kind = "dungeon", minLevel = 23, maxLevel = 60 },
}

-- Names disagree between the client and the DBC on three things only: a
-- leading "The", a " - <wing>" tail, and punctuation. Both sides go through
-- this first, so "The Deadmines" finds "Deadmines", and "Scarlet Monastery"
-- finds "Scarlet Monastery - Graveyard".
local function Normalise(name)
  if type(name) ~= "string" then return nil end
  local text = name:lower()
  text = text:gsub("%s+%-%s+.*$", "")
  text = text:gsub("^the%s+", "")
  text = text:gsub("[^%w%s]", "")
  text = text:gsub("%s+", " ")
  return (text:gsub("^%s+", ""))
end

local dungeonIndex
local function DungeonIndex()
  if dungeonIndex then return dungeonIndex end
  dungeonIndex = {}
  for _, entry in ipairs(CoA.dungeons) do
    local key = Normalise(entry.name)
    if key and key ~= "" and not dungeonIndex[key] then dungeonIndex[key] = entry end
  end
  return dungeonIndex
end

-- One entry for an instance or zone name, or for a Map.dbc id; nil when the
-- name is not one of the 103. Callers should treat nil as "not a dungeon I
-- know" rather than as an error: the client's own name is still usable.
function CoA.Dungeon(key)
  if type(key) == "number" then
    for _, entry in ipairs(CoA.dungeons) do
      if entry.map == key then return entry end
    end
    return nil
  end
  local normalised = Normalise(key)
  if not normalised or normalised == "" then return nil end
  return DungeonIndex()[normalised]
end

-- Lazy readers. Everything below tolerates ns.CoA / the client globals being
-- absent, so a Core file may call them from any load stage.

function CoA.Class(id)
  return id and CoA.classes[id] or nil
end

-- Token -> class entry (the token is what UnitClass returns second).
function CoA.ClassByToken(token)
  if not token then return nil end
  for _, entry in pairs(CoA.classes) do
    if entry.token == token then return entry end
  end
end

-- The class colour the client itself uses for this token.
function CoA.ClassColor(token)
  local colors = RAID_CLASS_COLORS
  if not colors or not token then return nil end
  return colors[token]
end

-- Localised name when the localisation owner has filled it, else English.
-- Dungeon rows carry no zh of their own: the localisation table is keyed by the
-- same English names and is consulted HERE, lazily, instead of pre-filling the
-- 103 rows (a name this build does not know stays English, and the wing rule
-- inside CoA.zhName still resolves "X - Wing" names). CoA.zhName is read at call
-- time because Locales/ and Capture/ load after Core/.
function CoA.Name(entry)
  local kind = type(entry)
  if kind == "string" then
    return (CoA.zhName and CoA.zhName(entry)) or entry
  end
  if kind ~= "table" then return entry end
  -- A row's own `zh` is Chinese text written here, with no other language's
  -- column to fall back on (the DBCs carry no zh either), so it is used only
  -- for a reader whose language is Chinese; every other locale gets the
  -- client's English name from `name` below, like every other string.
  local zh = entry.zh
  if zh and zh ~= "" and ns.Locale and ns.Locale.Is("zhCN") then return zh end
  local name = entry.name
  if name and CoA.zhName then
    local localised = CoA.zhName(name)
    if localised and localised ~= "" then return localised end
  end
  return name
end

function CoA.Battleground(name)
  return name and CoA.battlegrounds[name] or nil
end

function CoA.Reachable(entry)
  if type(entry) ~= "table" then return false end
  if entry.lfgOff then return false end
  return (entry.minLevel or 999) <= CoA.maxLevel
end

-- Reader-facing name lookup for the client's English names. The tables are
-- built by Locales/zhCN/Names.lua, which loads before this file, so re-hang
-- them here rather than letting ns.CoA = CoA above drop them. Display only:
-- the diary keeps the client's English names in what it saves.
local names = ns.Locale and ns.Locale.CoA
if names then
  -- CoA.Name() consults these lazily for every entry, so nothing is copied into
  -- the data tables here (no pre-filled zh on the 103 dungeon rows).
  CoA.zhNames, CoA.enNames = names.zhNames, names.enNames
  CoA.zhName, CoA.enName = names.zhName, names.enName
  CoA.todoNames = names.todoNames
end

ns._test = ns._test or {}
ns._test.CoA = CoA
