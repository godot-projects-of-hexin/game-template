class_name LoadGameCommand
extends GxCommand
## 意图：读档。
##
## Model 恢复时用的是静默写入，所以这里结束后必须发 GameLoadedEvent，
## 否则表现层不知道该重建界面。

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
	send_event(ScoreChangedEvent.create(int(player.score.get_value())))
