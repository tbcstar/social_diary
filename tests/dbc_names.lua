-- Names the client itself knows in Chinese.
--
-- Data\patch-ZH.mpq rewrites DBFilesClient and writes simplified Chinese into the
-- DBC name column, so the class names (ChrClasses), race names (ChrRaces) and
-- the map, instance, battleground and arena names (Map, BattlemasterList) are
-- copied from the client rather than invented here. Locales/zhCN/Maps.lua is
-- generated from the last two tables by tools/dbc_maps.py; Capture/CoA.lua
-- carries the first two by hand.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq

-- This client reports enUS; the diary reads Chinese only when that is the choice.
local saved = rawget(_G, "SocialDiaryDB")
_G.SocialDiaryDB = { settings = { language = "zhCN" } }
local ns = T.Load()
_G.SocialDiaryDB = saved
Eq(ns.Locale.id, "zhCN", "the diary is not reading Chinese")

local CoA = ns.CoA
Check(CoA and CoA.zhName and CoA.RaceName, "the name lookups are not installed")

Section("class names are the client's own")

local classes = 0
for _ in pairs(CoA.classes) do classes = classes + 1 end
Eq(classes, 32, "the class table no longer holds every CoA class")
Eq(CoA.Name(CoA.classes[1]), "战士", "a classic class is not named in Chinese")
Eq(CoA.Name(CoA.classes[14]), "恶魔猎手", "a CoA class is not named the way the client names it")
Eq(CoA.Name(CoA.classes[32]), "符文大师", "the last CoA class is not named in Chinese")

Section("race names come from ChrRaces.dbc")

Eq(CoA.races[5].zh, "亡灵", "the undead race lost its client name")
Eq(CoA.RaceName("Scourge"), "亡灵", "a race token does not resolve to its Chinese name")
Eq(CoA.RaceName("Undead"), "亡灵", "a race name does not resolve to its Chinese name")
Eq(CoA.RaceName(nil, 4), "暗夜精灵", "a race id does not resolve to its Chinese name")
Eq(CoA.RaceName("Vulpera"), "狐人", "a CoA race is not named in Chinese")
Eq(CoA.RaceName("Wombat"), "Wombat", "a race this table does not carry was renamed")

Section("instances, battlegrounds and arenas from Map.dbc and BattlemasterList.dbc")

Eq(CoA.zhName("Maldraxxus Coliseum"), "玛卓克萨斯竞技场", "a CoA arena is still English")
Eq(CoA.zhName("Nagrand Arena HD"), "纳格兰竞技场HD版", "a CoA arena is still English")
Eq(CoA.zhName("The Tiger's Peak"), "虎踞峰", "a CoA arena is still English")
Eq(CoA.zhName("FFA BG"), "自由混战战场", "a CoA battleground is still English")
Eq(CoA.Name(CoA.battlegrounds["Maldraxxus Coliseum"]), "玛卓克萨斯竞技场",
   "a battleground row with no hand-written name is not translated")
Eq(CoA.zhName("Shadowfang Keep"), "影牙城堡", "a classic instance lost its name")
Eq(CoA.zhName("Scarlet Monastery - Graveyard"), "血色修道院 - 墓地",
   "the wing rule no longer composes a name the client only stores in two halves")

Section("a hand-written name still wins over the client's")

Eq(CoA.zhName("Blackrock Spire"), "黑石塔", "the client's own spelling replaced ours")
Eq(CoA.zhName("Arathi Basin"), "阿拉希盆地", "a classic battleground lost its name")
Eq(CoA.Map(229), "黑石塔", "a hand-written map id was replaced by the generated one")

Section("the generated id table fills in the gaps")

local maps = 0
for _ in pairs(CoA.maps) do maps = maps + 1 end
Check(maps > 300, "the generated map ids are not loaded (" .. maps .. ")")
Eq(CoA.Map(1911), "阿肯城废墟", "an id only the client knows has no name")
