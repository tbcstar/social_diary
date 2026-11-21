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

11. **客户端有的函数，签名未必和 retail 一样**：名字存在 ≠ 能这么调。例：`IsKeyDown` 在本客户端收**数字键码**
   （它自己的 `FrameXML/GameTooltip.lua:1203` 传 `Enum.Key.F1`），照 retail 传按钮名 `"PAD1"` 会抛
   `bad argument #1 to 'IsKeyDown' (number expected, got string)`，而且每个鼠标按下刷满屏。
   跨版本调用的写法：先试客户端认的形态（`Enum.Key[name]`），拿不到就 `pcall` 探一次并**缓存结论**，
   以后不再问（`UI/Pad/Input.lua` 的 `Pad.KeyDown`）。判断"客户端有没有这个函数"用解出的 FrameXML 搜定义，
   判断"能不能这么调"只能靠探针或真机，不要凭名字假定。

12. **从 Blizzard 模板造的控件要带名字，不要的模板脚本要显式清掉**。3.3.5 的模板脚本按名字取子纹理
   （`_G[button:GetName() .. "Middle"]`，`FrameXML/UIPanelTemplates.lua:41` 的 `PanelTemplates_TabResize`），
   **无名按钮**直接抛 `attempt to concatenate local 'tabName' (a nil value)`，而且触发点常常是别的插件
   显示那个窗口的时候（真机 19 Nov 2026：DragonUI 预热 `Show()` 社交窗 → 我们挂在好友窗上的标签页报错）。
   做法：`CreateFrame` 时给名字；模板自带、我们又不参与的那套处理器一律 `SetScript("OnShow", nil)`
   （`UI/Blizzard/SocialTab.lua`，测试见 `tests/socialtab.lua`）。

13. **缺失的控件方法在 `Core/Compat/Widgets.lua` 一次性补齐，不要在几十个调用点各加 guard**。探针（`sd_probe`，345 个名字 × 16 种控件）查出本客户端**全部 16 种控件上都没有**的 23 个方法：
   `AddMaskTexture、CreateMaskTexture、EnableGamePadButton/Stick、GetFontObjectForAlphabet、GetOpenMenu、GetRotation、GetUnboundedStringWidth、IsGamePadButtonEnabled/StickEnabled、IsMouseClickEnabled、IsTruncated、RegisterCallback、SetClipsChildren、SetDesaturation、SetFixedFrameStrata、SetMaxLines、SetMouseClickEnabled、SetObeyStepOnDrag、SetPropagateKeyboardInput、SetSnapToPixelGrid、SetTexelSnappingBias、SetVertexOffset`。
   做法与 `Textures.lua` 的 `SetColorTexture` 相同：`getmetatable(widget).__index` 是该类控件的共享方法表，逐个**只在缺失时**填（成员级，绝不覆盖客户端自带的）；`SetDesaturation` 走 `SetDesaturated`，`GetUnboundedStringWidth` 退回 `GetStringWidth`，其余是 no-op / `false` / `nil`。真机 19 Nov 2026 的崩溃 `UI/Kit/List.lua:362: attempt to call method 'SetClipsChildren' (a nil value)` 就是它修的。
   **不要**补 `CreateMaskTexture`/`AddMaskTexture`（假 mask 会印错图，调用点本来就先问 `if x.CreateMaskTexture then`，见 `UI/Map/Dungeon.lua:203`）、`EventRegistry:RegisterCallback`（不是控件方法，`UI/Windows/Reunion/Placing.lua:94` 自带 guard），**尤其不要补 `SetVertexOffset`**。
   `SetVertexOffset` 不是普通的"缺失方法"而是**能力判据**：`UI/Style/Draw.lua:197` 的 `Style.Quad` 先问 `if not texture.SetVertexOffset then return false end`，问不到就返回 false，让调用方走"画平 / 隐藏"的降级分支；补成 no-op 后它**谎报成功**，每条笔迹、纸边、三角都被画成自己的**轴对齐外接矩形**（真机 19 Nov 2026：日记书页变成一片实心米黄与黑色色块；同形判据见 `UI/Paper/Surface.lua:73-94`、`UI/Paper/Sheet.lua:471` 与 `:505`、`UI/Paper/Strip.lua:339`、`Features/Witnesses/Card.lua:591`）。教训：补任何一个方法之前，先查它有没有被 `if x.M then` 当成能力判断用。测试见 `tests/widgets.lua`（断言 `SHIMS.SetVertexOffset == nil`、且 `Style.Quad` 在补过方法的控件上返回 false）。

14. **不是控件"方法"缺失，而是控件没有那个"脚本槽"**：3.3.5 的普通 Frame 上**没有** `OnHyperlinkClick` /
    `OnHyperlinkEnter` / `OnHyperlinkLeave`，`SetScript` 用这三个名字会抛
    `<unnamed> doesn't have a "OnHyperlinkClick" script`（真机 19 Nov 2026，`UI/Journey/Left.lua:491`，一开日记就炸）。
    本客户端只在自己的聊天框 / simple HTML 上认这三个名字（`_ui-port-scratch/out/Interface` 里 `ChatFrame.xml:15`、
    `SharedPanelTemplates.lua:1379`、`UIPanelTemplates.xml:966`），普通按钮没有。做法：先建一个自家按钮 `pcall` 探
    `SetScript`，结论缓存；没有就**不给控件设这三个脚本，文本里也别写 `|H...|h` 标记**（客户端会当原文读出来），
    名字改用纯色 `|cff<hex>名字|r`（`UI/Journey/Left.lua` 的 `TakesLinks` / `LinkScript` / `PLAIN`，测试见
    `tests/links.lua`，它用一个拒绝超链接脚本的假客户端复现崩溃）。

15. **同一个函数在不同客户端版本上形态不同时，用一次探测定形态，别照抄 retail 的参数类型**：本客户端的
    `SetGradient` 收**6 个数字**（它自己的 `FrameXML/CompactUnitFrame.lua:1665` 就这么调），带 alpha 的渐变走
    `SetGradientAlpha` 的**8 个数字**（`SharedXML/SharedPanelTemplates.lua:1346`、装上就有的 DragonUI
    `modules/hp_low_alert.lua:61-64`）；retail 收两个 `CreateColor` 对象。上游按 retail 传对象给数字形参，
    C 层把表当 **0** 吞掉、`pcall` 照样返回 true，于是整条渐变变成纯黑，**没有任何报错** —— 真机 19 Nov 2026
    空日记右页那条"黑底纸片"（`UI/Journal/Empty.lua` 的 light 纸片）就是这么来的。做法：能力判断集中一处，
    `UI/Style/Draw.lua` 的 `Style.Gradient` 建一个自家 texture 探一次并缓存形态（numbers / colours），
    数字客户端有 alpha 走 `SetGradientAlpha`，没有就退化到 6 数字 + 平均 alpha，最后才是平均色平涂；
    第 5 个参数 `keepArt` 表示保留原图只染色（`UI/Paper/Light.lua` 的 `Light.Tint`、`UI/Paper/Sheet.lua` 的
    `Grime` 都是转调它，别再各自 `pcall`）。教训：`pcall` 不报错 ≠ 调用生效，凡是"传对象 / 传数字"两种写法的
    API，都要像规则 11 那样先确认客户端认哪种。测试见 `tests/gradient.lua`。

16. **"不能弯"要当成"铺平"来画，别只当成"少一次调用"**：纸张的网格（`UI/Paper/Sheet.lua` 的
    `Crumple`/`FacetLight`）描述的是**能弯的纸**被光照成什么样；客户端的纹理移不了角（`SetVertexOffset` 缺失）时，
    每个 facet 只能画成自己的矩形，于是同一张纸被 21 种明度的矩形拼成**马赛克**（真机 19 Nov 2026：引导 1/5 页整页
    方格网，色块不再实心但一层层半透明接缝清晰）。作者已经写好了"铺平"这条路径（`flatSheets`）：facet 一律同色、
    不画 crease、不画 grime。做法：`Lay` 里加 `view.unbent = view.flat or not view.bends`，`FacetLight` 与四处
    crease/grime 循环都改判它（`UI/Paper/Sheet.lua:358、:693、:705、:723、:730`）。教训：能力缺失不只要退掉那次
    调用，还要退掉**基于该能力的外观假设**。测试见 `tests/sheet_flat.lua`（同一张纸，弯与不弯各画一次，断言不弯时
    只有一种纸色、零 crease、零 grime；把 `view.unbent` 改回 `view.flat` 立刻变 22 种纸色而失败）。

17. **本客户端的 map id 有两套编号，差 1**：`SetMapByID` 收的是 **WorldMapArea.dbc 的 id**，而
    `GetCurrentMapAreaID` 返回的是**它 + 1**。客户端自己的 FrameXML 就是这么用的：
    `FrameXML/WorldMapFrame.lua:1582-1606` 先 `local mapID = GetCurrentMapAreaID() - 1` 再 `SetMapByID(mapID)`，
    `:2337-2339` 把 `GetQuestWorldMapAreaID`（DBC id）直接喂进去；`FrameXML/Util/C_WorldMap.lua:3-34` 的
    continent/city 表逐条 = DBC id + 1（301 Stormwind…504 Dalaran、13 Kalimdor、14 Azeroth=东部王国、485 Northrend）。
    所以 `Core/Compat/Map.lua` 的 `MapInfo` 写 `pcall(SetMapByID, mapID - 1)`，再用 `GetCurrentMapAreaID() == mapID`
    判客户端是否真认得这张图（三张表的对账记在 `Core/Compat/NOTES.md`）。**存档、设置里一律用客户端报的那个 id**。
    但同一个地图在两代客户端上的 id 不同（零售 1453 Stormwind City… vs 本客户端 301/321/341…），所以城市清单（SIG-5）
    改存**区域名**：`Core/DB.lua` 的 `cities` 用 `"Stormwind City"` / `"Orgrimmar"` 这类 key，`CHARACTER_SCHEMA = 3`
    加 `STEPS.character[3]` 把旧的 1453..1458 搬过去（值 true/false 一起搬，删掉旧键）；`ns.City()` 先查 sanctuary、
    再按 `GetBestMapForUnit` 的 id 与父级（数字 key 仍支持，`/sd sightings city add 1454` 照样有效），最后由
    `GetRealZoneText()` 的区名命中；显示走 `ns.ZoneShown`。DBC 拼写与中文名对不上时（`Ogrimmar`/`ThunderBluff`/`Darnassis`、
    东部王国整块图叫 `Azeroth`）在 `Locales/zhCN/Names.lua` 补别名，别改 raw 值。测试的 mock 也照这个偏移建模
    （`tests/wowmock.lua` 的 `SetMapByID` 与 `SetMapToCurrentZone`），否则 shim 与 mock 会互相"证明"错的语义。
18. **区域名不够用时，从客户端自己的 DBC 取，别手抄**：本机客户端是 `locale=enUS`，`GetRealZoneText`、子区域名、
    `C_Map.GetMapInfo` 给的全是英文；`Locales/zhCN/Names.lua` 手写了 244 条（大陆、城市、副本、战场、职业），
    覆盖不到两千多条区域 / 子区域名。`Locales/zhCN/Areas.lua` 由 `tools/dbc_areas.py` 生成：读
    `Data\patch-AAS.mpq` 里的 `DBFilesClient\AreaTable.dbc`（WDBC 格式，2307 行 / 36 字段；名字是 16 语种块，
    从记录的字段 idx 11 起，**块内第 5 列就是简体中文**），得到 2105 条「英文 → 中文」，写进与手写表**同一张**
    `CoA.zhNames`（`or` 合并，手写词条优先；反向表 `CoA.enNames` 一起补，设置页搜中文也能命中）。DBC 中文里夹在
    音节中间的间隔号换成空格，因为 `tests/copy_rules.lua` 不许玩家可见文本出现间隔号。生成器不在插件包里，
    重新生成用 `py -3 -B tools\dbc_areas.py`；改译名改生成器的过滤而不是改产物。**只用于显示**：raw 英文名照旧
    进存档、做键、做比较（与 `docs/coa-port/i18n-gaps.md` 的原则一致），`CoA.zhName` / `ns.ZoneShown` 查不到原样返回。
    测试见 `tests/areas.lua`（一条只在 DBC 里有的子区域名、手写词条不被覆盖、未知名字不变、反向表可查）。
19. **绝不覆盖客户端自己的全局函数/表（`CreateFrame` 这类）**：addon 给一个全局赋新值，这个全局在本会话里就带污染（tainted），
    之后**客户端自己的安全代码**通过它造出来的东西也带污染——2026-11-21 真机弹「插件 social_diary 污染了安全函数
    `UseAction()` 的调用」，安全动作按钮点下去调的就是 `UseAction`。所以 `Core/Compat/Textures.lua` 里那段「把
    `_G.CreateFrame` 换成剥掉 `BackdropTemplate` 的包装」已删除：改成一次性探测 `ns.BackdropTemplate`
    （`pcall(CreateFrame, "Frame", nil, UIParent, "BackdropTemplate")` 成功才给字符串，3.3.5 给 nil），
    `UI/Kit/Chrome.lua` 只在拿到值时才把这个 token 传给 `CreateFrame`（3.3.5 的 Frame 本来就能直接 `SetBackdrop`）。
    要给客户端已有的表补东西，按硬性规则 9 只补缺失成员，绝不整表替换。
20. **中文名的权威来源是客户端自己的 DBC：`Data\patch-ZH.mpq` 把名字列直接写成了简体中文**。
    本机客户端装了两份同名表——`patch-M.mpq` 是英文，`patch-ZH.mpq` 后加载（优先级更高）而它改写
    `DBFilesClient`，把同一个名字列换成了中文：`ChrClasses.dbc` 第 4 列、`ChrRaces.dbc` 第 14 列、
    `Map.dbc` 第 5 列、`AreaTable.dbc` 第 11 列、`BattlemasterList.dbc` 第 11 列（`Faction` 第 23 列、
    `SkillLine` 第 3 列同理）。所以「DBC 的 zhCN 列是空的、没有权威中文」是**旧结论，已作废**：
    职业、种族、地图、副本、战场、竞技场名一律从客户端抄，不自己编译名、不等社区译名。
    落地：`Capture/CoA.lua` 的 `CoA.classes`（32 职业）与 `CoA.races`（42 行，含 51-63 的 NPC 重复行）
    带 `src = "client-dbc"`，`CoA.RaceName(name, id)` 供显示用；`Locales/zhCN/Maps.lua` 由
    `tools/dbc_maps.py` 从 `Map.dbc` + `BattlemasterList.dbc` 生成 348 条名字与 353 个 map id。
    合并一律 `or`（手写表优先）：客户端个别译名比官方差（`Map.dbc` 229 写作「黑石山」，我们保留
    「黑石塔」；607「先祖海滩」vs「远古海滩」），这类以手写表为准。`AreaTable.dbc` 两份补丁的中文
    **逐条相同**（2105 条 diff = 0），所以 `Locales/zhCN/Areas.lua` 不用重生成。
    重新生成：`py -3 -B tools\dbc_maps.py`；改译名改生成器的过滤而不是改产物。
    测试见 `tests/dbc_names.lua`（职业/种族/竞技场/场内名与 id 表、手写优先、翼名拼装）与 `tests/areas.lua`
    （`CoA.todoNames` 现在只剩客户端 DBC 也没有的 4 条，且每条必须确实没有中文）。
21. **按空白切词的分行器在中文上等于不分行**：中文没有空格，整句就是一个「词」，greedy 分行器只回
    一行（21 Nov 2026：引导第 3 步「与你互动过的每位玩家…」被画成 600px 的一整行，越出纸片与书页）。
    修法（`UI/Paper/Strip.lua` 的 `Wrap`）：一个词比一行还宽时，**按 UTF-8 字符**（`[%z\1-\127\194-\255][\128-\191]*`）
    切到放得下为止；只对含**宽字符**（U+3000 以上，`[\227-\239][\128-\191]`）的词这样做——
    拉丁词保持完整，因为引文（`Said`）的契约是「一个词放不下就到此为止、加省略号」，中途断开会让
    省略号逻辑失效（`tests/journey_ui.lua` 的 "a word too wide for the strip"）。
    连带：`Alone`（平衡行尾单字）不能把中日文行当成「一个词」——它没有空格但不是可下移的词，
    否则 `Balanced` 会反复重排；判据用同一个 `WIDE`，**不要**用 `[\194-\255]`（会把不换行空格
    `U+00A0` 也排除掉，`3 h 20 min` 这类绑定的时间就不再被当成一个词）。测试见 `tests/paper_strip.lua`。
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
| `Core/Compat/Widgets.lua` | `Frame/Texture/FontString/Button/...` 的 retail 专有方法（见硬性规则 13）：real 缺失的补 no-op 或 3.3.5 等价物 | 空实现/`SetDesaturated`/`GetStringWidth` |
| `Core/Compat/Textures.lua` | `Texture:SetColorTexture`、`C_Texture`、`SetAtlas`、`ns.BackdropTemplate` | `SetTexture(r,g,b,a)`；atlas → 3.3.5 贴图路径或 nil（调用方必须能接受 nil）；`ns.BackdropTemplate` 探测客户端认不认该模板，不覆盖 `CreateFrame`（硬性规则 19） |
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
- `C_Map.GetMapInfo(id)`：`SetMapByID(id - 1)`（本客户端的偏移，见硬性规则 17）→ `GetMapInfo()` → 还原。
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