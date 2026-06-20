extends Node
## GameManager — project-specific flow controller (autoload).
## Uses gd-common GxStateMachine to drive top-level scene/phase transitions.
## (Use godot_state_charts or similar for per-actor AI, not this.)

const GxStateMachine := preload("res://addons/gd-common/fsm/state_machine.gd")
const GxState := preload("res://addons/gd-common/fsm/state.gd")

# Map each phase to the scene it shows. Add your own phases/scenes here.
const SCENES := {
	&"title": "res://scenes/main.tscn",
	# &"play": "res://scenes/levels/level_01.tscn",
}

var _sm


func _ready() -> void:
	_sm = GxStateMachine.new(self)
	for phase: StringName in SCENES:
		_sm.add_state(phase, GxState.new())
	_sm.state_changed.connect(_on_phase_changed)


func go(phase: StringName) -> void:
	_sm.transition_to(phase)


func current_phase() -> StringName:
	return _sm.current_name()


func _on_phase_changed(_from: StringName, to: StringName) -> void:
	if SCENES.has(to):
		get_tree().change_scene_to_file.call_deferred(SCENES[to])
