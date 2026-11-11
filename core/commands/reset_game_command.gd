class_name ResetGameCommand
extends GxCommand
## 意图：重开一局。


func _on_execute() -> void:
	var player := get_model(PlayerModel) as PlayerModel
	if player == null:
		return
	player.reset()
	send_event(GameResetEvent.new())
	send_event(ScoreChangedEvent.create(0))
