# ARCHITECTURE.md — 架构与开发入口

> **开工前先读这份，人和 AI 都一样。** 它回答三件事：系统怎么组织、我的需求落在哪、什么绝对不能做。
>
> 本文是**索引 + 决策 + 红线**，不复制规则细节。规则的权威正文在下面「文档地图」列出的文件里；
> 如果本文与权威正文冲突，**以权威正文为准，并回来修正本文的索引**。

---

## 0. 三分钟看懂

```text
                    ┌──────────── 表现层（场景脚本）────────────┐
   输入 / UI 事件 ──▶│ GxControllerNode / GxController           │
                    │ 只能：get_model·get_system / bind /         │
                    │       register_event / send_command·query   │
                    └──────┬──────────────────────────┬──────────┘
                           │ send_command              │ send_query
                           ▼                          ▼
                    ┌─────────────┐            ┌─────────────┐
                    │  GxCommand  │            │  GxQuery    │
                    │ 唯一写入路径 │            │ 只读，算答案 │
                    └──────┬──────┘            └─────────────┘
                           │ 改状态 / send_event
          ┌────────────────┼─────────────────┐
          ▼                ▼                 ▼
   ┌───────────┐    ┌────────────┐   ┌──────────────┐
   │ GxModel   │    │ GxSystem   │   │ GxUtility    │
   │ 状态唯一源 │    │ 跨场景规则 │   │ 文件/SDK 封装│
   │ Bindable  │    │ 订阅事件   │   │ 不碰架构成员 │
   └─────┬─────┘    └────────────┘   └──────────────┘
         │ value_changed / 类型化架构 Event
         └──────────────▶ bind 的 UI、订阅的 System 同步收到
```

**三条铁律**（后面所有规则都是它们的展开）：

1. **状态只有一个来源**：`GxModel`；改状态只有一条路径：`send_command()`。
2. **业务状态变化走类型化架构 Event**；`EventBus` 只用于跨 autoload 的轻量通知。
3. **架构不是 autoload**：`GameArchitecture.get_instance()` 是静态单例，表现层只能经
   `GxController` / `GxControllerNode` 接触它。

**关键对象**

| 对象 | 位置 | 职责 |
|---|---|---|
| `GameArchitecture` | `core/game_architecture.gd` | 唯一实例；`_on_register()` 注册本项目 Model / System / Utility |
| `GxArchitecture` | `addons/gd-common/architecture/` | 分层基类、IOC 容器、写入作用域、类型化事件系统 |
| `GameFlow` | `core/game_flow.gd` | 唯一项目 autoload；流程状态机、换场景、阶段判定 |
| 4 个基础设施 autoload | `project.godot` | `EventBus` `SaveSystem` `AudioManager` `UIManager`（来自 gd-common） |
| `GxWriteGuard` | 共享库 | debug 期报告越权写入；只报告、不阻断，release 跳过 |

---

## 1. 需求 → 落点决策表

**先在这张表里找到你的需求类型，再去对应的权威文档看细节。** 找不到时看第 4 节，不要自行发明。

| 你的需求 | 落点 | 基类 / 关键 API | 必须补的验证 |
|---|---|---|---|
| 加一个状态字段（血量、金币、解锁标记） | `core/models/` | `GxModel` + `GxBindableProperty` | 项目层：字段读写 + `to_save_data()` |
| 拆新 Model 还是给现有 Model 加字段 | **规则未覆盖 → 走第 4 节** | — | — |
| 加一条跨场景规则（计分、成就、商店、昼夜） | `core/systems/` | `GxSystem`，订阅事件 | 项目层：规则输入/边界 |
| 玩家操作要改状态（`+分`、购买、拾取） | `core/commands/` | `GxCommand._on_execute()` | 项目层：状态确实变了 |
| 只要一个答案（够不够钱、汇总、排行） | `core/queries/` | `GxQuery`，只读 | 项目层：算得对、无副作用 |
| 状态变了要通知别人 | `core/events/` | `GxEvent` 子类，字段承载载荷 | 项目层：生产者/消费者对得上 |
| 界面跟着状态变 | `scenes/` 同目录脚本 | `GxControllerNode` + `bind()` | 手动 F5 + 项目层断言 |
| 读档后重建界面 | 表现层订阅 `GameLoadedEvent` | `PlayerModel.notify_all()` | 项目层：不漏显示 |
| 改存档字段 | `core/models/` + `SaveUtility._migrate()` | key 是契约，version 加一 | 项目层：旧档能读、默认值生效 |
| 加音效 / BGM | `core/utilities/` 新建映射（骨架未内置） | `AudioManager` 收 `AudioStream`，见 `agent.md` 4.5 | 手动听 |
| 加 UI 面板 / 层级 | `scenes/ui/` | `UIManager.push_panel()` / `set_layer()` | 共享库 `test_ui_manager` |
| 加流程阶段、换场景、改解锁阈值 | `core/game_flow.gd` | `PHASE_SCENES` `PLAY_UNLOCK_SCORE` `should_enter_play()` | 项目层：纯函数 + 读档判定 |
| 跨 autoload 打招呼（过场、调试开关） | `EventBus` | `StringName` 键 | — |
| 包文件、网络、平台 SDK | `core/utilities/` | `GxUtility`，只做自己的事 | 项目层：Fake 替身 |
| 复用对象池 / 数值工具 | 共享库现成组件 | `GxObjectPool` / `GxMath`，见共享库 `README.md` | 共享库已有套件 |
| 通用能力想上移共享库 | 先满足三次法则 | 见 `agent.md` 第 5 节 | 共享库对应套件 |
| 多槽位存档 / 配置表 / 性能预算 | **规则未覆盖 → 走第 4 节** | — | — |
| 两个规则冲突、谁先执行 | **规则未覆盖 → 走第 4 节** | — | — |

**每一步都别忘了注册**：新增 Model / System / Utility 必须在
`GameArchitecture._on_register()` 加一行，否则 `get_model()` 返回 `null`。这是最常漏的一步。

分层权限的完整表（哪层能调什么）在 `addons/gd-common/agent.md` 3.2，
写任何一层之前先确认自己没越权。

---

## 2. 红线：以下行为一律视为错误

这些是**不可协商**的约束。AI 助手不得以「更简洁」「更方便」「先跑通」为由绕过。

| # | 禁止 | 理由 / 检测 |
|---|---|---|
| R1 | 表现层直接 `set_value()` / `set_value_silent()` 改 Model | `GxWriteGuard` debug 期报告；状态变更走 Command |
| R2 | 新增第 6 个 autoload | `agent.md` 4.2；能用 Model / System 解决就不做 autoload |
| R3 | 把玩法逻辑、关卡、角色、资源路径写进 `addons/gd-common/` | 该项目层，共享层不假设项目结构 |
| R4 | 在 `Model / System / Command / Query` 里用 `EventBus` | `agent.md` 4.6；架构层不该知道 autoload |
| R5 | 把流程规则塞进场景脚本（`GameFlow.go()` / `current_phase()`） | `tests/test_project_core.gd` 有文本断言盯着 |
| R6 | 读档时发 `ScoreChangedEvent` | 会触发自动写回，读档只发 `GameLoadedEvent` |
| R7 | 改存档 key 却不补 `_migrate()` 默认值、不把 version 加一 | 破坏旧存档 |
| R8 | 放宽 `test_architecture.gd` 的 `has_method()` 断言表 | 它是分层权限的唯一硬锁 |
| R9 | 为了让测试变绿而关掉写守卫、删断言、放宽门禁脚本 | 门禁是最后一道防线 |
| R10 | 跳过 `--import` 直接跑 `--quit` | 全新 clone 无类缓存，必报 `Could not find base class` |
| R11 | 使用 4.5+ 语法 / 手改 `config/features` | 版本下限 4.4，见 `agent.md` 6 |
| R12 | 给 `GxSystem` 加节点引用、`get_tree()`、`Control` | 碰了它就是表现层 |
| R13 | 给 `GxQuery` 加写状态或发事件 | Query 只读 |
| R14 | 未经第 4 节流程，自行新增层级 / 机制 / 抽象 / 设计模式 | **AI 发散的主要来源** |

**已知护栏边界**（不是许可，是如实说明）：`send_event()` 统一同步派发，System 与表现层回调
共用同一写入作用域，因此表现层在事件回调里写 Model **不会**被写守卫报告；release 构建完全
跳过检查。别把「没收到 warning」当成「这样做没问题」。

---

## 3. 标准开发流程

```text
1. 读本文第 1 节，确定需求落点 ── 找不到 → 走第 4 节，不要开始写代码
2. 读对应权威文档（见第 5 节文档地图）与「加一个新功能」示例（README.md）
3. 按层实现；表现层只用四件事（见本文 0 节）
4. 在第 1 节表格的「必须补的验证」列对应位置补断言
5. 跑门禁：bash scripts/verify.sh（Godot 不在 PATH 时设 GODOT；Windows 见 README 验证章节）
6. CI 会在 main 分支 push / PR / 手动触发时复验同一脚本
```

门禁把通过标准固化为可执行检查：`--import` → `--quit`（0 ERROR / 0 泄漏）→
所有 `test_*.gd` 套件打印 `all passed`（项目层套件另需 0 泄漏）。
**套件从磁盘自动发现**，新增测试自动纳入门禁。

提交前手动跑到全绿，不要把「CI 会跑」当成本地不跑的理由。

---

## 4. 规则没覆盖时怎么办（防发散升级路径）

这是本文最重要的一节。遇到第 1 节表里没有的需求、或表内两条规则冲突时：

1. **停下来，不要自行发挥。** 不新增层级、不新增机制、不引入新抽象、不「临时」破例。
2. 按**最接近**的落点归类，写出你准备怎么做、依据是哪条现有规则。
3. **向项目维护者确认**（或在 PR 描述里明确提出「需要新增一条规则」）。
4. 确认后按顺序落地，缺一不可：
   - 在对应的**权威文档**补规则正文；
   - 回到本文第 1 节补一行决策（本文只加索引，不复制正文）；
   - 补一条能锁死该行为的断言 / 测试；
   - 跑 `bash scripts/verify.sh` 全绿。
5. 只在一个项目里出现过的能力**不要**顺手上移共享库（三次法则：`agent.md` 5）。

> **给 AI 助手**：不确定就问，不要为了让代码「看起来合理」而扩展架构。
> 改测试去迁就实现、重构分层、绕过红线，都比留下一个待确认的问题更糟。

---

## 5. 文档地图（改规则去哪一份）

**只有一份是权威正文，别在四处重复写同一条规则。**

| 文件 | 权威范围 | 什么时候读 |
|---|---|---|
| **`ARCHITECTURE.md`（本文）** | 架构组织、需求落点索引、红线、开发流程 | **每次开工，第一个读** |
| `agent.md` | 项目层约定：目录放置、标准动作、4.1–4.8 专属条款、提交纪律 | 写代码前 |
| `addons/gd-common/agent.md` | 通用规则：Godot 官方规范、分层权限表 3.2、命名、通信方式、三次法则、测试与版本基线 | 写共享库或查权限时 |
| `README.md` | 怎么跑起来、目录树、「加一个新功能」7 步示例、验证命令 | 首次 clone / 找示例时 |
| `addons/gd-common/README.md` | 共享库对外 API 清单（含 `GxWriteGuard`） | 查共享库接口时 |

改规则时：改权威正文 + 更新本文索引 + 补断言 + 跑门禁。
**不要**把同一段说明复制到多份文档里——一处改、其余没跟上是规则漂移的主要来源。

---

## 6. 现状与已知边界

- 验证基线：**Godot 4.7 stable** 实跑通过；4.4 / 4.5 / 4.6 矩阵复测未完成。
- 门禁：`scripts/verify.sh` + `.github/workflows/verify.yml`（main 分支 push / PR / 手动触发）。
- 已知例外（不是回归）：`test_audio_manager` 的 headless dummy 音频驱动泄漏、
  `test_architecture` 故意触发的两条写守卫 warning、测试故意走错误分支产生的 `ERROR:` 行。
- 一致性强度：**强约定 + 弱强制**。护栏只报告不阻断，release 不检查，规则靠本文、
  权威文档与门禁共同约束；不是编译期强制。
