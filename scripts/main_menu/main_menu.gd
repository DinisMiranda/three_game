extends Control
## Main menu: title and Start Battle button. Sci-fi style to match the battle screen.

const OptionsMenuScene = preload("res://scenes/ui/options_menu.tscn")
const BRIEFING_SCENE := "res://scenes/story/briefing_dialogue.tscn"
const _MENU_BG_PATH := "res://assets/background_blue.png"
const _MENU_BG_REPEAT_SHADER_PATH := "res://assets/menu_bg_repeat.gdshader"

const _COLOR_TEXT := Color(1.0, 1.0, 1.0, 0.95)
const _COLOR_ACCENT := Color(0.35, 0.9, 0.45, 1.0)
const _COLOR_SECONDARY := Color(1.0, 1.0, 1.0, 0.75)

@onready var title_label: Label = $Margin/ContentRow/MenuColumn/Title
@onready var subtitle_label: Label = $Margin/ContentRow/MenuColumn/Subtitle
@onready var start_btn: Button = $Margin/ContentRow/MenuColumn/StartBtn
@onready var options_btn: Button = $Margin/ContentRow/MenuColumn/OptionsBtn
@onready var concept_panel: PanelContainer = $Margin/ContentRow/ConceptPanel
@onready var concept_title: Label = $Margin/ContentRow/ConceptPanel/ConceptVBox/ConceptTitle
@onready var concept_text: Label = $Margin/ContentRow/ConceptPanel/ConceptVBox/ConceptText
@onready var background: TextureRect = $Background

var _options_menu: CanvasLayer

func _ready() -> void:
	randomize()
	_options_menu = OptionsMenuScene.instantiate()
	add_child(_options_menu)
	start_btn.pressed.connect(_on_start_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	_apply_theme()
	MusicPlayer.play_menu()
	_play_intro_animation()
	_setup_background()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _options_menu.visible:
		_options_menu.show_menu()
		get_viewport().set_input_as_handled()

const _CONCEPT_DESCRIPTION := "Three heroes. Turn-based combat. Speed decides who acts first. Use attacks and abilities, outsmart the enemy, wipe them out."

func _apply_theme() -> void:
	var empty_style := StyleBoxEmpty.new()
	empty_style.set_content_margin_all(8)
	title_label.add_theme_color_override("font_color", _COLOR_TEXT)
	title_label.add_theme_font_size_override("font_size", 56)
	subtitle_label.add_theme_color_override("font_color", _COLOR_SECONDARY)
	subtitle_label.add_theme_font_size_override("font_size", 20)
	start_btn.add_theme_color_override("font_color", _COLOR_TEXT)
	start_btn.add_theme_color_override("font_hover_color", _COLOR_ACCENT)
	start_btn.add_theme_font_size_override("font_size", 34)
	start_btn.add_theme_stylebox_override("normal", empty_style)
	start_btn.add_theme_stylebox_override("hover", empty_style)
	start_btn.add_theme_stylebox_override("pressed", empty_style)
	start_btn.add_theme_stylebox_override("focus", empty_style)
	start_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	options_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	options_btn.add_theme_color_override("font_color", _COLOR_SECONDARY)
	options_btn.add_theme_color_override("font_hover_color", _COLOR_ACCENT)
	options_btn.add_theme_font_size_override("font_size", 24)
	options_btn.add_theme_stylebox_override("normal", empty_style)
	options_btn.add_theme_stylebox_override("hover", empty_style)
	options_btn.add_theme_stylebox_override("pressed", empty_style)
	options_btn.add_theme_stylebox_override("focus", empty_style)
	concept_title.add_theme_color_override("font_color", _COLOR_ACCENT)
	concept_title.add_theme_font_size_override("font_size", 22)
	concept_text.add_theme_color_override("font_color", _COLOR_SECONDARY)
	concept_text.add_theme_font_size_override("font_size", 18)
	concept_text.text = _CONCEPT_DESCRIPTION
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.07, 0.1, 0.88)
	panel_style.border_color = Color(0.35, 0.9, 0.45, 0.5)
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(24)
	concept_panel.add_theme_stylebox_override("panel", panel_style)

func _play_intro_animation() -> void:
	var start_title_pos := title_label.position
	title_label.position = start_title_pos + Vector2(0, -40)
	title_label.modulate = Color(1, 1, 1, 0)
	start_btn.modulate = Color(1, 1, 1, 0)
	subtitle_label.modulate = Color(1, 1, 1, 0)
	options_btn.modulate = Color(1, 1, 1, 0)
	if concept_panel:
		concept_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(title_label, "position", start_title_pos, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(title_label, "modulate", Color(1, 1, 1, 1), 0.5)
	tween.parallel().tween_property(subtitle_label, "modulate", Color(1, 1, 1, 1), 0.5)
	tween.tween_property(start_btn, "modulate", Color(1, 1, 1, 1), 0.35).set_delay(0.2)
	tween.tween_property(options_btn, "modulate", Color(1, 1, 1, 1), 0.35)
	if concept_panel:
		tween.tween_property(concept_panel, "modulate", Color(1, 1, 1, 1), 0.5).set_delay(0.15)

func _setup_background() -> void:
	if not background:
		return
	var tex: Texture2D = load(_MENU_BG_PATH) as Texture2D
	if tex == null:
		return
	background.texture = tex
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.material = null
	var shader: Shader = load(_MENU_BG_REPEAT_SHADER_PATH) as Shader
	if shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		call_deferred("_apply_repeat_count", mat, tex)
		background.material = mat

func _apply_repeat_count(mat: ShaderMaterial, tex: Texture2D) -> void:
	if not background or not is_node_ready():
		return
	var view_width := get_viewport_rect().size.x
	var tex_width := tex.get_width()
	if tex_width > 0:
		mat.set_shader_parameter("repeat_x", view_width / tex_width)

func _on_start_pressed() -> void:
	start_btn.disabled = true
	options_btn.disabled = true
	var layer := CanvasLayer.new()
	layer.layer = 120
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color.BLACK
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.modulate = Color(1, 1, 1, 0)
	layer.add_child(rect)
	add_child(layer)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func () -> void:
		get_tree().change_scene_to_file(BRIEFING_SCENE)
	)

func _on_options_pressed() -> void:
	_options_menu.show_menu()
