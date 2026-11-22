shader_type canvas_item;
// Boss aura: pulsing outer glow around the sprite's alpha silhouette plus a
// red/amber colour grade. Works in Forward+ and Compatibility (GL, WebGL 2):
// plain texture() reads only, no compute, no screen/depth textures.
//
// The art touches the texture edges, so the sprite is drawn shrunk toward the
// quad centre (content_scale) to leave a margin in which the glow can render.
// Compensate with a larger node scale / box (BattlerSlot does this).

group_uniforms glow;
uniform vec4 glow_color : source_color = vec4(1.0, 0.35, 0.1, 1.0);
/** Glow reach in texels of the source texture. */
uniform float glow_width : hint_range(0.0, 40.0) = 14.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.2;
uniform float pulse_min : hint_range(0.0, 2.0) = 0.45;
uniform float pulse_max : hint_range(0.0, 2.0) = 1.1;
group_uniforms;

group_uniforms grade;
/** 0 = original colours, 1 = fully pushed to the red/amber palette. */
uniform float tint_strength : hint_range(0.0, 1.0) = 0.7;
uniform vec4 shadow_color : source_color = vec4(0.25, 0.04, 0.02, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.62, 0.2, 1.0);
group_uniforms;

/** Fraction of the quad the sprite occupies (rest is glow margin). */
uniform float content_scale : hint_range(0.5, 1.0) = 0.84;

// Node modulate / self_modulate arrive as the vertex COLOR. Overwriting COLOR in
// fragment() would discard them (breaking hit flash and the death fade), so they
// are captured here and re-applied at the end.
varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

// Alpha of the source texture at a (possibly out-of-range) UV; 0 outside.
float alpha_at(sampler2D tex, vec2 uv) {
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return texture(tex, uv).a * inside.x * inside.y;
}

void fragment() {
	// Remap so the sprite is shrunk about the quad centre.
	vec2 uv = (UV - 0.5) / content_scale + 0.5;
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	vec4 tex = texture(TEXTURE, uv);
	tex.a *= inside.x * inside.y;

	// Smooth 0..1 pulse mapped to [pulse_min, pulse_max].
	float pulse = mix(pulse_min, pulse_max, 0.5 + 0.5 * sin(TIME * pulse_speed));

	// Silhouette dilation: 8 taps at the full radius plus 8 at half radius.
	vec2 px = TEXTURE_PIXEL_SIZE * glow_width;
	float a = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982;
		vec2 d = vec2(cos(ang), sin(ang));
		a += alpha_at(TEXTURE, uv + d * px);
		a += alpha_at(TEXTURE, uv + d * px * 0.5);
	}
	float glow = clamp(a / 8.0, 0.0, 1.0) * (1.0 - tex.a) * pulse;

	// Colour grade: luminance-preserving remap of the mech into a dark red ->
	// amber gradient, so the green glow panels turn red/amber too.
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(shadow_color.rgb, highlight_color.rgb, clamp(lum * 1.6, 0.0, 1.0));
	// Keep a little of the original detail so panel lines survive.
	graded = mix(graded, graded * (0.6 + tex.rgb), 0.4);
	vec3 body = mix(tex.rgb, graded, tint_strength);

	// Body where the sprite is, glow outside it. node_modulate is re-applied so
	// hit flashes, the death fade and self_modulate affect the aura too.
	vec3 glow_rgb = glow_color.rgb * (1.0 + 0.4 * pulse);
	float out_a = max(tex.a, glow * glow_color.a);
	vec3 rgb = mix(glow_rgb, body, tex.a);
	COLOR = vec4(rgb, out_a) * node_modulate;
}
