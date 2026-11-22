extends PanelContainer
class_name BattlerSlot
## One slot in the arena: shows character sprite, name, HP bar and energy bar
## (each with a short tag and a "current/max" read; colours from BattleFeel).
## Used for both party (left) and enemies (right). Enemies get texture flipped (face left).
## Emits slot_clicked(slot_index, is_party) when the user clicks an alive slot (for targeting).

signal slot_clicked(slot_index: int, is_party: bool)

# Path used if the battle scene didn't pass a texture (fallback load inside this node)
const PLACEHOLDER_PATH := "res://assets/character_placeholder.png"
const _IDLE_SIZE := Vector2(200, 248)  # default sprite box (width x figure + floor margin)
const _ATTACK_DURATION := 0.75            # attack animation duration (seconds)
const _FLY_OFFSET_Y: int = -360            # pixels to move up from normal position when flying
const _HIT_FLASH_COLOR := Color(1.2, 0.6, 0.6, 1.0)  # default flash when no colour is passed
const _HIT_FLASH_IN := 0.12
const _HIT_FLASH_OUT := 0.18
const _TURN_FLASH_COLOR := Color(1.25, 0.45, 0.45, 1.0)
const _TURN_FLASH_IN := 0.14
const _TURN_FLASH_OUT := 0.22

@export var slot_index: int = 0
@export var is_party: bool = true

const _BOSS_SHADER: Shader = preload("res://assets/shaders/boss_aura.gdshader")
## Outline + rim + grade shader on every non-boss battle sprite (art direction §4).
const _CHAR_SHADER: Shader = preload("res://assets/shaders/character_unify.gdshader")

## Visible (trimmed) figure height, 1920x1080 space. Rosters may override per entry.
const FIGURE_HEIGHT: float = 240.0
const BOSS_FIGURE_HEIGHT: float = 320.0
## Feet sit this many px above the bottom of the sprite box (the floor line).
const FLOOR_MARGIN: float = 8.0
## Pixels with alpha below this are padding / remove.bg noise when trimming.
const ALPHA_TRIM_THRESHOLD: float = 0.1
## Outline thickness in screen px (1920x1080 space).
const OUTLINE_PX: float = 2.0
## Rim light colours: party_teal #00D9E6 / enemy_red #FF6B52 at 60%.
const PARTY_RIM_COLOR := Color(0.0, 0.851, 0.902, 0.6)
const ENEMY_RIM_COLOR := Color(1.0, 0.42, 0.322, 0.6)
## Rim light comes from behind-above: party faces right (light from the left),
## enemies face left (light from the right). Screen space, y down.
const PARTY_RIM_DIR := Vector2(-0.6, -0.8)
## 0 = rim on every edge, 1 = only edges facing the rim direction.
const RIM_DIRECTIONALITY: float = 0.85
## Boss aura reach in screen px; converted to source texels per frame.
const BOSS_GLOW_PX: float = 12.0
const ENEMY_RIM_DIR := Vector2(0.6, -0.8)
## The sprite quad overhangs the box so wide attack frames, the outline and the
## boss glow are not clipped: this fraction of the box width on each side, and
## a fixed headroom above.
const _QUAD_SIDE_FRAC: float = 0.5
const _QUAD_TOP_PX: float = 40.0

## Trim rects by texture (resource path or instance id). Computed once per texture.
static var _trim_cache: Dictionary = {}

var _boss_visual: bool = false
var _base_scale: Vector2 = Vector2.ONE   # resting sprite scale (boss > 1)

const _DEFAULT_FEEL: BattleFeel = preload("res://resources/battle_feel_default.tres")
## Boss info plate: dark backing behind name and bars so the enlarged boss
## sprite (and its aura) cannot wash them out.
const _BOSS_PLATE_BG := Color(0.02, 0.03, 0.06, 0.82)
const _BOSS_PLATE_BORDER_ALPHA: float = 0.7

## Bar colours, tags and font size. BattleScene assigns its BattleFeel before
## adding the slot to the tree; standalone slots use the default resource.
var feel: BattleFeel = _DEFAULT_FEEL

@onready var texture_rect: TextureRect = $VBox/SpriteContainer/TextureRect
@onready var info_plate: PanelContainer = $VBox/InfoPlate
@onready var name_label: Label = $VBox/InfoPlate/Info/NameLabel
@onready var role_label: Label = $VBox/InfoPlate/Info/RoleLabel
@onready var flying_label: Label = $VBox/InfoPlate/Info/FlyingLabel
@onready var shielded_label: Label = $VBox/InfoPlate/Info/ShieldedLabel
@onready var guarded_label: Label = $VBox/InfoPlate/Info/GuardedLabel
@onready var hp_tag: Label = $VBox/InfoPlate/Info/HPRow/HPTag
@onready var hp_bar_container: Control = $VBox/InfoPlate/Info/HPRow/HPBarContainer
@onready var hp_bar: ProgressBar = $VBox/InfoPlate/Info/HPRow/HPBarContainer/HPBar
@onready var shield_bar: ProgressBar = $VBox/InfoPlate/Info/HPRow/HPBarContainer/ShieldBar
@onready var hp_value_label: Label = $VBox/InfoPlate/Info/HPRow/HPValue
@onready var energy_tag: Label = $VBox/InfoPlate/Info/EnergyRow/EnergyTag
@onready var energy_bar: ProgressBar = $VBox/InfoPlate/Info/EnergyRow/EnergyBar
@onready var energy_value_label: Label = $VBox/InfoPlate/Info/EnergyRow/EnergyValue
@onready var sprite_container: Control = $VBox/SpriteContainer
@onready var shield_bubble: Control = $VBox/SpriteContainer/ShieldBubble

var _stats: BattlerStats
var _texture_idle: Texture2D
var _attack_frames: Array[Texture2D] = []
var _default_panel_style: StyleBoxFlat  # stored to restore when turning off turn highlight
var _idle_size: Vector2 = _IDLE_SIZE
var _figure_height: float = FIGURE_HEIGHT
var _grade: Vector3 = Vector3(1.0, 1.0, 0.0)  # saturation, contrast, brightness
var _current_tex: Texture2D
var _quad_side: float = 0.0  # current quad overhang (px) left/right of the box
var _is_flying: bool = false
var _downed: bool = false        # set once the death animation has started (BattleFx)
var _flash_tween: Tween
var _hp_fill_style: StyleBoxFlat  # per-slot, recoloured by HP ratio in refresh()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	if sprite_container:
		sprite_container.gui_input.connect(_on_gui_input)
	if texture_rect:
		texture_rect.gui_input.connect(_on_gui_input)
	if hp_bar_container:
		hp_bar_container.gui_input.connect(_on_gui_input)
	if hp_bar:
		hp_bar.gui_input.connect(_on_gui_input)

	# No box: transparent panel, no border (turn highlight adds border only when active)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0)
	panel_style.set_border_width_all(0)
	_default_panel_style = panel_style.duplicate()
	add_theme_stylebox_override("panel", panel_style)
	if name_label:
		name_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95, 1))
	if role_label:
		role_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8, 1))
		role_label.add_theme_font_size_override("font_size", 12)
		role_label.visible = false
	if flying_label:
		flying_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1))
	if shielded_label:
		shielded_label.add_theme_color_override("font_color", Color(0.4, 0.65, 0.95, 1))
	if guarded_label:
		guarded_label.add_theme_color_override("font_color", Color(0.75, 0.9, 0.55, 1))
	if feel == null:
		feel = _DEFAULT_FEEL
	_hp_fill_style = _make_bar_style(true)
	_hp_fill_style.bg_color = feel.hp_color
	if hp_bar:
		hp_bar.add_theme_stylebox_override("background", _make_bar_style(false))
		hp_bar.add_theme_stylebox_override("fill", _hp_fill_style)
	if shield_bar:
		# Transparent background so the HP fill underneath stays visible.
		shield_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		shield_bar.add_theme_stylebox_override("fill", _make_shield_bar_style())
	if energy_bar:
		energy_bar.add_theme_stylebox_override("background", _make_bar_style(false))
		energy_bar.add_theme_stylebox_override("fill", _make_energy_bar_style())
	_style_bar_label(hp_tag, feel.hp_text_color, feel.hp_tag)
	_style_bar_label(hp_value_label, feel.hp_text_color)
	_style_bar_label(energy_tag, feel.energy_text_color, feel.energy_tag)
	_style_bar_label(energy_value_label, feel.energy_text_color)
	_set_info_plate(false, Color.TRANSPARENT)

	# The sprite quad fills the box plus an overhang; the shader trims the
	# texture and draws the figure bottom-aligned on the floor line, so the quad
	# itself never moves when frames change (BattleFx owns its position).
	if texture_rect:
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		# The quad overhangs neighbouring slots: clicks go to the sprite box.
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not texture_rect.resized.is_connected(_update_boss_pivot):
			texture_rect.resized.connect(_update_boss_pivot)
	if sprite_container:
		sprite_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if not sprite_container.resized.is_connected(_update_material):
			sprite_container.resized.connect(_update_material)

# --- Setup with two textures: idle (correct facing) and attack (for animation). ---
# idle_party = face right, idle_enemy = face left (no flip used).
# size_override: if non-zero, its WIDTH sets the sprite box width (e.g. wider
# enemies). Its height is ignored: box height = figure height + FLOOR_MARGIN,
# with figure height read from the roster (HeroRoster / EnemyRoster).
func setup(stats: BattlerStats, texture_idle: Texture2D, texture_attack: Texture2D = null, size_override: Vector2 = Vector2.ZERO) -> void:
	_stats = stats
	_read_visual_data()
	var box_w: float = size_override.x if size_override.x > 0.0 else _IDLE_SIZE.x
	_idle_size = Vector2(box_w, _figure_height + FLOOR_MARGIN)
	var idle: Texture2D = texture_idle
	if idle == null:
		idle = _load_placeholder_here()
	if idle == null:
		idle = _load_placeholder_from_file()
	if idle == null:
		idle = _make_fallback_texture()
	_texture_idle = idle
	_attack_frames.clear()
	if texture_attack != null:
		_attack_frames.append(texture_attack)
	else:
		_attack_frames.append(idle)
	if texture_rect:
		texture_rect.flip_h = false
	_apply_box()
	_apply_material()
	_show_frame(_texture_idle)
	refresh()


## Reads figure height and grade for this slot from the roster data. Party
## slots use HeroRoster[slot_index] (only if the name matches, so ad-hoc
## stats stay neutral); enemy slots use the archetype in stats.enemy_type.
func _read_visual_data() -> void:
	_figure_height = FIGURE_HEIGHT
	_grade = Vector3(1.0, 1.0, 0.0)
	if _stats == null:
		return
	if is_party:
		var hero: Dictionary = HeroRoster.get_hero(slot_index)
		if not hero.is_empty() and str(hero.get("display_name", "")) == _stats.display_name:
			_figure_height = HeroRoster.get_figure_height(slot_index)
			_grade = HeroRoster.get_shader_grade(slot_index)
	elif EnemyRoster.has_type(_stats.enemy_type):
		_figure_height = EnemyRoster.get_figure_height(_stats.enemy_type)
		_grade = EnemyRoster.get_shader_grade(_stats.enemy_type)


## Sizes the sprite box and the overhanging quad from _idle_size.
func _apply_box() -> void:
	if sprite_container:
		sprite_container.custom_minimum_size = _idle_size
	# Bars fill the row (tag + bar + numbers); the row is as wide as the sprite.
	if info_plate:
		info_plate.custom_minimum_size.x = _idle_size.x
	if texture_rect:
		_quad_side = roundf(_idle_size.x * _QUAD_SIDE_FRAC)
		texture_rect.custom_minimum_size = Vector2.ZERO
		texture_rect.offset_left = -_quad_side
		texture_rect.offset_right = _quad_side
		texture_rect.offset_top = -_QUAD_TOP_PX
		texture_rect.offset_bottom = 0.0
	_update_boss_pivot()


## Installs the slot's ShaderMaterial: boss_aura on boss slots, otherwise
## character_unify (outline + side-colour rim + per-sprite grade).
func _apply_material() -> void:
	if not texture_rect:
		return
	var mat := ShaderMaterial.new()
	if _boss_visual:
		mat.shader = _BOSS_SHADER
	else:
		mat.shader = _CHAR_SHADER
		mat.set_shader_parameter("rim_color", PARTY_RIM_COLOR if is_party else ENEMY_RIM_COLOR)
		mat.set_shader_parameter("rim_dir", PARTY_RIM_DIR if is_party else ENEMY_RIM_DIR)
		mat.set_shader_parameter("rim_directionality", RIM_DIRECTIONALITY)
		mat.set_shader_parameter("saturation", _grade.x)
		mat.set_shader_parameter("contrast", _grade.y)
		mat.set_shader_parameter("brightness", _grade.z)
	texture_rect.material = mat
	_update_material()


## Shows [param tex] (idle or attack frame) trimmed and floor-aligned.
func _show_frame(tex: Texture2D) -> void:
	_current_tex = tex
	if texture_rect:
		texture_rect.texture = tex
	_update_material()


## Recomputes the placement uniforms (crop_uv, dest_rect, outline_uv) for the
## current frame from the sprite box size. Called on frame swaps and resizes.
func _update_material() -> void:
	if not texture_rect or _current_tex == null:
		return
	var mat := texture_rect.material as ShaderMaterial
	if mat == null:
		return
	var box: Vector2 = _idle_size
	if sprite_container and sprite_container.is_inside_tree() and sprite_container.size.y > 0.0:
		box = sprite_container.size
	var quad := Vector2(box.x + 2.0 * _quad_side, box.y + _QUAD_TOP_PX)
	var tex_size: Vector2 = _current_tex.get_size()
	var trim: Rect2i = get_trim_rect(_current_tex)
	var fig: Vector2 = fit_figure(Vector2(trim.size), _figure_height, quad.x - 4.0 * OUTLINE_PX)
	var place: Rect2 = place_figure(box, fig, FLOOR_MARGIN)
	place.position += Vector2(_quad_side, _QUAD_TOP_PX)  # box space -> quad space
	mat.set_shader_parameter("crop_uv", Vector4(
		trim.position.x / tex_size.x, trim.position.y / tex_size.y,
		trim.size.x / tex_size.x, trim.size.y / tex_size.y))
	mat.set_shader_parameter("dest_rect", Vector4(
		place.position.x / quad.x, place.position.y / quad.y,
		place.size.x / quad.x, place.size.y / quad.y))
	# Texture UV per screen px = crop size in UV / figure size in px.
	var uv_per_px := Vector2(trim.size.x / tex_size.x / maxf(fig.x, 1.0),
		trim.size.y / tex_size.y / maxf(fig.y, 1.0))
	mat.set_shader_parameter("outline_uv", uv_per_px * OUTLINE_PX)
	if _boss_visual and fig.y > 0.0:
		# glow_width is in source texels: keep the on-screen reach constant.
		mat.set_shader_parameter("glow_width", BOSS_GLOW_PX * float(trim.size.y) / fig.y)


## Display size of a figure whose trimmed texture size is [param trim_size],
## scaled so its height is [param target_height] (keeps aspect), but no wider
## than [param max_width]. Pure function.
static func fit_figure(trim_size: Vector2, target_height: float, max_width: float) -> Vector2:
	if trim_size.x <= 0.0 or trim_size.y <= 0.0 or target_height <= 0.0:
		return Vector2.ZERO
	var s: float = target_height / trim_size.y
	if max_width > 0.0 and trim_size.x * s > max_width:
		s = max_width / trim_size.x
	return trim_size * s


## Rect of a [param figure] sized figure inside a [param box] sized sprite box:
## horizontally centred, feet [param floor_margin] px above the box bottom.
## Pure function.
static func place_figure(box: Vector2, figure: Vector2, floor_margin: float) -> Rect2:
	return Rect2(Vector2((box.x - figure.x) * 0.5, box.y - floor_margin - figure.y), figure)


## Bounding box of the pixels in [param img] with alpha >= [param threshold]
## (padding and faint matte noise are excluded). Images without alpha return
## the full rect; a fully transparent image returns an empty Rect2i. Pure.
static func compute_trim_rect(img: Image, threshold: float = ALPHA_TRIM_THRESHOLD) -> Rect2i:
	if img == null or img.is_empty():
		return Rect2i()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var src: Image = img
	if src.is_compressed():
		src = img.duplicate()
		if src.decompress() != OK:
			return Rect2i(0, 0, w, h)
	if src.detect_alpha() == Image.ALPHA_NONE:
		return Rect2i(0, 0, w, h)
	if src.get_format() != Image.FORMAT_RGBA8:
		src = src.duplicate()
		src.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = src.get_data()
	var cut: int = clampi(ceili(threshold * 255.0), 1, 255)
	var stride: int = w * 4
	# Each scan stops at the first opaque pixel, so cost ~ padding area only.
	var top: int = -1
	for y in h:
		var row: int = y * stride + 3
		for x in w:
			if data[row + x * 4] >= cut:
				top = y
				break
		if top >= 0:
			break
	if top < 0:
		return Rect2i()
	var bottom: int = top
	for y in range(h - 1, top - 1, -1):
		var row: int = y * stride + 3
		var hit := false
		for x in w:
			if data[row + x * 4] >= cut:
				hit = true
				break
		if hit:
			bottom = y
			break
	var left: int = 0
	var found := false
	for x in w:
		for y in range(top, bottom + 1):
			if data[y * stride + x * 4 + 3] >= cut:
				left = x
				found = true
				break
		if found:
			break
	var right: int = left
	found = false
	for x in range(w - 1, left - 1, -1):
		for y in range(top, bottom + 1):
			if data[y * stride + x * 4 + 3] >= cut:
				right = x
				found = true
				break
		if found:
			break
	return Rect2i(left, top, right - left + 1, bottom - top + 1)


## Cached trim rect of [param tex]; the full texture if it cannot be read
## (e.g. the headless dummy renderer) or is fully transparent.
static func get_trim_rect(tex: Texture2D) -> Rect2i:
	if tex == null:
		return Rect2i()
	var key: Variant = tex.resource_path if not tex.resource_path.is_empty() else tex.get_instance_id()
	if _trim_cache.has(key):
		return _trim_cache[key]
	var full := Rect2i(Vector2i.ZERO, Vector2i(tex.get_size()))
	var r: Rect2i = compute_trim_rect(tex.get_image())
	if r.size.x <= 0 or r.size.y <= 0:
		r = full
	_trim_cache[key] = r
	return r


## Visible figure height this slot uses (px, 1920x1080 space).
func get_figure_height() -> float:
	return _figure_height

## Tints the sprite (archetype colour, e.g. the boss's red/amber). Uses
## self_modulate so hit flashes, which tween modulate back to white, keep the tint.
func set_sprite_tint(color: Color) -> void:
	if texture_rect:
		texture_rect.self_modulate = color


## Current archetype tint (white = none).
func get_sprite_tint() -> Color:
	return texture_rect.self_modulate if texture_rect else Color.WHITE


## Boss presentation hook. When [param enabled], swaps the character shader for
## the boss aura ShaderMaterial (pulsing glow in [param aura_color] + red/amber
## grade; it replaces the outline/rim) and grows the figure to the boss height
## (EnemyRoster figure_height, default BOSS_FIGURE_HEIGHT), still standing on
## the floor line. When false, restores the character shader and normal height.
## Hit flash and death fade tween [code]modulate[/code], which both shaders keep.
## Omitted/zero [param aura_color] is read from the archetype (stats.enemy_type).
## [param visual_scale] is legacy: sizing now comes from the figure height, so
## it only scales BOSS_FIGURE_HEIGHT for slots without an archetype.
func set_boss_visual(enabled: bool, aura_color: Color = Color(0.0, 0.0, 0.0, 0.0),
		visual_scale: float = 0.0) -> void:
	_boss_visual = enabled
	if not texture_rect:
		return
	var has_type: bool = _stats != null and EnemyRoster.has_type(_stats.enemy_type)
	if enabled:
		if aura_color.a <= 0.0 and has_type:
			aura_color = EnemyRoster.get_aura_color(_stats.enemy_type)
		if aura_color.a <= 0.0:
			aura_color = Color(1.0, 0.3, 0.08)
		if has_type:
			_figure_height = EnemyRoster.get_figure_height(_stats.enemy_type)
		else:
			_figure_height = BOSS_FIGURE_HEIGHT * (visual_scale / 1.2 if visual_scale > 0.0 else 1.0)
	else:
		_read_visual_data()
	_base_scale = Vector2.ONE
	_idle_size.y = _figure_height + FLOOR_MARGIN
	_apply_box()
	_apply_material()
	if enabled:
		(texture_rect.material as ShaderMaterial).set_shader_parameter("glow_color", aura_color)
	if not _downed:
		texture_rect.scale = _base_scale
	# The boss figure is taller than the others: draw the name/bars on a dark
	# plate so the aura and sprite detail cannot wash them out.
	_set_info_plate(enabled, aura_color)


## Shows or hides the dark backing plate behind the name and bars. Off (normal
## slots) the plate is an empty style, so the layout is the same either way.
func _set_info_plate(on: bool, border_color: Color) -> void:
	if not info_plate:
		return
	info_plate.z_index = 1 if on else 0
	if not on:
		info_plate.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return
	var plate := StyleBoxFlat.new()
	plate.bg_color = _BOSS_PLATE_BG
	plate.border_color = Color(border_color.r, border_color.g, border_color.b, _BOSS_PLATE_BORDER_ALPHA)
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(4)
	plate.content_margin_left = 8.0
	plate.content_margin_right = 8.0
	plate.content_margin_top = 4.0
	plate.content_margin_bottom = 6.0
	info_plate.add_theme_stylebox_override("panel", plate)


## True when the dark info plate is drawn (boss slots).
func has_info_plate() -> bool:
	if not info_plate:
		return false
	return info_plate.get_theme_stylebox("panel") is StyleBoxFlat


## Pivot at the sprite's bottom-centre so attack pops and the death squash
## grow from the feet.
func _update_boss_pivot() -> void:
	if texture_rect:
		texture_rect.pivot_offset = Vector2(texture_rect.size.x * 0.5, texture_rect.size.y)


## True if this slot shows a boss (see set_boss_visual).
func is_boss_visual() -> bool:
	return _boss_visual


func set_attack_frames(frames: Array[Texture2D]) -> void:
	_attack_frames.clear()
	for tex in frames:
		if tex != null:
			_attack_frames.append(tex)
	if _attack_frames.is_empty():
		_attack_frames.append(_texture_idle)

## Plays the attack frames (larger attack sprite) for [param duration] seconds, then
## returns to idle. BattleFx passes a duration already scaled for battle speed.
func play_attack_animation(duration: float = _ATTACK_DURATION) -> void:
	if not texture_rect or not is_inside_tree():
		return
	var frames: Array[Texture2D] = _attack_frames.duplicate()
	if frames.is_empty():
		frames.append(_texture_idle)
	var tween: Tween = create_tween()
	tween.tween_property(texture_rect, "scale", _base_scale * 1.08, duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(texture_rect, "scale", _base_scale, duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var frame_time := duration / float(frames.size())
	for tex in frames:
		if not is_inside_tree():
			return
		_show_frame(tex)
		await get_tree().create_timer(frame_time).timeout
	if not is_inside_tree():
		return
	_show_frame(_texture_idle)

## Tints the sprite to [param color], holds it for [param hold] seconds (the
## hit-stop), then fades back. Restarts a flash already in progress.
func play_hit_flash(color: Color = _HIT_FLASH_COLOR, fade_in: float = _HIT_FLASH_IN,
		hold: float = 0.0, fade_out: float = _HIT_FLASH_OUT) -> void:
	if not texture_rect:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(texture_rect, "modulate", color, fade_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		_flash_tween.tween_interval(hold)
	_flash_tween.tween_property(texture_rect, "modulate", Color.WHITE, fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Red pulse on the whole slot when an enemy's turn starts. [param speed_scale]
## follows the battle speed toggle.
func play_enemy_turn_flash(speed_scale: float = 1.0) -> void:
	var tween: Tween = create_tween()
	tween.set_speed_scale(maxf(0.01, speed_scale))
	tween.tween_property(self, "modulate", _TURN_FLASH_COLOR, _TURN_FLASH_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, _TURN_FLASH_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## The sprite node that BattleFx lunges, flashes and slumps.
func get_sprite() -> Control:
	return texture_rect


## The slot's content root; BattleFx dims it when the battler is downed. (The
## slot itself is not used because BattleScene sets its modulate for targeting.)
func get_body() -> Control:
	return get_node_or_null("VBox") as Control


## True once the death animation has started for this slot.
func is_downed() -> bool:
	return _downed


## Marks the slot as downed so the death animation plays only once.
func mark_downed() -> void:
	_downed = true


func set_role_display(role: String, color: Color = Color(0.65, 0.72, 0.8)) -> void:
	if role_label == null:
		return
	role_label.text = role
	role_label.visible = not role.is_empty()
	role_label.add_theme_color_override("font_color", color)
	if name_label and not role.is_empty():
		name_label.add_theme_color_override("font_color", color.lightened(0.15))


func get_combat_text_position() -> Vector2:
	if sprite_container:
		return sprite_container.global_position + Vector2(_idle_size.x * 0.5, -8.0)
	return global_position + Vector2(100, 0)

# --- Highlight this slot when it's this character's turn (amber outline only, no box). ---
func set_turn_highlight(active: bool) -> void:
	if active:
		var hi = StyleBoxFlat.new()
		hi.bg_color = Color(0, 0, 0, 0)
		hi.border_color = Color(1.0, 0.75, 0.2, 1.0)
		hi.set_border_width_all(2)
		add_theme_stylebox_override("panel", hi)
	else:
		if _default_panel_style != null:
			add_theme_stylebox_override("panel", _default_panel_style)

func _make_bar_style(fill: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.set_corner_radius_all(2)
	if fill:
		s.bg_color = Color(0.0, 0.9, 1.0, 0.8)
	else:
		s.bg_color = Color(0.06, 0.07, 0.1, 1)
	return s

func _make_shield_bar_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.set_corner_radius_all(2)
	s.bg_color = Color(0.4, 0.65, 0.95, 0.9)  # azul mais claro
	return s

func _make_energy_bar_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.set_corner_radius_all(2)
	s.bg_color = feel.energy_color if feel else Color(1.0, 0.84, 0.22, 0.92)
	return s


## Small tag / number label next to a bar ([param text] empty = keep current).
func _style_bar_label(label: Label, color: Color, text: String = "") -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", feel.bar_text_font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not text.is_empty():
		label.text = text

# --- 1) Godot's resource loader (uses imported .ctex). Can fail if import is missing or path wrong. ---
func _load_placeholder_here() -> Texture2D:
	var r = ResourceLoader.load(PLACEHOLDER_PATH, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	return r as Texture2D

# --- 2) Read the PNG file as raw bytes and decode with Image.load_png_from_buffer(). ---
#    Bypasses Godot's import; often works when load() doesn't (e.g. export, different project path).
func _load_placeholder_from_file() -> Texture2D:
	var file = FileAccess.open(PLACEHOLDER_PATH, FileAccess.READ)
	if file == null:
		return null
	var bytes = file.get_buffer(file.get_length())
	file.close()
	var img = Image.new()
	var err = img.load_png_from_buffer(bytes)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)

# --- 3) If no image loads, show a 64x64 checker pattern so the slot is never empty ---
func _make_fallback_texture() -> Texture2D:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.12, 0.18, 1))
	for y in 8:
		for x in 8:
			if (x + y) % 2 == 0:
				img.fill_rect(Rect2i(x * 8, y * 8, 8, 8), Color(0.0, 0.85, 1.0, 0.5))
	return ImageTexture.create_from_image(img)

# --- Update name, flying, shielded, HP/shield bars, and bubble from _stats. ---
# A dead battler stays in its slot (BattleFx dims and slumps it) but loses its
# bars and status labels, so it is clear the slot is down.
func refresh() -> void:
	if _stats == null:
		return
	var alive := _stats.is_alive()
	if name_label:
		name_label.text = _stats.display_name
	set_flying(_stats.is_flying and alive)
	var has_shield := alive and (_stats.shield_amount > 0 or _stats.shield_rounds_left > 0)
	if shielded_label:
		shielded_label.visible = has_shield
	if guarded_label:
		guarded_label.visible = alive and _stats.guard_active
	if shield_bubble:
		shield_bubble.visible = has_shield
		if shield_bubble.visible:
			shield_bubble.queue_redraw()
	if hp_bar and shield_bar:
		hp_bar.max_value = float(_stats.max_hp)
		hp_bar.value = float(_stats.current_hp)
		hp_bar.visible = alive
		if _hp_fill_style and feel:
			_hp_fill_style.bg_color = feel.get_hp_color(_stats.current_hp, _stats.max_hp)
		if has_shield and _stats.shield_amount > 0:
			# Barra do escudo: mesma escala (max_hp), valor = shield_amount → ocupa o tamanho exato do escudo a partir da esquerda
			shield_bar.max_value = float(_stats.max_hp)
			shield_bar.value = float(_stats.shield_amount)
			shield_bar.visible = true
		else:
			shield_bar.visible = false
	if hp_value_label:
		hp_value_label.text = BattleFeel.format_bar_value(_stats.current_hp, _stats.max_hp)
		hp_value_label.visible = alive
	if hp_tag:
		hp_tag.visible = alive
	if energy_bar:
		energy_bar.max_value = float(_stats.max_energy)
		energy_bar.value = float(_stats.current_energy)
		energy_bar.visible = alive
	if energy_value_label:
		energy_value_label.text = BattleFeel.format_bar_value(_stats.current_energy, _stats.max_energy)
		energy_value_label.visible = alive
	if energy_tag:
		energy_tag.visible = alive

func set_flying(flying: bool) -> void:
	_is_flying = flying
	if flying_label:
		flying_label.visible = flying
	if sprite_container:
		sprite_container.position.y = -_FLY_OFFSET_Y if flying else 0.0

func get_stats() -> BattlerStats:
	return _stats

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _stats and _stats.is_alive():
				slot_clicked.emit(slot_index, is_party)
