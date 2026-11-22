shader_type canvas_item;
// Boss aura: pulsing outer glow around the sprite's alpha silhouette plus a
// red/amber colour grade. Replaces character_unify's outline/rim on boss slots
// (art direction §4). Author: technical-artist.
// Targets: Forward+ and Compatibility (GL 3.3 / WebGL 2): plain texture() reads
// only, no compute, no screen/depth textures, no loops.
// Budget: 9 texture reads per fragment (was 17: a 16-tap loop + centre).
//
// Placement uses the same contract as character_unify: BattlerSlot passes the
// trimmed figure (crop_uv) and where it sits in the quad (dest_rect). The quad
// is larger than the figure, so the glow has room without shrinking the sprite.

group_uniforms placement;
/** Figure bounding box in texture UV: (x, y, w, h). */
uniform vec4 crop_uv = vec4(0.0, 0.0, 1.0, 1.0);
/** Where the figure is drawn, in quad UV: (x, y, w, h). */
uniform vec4 dest_rect = vec4(0.08, 0.08, 0.84, 0.84);
group_uniforms;

group_uniforms glow;
uniform vec4 glow_color : source_color = vec4(1.0, 0.35, 0.1, 1.0);
/** Glow reach in texels of the source texture. */
uniform float glow_width : hint_range(0.0, 40.0) = 14.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.2;
uniform float pulse_min : hint_range(0.0, 2.0) = 0.45;
uniform float pulse_max : hint_range(0.0, 2.0) = 1.1;
/** Radius of the 4 diagonal taps relative to glow_width (inner ring). */
uniform float inner_ring : hint_range(0.2, 1.0) = 0.55;
group_uniforms;

group_uniforms grade;
/** 0 = original colours, 1 = fully pushed to the red/amber palette. */
uniform float tint_strength : hint_range(0.0, 1.0) = 0.7;
uniform vec4 shadow_color : source_color = vec4(0.25, 0.04, 0.02, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.62, 0.2, 1.0);
group_uniforms;

const float DIAG = 0.7071068;  // cos(45 deg)
const vec3 LUMA = vec3(0.299, 0.587, 0.114);  // Rec. 601 luma weights
const float LUM_GAIN = 1.6;      // stretches luma so mids reach the highlight colour
const float DETAIL_KEEP = 0.4;   // share of original detail kept on top of the grade
const float GLOW_BOOST = 0.4;    // extra glow brightness at the pulse peak

// Node modulate / self_modulate arrive as the vertex COLOR. Overwriting COLOR in
// fragment() would discard them (breaking hit flash and the death fade), so they
// are captured here and re-applied at the end.
varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

// Alpha of the cropped figure at texture UV p; 0 outside the crop box.
float crop_alpha(sampler2D tex, vec2 p) {
	vec2 lo = crop_uv.xy;
	vec2 hi = crop_uv.xy + crop_uv.zw;
	vec2 inside = step(lo, p) * step(p, hi);
	return texture(tex, p).a * inside.x * inside.y;
}

void fragment() {
	vec2 local = (UV - dest_rect.xy) / dest_rect.zw;
	vec2 uv = crop_uv.xy + local * crop_uv.zw;
	vec2 in_box = step(vec2(0.0), local) * step(local, vec2(1.0));
	vec4 tex = texture(TEXTURE, uv);
	tex.a *= in_box.x * in_box.y;

	// Smooth 0..1 pulse mapped to [pulse_min, pulse_max].
	float pulse = mix(pulse_min, pulse_max, 0.5 + 0.5 * sin(TIME * pulse_speed));

	// Silhouette dilation, 8 unrolled taps: 4 axis taps at the full radius and
	// 4 diagonal taps on an inner ring (the old version used 8 + 8 in a loop).
	// Dividing by 4 saturates near the silhouette and fades toward the radius.
	vec2 px = TEXTURE_PIXEL_SIZE * glow_width;
	vec2 pd = px * inner_ring * DIAG;
	float a = crop_alpha(TEXTURE, uv + vec2(px.x, 0.0))
		+ crop_alpha(TEXTURE, uv - vec2(px.x, 0.0))
		+ crop_alpha(TEXTURE, uv + vec2(0.0, px.y))
		+ crop_alpha(TEXTURE, uv - vec2(0.0, px.y))
		+ crop_alpha(TEXTURE, uv + pd)
		+ crop_alpha(TEXTURE, uv - pd)
		+ crop_alpha(TEXTURE, uv + vec2(pd.x, -pd.y))
		+ crop_alpha(TEXTURE, uv + vec2(-pd.x, pd.y));
	float glow = clamp(a / 4.0, 0.0, 1.0) * (1.0 - tex.a) * pulse;

	// Colour grade: luminance-preserving remap of the mech into a dark red ->
	// amber gradient, so the green glow panels turn red/amber too.
	float lum = dot(tex.rgb, LUMA);
	vec3 graded = mix(shadow_color.rgb, highlight_color.rgb, clamp(lum * LUM_GAIN, 0.0, 1.0));
	graded = mix(graded, graded * (0.6 + tex.rgb), DETAIL_KEEP);
	vec3 body = mix(tex.rgb, graded, tint_strength);

	// Body where the sprite is, glow outside it. node_modulate is re-applied so
	// hit flashes, the death fade and self_modulate affect the aura too.
	vec3 glow_rgb = glow_color.rgb * (1.0 + GLOW_BOOST * pulse);
	float out_a = max(tex.a, glow * glow_color.a);
	vec3 rgb = mix(glow_rgb, body, tex.a);
	COLOR = vec4(rgb, out_a) * node_modulate;
}
