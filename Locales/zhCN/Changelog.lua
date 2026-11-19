local addonName, ns = ...

-- 更新日志的中文，只在这本书用中文时才挂上去。
if not ns.Locale.Is("zhCN") then return end

-- Core/ChangelogData.lua 是 CHANGELOG.md 的逐字副本（tests/changelog.lua 盯着
-- 这条），所以那份数据一律保持英文；这里只存**显示时**查的中文，页面画到那
-- 一行时再换成中文（UI/Settings/Sections/Changelog.lua:65-71 的 ChangelogZh
-- 帮助函数负责调用；它查不到或出错时原样显示英文）。
--
-- 表里的键与下标，必须与 Core/ChangelogData.lua 的结构严格对应：
--   * 外层键是 release 的 version 字符串（"4.2.0"、"4.1.1"…），版本号对不上
--     就整份回落英文，不会拿错行；
--   * [0] 是那条 release 的 summary；
--   * [1] 起的下标，按**页面从上到下的顺序**数文字项：每个分组里先一条
--     entry，紧接着它自己的每条 sub，然后才轮到下一条 entry（与
--     UI/Settings/Sections/Changelog.lua:174-188 的 item 计数器同步）。
--     分组的 heading 不占下标（那是另有一套 L 词条）。
-- 所以改动 Core/ChangelogData.lua 的条目顺序（比如上游加了一条）时，这里
-- 的 [n] 也要跟着挪，否则会把中文错位到另一条上面。
local Table = {
    ["4.2.0"] = {
        [0] = "这次更新给日记带来了巴西葡萄牙语。",
        [1] = "日记的语言设置里加入了巴西葡萄牙语",
    },
    ["4.1.1"] = {
        [0] = "一次小更新：预设标签现在会说你的语言；假死和自我治疗不再在日记里留下虚假的死亡和_死里逃生_。",
        [1] = "预设标签现在以你的语言显示",
        [2] = "假死不再计作死亡",
        [3] = "自我治疗不再误记_死里逃生_",
    },
    ["4.1.0"] = {
        [0] = "这次更新给_你的日记_添了一件让人兴奋的新东西：装备更新！每当你装备上一件更好的物品，它就会被写下来。只是试穿不会触发。双手武器换成两把单手武器这类情况可能还有些别扭，遇到问题请报告！日记现在还能选择自动添加你经常遇到的人。",
        [1] = "_你的日记_现在能看出你为身上装备换的升级，并显示在日记的图版上",
        [2] = "日记的语言设置里加入了波兰语",
        [3] = "现在可以让日记自动添加你常遇到的人，以及和你一起打副本和团队副本的人",
    },
    ["4.0.2"] = {
        [0] = "手柄界面的一处热修复：打开玩家菜单会把控制器锁住。目前用手柄游玩时，请用「记录」按键或宏来添加玩家。",
        [1] = "用手柄界面时，玩家菜单不再锁住控制器",
        [2] = "日记的那一项暂时从该菜单中拿掉",
        [3] = "德语地区名现在会带上冠词和格变化",
    },
    ["4.0.1"] = {
        [0] = "这次更新加入了简体中文支持，另外还修了几个问题。",
        [1] = "加入了简体中文支持",
        [2] = "任务物品的狩猎现在更容易_走运_：只需预期击杀数的一半，而不再是八分之一",
        [3] = "在韩语和中文客户端里，不断行空格的位置不再出现方块字或豆腐块",
        [4] = "对 ruRU 的语言修正",
    },

}

ns.Locale.ChangelogZhTable = Table

-- 页面要的那一句；查不到就给回英文原文。永远返回字符串，永不 nil，
-- 也不让调用方去处理「这一条还没翻」的情形。
function ns.Locale.ChangelogZh(version, index, fallback)
    local release = type(version) == "string" and Table[version]
    if not release then return fallback end
    local said = type(index) == "number" and release[index]
    if type(said) ~= "string" or said == "" then return fallback end
    return said
end
