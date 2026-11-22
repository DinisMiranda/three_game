shader_type canvas_item;
// Character unify: one look for every non-boss battle sprite (art direction §4).
//   - Trim + placement: the quad (the BattlerSlot TextureRect) is larger than the
//     figure. BattlerSlot computes the figure's opaque bounding box in the texture
//     (crop_uv) and where it must sit in the quad (dest_rect, bottom-aligned on the
//     floor line). Swapping attack frames only changes these two uniforms, so the
//     node's position/size never move (BattleFx lunges and slumps stay intact).
//   - 2 px dark outline (alpha dilation) and a thin rim light in the side colour.
//   - Per-sprite grade: saturation, contrast, brightness (defaults 1 / 1 / 0).
//
// Author: technical-artist (Phase 2 visual coherence).
// Targets: Forward+ and Compatibility (GL 3.3 / WebGL 2). Plain texture() reads
// only, no screen/depth textures, no loops, no branches.
// Budget: 9 texture reads per fragment (1 centre + 8 unrolled ring taps shared by
// outline and rim), down from boss_aura's 17. Quad = slot sprite box.

group_uniforms placement;
/** Figure bounding box in texture UV: (x, y, w, h). */
uniform vec4 crop_uv = vec4(0.0, 0.0, 1.0, 1.0);
/** Where the figure is drawn, in quad UV: (x, y, w, h). */
uniform vec4 dest_rect = vec4(0.0, 0.0, 1.0, 1.0);
group_uniforms;

group_uniforms outline;
/** Outline radius in texture UV (BattlerSlot converts 2 screen px to this). */
uniform vec2 outline_uv = vec2(0.004, 0.003);
uniform vec4 outline_color : source_color = vec4(0.0196, 0.0275, 0.0471, 0.9);
group_uniforms;

group_uniforms rim;
/** Side colour: party_teal #00D9E6 or enemy_red #FF6B52; alpha = strength. */
uniform vec4 rim_color : source_color = vec4(0.0, 0.851, 0.902, 0.6);
/** Direction the rim light comes FROM, in screen space (y down). */
uniform vec2 rim_dir = vec2(-0.6, -0.8);
/** 0 = rim on every edge, 1 = only on edges facing rim_dir. */
uniform float rim_directionality : hint_range(0.0, 1.0) = 0.6;
group_uniforms;

group_uniforms grade;
uniform float saturation : hint_range(0.0, 3.0) = 1.0;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
group_uniforms;

const float DIAG = 0.7071068;  // cos(45 deg): diagonal ring taps
const vec3 LUMA = vec3(0.299, 0.587, 0.114);  // Rec. 601 luma weights

// Node modulate / self_modulate arrive as the vertex COLOR. Writing COLOR in
// fragment() would discard them (hit flash, tint, death fade), so capture here
// and multiply back at the end (same as boss_aura).
varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

// Alpha of the cropped figure at texture UV p; 0 outside the crop box, so
// neighbouring padding noise never produces outline.
float crop_alpha(sampler2D tex, vec2 p) {
	vec2 lo = crop_uv.xy;
	vec2 hi = crop_uv.xy + crop_uv.zw;
	vec2 inside = step(lo, p) * step(p, hi);
	return texture(tex, p).a * inside.x * inside.y;
}

// One ring tap: accumulates max/min alpha and the "open" (transparent) direction.
void ring_tap(sampler2D tex, vec2 uv, vec2 d, inout float a_max, inout float a_min, inout vec2 open_dir) {
	float s = crop_alpha(tex, uv + d * outline_uv);
	a_max = max(a_max, s);
	a_min = min(a_min, s);
	open_dir += d * (1.0 - s);
}

void fragment() {
	// Quad UV -> local 0..1 inside the figure box -> texture UV.
	vec2 local = (UV - dest_rect.xy) / dest_rect.zw;
	vec2 uv = crop_uv.xy + local * crop_uv.zw;

	vec4 tex = texture(TEXTURE, uv);
	vec2 in_box = step(vec2(0.0), local) * step(local, vec2(1.0));
	tex.a *= in_box.x * in_box.y;

	// 8 ring taps at the outline radius (unrolled: no texture reads in a loop).
	// max -> outline, min -> rim mask, sum of empty directions -> edge facing.
	float a_max = 0.0;
	float a_min = 1.0;
	vec2 open_dir = vec2(0.0);
	ring_tap(TEXTURE, uv, vec2(1.0, 0.0), a_max, a_min, open_dir);
	ring_tap(TEXTURE, uv, vec2(-1.0, 0.0), a_max, a_min, open_dir);
	ring_tap(TEXTURE, uv, vec2(0.0, 1.0), a_max, a_min, open_dir);
	ring_tap(TEXTURE, uv, vec2(0.0, -1.0), a_max, a_min, open_dir);
	ring_tap(TEXTURE, uv, vec2(DIAG, DIAG), a_max, a_min, open_dir);
	ring_tap(TEXTURE, uv, vec2(-DIAG, DIAG), a_max, a_min, open_dir);
	ring_tap(TEXTURE, uv, vec2(DIAG, -DIAG), a_max, a_min, open_dir);
	ring_tap(TEXTURE, uv, vec2(-DIAG, -DIAG), a_max, a_min, open_dir);

	// Grade: saturation -> contrast (about mid grey) -> brightness.
	vec3 c = tex.rgb;
	float lum = dot(c, LUMA);
	c = mix(vec3(lum), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c = clamp(c + brightness, 0.0, 1.0);

	// Rim: inner edge (opaque here, transparent within the radius), biased to
	// edges whose open side faces the light. 1e-4 keeps normalize() defined
	// inside solid areas where open_dir is zero.
	float edge = tex.a * (1.0 - a_min);
	float facing = dot(normalize(open_dir + vec2(1e-4)), normalize(rim_dir));
	float dir_w = mix(1.0, smoothstep(-0.1, 0.7, facing), rim_directionality);
	c = mix(c, rim_color.rgb, edge * dir_w * rim_color.a);

	// Outline behind the sprite ("over" composite, straight alpha). max() guards
	// the divide where nothing is drawn.
	float o_a = a_max * outline_color.a * (1.0 - tex.a);
	float out_a = tex.a + o_a;
	vec3 rgb = (c * tex.a + outline_color.rgb * o_a) / max(out_a, 1e-4);
	COLOR = vec4(rgb, out_a) * node_modulate;
}
