# game-template（Godot 4.4）

可以直接克隆开工的 Godot 骨架。**架构已搭好、基础设施已接好、玩法留空。**

> **规则看 [`agent.md`](agent.md)**（项目层）和 [`addons/gd-common/agent.md`](addons/gd-common/agent.md)（通用层）。
> 本文只讲：怎么跑起来、里面有什么、怎么往下加东西。

---

## 快速开始

```bash
git clone https://github.com/godot-projects-of-hexin/game-template.git my-game
cd my-game
git submodule update --init --recursive
```

用 Godot 4.4 打开，确认 **项目设置 → 插件 → gd-common** 已启用，然后 F5 运行。

控制台会打印：

```text
[Main] ready — SPACE/ENTER 加分, ESC 重置, 到 100 分自动进入 play 阶段
```

按空格加分，到 100 分会自动切到 `scenes/levels/level_01.tscn`，并在每满 100 分时自动存档。
这条链路把架构的每一层都走了一遍，是**可运行的参照实现**。

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
```

---

## autoload

| 名字 | 来源 | 作用 |
|---|---|---|
| `EventBus` | gd-common | 基础设施广播（字符串键） |
| `SaveSystem` | gd-common | 存档读写机制 |
| `AudioManager` | gd-common | SFX / BGM / 环境音 |
| `UIManager` | gd-common | Control 模态面板栈 |
| `GameFlow` | 本项目 | 流程状态机与换场景 |

前四个由 gd-common 插件自动注册。**不要新增第六个** —— 门槛见 `agent.md` 第 4.2 节。

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

表现层能做的只有四件事：`get_model / get_system`、`bind`、`register_event`、`send_command / send_query`。
**它没有直接改状态的接口** —— 这是基类的 API 决定的，不是靠自觉。

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
godot --headless --path . --import               # 全新 clone 必须先跑这步
godot --headless --path . --quit                 # 项目能起、无错误、无泄漏
./addons/gd-common/tests/run_all.sh              # 共享库全部测试
```

第一步不能省：全新 clone 没有 `.godot/` 全局类缓存，直接跑第二步会报
`Could not find base class "GxControllerNode"`。

通过标准三条：0 个 `ERROR`、没有 `ObjectDB instances were leaked at exit`、
结尾打印 `RESULT: all 8 suites passed`。

已在 **Godot 4.7.stable** 上验证通过。Godot 不在 `PATH` 时用
`GODOT=/path/to/godot ./addons/gd-common/tests/run_all.sh`。

---

## 更新共享库

```bash
git -C addons/gd-common pull origin main
git add addons/gd-common
git commit -m "chore: bump gd-common"
godot --headless --path . --quit
```

submodule 指针是一次提交。忘记 `git add addons/gd-common`，别人 clone 到的还是旧版本。
