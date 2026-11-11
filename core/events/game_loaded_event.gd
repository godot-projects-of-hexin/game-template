class_name GameLoadedEvent
extends GxEvent
## 存档已经读取完成。
##
## 读档时 Model 用 set_value_silent 静默写入，所以表现层不会收到逐个属性的
## 变化通知 —— 改为在这里统一重建界面。

var slot: int


static func create(slot_index: int) -> GameLoadedEvent:
	var event := GameLoadedEvent.new()
	event.slot = slot_index
	return event
