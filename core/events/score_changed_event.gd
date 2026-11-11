class_name ScoreChangedEvent
extends GxEvent
## 分数已经变化。过去式命名，因为事件描述的是既成事实。

var score: int


static func create(value: int) -> ScoreChangedEvent:
	var event := ScoreChangedEvent.new()
	event.score = value
	return event
