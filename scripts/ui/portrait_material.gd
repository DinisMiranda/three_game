class_name PortraitMaterial
extends RefCounted
## Character shader on portraits outside the battle arena (main menu teaser,
## turn-order chips, briefing speakers): the same character_unify outline, side
## rim and per-sprite roster grade as BattlerSlot, so a hero never appears
## "raw" (washed out) next to its battle sprite. Trim + crop happen in the
## shader (crop_uv / dest_rect), so the TextureRect shows the raw texture with
## STRETCH_SCALE and this helper owns where the figure lands in the rect.

const _CHAR_SHADER: Shader = preload("res://assets/shaders/character_unify.gdshader")
const _META := &"portrait_material_spec"
const _HOOKED := &"portrait_material_hooked"
const _STRETCH := &"portrait_material_stretch"

## Full trimmed figure (region of the trim rect, normalised).
const FULL_FIGURE := Rect2(0.0, 0.0, 1.0, 1.0)
## Head and shoulders of a trimmed figure (turn-order chips).
const HEAD_REGION := Rect2(0.15, 0.0, 0.7, 0.38)


## Pure placement maths. [param region] is a normalised sub-rect of the trim
## rect [param trim] inside a texture of [param tex_size]; [param rect_size] is
## the TextureRect size. [param cover] fills the rect (region shrunk to the rect
## aspect, top-anchored so heads stay in frame); otherwise the region is fitted
## inside the rect minus [param inset_px] on every side, centred horizontally
## and bottom-aligned. Returns [code]{ crop_uv: Vector4, dest_rect: Vector4,
## outline_uv: Vector2 }[/code] (UVs in texture / quad space). Empty inputs
## return the identity placement.
static func compute_placement(tex_size: Vector2, trim: Rect2i, rect_size: Vector2,
		region: Rect2 = FULL_FIGURE, cover: bool = false,
		inset_px: float = BattlerSlot.OUTLINE_PX) -> Dictionary:
	var identity := {
		"crop_uv": Vector4(0.0, 0.0, 1.0, 1.0),
		"dest_rect": Vector4(0.0, 0.0, 1.0, 1.0),
		"outline_uv": Vector2.ZERO,
	}
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return identity
	var t := Rect2(trim)
	if t.size.x <= 0.0 or t.size.y <= 0.0:
		t = Rect2(Vector2.ZERO, tex_size)
	var src := Rect2(t.position + region.position * t.size, region.size * t.size)
	src = src.intersection(Rect2(Vector2.ZERO, tex_size))
	if not src.has_area():
		return identity
	var dest := Rect2(Vector2.ZERO, rect_size)
	if cover:
		var want: float = rect_size.x / rect_size.y
		if src.size.x / src.size.y > want:
			var w: float = src.size.y * want
			src.position.x += (src.size.x - w) * 0.5
			src.size.x = w
		else:
			src.size.y = src.size.x / want
	else:
		var avail := rect_size - Vector2.ONE * (2.0 * inset_px)
		var fig: Vector2 = BattlerSlot.fit_figure(src.size, avail.y, avail.x)
		if fig.x <= 0.0 or fig.y <= 0.0:
			return identity
		dest = Rect2(Vector2((rect_size.x - fig.x) * 0.5, rect_size.y - inset_px - fig.y), fig)
	var uv_per_px := Vector2(src.size.x / tex_size.x / dest.size.x,
		src.size.y / tex_size.y / dest.size.y)
	return {
		"crop_uv": Vector4(src.position.x / tex_size.x, src.position.y / tex_size.y,
			src.size.x / tex_size.x, src.size.y / tex_size.y),
		"dest_rect": Vector4(dest.position.x / rect_size.x, dest.position.y / rect_size.y,
			dest.size.x / rect_size.x, dest.size.y / rect_size.y),
		"outline_uv": uv_per_px * BattlerSlot.OUTLINE_PX,
	}


## New character_unify material with the side rim and [param grade]
## (saturation, contrast, brightness) — the same values BattlerSlot uses.
static func build(grade: Vector3, is_party: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _CHAR_SHADER
	mat.set_shader_parameter("rim_color", BattlerSlot.PARTY_RIM_COLOR if is_party else BattlerSlot.ENEMY_RIM_COLOR)
	mat.set_shader_parameter("rim_dir", BattlerSlot.PARTY_RIM_DIR if is_party else BattlerSlot.ENEMY_RIM_DIR)
	mat.set_shader_parameter("rim_directionality", BattlerSlot.RIM_DIRECTIONALITY)
	mat.set_shader_parameter("saturation", grade.x)
	mat.set_shader_parameter("contrast", grade.y)
	mat.set_shader_parameter("brightness", grade.z)
	return mat


## Shows [param tex] in [param rect] through the character shader, trimmed to
## [param region] of the figure. Keeps placement in sync on resize. A null
## texture clears the rect and its material.
static func apply(rect: TextureRect, tex: Texture2D, grade: Vector3, is_party: bool,
		region: Rect2 = FULL_FIGURE, cover: bool = false) -> void:
	if rect == null:
		return
	rect.texture = tex
	if tex == null:
		clear(rect)
		return
	if not rect.has_meta(_STRETCH):
		rect.set_meta(_STRETCH, rect.stretch_mode)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.material = build(grade, is_party)
	rect.set_meta(_META, {"region": region, "cover": cover})
	if not rect.has_meta(_HOOKED):
		rect.set_meta(_HOOKED, true)
		rect.resized.connect(_refresh.bind(rect))
	_refresh(rect)


## Removes the portrait material from [param rect] (e.g. a non-roster speaker)
## and restores the stretch mode it had before [method apply].
static func clear(rect: TextureRect) -> void:
	if rect == null:
		return
	rect.material = null
	if rect.has_meta(_STRETCH):
		rect.stretch_mode = rect.get_meta(_STRETCH)
		rect.remove_meta(_STRETCH)
	if rect.has_meta(_META):
		rect.remove_meta(_META)


static func _refresh(rect: TextureRect) -> void:
	if not is_instance_valid(rect) or not rect.has_meta(_META) or rect.texture == null:
		return
	var mat := rect.material as ShaderMaterial
	if mat == null:
		return
	var spec: Dictionary = rect.get_meta(_META)
	var size: Vector2 = rect.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = rect.custom_minimum_size
	var p: Dictionary = compute_placement(rect.texture.get_size(),
		BattlerSlot.get_trim_rect(rect.texture), size, spec.region, spec.cover)
	mat.set_shader_parameter("crop_uv", p.crop_uv)
	mat.set_shader_parameter("dest_rect", p.dest_rect)
	mat.set_shader_parameter("outline_uv", p.outline_uv)
