shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint : source_color = vec4(0.03, 0.05, 0.09, 1.0);

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 3.0 * amount).rgb;
	c = mix(c, tint.rgb, 0.55 * amount);
	float left = smoothstep(0.7, 0.0, SCREEN_UV.x);
	c = mix(c, tint.rgb * 0.5, left * 0.55 * amount);
	float vig = smoothstep(1.0, 0.3, length((SCREEN_UV - 0.5) * vec2(1.2, 1.0)));
	COLOR = vec4(c * mix(0.6, 1.0, vig), 1.0);
}
