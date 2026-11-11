extends Node
## 画面风格演示：打开 demo.tscn 按 F6 运行。
## 1 / 2 / 3 切换 low / balanced / high，Space 开关后处理，H 显示或隐藏提示。
## 这里的场景由代码搭建，只为观察风格；正式项目请把模型保存在自己的 .tscn 里。

const PRESETS := {
	KEY_1: "res://visual/styles/industrial/presets/low.tres",
	KEY_2: "res://visual/styles/industrial/presets/balanced.tres",
	KEY_3: "res://visual/styles/industrial/presets/high.tres",
}

var _fx: CanvasLayer
var _hud: Label


func _ready() -> void:
	_build_world()
	var fx: CanvasLayer = load("res://visual/styles/industrial/industrial.tscn").instantiate()
	add_child(fx)
	_fx = fx
	_build_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key := (event as InputEventKey).keycode
	if PRESETS.has(key):
		_fx.profile = load(PRESETS[key])
	elif key == KEY_SPACE:
		_fx.effect_enabled = not _fx.effect_enabled
	elif key == KEY_H:
		_hud.visible = not _hud.visible


func _build_world() -> void:
	var world := Node3D.new()
	add_child(world)
	var floor_node := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(20, 20)
	floor_node.mesh = floor_mesh
	floor_node.material_override = load("res://visual/styles/industrial/materials/stained_wall.tres")
	world.add_child(floor_node)

	var table := MeshInstance3D.new()
	var table_mesh := BoxMesh.new()
	table_mesh.size = Vector3(3.0, 0.2, 1.6)
	table.mesh = table_mesh
	table.material_override = load("res://visual/styles/industrial/materials/worn_wood.tres")
	table.position = Vector3(0, 1.0, 0)
	world.add_child(table)

	var names := ["blued_steel", "old_brass", "olive_felt"]
	for i in range(3):
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.5, 0.5, 0.5)
		box.mesh = mesh
		box.material_override = load("res://visual/styles/industrial/materials/%s.tres" % names[i])
		box.position = Vector3(-0.9 + i * 0.9, 1.35, 0)
		world.add_child(box)

	var lights: Node = load("res://visual/styles/industrial/lights.tscn").instantiate()
	world.add_child(lights)
	var env := WorldEnvironment.new()
	env.environment = load("res://visual/styles/industrial/environment.tres")
	world.add_child(env)
	var camera := Camera3D.new()
	camera.current = true
	world.add_child(camera)
	camera.look_at_from_position(Vector3(3.2, 2.6, 4.2), Vector3(0, 1.0, 0))


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100  # 在效果层（20）之后，保持文字清晰
	add_child(layer)
	_hud = Label.new()
	_hud.text = "1/2/3 切换预设    Space 开关后处理    H 隐藏提示"
	_hud.position = Vector2(16, 12)
	layer.add_child(_hud)
