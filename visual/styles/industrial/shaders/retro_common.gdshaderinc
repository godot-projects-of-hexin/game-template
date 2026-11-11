uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float grain : hint_range(0.0, 0.15) = 0.035;
uniform float grain_fps = 20.0;
uniform float vignette = 0.38;
uniform float saturation = 0.76;
uniform float contrast = 1.08;
uniform float exposure = 1.0;
uniform vec3 shadow_tint = vec3(0.89, 0.98, 0.91);
uniform vec3 highlight_tint = vec3(1.04, 1.01, 0.91);
uniform float dither = 0.3;
uniform float color_steps = 64.0;
uniform float scanlines = 0.0;

float hash_pixel(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// 4x4 ordered dithering; no noise texture, array lookup or trigonometry.
float bayer4(vec2 pixel) {
	vec2 lo = mod(pixel, 2.0);
	vec2 hi = mod(floor(pixel * 0.5), 2.0);
	float a = 2.0 * lo.x + 3.0 * lo.y - 4.0 * lo.x * lo.y;
	float b = 2.0 * hi.x + 3.0 * hi.y - 4.0 * hi.x * hi.y;
	return (4.0 * a + b + 0.5) / 16.0 - 0.5;
}

vec3 retro_finish(vec3 original, vec2 uv, vec2 pixel, float seconds) {
	vec3 c = original * exposure;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c *= mix(shadow_tint, highlight_tint, smoothstep(0.06, 0.8, luma));
	// Multiplicative contrast preserves black and doesn't make dark scenes clip away.
	c *= mix(1.0 / max(contrast, 0.01), contrast, clamp(luma, 0.0, 1.0));
	float steps = max(color_steps, 8.0);
	vec3 quantized = floor(clamp(c, 0.0, 1.0) * steps + 0.5 + bayer4(pixel) * dither) / steps;
	c = mix(c, quantized, dither);
	vec2 centered = (uv - 0.5) * 2.0;
	float corner = smoothstep(0.2, 1.55, dot(centered, centered));
	c *= 1.0 - corner * vignette;
	// Keep the temporal offset bounded: growing coordinates lose hash precision
	// after a few minutes and otherwise form visible vertical bands.
	float tick = mod(floor(seconds * grain_fps), 4096.0);
	vec2 seed = fract(tick * vec2(0.754877666, 0.569840291)) * 97.0;
	float noise = hash_pixel(pixel + seed) - 0.5;
	// Little grain in absolute black, more in midtones; monochrome rather than RGB snow.
	c += noise * grain * smoothstep(0.0, 0.12, luma) * mix(1.0, 0.45, clamp(luma, 0.0, 1.0));
	c *= 1.0 - mod(pixel.y, 2.0) * scanlines;
	return mix(original, clamp(c, 0.0, 1.0), strength);
}
