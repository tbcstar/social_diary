# Social Diary → CoA (3.3.5a) 移植验证报告

verify-port（质量门）· 2026-11-19 · 写入范围 tests/**、tools/**；未改 Core/UI/Features/Capture/Locales/TOC。

## 0. 结论先行

| 阶段 | 结果 |
|---|---|
| 上游 4.1.1 基线（retail mock，未移植） | 121 文件 / 124,356 断言，3 红（kinds、ui_layout、copy_rules，均为 Unix `io.popen("find")`） |
| mock 切到 3.3.5 后的第一版（本任务的 before） | 75 红 / 121，69,589 断言通过 |
| 当前（本报告） | **121 文件全绿，128,393 断言通过**（4.2.0 同步后；4.1.1 时是 128,383，差 10 条来自 locale 文件新增的 ptBR 列检查），`tests/journey.lua` 的路线几何按 lead 的决定归 D（见 4.3） |
| 静态门禁 `python -B tools/coa_audit.py` | **0 error / 0 warning**（R1–R6 全绿），退出码 0 |
| 门禁自测 `python -B tools/selftest_coa_audit.py` | 17/17 通过 |

命令（不需要装 luajit，走 lupa 里的 LuaJIT）：

```
cd D:\DSH-source\social_diary_coa\social_diary
python -B D:\DSH-source\.tools\luarun.py tests/run.lua            # 全量
python -B D:\DSH-source\.tools\luarun.py tests/run.lua locale     # 单文件
$env:FORCE_RETAIL=1; python -B D:\DSH-source\.tools\luarun.py tests/run.lua   # 对照：旧 retail mock
python -B tools/coa_audit.py                 # 静态门禁，非 0 = 不合格
python -B tools/coa_audit.py --json           # 机器可读
python -B tools/selftest_coa_audit.py         # 门禁自身的 17 个用例
```

测试现在**通过 TOC 驱动加载**：`tests/harness.lua` 先 `FS.Toc(root)` 找到唯一 .toc，`mock.LoadAddon(root, toc)` 逐行 loadfile/chunk 进同一个 ns，因此 `Core/Compat/*.lua` 和业务代码一起被真正跑到 —— 兼容层本身是被测对象，而不是被 mock 顶替。mock 只模拟**客户端**（3.3.5 + CoA 客户端 FrameXML 里真实存在的 API），retail 专有名一律留给 Core/Compat。

---

## 1. 改了哪些文件（全部在 tests/**、tools/**）

**新增**

| 文件 | 作用 |
|---|---|
| `tests/fs.lua` | 无依赖跨平台目录遍历（lfs → Windows `dir /b[/ad|/a-d]` / `dir /s /b /a-d` → Unix `find` → TOC 清单兜底），替代 3 个测试里的 `io.popen("find … | sort")`。找不到目录时抛清晰错误，而不是把空列表当好结果。 |
| `tests/dev.lua` | 按上游 TOC 的 dev 块顺序加载 `Dev/*.lua` 与 `Features/*/Dev.lua`（TOC 里没有 dev 块时由它补上；TOC 已有则不重复加载，避免 `/sd art` 注册两次）。 |
| `tests/pad_api.lua` | 手柄 API 替身（3.3.5 完全没有 gamepad API）。只在源码里出现 `mock.pad` / `C_GamePad` / `InputUtil` 的文件里安装，文件跑完 `Uninstall()` 还原。 |
| `tests/wowmock_retail.lua` | 冻结的 retail mock（54,953 字节），`FORCE_RETAIL=1` 时使用，作为“移植前”的对照。 |
| `tools/coa_audit.py` | 静态门禁（R1–R6，纯标准库，`--json`，退出码 0/1/2）。 |
| `tools/selftest_coa_audit.py` | 门禁自测：在临时目录造“干净/违规”两版插件，断言哪条规则会红（17 例）。 |
| `tools/scan_client_api.py` | 扫描 CoA 客户端导出的 Interface 源码，产出 `tools/client_native.txt`（96 个名字，其中 39 个 `C_*`），区分 class N（客户端自带）与 class S（必须 Compat 提供）。 |
| `tools/client_native.txt` | 客户端原生 API 缓存：`名字<TAB>文件:行`。 |

**修改（测试层）**：`tests/wowmock.lua`（mock 从 retail 改写成 3.3.5 形状）、`tests/harness.lua`（TOC 驱动、FORCE_RETAIL、菜单记录器、pad 安装/卸载、全局回收）、`tests/kinds.lua`、`tests/ui_layout.lua`、`tests/copy_rules.lua`、`tests/locale.lua`、`tests/settings_language.lua`、`tests/suggest.lua`、`tests/diary.lua`、`tests/identity.lua`、`tests/helpers.lua`、`tests/combat.lua`、`tests/interactions.lua`、`tests/chat.lua`、`tests/notes.lua`、`tests/group_sessions.lua`、`tests/deaths.lua`、`tests/matches.lua`、`tests/dungeon_run.lua`、`tests/sightings.lua`、`tests/menus.lua`、`tests/reunion.lua`、`tests/journey.lua`、`tests/journey_ui.lua`、`tests/pace.lua`、`tests/pad_cards.lua`、`tests/settings_about.lua`、`tests/uidump.lua`。

---

## 2. mock 移植：retail API → 3.3.5a

### 2.1 mock 里删掉的 retail 专有名（改由 Core/Compat 或客户端形状代替）

`issecretvalue`、`scrubsecretvalues`、`C_Item`、`C_Container`、`C_QuestLog`、`C_PlayerInfo`、`C_AddOns`、`C_Timer`（mock 不再定义）、`C_GamePad`、`InputUtil`、`MenuUtil`、`Settings`、`TooltipDataProcessor`、`Enum.TooltipDataType`、`C_Map` 的 retail 成员（`GetMapInfo(mapID)`/`GetPlayerMapPosition`/`GetWorldPosFromMapPos`/`GetMapPosFromWorldPos`/`GetMapWorldSize`/`GetMapArtLayers`/`GetMapArtLayerTextures`）、`C_MapExplorationInfo`、`CreateVector2D/3D`、`UnitPosition`（返回 nil）、`UnitTokenFromGUID`。

### 2.2 mock / 兼容层里保留并写成 3.3.5 真实形状的 API

| API | 3.3.5 真实形状（mock 与 Compat 都按这个写） |
|---|---|
| `GetBuildInfo()` | `"3.3.5", "12340", "Aug 12 2009", 30300` |
| `GetQuestLogTitle(i)` | 8 个返回值：`title, level, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID` |
| `GetNumQuestLogEntries()` | 只返回条目数（retail 的 `GetNumQuestLogEntries` 是 C_QuestLog） |
| `GetNumQuestLeaderBoards(i)` / `GetQuestLogLeaderBoard(j, i)` | `text, type, finished, numFulfilled, numRequired` |
| `GetContainerNumSlots(bag)` / `GetContainerItemInfo(bag, slot)` | 后者 8 个扁平返回值：`texture, count, locked, quality, readable, lootable, link, isFiltered` |
| `GetItemInfo(id)` | 11 个返回值，第 10 个是 texture |
| `GetItemInfoInstant(id)` | 7 个返回值：`id, type, subType, equipLoc, icon, classID, subclassID` |
| `GetMapInfo()` | **无参**，返回当前区域图的 `file, height`（retail 是 `GetMapInfo(mapID)`） |
| `GetPlayerMapPosition(unit)` | 0..1 的地图比例；不在当前区域图为 0,0 |
| `GetMapContinents/GetMapZones/SetMapZoom/GetCurrentMapContinent/GetCurrentMapZone/GetCurrentMapAreaID/SetMapByID/SetMapToCurrentZone` | 3.3.5 原样（Compat 的 C_Map 由它们实现） |
| `UnitAura/UnitBuff/UnitDebuff`、`GetNumRaidMembers/GetNumPartyMembers`、`GetNumGroupMembers`、`GetSpecialization(Info)` | 由 Compat 用 3.3.5 实现，测试照常调用 retail 名 |
| `GameTooltip:GetUnit()` | **两个**返回值：`("player", token)` —— 客户端 FrameXML 用第二个 |
| `GetTime()` / `GetServerTime()` | 3.3.5 原生 |
| `InterfaceOptions_AddCategory` / `InterfaceOptionsFrame_OpenToCategory` | Settings 兼容层的 3.3.5 底座（后者在 3.3.5 要调两次才真正打开） |

### 2.3 测试层三处“客户端保真”修正（T 类，都是测试自己的问题）

1. **跨文件泄漏**：Compat 的 shim 是 `X = X or ...` 的**全局**，第一个测试文件的闭包带着自己的 map 缓存/定时器表一直活着；后面的文件重新加载插件时 guard 全部跳过，于是用上一个文件的状态回答（表现：`reunion:486 no heat on the first map`、`custom_duel:437 setup: a full plate` 只在全量跑里红）。修复：`mock.Reset()` 记录加载时的 `_G` 快照，回收插件装进去的所有全局，并把 mock 自带的 `C_Map` 恢复成客户端形状（只有 `GetBestMapForUnit`）。
2. **区域变更事件**：客户端换区域图时区名和 area id 一起变，`Core/Compat/Map.lua` 的 `BestMapForUnit` 以 `GetRealZoneText()|""` 为缓存键，只在 `ZONE_CHANGED*` 时清缓存。测试只改 `mock.mapID` 不会触发事件 → 新增 `mock.MoveTo(mapID, position)`，改完 id 后主动 `AnnounceArea()` 发 `ZONE_CHANGED_INDOORS`。**不能**在 `SetMapByID`/`SetMapToCurrentZone` 里直接发事件：Compat 的 MapInfo 会在读图过程中被事件重入，读到一半的视图被改掉。
3. **手柄替身按文件安装**：3.3.5 无 gamepad API，Compat 故意装空表；只有写 `mock.pad` / `C_GamePad` / `InputUtil` 的测试文件才拿替身，跑完卸载。这样非手柄文件不会“看见”一个客户端没有的 API。

### 2.4 `FORCE_RETAIL=1` 对照开关

`tests/harness.lua` 里 `os.getenv("FORCE_RETAIL") == "1"` 时 `dofile(tests/wowmock_retail.lua)`，否则用 3.3.5 mock。retail mock 是一份冻结副本，用于“移植前行为”的对照；默认永远是 3.3.5。

---

## 3. 静态门禁 tools/coa_audit.py

六条规则（任一失败退出码 1；`--strict` 把 warning 也当失败；`--json` 输出结构化结果；`--only R4` 只跑一条）：

| 规则 | 内容 | 当前 |
|---|---|---|
| R1 | retail 专有名只允许在 `Core/Compat/` 定义；且业务代码调用的每个 retail 名都必须有来源：class N 由客户端提供（只能补成员，整表重定义 = class D 错误）、class S 由 Compat 提供。`Texture:SetColorTexture` 这类成员方法单独判定。 | PASS（8 class N / 32 class S / 40 个被调用的 retail 名；C_CVar、C_Map、C_Timer、Enum 是“补成员”） |
| R2 | TOC 列出的每个文件都存在；每个 .lua 都是合法 UTF-8（未进 TOC 的 tests/tools/Dev 只警告） | PASS（531 个 .lua，392 个在 TOC） |
| R3 | TOC 没有 3.3.5 不认的指令（`LoadSavedVariablesFirst` / `AddonCompartmentFunc` / `X-Category` 等），`## Interface:` 必须是 30300 | PASS |
| R4 | 每个 `L["..."]` / `ns.L[...]` 字面量 key 在 `Locales/zhCN/*.lua` 里都有译文；enUS 有的 key zhCN 不能缺，并输出覆盖率 | PASS：zhCN 覆盖 **1871/1871** enUS key（100.0%），1871/1871 被代码使用 |
| R5 | Lua 5.1 字符串转义：Windows 反斜杠路径（如 `"C:\path"`）不得写成非法转义；测试不得 `io.popen` 依赖 Unix 命令 | PASS |
| R6 | 测试 mock 只能模拟客户端，不能替 Compat 定义 class S 名（否则测试会被 mock 自己的 shim 放行，移植漏洞被掩盖） | PASS |

自测 17 例覆盖：干净移植通过 / retail 调用无 shim / shim 重定义 / 模板缺失 / TOC 指向不存在文件 / 非 UTF-8 / retail TOC 指令 / L key 无译文 / Windows 路径转义 / Unix shell / mock 定义 retail 全局 / mock 模拟客户端原生名（应通过）/ mock 定义 class S 名 / 客户端原生表整表重定义 / 客户端原生表成员级补齐（应通过）/ 成员被覆盖 / 干净版再验证。

---

## 4. T / P / D 分类表

- **T**（test assumption，测试假设过时）：断言写的是 retail 行为或测试自身状态管理问题 → 改断言/改测试设施到 3.3.5 事实。
- **P**（port bug，移植缺陷）：业务/兼容层代码的问题 → 只报给 owner（core-port / ui-port / features-port / l10n-port），不改别人的文件。
- **D**（dropped feature，3.3.5 上不可得的能力）：断言改成“按 3.3.5 的真实结果”，并在下面逐条记录原覆盖与现在的等价验证。

### 4.1 T 类

| 文件:行 | 原断言 | 改动 |
|---|---|---|
| `tests/kinds.lua:159`、`tests/ui_layout.lua:159`、`tests/copy_rules.lua:45` | 用 `io.popen("find …")` 列目录，Windows 下返回空 → 误红 | 改用 `tests/fs.lua` 的纯 Lua/跨平台遍历（lfs → dir/find → TOC 兜底） |
| `tests/locale.lua` 默认语言小节 | `Locale.default`/`Wanted(nil)`/`Wanted("auto")` = enUS | 3.3.5 上默认 = zhCN（`Locales/Locale.lua:75` 按 build 30300 判）；`Locale.id` 仍为存档的 enUS |
| `tests/locale.lua:165` | `Locale.Settle("auto")` 不等待 | 改成 `Locale.Settle("enUS")`；auto 现在指向中文，会像任何选择一样等待 |
| `tests/locale.lua` `GrammarNs` | 只改 `GetLocale` 就选语言 | 3.3.5 恢复 SavedVariables 早于加载，`Locale.Chosen()` 先读存档 → 同时设置 `_G.SocialDiaryDB.settings.language`，跑完恢复 |
| `tests/suggest.lua:40-45`、`tests/diary.lua:233-237`、`tests/settings_language.lua` | 同上，改语种只改 `GetLocale` | 同样先种 `_G.SocialDiaryDB.settings.language`（deDE / enUS） |
| `tests/identity.lua` bootstrap | 默认有存档语言 | 首次加载模型：`_G.SocialDiaryDB = nil` |
| `tests/helpers.lua` 地图小节 | retail `C_Map.GetMapInfo` 形状 | 同时 patch `C_Map.GetMapInfo` 与 `GetBestMapForUnit`（客户端的后者只给区域级 id），跑完还原 |
| `tests/pad_cards.lua` “off this map” | `mock.mapID = nil` 表示“人在别处” | 客户端永远有 area id：改成 `1413`（The Barrens）+ 位置 0.5/0.5 |
| `tests/pace.lua` 探针字符串 | `3 readable, 1 hidden`、`#11318 x3, #11320 x2` | 无 secret 值：`4 readable, 0 hidden, 1 not creatures`、`#11318 x3, #11320 x1` |
| `tests/sightings.lua`、`tests/helpers.lua:201`、`tests/combat.lua` | secret 语义（见 4.3 同批文件） | 同上，按 3.3.5 读出 |
| `tests/settings_about.lua` 新增最后一节 | 无（新增覆盖） | changelog 中文缺失时的英文回退 + `ChangelogZh` 委托与编号（`9.9.9#0`、`9.9.9#3`）；与 ui-port 共同确定 |
| `tests/harness.lua` | `mock.LoadAddon(root)` 硬编码 TOC 名；重复加载 Dev | TOC 用 `FS.Toc()` 找（core-port 可能改名）；TOC 里已有 `Dev/Art.lua` 就不再 `Dev().Load`（否则 `/sd art` 注册两次） |

### 4.2 P 类（报给 owner，已修或待修的移植缺陷）

| 发现处 | 问题 | owner | 状态 |
|---|---|---|---|
| `Core/Compat/Map.lua:170`（首版） | 整表 guard：`if not C_Map then C_Map = {...} end`。客户端 FrameXML/Util/C_WorldMap.lua:188 已经定义 `C_Map`（只有 `GetBestMapForUnit`），guard 跳过 → 游戏里 `C_Map.GetMapInfo/GetPlayerMapPosition/GetMapArtLayers` 全是 nil，40+ 个测试文件 zone id 为 nil | core-port | **已修**：改成 `C_Map = C_Map or {}` + 成员级 `C_Map.X = C_Map.X or …`；R1 的 7 条成员告警随之为 0 |
| `Core/Compat/Extras.lua:188` | `local unit = self.GetUnit and self:GetUnit()` 只取第一个返回值。客户端 FrameXML/GameTooltip.lua:758 用 `local _, unit = self:GetUnit()`，第二个才是 token → tooltip 里永远拿到 `"player"`，sightings/reunion/settings 的 tooltip 行缺失 | core-port | **已修**：`local _, unit = self.GetUnit and self:GetUnit()` |
| `Core/Compat/Quests.lua:16` | `GetQuestLogTitle(i)` 解构错位：3.3.5 是 `title, level, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID`，原代码把第 5 个当 isHeader、第 9 个当 questID（永远 nil）→ `GetTitleForQuestID` 恒 nil、`IsOnQuest` 恒 false | core-port | 已报告（questie/hunt 相关测试现已绿） |
| `Core/Compat/Quests.lua:9-41` | `C_QuestLog` 缺 `GetNumQuestLogEntries` 与 `GetInfo`，`Features/Hunts/Capture.lua:63-72` 静默退回旧全局；另缺 `GetQuestObjectives` | core-port | 已报告 |
| `Core/Compat/Extras.lua:49-58` | `MenuUtil` 的 `ElementMeta.__index` 对任何 UpperCamelCase 返回 Noop（无返回值），子菜单元素无法嵌套 → `UI/Journal/People.lua:189-192/244`、`UI/Style/Widgets.lua:200-205` 的二级菜单消失 | core-port | 已报告（相关 UI 测试现已绿） |
| `Core/Compat/Textures.lua:18-45` | 给 widget metatable 加 `SetColorTexture/SetAtlas/GetAtlasInfo`，但 mock 的 widget 各自带方法且无 metatable；测试需 widget 自身方法（已在 mock 侧补 `SetColorTexture` 等） | core-port / 我 | 测试侧已兼容 |
| `Core/Compat/Settings.lua` | 必须继续用 `InterfaceOptions_AddCategory` + 两次 `InterfaceOptionsFrame_OpenToCategory`（3.3.5 的打开是两步） | core-port | 保持 |
| `Core/Compat`（无 C_PlayerInfo 位置） | `C_PlayerInfo.GetGUIDFromPlayerLocation` 无 3.3.5 等价物 | core-port | 3.3.5 上不存在该能力 → 归 D（见 4.3） |
| `UI/Journal/*`、`UI/Pad/*` | 8 处 `C_CVar`/`C_GamePad` 调用都带 `C_CVar and …` 兜底，无需改 | ui-port | 无需修（契约一致） |

### 4.3 D 类（3.3.5 不可得，断言改为真实结果；逐条记录原覆盖与替代验证）

**secret 值（retail 的受限值保护）—— 3.3.5 没有受限值**：`mock.secret()` 现在返回原值（`tests/wowmock.lua`），`Compat` 的 `issecretvalue` 恒 false，所以守卫分支是死代码但无害。原断言覆盖的是“受限值不进日记/不触发提醒”；3.3.5 上等价验证变成**形状守卫**（nil / 非字符串 / Creature- / 非法 GUID 仍被 `Core/Addon.lua` 的 `SafeGUID` 拒绝）以及“普通值正常读出”。

| 文件:行 | 原断言 | 现在的断言 | 替代验证 |
|---|---|---|---|
| `tests/interactions.lua:28` | secret GUID 加不进缓冲 = nil | 普通 GUID 能进（`Count == 1`）；`Add(nil, …) == nil` | nil GUID 守卫（SafeGUID） |
| `tests/chat.lua:31` | 受限私聊计数 +1、不存储 | 不扣留（计数不变）、正常存储（`Count == 3`） | 计数 API 仍覆盖；非法 guid 由 SafeGUID 拦 |
| `tests/diary.lua:44` | secret GUID 进不了日记 = nil | `Diary.Add(nil, {}) == nil`；Creature- GUID 仍拒绝（:43） | 同上 |
| `tests/notes.lua:53` | secret GUID 的笔记 = nil | `Notes.Add(nil, …) == nil`；空白/nil/日记外/creature 用例保留 | 同上 |
| `tests/group_sessions.lua:135` | secret GUID 的死亡只算 1 | 普通 GUID 第二次死亡计入（=2） | 会话死亡计数逻辑 |
| `tests/deaths.lua:150` | secret 的 recap 不替换猜测 | recap 正常读出并使用（`source == "recap"`） | stale/missing recap 用例保留 |
| `tests/matches.lua:123` | secret GUID 不保留 | GUID 以普通字符串保留（`Player-…`），`kb` 仍 nil | 战场名字表逻辑 |
| `tests/dungeon_run.lua:98` | secret 的 pull 不标记 | pull 正常标记，name/id 正常读出；战利品计数相应 +1 | 副本事件提取 |
| `tests/reunion.lua:868` | secret GUID 不提醒 | 被当成普通 GUID 提醒；`Due(nil, …) == nil` | nil 守卫 |
| `tests/reunion.lua:933` | secret 对手不告警 | 正常告警；`FoeAlert(nil, …) == false` | nil 守卫 |

**路线记录（stop/road/flight）**：原断言覆盖每 N 码一个面包屑、道格拉斯-普克抽稀、200 码瞬移切分、停留聚类；3.3.5 客户端不提供世界坐标，整条几何链不可用；等价验证 = 升级点、副本行程、战斗标记仍按区域图比例记录，skip 原因可在 /sd journey stats 查看。lead 决定：不改 `Core/Journey.lua` 的码数几何，也不改成地图比例反推。合成 `J.Feed` 的段落（抽稀/合并/瞬移切分/存储与旧存档行迁移）**保留**，因为它们验证的是 `Core/Journey.lua` 的压缩与存档逻辑，而不是客户端不可得的世界坐标。

**地图：没有世界坐标 / 没有地图美术**（PORT.md §5：`UnitPosition`、`C_Map.GetWorldPosFromMapPos`、`GetMapArtLayers`、`C_MapExplorationInfo` 在 3.3.5 都不存在）

| 文件:行 | 原断言 | 现在的断言 | 替代验证 |
|---|---|---|---|
| `tests/journey.lua` zone map 小节 | sub-map（洞穴）世界坐标投影出 x/y | `ns.ZoneWhere() == nil`（无世界投影的点被跳过）；非数字位置也得 nil | 坐标合法性校验 |
| `tests/journey.lua` 采集小节（原 :343） | 走路每 N 码生成一个面包屑 → road → stop | `mine.open.road == nil`、`Kinds("road")==0`、`Kinds("stop")==0`；`ns.JourneyCapture.status.skip == "no world position (UnitPosition)"` | 升级点、副本行程、战斗标记仍按区域图比例记录（见下几行） |
| `tests/journey.lua` 出租车小节 | 飞行段画 flight 线 | `status.skip == "on a taxi"`；`Kinds("flight")==0`、`Kinds("road")==0` | 出租车状态本身仍验证 |
| `tests/journey.lua` 副本小节 | 进本时按样本落一个入口坐标 | `d.mapID/d.x/d.y` 均为 nil（`GetInstanceInfo` 就能开本，无需样本）；名字/instanceID/秒数/跑尸/离开/一次只记一本/战场暂停全部保留 | `Core/Journey.lua:982 Journey.InDungeon` |
| `tests/journey.lua` 升级小节 | 升级时写一个带 levelTo 的段 | 段只剩两个副本段；`levels[11]` 的 mapID/x/y/subZone 仍按区域图比例记录 | `Journey.Level`（`Core/Journey.lua:965`） |
| `tests/journey.lua` `/reload` 小节 | 重载后 open stop 仍在 | 路线/等级/段数原样存活；没有新段被凭空造出；长间隔不 Settle | 存档往返 |
| `tests/journey.lua` raw buffer 小节 | 开 debug 会写原始点 | `J.RawCount()==0`、`db.journeyRaw.at == nil`（样本根本到不了 Journey） | 上限常量仍验证 |
| `tests/journey.lua` 新角色小节 | 1、2 级各有 entries | 1 级没有任何保留活动 → 只有 1 条 entry（正在玩的 2 级）；road 0 | 页面 state 仍验证 |
| `tests/journey.lua` 会面小节 | 洞穴点位会被挪到区域图（靠 parentMapID 反查） | `ZoneOf(2000)==2000`，洞穴注释留在洞穴自己的图上（`onCave.x == 0.5`），不上区域图 | `Core/Compat/Map.lua` 的“父图未知就不猜” |
| `tests/journey.lua` tick 错误小节 | 让 `J.Feed` 抛错 | 改为 stub `ns.ZoneWhere` 抛错（Feed 在 3.3.5 不可达）：仍计入 `status.errors`、`lastError` 含 "boom"、下一 tick 继续 | 错误上报路径 |
| `tests/journey.lua` MapYards 小节 | `C_Map.GetMapWorldSize` 把区域图换算成码 | `J.MapYards(MULGORE) == nil`、`MapYards(7001) == nil`、`MapYards() == nil` | 3.3.5 无 `GetMapWorldSize`/`GetWorldPosFromMapPos` |
| `tests/journey.lua` 跑尸小节 | 死/跑尸期间也要画 road | 全程 `Kinds("road")==0`；死时 skip `"dead or a ghost"`，复活后 skip `"no world position (UnitPosition)"`；死亡标记仍在 | 死亡/幽灵状态机仍验证 |
| `tests/journey_ui.lua:1100-1122` | 画出了 2 块探索区域 | `plate.exploredCount == 0`；`MapArt.For(1412)` 第三返回 nil；不再打印 9001/9002/9003 贴图 | 地图页仍画出空卡（zone 名） |
| `tests/journey_ui.lua:1177-1196` | 整图/揭示模式画出美术层 | `MapArt.For(1412)`、`For(1412, true)` 均为 nil；revealMap 开关不改变 exploredCount | 同上 |
| `tests/journey_ui.lua:1503-1504` | 跨区域飞行画虚线 | `counts.dashes == 0` | 飞行提示文字走 “Flew to another zone” 回退 |
| `tests/journey_ui.lua:2347-2358/2371/2390` | 飞行管理员连线 + 跨区虚线 | 只有本区域内的那条线（`#flightLines == 1`）；第三座管理员没有线 | 圆环布局仍验证 |
| `tests/reunion.lua:659` | 热力图 12 块贴图 | `HM.tileCount == 0` | 热力数据本身仍验证（mapID/x/y） |
| `tests/menus.lua` 聊天名路径 | `C_PlayerInfo.GetGUIDFromPlayerLocation` 拿到 GUID | 3.3.5 回退为 last-seen 名字：`"failed"` | `Capture/Menus.lua` 的回退分支 |
| `tests/menus.lua` secret 单位菜单 | 0 项 | 1 项（无受限值） | 菜单构建逻辑 |
| 手柄 UI（`tests/pad.lua`、`pad_*.lua`、`autoadd_sheet`、`custom_duel`） | 客户端有手柄 API | 客户端没有：兼容层装空表，测试用 `tests/pad_api.lua` 替身（只在相关文件内），游戏里手柄 UI 永不开启 | 替身仍验证 pad 布局/输入映射；`VERIFY.md` 即此条 |

---

## 5. 3.3.5a（CoA 客户端）与 retail 的行为差异清单

凡是从客户端 FrameXML 或 C 端确认过的差异，都写进 mock/Compat 并按真实形状测试：

| 事实 | 依据 | 影响 |
|---|---|---|
| `C_Map` 在客户端**只有 `GetBestMapForUnit`**（区域级） | `Interface/FrameXML/Util/C_WorldMap.lua:188` | `GetMapInfo`/`GetPlayerMapPosition` 等由 Compat 成员级补齐；`ns.City()` 依赖 `Core/Location.lua:152-153` 的区名回退 |
| 没有世界坐标：`UnitPosition` 返回 nil、无 `CreateVector2D/3D`、无 `GetWorldPosFromMapPos` | 客户端 0 命中；Compat `Map.lua:225` | 路线/跨区投影/地图美术不可能；本项目按 PORT.md §5 降级 |
| `GetInstanceInfo()` 只返回 **7** 个值：`name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic` | 客户端 `Util/GlobalOverwrites.lua:419-420`（features-port m00410） | `select(8, …)` 永远 nil（`Core/Location.lua:42`、`Core/Instances.lua:169-199` 已按 7 个写） |
| 没有 `RegisterUnitEvent` | FrameXML 0 命中；28 处 UNIT_AURA 都用 `RegisterEvent` | 只能 `RegisterEvent`，事件载荷里没有 unit 参数 |
| `UNIT_AURA` 没有载荷（无 addedAuras/removedAuraInstanceIDs/isFullUpdate） | 客户端 | 单位光环靠 `UnitAura` 轮询 |
| `PVP_MATCH_ACTIVE/STATE_CHANGED/COMPLETE` 永不触发 | 客户端 | 用 `GetBattlefieldWinner()` 非 nil / `UPDATE_BATTLEFIELD_STATUS` / `UPDATE_BATTLEFIELD_SCORE` |
| 战场记分板有 race/class（`GetBattlefieldScore` 12 个返回值），但**没有 guid**、没有 per-battlefield stats | `FrameXML/WorldStateFrame.lua:703` | Core/Compat/PvP.lua 已传 race/class + 5 个计数 |
| 没有 `C_DamageMeter` | 客户端 0 命中 | 伤害统计走自建/CloseCalls |
| `LFG` 的 MapID 与 WorldMapArea id 不是同一套 | 客户端 | 不能直接当 mapID 用 |
| 没有图集（atlas）与排序箭头、没有 `CreateMaskTexture` | 客户端 0 命中 | UI 用 SetTexture 路径；相关测试按 nil/0 断言 |
| 没有 `Menu.ModifyMenu` | 客户端 0 命中 | 菜单项不会出现在 Blizzard 右键菜单里（guard 在 `Capture/Menus.lua:149`） |
| 没有 `C_PlayerInfo.GetGUIDFromPlayerLocation` | 客户端 0 命中 | 聊天名路径退化为 last-seen 名 |
| 没有 gamepad API（`C_GamePad`/`InputUtil`） | 客户端 0 命中 | 手柄 UI 在游戏里不可用；测试用手柄替身 |
| SavedVariables 在插件加载**之前**恢复（所以不需要 `## LoadSavedVariablesFirst`） | 3.3.5 行为 | mock/测试按此建模；DB 保留已有表 |

---

## 6. 契约变更（需要全体知道的）

1. **默认语言 = zhCN**：`Locales/Locale.lua:75` 在 build 30000–40000 之间默认 zhCN；`Locale.Wanted(nil|"auto")` = zhCN。测试里“默认英文”的断言已按此改写（`tests/locale.lua`、`tests/settings_language.lua`），`Locale.id` 仍是存档选择（默认为空 → 用 default）。
2. **测试通过 TOC + Core/Compat 加载**，兼容层是被测对象；mock 不再提供 retail 名（R6 强制）。
3. **`FORCE_RETAIL=1`** 保留为整套对照开关；默认 3.3.5。
4. **TOC 名不硬编码**：`tests/fs.lua` 的 `Toc()` 用 `*.toc` 匹配，core-port 改名（如 `social_diary_coa.toc`）不会弄坏测试。
5. **Dev 块**：core-port 已把 `#@do-not-package@` 找回 TOC；`tests/dev.lua` 只在 TOC 缺 dev 块时才补加载（防止重复注册）。

---

## 7. 还没验证 / 无法自动验证的

- **真实客户端加载**：本报告全部来自 LuaJIT 下的 mock + 兼容层；没有启动游戏客户端（任务要求），所以真实 FrameXML 的加载顺序、taint、事件时序、字体度量未验证。
- **中文文本宽度与排版**：mock 的字体串是假的（`FontString:SetText` 只检查是否设过字体），换行/截断/行宽在真机上未验证；`ui_layout` 只验证结构。
- **字体文件**：`ARHei.ttf` 等已在机器上、客户端读 UTF-8 Lua（PORT.md §1），但真实渲染未验证。
- **地图/副本的真实 id**：mock 用 1412 Mulgore / 1413 The Barrens / 1454 Orgrimmar 等样本；真实客户端的 zone id 集合更大，`C_Map.GetMapInfo` 的边界（未探索区域、副本内）未穷举。
- **手柄 UI**：客户端没有该 API，只有测试替身；真机永远不开启。
- **秘密值语义**：3.3.5 没有受限值，相关分支为死代码（无害）；若未来客户端引入，需要重新引入 mock.secret 与断言。
- **路线几何**：3.3.5 无世界坐标，`Capture/Journey.lua` 永远拿不到 sample，面包屑/road/stop/飞行段/码数换算在真机与测试里都不可用（lead 定为 D，见 4.3）。`/sd journey stats` 会显示 skip 原因 `no world position (UnitPosition)`，这是最强的现场证据，但“它在真机上一定显示”只在 mock 下验证过。
- **手柄/秘密值/地图美术**之外的 UI 细节（动画、贴图实际可用性）同样只有结构级验证。

## 8. 上游 4.2.0 同步（2026-11-19，lead 执行）

上游 `3e44eec v4.1.1` → `b63837f v4.2.0`（三个提交：测试套件内存泄漏修复、巴西葡萄牙语、v4.2.0）。逐项合并后本移植仍然全绿。

| 上游改动 | 本移植的处理 |
|---|---|
| `Locales/ptBR/` 12 个文件（新增） | 上游原样复制；TOC 在 deDE 之后、zhCN 之前加同样的 12 行；`## Version: 4.2.0` |
| `Core/ChangelogData.lua`（加 4.2.0、剪掉 4.0.0） | 不手改：`Dev/changelog.lua` 从 CHANGELOG.md 重生成（KEEP=5，4.2.0 进来、4.0.0 出去），产物与上游 b63837f 的文件逐字一致（去掉 BOM/CRLF 后完整比对相同） |
| `CHANGELOG.md`（加 4.2.0 段、两处行尾空格） | 同样两处改动，保持上游文本 |
| `tests/harness.lua`：GUARD（`debug.sethook` 每 1,000,000 条指令查堆内存与耗时，`--max-mb` / `--max-sec` 可调）、`jit.off()`、`mock.Reset` 包装（`--locale` 下每次 Reset 后重新装上客户端语言）、每个文件跑完 Reset + 两次 `collectgarbage` | 全量照搬；Reset 包装与本移植原有的 `mock.Reset` 兼容（只是包一层，不替换实现） |
| `tests/wowmock.lua`：Reset 把「被原地改过的全局」也还原（不只删掉新增的） | 加在原有「删掉新增全局」之后，防 `hooksecurefunc` 一类的 stub 每加载一次多包一层 |
| `tests/locale.lua`：ptBR 复数规则；`tests/run.lua`：新参数说明；`tests/suggest.lua`：文件内 Reset 之后重新装 deDE | 三处照搬（suggest 那条是 Reset 包装的必然副作用） |
| 本移植独有的两条词条（`UI/Windows/Intro/Tour.lua` 的 `Your first green!`、`UI/Settings/Sections/Recording.lua` 的「本客户端无法测量距离」） | 补 ptBR 译文（ptBR 现 1872/1872）；`Locales/zhCN/Changelog.lua` 补 4.2.0 两行、删掉已剪掉的 4.0.0 段 |

验证：

- `python -B tools/coa_audit.py` → OK，0 error / 0 warning（R4：zhCN 1872/1872）。
- 全量 `tests/run.lua` → **ALL 128,393 CHECKS PASSED**（121 文件）。
- 探针 `D:\DSH-source\.tmp-sd-port\probe_changelog_toc.lua`（真 TOC 全量加载，zhCN）：页面 5 个 release 共 19 行、missing 0，4.2.0 的 summary 与条目都命中中文。
- 探针 `D:\DSH-source\.tmp-sd-port\probe_ptbr.lua`：存档选 ptBR 时 `Locale.id` = ptBR，上游词条与本移植补的两条都取到葡萄牙语。
- 打包：788 文件 / 22.5 MB；dist 的 TOC 是 `## Version: 4.2.0` 且含 12 个 `Locales/ptBR/` 条目。
