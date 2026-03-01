extends Control
## Main menu: title and Start Battle button. Sci-fi style to match the battle screen.

const OptionsMenuScene = preload("res://scenes/ui/options_menu.tscn")

const _COLOR_PANEL := Color(0.08, 0.09, 0.12, 0.95)
const _COLOR_BORDER := Color(0.0, 0.85, 1.0, 0.6)
const _COLOR_TEXT := Color(0.9, 0.92, 0.95, 1)
const _COLOR_ACCENT := Color(0.0, 0.9, 1.0, 1)

@onready var title_label: Label = $Margin/VBox/Title
@onready var start_btn: Button = $Margin/VBox/StartBtn

var _options_menu: CanvasLayer

func _ready() -> void:
	_options_menu = OptionsMenuScene.instantiate()
	add_child(_options_menu)
	start_btn.pressed.connect(_on_start_pressed)
	_apply_theme()
	MusicPlayer.play_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _options_menu.visible:
		_options_menu.show_menu()
		get_viewport().set_input_as_handled()

func _apply_theme() -> void:
	title_label.add_theme_color_override("font_color", _COLOR_ACCENT)
	title_label.add_theme_font_size_override("font_size", 48)
	start_btn.add_theme_color_override("font_color", _COLOR_TEXT)
	start_btn.add_theme_stylebox_override("normal", _make_btn_style(false))
	start_btn.add_theme_stylebox_override("hover", _make_btn_style(true))

func _make_btn_style(hover: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.14, 0.18, 1) if not hover else Color(0.18, 0.22, 0.28, 1)
	s.border_color = _COLOR_BORDER
	s.set_border_width_all(1)
	s.set_content_margin_all(12)
	return s

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")
