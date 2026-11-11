extends GxControllerNode
## 表现层接法的最小示例：读状态 / bind / register_event / send_command|query 四件事。
## 拿到 Model 后技术上能直接 set_value()，但 debug 写守卫会报告这种越权写入；
## 状态变更只走 send_command()，流程转换归 GameFlow。规则见 agent.md 4.7 / 4.8。

const SCORE_PER_PRESS := 10

@onready var _score_label: Label = $ScoreLabel


func _on_controller_ready() -> void:
	var player := get_model(PlayerModel) as PlayerModel
	if player == null:
		return
	# bind 会立刻用当前值回调一次，所以读档后的分数不会漏显示。
	bind(player.score, _on_score_changed)
	register_event(GameResetEvent, _on_game_reset)
	register_event(GameLoadedEvent, _on_game_loaded)
	print("[Main] ready — SPACE/ENTER 加分, ESC 重置, L 读档, 分数达标自动进入 play 阶段")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		send_command(AddScoreCommand.new(SCORE_PER_PRESS))
	elif event.is_action_pressed(&"ui_cancel"):
		send_command(ResetGameCommand.new())
	elif event is InputEventKey:
		# 运行期读档入口：用来演示 GameLoadedEvent 触发后的界面重建。
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_L:
			send_command(LoadGameCommand.new())


func _on_score_changed(value: int) -> void:
	_score_label.text = "score=%d" % value
	var summary: Dictionary = send_query(ScoreSummaryQuery.new())
	print("[Main] score=%d coins=%d convertible=%d" % [
		value,
		int(summary.get("coins", 0)),
		int(summary.get("convertible_coins", 0)),
	])


func _on_game_reset(_event: GameResetEvent) -> void:
	print("[Main] game reset")


func _on_game_loaded(event: GameLoadedEvent) -> void:
	var player := get_model(PlayerModel) as PlayerModel
	if player == null:
		return
	# apply_save_data() 是静默写入，重播一次让已 bind 的视图重建（契约见 agent.md 4.4）。
	player.notify_all()
	print("[Main] save slot %d loaded" % event.slot)
