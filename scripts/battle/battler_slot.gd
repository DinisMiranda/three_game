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

@export var slot_index: int = 0
@export var is_party: bool = true

@onready var texture_rect: TextureRect = $VBox/SpriteContainer/TextureRect
@onready var name_label: Label = $VBox/NameLabel
@onready var flying_label: Label = $VBox/FlyingLabel
@onready var shielded_label: Label = $VBox/ShieldedLabel
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
var _base_position_y: float = 0.0         # Y from container when not flying

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
	if flying_label:
		flying_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1))
	if shielded_label:
		shielded_label.add_theme_color_override("font_color", Color(0.4, 0.65, 0.95, 1))
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

func set_attack_frames(frames: Array[Texture2D]) -> void:
	_attack_frames.clear()
	for tex in frames:
		if tex != null:
			_attack_frames.append(tex)
	if _attack_frames.is_empty():
		_attack_frames.append(_texture_idle)

# --- Play attack animation: show larger attack sprite, wait, then back to idle. ---
func play_attack_animation() -> void:
	if not texture_rect:
		return
	var frames: Array[Texture2D] = _attack_frames.duplicate()
	if frames.is_empty():
		frames.append(_texture_idle)
	var tween: Tween = create_tween()
	tween.tween_property(texture_rect, "scale", Vector2(1.08, 1.08), _ATTACK_DURATION * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(texture_rect, "scale", Vector2.ONE, _ATTACK_DURATION * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var frame_time := _ATTACK_DURATION / float(frames.size())
	for tex in frames:
		texture_rect.texture = tex
		texture_rect.custom_minimum_size = _attack_size
		await get_tree().create_timer(frame_time).timeout
	texture_rect.texture = _texture_idle
	texture_rect.custom_minimum_size = _idle_size

func play_hit_flash() -> void:
	if not texture_rect:
		return
	var tween: Tween = create_tween()
	tween.tween_property(texture_rect, "modulate", Color(1.2, 0.6, 0.6, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(texture_rect, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

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

# --- Update name, flying, shielded, HP/shield bars, and bubble from _stats; hide slot when dead ---
func refresh() -> void:
	if _stats == null:
		return
	if name_label:
		name_label.text = _stats.display_name
	set_flying(_stats.is_flying)
	var has_shield := _stats.shield_amount > 0 or _stats.shield_rounds_left > 0
	if shielded_label:
		shielded_label.visible = has_shield
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
	visible = _stats.is_alive()

func set_flying(flying: bool) -> void:
	_is_flying = flying
	if flying_label:
		flying_label.visible = flying
	if not flying and get_parent() is Container:
		get_parent().queue_sort()

func _process(_delta: float) -> void:
	if _is_flying:
		position.y = _base_position_y + _FLY_OFFSET_Y
	else:
		_base_position_y = position.y

func get_stats() -> BattlerStats:
	return _stats

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _stats and _stats.is_alive():
				slot_clicked.emit(slot_index, is_party)
