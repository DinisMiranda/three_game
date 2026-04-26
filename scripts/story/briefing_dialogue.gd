extends Control
## Pre-battle briefing: mercenary team + handler. Noir / terminal-style dialogue boxes.
## Placeholder story: rooftop package retrieval. Edit `_dialogue_lines` when you have the final script.
## Layout: lower ~2/3 of screen; wide text panel over legs; large corner portrait; only active speaker visible.

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"

const _BOSS_PORTRAIT := "res://assets/enemy_1-removebg-preview.png"
const _MERC_PORTRAIT := "res://assets/hero 2 no bg.png"

## Dark tint over `OfficeBackground` so UI stays readable.
const _BG_OVERLAY := Color(0.06, 0.07, 0.1, 0.55)
const _BOX_BG := Color(0.05, 0.06, 0.12, 0.96)
const _BOX_BORDER := Color(0.0, 0.88, 1.0, 0.72)
const _TEXT_COLOR := Color(0.95, 0.96, 1.0, 1.0)

enum Speaker { BOSS, MERC }

## Edit when you have the final story (order = sequence on screen).
var _dialogue_lines: Array[Dictionary] = [
	{
		"speaker": Speaker.BOSS,
		"text": "Listen up. Package on Meridian Spire — rooftop. Extraction only. No heroics."
	},
	{
		"speaker": Speaker.MERC,
		"text": "Copy. Team’s staged at the drop-off."
	},
	{
		"speaker": Speaker.BOSS,
		"text": "Good. Clean in, clean out. Any questions?"
	},
	{
		"speaker": Speaker.MERC,
		"text": "Got it, boss."
	},
]

var _line_index: int = -1
var _is_exiting: bool = false

@onready var _background: ColorRect = $Background
@onready var _boss_side: Control = $BossSide
@onready var _boss_portrait: TextureRect = $BossSide/BossPortrait
@onready var _boss_panel: PanelContainer = $BossSide/BossDialogPanel
@onready var _boss_label: Label = $BossSide/BossDialogPanel/Margin/BossText
@onready var _merc_side: Control = $MercSide
@onready var _merc_portrait: TextureRect = $MercSide/MercPortrait
@onready var _merc_panel: PanelContainer = $MercSide/MercDialogPanel
@onready var _merc_label: Label = $MercSide/MercDialogPanel/Margin/MercText
@onready var _fade: ColorRect = $FadeOverlay
@onready var _hint: Label = $Hint


func _ready() -> void:
	_background.color = _BG_OVERLAY
	_apply_dialogue_panel_style(_boss_panel)
	_apply_dialogue_panel_style(_merc_panel)
	_boss_label.add_theme_color_override("font_color", _TEXT_COLOR)
	_merc_label.add_theme_color_override("font_color", _TEXT_COLOR)
	_setup_monospace(_boss_label)
	_setup_monospace(_merc_label)
	_load_portraits()
	_boss_label.text = ""
	_merc_label.text = ""
	_boss_side.visible = false
	_merc_side.visible = false
	_boss_portrait.modulate = Color.WHITE
	_merc_portrait.modulate = Color.WHITE
	_boss_panel.modulate = Color.WHITE
	_merc_panel.modulate = Color.WHITE
	_hint.text = "Click or SPACE to continue"
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.color = Color.BLACK
	_fade.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_advance_line()


func _setup_monospace(label: Label) -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Courier New", "Consolas", "Monaco", "monospace"])
	sf.font_weight = 500
	label.add_theme_font_override("font", sf)
	label.add_theme_font_size_override("font_size", 27)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _apply_dialogue_panel_style(panel: PanelContainer) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = _BOX_BG
	s.border_color = _BOX_BORDER
	s.set_border_width_all(2)
	s.set_content_margin_all(24)
	s.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", s)


func _load_portraits() -> void:
	var boss_tex: Texture2D = load(_BOSS_PORTRAIT) as Texture2D
	var merc_tex: Texture2D = load(_MERC_PORTRAIT) as Texture2D
	if boss_tex:
		_boss_portrait.texture = boss_tex
	if merc_tex:
		_merc_portrait.texture = merc_tex


func _input(event: InputEvent) -> void:
	if _is_exiting or _fade.modulate.a > 0.01:
		return
	if event.is_action_pressed("ui_accept"):
		_advance_line()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_line()
		get_viewport().set_input_as_handled()


func _advance_line() -> void:
	_line_index += 1
	if _line_index >= _dialogue_lines.size():
		_go_to_battle()
		return
	var entry: Dictionary = _dialogue_lines[_line_index]
	var speaker: Speaker = entry["speaker"]
	var text: String = str(entry["text"])
	if speaker == Speaker.BOSS:
		_boss_label.text = "\"%s\"" % text
		_merc_label.text = ""
	else:
		_merc_label.text = "\"%s\"" % text
		_boss_label.text = ""
	_show_only_speaker(speaker)
	_pulse_panel(speaker)


func _show_only_speaker(speaker: Speaker) -> void:
	_boss_side.visible = speaker == Speaker.BOSS
	_merc_side.visible = speaker == Speaker.MERC


func _pulse_panel(speaker: Speaker) -> void:
	var panel := _boss_panel if speaker == Speaker.BOSS else _merc_panel
	var s := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if s == null:
		return
	var base := _BOX_BORDER
	var bright := Color(base.r, base.g, base.b, 1.0)
	s.border_color = bright
	var tw := create_tween()
	tw.tween_property(s, "border_color", base, 0.35).set_trans(Tween.TRANS_SINE)


func _go_to_battle() -> void:
	if _is_exiting:
		return
	_is_exiting = true
	_hint.visible = false
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file(BATTLE_SCENE)
