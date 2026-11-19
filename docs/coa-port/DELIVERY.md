# Social Diary · CoA 移植交付说明

把 Social Diary 4.2.0（面向 "WoW Forever"、零售版客户端 API 的插件）移植并全量汉化，使其能在
Conquest of Azeroth（CoA，AzerothCore 3.3.5a 客户端，Interface 30300）上加载运行。

- 上游源（只读，未改动）：`D:\DSH-source\social_diary`
- 移植工作副本：`D:\DSH-source\social_diary_coa\social_diary`
- 发布包：`D:\DSH-source\social_diary_coa\dist\social_diary`（788 文件 / 22.5 MB）
- 安装到客户端：`D:\Game\CoA-live-64\Interface\AddOns\social_diary`

## 一、汉化（任务 1）

| 项目 | 结果 |
| --- | --- |
| 汉化默认语言 | 客户端版本第四位落在 [30000, 40000) → 默认 `zhCN`（`Locales/Locale.lua` 的 `Locale.default`）；也支持手动切换 |
| 界面词条覆盖 | `L[...]` 共 1872 条，zhCN 1872/1872（100%），且 1872 个 key 全部被代码引用（audit R4） |
| 其它语言 | 保留上游全部语言（deDE / esES / frFR / itIT / plPL / ruRU，4.2.0 新增 ptBR——巴西葡萄牙语），客户端是哪种语言就用哪种；本移植新增的两条词条也补了 ptBR 与 zhCN，ptBR 现为 1872/1872 |
| 地名 / 副本名 | 显示期翻译：手账显示中文，存档、比较、索引仍存客户端英文原名，换语言不串数据 |
| 地名表 | `Locales/zhCN/Names.lua`：240 条英中对照（enUS 232 条），另有 119 条 CoA 自创内容无中文权威源，按"留英文不臆造"处理 |
| 地图 / 职业名 | `Locales/zhCN/CoA.lua`：地图名 + 32 个 CoA 职业中文名；显示期统一出口 `Core/Location.lua` 的 `ns.ZoneShown` / `ns.MapNameShown` 与 `UI/Words/Format.lua` 的 `PlaceName` / `VisitName` / `ClassName`，存档里始终留客户端英文原名 |
| 更新日志 | `Locales/zhCN/Changelog.lua`：5 个版本 19 行（4.2.0 / 4.1.1 / 4.1.0 / 4.0.2 / 4.0.1 含子项；`Dev/changelog.lua` 只保留最新 5 个 release，旧的 4.0.0 已被上游从页面里剪掉），显示期翻译，源数据与 CHANGELOG.md 不动（有测试断言两者逐条一致） |
| 字体 | `UI/Style/Tokens.lua` 做字体探测：命中中文字体（本客户端 FRIZQT__ = ARHei = 微软雅黑，MORPHEUS = 方正粗圆）则用，失败回退 `Fonts\FRIZQT__.TTF` |
| 硬编码体检 | 残留硬编码英文已清零（4 处标题改为 `L[...]`，示例人名 Thex 有意保留英文）；种族名/子区域/CoA 自创名等无权威中文源的项按策略留英文，清单与理由：移植工作区 `docs/i18n-gaps.md` |

## 二、CoA 适配（任务 2）

### 2.1 兼容层（`Core/Compat/`，9 个文件 + NOTES.md）

按三档处理零售 API，判据全部来自从客户端 MPQ 解出的 FrameXML（`Interface\FrameXML\`、`Interface\SharedXML\`）：

- **A 真实现**：`C_Map`（成员级补全）、`C_Item`、`C_Timer`、`C_Container`、`C_QuestLog`、`C_PvP`、`C_UnitAuras`、`C_Texture`、`Settings`、`C_AddOns`、`C_CVar`、`C_CreatureInfo`、`C_FriendList`、`C_InstanceEncounter`、`C_MapExplorationInfo`、`CreateVector2D`、`TooltipDataProcessor`、`MenuUtil`
- **B 空实现**（调用不崩、不返回假数据）：`C_Bank`、`C_NamePlate`、`C_Secrets`、`C_LootHistory`、`InputUtil`、`CreateVector3D`
- **C 功能关闭（feature flag）**：手柄（`C_GamePad`）、伤害统计（`C_DamageMeter`）、死亡回顾（`C_DeathRecap`）、输入设备界面风格（`C_InputInterfaceStyle`）。shim 存在但运行路径不进入，功能安静关闭而非报错。

硬性规则：Compat 一律**成员级 guard**（`C_Map.GetMapInfo = C_Map.GetMapInfo or ...`），不许整表 guard——
客户端已经提供一部分的表只能补缺成员，否则会把真机可用的成员顶成 nil。

### 2.2 客户端适配点

| 客户端差异 | 处理 |
| --- | --- |
| Interface 16001 → 30300 | TOC 改号，删 `LoadSavedVariablesFirst` / `AddonCompartmentFunc` / `X-Category` |
| 社交面板是 `FriendsFrame`（无 `SocialUIFrame`） | `UI/Blizzard/SocialTab.lua` 在最后一个已有 `FriendsFrameTab` 右侧插入标签按钮；不改 `selectedTab`、不调 `PanelTemplates_SetNumTabs` |
| 设置面板是 `InterfaceOptionsFrame`（无 `SettingsPanel`） | `UI/Blizzard/Signpost.lua` 走 `Settings.RegisterCanvasLayoutCategory`，关闭时同时关 `InterfaceOptionsFrame` |
| 无 `C_Map.GetMapInfo/GetPlayerMapPosition` | `Core/Compat/Map.lua` 用 `SetMapByID` / `SetMapToCurrentZone` + `GetCurrentMapAreaID` 实现，每次读都 SaveView/RestoreView 还原视图 |
| 无世界坐标投影 | `GetWorldPosFromMapPos` / `GetMapPosFromWorldPos` / `GetMapWorldSize` 恒 nil：子图位置直接跳过，不伪造区域坐标 |
| 无世界坐标（`UnitPosition`） | **“你的日记”的路线记录整体不可用**：停留点、两地之间的路线、飞行段都靠世界码数（上游把“绝不用地图单位”写成设计不变量，阈值要用真实路线调），本客户端量不出码数，按“不编数据”的口径整条几何链关闭；升级点、副本行程、战斗标记仍按区域图比例记录。设置页的开关说明会直接写出这一点，`/sd journey stats` 里每次跳过的原因都是 no world position (UnitPosition) |
| 无 `C_Map.GetMapArtLayers` | 地图只画区域底图与外框，无图钉图层、无探索图层 |
| 无 `GetAtlasInfo` | 图标全部降级为贴图文件路径或纯色块，地图羽化关闭 |
| 无 `TooltipDataProcessor` | hook `GameTooltip` / `ItemRefTooltip` 的 `OnTooltipSetUnit`（注意 3.3.5 `GetUnit()` 返回两个值） |
| 无 `RegisterUnitEvent` | 篝火捕获改为 `RegisterEvent` |
| `GetInstanceInfo` 只 7 个返回值（无 instanceID） | 副本查找三层：instanceID/mapID → 区域名 → CoA 自建表 `Capture/CoA.lua` |
| 无战场 `PVP_MATCH_*` 事件 | 用 `UPDATE_BATTLEFIELD_STATUS` + `UPDATE_BATTLEFIELD_SCORE` + `GetBattlefieldWinner()` 收尾 |
| 无 `Menu.ModifyMenu` / `C_PlayerInfo` | 右键菜单"记住这个人"等条目安静不出现 |
| 无 `CreateMaskTexture` | 卡片羽化关闭，其余照常 |

### 2.3 CoA 内容表（`Capture/CoA.lua`）

等级上限 60；32 个职业（id/name/token/资源/中文名，按客户端 `ChrClasses` DBC 权威顺序）；65 个战场/竞技场；
103 个副本/团队（来自客户端 `LFGDungeons` DBC，按 MapID 去重）。`CoA.Name()` 惰性查中文（条目自带 zh →
地名表 → 英文原名），不预填，UI 副本标题直接出中文。

## 三、验证

- 静态审计 `python -B tools/coa_audit.py`：R1（零售 API 分类）～R6（mock 不得替 Compat 作弊）全 PASS，
  0 error / 0 warning。
- 单元测试 `tests/run.lua`（LuaJIT + 3.3.5 形状的 `tests/wowmock.lua`）：移植前基线 121 文件 /
  124356 checks，3 个失败（Unix `find`）；当前结果见 `VERIFY.md`。
- 打包实测 `python tools/coa_pack.py`：776 文件 / 22.3 MB，TOC 按 `#@do-not-package@` 截断，发布包内
  Dev 块 0 个文件。
- 失败分类口径（T/P/D）与等价验证记录：`VERIFY.md`。

## 四、明确未验证

1. **真机加载**：本轮未启动游戏客户端，插件的实际加载、报错、事件行为均未在游戏内确认。
2. **中文渲染宽度**：中文字体命中与断行/裁切只在探针层面验证，未在真机截图比对。
3. 自创内容的中文全部留英文（无权威中文源），这是策略而非遗漏。

## 五、已知降级清单（交付必读）

**路线记录（停留点 / 路线 / 飞行段）在 3.3.5 上不可用**——这是本次移植最大的功能降级，原因与替代（升级点、副本行程、战斗标记）见 §2.2；设置页有说明，`/sd journey` 可查跳过原因。

伤害统计缺失 → "千钧一发"永不触发（安静关闭，不崩、不出空卡）；战场记分板缺 guid 与 per-BG stats（靠对局中按名字合并填空）；副本只按实例名匹配（`LFGDungeons` 的 MapID 与 `WorldMapArea` 不同域）；936 Vaults of Inquisition / 937 Road to De Other Side 被服务器 SQL 锁定；Atal'Zul 只在客户端 DBC、服务端无数据；50 条 CoA 自创战场无中文来源。
