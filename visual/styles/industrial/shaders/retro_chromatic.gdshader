shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float chromatic_pixels = 0.65;
#include "retro_common.gdshaderinc"

void fragment() {
	vec2 edge = SCREEN_UV - 0.5;
	vec2 shift = edge * dot(edge, edge) * chromatic_pixels * SCREEN_PIXEL_SIZE * 4.0 * strength;
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	c.r = textureLod(screen_texture, SCREEN_UV + shift, 0.0).r;
	c.b = textureLod(screen_texture, SCREEN_UV - shift, 0.0).b;
	COLOR = vec4(retro_finish(c, SCREEN_UV, floor(SCREEN_UV / SCREEN_PIXEL_SIZE), TIME), 1.0);
}
