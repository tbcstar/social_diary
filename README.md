# Social Diary · CoA 版

一个记录你在这片世界上遇见谁的魔兽插件：和谁组过队、和谁交易过、谁在密语里
找过你、谁和你并肩或对砍过、谁杀过你、路上瞥见过谁，以及你们后来又重逢在
哪一天。它同样记下你自己的旅程——等级、第一次、走过的区域、千钧一发、幸运
掉落、长任务线的终点、专业上限——全部自动写进一本纸质手账。

本仓库是 [Social Diary](https://github.com/social-diary/social_diary) 4.2.0 的
**Conquest of Azeroth（CoA）移植版**：目标客户端是 **3.3.5a（WotLK）+ CoA**，
Interface 号为 **30300**，并已全量汉化（默认中文）。源码在
[tbcstar/social_diary](https://github.com/tbcstar/social_diary) 的 `coa-port` 分支，
基线是上游 v4.2.0。

## 安装

把整个 `social_diary` 文件夹放进客户端的 `Interface/AddOns` 目录，然后重启
客户端或 `/reload`：

```
<客户端目录>/Interface/AddOns/social_diary/
```

本仓库自带的打包脚本会按 `.pkgmeta` 的排除规则生成干净的发布目录（不含
`tests/`、`Dev/` 与开发期脚手架），并可直接安装：

```powershell
python tools/coa_pack.py            # 只打包到 dist/social_diary
python tools/coa_pack.py --install  # 打包后复制进客户端 Interface/AddOns
python tools/coa_pack.py --info     # 只对照本插件与客户端已装插件的 Interface 号
```

默认客户端路径是 `D:\Game\CoA-live-64`，可用 `--client` 指定。更多安装与排错
见 [INSTALL.md](docs/coa-port/INSTALL.md)。

## 移植记录

这次移植做了什么、哪些能力在 3.3.5a 上降级、怎么验证的，都写在仓库里：

- [PORT.md](docs/coa-port/PORT.md)：移植契约（能力三档、存档兼容、失败关闭）
- [DELIVERY.md](docs/coa-port/DELIVERY.md)：交付清单与逐条验收
- [VERIFY.md](docs/coa-port/VERIFY.md)：验证记录与结果
- [i18n-gaps.md](docs/coa-port/i18n-gaps.md)：汉化的取舍与留英文清单

这些文档不打进发布包（`.pkgmeta` 的 `docs` 排除项）。

## 上手

第一次进入游戏会弹出引导卡片；之后输入 `/sd` 打开手账。建议在设置里给手账和
“记住这个人”各绑一个快捷键。

### 手账是怎么记的

只是擦肩而过的人会被**铅笔轻轻记下**，30 天没再出现就擦掉（期限可在设置里改）；
你亲手加进来的人会被**墨迹写上**，永久保留。

设置里的“界面 → 键位与快捷键”提供手账与“记住这个人”的按键，以及可以拖到动作
条上的宏。

## 语言

- 客户端是 3.3.5a 时默认中文（`zhCN`），也可在设置里切换到其他语言；保留了上游的
  德语、西班牙语、法语、意大利语、波兰语、俄语，以及 4.2.0 新增的巴西葡萄牙语。
- 界面字符串 100% 走 `L[...]`，中文词条 1876/1876 全覆盖；界面里不再有遗漏的
  英文标题。连引导里的示例人物名也译成中文（Thex Theximus → 塞克斯 塞西姆斯、
  Bram Redfen → 布拉姆 雷德芬），英文客户端仍读原名。
- 插件列表（AddOns）里显示的名字与说明也是中文（“冒险日记”/“记住你在野外
  遇见的每一个人。”）：直接写进 `social_diary.toc` 的 `## Title` / `## Notes`，
  因为 3.3.5 的插件列表对每个客户端语言只认一套标题，而 CoA 客户端只装了
  enUS；上游英文原文留在同一处的注释里，合并上游时照着核对。
- **地名、副本名、职业名是“显示期翻译”**：手账里显示中文（含 32 个 CoA 职业
  的中文名），存档、比较、索引仍用客户端英文原名与职业 token，因此换语言或换
  客户端不会串数据；英文客户端下这些名字仍是英文。
- **中文名不靠猜，抄客户端自己的表**：CoA 客户端装了 `Data\patch-ZH.mpq`，它把
  DBC 的名字列本身改写成了简体中文。所以 `Locales/zhCN/Maps.lua`（`tools/dbc_maps.py`
  生成）逐条抄 `Map.dbc` / `BattlemasterList.dbc` 的 348 个名字（副本、战场、竞技场、
  CoA 自创区域），`Locales/zhCN/Areas.lua` 抄 `AreaTable.dbc` 的 2,105 个区域名；
  32 个职业名与 42 行种族名照抄 `ChrClasses.dbc` / `ChrRaces.dbc`。手写表优先，
  个别客户端写法与官方译名不同时（如它把 229 写作「黑石山」）保留「黑石塔」。
  仍留英文的只有客户端表里也没有名字的（天赋、物品、任务、NPC 名），取舍见
  [i18n-gaps.md](docs/coa-port/i18n-gaps.md)（不打进发布包，避免把开发文档塞进发布目录）。

## CoA 适配：哪些能用，哪些降级

3.3.5a 的客户端 API 比现代零售客户端少很多能力，插件对这些缺口做了三档处理
（真实现 / 空实现 / 关功能）。重要的可见差异如下：

| 能力 | CoA 客户端上的表现 |
| --- | --- |
| 社交标签页 | 在原生好友窗口 `FriendsFrame` 末尾注入按钮，点击打开手账（3.3.5 没有 `SocialUIFrame`） |
| 设置页 | 挂到 `InterfaceOptionsFrame`（3.3.5 没有新版 `Settings` API） |
| 字体 | 走客户端自带中文字体（ARHei / ARKai 等）；非中文客户端保持原字体 |
| 地图 | 只显示区域名卡片：无世界坐标、无地图美术图层，因而**没有图钉、热区与底图** |
| 路线记录（“你的日记”） | 无世界坐标（`UnitPosition` / `C_Map.GetWorldPosFromMapPos` 都是零售 API），**停留点、两地之间的路线、飞行段无法记录**；升级点、副本行程、战斗标记仍按区域图比例记录。设置里那句说明会直接告诉你这一点，`/sd journey` 统计能看到每次跳过的原因 |
| 图集图标 | 无 `GetAtlasInfo`，图标降级为贴图路径或纯色；副本地图的羽化遮罩关闭 |
| 伤害统计 | 无 `C_DamageMeter`，“千钧一发”捕获不开启（不报错、不出空卡片） |
| 单位右键菜单 | 无 `Menu.ModifyMenu`，“记住这个人”不出现在右键菜单，改走快捷键/宏 |
| 副本识别 | `GetInstanceInfo` 只返回 7 个值（无 instanceID），按地图/区域名匹配 CoA 自建副本表（103 条） |
| 战场/竞技场 | 用 `UPDATE_BATTLEFIELD_STATUS` + `GetBattlefieldWinner` 收尾（`PVP_MATCH_*` 是 Forever 专有事件） |

完整的“客户端有什么/没什么”、逐项测试分类与验证方式见移植工作区根目录的
VERIFY.md、PORT.md 与 DELIVERY.md（不在插件包内，避免把开发文档打进发布包）。

## Questie（可选）

插件本身独立可用。装了 [Questie](https://github.com/Questie) 与 QuestieDB 时，
手账会额外读取它们的数据：生物按真名记录、任务掉落按真实掉率比较（幸运/倒霉
各自成卡），设置里会多出一页“集成”显示是否找到 Questie。

## 隐私

所有数据都保存在你自己的电脑上（`WTF/Account/<账号>/SavedVariables`）。

## 参与

问题与点子请走上游
[Issues](https://github.com/social-diary/social_diary/issues) 或
[Discussions](https://github.com/social-diary/social_diary/discussions)；本移植
版的具体改动见 [docs/](docs/) 与 [CHANGELOG.md](CHANGELOG.md)。

## 致谢

- **Neuton Italic** 字体：Copyright 2010 The Neuton Project Authors，SIL Open
  Font License 1.1，原样随 `Fonts/` 分发（许可证见 `Fonts/OFL.txt`）。
- **Goodmountain** 字体 by Hermann S Designs
  ([github.com/Hermann-S-Designs/Goodmountain](https://github.com/Hermann-S-Designs/Goodmountain))：
  著作权归 Hermann S Designs，按其最终用户许可分发，原样、未改名随 `Fonts/`
  分发（许可证见 `Fonts/Goodmountain-LICENSE.txt`）。
- **Questie 与 QuestieDB** ([github.com/Questie](https://github.com/Questie))：
  可选的集成在游戏运行时读取其数据。
- **Dungeon Crawler Forever** by Per
  ([github.com/perweum/dungeon-crawler-forever](https://github.com/perweum/dungeon-crawler-forever))：
  随 `Vendor/` 原样分发，只由 `Core/Dungeons.lua` 读取，移植不改其源码。

## 许可

见 [LICENSE](LICENSE) 与 `Vendor/` 内各组件的许可证。
