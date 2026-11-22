class_name TurnOrderBar
extends HBoxContainer
## Row of compact turn-order chips: portrait, short name and a side-coloured
## underline per battler, with the active battler's chip highlighted and larger.
##
## BattleScene only feeds data through [method set_order]; this node owns every
## chip node, style and animation. Chips are keyed so they persist between
## updates: a battler that drops out of the order (downed) fades and shrinks
## away instead of the whole row being rebuilt (Phase 1D, portfolio plan).
##
## Entry format for [method set_order]:
## [code]{ "key": String, "name": String, "is_party": bool, "texture": Texture2D }[/code]
## where [code]key[/code] is unique and stable per battler (e.g. "P0", "E1").

## Fallback removal length when no [BattleFeel] is assigned.
const _FALLBACK_REMOVE_DURATION := 0.3

## Durations for the remove / activate animations come from here.
@export var feel: BattleFeel

@export_group("Colours")
## Underline and border tint of party chips (teal, matches the battle accent).
@export var party_color: Color = Palette.PARTY_TEAL
## Underline and border tint of enemy chips (red-amber).
@export var enemy_color: Color = Palette.ENEMY_RED
## Border and name colour of the active battler's chip.
@export var active_color: Color = Palette.SELECT_AMBER
## Chip background.
@export var chip_bg_color: Color = Palette.PANEL_FILL
## Chip background while active.
@export var active_bg_color: Color = Palette.BG_DEEP
## Name colour of inactive chips.
@export var text_color: Color = Palette.TEXT_PRIMARY
## Alpha of the side-coloured border on inactive chips.
@export_range(0.0, 1.0, 0.05) var inactive_border_alpha: float = 0.45

@export_group("Sizes")
## Portrait edge (px) of inactive chips.
@export_range(8.0, 128.0, 1.0) var portrait_size: float = 44.0
## Portrait edge (px) of the active chip.
@export_range(8.0, 128.0, 1.0) var active_portrait_size: float = 60.0
## Name font size of inactive chips.
@export_range(8, 48, 1) var font_size: int = 16
## Name font size of the active chip.
@export_range(8, 48, 1) var active_font_size: int = 21
## Names longer than this are cut and end with an ellipsis.
@export_range(3, 40, 1) var max_name_chars: int = 18
## Height (px) of the side-coloured underline.
@export_range(0, 12, 1) var underline_px: int = 3
## Normalised region of the battler sprite used as the portrait (head and
## shoulders of a full-body sprite). Rect2(0, 0, 1, 1) uses the whole sprite.
@export var portrait_crop: Rect2 = Rect2(0.2, 0.02, 0.6, 0.42)

## Presentation speed (BattleFx speed multiplier); animation lengths are divided by it.
var speed_multiplier: float = 1.0

var _chips: Dictionary = {}  # key -> _Chip (live chips only)
var _dying: Array[Control] = []
var _active_key: String = ""
var _portrait_cache: Dictionary = {}  # Texture2D -> AtlasTexture


## One turn-order chip. Built in code so the component has no scene dependency.
class _Chip extends PanelContainer:
	var key: String = ""
	var is_party: bool = true
	var is_active: bool = false
	var side_color: Color = Color.WHITE
	var portrait: TextureRect
	var name_label: Label
	var underline: ColorRect

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vbox)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(row)
		portrait = TextureRect.new()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(portrait)
		name_label = Label.new()
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)
		underline = ColorRect.new()
		underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(underline)


func _init() -> void:
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_BEGIN


## Shortens [param display_name] to at most [param max_chars] characters,
## ending with an ellipsis when cut.
static func shorten_name(display_name: String, max_chars: int) -> String:
	var clean := display_name.strip_edges()
	if max_chars < 2 or clean.length() <= max_chars:
		return clean
	return clean.substr(0, max_chars - 1).strip_edges() + "…"


## Pure view model: one spec per entry, in order. Each spec is
## [code]{ key, name, is_party, is_active, side_color, texture }[/code].
## Entries without a key are skipped; the first entry matching
## [param active_key] is the only active one.
func build_chip_specs(entries: Array, active_key: String) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var seen: Dictionary = {}
	for e in entries:
		if not (e is Dictionary):
			continue
		var key: String = str(e.get("key", ""))
		if key.is_empty() or seen.has(key):
			continue
		seen[key] = true
		var is_party: bool = bool(e.get("is_party", true))
		specs.append({
			"key": key,
			"name": shorten_name(str(e.get("name", key)), max_name_chars),
			"is_party": is_party,
			"is_active": key == active_key and not active_key.is_empty(),
			"side_color": get_side_color(is_party),
			"texture": e.get("texture", null),
		})
	return specs


## Returns the side accent colour for a party ([code]true[/code]) or enemy chip.
func get_side_color(is_party: bool) -> Color:
	return party_color if is_party else enemy_color


## Updates the bar to [param entries] (see class doc) with [param active_key]
## highlighted. Chips whose key is no longer present animate out.
func set_order(entries: Array, active_key: String) -> void:
	var specs := build_chip_specs(entries, active_key)
	_active_key = ""
	var live_keys: Dictionary = {}
	for spec in specs:
		live_keys[spec.key] = true
		if spec.is_active:
			_active_key = spec.key
	for key in _chips.keys():
		if not live_keys.has(key):
			_remove_chip(key)
	var ordered: Array[Control] = []
	for spec in specs:
		var chip: _Chip = _chips.get(spec.key, null)
		if chip == null:
			chip = _Chip.new()
			chip.key = spec.key
			chip.name = "Chip_%s" % spec.key
			add_child(chip)
			_chips[spec.key] = chip
		var became_active: bool = spec.is_active and not chip.is_active
		_apply_spec(chip, spec)
		if became_active:
			_play_activate(chip)
		ordered.append(chip)
	_reorder(ordered)


## Number of live (not animating out) chips.
func get_chip_count() -> int:
	return _chips.size()


## Keys of the live chips in display order.
func get_chip_keys() -> Array[String]:
	var keys: Array[String] = []
	for c in get_children():
		if c is _Chip and _chips.get(c.key, null) == c:
			keys.append(c.key)
	return keys


## Key of the highlighted chip, or "" when none is active.
func get_active_key() -> String:
	return _active_key


## Whether the chip for [param key] is the highlighted one.
func is_chip_active(key: String) -> bool:
	var chip: _Chip = _chips.get(key, null)
	return chip != null and chip.is_active


## Side colour applied to the chip for [param key] (transparent if missing).
func get_chip_side_color(key: String) -> Color:
	var chip: _Chip = _chips.get(key, null)
	return chip.side_color if chip != null else Color.TRANSPARENT


## Displayed (shortened) name of the chip for [param key].
func get_chip_name(key: String) -> String:
	var chip: _Chip = _chips.get(key, null)
	return chip.name_label.text if chip != null else ""


## Number of chips currently animating out.
func get_dying_count() -> int:
	var n := 0
	for c in _dying:
		if is_instance_valid(c):
			n += 1
	return n


func _apply_spec(chip: _Chip, spec: Dictionary) -> void:
	chip.is_party = spec.is_party
	chip.is_active = spec.is_active
	chip.side_color = spec.side_color
	var edge: float = active_portrait_size if chip.is_active else portrait_size
	var tex: Texture2D = spec.texture as Texture2D
	chip.portrait.texture = _get_portrait(tex)
	chip.portrait.visible = tex != null
	chip.portrait.custom_minimum_size = Vector2(edge, edge)
	chip.name_label.text = spec.name
	chip.name_label.add_theme_font_size_override("font_size", active_font_size if chip.is_active else font_size)
	chip.name_label.add_theme_color_override("font_color", active_color if chip.is_active else text_color)
	chip.underline.color = chip.side_color
	chip.underline.custom_minimum_size = Vector2(0.0, float(underline_px))
	chip.underline.visible = underline_px > 0
	var style := StyleBoxFlat.new()
	style.bg_color = active_bg_color.lerp(active_color, 0.12) if chip.is_active else chip_bg_color
	if chip.is_active:
		style.border_color = active_color
		style.set_border_width_all(2)
	else:
		var c := chip.side_color
		style.border_color = Color(c.r, c.g, c.b, c.a * inactive_border_alpha)
		style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 3.0
	chip.add_theme_stylebox_override("panel", style)
	chip.tooltip_text = str(spec.name)


## Crops [param tex] to [member portrait_crop]; cached per texture.
func _get_portrait(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _portrait_cache.has(tex):
		return _portrait_cache[tex]
	var tex_size := tex.get_size()
	var region := Rect2(
		portrait_crop.position * tex_size,
		portrait_crop.size * tex_size
	).intersection(Rect2(Vector2.ZERO, tex_size))
	var result: Texture2D = tex
	if region.has_area():
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = region
		result = atlas
	_portrait_cache[tex] = result
	return result


func _remove_chip(key: String) -> void:
	var chip: _Chip = _chips.get(key, null)
	_chips.erase(key)
	if chip == null:
		return
	var duration := _scaled(feel.turn_chip_remove_duration if feel else _FALLBACK_REMOVE_DURATION)
	if duration <= 0.0 or not is_inside_tree():
		remove_child(chip)
		chip.queue_free()
		return
	_dying.append(chip)
	chip.pivot_offset = chip.size * 0.5
	var end_scale: float = feel.turn_chip_remove_scale if feel else 0.5
	var tw := chip.create_tween().set_parallel(true)
	tw.tween_property(chip, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(chip, "scale", Vector2(end_scale, end_scale), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		_dying.erase(chip)
		chip.queue_free())


func _play_activate(chip: _Chip) -> void:
	if not is_inside_tree() or feel == null:
		return
	var duration := _scaled(feel.turn_chip_activate_duration)
	if duration <= 0.0:
		return
	# Size is only known after layout; pop around the centre once it is.
	await get_tree().process_frame
	if not is_instance_valid(chip) or not chip.is_active:
		return
	chip.pivot_offset = chip.size * 0.5
	chip.scale = Vector2(feel.turn_chip_activate_from_scale, feel.turn_chip_activate_from_scale)
	var tw := chip.create_tween()
	tw.tween_property(chip, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Orders children as [param live], keeping dying chips near their old slot so
## the fade plays in place.
func _reorder(live: Array[Control]) -> void:
	var final: Array[Control] = live.duplicate()
	var old_children := get_children()
	for i in old_children.size():
		var c: Node = old_children[i]
		if c is Control and _dying.has(c):
			final.insert(mini(i, final.size()), c as Control)
	for i in final.size():
		if final[i].get_parent() == self:
			move_child(final[i], i)


func _scaled(duration: float) -> float:
	return duration / maxf(speed_multiplier, 0.01)
