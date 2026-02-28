extends PanelContainer
class_name BattlerSlot
## One slot in the arena: shows character sprite, name, HP bar.
## Used for both party (left) and enemies (right). Enemies get texture flipped (face left).
## Emits slot_clicked(slot_index, is_party) when the user clicks an alive slot (for targeting).

signal slot_clicked(slot_index: int, is_party: bool)

# Path used if the battle scene didn't pass a texture (fallback load inside this node)
const PLACEHOLDER_PATH := "res://assets/character_placeholder.png"

@export var slot_index: int = 0
@export var is_party: bool = true

@onready var texture_rect: TextureRect = $HBox/TextureRect
@onready var info: VBoxContainer = $HBox/Info
@onready var name_label: Label = $HBox/Info/NameLabel
@onready var hp_bar: ProgressBar = $HBox/Info/HPBar

var _stats: BattlerStats

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

	# Sci-fi panel: dark background, thin cyan border
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	panel_style.border_color = Color(0.0, 0.85, 1.0, 0.5)
	panel_style.set_border_width_all(1)
	add_theme_stylebox_override("panel", panel_style)
	if name_label:
		name_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95, 1))
	if hp_bar:
		hp_bar.add_theme_stylebox_override("background", _make_bar_style(false))
		hp_bar.add_theme_stylebox_override("fill", _make_bar_style(true))

	# So the texture always has space and keeps aspect ratio
	if texture_rect:
		texture_rect.custom_minimum_size = Vector2(80, 100)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

# --- Called by battle_scene after instantiating the slot. Sets stats and texture. ---
# We try several ways to get a texture so the sprite shows even when Godot's normal load fails.
func setup(stats: BattlerStats, texture: Texture2D) -> void:
	_stats = stats
	var tex: Texture2D = texture
	if tex == null:
		tex = _load_placeholder_here()
	if tex == null:
		tex = _load_placeholder_from_file()
	if tex == null:
		tex = _make_fallback_texture()
	if texture_rect:
		texture_rect.texture = tex
		texture_rect.flip_h = not is_party  # enemies face left
		# Force a visible area; some setups need this for the texture to draw
		texture_rect.custom_minimum_size = Vector2(80, 100)
		texture_rect.size = Vector2(80, 100)
	refresh()

func _make_bar_style(fill: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.set_corner_radius_all(2)
	if fill:
		s.bg_color = Color(0.0, 0.9, 1.0, 0.8)
	else:
		s.bg_color = Color(0.06, 0.07, 0.1, 1)
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

# --- Update name and HP bar from _stats; dim if dead ---
func refresh() -> void:
	if _stats == null:
		return
	if name_label:
		name_label.text = _stats.display_name
	if hp_bar:
		hp_bar.max_value = float(_stats.max_hp)
		hp_bar.value = float(_stats.current_hp)
		hp_bar.visible = _stats.is_alive()
	modulate.a = 1.0 if _stats.is_alive() else 0.45

func get_stats() -> BattlerStats:
	return _stats

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _stats and _stats.is_alive():
				slot_clicked.emit(slot_index, is_party)
