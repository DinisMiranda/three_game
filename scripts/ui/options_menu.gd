extends CanvasLayer
## Pause/options overlay: volume slider, Back to Main Menu, Quit. Toggle with ESC; ESC or Close hides.

const _COLOR_PANEL := Color(0.08, 0.09, 0.12, 0.95)
const _COLOR_BORDER := Color(0.0, 0.85, 1.0, 0.6)
const _COLOR_TEXT := Color(0.9, 0.92, 0.95, 1)
const MASTER_BUS_IDX := 0
const VOLUME_MIN_DB := -40.0  # 0% slider
const VOLUME_MAX_DB := 0.0    # 100% slider

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Center/Panel
@onready var volume_slider: HSlider = $Center/Panel/VBox/VolumeRow/VolumeSlider
@onready var volume_label: Label = $Center/Panel/VBox/VolumeRow/VolumePercent
@onready var back_btn: Button = $Center/Panel/VBox/BackBtn
@onready var quit_btn: Button = $Center/Panel/VBox/QuitBtn
@onready var close_btn: Button = $Center/Panel/VBox/CloseBtn
@onready var title_label: Label = $Center/Panel/VBox/Title

func _ready() -> void:
	visible = false
	_process_viewport_size()
	volume_slider.value = _db_to_percent(AudioServer.get_bus_volume_db(MASTER_BUS_IDX))
	_update_volume_label(int(volume_slider.value))
	volume_slider.value_changed.connect(_on_volume_changed)
	back_btn.pressed.connect(_on_back_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	_apply_theme()

func _process_viewport_size() -> void:
	var vp = get_viewport().get_visible_rect().size
	overlay.set_size(vp)
	overlay.set_position(Vector2.ZERO)
	$Center.set_size(vp)
	$Center.set_position(Vector2.ZERO)

func _apply_theme() -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = _COLOR_PANEL
	s.border_color = _COLOR_BORDER
	s.set_border_width_all(2)
	s.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", s)
	title_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 1))
	title_label.add_theme_font_size_override("font_size", 28)
	$Center/Panel/VBox/VolumeRow/VolumeLabel.add_theme_color_override("font_color", _COLOR_TEXT)
	volume_label.add_theme_color_override("font_color", _COLOR_TEXT)
	back_btn.add_theme_color_override("font_color", _COLOR_TEXT)
	quit_btn.add_theme_color_override("font_color", _COLOR_TEXT)
	close_btn.add_theme_color_override("font_color", _COLOR_TEXT)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.14, 0.18, 1)
	btn_style.border_color = _COLOR_BORDER
	btn_style.set_border_width_all(1)
	btn_style.set_content_margin_all(10)
	for btn in [back_btn, quit_btn, close_btn]:
		btn.add_theme_stylebox_override("normal", btn_style)

func _db_to_percent(db: float) -> float:
	if db <= VOLUME_MIN_DB:
		return 0.0
	if db >= VOLUME_MAX_DB:
		return 100.0
	return (db - VOLUME_MIN_DB) / (VOLUME_MAX_DB - VOLUME_MIN_DB) * 100.0

func _percent_to_db(p: float) -> float:
	if p <= 0.0:
		return VOLUME_MIN_DB
	return VOLUME_MIN_DB + (VOLUME_MAX_DB - VOLUME_MIN_DB) * (p / 100.0)

func _update_volume_label(percent: int) -> void:
	volume_label.text = str(percent) + "%"

func _on_volume_changed(value: float) -> void:
	var db = _percent_to_db(value)
	AudioServer.set_bus_volume_db(MASTER_BUS_IDX, db)
	_update_volume_label(int(value))

func _on_back_pressed() -> void:
	hide()
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_close_pressed() -> void:
	hide()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()

func show_menu() -> void:
	_process_viewport_size()
	visible = true
