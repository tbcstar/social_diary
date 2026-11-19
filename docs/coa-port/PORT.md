# Social Diary → CoA (3.3.5a) 移植 + 汉化：总纲与契约

本文件是本次工作的唯一权威契约。所有参与者先读本文件，再读自己范围内的代码。

## 0. 目标

把 `D:\DSH-source\social_diary`（Social Diary 4.1.1，为 **WoW Forever** 写的、
**retail 插件 API / Interface 16001** 的插件）移植到 **Conquest of Azeroth (CoA) 客户端 = 3.3.5a / WotLK API**，
并让插件默认以**中文**显示。

- 源目录（只读，不要改）：`D:\DSH-source\social_diary`
- 移植工作目录（唯一写入区）：`D:\DSH-source\social_diary_coa\social_diary`
  （该目录名 `social_diary` 就是插件文件夹名，安装时整目录复制到 `Interface\AddOns\social_diary`）
- 安装目标（最终交付时由 Lead 复制，不要自己写）：`D:\Game\CoA-live-64\Interface\AddOns\social_diary`

## 1. 已核实的环境事实（有证据，不要再猜）

客户端：`D:\Game\CoA-live-64\CoA64.exe`（14MB，WotLK 3.3.5a 客户端，Ascension/CoA）。
在 exe 二进制里查 Lua API 符号名的结果（命中=存在，0=不存在）：

| 存在（3.3.5 风格） | 不存在（retail 专有） |
|---|---|
| `GetCurrentMapAreaID` `GetMapInfo` `GetPlayerMapPosition` `SetMapByID` `GetMapZones` `GetCurrentMapZone` | `C_Map` `GetBestMapForUnit` `GetWorldPosFromMapPos` `CreateVector2D` `UnitPosition` |
| `UnitAura` `GetNumRaidMembers` `GetNumPartyMembers` `UnitGUID` `GetInstanceInfo` | `C_Container` `GetNumGroupMembers` `SetColorTexture` `issecretvalue` `UnitTokenFromGUID` |
| `GetItemInfo` `GetContainerItemInfo` `GetAddOnMetadata` `IsAddOnLoaded` `GetQuestLogTitle` | `C_Timer` `C_AddOns` `C_Item` `C_QuestLog` `Enum` `Settings` `GetSpecialization` |
| `SetBackdrop` `CreateAnimationGroup` `hooksecurefunc` `strsplit` `wipe` | `BackdropTemplate` `AddonCompartment` `CombatLogGetCurrentEventInfo` |

补充：
- 客户端 locale 是 **enUS**（`WTF\Config.wtf: SET locale "enUS"`），但 `Fonts\` 全是中文字体
  （`ARHei.ttf`/`ARIALN.TTF`/`ARKai_T.ttf` 14MB、`bKAI00M.TTF`/`bHEI00M.TTF`/`ZYHei.ttf` 8.5MB 等），
  所以中文能正常显示，**不需要**改字体文件，只需把 SetFont 的路径指到这些字体。
- 客户端读 **UTF-8** 的 lua/xml。
- `FrameXML` 不在磁盘上（在 MPQ 里），因此 `InterfaceOptions_AddCategory`、`PanelTemplates`、
  `GameFontNormalHuge` 这类 FrameXML 函数在 exe 里查不到是正常的，**3.3.5 的 FrameXML 里它们存在**。

## 2. 硬性规则

1. **所有 retail 全局名一律保留**。移植的做法是：在 `Core/Compat/*.lua` 里**定义同名全局**
   （`C_Map`、`C_Item`、`C_Timer`、`Enum`、`C_UnitAuras`…），用 3.3.5 API 实现；
   业务代码（`Core/Location.lua`、`UI/...`、`Features/...`）继续按原来的写法调用。
   这样 370 个文件的业务逻辑改动最小。
2. **只有 `Core/Compat/` 里允许出现 retail 专有名**（`C_*`、`Enum.`、`Settings.`、`issecretvalue`、
   `AddonCompartment`、`BackdropTemplate`、`SetColorTexture`、`GetNumGroupMembers`…）。
   其它目录出现即视为未完成（有静态审计脚本会查）。
3. **不要编辑 `Vendor/DungeonCrawlerForever/` 任何文件**（上游 GPL 原样数据，只允许 `Core/Dungeons.lua` 读它）。
4. 玩家能读到的字符串**必须**走 `L["..."]` / `ns.T` / `ns.Plural`；新增文案后要重生成 `Locales/enUS.lua`
   （`Dev/Locale/extract.lua`）并让 `Locales/zhCN/*.lua` 有对应词条。
5. 源码注释、标识符保持 **英文**（与上游风格一致）；`Locales/zhCN/` 才是中文。
6. **不许回归**：`tests/run.lua` 必须保持全绿（见 §6）。改了共享行为要同步改测试。
7. 存档兼容：不许无迁移地删/改 `SocialDiaryDB` / `SocialDiaryCharDB` 字段（`Core/DB.lua` 的 `STEPS`）。
8. 写入范围互斥（见 §4），越界改别人的文件 = 冲突。
9. **Compat 一律「成员级 guard」，不许整表 guard**：客户端**已经有一部分的表**必须只补缺失成员。
   `if not C_Map then ... end` 在真客户端上整块跳过（`C_WorldMap.lua:188` 只定义了 `C_Map.GetBestMapForUnit`），
   结果是 `C_Map.GetMapInfo` / `GetPlayerMapPosition` / `GetMapArtLayers` 在游戏里是 `nil` —— 这是 verify-port 查实的真 bug。
   正确写法：`if not C_Map.GetMapInfo then function C_Map.GetMapInfo(id) ... end end`；
   整表缺失时才建表，表已存在时逐个成员判空。同理适用于 `Enum`（只加成员）、`C_Timer`、`C_CVar`、`C_NamePlate`。

10. **TOC 里的文件条目一律用反斜杠 `\`**（`Core\Addon.lua`）。3.3.5 客户端把 TOC 行按字面拼到
   插件目录后面，不做分隔符归一化：写 `Core/Addon.lua` 会得到
   `Interface\AddOns\social_diary\Core/Addon.lua`，客户端对**每一行**打一条 `Error loading`，
   整包 Lua 一行都不执行（插件列表里还有名字、勾选也在，只是 `/sd` 不存在）。上游为 retail 写的是 `/`，
   所以合并上游 TOC 后必须再转一次；`tools/coa_audit.py` 的 R2 会拦。

## 3. 兼容层契约（`Core/Compat/`，owner: core-port）

每个文件在 TOC 里紧跟 `Core/Addon.lua` 之后、`Locales/` 之前加载。**按成员补齐，不做整表 guard**（硬性规则 9）：
整表不存在时才创建整张表；整表已存在（客户端给了一部分成员）时，逐个成员 `if not X.Y then` 补。
判据来自解出的客户端 FrameXML（`_ui-port-scratch/out/Interface/`）：能在里面 grep 到定义的成员就是客户端原生，只能补缺、不能覆盖。

| 文件 | 提供的全局 | 用 3.3.5 实现 |
|---|---|---|
| `Core/Compat/Env.lua` | `issecretvalue`(=nil)、`strsplit/strtrim/strjoin/wipe`(缺失时)、`Mixin`、`CreateFromMixins`、`UnitTokenFromGUID`、`GetNumGroupMembers`、`GetItemInfoInstant`、`Enum`(用到的子表)、`C_Timer`(After/NewTimer/NewTicker，OnUpdate 驱动)、`C_AddOns`、`C_ChatInfo` | OnUpdate 计时器池；`GetNumRaidMembers()>0 and GetNumRaidMembers() or GetNumPartyMembers()`；`UnitTokenFromGUID` 扫 player/target/focus/partyN/raidN |
| `Core/Compat/Map.lua` | `C_Map` + `CreateVector2D` | 见 §5 |
| `Core/Compat/Items.lua` | `C_Item`、`C_Container`、`C_CurrencyInfo`(若用到) | `GetItemInfo`/`GetContainerItemInfo`/`GetContainerNumSlots` 包装 |
| `Core/Compat/Quests.lua` | `C_QuestLog`、`C_Spell` | `IsQuestFlaggedCompleted`(3.3.5 有)、`GetQuestLink`、`GetSpellInfo`/`GetSpellLink`/`IsSpellKnown` |
| `Core/Compat/Units.lua` | `C_UnitAuras`、`C_PlayerInfo`、`C_PartyInfo`、`C_Friend`、`GetSpecialization`/`GetSpecializationInfo` | `UnitAura(unit,i,filter)` → 表；`GetPlayerInfoByGUID`；`GetNumSubgroupMembers`；`GetTalentTabInfo` |
| `Core/Compat/PvP.lua` | `C_PvP` | `GetBattlefieldScore`/`GetBattlefieldStatData`/`GetNumBattlefieldScores` |
| `Core/Compat/Textures.lua` | `Texture:SetColorTexture`、`C_Texture`、`SetAtlas` | `SetTexture(r,g,b,a)`；atlas → 3.3.5 贴图路径或 nil（调用方必须能接受 nil） |
| `Core/Compat/Settings.lua` | `Settings` | 注册表 + 打开插件自己的设置页（`UI/Settings/Page.lua`），并在 3.3.5 的 Interface Options 里加一个入口 |

**`SetColorTexture` 是 240 处**：只要把 `Texture:SetColorTexture` 补上（`SetTexture(r,g,b,a)`），
这 240 处一行都不用改。

要求：Compat 里每个函数都要 `pcall` 保护的调用方假设最小化；返回 shape 必须匹配 retail 文档
（例如 `C_Map.GetMapInfo` 返回 `{ name, mapType, parentMapID, mapID }`，
`C_Map.GetPlayerMapPosition(mapID, unit)` 返回带 `:GetXY()` 的对象）。

## 4. 写入范围（互斥）

| 角色 | 可写 |
|---|---|
| core-port | `social_diary.toc`→`social_diary_coa.toc`、`Bindings.xml`、`Core/**`（含 `Core/Compat/`）、`Features/*/Dev.lua` 不动 |
| ui-port | `UI/**` |
| features-port | `Features/**`（除 `Features/*/Dev.lua`）、`Capture/**` |
| l10n-port | `Locales/**`、`Dev/Locale/**`、`CHANGELOG.md` |
| verify-port | `tests/**`、`tools/**`（新建） |

跨范围需要的改动 → 用 `send_message` 找 owner，别自己改。

## 5. 地图/坐标策略（3.3.5 没有 C_Map）

- 区域身份以 **名字** 为准：`GetRealZoneText()`（3.3.5 有），mapID 只是附加值。
- `C_Map.GetBestMapForUnit("player")`：缓存 + `ZONE_CHANGED*` 事件驱动；
  实现用 `SetMapToCurrentZone(); GetCurrentMapAreaID()`，**并在调用后恢复玩家原来的地图视图**
  （保存 `GetCurrentMapContinent()`/`GetCurrentMapZone()`，用 `SetMapZoom` 还原）。
  绝不允许每次 `ns.Where()` 都把世界地图重置到玩家位置（会把玩家的地图浏览打断）。
- `C_Map.GetMapInfo(id)`：`SetMapByID(id)` → `GetMapInfo()` → 还原。
- `C_Map.GetPlayerMapPosition(mapID, "player")`：同上，用 `GetPlayerMapPosition("player")`（返回 x,y 0..1）。
- `C_Map.GetWorldPosFromMapPos` / `GetMapPosFromWorldPos` / `CreateVector2D`：3.3.5 **无等价物** →
  返回 nil。调用方（`Core/Location.lua` 的 `Project`）已有 nil 分支，只是"路线不再跨子地图投影"。
- `UnitPosition`（世界坐标/码）3.3.5 **无** → `ns.WorldWhere()` 退化为 nil；
  依赖"码"的邻近判定改用 3.3.5 的 `CheckInteractDistance(unit, 1..4)`（28/10/8/11 码档位）
  + `UnitIsVisible`，**不许编造距离**。
- `Enum.UIMapType`：zone=3、continent=2、world=1（3.3.5 的 `GetMapInfo` 第二返回值给出 mapType 时用它；
  没有就按大陆/区域名表判断）。

## 6. 验证（每个人的自检门）

运行测试（LuaJIT 通过 lupa 提供，无需装 luajit）：

```
cd D:\DSH-source\social_diary_coa\social_diary
python -B D:\DSH-source\.tools\luarun.py tests/run.lua
```

基线：源目录 121 个测试文件、124356 个断言；其中 `kinds`/`ui_layout`/`copy_rules` 因用了 Unix `find`
在本机失败（verify-port 负责修成跨平台）。

静态审计（verify-port 提供）：`python -B tools/coa_audit.py` —— 检查 retail 专有名只出现在
`Core/Compat/`、TOC 列出的文件都存在、每个 `L["..."]` 都有 zhCN 译文、`.lua` 全部 UTF-8。

## 7. 汇报格式

每个角色完成任务后在共享任务板上 `complete`，并在消息里给 Lead：
1. 改了哪些文件（路径 + 一句话）；
2. 新增/修改的 shim 及其 3.3.5 实现要点；
3. 自检结果（测试通过数/失败项、审计结果）；
4. 仍然降级/做不到的点（明确写"未验证"）。
