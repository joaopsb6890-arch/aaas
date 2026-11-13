shader_type canvas_item;
uniform vec4 col_a : source_color = vec4(0.03, 0.04, 0.08, 1.0);
uniform vec4 col_b : source_color = vec4(0.16, 0.07, 0.03, 1.0);

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.12;
	float g = smoothstep(0.0, 1.0, uv.y + 0.15 * sin(uv.x * 3.0 + t * 4.0));
	vec3 c = mix(col_a.rgb, col_b.rgb, pow(g, 2.2));
	// feixes de luz lentos
	float beam = pow(max(0.0, sin(uv.x * 6.0 - uv.y * 2.0 + t * 6.0)), 14.0) * 0.07;
	c += vec3(1.0, 0.45, 0.15) * beam * uv.y;
	// grelha em perspetiva
	vec2 gp = vec2((uv.x - 0.5) / max(uv.y - 0.55, 0.02), 1.0 / max(uv.y - 0.55, 0.02) + TIME * 0.8);
	float grid = step(0.96, fract(gp.x * 0.6)) + step(0.96, fract(gp.y * 0.6));
	c += vec3(0.2, 0.55, 0.8) * clamp(grid, 0.0, 1.0) * 0.12 * smoothstep(0.55, 1.0, uv.y);
	float vig = smoothstep(1.1, 0.3, length((uv - 0.5) * vec2(1.2, 1.0)));
	COLOR = vec4(c * mix(0.5, 1.0, vig), 1.0);
}
