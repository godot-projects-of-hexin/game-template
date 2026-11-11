class_name ScoreSystem
extends GxSystem
## System 层：不属于任何单一场景的计分规则。
##
## 判断标准是「这条规则被两个以上的表现节点需要吗」—— 自动存档既和 HUD 无关，
## 也和关卡无关，所以它属于 System，不属于某个节点。
##
## System 不许持有节点引用、不许 get_tree()、不许碰 Control。一旦碰了，
## 它就是表现层。

## 每累积这么多分自动存一次档。
const AUTOSAVE_SCORE_STEP := 100

var _last_autosave_step := 0


func _on_init() -> void:
	register_event(ScoreChangedEvent, _on_score_changed)
	register_event(GameResetEvent, _on_game_reset)
	register_event(GameLoadedEvent, _on_game_loaded)


## 当前分数能换多少硬币。业务规则放 System，不放 Model。
func coins_for_score(score: int) -> int:
	return score / 10


func _on_score_changed(event: ScoreChangedEvent) -> void:
	var step := event.score / AUTOSAVE_SCORE_STEP
	if step <= _last_autosave_step:
		return
	_last_autosave_step = step
	var player := get_model(PlayerModel) as PlayerModel
	var save_utility := get_utility(SaveUtility) as SaveUtility
	if player == null or save_utility == null:
		return
	save_utility.save(PlayerModel.SAVE_SLOT, player.to_save_data())


func _on_game_reset(_event: GameResetEvent) -> void:
	_last_autosave_step = 0


## 读档后按恢复出来的分数重新起算步进，避免沿用上一局的计数。
func _on_game_loaded(_event: GameLoadedEvent) -> void:
	var player := get_model(PlayerModel) as PlayerModel
	if player == null:
		return
	_last_autosave_step = int(player.score.get_value()) / AUTOSAVE_SCORE_STEP
