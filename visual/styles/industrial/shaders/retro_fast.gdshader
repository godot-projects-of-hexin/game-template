shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
#include "retro_common.gdshaderinc"

void fragment() {
	vec3 original = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec2 pixel = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	COLOR = vec4(retro_finish(original, SCREEN_UV, pixel, TIME), 1.0);
}
