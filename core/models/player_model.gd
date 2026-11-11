class_name PlayerModel
extends GxModel
## Model 层：玩家状态的唯一来源。
##
## 这里只放「状态」和「读写状态的方法」。判断逻辑（够不够钱、该不该升级）
## 属于 System 或 Query，不要写进来。
##
## 对外暴露的值用 GxBindableProperty，这样 UI 可以 bind 并立刻拿到当前值，
## 不会出现「界面先显示 0，等下一次变化才对」的问题。

const SAVE_SLOT := 0

var score := GxBindableProperty.new(0)
var coins := GxBindableProperty.new(0)


func add_score(amount: int) -> void:
	score.set_value(int(score.get_value()) + amount)


func add_coins(amount: int) -> void:
	coins.set_value(maxi(0, int(coins.get_value()) + amount))


func reset() -> void:
	score.set_value(0)
	coins.set_value(0)


## 打平成一个字典交给 Utility 存。字段名就是存档的 key，改名等于破坏旧存档。
func to_save_data() -> Dictionary:
	return {
		"score": int(score.get_value()),
		"coins": int(coins.get_value()),
	}


## 从存档恢复。用 set_value_silent 避免逐字段触发一串 UI 刷新，
## 恢复完成后由 GameLoadedEvent 统一通知表现层重建。
func apply_save_data(data: Dictionary) -> void:
	score.set_value_silent(int(data.get("score", 0)))
	coins.set_value_silent(int(data.get("coins", 0)))
