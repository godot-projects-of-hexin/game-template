class_name AddScoreCommand
extends GxCommand
## 意图：加分。
##
## Command 必须无状态 —— 参数进去，什么都不带出来。需要返回值就改用 Query。

var _amount: int


func _init(amount: int) -> void:
	_amount = amount


func _on_execute() -> void:
	if _amount == 0:
		return
	var player := get_model(PlayerModel) as PlayerModel
	if player == null:
		return
	player.add_score(_amount)
	send_event(ScoreChangedEvent.create(int(player.score.get_value())))
