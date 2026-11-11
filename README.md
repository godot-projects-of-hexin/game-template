# game-template（Godot 4.4+）

可以直接克隆开工的 Godot 骨架。**架构已搭好、基础设施已接好、玩法留空。**

> **开工先读 [`ARCHITECTURE.md`](ARCHITECTURE.md)** —— 架构组织、需求落点决策表、红线清单、
> 开发流程都在那一份，人和 AI 都一样。本文只讲：怎么跑起来、里面有什么、怎么往下加东西。
> 规则正文在 [`agent.md`](agent.md)（项目层）与
> [`addons/gd-common/agent.md`](addons/gd-common/agent.md)（通用层）。

---

## 快速开始

```bash
git clone https://github.com/godot-projects-of-hexin/game-template.git my-game
cd my-game
git submodule update --init --recursive
```

用 **Godot 4.4 或更高版本** 打开（4.4 / 4.5 / 4.6 / 4.7 均可打开），
确认 **项目设置 → 插件 → gd-common** 已启用，然后 F5 运行。
`project.godot` 里的 `config/features` 是 `4.4`，那是项目格式下限，不是锁定 4.4；
版本规则见 `agent.md` 的「版本基线」。

控制台会打印：

```text
[Main] score=0 coins=0 convertible=0
[Main] ready — SPACE/ENTER 加分, ESC 重置, L 读档, 分数达标自动进入 play 阶段
```

按空格加分，`ScoreLabel` 由 `bind()` 驱动，能直观看到状态镜像；按 `L` 读档会演示
`GameLoadedEvent` 触发后的界面重建。这条链路把架构每一层都走了一遍，是
**可运行的参照实现**。

这里有两个彼此独立的 100：`GameFlow.PLAY_UNLOCK_SCORE` 决定何时从 title 进入 play
（只判一次），`ScoreSystem.AUTOSAVE_SCORE_STEP` 决定每累积多少分自动存档（逐档触发）。
改任一常量都不影响另一个。

---

## 目录

```text
addons/gd-common/           通用层（submodule）
core/
├── game_architecture.gd    GameArchitecture —— 注册中心，唯一实例
├── game_flow.gd            [autoload GameFlow] 流程状态机 + 换场景
├── models/
│   └── player_model.gd     PlayerModel        状态
├── systems/
│   └── score_system.gd     ScoreSystem        计分与自动存档规则
├── commands/
│   ├── add_score_command.gd
│   ├── reset_game_command.gd
│   ├── save_game_command.gd
│   └── load_game_command.gd
├── queries/
│   ├── can_afford_query.gd
│   └── score_summary_query.gd
├── events/
│   ├── score_changed_event.gd
│   ├── game_reset_event.gd
│   └── game_loaded_event.gd
├── utilities/
│   └── save_utility.gd     SaveUtility        包 SaveSystem autoload
└── data/                   CSV、数据表
scenes/
├── main.tscn + main.gd     入口场景与控制器
├── levels/level_01.tscn    play 阶段占位
├── actors/ ui/ fx/
assets/                     美术、音频、字体
tests/                      项目层回归测试 + run_all.sh
scripts/verify.sh           提交前门禁（跑完三条通过标准）
```

---

## autoload

| 名字 | 来源 | 作用 |
|---|---|---|
| `EventBus` | gd-common | 跨 autoload 的轻量通知（字符串键，业务状态不用） |
| `SaveSystem` | gd-common | 存档读写机制 |
| `AudioManager` | gd-common | SFX / BGM / 环境音 |
| `UIManager` | gd-common | Control 模态面板栈 |
| `GameFlow` | 本项目 | 流程状态机与换场景 |

前四个由 gd-common 插件自动注册。**不要新增第六个** —— 门槛见 `agent.md` 第 4.2 节。
业务状态变化走类型化架构 Event（事件类作键），别用 `EventBus` 传；
两套机制的边界见 `agent.md` 第 4.6 节。

`GameArchitecture` 故意不是 autoload：全局可达的架构会让分层规则失效。

---

## 架构一眼看懂

```text
输入 → scenes/main.gd ──── send_command ────▶ AddScoreCommand
      （GxControllerNode）                          │
            ▲                                       ▼
            │                                  PlayerModel.add_score()
            │                                       │
            │                                  ScoreChangedEvent
            │                                       │
            │                        ┌──────────────┴──────────────┐
            │                        ▼                             ▼
            └── BindableProperty ── ScoreSystem              其他订阅者
                （bind 立刻拿到值）   （满 100 分自动存档）
                                          │
                                          ▼
                                    SaveUtility → SaveSystem
```

表现层只做四件事：`get_model / get_system`、`bind`、`register_event`、`send_command / send_query`。
GDScript 没有 private，拿到 Model 后技术上仍能直接 `set_value()` —— 这是**不该做**而非
**做不到**：debug 写守卫会报告越权写入。流程转换同样归 `GameFlow`，不进场景脚本。
两处护栏与流程规则分别见 `agent.md` 4.7 / 4.8。

---

## 加一个新功能

以背包为例，从下往上：

| 步骤 | 文件 | 基类 |
|---|---|---|
| 1 | `core/models/inventory_model.gd` | `GxModel` |
| 2 | `core/systems/inventory_system.gd` | `GxSystem` |
| 3 | `core/events/item_added_event.gd` | `GxEvent` |
| 4 | `core/commands/add_item_command.gd` | `GxCommand` |
| 5 | `core/queries/has_item_query.gd` | `GxQuery` |
| 6 | 在 `GameArchitecture._on_register()` 注册 Model 和 System | — |
| 7 | `scenes/ui/inventory_panel.gd` | `GxControllerNode` |

第 6 步最容易漏，漏了 `get_model()` 会报错返回 `null`。

照着现成示例改最快：

| 想看什么 | 看哪个文件 |
|---|---|
| 架构注册 | `core/game_architecture.gd` |
| Model | `core/models/player_model.gd` |
| System 订阅事件 | `core/systems/score_system.gd` |
| Command | `core/commands/add_score_command.gd` |
| Query 跨 Model + System | `core/queries/score_summary_query.gd` |
| Utility 包 autoload | `core/utilities/save_utility.gd` |
| 表现层接法 | `scenes/main.gd` |
| 流程状态机 | `core/game_flow.gd` |

正式开工前把这些示例删掉或改掉，别把 `PlayerModel.score` 留在项目里当遗迹。

---

## 验证

```bash
bash scripts/verify.sh                           # 一条命令跑完三条通过标准
```

门禁自动执行 `--import` → `--quit`（0 ERROR / 0 泄漏）→ 磁盘上所有 `test_*.gd` 套件
（每个都要打印 `all passed`，项目层套件另需 0 泄漏），最后打印 `GATE: PASSED`。
新增测试会自动纳入，无需改脚本。
CI 在 main 分支 push / PR / 手动触发时跑同一脚本，见 `.github/workflows/verify.yml`。

脚本是 bash，Windows PowerShell 下用 Git Bash 执行，并设置 `GODOT`：

```powershell
$env:GODOT = 'D:\path\to\Godot_v4.7-stable_win64_console.exe'   # console 版才能捕获输出
& 'C:\Program Files\Git\bin\bash.exe' scripts/verify.sh
```

要单独跑某一层时仍可用：

```bash
godot --headless --path . --import               # 全新 clone 必须先跑这步
bash addons/gd-common/tests/run_all.sh           # 共享库 12 个套件
bash tests/run_all.sh                            # 项目层 1 个套件
```

第一步不能省：全新 clone 没有 `.godot/` 全局类缓存，否则报
`Could not find base class "GxControllerNode"`。

当前实现已在 **Godot 4.7 stable** 实跑通过：启动 0 错误 0 泄漏、
13/13 套件，项目层 0 泄漏 0 告警，且无写守卫误报。
4.4 / 4.5 / 4.6 的矩阵复测尚未重跑。Linux / macOS 下 Godot 不在 `PATH` 时用
`GODOT=/path/to/godot bash scripts/verify.sh`。

---

## 更新共享库

```bash
git -C addons/gd-common pull origin main
git add addons/gd-common
git commit -m "chore: bump gd-common"
godot --headless --path . --quit
```

submodule 指针是一次提交。忘记 `git add addons/gd-common`，别人 clone 到的还是旧版本。
