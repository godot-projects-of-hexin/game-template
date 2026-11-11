extends GxControllerNode
## 入口场景控制器 —— 表现层接法的最小可运行示例。
##
## 这个脚本演示了表现层允许做的全部四件事：
##   1. get_model / get_system  读状态
##   2. bind                     镜像 BindableProperty
##   3. register_event           响应已发生的事实
##   4. send_command / send_query 声明意图、提问
##
## 它做不到的事同样重要：没有办法直接改 Model 状态。想改就得发 Command。

const SCORE_PER_PRESS := 10


func _on_controller_ready() -> void:
	var player := get_model(PlayerModel) as PlayerModel
	if player == null:
		return
	# bind 会立刻用当前值回调一次，所以读档后的分数不会漏显示。
	bind(player.score, _on_score_changed)
	register_event(GameResetEvent, _on_game_reset)
	register_event(GameLoadedEvent, _on_game_loaded)
	print("[Main] ready — SPACE/ENTER 加分, ESC 重置, 到 100 分自动进入 play 阶段")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		send_command(AddScoreCommand.new(SCORE_PER_PRESS))
	elif event.is_action_pressed(&"ui_cancel"):
		send_command(ResetGameCommand.new())


func _on_score_changed(value: int) -> void:
	var summary: Dictionary = send_query(ScoreSummaryQuery.new())
	print("[Main] score=%d coins=%d convertible=%d" % [
		value,
		int(summary.get("coins", 0)),
		int(summary.get("convertible_coins", 0)),
	])
	if value >= 100 and GameFlow.current_phase() == GameFlow.PHASE_TITLE:
		GameFlow.go(GameFlow.PHASE_PLAY)


func _on_game_reset(_event: GameResetEvent) -> void:
	print("[Main] game reset")


func _on_game_loaded(event: GameLoadedEvent) -> void:
	print("[Main] save slot %d loaded" % event.slot)
