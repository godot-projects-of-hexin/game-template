extends Node
## GameData — project-specific model + persistence (autoload).
## Mechanism comes from gd-common SaveSystem; the fields are yours to define.

const SAVE_SLOT := 0

# --- your game state ---
var level: int = 0
var score: int = 0

signal changed


func reset() -> void:
	level = 0
	score = 0
	changed.emit()


func save() -> void:
	SaveSystem.save_to_slot(SAVE_SLOT, {
		"level": level,
		"score": score,
	})


func load_game() -> void:
	var data := SaveSystem.load_from_slot(SAVE_SLOT)
	if data.is_empty():
		return
	level = data.get("level", 0)
	score = data.get("score", 0)
	changed.emit()


func has_save() -> bool:
	return SaveSystem.has_slot(SAVE_SLOT)
