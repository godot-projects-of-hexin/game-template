class_name PlayerModel
extends GxModel
## Model 层：只放状态与读写状态的方法；判断逻辑归 System / Query。
## 用 GxBindableProperty 暴露值，UI 可以 bind 并立刻拿到当前值。

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
## 恢复完成后由 GameLoadedEvent 统一通知表现层重建（见 notify_all）。
func apply_save_data(data: Dictionary) -> void:
	score.set_value_silent(int(data.get("score", 0)))
	coins.set_value_silent(int(data.get("coins", 0)))


## 读档后统一重播所有可绑定状态，让已经 bind 的表现层重建界面。
## 只重播、不写入 —— 状态恢复完全由 apply_save_data() 负责，
## 所以这不属于「表现层直接改状态」。
func notify_all() -> void:
	score.notify()
	coins.notify()
