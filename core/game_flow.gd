extends GxControllerNode
## Autoload: GameFlow —— 顶层流程控制器。
##
## 它是表现层：持有流程状态机、负责换场景、读档。业务规则不写在这里。
##
## 通过覆写 _resolve_architecture() 把架构的创建时机钉在这里。autoload 先于
## 主场景加载，所以等主场景里的控制器开始解析默认架构时，它已经就绪了。

## 流程阶段。新增阶段时在 PHASE_SCENES 里补一条映射。
const PHASE_TITLE := &"title"
const PHASE_PLAY := &"play"

const PHASE_SCENES := {
	&"title": "res://scenes/main.tscn",
	&"play": "res://scenes/levels/level_01.tscn",
}

## 阶段已经切换。表现层想跟随流程时监听这个，不要去读状态机内部。
signal phase_changed(from_phase: StringName, to_phase: StringName)

var _machine: GxStateMachine


func _resolve_architecture() -> GxArchitecture:
	return GameArchitecture.get_instance()


func _on_controller_ready() -> void:
	_machine = GxStateMachine.new(self)
	for phase: StringName in PHASE_SCENES:
		_machine.add_state(phase, GxState.new())
	_machine.state_changed.connect(_on_phase_changed)
	# start() 不触发 state_changed，所以不会在启动时又切一次场景。
	_machine.start(PHASE_TITLE)
	# 槽位为空时该命令自己会静默返回，不需要先查一次。
	send_command(LoadGameCommand.new())


func _exit_tree() -> void:
	# 游戏退出时必须释放静态单例持有的架构，否则引擎在退出检查里会报
	# 「ObjectDB instances were leaked」。GameArchitecture._instance 是
	# static var，不会随场景树一起消失。
	_machine = null
	GameArchitecture.reset_instance()


## 切换到某个阶段。目标等于当前阶段时状态机会告警并忽略。
func go(phase: StringName) -> void:
	if _machine == null:
		push_error("GameFlow.go: flow is not ready yet")
		return
	_machine.transition_to(phase)


func current_phase() -> StringName:
	return _machine.current_name() if _machine != null else &""


func _on_phase_changed(from_phase: StringName, to_phase: StringName) -> void:
	phase_changed.emit(from_phase, to_phase)
	if not PHASE_SCENES.has(to_phase):
		push_error("GameFlow: phase '%s' has no scene mapping" % to_phase)
		return
	# 延迟到帧末再换场景，避免在信号回调里销毁正在发信号的节点。
	get_tree().change_scene_to_file.call_deferred(PHASE_SCENES[to_phase])
