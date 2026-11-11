extends SceneTree
## Project-layer regression tests for core/.
## Run: godot --headless --path . --script res://tests/test_project_core.gd
##
## These suites build a bare GxArchitecture instead of calling
## GameArchitecture.get_instance(): the latter registers SaveUtility, whose
## _on_init() touches the SaveSystem autoload. Staying independent of autoload
## wiring is what makes the suites safe to run headless.

class FakeSaveUtility extends SaveUtility:
	var data: Dictionary = {}
	var save_calls := 0

	func _on_init() -> void:
		pass  # 不碰 SaveSystem autoload，让套件可以 headless 运行

	func load_slot(_slot: int) -> Dictionary:
		return data.duplicate()

	func save(_slot: int, _saved: Dictionary) -> bool:
		save_calls += 1
		return true


var _done := false
var _architectures: Array[GxArchitecture] = []


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var failures := 0
	failures += _t_save_data_roundtrip()
	failures += _t_apply_save_data_uses_silent_writes()
	failures += _t_coins_for_score_rule()
	failures += _t_score_summary_query()
	failures += _t_can_afford_query()
	failures += _t_notify_all_replays_restored_state()
	failures += _t_load_game_rebuilds_views_without_autosaving()
	failures += _t_flow_phase_scenes_are_complete()
	failures += _t_flow_unlock_rule_is_a_pure_function()
	failures += _t_loaded_save_score_unlocks_play()
	failures += _t_presentation_holds_no_flow_rules()
	failures += _t_get_instance_caller_whitelist()
	# --script 模式下 autoload GameFlow 仍会实例化并登记静态默认架构；
	# 反初始化所有自建架构以断开事件回调里的 lambda 捕获环，再清空静态引用。
	for architecture in _architectures:
		if is_instance_valid(architecture):
			architecture.deinitialize()
	GameArchitecture.reset_instance()
	GxArchitecture.clear_default()
	if failures > 0:
		print("PROJECT_CORE_TEST: %d failure(s)" % failures)
		quit(1)
	else:
		print("PROJECT_CORE_TEST: all passed")
		quit(0)
	return true


func _fail(label: String) -> int:
	print("  FAIL: %s" % label)
	return 1


func _make_architecture() -> GxArchitecture:
	var architecture := GxArchitecture.new()
	_architectures.append(architecture)
	architecture.initialize()
	architecture.register_model(PlayerModel.new())
	architecture.register_system(ScoreSystem.new())
	return architecture


func _make_architecture_with_fake_save(fake: FakeSaveUtility) -> GxArchitecture:
	var architecture := GxArchitecture.new()
	_architectures.append(architecture)
	architecture.initialize()
	architecture.register_utility(fake)
	architecture.register_model(PlayerModel.new())
	architecture.register_system(ScoreSystem.new())
	return architecture


func _t_save_data_roundtrip() -> int:
	var player := PlayerModel.new()
	player.add_score(120)
	player.add_coins(7)
	var data: Dictionary = player.to_save_data()
	var restored := PlayerModel.new()
	restored.apply_save_data(data)
	if int(restored.score.get_value()) != 120:
		return _fail("score did not survive the save roundtrip")
	if int(restored.coins.get_value()) != 7:
		return _fail("coins did not survive the save roundtrip")
	return 0


func _t_apply_save_data_uses_silent_writes() -> int:
	var player := PlayerModel.new()
	var observed: Array = []
	player.score.bind(func(value: Variant) -> void: observed.append(int(value)))
	player.apply_save_data({"score": 42, "coins": 3})
	if int(player.score.get_value()) != 42:
		return _fail("apply_save_data did not store the restored score")
	if observed != [0]:
		return _fail("apply_save_data must not emit per-property notifications")
	return 0


func _t_coins_for_score_rule() -> int:
	var system := ScoreSystem.new()
	if system.coins_for_score(37) != 3:
		return _fail("coins_for_score(37) should be 3")
	if system.coins_for_score(0) != 0:
		return _fail("coins_for_score(0) should be 0")
	return 0


func _t_score_summary_query() -> int:
	var architecture := _make_architecture()
	var player := architecture.get_model(PlayerModel) as PlayerModel
	# 测试脚手架布置初始状态属于框架内部受控写入，不是表现层越权写入。
	GxWriteGuard.begin()
	player.add_score(125)
	player.add_coins(7)
	GxWriteGuard.end()
	var summary: Dictionary = architecture.send_query(ScoreSummaryQuery.new())
	if int(summary.get("score", -1)) != 125:
		return _fail("summary.score is wrong")
	if int(summary.get("coins", -1)) != 7:
		return _fail("summary.coins is wrong")
	if int(summary.get("convertible_coins", -1)) != 12:
		return _fail("summary.convertible_coins should use the System rule")
	return 0


func _t_can_afford_query() -> int:
	var architecture := _make_architecture()
	var player := architecture.get_model(PlayerModel) as PlayerModel
	GxWriteGuard.begin()
	player.add_coins(7)
	GxWriteGuard.end()
	if not bool(architecture.send_query(CanAffordQuery.new(7))):
		return _fail("CanAffordQuery(7) should be true with 7 coins")
	if bool(architecture.send_query(CanAffordQuery.new(8))):
		return _fail("CanAffordQuery(8) should be false with 7 coins")
	return 0


func _t_notify_all_replays_restored_state() -> int:
	var player := PlayerModel.new()
	var scores: Array = []
	var coins: Array = []
	player.score.bind(func(value: Variant) -> void: scores.append(int(value)))
	player.coins.bind(func(value: Variant) -> void: coins.append(int(value)))
	player.apply_save_data({"score": 250, "coins": 9})
	if scores != [0] or coins != [0]:
		return _fail("apply_save_data should stay silent")
	player.notify_all()
	if scores != [0, 250] or coins != [0, 9]:
		return _fail("notify_all should replay every restored property")
	if int(player.score.get_value()) != 250:
		return _fail("notify_all must not write state")
	return 0


func _t_load_game_rebuilds_views_without_autosaving() -> int:
	var fake := FakeSaveUtility.new()
	fake.data = {"score": 250, "coins": 9}
	var architecture := _make_architecture_with_fake_save(fake)
	var player := architecture.get_model(PlayerModel) as PlayerModel
	var observed: Array = []
	player.score.bind(func(value: Variant) -> void: observed.append(int(value)))
	var score_events: Array = []
	architecture.register_event(ScoreChangedEvent, func(_e: ScoreChangedEvent) -> void:
		score_events.append(true))
	# 模拟表现层收到读档事实后的统一重建。
	architecture.register_event(GameLoadedEvent, func(_e: GameLoadedEvent) -> void:
		player.notify_all())
	architecture.send_command(LoadGameCommand.new(0))
	if int(player.score.get_value()) != 250:
		return _fail("LoadGameCommand did not restore the score")
	if not score_events.is_empty():
		return _fail("LoadGameCommand must not emit ScoreChangedEvent (it would trigger an autosave)")
	if fake.save_calls != 0:
		return _fail("loading a save must not write a save back to disk")
	if observed != [0, 250]:
		return _fail("bound view was not rebuilt after loading, got %s" % str(observed))
	var system := architecture.get_system(ScoreSystem) as ScoreSystem
	if system._last_autosave_step != 2:
		return _fail("autosave step should restart from the loaded score (250 / 100)")
	return 0


func _t_flow_phase_scenes_are_complete() -> int:
	var script: Script = load("res://core/game_flow.gd")
	var constants: Dictionary = script.get_script_constant_map()
	var scenes: Dictionary = constants.get("PHASE_SCENES", {})
	if scenes.is_empty():
		return _fail("GameFlow has no PHASE_SCENES mapping")
	var title: StringName = constants.get("PHASE_TITLE", &"")
	var play: StringName = constants.get("PHASE_PLAY", &"")
	if not scenes.has(title) or not scenes.has(play):
		return _fail("PHASE_SCENES is missing a declared phase")
	for phase: StringName in scenes:
		var path: String = scenes[phase]
		if not ResourceLoader.exists(path):
			return _fail("phase '%s' points to a missing scene: %s" % [phase, path])
	return 0


func _t_flow_unlock_rule_is_a_pure_function() -> int:
	var script: Script = load("res://core/game_flow.gd")
	var constants: Dictionary = script.get_script_constant_map()
	if int(constants.get("PLAY_UNLOCK_SCORE", -1)) != 100:
		return _fail("GameFlow must own PLAY_UNLOCK_SCORE = 100")
	var title: StringName = constants.get("PHASE_TITLE", &"")
	var play: StringName = constants.get("PHASE_PLAY", &"")
	if bool(script.call("should_enter_play", 99, title)):
		return _fail("below the threshold must stay in title")
	if not bool(script.call("should_enter_play", 100, title)):
		return _fail("reaching the threshold should enter play")
	if not bool(script.call("should_enter_play", 250, title)):
		return _fail("a restored save score should also unlock play")
	if bool(script.call("should_enter_play", 250, play)):
		return _fail("already in play must not re-trigger the transition")
	return 0


func _t_loaded_save_score_unlocks_play() -> int:
	# 读档时按恢复出来的分数立即判定阶段，不必等下一次加分。
	var flow_text := FileAccess.get_file_as_string("res://core/game_flow.gd")
	if not flow_text.contains("register_event(GameLoadedEvent"):
		return _fail("GameFlow must subscribe to GameLoadedEvent")
	if not flow_text.contains("register_event(ScoreChangedEvent"):
		return _fail("GameFlow must subscribe to ScoreChangedEvent")
	var script: Script = load("res://core/game_flow.gd")
	var fake := FakeSaveUtility.new()
	fake.data = {"score": 250, "coins": 9}
	var architecture := _make_architecture_with_fake_save(fake)
	var decisions: Array = []
	architecture.register_event(GameLoadedEvent, func(_event: GameLoadedEvent) -> void:
		var player := architecture.get_model(PlayerModel) as PlayerModel
		decisions.append(bool(script.call(
			"should_enter_play", int(player.score.get_value()), &"title"))))
	architecture.send_command(LoadGameCommand.new(0))
	if decisions != [true]:
		return _fail("loaded score should drive the phase decision, got %s" % str(decisions))
	return 0


func _t_presentation_holds_no_flow_rules() -> int:
	var main_text := FileAccess.get_file_as_string("res://scenes/main.gd")
	if main_text.is_empty():
		return _fail("could not read scenes/main.gd")
	if main_text.contains("GameFlow.go(") or main_text.contains("current_phase()"):
		return _fail("flow transition rules must live in GameFlow, not the view")
	return 0


func _t_get_instance_caller_whitelist() -> int:
	# 栈信息不可用时应放行（宁可漏报也不误报）。
	if not GameArchitecture._is_allowed_caller([]):
		return _fail("an empty stack must be allowed")
	var resolve := [{"source": "res://core/game_flow.gd", "function": "_resolve_architecture"}]
	if not GameArchitecture._is_allowed_caller(resolve):
		return _fail("_resolve_architecture is the sanctioned resolution point")
	var view := [{"source": "res://scenes/main.gd", "function": "_on_controller_ready"}]
	if GameArchitecture._is_allowed_caller(view):
		return _fail("a view calling get_instance() directly must be flagged")
	return 0
