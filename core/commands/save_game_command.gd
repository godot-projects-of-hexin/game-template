class_name SaveGameCommand
extends GxCommand
## 意图：存档。

var _slot: int


func _init(slot: int = PlayerModel.SAVE_SLOT) -> void:
	_slot = slot


func _on_execute() -> void:
	var player := get_model(PlayerModel) as PlayerModel
	var save_utility := get_utility(SaveUtility) as SaveUtility
	if player == null or save_utility == null:
		return
	if not save_utility.save(_slot, player.to_save_data()):
		push_error("SaveGameCommand: failed to write slot %d" % _slot)
