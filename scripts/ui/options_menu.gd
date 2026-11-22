extends CanvasLayer
## Pause/options overlay: volume slider, Back to Main Menu, Quit. Toggle with ESC; ESC or Close hides.

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

## Panel, buttons, slider and labels are styled by the Theme set on Center
## (a CanvasLayer does not pass a theme down, so the scene sets it there).
func _apply_theme() -> void:
	title_label.add_theme_color_override("font_color", Palette.ACCENT_CYAN)
	volume_label.theme_type_variation = &"MonoLabel"
	volume_label.add_theme_font_size_override("font_size", TriadThemeBuilder.SIZE_BODY)

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
	SceneFader.change_scene("res://scenes/main_menu/main_menu.tscn")

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
	close_btn.grab_focus()
