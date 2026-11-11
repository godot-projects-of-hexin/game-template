class_name GameArchitecture
extends GxArchitecture
## 本项目的架构实例，全局唯一但不做成 autoload；表现层只能经
## GxControllerNode / GxController 接触它（原因见 agent.md 4.1）。
## 新增 Model / System / Utility 在 _on_register() 里加一行即可，
## initialize() 会按 Utility → Model → System 初始化。

static var _instance: GameArchitecture
static var _unexpected_access_warnings := 0


## 唯一入口。第一次调用时完成注册、初始化，并登记为表现层的默认架构。
static func get_instance() -> GameArchitecture:
	if OS.is_debug_build() and not Engine.is_editor_hint():
		if not _is_allowed_caller(get_stack()):
			_unexpected_access_warnings += 1
			push_warning(
				"GameArchitecture.get_instance(): resolve the architecture through "
				+ "GxControllerNode / GxController instead of calling this directly."
			)
	if _instance == null:
		_instance = GameArchitecture.new()
		_instance.initialize()
		GxArchitecture.set_default(_instance)
	return _instance


## 纯判定，便于测试锁死：只有架构解析点（覆写 _resolve_architecture）与测试
## 夹具允许直接拿单例。栈信息不可用时放行，宁可漏报也不误报。
static func _is_allowed_caller(stack: Array) -> bool:
	if stack.is_empty():
		return true
	for frame in stack:
		var entry: Dictionary = frame as Dictionary
		var function := String(entry.get("function", ""))
		var source := String(entry.get("source", ""))
		if function == "_resolve_architecture" or function == "_ensure_controller":
			return true
		if source.begins_with("res://tests/"):
			return true
	return false


## 测试可观测：记录到多少次非白名单直接访问。
static func unexpected_access_warnings() -> int:
	return _unexpected_access_warnings


static func reset_access_warnings() -> void:
	_unexpected_access_warnings = 0


## 整局结束或测试之间调用，避免一局的状态泄漏到下一局。
static func reset_instance() -> void:
	if _instance != null:
		_instance.deinitialize()
	_instance = null
	GxArchitecture.clear_default()


func _on_register() -> void:
	register_utility(SaveUtility.new())
	register_model(PlayerModel.new())
	register_system(ScoreSystem.new())
