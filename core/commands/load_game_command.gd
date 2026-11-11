class_name LoadGameCommand
extends GxCommand
## 意图：读档。恢复用静默写入，结束时发 GameLoadedEvent 让表现层统一重建界面。
## 刻意不发 ScoreChangedEvent —— 那会让 ScoreSystem 把刚读进来的档立刻写回去。
## 契约见 agent.md 4.4。

var _slot: int


func _init(slot: int = PlayerModel.SAVE_SLOT) -> void:
	_slot = slot


func _on_execute() -> void:
	var player := get_model(PlayerModel) as PlayerModel
	var save_utility := get_utility(SaveUtility) as SaveUtility
	if player == null or save_utility == null:
		return
	var data := save_utility.load_slot(_slot)
	if data.is_empty():
		return
	player.apply_save_data(data)
	send_event(GameLoadedEvent.create(_slot))
