# agent.md — game-template 项目约定

> **开工第一个读 [`ARCHITECTURE.md`](ARCHITECTURE.md)** —— 架构组织、需求 → 落点决策表、
> 红线清单、标准开发流程、文档地图都在那一份；它同时约束人类开发者与 AI 助手的发散行为。
>
> **通用规则正文在 [`addons/gd-common/agent.md`](addons/gd-common/agent.md)** —— Godot 官方规范、
> 分层权限表、命名、通信方式选择、提交流程，全部在那一份里。
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
2. core/systems/inventory_system.gd    容量、堆叠、能否拾取    GxSystem
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

想在表现层里直接 `player.score.set_value(...)` —— 技术上调得到，但不该做：
状态变更发 Command，debug 写守卫会报告越权写入（见 4.7）。

---

## 4. 项目层专属约定

### 4.1 架构不是 autoload

`GameArchitecture` 通过静态方法拿：

```gdscript
GameArchitecture.get_instance()
```

**但表现层不许直接调它。** 继承 `GxControllerNode` 或持有 `GxController`，它们会自己解析默认架构。
直接拿 architecture 等于绕过分层，代码 review 不过。debug 构建里 `get_instance()` 还会
用 `get_stack()` 检查调用者：不在白名单（`_resolve_architecture`、`_ensure_controller`、
`res://tests/`）就 `push_warning` 并累计到 `unexpected_access_warnings()`。
栈信息不可用时放行，宁可漏报不误报；release 构建完全跳过检查。详见第 4.7 节。

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

### 4.4 读档后要发事件，并统一重建界面

Model 恢复存档用 `set_value_silent()`，不会触发逐属性通知。读档链路有两条硬性约定：

1. `LoadGameCommand` 结束时发 `GameLoadedEvent`；**不要发 `ScoreChangedEvent`** ——
   读档不是「分数变了」，发它会让 `ScoreSystem` 把刚读进来的档立刻自动写回去。
2. 表现层收到 `GameLoadedEvent` 后调用 `PlayerModel.notify_all()`，把所有可绑定状态
   重播一次，让已经 `bind` 的视图重建。参照实现见 `scenes/main.gd` 的
   `_on_game_loaded()`。

`notify_all()` 只重播、不写入，不属于「表现层直接改状态」。
`ScoreSystem` 同时订阅 `GameLoadedEvent`，按恢复出来的分数重新起算自动存档步进，
避免沿用上一局的计数。新增读档路径时别忘了这两步，否则界面会停在旧值上。
`GameFlow` 也订阅 `GameLoadedEvent` 判定阶段，见第 4.8 节。

### 4.5 音频资源归项目

`AudioManager` 只收 `AudioStream` 对象，不收路径。项目要自己维护映射：

```gdscript
# 建议放 core/utilities/audio_library.gd
const SFX := {
	&"ui_click": "res://assets/audio/sfx/ui_click.wav",
}
```

不要在 `gd-common` 里写死任何 `res://assets/...`。

### 4.6 两套事件，别混用

| 机制 | 键 | 项目层用在哪 |
|---|---|---|
| 架构 Event（`GxTypeEventSystem`） | 事件类（Script） | 业务事实：`ScoreChangedEvent`、`GameLoadedEvent` |
| `EventBus` autoload | `StringName` | 跨 autoload 的轻量通知：过场、音频提示、调试开关 |

规则：`Model / System / Command / Query` 里**不准**出现 `EventBus` —— 架构层不该知道
autoload 存在。状态变化一律用事件类，载荷字段写在类里，生产者和消费者对不上时能立刻发现；
`EventBus` 的字符串键与裸 `Variant` 载荷没有这层保护。

判断口诀：**「某个游戏状态变了」→ 架构 Event；「某个全局服务要打个招呼」→ EventBus。**
两种方式都可行时选架构 Event。

### 4.7 护栏不是靠自觉：写守卫与单例白名单

分层规则靠两层 debug 期可观测的护栏兜底：

| 护栏 | 位置 | 抓什么 |
|---|---|---|
| `GxWriteGuard` | `addons/gd-common/architecture/gx_write_guard.gd` | 表现层拿到 Model 后直接 `set_value()` / `set_value_silent()` |
| `get_instance()` 白名单 | `core/game_architecture.gd` | 表现层绕过 `GxControllerNode` 直接取架构单例 |

`GxArchitecture` 在 `initialize()`、各层 `_on_init()`、`send_command()` 的
`_on_execute()`、`send_event()` 的同步 handler 这几处各包一层 `GxWriteGuard.begin()/end()`，
这些区间就是**受控写入上下文**。只有注册进架构的 Model 上的 `GxBindableProperty` 会被
`_mark_model_bindables()` 标记为受守卫，独立创建的 observable（单测、临时值）完全不受影响；
release 构建直接跳过检查。看到 `GxWriteGuard: ... ran outside a sanctioned write scope`
不要去关掉它，先把写入挪进 Command。

测试夹具如果必须直接布置初始状态，自己包一层 `GxWriteGuard.begin()/end()`，
`violation_count()` / `reset_violations()` 就是为此留的。`test_architecture` 里那两条
写守卫 warning 是故意触发的预期输出，不是回归。

注意 `has_method()` 那组断言只锁得住「基类上不存在某个 API」，锁不住「拿到对象后调用
它的 public 方法」—— 这正是两层护栏存在的原因，别把它当重复检查删掉。

### 4.8 流程规则归 GameFlow

「分数达标进 play」是**流程配置**，不是业务规则（分数怎么换算仍归 `ScoreSystem`），
所以放在 `core/game_flow.gd` 里，和 `PHASE_SCENES` 放一起：

- `const PLAY_UNLOCK_SCORE := 100`；
- `static should_enter_play(score, current) -> bool`：纯判定，与状态机/节点解耦，项目层测试直接锁死；
- `_on_controller_ready()` 同时订阅 `ScoreChangedEvent` 与 `GameLoadedEvent`，两条路径都走 `_try_enter_play()`。

读档时直接按 `PlayerModel` 恢复出来的分数判定阶段，不必等下一次加分，所以读档出
250 分也不会停在 title。读档刻意不发 `ScoreChangedEvent`（见第 4.4 节），避免自动写回。

表现层（`scenes/main.gd`）不再持有流程规则，只做界面更新、Query 与输入转发，
**不准**出现 `GameFlow.go(` 或 `current_phase()`；`tests/test_project_core.gd` 有断言盯着。
把规则塞进某个场景脚本，换场景后规则就失效，而且项目层测试覆盖不到。

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
bash scripts/verify.sh                               # 唯一入口：跑完三条通过标准
```

`scripts/verify.sh` 把下面三条标准固化为可执行检查，打印 `GATE: PASSED` 才算通过。
Godot 不在 `PATH` 时用 `GODOT=/path/to/godot bash scripts/verify.sh` 指定引擎；
Windows PowerShell 下的执行方式见 `README.md` 验证章节。CI（`.github/workflows/verify.yml`）
在 main 分支 push / PR / 手动触发时跑同一脚本。

| 检查项 | 通过标准 |
|---|---|
| 类缓存 | `--import` 成功（全新 clone 无这一步会报 `Could not find base class`） |
| 解析与运行 | `--quit` 输出 0 个 `ERROR`、0 个 `SCRIPT ERROR` |
| 内存 | `--quit` 输出没有 `ObjectDB instances were leaked at exit`；项目层套件同样 0 泄漏 |
| 测试 | 磁盘上所有 `test_*.gd` 套件都打印 `all passed`，且无编译/解析错误 |

套件由脚本从磁盘自动发现，**新增测试即自动纳入门禁**，不必改脚本。
要单独跑某一层仍可用 `bash addons/gd-common/tests/run_all.sh` 与
`bash tests/run_all.sh`（Godot 不在 `PATH` 时同样设 `GODOT`）。

测试输出里的 `ERROR:` 行、`test_architecture` 里故意触发的写守卫 warning，
以及 `test_audio_manager` 的泄漏警告都是已知且正常的，门禁脚本已按此放行；
原因见 `addons/gd-common/agent.md` 第 7.1 节与本文第 4.7 节。
这些例外只针对共享库套件，项目层套件不在豁免内，泄漏会被门禁判失败。

### 版本基线

**支持 Godot 4.4 及更高版本；不是只能用 4.4。**

`project.godot` 里的 `config/features=PackedStringArray("4.4")` 是**项目格式下限**，
不是「必须用 4.4 打开」。已实测 4.5 / 4.6 / 4.7 打开都不会改写这一行。
代码里最老的语法门槛是 `static var`（4.1 引入），没有使用任何 4.5+ 才有的 API。

下表在新增测试套件后只有 4.7 已重新实跑，其余版本待矩阵复测。

| 引擎版本 | 实测结果 |
|---|---|
| 4.4.stable | 改动后待复测（改动前：启动 0 错误，8/8 套件通过） |
| 4.5.stable | 改动后待复测（改动前：启动 0 错误，8/8 套件通过） |
| 4.6.stable | 改动后待复测（改动前：启动 0 错误，8/8 套件通过） |
| 4.7.stable | ✅ 本次改动实测：启动 0 错误 0 泄漏，12/12 + 2/2 套件通过 |
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
- 需求落点有变化 → 同步 `ARCHITECTURE.md` 第 1 节决策表（只加索引，不复制正文）。
- 验证标准有变化 → 同步 `scripts/verify.sh`，别只改文档。
- 本文与代码不一致 → 以代码为事实，立刻修本文。
