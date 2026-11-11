class_name GameArchitecture
extends GxArchitecture
## 本项目的架构实例。整个游戏只有一个。
##
## 故意不做成 autoload：如果 Architecture 全局可达，任何节点都能直接
## get_model() 改状态，分层规则当场失效。表现层只能通过 GxControllerNode
## 或 GxController 接触它。
##
## 新增 Model / System / Utility 就在 _on_register() 里加一行。注册顺序随意，
## initialize() 会按 Utility → Model → System 初始化。

static var _instance: GameArchitecture


## 唯一入口。第一次调用时完成注册、初始化，并登记为表现层的默认架构。
static func get_instance() -> GameArchitecture:
	if _instance == null:
		_instance = GameArchitecture.new()
		_instance.initialize()
		GxArchitecture.set_default(_instance)
	return _instance


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
