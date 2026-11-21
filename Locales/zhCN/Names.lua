local addonName, ns = ...

-- 名字对照：把客户端（enUS）给出的英文名，在**显示时**换成中文。
-- 只在 zhCN 下生效。
if not ns.Locale.Is("zhCN") then return end

-- 关键约束（lead 定）：这张表只给显示用，**绝不**用于写存档、比较或索引。
-- 存档里永远留客户端给的英文原名（区域身份、地图 id、职业名都是客户端的数据）；
-- 显示时调 zhName() 临时翻译。这样换语言时存档依然有效。
--
-- 数据来源：
--   * Map.dbc / AreaTable.dbc / ChrClasses.dbc 的英文名（enUS 客户端）；
--   * 有官方简体中文名的内容按官方译名写（3.3.5a 及以后被移植过来的地图也算）；
--   * CoA 自创内容没有中文来源（客户端 zhCN 词条列是空的，见 Locales/zhCN/CoA.lua
--     文件头），一律不编：不进表，zhName() 原样返回英文，并在本文件末尾的
--     TODO 名单里列出来等社区译名。
local CoA = ns.Locale.CoA or {}
ns.Locale.CoA = CoA

-- 英文名 -> 中文名。比的是客户端原文，别改英文字面量。
-- 与 Locales/zhCN/CoA.lua 的关系：那边是按 Map.dbc / ChrClasses 的 id 查的
-- 表，这边按英文名查；同一张地图在两个文件里都有中文名，改译名要两处一起改
-- （探针 probe_overlap.lua 会比两表的分歧，当前为 0）。
CoA.zhNames = {
    -- 大陆
    ["Eastern Kingdoms"] = "东部王国",
    ["Kalimdor"] = "卡利姆多",
    ["Outland"] = "外域",
    ["Northrend"] = "诺森德",
    ["Twisting Nether"] = "扭曲虚空",
    ["The Twisting Nether"] = "扭曲虚空",
    ["Emerald Dream"] = "翡翠梦境",
    -- 主城与城市区
    ["Stormwind"] = "暴风城",
    ["Stormwind City"] = "暴风城",
    ["Orgrimmar"] = "奥格瑞玛",
    ["Ironforge"] = "铁炉堡",
    ["Darnassus"] = "达纳苏斯",
    ["Exodar"] = "埃索达",
    ["Thunder Bluff"] = "雷霆崖",
    ["Undercity"] = "幽暗城",
    -- CoA 的 WorldMapArea.dbc 把这三个拼成了别的样子（少空格、少一个字母），
    -- 客户端自己报出来的就是这一串，所以按原文各补一条。
    ["Ogrimmar"] = "奥格瑞玛",
    ["ThunderBluff"] = "雷霆崖",
    ["Darnassis"] = "达纳苏斯",
    -- 本客户端里「东部王国」的整块世界地图 DBC 名字就是 Azeroth。
    ["Azeroth"] = "东部王国",
    ["Silvermoon City"] = "银月城",
    ["Shattrath City"] = "沙塔斯城",
    ["Dalaran"] = "达拉然",
    ["Deeprun Tram"] = "矿道地铁",
    -- 经典副本与团队
    ["Shadowfang Keep"] = "影牙城堡",
    ["Stormwind Stockade"] = "暴风城监狱",
    ["Deadmines"] = "死亡矿井",
    ["The Deadmines"] = "死亡矿井",
    ["Wailing Caverns"] = "哀嚎洞穴",
    ["Razorfen Kraul"] = "剃刀沼泽",
    ["Blackfathom Deeps"] = "黑暗深渊",
    ["Uldaman"] = "奥达曼",
    ["Gnomeregan"] = "诺莫瑞根",
    ["Sunken Temple"] = "沉没的神庙",
    ["The Temple of Atal'Hakkar"] = "阿塔哈卡神庙",
    ["Razorfen Downs"] = "剃刀高地",
    ["Scarlet Monastery"] = "血色修道院",
    ["Zul'Farrak"] = "祖尔法拉克",
    ["Blackrock Spire"] = "黑石塔",
    ["Blackrock Depths"] = "黑石深渊",
    ["Onyxia's Lair"] = "奥妮克希亚的巢穴",
    ["Opening of the Dark Portal"] = "黑暗之门的开启",
    ["Scholomance"] = "通灵学院",
    ["Zul'Gurub"] = "祖尔格拉布",
    ["Stratholme"] = "斯坦索姆",
    ["Maraudon"] = "玛拉顿",
    ["Ragefire Chasm"] = "怒焰裂谷",
    ["Molten Core"] = "熔火之心",
    ["Dire Maul"] = "厄运之槌",
    ["Blackwing Lair"] = "黑翼之巢",
    ["Ruins of Ahn'Qiraj"] = "安其拉废墟",
    ["Ahn'Qiraj Temple"] = "安其拉神殿",
    ["Naxxramas"] = "纳克萨玛斯",
    ["The Battle for Mount Hyjal"] = "海加尔山之战",
    ["Karazhan"] = "卡拉赞",
    ["Monastery"] = "修道院",
    -- 燃烧的远征
    ["Hellfire Citadel: Ramparts"] = "地狱火堡垒：地狱火城墙",
    ["Hellfire Citadel: The Blood Furnace"] = "地狱火堡垒：鲜血熔炉",
    ["Hellfire Citadel: The Shattered Halls"] = "地狱火堡垒：破碎大厅",
    ["Hellfire Ramparts"] = "地狱火城墙",
    ["The Blood Furnace"] = "鲜血熔炉",
    ["The Shattered Halls"] = "破碎大厅",
    ["Magtheridon's Lair"] = "玛瑟里顿的巢穴",
    ["Coilfang: The Slave Pens"] = "盘牙水库：奴隶围栏",
    ["Coilfang: The Underbog"] = "盘牙水库：幽暗沼泽",
    ["Coilfang: The Steamvault"] = "盘牙水库：蒸汽地窟",
    ["Coilfang: Serpentshrine Cavern"] = "盘牙水库：毒蛇神殿",
    ["The Slave Pens"] = "奴隶围栏",
    ["The Underbog"] = "幽暗沼泽",
    ["The Steamvault"] = "蒸汽地窟",
    ["Serpentshrine Cavern"] = "毒蛇神殿",
    ["Tempest Keep"] = "风暴要塞",
    ["Tempest Keep: The Mechanar"] = "风暴要塞：能源舰",
    ["Tempest Keep: The Botanica"] = "风暴要塞：生态船",
    ["Tempest Keep: The Arcatraz"] = "风暴要塞：禁魔监狱",
    ["The Mechanar"] = "能源舰",
    ["The Botanica"] = "生态船",
    ["The Arcatraz"] = "禁魔监狱",
    ["Auchindoun: Auchenai Crypts"] = "奥金顿：奥金尼地穴",
    ["Auchindoun: Mana-Tombs"] = "奥金顿：法力陵墓",
    ["Auchindoun: Sethekk Halls"] = "奥金顿：塞泰克大厅",
    ["Auchindoun: Shadow Labyrinth"] = "奥金顿：暗影迷宫",
    ["Auchenai Crypts"] = "奥金尼地穴",
    ["Mana-Tombs"] = "法力陵墓",
    ["Sethekk Halls"] = "塞泰克大厅",
    ["Shadow Labyrinth"] = "暗影迷宫",
    ["The Escape From Durnholde"] = "逃离敦霍尔德",
    ["Black Temple"] = "黑暗神殿",
    ["Gruul's Lair"] = "格鲁尔的巢穴",
    ["Zul'Aman"] = "祖阿曼",
    ["The Sunwell"] = "太阳之井",
    ["Sunwell Plateau"] = "太阳之井高地",
    ["Magister's Terrace"] = "魔导师平台",
    -- 巫妖王之怒
    ["Utgarde Keep"] = "乌特加德城堡",
    ["Utgarde Pinnacle"] = "乌特加德之巅",
    ["The Nexus"] = "魔枢",
    ["The Oculus"] = "魔环",
    ["The Culling of Stratholme"] = "净化斯坦索姆",
    ["Halls of Stone"] = "岩石大厅",
    ["Drak'Tharon Keep"] = "达克萨隆要塞",
    ["Azjol-Nerub"] = "艾卓-尼鲁布",
    ["Halls of Lightning"] = "闪电大厅",
    ["Ulduar"] = "奥杜尔",
    ["Gundrak"] = "古达克",
    ["Violet Hold"] = "紫罗兰监狱",
    ["Ebon Hold"] = "黑锋要塞",
    ["The Obsidian Sanctum"] = "黑曜石圣殿",
    ["The Eye of Eternity"] = "永恒之眼",
    ["Ahn'kahet: The Old Kingdom"] = "安卡赫特：古代王国",
    ["Vault of Archavon"] = "阿尔卡冯的宝库",
    ["Icecrown Citadel"] = "冰冠堡垒",
    ["The Forge of Souls"] = "灵魂洪炉",
    ["Trial of the Crusader"] = "十字军的试炼",
    ["Trial of the Champion"] = "冠军的试炼",
    ["Pit of Saron"] = "萨隆矿坑",
    ["Halls of Reflection"] = "映像大厅",
    ["The Ruby Sanctum"] = "红玉圣殿",
    -- 战场与竞技场
    ["Alterac Valley"] = "奥特兰克山谷",
    ["Warsong Gulch"] = "战歌峡谷",
    ["Arathi Basin"] = "阿拉希盆地",
    ["Eye of the Storm"] = "风暴之眼",
    ["Strand of the Ancients"] = "远古海滩",
    ["Isle of Conquest"] = "征服之岛",
    ["Twin Peaks"] = "双子峰",
    ["Nagrand Arena"] = "纳格兰竞技场",
    ["Blade's Edge Arena"] = "刀锋山竞技场",
    ["Ruins of Lordaeron"] = "洛丹伦废墟",
    ["Dalaran Sewers"] = "达拉然下水道",
    ["The Ring of Valor"] = "勇气竞技场",
    -- 后续资料片移植进客户端的内容（官方中文名）
    ["Halls of Origination"] = "起源大厅",
    ["Blackrock Caverns"] = "黑石洞穴",
    ["The Vortex Pinnacle"] = "旋云之巅",
    ["Throne of the Four Winds"] = "四风王座",
    ["Lost City of the Tol'vir"] = "托尔维尔的失落之城",
    ["Baradin Hold"] = "巴拉丁监狱",
    ["Temple of Kotmogu"] = "寇魔古寺",
    ["Black Rook Hold Arena"] = "黑鸦堡垒竞技场",
    -- 区域（客户端 AreaTable 的名字；副本化的区域也用同一张表）
    ["Alterac Mountains"] = "奥特兰克山脉",
    ["Arathi Highlands"] = "阿拉希高地",
    ["Ashenvale"] = "灰谷",
    ["Azshara"] = "艾萨拉",
    ["Badlands"] = "荒芜之地",
    ["Blasted Lands"] = "诅咒之地",
    ["Burning Steppes"] = "燃烧平原",
    ["Darkshore"] = "黑海岸",
    ["Deadwind Pass"] = "逆风小径",
    ["Desolace"] = "凄凉之地",
    ["Dun Morogh"] = "丹莫罗",
    ["Durotar"] = "杜隆塔尔",
    ["Duskwood"] = "暮色森林",
    ["Dustwallow Marsh"] = "尘泥沼泽",
    ["Eastern Plaguelands"] = "东瘟疫之地",
    ["Elwynn Forest"] = "艾尔文森林",
    ["Felwood"] = "费伍德森林",
    ["Feralas"] = "菲拉斯",
    ["Ghostlands"] = "幽魂之地",
    ["Hillsbrad Foothills"] = "希尔斯布莱德丘陵",
    ["Loch Modan"] = "洛克莫丹",
    ["Mulgore"] = "莫高雷",
    ["Moonglade"] = "月光林地",
    ["Redridge Mountains"] = "赤脊山",
    ["Searing Gorge"] = "灼热峡谷",
    ["Silithus"] = "希利苏斯",
    ["Silverpine Forest"] = "银松森林",
    ["Stonetalon Mountains"] = "石爪山脉",
    ["Stranglethorn Vale"] = "荆棘谷",
    ["Swamp of Sorrows"] = "悲伤沼泽",
    ["Tanaris"] = "塔纳利斯",
    ["Teldrassil"] = "泰达希尔",
    ["The Barrens"] = "贫瘠之地",
    ["Thousand Needles"] = "千针石林",
    ["Tirisfal Glades"] = "提瑞斯法林地",
    ["Un'Goro Crater"] = "安戈洛环形山",
    ["Western Plaguelands"] = "西瘟疫之地",
    ["Westfall"] = "西部荒野",
    ["Wetlands"] = "湿地",
    ["Winterspring"] = "冬泉谷",
    ["Azuremyst Isle"] = "秘蓝岛",
    ["Bloodmyst Isle"] = "秘血岛",
    ["Eversong Woods"] = "永歌森林",
    ["Isle of Quel'Danas"] = "奎尔丹纳斯岛",
    ["Hellfire Peninsula"] = "地狱火半岛",
    ["Zangarmarsh"] = "赞加沼泽",
    ["Terokkar Forest"] = "泰罗卡森林",
    ["Nagrand"] = "纳格兰",
    ["Blade's Edge Mountains"] = "刀锋山",
    ["Netherstorm"] = "虚空风暴",
    ["Shadowmoon Valley"] = "影月谷",
    ["Borean Tundra"] = "北风苔原",
    ["Howling Fjord"] = "嚎风峡湾",
    ["Dragonblight"] = "龙骨荒野",
    ["Grizzly Hills"] = "灰熊丘陵",
    ["Zul'Drak"] = "祖达克",
    ["Sholazar Basin"] = "索拉查盆地",
    ["Crystalsong Forest"] = "晶歌森林",
    ["The Storm Peaks"] = "风暴峭壁",
    ["Icecrown"] = "冰冠冰川",
    ["Darkwhisper Gorge"] = "暗语峡谷",
}
-- 职业名。3.3.5 的 UnitClass() 返回**本地化**职业名，enUS 客户端给英文原文，
-- 所以键还是英文；查表同样只在显示时做。
local classes = {
    ["Warrior"] = "战士",
    ["Paladin"] = "圣骑士",
    ["Hunter"] = "猎人",
    ["Rogue"] = "潜行者",
    ["Priest"] = "牧师",
    ["Death Knight"] = "死亡骑士",
    ["Shaman"] = "萨满祭司",
    ["Mage"] = "法师",
    ["Warlock"] = "术士",
    ["Hero"] = "英雄",
    ["Druid"] = "德鲁伊",
    ["Barbarian"] = "野蛮人",
    ["Witch Doctor"] = "巫医",
    ["Felsworn"] = "魔誓者",
    ["Witch Hunter"] = "猎巫人",
    ["Stormbringer"] = "风暴使者",
    ["Knight of Xoroth"] = "克索罗斯骑士",
    ["Guardian"] = "守卫者",
    ["Templar"] = "圣堂武士",
    ["Bloodmage"] = "血法师",
    ["Ranger"] = "游侠",
    ["Chronomancer"] = "时空法师",
    ["Necromancer"] = "死灵法师",
    ["Pyromancer"] = "火法师",
    ["Cultist"] = "邪教徒",
    ["Starcaller"] = "唤星者",
    ["Sun Cleric"] = "太阳牧师",
    ["Tinker"] = "机械师",
    ["Venomancer"] = "毒术师",
    ["Reaper"] = "收割者",
    ["Primalist"] = "原初者",
    ["Runemaster"] = "符文师",
}
for english, chinese in pairs(classes) do
    CoA.zhNames[english] = chinese
end

-- 副本的翼名（Dungeons.Name 会给 "Scarlet Monastery - Library" 这种串）。
-- 只有主名和翼名都在表里时 zhName 才拼出中文，否则保留英文那半边。
local wings = {
    ["Library"] = "图书馆",
    ["Armory"] = "军械库",
    ["Cathedral"] = "大教堂",
    ["Graveyard"] = "墓地",
    ["The Deadmines"] = "死亡矿井",
}
for english, chinese in pairs(wings) do
    CoA.zhNames[english] = chinese
end

-- CoA 可达副本与团队的短名：Capture/CoA.lua 的 CoA.dungeons 用的是这些短名
-- （服务器等级上限 60，103 条里只有 38 条能进，这几条就是其中原本没对上的）。
-- 带 " - " 的翼名写成整串，免得靠上面那条拆分规则去猜措辞。
local dungeons = {
    ["Lower Blackrock Spire"] = "黑石塔下层",
    ["Blackrock Depths - Prison"] = "黑石深渊 - 监狱",
    ["Stratholme - Main Gate"] = "斯坦索姆 - 正门",
    ["Maraudon - Orange Crystals"] = "玛拉顿 - 橙色水晶",
    ["Dire Maul - East"] = "厄运之槌 - 东",
    ["The Black Morass"] = "黑色沼泽",
    ["Shattered Halls"] = "破碎大厅",
    ["Blood Furnace"] = "鲜血熔炉",
    ["Underbog"] = "幽暗沼泽",
    ["Slave Pens"] = "奴隶围栏",
    ["The Escape From Durnholde"] = "逃离敦霍尔德城堡",
    ["Ahn'Qiraj Ruins"] = "安其拉废墟",
}
for english, chinese in pairs(dungeons) do
    CoA.zhNames[english] = chinese
end

-- 名字 -> 名字。反向表给设置页的搜索/排序用（输入中文也能找到条目）。
-- 同一个中文名出现两次时保留先出现的那条，避免覆盖掉更有代表性的英文。
CoA.enNames = {}
for english, chinese in pairs(CoA.zhNames) do
    if CoA.enNames[chinese] == nil then
        CoA.enNames[chinese] = english
    end
end

-- 显示时翻译一个名字。**永远返回字符串**，查不到就原样返回，
-- 所以调用点可以放心地写 SetText(zhName(x))，不需要判空。
-- text 不是字符串（nil、数字、表）时原样返回，交给调用点自己处理。
function CoA.zhName(text)
    if type(text) ~= "string" or text == "" then return text end

    local direct = CoA.zhNames[text]
    if direct then return direct end

    -- 有些地图名带资料片前缀，例如 Tempest Keep: The Arcatraz、
    -- Hellfire Citadel: The Shattered Halls。两半各自查，查不到的那半保留英文。
    local left, right = text:match("^(.-)%s*:%s*(.+)$")
    if left then
        local knownLeft, knownRight = CoA.zhNames[left], CoA.zhNames[right]
        if knownLeft or knownRight then
            return (knownLeft or left) .. "：" .. (knownRight or right)
        end
    end

    -- 副本名带翼名，例如 Scarlet Monastery - Library。
    local wingLeft, wingRight = text:match("^(.-)%s+%-%s+(.+)$")
    if wingLeft then
        local knownLeft, knownRight = CoA.zhNames[wingLeft], CoA.zhNames[wingRight]
        if knownLeft or knownRight then
            return (knownLeft or wingLeft) .. " - " .. (knownRight or wingRight)
        end
    end

    return text
end

-- 显示一个名字的英文原名（给「对照原文」这类地方用）。查不到返回原值。
function CoA.enName(text)
    if type(text) ~= "string" then return text end
    return CoA.enNames[text] or text
end

-- 已知没有中文来源的名字。**故意不翻**：只留客户端 DBC 也查不到的少数几个。
--
-- 更正（2026-11-21）：客户端 Data\patch-ZH.mpq 把 Map.dbc 与 BattlemasterList.dbc
-- 的名字列写成了简体中文，所以 CoA 自创的副本、战场、竞技场、地图名现在都从
-- 客户端抄（Locales/zhCN/Maps.lua，生成器 tools/dbc_maps.py），不再自己造译名。
-- 这里只剩 DBC 里也没有的：服务端 SQL 独有的副本名、对不上 DBC 的拼写与占位串。
CoA.todoNames = {
    -- 服务端 SQL 有、客户端 DBC 里没有
    "Vaults of Inquisition",
    -- 客户端也没有中文列的
    "Druk'Thar", "Skywall",
    -- 占位串（不是地图名）
    "InstanceName",
}

-- 让 UI 侧也能直接拿：ns.CoA 是 features-port 的主源，这里只挂显示用的名字，
-- 不覆盖他已写好的 classes/battlegrounds/dungeons（用 or 保留）。
local root = ns.CoA or {}
ns.CoA = root
root.zhNames = root.zhNames or CoA.zhNames
root.enNames = root.enNames or CoA.enNames
root.zhName = root.zhName or CoA.zhName
root.enName = root.enName or CoA.enName
root.todoNames = root.todoNames or CoA.todoNames
