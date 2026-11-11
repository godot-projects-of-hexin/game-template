@tool
extends Resource
## 外观参数资源。风格 = 参数 + shader，换风格就是换一份 Profile。
## 组件按 changed 信号刷新，不做每帧轮询。项目自定义外观请另存副本，别改随包预设。

## 基础 shader（单采样）。为 null 时组件不绘制。
@export var shader: Shader:
	set(value):
		shader = value
		emit_changed()
## 可选的三采样色差 shader；chromatic_enabled 打开且此字段非空时才使用。
@export var chromatic_shader: Shader:
	set(value):
		chromatic_shader = value
		emit_changed()

@export_range(0.0, 1.0) var strength: float = 1.0:
	set(value):
		strength = value
		emit_changed()
@export_range(0.0, 0.15) var grain: float = 0.035:
	set(value):
		grain = value
		emit_changed()
## 噪声图案每秒更新次数，不是游戏帧率。
@export_range(1.0, 60.0) var grain_fps: float = 20.0:
	set(value):
		grain_fps = value
		emit_changed()
@export_range(0.0, 1.0) var vignette: float = 0.38:
	set(value):
		vignette = value
		emit_changed()
@export_range(0.0, 1.5) var saturation: float = 0.76:
	set(value):
		saturation = value
		emit_changed()
@export_range(0.5, 1.5) var contrast: float = 1.08:
	set(value):
		contrast = value
		emit_changed()
## 后处理亮度倍率，不等于物理相机曝光。
@export_range(0.25, 2.0) var exposure: float = 1.0:
	set(value):
		exposure = value
		emit_changed()
## 乘数而非取色器颜色：作用在最终 LDR 图像上。
@export var shadow_tint: Vector3 = Vector3(0.89, 0.98, 0.91):
	set(value):
		shadow_tint = value
		emit_changed()
@export var highlight_tint: Vector3 = Vector3(1.04, 1.01, 0.91):
	set(value):
		highlight_tint = value
		emit_changed()
@export_range(0.0, 1.0) var dither: float = 0.3:
	set(value):
		dither = value
		emit_changed()
@export_range(8.0, 256.0) var color_steps: float = 64.0:
	set(value):
		color_steps = value
		emit_changed()
## 可选 CRT 扫描线；工业预设默认为 0。
@export_range(0.0, 0.2) var scanlines: float = 0.0:
	set(value):
		scanlines = value
		emit_changed()
@export var chromatic_enabled: bool = false:
	set(value):
		chromatic_enabled = value
		emit_changed()
@export_range(0.0, 3.0) var chromatic_pixels: float = 0.65:
	set(value):
		chromatic_pixels = value
		emit_changed()
