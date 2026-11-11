@tool
extends CanvasLayer
## 通用全屏后处理宿主。外观由 StyleProfile 提供，本脚本不认识任何具体风格。
## 每个 Viewport 只放一个，位于世界 UI 之上、需要清晰的 HUD 之下。

const Profile = preload("style_profile.gd")
const PARAMETERS = [&"strength", &"grain", &"grain_fps", &"vignette", &"saturation",
	&"contrast", &"exposure", &"shadow_tint", &"highlight_tint", &"dither",
	&"color_steps", &"scanlines", &"chromatic_pixels"]

@export var profile: Profile:
	set(value):
		if profile != null and profile.changed.is_connected(_refresh):
			profile.changed.disconnect(_refresh)
		profile = value
		if profile != null:
			profile.changed.connect(_refresh)
		_refresh()
@export var effect_enabled: bool = true:
	set(value):
		effect_enabled = value
		_refresh()

var _material: ShaderMaterial


func _ready() -> void:
	# 防止同一视口出现第二个全屏 pass。
	for other in get_tree().get_nodes_in_group(&"visual_style_effect"):
		if other != self and other.get_viewport() == get_viewport():
			push_warning("VisualStyle: duplicate effect in one Viewport; later instance disabled.")
			effect_enabled = false
			break
	add_to_group(&"visual_style_effect")
	_refresh()


func _active_shader() -> Shader:
	if profile == null:
		return null
	if profile.chromatic_enabled and profile.chromatic_shader != null:
		return profile.chromatic_shader
	return profile.shader


func _refresh() -> void:
	if not is_node_ready():
		return
	var shader := _active_shader()
	visible = effect_enabled and shader != null and profile.strength > 0.0
	$BackBufferCopy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if visible else BackBufferCopy.COPY_MODE_DISABLED
	if _material == null:
		_material = ShaderMaterial.new()
		$Film.material = _material
	_material.shader = shader
	if profile == null:
		return
	for parameter in PARAMETERS:
		_material.set_shader_parameter(parameter, profile.get(parameter))


func get_sample_count() -> int:
	if not visible:
		return 0
	return 3 if profile.chromatic_enabled else 1
