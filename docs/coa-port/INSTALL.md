# Social Diary CoA 版：安装 / 验证 / 回滚

## 安装

1. 确认游戏没在运行。
2. 把 **整个** `D:\DSH-source\social_diary_coa\social_diary\` 目录复制到
   `D:\Game\CoA-live-64\Interface\AddOns\social_diary\`
   （目标路径的最后一级必须正好是 `social_diary`，与 `.toc` 同名，否则客户端不认）。
3. 启动游戏 → 角色选择界面左下"插件"按钮 → 确认 "Social Diary" 出现在列表里且没有报错标记。
   如果显示"过期"，说明 TOC 里的 `## Interface:` 值与客户端不符（`python tools/coa_pack.py --info` 会打印本插件与客户端里已安装插件的 Interface 取值）。
4. 进游戏后 `/sd` 或 `/socialdiary` 打开；`/sd help` 看命令。
5. 首次进去请打开设置页确认语言是 **简体中文**（默认值已改成 zhCN）。

## 用脚本安装（推荐）

仓库根目录的 `tools/coa_pack.py` 按插件的 `.pkgmeta` 排除规则生成发布目录
（不带 `tests/`、`Dev/`、`.claude/`、`.github/`），并在复制 TOC 时截断
`#@do-not-package@` 之后的行：

```powershell
python tools/coa_pack.py --info              # 只对照 Interface 号
python tools/coa_pack.py                     # 打包到 dist/social_diary
python tools/coa_pack.py --install           # 打包并复制进客户端 Interface/AddOns
python tools/coa_pack.py --client "D:\Game\CoA-live-64" --out "D:\tmp\sd"
```

手动复制整个 `social_diary\` 目录也可以，但会把 `tests/` 与 `Dev/` 一起带进游戏
（它们不加载，只是多占空间；`Dev/` 会注册额外的 `/sd` 子命令）。

## 首次运行要看的 5 件事（回归清单）

1. 打开主窗口不报 Lua 错误（`/console scriptErrors 1` 先打开；聊天框若出现红字错误，把错误原文记下来）。
2. 走动 / 换区域 / 进副本，日记里出现带**中文区域名**的新条目。
3. 打开"旅程/地图"视图，地图不崩（3.3.5 没有 C_Map，这里是降级路径）。
4. 打开"副本"视图，CoA 的副本列表里有内容。
5. 设置页能打开、能保存、重登后设置还在。

## 回滚

- 直接删掉 `Interface\AddOns\social_diary` 目录即可（不改动客户端任何文件）。
- 存档在 `WTF\Account\<账号>\SavedVariables\social_diary.lua`（角色级在 `WTF\Account\<账号>\<服务器>\<角色>\SavedVariables\social_diary.lua`）。
  想回到干净状态：退出游戏后删掉这两个文件。
- 本项目**没有**改动 `MPQ`、`FrameXML`、`Fonts`，也没有改动服务端，所以回滚不影响其它任何东西。

## 这台机器上的参考路径

- 客户端：`D:\Game\CoA-live-64\`（`CoA64.exe`，`Interface\AddOns\` 里已有 DragonUI 等插件）
- 解出的客户端 FrameXML（只读参考，不是插件的一部分）：
  `D:\DSH-source\social_diary_coa\_ui-port-scratch\out\Interface\FrameXML\`
- 上游原始插件（只读）：`D:\DSH-source\social_diary\`
