# agent.md — game-template 项目约定

> **通用规则在 [`addons/gd-common/agent.md`](addons/gd-common/agent.md)** —— Godot 官方规范、分层权限表、
> 命名、通信方式选择、提交流程，全部在那一份里，**先读它**。
> 本文只写「项目层」额外的约定：代码放哪、怎么加新功能、哪些东西不准往共享库里塞。

---

## 1. 这个仓库是什么

一个可以直接克隆开工的 Godot **4.4+** 骨架：架构已经搭好，基础设施已经接好，玩法留空。

```bash
git clone https://github.com/godot-projects-of-hexin/game-template.git my-game
cd my-game
git submodule update --init --recursive
```

用 Godot 打开，确认 **项目设置 → 插件 → gd-common** 已启用，然后运行。

开新项目要改的：`project.godot` 的 `config/name`、`icon.svg`、`core/` 里的 Model 和 System、`scenes/`。

---

## 2. 目录与放置决策

```text
addons/gd-common/       通用层（submodule）—— 不要在这里写玩法
core/                   本项目的业务架构
├── game_architecture.gd    GameArchitecture，唯一实例
├── game_flow.gd            [autoload GameFlow] 顶层流程与换场景
├── models/                 状态
├── systems/                跨场景的业务规则
├── commands/               写入意图
├── queries/                只读问题
├── events/                 已发生的事实
├── utilities/              基础设施封装
└── data/                   CSV、数据表
scenes/                 场景与随场景的脚本
├── main.tscn / main.gd     入口
├── levels/ actors/ ui/ fx/
assets/                 美术、音频、字体
```

新写一段代码时，按这个顺序问：

```text
它是状态吗？                        → core/models/
它是跨场景共享的规则吗？            → core/systems/
它要改状态吗？                      → core/commands/
它只是要一个答案吗？                → core/queries/
它描述一件已经发生的事吗？          → core/events/
它在包文件 / 网络 / 平台 SDK 吗？   → core/utilities/
它是节点的表现逻辑吗？              → 和场景放一起，继承 GxControllerNode
它换下个题材的游戏还成立吗？        → 考虑上移 gd-common（看三次法则）
```

**场景脚本和场景文件放同一个目录**（`scenes/main.tscn` + `scenes/main.gd`），这是 Godot 官方推荐的「资源尽量贴近使用它的场景」。

---

## 3. 加一个新功能的标准动作

以「加一个背包」为例，按层从下往上写：

```text
1. core/models/inventory_model.gd      背包里有什么            GxModel
2. core/systems/inventory_system.gb    容量、堆叠、能否拾取    GxSystem
3. core/events/item_added_event.gd     物品已加入              GxEvent
4. core/commands/add_item_command.gd   意图：加入物品          GxCommand
5. core/queries/has_item_query.gd      只读：有没有这个物品    GxQuery
6. 在 GameArchitecture._on_register() 里注册 Model 和 System
7. scenes/ui/inventory_panel.gd        界面                    GxControllerNode
```

第 6 步最容易漏。没注册的 Model，`get_model()` 会 `push_error` 返回 `null`。

写表现层时只能用这四件事：

```gdscript
get_model / get_system      读状态
bind                        镜像 BindableProperty
register_event              响应事实
send_command / send_query   声明意图、提问
```

想在表现层里直接 `player.score.set_value(...)` —— 不行，发 Command。

---

## 4. 项目层专属约定

### 4.1 架构不是 autoload

`GameArchitecture` 通过静态方法拿：

```gdscript
GameArchitecture.get_instance()
```

**但表现层不许直接调它。** 继承 `GxControllerNode` 或持有 `GxController`，它们会自己解析默认架构。
直接拿 architecture 等于绕过分层，代码 review 不过。

唯一例外是 `core/game_flow.gd`：它覆写 `_resolve_architecture()` 来钉住架构的创建时机。
autoload 先于主场景加载，所以等主场景的控制器解析默认架构时，它已经就绪。

`GameFlow` 还负责**退出时释放架构**：

```gdscript
func _exit_tree() -> void:
	_machine = null
	GameArchitecture.reset_instance()
```

`GameArchitecture._instance` 是 `static var`，不会随场景树消失。少了这段，
引擎退出检查会报 `ObjectDB instances were leaked at exit`。

### 4.2 autoload 只允许这五个

```text
EventBus / SaveSystem / AudioManager / UIManager    来自 gd-common
GameFlow                                            本项目唯一的流程控制器
```

**不要新增第六个。** 想加之前先看 `addons/gd-common/agent.md` 第 2.7 节的门槛：
能用 Model / System 解决的，就不该做成 autoload。再加 `XxxManager` autoload 会把架构重新退化成全局单例堆。

### 4.3 存档字段就是契约

`PlayerModel.to_save_data()` 里的 key 直接写进玩家磁盘上的存档文件。

- 改名、删字段 → 破坏旧存档。
- 加字段 → 必须在 `SaveUtility._migrate()` 里补默认值，并把 `SaveSystem.set_version()` 加一。
- 读取一律 `data.get(key, 默认值)`，不要用 `data[key]`。

### 4.4 读档后要发事件

Model 恢复存档用 `set_value_silent()`，不会触发逐属性通知。
所以 `LoadGameCommand` 结束时必须发 `GameLoadedEvent`，表现层靠它统一重建界面。
新增读档路径时别忘了这一步，否则界面会停在旧值上。

### 4.5 音频资源归项目

`AudioManager` 只收 `AudioStream` 对象，不收路径。项目要自己维护映射：

```gdscript
# 建议放 core/utilities/audio_library.gd
const SFX := {
	&"ui_click": "res://assets/audio/sfx/ui_click.wav",
}
```

不要在 `gd-common` 里写死任何 `res://assets/...`。

---

## 5. 不准往 gd-common 里塞的东西

| 禁止 | 为什么 |
|---|---|
| 本项目的 Model / System / Command | 它们带题材假设，下个游戏用不上 |
| 具体关卡、角色、技能逻辑 | 同上 |
| 任何 `res://assets/...` 路径 | 共享层不该知道项目目录结构 |
| 对 `GameFlow`、`GameArchitecture` 的依赖 | 共享层不能假设项目 autoload 存在 |
| 第三方插件代码 | 要用就放本项目 `addons/third_party/`，保留 LICENSE |

上移的门槛是**三次法则**：至少在 2~3 处复用、形态稳定、确认跨题材通用。只用过一次的留在项目里。

---

## 6. 验证与提交

### 提交前必须跑

```bash
godot --headless --path . --import                    # 全新 clone 必须先跑这步
godot --headless --path . --quit                      # 项目能起、无错误、无泄漏
./addons/gd-common/tests/run_all.sh                   # 共享库全部测试
```

第一步不能省：全新 clone 没有 `.godot/` 全局类缓存，直接跑第二步会报
`Could not find base class "GxControllerNode"`。

通过标准三条：

| 检查项 | 通过标准 |
|---|---|
| 解析与运行 | `--quit` 这一步 0 个 `ERROR`、0 个 `SCRIPT ERROR` |
| 内存 | `--quit` 这一步没有 `ObjectDB instances were leaked at exit` |
| 测试 | `RESULT: all 8 suites passed` |

测试输出里的 `ERROR:` 行和 `test_audio_manager` 的泄漏警告是已知且正常的，
原因见 `addons/gd-common/agent.md` 第 7.1 节。

> Godot 不在 `PATH` 时：`GODOT=/path/to/godot ./addons/gd-common/tests/run_all.sh`

### 版本基线

**支持 Godot 4.4 及更高版本；不是只能用 4.4。**

`project.godot` 里的 `config/features=PackedStringArray("4.4")` 是**项目格式下限**，
不是「必须用 4.4 打开」。已实测 4.5 / 4.6 / 4.7 打开都不会改写这一行。
代码里最老的语法门槛是 `static var`（4.1 引入），没有使用任何 4.5+ 才有的 API。

| 引擎版本 | 实测结果 |
|---|---|
| 4.4.stable | ✅ 启动 0 错误，8/8 套件通过 |
| 4.5.stable | ✅ 启动 0 错误，8/8 套件通过 |
| 4.6.stable | ✅ 启动 0 错误，8/8 套件通过 |
| 4.7.stable | ✅ 启动 0 错误 0 泄漏，8/8 套件通过 |
| 4.3 及以下 | ❌ 不支持：`features` 声明 4.4，且 `.gd.uid` 是 4.4 才引入 |
| 4.8+ | 未验证；`features=4.4` 本身不会阻止打开 |

项目层两条硬规则：

1. **不要手动升级 `config/features`。** 一旦被改成 `4.7`，4.4 就打不开了。
   高版本编辑器若提示「升级项目格式」，选否，或提交前还原这一行。
2. **团队尽量统一小版本。** 混用版本时 `icon.svg.import` 会来回变脏：
   4.7 会多写 `compress/uastc_level`、`process/channel_remap/*` 等默认参数，
   4.4 打开又会删掉。只涉及这一个 `.import` 文件、没有别的改动时，直接还原。

首次 `--import` 打印的 4 行 `gd-common: autoload '...' already exists` 警告，
是插件保留项目自定义 autoload 的正常行为，不是错误。

共享库自身的版本约束与代码门槛见
[`addons/gd-common/agent.md`](addons/gd-common/agent.md) 第 7.0 节。

### 更新共享库

```bash
git -C addons/gd-common pull origin main
git add addons/gd-common
git commit -m "chore: bump gd-common"
godot --headless --path . --quit
```

submodule 指针是**一次提交**。忘记 `git add addons/gd-common`，别人 clone 下来还是旧版本。

### 提交信息

```text
feat: 新能力      fix: 修 bug       refactor: 重构
docs: 文档        test: 测试        chore: 依赖 / submodule 指针
```

---

## 7. 现成示例的位置

骨架里的示例代码是**可运行的参照**，照着改就行：

| 想看什么 | 看哪个文件 |
|---|---|
| 架构怎么注册 | `core/game_architecture.gd` |
| Model 怎么写 | `core/models/player_model.gd` |
| System 怎么订阅事件 | `core/systems/score_system.gd` |
| Command 怎么写 | `core/commands/add_score_command.gd` |
| Query 怎么跨 Model + System | `core/queries/score_summary_query.gd` |
| Utility 怎么包 autoload | `core/utilities/save_utility.gd` |
| 事件怎么定义 | `core/events/score_changed_event.gd` |
| 表现层怎么接 | `scenes/main.gd` |
| 流程状态机怎么用 | `core/game_flow.gd` |

真正开工前把这些示例删掉或改掉，不要把 `PlayerModel.score` 留在正式项目里当遗迹。

---

## 8. 改本文的规则

- 项目层新约定 → 写进本文。
- 通用层新约定 → 写进 `addons/gd-common/agent.md`，**不要**在本文复制一份。
- 本文与代码不一致 → 以代码为事实，立刻修本文。
