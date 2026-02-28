extends PanelContainer
class_name BattlerSlot
## One slot in the arena: shows character sprite (placeholder), name, HP bar.
## Used for both party (left) and enemies (right). Enemies get sprite flipped.

signal slot_clicked(slot_index: int, is_party: bool)

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

func setup(stats: BattlerStats, texture: Texture2D) -> void:
	_stats = stats
	if texture_rect and texture:
		texture_rect.texture = texture
		texture_rect.flip_h = not is_party  # Enemies face left
	refresh()

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
