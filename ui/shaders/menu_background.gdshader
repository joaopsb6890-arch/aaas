shader_type canvas_item;

// Animated, asset-free menu background: gradient + moving tactical grid +
// scan band + radial accent glow + vignette + light film grain.

uniform vec4 top_color : source_color = vec4(0.055, 0.075, 0.105, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.012, 0.016, 0.024, 1.0);
uniform vec4 grid_color : source_color = vec4(0.70, 0.80, 0.95, 0.055);
uniform vec4 accent_color : source_color = vec4(1.0, 0.62, 0.11, 1.0);
uniform float grid_scale = 22.0;
uniform float grid_speed = 0.035;
uniform float glow_strength = 0.20;
uniform float vignette_strength = 1.25;
uniform float grain_strength = 0.022;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, uv.y);

	// Scrolling grid, two layers moving at different speeds for parallax.
	vec2 slow = uv + vec2(TIME * grid_speed, TIME * grid_speed * 0.35);
	vec2 fast = uv + vec2(TIME * grid_speed * 2.1, TIME * grid_speed * 0.9);
	vec2 cell_slow = abs(fract(slow * grid_scale) - 0.5);
	vec2 cell_fast = abs(fract(fast * grid_scale * 0.5 + 0.25) - 0.5);
	float lines = max(smoothstep(0.47, 0.5, max(cell_slow.x, cell_slow.y)),
			smoothstep(0.485, 0.5, max(cell_fast.x, cell_fast.y)) * 0.45);
	col += grid_color.rgb * lines;

	// Thin scan band travelling upwards.
	float band = pow(1.0 - abs(fract(uv.y - TIME * 0.045) * 2.0 - 1.0), 26.0);
	col += accent_color.rgb * band * 0.10;

	// Soft accent glow behind the title block.
	float glow = smoothstep(0.85, 0.0, distance(uv, vec2(0.30, 0.46)));
	col += accent_color.rgb * glow * glow_strength * 0.55;

	// Vignette.
	float vig = smoothstep(0.32, 1.05, distance(uv, vec2(0.5, 0.5)));
	col *= 1.0 - clamp(vig * vignette_strength, 0.0, 0.92);

	// Film grain to avoid visible banding.
	col += (hash21(uv * 920.0 + fract(TIME) * 137.0) - 0.5) * grain_strength;

	COLOR = vec4(col, 1.0);
}
