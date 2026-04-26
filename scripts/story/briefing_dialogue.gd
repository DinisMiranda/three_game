extends Control
## Pre-battle story: office (mission contact + lead), then alley (hero left, Sevro right). Background swap on fade.

const WORLD_MAP_SCENE := "res://scenes/story/world_map_select.tscn"

const _TEXTURE_OFFICE := "res://assets/escritorio.png"
const _TEXTURE_ALLEY := "res://assets/alley.png"

const _PORTRAIT_OFFICE_RIGHT := "res://assets/mission guy.png"
const _PORTRAIT_OFFICE_LEFT := "res://assets/hero 2 no bg.png"
const _PORTRAIT_ALLEY_LEFT := "res://assets/hero 2 no bg.png"
const _PORTRAIT_ALLEY_RIGHT := "res://assets/sevro_pixel_no_bg-removebg-preview.png"

const _BOSS_PORTRAIT_STRIP_OFFICE := 672.0
const _BOSS_PORTRAIT_STRIP_ALLEY := 820.0

## Dark tint over background texture.
const _BG_OVERLAY_OFFICE := Color(0.06, 0.07, 0.1, 0.55)
const _BG_OVERLAY_ALLEY := Color(0.04, 0.05, 0.12, 0.52)
const _BOX_BG := Color(0.05, 0.06, 0.12, 0.96)
const _BOX_BORDER := Color(0.0, 0.88, 1.0, 0.72)
const _TEXT_COLOR := Color(0.95, 0.96, 1.0, 1.0)

enum Phase { OFFICE, ALLEY }

## MERC = left column, BOSS = right column.
enum Speaker { MERC, BOSS }

var _office_lines: Array[Dictionary] = [
	{
		"speaker": Speaker.BOSS,
		"text": "Sit if you want. I don't do coffee — I do deadlines. Meridian Spire, rooftop. One package, one window. You miss it, I don't call you again."
	},
	{
		"speaker": Speaker.MERC,
		"text": "We won't miss it. Question is who else thinks that roof is a buffet."
	},
	{
		"speaker": Speaker.BOSS,
		"text": "Corporate security, bored drones, and someone who paid extra for 'accidents'. Extraction only. If it shoots back, you leave it breathing — or not. I don't care. The package cares."
	},
	{
		"speaker": Speaker.MERC,
		"text": "Copy. Team's staged two blocks out. Silent approach, no signatures on scanners until we're airborne."
	},
	{
		"speaker": Speaker.BOSS,
		"text": "Good. Last job like this, someone tried to 'save' a hostage. The hostage was a decoy. Three dead freelancers and a stain on my floor. Don't decorate my office with your conscience."
	},
	{
		"speaker": Speaker.MERC,
		"text": "...Understood. Clean in, clean out. Anything that isn't the package or us stays behind."
	},
	{
		"speaker": Speaker.BOSS,
		"text": "Then we're done talking. Spire lights up in forty minutes. Don't be fashionably late."
	},
	{
		"speaker": Speaker.MERC,
		"text": "We'll be early. And we'll be gone before anyone counts to three."
	},
]

var _alley_lines: Array[Dictionary] = [
	{
		"speaker": Speaker.MERC,
		"text": "Forty minutes on the clock. Everyone still breathing?"
	},
	{
		"speaker": Speaker.BOSS,
		"text": "Define breathing. I've got jitters on channel four — could be static, could be some amateur painting the alley with RF."
	},
	{
		"speaker": Speaker.MERC,
		"text": "Then we treat it like a knife. Quiet feet until the Spire. No hero poses."
	},
	{
		"speaker": Speaker.MERC,
		"text": "Alley's clear to my eyes. Two smokers who don't inhale, one dumpster that hums wrong."
	},
	{
		"speaker": Speaker.BOSS,
		"text": "That hum's a relay — cheap, loud, dumb. I can ghost it, but the second I do, someone gets a Christmas notification."
	},
	{
		"speaker": Speaker.MERC,
		"text": "Ghost it on my mark, not on your boredom. We move as one pulse — jammer, feet, rooftop."
	},
	{
		"speaker": Speaker.BOSS,
		"text": "Copy, grumpy. Mark's yours. I'll be the angel whispering 'run' in the machines' ears."
	},
	{
		"speaker": Speaker.MERC,
		"text": "Service lift still green. If the package's half as cold as the handler says, we don't stop for wounded pride."
	},
	{
		"speaker": Speaker.MERC,
		"text": "We don't stop. We finish. Eyes up when we breach the roof line — drones love a silhouette with a story."
	},
	{
		"speaker": Speaker.BOSS,
		"text": "Already spoofing silhouettes. By the time they focus, we'll be ghosts with a paycheck."
	},
	{
		"speaker": Speaker.MERC,
		"text": "Then we're set. Three out, three up, one box. Let's steal the night before it steals us."
	},
	{
		"speaker": Speaker.MERC,
		"text": "Move."
	},
]

var _phase: Phase = Phase.OFFICE
var _line_index: int = -1
var _is_exiting: bool = false

@onready var _office_bg: TextureRect = $OfficeBackground
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
	_background.color = _BG_OVERLAY_OFFICE
	_apply_dialogue_panel_style(_boss_panel)
	_apply_dialogue_panel_style(_merc_panel)
	_boss_label.add_theme_color_override("font_color", _TEXT_COLOR)
	_merc_label.add_theme_color_override("font_color", _TEXT_COLOR)
	_setup_monospace(_boss_label)
	_setup_monospace(_merc_label)
	_load_portraits_for_phase()
	_apply_boss_portrait_strip_width()
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


func _current_lines() -> Array[Dictionary]:
	return _office_lines if _phase == Phase.OFFICE else _alley_lines


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


func _load_portraits_for_phase() -> void:
	if _phase == Phase.OFFICE:
		var left_tex: Texture2D = load(_PORTRAIT_OFFICE_LEFT) as Texture2D
		var right_tex: Texture2D = load(_PORTRAIT_OFFICE_RIGHT) as Texture2D
		if left_tex:
			_merc_portrait.texture = left_tex
		if right_tex:
			_boss_portrait.texture = right_tex
	else:
		var l: Texture2D = load(_PORTRAIT_ALLEY_LEFT) as Texture2D
		var r: Texture2D = load(_PORTRAIT_ALLEY_RIGHT) as Texture2D
		if l:
			_merc_portrait.texture = l
		if r:
			_boss_portrait.texture = r


func _apply_boss_portrait_strip_width() -> void:
	var w: float = _BOSS_PORTRAIT_STRIP_OFFICE if _phase == Phase.OFFICE else _BOSS_PORTRAIT_STRIP_ALLEY
	_boss_portrait.anchor_left = 1.0
	_boss_portrait.anchor_right = 1.0
	_boss_portrait.offset_left = -w
	_boss_portrait.offset_right = -12.0


func _unhandled_input(event: InputEvent) -> void:
	if _is_exiting or _fade.modulate.a > 0.01:
		return
	if _is_advance_dialogue_input(event):
		_advance_line()
		get_viewport().set_input_as_handled()


func _is_advance_dialogue_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
			return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return false


func _advance_line() -> void:
	_line_index += 1
	var lines := _current_lines()
	if _line_index >= lines.size():
		if _phase == Phase.OFFICE:
			await _transition_to_alley()
		else:
			_go_to_world_map()
		return
	var entry: Dictionary = lines[_line_index]
	var speaker: Speaker = entry["speaker"]
	var text: String = str(entry["text"])
	_merc_label.text = ""
	_boss_label.text = ""
	if speaker == Speaker.BOSS:
		_boss_label.text = "\"%s\"" % text
	else:
		_merc_label.text = "\"%s\"" % text
	_show_only_speaker(speaker)
	_pulse_panel(speaker)


func _transition_to_alley() -> void:
	_line_index = -1
	_hint.visible = false
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	_phase = Phase.ALLEY
	var alley_tex: Texture2D = load(_TEXTURE_ALLEY) as Texture2D
	if alley_tex:
		_office_bg.texture = alley_tex
	_background.color = _BG_OVERLAY_ALLEY
	_load_portraits_for_phase()
	_apply_boss_portrait_strip_width()
	_boss_label.text = ""
	_merc_label.text = ""
	_boss_side.visible = false
	_merc_side.visible = false
	tw = create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_hint.visible = true
	_advance_line()


func _show_only_speaker(speaker: Speaker) -> void:
	_boss_side.visible = speaker == Speaker.BOSS
	_merc_side.visible = speaker == Speaker.MERC


func _pulse_panel(speaker: Speaker) -> void:
	var panel: PanelContainer = _boss_panel if speaker == Speaker.BOSS else _merc_panel
	var s := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if s == null:
		return
	var base := _BOX_BORDER
	var bright := Color(base.r, base.g, base.b, 1.0)
	s.border_color = bright
	var tw := create_tween()
	tw.tween_property(s, "border_color", base, 0.35).set_trans(Tween.TRANS_SINE)


func _go_to_world_map() -> void:
	if _is_exiting:
		return
	_is_exiting = true
	_hint.visible = false
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file(WORLD_MAP_SCENE)
