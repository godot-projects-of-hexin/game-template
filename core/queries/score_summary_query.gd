class_name ScoreSummaryQuery
extends GxQuery
## 只读问题：把分数相关的信息拼成一份给 UI 用的摘要。
##
## 需要同时读 Model 的状态和 System 的规则时，就该用 Query —— 别让表现层
## 自己去取两边再拼，那等于把业务规则泄漏到 UI 里。


func _on_run() -> Variant:
	var player := get_model(PlayerModel) as PlayerModel
	var scoring := get_system(ScoreSystem) as ScoreSystem
	if player == null or scoring == null:
		return {}
	var score := int(player.score.get_value())
	return {
		"score": score,
		"coins": int(player.coins.get_value()),
		"convertible_coins": scoring.coins_for_score(score),
	}
