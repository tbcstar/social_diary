# 汉化体检：硬编码英文 + 显示期的名字接入点

扫描对象：`D:\DSH-source\social_diary_coa\social_diary\` 的 Core/、UI/、Features/、Capture/、Dev/ 与根目录 Lua 文件（不含 Locales/）。
本文两件事：**第二节**是 lead 要的「显示期接入点清单」（把游戏返回的英文名接到 `ns.CoA.zhName`），第三～五节是硬编码英文的体检结果。

---

## 一、扫描方式与统计

1. 词法扫描（去注释、取全部字符串字面量），共 **14,236** 个字面量；其中 **2,396** 个处在翻译入口（紧跟 `L[` 或 `ns.T(`）上，视为已本地化。
2. 剩下的按两类判据筛：文本接收点（`:SetText` / `:SetFormattedText` / `:SetLabel` / `:SetTitle` / `:AddLine` / `AddMessage` / `ns.Print` / `TipList` / `Fmt`，以及 `text =` / `label =` / `title =` / `heading =` / `caption =` / `placeholder =` 赋值）与自然语言特征（≥2 个词、含小写词、非 API/常量/路径/字体名）。

结论：这个插件**已经很干净**——「疑似散文」里绝大多数是客户端数据名（NPC/任务/区域/副本）、调试输出、字体名与 API 常量。真正要动的只剩第三节的 5 处硬编码，加上第四节更新日志正文（需设计决定）。

> 改法约定：源文件不是我的写入范围（PORT.md §4）。请 owner 把字面量换成 `L["…"]`（键用英文原文），把键名 + 所属 section 告诉我，我在 `Locales/enUS.lua` 与 `Locales/zhCN/*.lua` 补词条。section 与源文件一一对应，例如 `UI/Blizzard/Minimap.lua` 就是 `Locales/zhCN/Core.lua` 里 `-- UI/Blizzard/Minimap.lua` 那一段。

---

## 二、显示期接入点清单：把客户端给的英文名换成中文

**为什么需要这一节**：CoA 客户端的语言是 enUS（`WTF\Config.wtf` 里 `SET locale "enUS"`），所以 `GetRealZoneText` / `GetZoneText` / `C_Map.GetMapInfo().name` / `GetInstanceInfo` / `UnitClass` / 战场名一律返回英文。插件自己的 UI 文案已经 `L[…]\` 化了，但**名字**不是文案，翻不了——只能在**显示的那一刻**查表。

**原则（lead 定，别破坏）**：存档里永远留客户端给的英文原名（区域身份、地图 id、职业 token 都是客户端数据）；`ns.CoA.zhName(x)` **只用于显示**，不得用于写存档、比较、索引。它不是 `nil` 安全就够，还要求「查不到原样返回」。

数据在哪：`Locales/zhCN/Names.lua`（229 条英文→中文，含大陆/城市/经典与 TBC·WotLK 副本团队/战场竞技场/区域/32 职业；反向表 `ns.CoA.enNames` 中文→英文；`CoA.todoNames` 是**故意留英文**的 118 条 CoA 自创名）。API：`ns.CoA.zhName(text)`、`ns.CoA.enName(text)`（`ns.CoA` 由 Capture/CoA.lua 归 features-port；同一份也在 `ns.Locale.CoA`，UI 若担心加载顺序可以读后者）。

### 2.1 已经统一的：不用再改

`Locales/Locale.lua` 的 `ns.ZoneIn` / `ns.ZonesIn` / `ns.DungeonIn`（`Locales/Locale.lua:413-445`）现在在 zhCN 下会把 `name` 过一遍 `Locale.CoA.zhName`。**凡是走这三条函数的句子都已经自动中文**，包括：

- `UI/Words/Timeline.lua:57`、`UI/Words/Person.lua:371`、`UI/Words/Format.lua:196,198`
- `UI/Journal/Nearby.lua:207-211`、`UI/Paper/NoteSheet.lua:237`、`UI/Windows/Entry.lua:64`、`UI/Windows/Reunion/Words.lua:103`
- `UI/Journey/Text/Prose.lua:29,52,54,55,83,139,183,185,330`、`UI/Journey/Text/Caption.lua:43,146,153`、`UI/Journey/Text/Tips.lua:297`
- `Features/Campfire/Text.lua:128`、`Features/Campfire/Kind.lua:56`、`Features/QuestFinales/Text.lua:58,82,122`、`Features/Firsts/Text.lua:99`、`Features/Duels/Text.lua:235,294`、`Features/Witnesses/Kind.lua:117`

所以 toast、卡片正文、旅程散文里的「in Stormwind City」已经是「在暴风城」。

**落地状态（2026-11-19）**：`Locales/zhCN/CoA.lua` 与 `Locales/zhCN/Names.lua` 已进 TOC（`social_diary.toc:93`、`:94`，都在 Locales 段末尾、早于 Capture/）；features-port 在 `Capture/CoA.lua` 末尾把 `zhNames`/`zhName`/`enName`/`todoNames` 重新挂回 `ns.CoA`（否则该文件的 `ns.CoA = CoA` 会覆盖镜像），32 个职业与 15 条战场/竞技场的 `zh` 已填。整机启动探针（`tests/wowmock.lua` 的 `LoadAddon` 按 TOC 全量加载 + `ADDON_LOADED`/`PLAYER_LOGIN`，不写存档）验证：`Locale.id == "zhCN"`、`ns.CoA.zhName("Stormwind City") == "暴风城"`、`ns.CoA.Name(ns.CoA.classes[1]) == "战士"`、`ns.ZoneIn(nil,"Elwynn Forest") == "在艾尔文森林"`、`ns.DungeonIn` 与未知名原样返回均正确。**不要在 Core 里改 `ns.Where`/`ns.MapName`/`ns.RowZone` 去翻**——那是存档与比较用的 raw 值（`Core/Sightings.lua:54` 的 `row.zone == where.zone` 靠它）。

### 2.2 显示点（下表是当初的派单，**19 日已全部落地**，实际形态见表下「落地记录」）

| # | 文件:行 | 现在做什么 | 改成 | owner |
|---|---|---|---|---|
| 1 | `UI/Journal/Nearby.lua:341` | `row.zone:SetText(e.zone)` —— 附近列表的「地区」列 | `row.zone:SetText(ns.CoA.zhName(e.zone))` | ui-port |
| 2 | `UI/Map/HeatSheet.lua:84-85` | `MapName(mapID) = ns.MapName(mapID) or Fmt(L["Map %d"], mapID)` —— 热力表的地图名，用在 `:225`/`:428` 的标签与 `:486` 的按钮 | 在 `MapName` 里包一层：`ns.CoA.zhName(ns.MapName(mapID))`（兜底分支不动） | ui-port |
| 3 | `UI/Journey/Text/Zones.lua:23` | `MapName(z.mapID)` —— 旅程「区域」标题 | 同上包 `ns.CoA.zhName` | ui-port |
| 4 | `UI/Journey/Text/Tips.lua:200,229,275,283` | `a.place or MapName(a.mapID)` —— 提示里的地点；`a.place` 是存档的 raw zone | 两个来源都包 `ns.CoA.zhName`（`a.place` 是英文原名，正好命中表） | ui-port |
| 5 | `UI/Settings/Sections/Recording.lua:56` | `city.name = type(city.key) == "number" and (ns.MapName(city.key) or …) or city.key` —— 城市清单**显示**地名 | 只翻显示分支，`city.key` 保持 raw（它是设置里存的匹配键） | ui-port |
| 6 | `UI/Words/Format.lua:355-361` `Format.ClassName` | `LOCALIZED_CLASS_NAMES_MALE[token]`，enUS 下给英文；CoA 自创职业该表可能没有 → 兜底 `token` 首字母大写 | **数据已经就位**：`ns.CoA.ClassByToken(token)` 给出 `{ id, name, token, zh }`（32 职业全有 `zh`）。改成 `local c = ns.CoA.ClassByToken(token); if c then return ns.CoA.Name(c) end`，再退回原来的查表/兜底 | ui-port |
| 7 | `UI/Journey/Text/Match.lua:260` | 战场页的队伍栏里 `LOCALIZED_CLASS_NAMES_MALE[p.class]` | 同上，用 `ns.CoA.ClassByToken(p.class)` + `ns.CoA.Name(entry)` | ui-port |
| 8 | `UI/Dungeon/**` 的标题渲染 | 副本名来自 `Core/Dungeons.lua:54 Dungeons.Name`（DCF 数据，英文） | 渲染处包 `ns.CoA.zhName(d.name)`；`Dungeons.Name` 本身别改（`Core/Instances.lua` 拿它做键/比较） | ui-port |
| 9 | `Core/Slash.lua:195` | `/sd` 回显 `ns.RowZone(row)` | 可翻（`ns.CoA.zhName(ns.RowZone(row))`）；`:258`/`:302`/`:312`/`:316` 是命令参数与调试输出，**保持英文** | core-port（建议） |
| 10 | `UI/Journal/People.lua:99`、`Core/Instances.lua:294` | 前者已走 `ns.ZoneIn`；后者存的是职业 token | 无需改（记录）：存档里是 raw/token 才对 | — |

**落地记录（2026-11-19，lead 亲自改；全量 128,383 checks 绿、audit R1–R6 绿）**

- 新增单一出口：`Core/Location.lua:104 ns.ZoneShown(name)`（`zhName` 查不到原样返回）与 `:111 ns.MapNameShown(mapID)`；`UI/Words/Format.lua:410 Format.PlaceName(text)`（同语义，UI 侧入口）。四处调用点因此只改一行。
- #1 `UI/Journal/Nearby.lua:341` → `row.zone:SetText(Format.PlaceName(e.zone))`。
- #2 `UI/Map/HeatSheet.lua:84` 的 `MapName` → `ns.MapNameShown(mapID) or Fmt(L["Map %d"], mapID)`。
- #3 #4 走同一处：`UI/Journey/Text/Grammar.lua:66` 拆成 `RawMapName`（客户端原名，只给比较用）与 `MapName`（走 `ns.MapNameShown`），`Text.MapName` 导出后者；于是 `UI/Journey/Text/{Zones,Tips,Prose,Caption}.lua` 里所有 `Text.MapName` 取到的都是中文，无需逐行改。`Grammar.Place`（`:75`）把子区域也过 `ZoneShown` 再与已翻译的区名比较。
- 唯一必须用原名的比较：`UI/Journey/Text/Caption.lua:159` 的「A long stay」判据（`seg.subZone ~= RawMapName(seg.mapID)`），比完再翻，否则英文子区域永远不等于中文区名。
- #5 `UI/Settings/Sections/Recording.lua` 改用**独立的显示字段** `city.shown`（不是 `city.name`），排序也按 `shown`；`city.key` 一个字节都没动（它是设置里存的匹配键）。
- #6 `UI/Words/Format.lua:355 Format.ClassName` 先问 `ns.CoA.ClassByToken` + `ns.CoA.Name`（32 职业全中），再回落客户端 `LOCALIZED_CLASS_NAMES_*`，最后 token 首字母大写；全程 pcall。
- #7 `UI/Journey/Text/Match.lua:260` 改调 `Format.ClassName(p)`（同一实现）。
- #8 `UI/Dungeon/**` 的副本标题早已走 ui-port 的 `Format.VisitName`（`UI/Dungeon/Sheet.lua:524` 等 9 处），本次无需再改。
- #9 `Core/Slash.lua:195 RowZone` → `ns.ZoneShown(ns.RowZone(row))`；`:258`/`:302`/`:312`/`:316` 保持英文（参数与调试）。
- `Capture/CoA.lua:381 CoA.Name` 补一条语言闸门：行内预填的 `entry.zh` 只在 `ns.Locale.Is("zhCN")` 时使用（它是一列**只有中文**的数据，DBC 也没有别的语言列），其它语种一律拿 `entry.name`。`zhName` 路径本身天然只装在 zhCN（`Locales/zhCN/Names.lua:5` 的文件级 guard）。
- 双语探针（`D:\DSH-source\.tmp-sd-port\probe_l10n_zhcn.lua`、`probe_l10n_enus.lua`，按真 TOC 全量加载）：zhCN 下 `Format.ClassName({class="PYROMANCER"})` 得「火法师」、`PlaceName("Mulgore")` 得「莫高雷」、`VisitName`/`CoA.Name` 副本名中文；**enUS 下同样四处全部回落英文**（Pyromancer / Mulgore / Shadowfang Keep），无中文泄漏。


### 2.3 还没数据、翻不了（要保持英文，别硬造）

- **种族名**：`UI/Words/Format.lua:352` 的 `RACE_NAMES[record.race]`，以及 `GetRace`/`UnitRace` 的返回值。**已定：保留英文**。理由：`ChrRaces.dbc` 有 42 行（经典 10 个 + CoA 自创 32 个），而客户端只装了 enUS 的表（`WTF\Config.wtf` 里 `SET locale "enUS"`，DBC 没有中文列）；自创种族没有任何官方中文名，经典 10 个虽有通行译名，但在客户端里核不到权威来源。按 lead 的规则「查不到就标 TODO，不许编」，这里不落盘。将来若能在客户端 GlobalStrings 或中文 DBC 里核到，再做成 `Locales/zhCN/Names.lua` 的表。
- **子区域名**（`GetSubZoneText`：Goldshire、Razor Hill…）：**已铺** —— `Locales/zhCN/Areas.lua` 由 `tools/dbc_areas.py` 从客户端 `patch-AAS.mpq` 的 `AreaTable.dbc`（2307 行，16 语种块，块内第 5 列是简体中文）生成 2,105 条英中对照，写进同一张 `CoA.zhNames`（手写词条优先），`ns.ZoneIn(nil, subZone)` / `ZoneShown` 因此都能查到；DBC 里的间隔号换成空格。测试 `tests/areas.lua`。
- **天赋/专精名**（`ChrSpecs.dbc` 无名字段）、**物品名**（`GetItemInfo` 的 link 名）、**任务名**（`Features/QuestFinales/Data.lua` 97 条 title）、**NPC/生物名**（`Core/Pace/*.lua` 978 条）、**CoA 自创副本/战场/区域**（`CoA.todoNames` 118 条）——都是客户端数据，没有权威中文来源；按 lead 的规则**保留英文**，等社区译名。
- `Capture/CoA.lua` 的 `CoA.dungeons` 仍是空表（features-port 说 CoA 没有权威副本清单），所以 `ns.CoA.dungeons` 没有任何条目。

---

## 三、P1：玩家直接看到的硬编码英文（5 处：4 处已改，1 处有意保留）

| # | 文件:行 | 现文 | 上下文（出现在哪） | 建议进哪一段 / 键 | owner |
|---|---|---|---|---|---|
| 1 | `UI/Blizzard/Minimap.lua:128` | `"Social Diary"` | `Style.TipList("Social Diary", { … })` —— 小地图按钮悬停提示的**标题行**；下面三行说明已经是 `L[…]\` | `-- UI/Blizzard/Minimap.lua`，`L["Social Diary"]`（enUS 保持品牌英文，zhCN 建议「社交日记」） | ui-port |
| 2 | `UI/Blizzard/Bindings.lua:19` | `"Social Diary"` | `BINDING_HEADER_SOCIAL_DIARY = "Social Diary"` —— 系统「按键设置」窗口里这一组绑定的**分类标题** | 同段；`L["Social Diary"]`。旁边注释已说明：绑定**名**（Bindings.xml 里的 `BINDING_NAME_…`）保持英文，只有 header 是给读者看的 | ui-port |
| 3 | `UI/Windows/Intro/Wrapped.lua:177` | `"SOCIAL DIARY"` | 引导/信件回顾卡片上压印的**标题**：`label.title:SetText("SOCIAL DIARY")`（全大写是美术效果） | `-- UI/Windows/Intro/Wrapped.lua`，`L["SOCIAL DIARY"]`；zhCN 用「社交日记」（中文无大小写，长度受卡片宽度限制） | ui-port |
| 4 | `UI/Windows/Intro/Tour.lua:172` | `"Your first green!"` | 引导卡片小标题：`find = { heading = "Your first green!", item = L["Wolfskin Bracers"] }`。同一张表里其它 `heading` 都写了 `L[…]\`（164、167 行），只有这条漏了 | `-- UI/Windows/Intro/Tour.lua`，`L["Your first green!"]`；zhCN：「你拿到的第一件绿装！」（voices/zhCN.md：uncommon = 优秀（绿）） | ui-port |
| 5 | `UI/Journal/Empty.lua:72` | `"Thex Theximus"` | 空白页上演示右键菜单的**虚构人物名**：`name:SetText("Thex Theximus")`；菜单项都已 `L[…]\`，只有这个示例名硬编码 | **已改为进 Locale**：引导里的句子本来就写着「塞克斯」，卡片却还是拉丁名，两处对不上。现在 `L["Thex Theximus"]` / `L["Thex"]` / `L["Theximus"]` 各一条（zhCN「塞克斯 塞西姆斯」/「塞克斯」/「塞西姆斯」），`Core/Sample.lua` 的 `Sample.Shown()` 供书签与搜索框用，记录里的 first/surname 也走同一对键，所以卡片、书签、人物列表读同一个名字；`Tour.lua` 的 `Bram Redfen` 同理（`L["Bram Redfen"]`，zhCN「布拉姆 雷德芬」）。enUS 仍是原名 | — |

**落地记录**：#1 `UI/Blizzard/Minimap.lua:128` → `L["Social Diary"]`；#2 `UI/Blizzard/Bindings.lua:19` → `L["Social Diary"]`；#3 `UI/Windows/Intro/Wrapped.lua:177` → `string.upper(L["Social Diary"])`（中文无大小写，保住压印的美术效果）；#4 `UI/Windows/Intro/Tour.lua:172` → `L["Your first green!"]`（zhCN「你的第一件绿装！」，enUS.lua 已重生成，现 1872 键）。

## 四、P2：更新日志正文（已定：数据留英文，显示期查中文）

- `Core/ChangelogData.lua` 是 `CHANGELOG.md` 的逐字副本：`tests/changelog.lua` 盯着这条一致性，`Dev/changelog.lua` 是它的生成器。**结论：这个文件一个字都不动**——把条目包成 `L[…]` 或直接翻成中文，那条测试必红，生成器也不再幂等。
- 中文从另一侧挂上去：`Locales/zhCN/Changelog.lua`（我的写入范围）导出 `ns.Locale.ChangelogZh(version, index, fallback)`；`UI/Settings/Sections/Changelog.lua:65-71` 已经在渲染时调用它（`:170` summary、`:182` entry、`:185` sub），帮助函数缺失、抛错或返回空串时原样显示英文。
- 下标约定（以后改 `Core/ChangelogData.lua` 的条目顺序时要同步挪）：外层键是 release 的 `version` 字符串；`[0]` 是该 release 的 `summary`；`[1]` 起按**页面从上到下**数文字项——每个分组里先一条 entry，紧接着它自己的每条 sub，然后才轮到下一条 entry（与 `UI/Settings/Sections/Changelog.lua:174-188` 的 `item` 计数器同步）。分组 heading 不占下标，它走另一套 `L` 词条（`:44-48`，早已本地化）。
- 覆盖：**5 个 release、19 行**（5 条 summary + 14 条 entry 与 sub；4.2.0 起 `Dev/changelog.lua` 只保留最新 5 个 release，4.0.0 已随上游从页面剪掉）全部有中文；`_斜体_` 标记保留在中文里（`Emphasis()` 是查表之后才处理的）。版本号对不上就整份回落英文。
- `CHANGELOG.md` 也不动（它是`ChangelogData.lua` 的生成源）；移植说明由 lead 写进 PORT.md / INSTALL.md。

## 五、不是 UI 文案、不该进 Locale 的（附理由，避免被误当缺陷）

| 位置 | 内容 | 为什么不译 |
|---|---|---|
| `Core/Pace/*.lua`（7 个文件，共 978 条字面量） | 副本名、Boss/NPC 名、`names = { … }`、`source = "Spawns: advocaite/TrinityCore, …"` 版权注记 | **客户端数据名**：enUS 客户端下游戏里显示的本来也是英文；要中文得建 id→中文表（同 `Locales/zhCN/CoA.lua` 的做法），不是 UI 文案 |
| `Features/QuestFinales/Data.lua`（97 条 `title =`） | 任务标题（「The Legend of Stalvan」…） | 同上，任务名属客户端数据。**但有个副作用值得 features-port 看一眼**：`Features/QuestFinales/Text.lua:17` 用 `Fmt(L["“%s”"], title)` 把英文任务名嵌进中文句子。更稳的做法是运行时取客户端给的标题，而不是硬编码表 |
| `Core/Compat/Env.lua`（`"Trade Goods"`、`"One-Handed Axes"`…） | 物品类别、护甲/武器类型的英文字面量 | **查表用的英文 key**（把 API 返回的英文名映射成枚举），不是显示文本 |
| `UI/Style/Art.lua:110,113`、`Features/*/Capture.lua` 的 `Note(… )`、`Core/Diary.lua:190`、`Capture/Sightings.lua:103` 等 | `"paper: flat colour"`、`"UPGRADE confirmed (worn %ds)…"`、`"sighting queue"` | 只在 `/sd debug` 打开时进聊天框的调试输出；按 PORT.md 源码/调试串保持英文 |
| `Core/Addon.lua:14` `CHAT_PREFIX = "|cff7db8ffSocial Diary|r "` | 聊天前缀 | 品牌名，建议保留英文 |
| `UI/Settings/Sections/Integrations.lua:53` `"Total RP 3"` | 第三方插件名 | 专名 |
| `UI/Ink/HandData.lua:17-29` `"snagged an item"`、`"from me"` | 手写笔迹的**预渲染笔画数据**（`strokes = { … }`，逐字坐标） | 不是文本：字是一笔一笔画出来的向量，`L[]` 换不了。zhCN 下这张纸条会显示英文手写字——**已知限制**，要中文得另做字形数据 |
| `UI/Style/Person.lua:186` `("^The ", "")` | 剥「The 」前缀再取首字母做头像 | 英文冠词处理，中文名不含「The」，无动作 |
| `UI/Pad/Input.lua:135` `Input.reason = "not yet"` | 调试原因串 | 只被 `/sd pad` 与调试打印读取 |
| `UI/Journey/Run.lua:905`、`UI/Windows/Picker.lua:85` | 纯颜色码/格式片段 | 拼装零件，不含文案 |

## 六、静态扫描照不到的地方（列出来，不假装覆盖全）

- **间接传参**：先 `local label = "…"` 再 `SetText(label)`、或表字段经中间函数渲染的，只能靠 data-flow 追；本清单用「赋值字段名」二次扫描兜底（命中 `UI/Pad/Input.lua:135` 一处，非可见）。
- **`Bindings.xml`**：`BINDING_NAME_…` 这类是 XML 字面量，不走 Lua，本清单未扫（当前设计里它们保持英文，见 `UI/Blizzard/Bindings.lua:17-18` 的注释）。
- **客户端数据**（DBC 的区域/职业/副本/战场/生物/任务）：中文名与客户端语言绑定，本仓库查不到（见 `Locales/zhCN/CoA.lua` 文件头与 `CoA.todo`）。
- **格式串里的介词拼接**：英文「from %s」「in %s」类已走 `L[…]\` 与 `PLACE` 表，无需额外处理。

## 七、建议分派

1. ui-port：第二节 2.2 的 8 条（大多是 `ns.CoA.zhName(…)` 包一层）+ 第三节 5 处（给字面量套 `L[…]\`），改完把键名发我，我补 enUS + zhCN。
2. lead：第四节更新日志正文做不做（方案 A 推荐）；2.3 的种族名要不要做。
3. features-port：`Features/QuestFinales` 改用客户端任务标题，避免中文句子里嵌英文任务名；给 `Capture/CoA.lua` 的 `zh` 填上我给的职业/战场译文。
4. core-port：只 `Core/Slash.lua:195` 一处可选。

## 复现

扫描是临时脚本，未入库。判据同第一节两段；重跑时按 text sink 列表 + 自然语言过滤，噪声过滤要剔掉：单 token/CamelCase 名、API 事件名（`OnEnter`…）、含反斜杠的路径、全大写常量、字体名（`SocialDiaryFont*`）。
