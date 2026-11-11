extends SceneTree
## visual/ 模块回归测试。headless 只验证逻辑与资源引用，不评价 GPU 画面。
## Run: godot --headless --path . --script res://tests/test_visual_style.gd
##
## 注意：查重用例会故意触发一条 "duplicate effect" warning，属预期输出。
## 覆盖：开箱即用场景、demo 按键路径、参数同步、色差切换、开关、查重、资源加载。

const POST_PROCESS = preload("res://visual/core/post_process.tscn")
const BALANCED = preload("res://visual/styles/industrial/presets/balanced.tres")

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var failures := 0
	failures += _t_no_profile_draws_nothing()
	failures += _t_profile_drives_shader_and_params()
	failures += _t_chromatic_switches_shader()
	failures += _t_disable_stops_copy_and_draw()
	failures += _t_duplicate_instance_is_disabled()
	failures += _t_style_assets_load()
	failures += _t_industrial_scene_is_ready()
	failures += _t_demo_key_switch()
	if failures > 0:
		print("VISUAL_STYLE_TEST: %d failure(s)" % failures)
		quit(1)
	else:
		print("VISUAL_STYLE_TEST: all passed")
		quit(0)
	return true


func _fail(label: String) -> int:
	print("  FAIL: %s" % label)
	return 1


func _spawn() -> CanvasLayer:
	var node := POST_PROCESS.instantiate() as CanvasLayer
	root.add_child(node)
	return node


func _t_no_profile_draws_nothing() -> int:
	var node := _spawn()
	var failed := 0
	if node.visible:
		failed += _fail("no profile must not draw")
	if node.get_sample_count() != 0:
		failed += _fail("no profile must sample nothing")
	node.free()
	return failed


func _t_profile_drives_shader_and_params() -> int:
	var node := _spawn()
	var profile := BALANCED.duplicate() as Resource
	node.set("profile", profile)
	var failed := 0
	var material := node.get_node("Film").material as ShaderMaterial
	if not node.visible:
		failed += _fail("valid profile should enable drawing")
	if material.shader != profile.get("shader"):
		failed += _fail("material must use the profile shader")
	profile.set("grain", 0.05)
	var grain: Variant = material.get_shader_parameter(&"grain")
	if not is_equal_approx(float(grain), 0.05):
		failed += _fail("profile change must sync shader parameters")
	node.free()
	return failed


func _t_chromatic_switches_shader() -> int:
	var node := _spawn()
	var profile := BALANCED.duplicate() as Resource
	node.set("profile", profile)
	var failed := 0
	profile.set("chromatic_enabled", true)
	var material := node.get_node("Film").material as ShaderMaterial
	if material.shader != profile.get("chromatic_shader"):
		failed += _fail("chromatic_enabled must switch to the chromatic shader")
	if node.get_sample_count() != 3:
		failed += _fail("chromatic path samples three times")
	node.free()
	return failed


func _t_disable_stops_copy_and_draw() -> int:
	var node := _spawn()
	node.set("profile", BALANCED.duplicate())
	var failed := 0
	node.set("effect_enabled", false)
	if node.visible:
		failed += _fail("disabled effect must not draw")
	var copy := node.get_node("BackBufferCopy") as BackBufferCopy
	if copy.copy_mode != BackBufferCopy.COPY_MODE_DISABLED:
		failed += _fail("disabled effect must stop the screen copy")
	if node.get_sample_count() != 0:
		failed += _fail("disabled effect must sample nothing")
	node.free()
	return failed


func _t_duplicate_instance_is_disabled() -> int:
	var first := _spawn()
	first.set("profile", BALANCED.duplicate())
	var second := _spawn()
	second.set("profile", BALANCED.duplicate())
	var failed := 0
	if not first.get("effect_enabled"):
		failed += _fail("first instance must stay enabled")
	if second.get("effect_enabled"):
		failed += _fail("later instance in the same viewport must be disabled")
	first.free()
	second.free()
	return failed


func _t_style_assets_load() -> int:
	# 迁移后所有 res:// 引用都必须仍可解析。
	var failed := 0
	var paths := [
		"res://visual/core/style_stage.tscn",
		"res://visual/styles/industrial/industrial.tscn",
		"res://visual/styles/industrial/lights.tscn",
		"res://visual/styles/industrial/environment.tres",
		"res://visual/styles/industrial/presets/low.tres",
		"res://visual/styles/industrial/presets/high.tres",
	]
	for path in paths:
		if load(path) == null:
			failed += _fail("cannot load %s" % path)
	for material_name in ["blued_steel", "old_brass", "olive_felt", "stained_wall", "worn_wood"]:
		var material := load("res://visual/styles/industrial/materials/%s.tres" % material_name) as StandardMaterial3D
		if material == null or material.albedo_texture == null or material.roughness_texture == null:
			failed += _fail("material %s lost its textures" % material_name)
	return failed


func _t_industrial_scene_is_ready() -> int:
	# 「拖进场景即可用」是工业风格包的对外承诺，只 load() 检查不出 Profile 是否真的绑上。
	var scene := load("res://visual/styles/industrial/industrial.tscn")
	var fx := scene.instantiate() as CanvasLayer
	root.add_child(fx)
	var failed := 0
	var profile: Variant = fx.get("profile")
	if profile == null:
		failed += _fail("industrial.tscn has no bound profile")
	else:
		var material := fx.get_node("Film").material as ShaderMaterial
		if material.shader == null:
			failed += _fail("industrial.tscn material has no shader")
		if not fx.visible:
			failed += _fail("industrial.tscn is not drawing")
	fx.free()
	return failed


func _t_demo_key_switch() -> int:
	# demo 是文档里给出的主要入口，按键路径必须真的能跑。
	var demo: Node = load("res://visual/demo/demo.tscn").instantiate()
	root.add_child(demo)
	var failed := 0
	for key in [KEY_1, KEY_3, KEY_SPACE, KEY_SPACE, KEY_H, KEY_H]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		demo.call("_unhandled_input", event)
	var fx: Variant = demo.get("_fx")
	if fx == null or fx.get("profile") == null:
		failed += _fail("demo key switch left profile null")
	if fx != null and not bool(fx.get("effect_enabled")):
		failed += _fail("demo Space toggle did not restore effect")
	demo.free()
	return failed
