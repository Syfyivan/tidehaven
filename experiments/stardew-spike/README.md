# Tidehaven：星露谷 Mod 技术样板

2026-10-30。这个独立试验用于评估“原生俯视甲板＋自定义横版潜水＋双人自由分工”的实现成本。它不代表已经决定迁移，仓库根目录的 Godot 0.18 游戏入口保持原样。

## 运行范围

目标版本为 Windows《星露谷物语》1.6.15、SMAPI 4.2.1。当前实现面向原生 LAN 联机的两个独立游戏进程；不支持同一进程中的本地分屏。两端都需加载这个 Mod。

甲板使用原生 GameLocation、人物与箱子；主机裁决扩建、航行和水下状态，SMAPI 消息传递自定义输入与状态。玩家可以一人留在甲板、一人下潜，也可以交换角色。

这里只是技术样板：水下只有一个矿点；航行目前改变海上坐标和背景，没有完整海图或岛间航行。甲板环境、水下环境和威胁形状采用临时程序绘制。原生陆地人物尚未替换为架空近代中国海港人物。

## 手动试玩

本机已备好运行目录，可双击[启动主机试验.cmd](启动主机试验.cmd)和[启动客机试验.cmd](启动客机试验.cmd)。实测范围和缺口见[样板报告](../../docs/implementation-stardew-spike.md)。库存按主机预约、持有者本地执行、回执提交处理；不能直接在主机修改远端背包。

使用全新的独立 session 名称，例如 `manual-host`、`manual-guest`。手动 session 不要放 `probe.json` 或 `command.json`；`host-a`、`guest-a` 是受控试验目录，包含自动操作配置，不作为用户试玩入口。

如果隔离 runtime 和 Mod 已经准备好，在 PowerShell 中运行：

```powershell
Set-Location 'C:\Users\s_f15\Projects\Personal\tidehaven'
.\experiments\stardew-spike\tools\launch.ps1 -Session manual-host
.\experiments\stardew-spike\tools\launch.ps1 -Session manual-guest
```

主机窗口通过原生“合作模式 → 主持”新建农场，并保留至少一间小屋。客机窗口通过原生合作模式输入 LAN 地址 `127.0.0.1`，选择可用农夫。后续继续同一试验时，主机从合作模式主持已有试验存档，客机再加入。两个窗口分别使用自己的 session，不能同时共用一个 session。

同机操作时，按需在游戏设置中关闭失焦暂停，让另一个窗口继续更新。原生菜单、人物创建、背包、箱子和过夜流程仍按原作操作。

| 场景 | 操作 |
| --- | --- |
| 原生农场／甲板 | `F8` 上船，`F9` 回农场 |
| 甲板 | `WASD` 走动，方向键操船，`K` 切换锚 |
| 甲板 | 鼠标指向相邻可扩建格，按 `R` 扩建；每格消耗 5 木材 |
| 甲板箱子 | 在原生背包中选中箱子后放置，右键打开；用原生箱子菜单存取物品 |
| 甲板 | `J` 下潜 |
| 水下 | `WASD` 游动，靠近矿点按 `E` 采矿，`F` 发射鱼叉，`Esc` 返航 |

首次上船会为该玩家提供试验物资：30 木材和一个原生箱子，需要预留背包空间。这些是样板物资，不是正式游戏平衡。

**保存走原生过夜流程，没有即时保存。** 双方返回农场并按原作睡觉，等待保存完成和新一天开始，再退出。重新使用相同 session 名称，可以在原生合作菜单继续其试验存档。

## 首次准备与构建

准备已安装的正版游戏及 .NET SDK。当前脚本默认游戏路径为 `C:\SteamLibrary\steamapps\common\Stardew Valley`。

先下载并解压 [SMAPI 官方 4.2.1 安装包](https://github.com/Pathoschild/SMAPI/releases/tag/4.2.1)，使 Windows 内包位于：

```text
artifacts/stardew-spike/installer/SMAPI 4.2.1 installer/internal/windows/install.dat
```

然后在仓库根目录运行：

```powershell
.\experiments\stardew-spike\tools\setup-runtime.ps1
.\experiments\stardew-spike\tools\build.ps1
```

`setup-runtime.ps1` 复制运行文件并解开匹配的 SMAPI 内包；它在 runtime 已存在时会停止，避免覆盖既有试验。安装位置不同可传 `-InstalledGame '实际游戏目录'`。`Content` 通过目录联接引用已安装游戏，试验只读复用素材，不能编辑联接中的原作文件。

`build.ps1` 默认先执行纯规则检查，再构建隔离启动器和 Mod，并部署到试验 runtime。`-SkipChecks` 只跳过纯规则检查，不表示游戏行为已经通过验证。重建前先正常退出使用这份 runtime 的试验进程。

## 隔离与源码布局

必须通过 `tools/launch.ps1` 启动这份试验 runtime 中的 `TidehavenBootstrap.exe`。启动器在 SMAPI 启动前，将该进程的游戏数据、存档和日志路径重定向到指定 session；直接运行原作或普通 SMAPI 可执行文件不会自动获得这层隔离。脚本不修改原游戏安装或 Steam 启动设置。

| 路径 | 用途 |
| --- | --- |
| `core/` | 主机管理的世界规则、动作与状态数据 |
| `mod/ModEntry.cs` | 原生地点、输入、绘制、联机消息和存档接入 |
| `mod/ProbeDriver.cs` | 仅供隔离受控试验的自动菜单操作、命令、状态与截图 |
| `bootstrap/` | 进程内路径隔离启动器 |
| `checks/` | 独立规则检查，不替代游戏实测 |
| `tools/setup-runtime.ps1` | 准备独立 runtime |
| `tools/build.ps1` | 规则检查、构建和部署 |
| `tools/launch.ps1` | 创建／复用指定 session 并启动隔离进程 |
| `tools/inspect/` | 开发时核对本机游戏 API 的辅助工具 |

运行产物位于仓库忽略的 `artifacts/stardew-spike/`：

- `runtime/`：试验运行文件与 Mod。
- `sessions/<名称>/appdata/Saves/`：该 session 的原生存档。
- `sessions/<名称>/appdata/ErrorLogs/`：该 session 的 SMAPI 日志。
- `sessions/<名称>/history/`：每次启动保留的日志、状态和构建哈希记录。

原作运行文件、素材和试验存档不随源码分发。泳姿复用仓库的 `assets/characters/swimming/diver-hood.png`，构建时复制为 Mod 的 `assets/diver.png`；生成来源、帧规格与原有验收边界见[泳姿来源记录](../../assets/characters/swimming/SOURCE.md)。这份素材不是原作泳姿，也不代表本 Mod 的角色美术已经完成。

## 验证边界

本说明记录运行方法与实现范围，不代替实测报告。需要分别记录：正常入口、主客交换、竞争动作、氧气救援、原生箱子交互、过夜保存、重新加载、断线重连、同机 LAN、跨电脑联机及真人手感。受控菜单调用或脚本输入不能称为真人试玩，纯规则检查不能证明图形和网络流程。

开发约定：观察到账号额度重置后，立即停止修改和验证，不为收尾继续操作。
