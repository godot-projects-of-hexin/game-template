class_name CanAffordQuery
extends GxQuery
## 只读问题：当前硬币够不够付这个价。
##
## 这种判断不放 Model（Model 只管状态），也不值得做成 Command（Command 不返回值）。

var _price: int


func _init(price: int) -> void:
	_price = price


func _on_run() -> Variant:
	var player := get_model(PlayerModel) as PlayerModel
	if player == null:
		return false
	return int(player.coins.get_value()) >= _price
