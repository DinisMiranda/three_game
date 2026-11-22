extends PanelContainer
class_name BattlerSlot
## One slot in the arena: shows character sprite, name, HP bar.
## Used for both party (left) and enemies (right). Enemies get texture flipped (face left).
## Emits slot_clicked(slot_index, is_party) when the user clicks an alive slot (for targeting).

signal slot_clicked(slot_index: int, is_party: bool)

# Path used if the battle scene didn't pass a texture (fallback load inside this node)
const PLACEHOLDER_PATH := "res://assets/character_placeholder.png"
const _IDLE_SIZE := Vector2(200, 260)
const _ATTACK_SIZE := Vector2(240, 312)   # slightly larger during attack animation
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
## Fraction of the quad the sprite fills under the aura shader (rest = glow margin).
const _BOSS_CONTENT_SCALE: float = 0.84

var _boss_visual: bool = false
var _base_scale: Vector2 = Vector2.ONE   # resting sprite scale (boss > 1)

@onready var texture_rect: TextureRect = $VBox/SpriteContainer/TextureRect
@onready var name_label: Label = $VBox/NameLabel
@onready var role_label: Label = $VBox/RoleLabel
@onready var flying_label: Label = $VBox/FlyingLabel
@onready var shielded_label: Label = $VBox/ShieldedLabel
@onready var guarded_label: Label = $VBox/GuardedLabel
@onready var hp_bar_container: Control = $VBox/HPBarContainer
@onready var hp_bar: ProgressBar = $VBox/HPBarContainer/HPBar
@onready var shield_bar: ProgressBar = $VBox/HPBarContainer/ShieldBar
@onready var energy_bar: ProgressBar = $VBox/EnergyBar
@onready var sprite_container: Control = $VBox/SpriteContainer
@onready var shield_bubble: Control = $VBox/SpriteContainer/ShieldBubble

var _stats: BattlerStats
var _texture_idle: Texture2D
var _attack_frames: Array[Texture2D] = []
var _default_panel_style: StyleBoxFlat  # stored to restore when turning off turn highlight
var _idle_size: Vector2 = _IDLE_SIZE
var _attack_size: Vector2 = _ATTACK_SIZE
var _is_flying: bool = false
var _downed: bool = false        # set once the death animation has started (BattleFx)
var _flash_tween: Tween

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
	if hp_bar:
		hp_bar.add_theme_stylebox_override("background", _make_bar_style(false))
		hp_bar.add_theme_stylebox_override("fill", _make_bar_style(true))
	if shield_bar:
		shield_bar.add_theme_stylebox_override("background", _make_bar_style(false))
		shield_bar.add_theme_stylebox_override("fill", _make_shield_bar_style())

	# Space for the sprite; keep aspect ratio. Size updated in setup() to match.
	if texture_rect:
		texture_rect.custom_minimum_size = _IDLE_SIZE
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

# --- Setup with two textures: idle (correct facing) and attack (for animation). ---
# idle_party = face right, idle_enemy = face left (no flip used).
# size_override: if non-zero, use this for sprite size (e.g. larger enemies).
func setup(stats: BattlerStats, texture_idle: Texture2D, texture_attack: Texture2D = null, size_override: Vector2 = Vector2.ZERO) -> void:
	_stats = stats
	if size_override != Vector2.ZERO:
		_idle_size = size_override
		_attack_size = Vector2(size_override.x * 1.2, size_override.y * 1.2)
	else:
		_idle_size = _IDLE_SIZE
		_attack_size = _ATTACK_SIZE
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
		texture_rect.texture = _texture_idle
		texture_rect.flip_h = false
		texture_rect.custom_minimum_size = _idle_size
	if sprite_container:
		sprite_container.custom_minimum_size = _idle_size
	if hp_bar_container:
		hp_bar_container.custom_minimum_size.x = _idle_size.x
	if hp_bar:
		hp_bar.custom_minimum_size.x = _idle_size.x
	if shield_bar:
		shield_bar.custom_minimum_size.x = _idle_size.x
	if energy_bar:
		energy_bar.custom_minimum_size.x = _idle_size.x
	refresh()

## Tints the sprite (archetype colour, e.g. the boss's red/amber). Uses
## self_modulate so hit flashes, which tween modulate back to white, keep the tint.
func set_sprite_tint(color: Color) -> void:
	if texture_rect:
		texture_rect.self_modulate = color


## Current archetype tint (white = none).
func get_sprite_tint() -> Color:
	return texture_rect.self_modulate if texture_rect else Color.WHITE


## Boss presentation hook. When [param enabled], applies the boss aura
## ShaderMaterial (pulsing glow in [param aura_color] + red/amber grade) to the
## sprite and enlarges the sprite by [param visual_scale] about its bottom-centre
## (feet), growing upward into empty space so the name/HP bar are not covered.
## When false, removes the material and restores scale. Hit flash and death fade
## tween [code]modulate[/code], which the material respects (COLOR is modulated).
## Omitted/zero [param aura_color] and [param visual_scale] are read from the
## slot's archetype (EnemyRoster aura_color / sprite_scale) via stats.enemy_type.
func set_boss_visual(enabled: bool, aura_color: Color = Color(0.0, 0.0, 0.0, 0.0),
		visual_scale: float = 0.0) -> void:
	_boss_visual = enabled
	if not texture_rect:
		return
	if enabled:
		if _stats != null and not _stats.enemy_type.is_empty():
			if aura_color.a <= 0.0:
				aura_color = EnemyRoster.get_aura_color(_stats.enemy_type)
			if visual_scale <= 0.0:
				visual_scale = EnemyRoster.get_sprite_scale(_stats.enemy_type)
		if aura_color.a <= 0.0:
			aura_color = Color(1.0, 0.3, 0.08)
		if visual_scale <= 0.0:
			visual_scale = 1.0
		var mat := ShaderMaterial.new()
		mat.shader = _BOSS_SHADER
		mat.set_shader_parameter("glow_color", aura_color)
		mat.set_shader_parameter("content_scale", _BOSS_CONTENT_SCALE)
		texture_rect.material = mat
		# Compensate the shader's shrink so the mech keeps its size, then apply
		# the boss scale.
		var s: float = maxf(visual_scale, 0.1) / _BOSS_CONTENT_SCALE
		_base_scale = Vector2(s, s)
		if not texture_rect.resized.is_connected(_update_boss_pivot):
			texture_rect.resized.connect(_update_boss_pivot)
		_update_boss_pivot()
	else:
		texture_rect.material = null
		_base_scale = Vector2.ONE
		if texture_rect.resized.is_connected(_update_boss_pivot):
			texture_rect.resized.disconnect(_update_boss_pivot)
	if not _downed:
		texture_rect.scale = _base_scale
	# The enlarged sprite grows up over the name/HP bar rows; draw those above it.
	var overlay_z: int = 1 if enabled else 0
	for n: Control in [name_label, role_label, hp_bar_container, energy_bar,
			flying_label, shielded_label, guarded_label]:
		if n:
			n.z_index = overlay_z


## Pivot at the sprite's bottom-centre so boss scaling grows upward from the feet.
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
		texture_rect.texture = tex
		texture_rect.custom_minimum_size = _attack_size
		await get_tree().create_timer(frame_time).timeout
	if not is_inside_tree():
		return
	texture_rect.texture = _texture_idle
	texture_rect.custom_minimum_size = _idle_size

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
	s.bg_color = Color(0.95, 0.75, 0.2, 0.9)
	return s

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
		hp_bar.visible = _stats.is_alive()
		if has_shield and _stats.shield_amount > 0:
			# Barra do escudo: mesma escala (max_hp), valor = shield_amount → ocupa o tamanho exato do escudo a partir da esquerda
			shield_bar.max_value = float(_stats.max_hp)
			shield_bar.value = float(_stats.shield_amount)
			shield_bar.visible = true
		else:
			shield_bar.visible = false
	if energy_bar:
		energy_bar.max_value = float(_stats.max_energy)
		energy_bar.value = float(_stats.current_energy)
		energy_bar.visible = _stats.is_alive()

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
