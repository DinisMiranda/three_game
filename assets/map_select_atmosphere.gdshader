shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 neon_cyan : source_color = vec4(0.0, 0.92, 1.0, 1.0);
uniform vec4 neon_magenta : source_color = vec4(1.0, 0.15, 0.72, 1.0);
uniform float grid_scale : hint_range(20.0, 200.0) = 72.0;
uniform float scan_speed : hint_range(0.0, 40.0) = 14.0;

void fragment() {
	vec2 uv = UV;
	vec3 base = mix(vec3(0.02, 0.01, 0.06), vec3(0.0, 0.04, 0.09), uv.y);
	vec2 g = uv * vec2(grid_scale, grid_scale * 0.56);
	vec2 fr = fract(g) - 0.5;
	float cell = max(abs(fr.x), abs(fr.y));
	float grid = 1.0 - smoothstep(0.38, 0.5, cell);
	float pulse = sin(TIME * 1.8 + uv.x * 9.0 + uv.y * 3.0) * 0.18 + 0.82;
	vec3 gcol = mix(neon_cyan.rgb, neon_magenta.rgb, sin(TIME * 0.7 + uv.y * 4.0) * 0.5 + 0.5);
	vec3 neon = gcol * grid * 0.35 * pulse;
	float scan = sin(uv.y * 900.0 + TIME * scan_speed) * 0.04 + 0.96;
	float horiz = sin(uv.y * 3.14159 * 12.0 + TIME * 2.5) * 0.015;
	vec3 col = base * scan * (1.0 + horiz) + neon;
	float vig = smoothstep(1.35, 0.28, distance(uv, vec2(0.5, 0.48)));
	col *= vig;
	float flick = step(0.997, sin(TIME * 37.0 + uv.x * 100.0)) * 0.08;
	col += vec3(flick);
	COLOR = vec4(col, 0.62);
}
