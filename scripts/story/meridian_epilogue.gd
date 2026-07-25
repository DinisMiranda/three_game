extends Control
## Post-rooftop story: robot escape, bag on the roof, return to Handler, ambush, squad keeps case, back to base.

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const HIDEOUT_SELECT_SCENE := "res://scenes/story/hideout_select.tscn"

const _TEXTURE_ROOFTOP := "res://assets/e32ee0a6-a11a-4f0a-b8be-ec9723487b2b.png"
const _TEXTURE_OFFICE := "res://assets/escritorio.png"
const _TEXTURE_BASE := "res://assets/alley.png"

const _BG_OVERLAY_ROOFTOP := Color(0.03, 0.05, 0.12, 0.58)
const _BG_OVERLAY_OFFICE := Color(0.06, 0.07, 0.1, 0.55)
const _BG_OVERLAY_BASE := Color(0.04, 0.05, 0.12, 0.52)
const _BOX_BG := Color(0.05, 0.06, 0.12, 0.96)
const _BOX_BORDER := Color(0.0, 0.88, 1.0, 0.72)
const _TEXT_COLOR := Color(0.95, 0.96, 1.0, 1.0)
const _TYPEWRITER_CHARS_PER_SEC := 48.0

enum Phase { ROOFTOP, OFFICE, BASE }
enum Speaker { SQUAD, OTHER }

var _rooftop_lines: Array[Dictionary] = [
	{
		"speaker": Speaker.SQUAD,
		"name": "Nova",
		"text": "Custodian's scrap. Helo on the pad — rotors spooling. They're bailing."
	},
	{
		"speaker": Speaker.OTHER,
		"name": "Custodian",
		"text": "Weight dump protocol. Package non-essential. Evacuate."
	},
	{
		"speaker": Speaker.SQUAD,
		"name": "Rin",
		"text": "Something hit the deck. Reinforced case — handler's seal still on it."
	},
	{
		"speaker": Speaker.OTHER,
		"name": "Helicopter",
		"text": "Lifting. Clear the pad. We are gone."
	},
	{
		"speaker": Speaker.SQUAD,
		"name": "Nova",
		"text": "Let them run. We didn't climb three floors to chase rotors."
	},
	{
		"speaker": Speaker.SQUAD,
		"name": "Kael",
		"text": "Bag stays with us. Move — before security remembers we exist."
	},
]

var _office_lines: Array[Dictionary] = [
	{
		"speaker": Speaker.SQUAD,
		"name": "Nova",
		"text": "Package on the table, Handler. Air's cold, streets are loud. Talk fast."
	},
	{
		"speaker": Speaker.OTHER,
		"name": "Handler",
		"text": "You actually— good. Door was supposed to stay locked until I cleared the ch—"
	},
	{
		"speaker": Speaker.SQUAD,
		"name": "Kael",
		"text": "Ears up."
	},
	{
		"speaker": Speaker.OTHER,
		"name": "Handler",
		"text": "Wait— that's not my—"
	},
	{
		"speaker": Speaker.SQUAD,
		"name": "Nova",
		"text": "DOWN! Glass! Multiple contacts — east stair!"
	},
	{
		"speaker": Speaker.SQUAD,
		"name": "Rin",
		"text": "Handler's hit. Pulse flat. They're sweeping the room."
	},
	{
		"speaker": Speaker.SQUAD,
		"name": "Kael",
		"text": "Case is ours now. Back door. Nobody leaves empty-handed tonight."
	},
]

var _base_lines: Array[Dictionary] = [
	{
		"speaker": Speaker.SQUAD,
		"name": "Nova",
		"text": "Safe house. Alley's quiet. Handler's dead and the city didn't blink."
	},
	{
		"speaker": Speaker.SQUAD,
		"name": "Kael",
		"text": "So we open the case or we bury it with him?"
	},
	{
		"speaker": Speaker.SQUAD,
		"name": "Rin",
		"text": "We survived the Spire for a reason. Whatever's inside answers who sent that team."
	},
	{
		"speaker": Speaker.SQUAD,
		"name": "Nova",
		"text": "Base mode. No contracts, no rooftops, until we know whose money that was."
	},
	{
		"speaker": Speaker.SQUAD,
		"name": "Kael",
		"text": "Home."
	},
]

var _phase: Phase = Phase.ROOFTOP
var _line_index: int = -1
var _is_exiting: bool = false
var _is_typing: bool = false
var _typing_tween: Tween
var _typing_label: Label = null

@onready var _scene_bg: TextureRect = $SceneBackground
@onready var _background: ColorRect = $Background
@onready var _bag_prop: Label = $BagProp
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
	if not MissionProgress.meridian_epilogue_pending:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
	MusicPlayer.play_menu()
	_background.color = _BG_OVERLAY_ROOFTOP
	_apply_dialogue_panel_style(_boss_panel)
	_apply_dialogue_panel_style(_merc_panel)
	_boss_label.add_theme_color_override("font_color", _TEXT_COLOR)
	_merc_label.add_theme_color_override("font_color", _TEXT_COLOR)
	_setup_monospace(_boss_label)
	_setup_monospace(_merc_label)
	_boss_label.text = ""
	_merc_label.text = ""
	_boss_side.visible = false
	_merc_side.visible = false
	_bag_prop.visible = false
	_hint.text = "Click, SPACE or ESC to continue"
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.color = Color.BLACK
	_fade.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_advance_line()


func _current_lines() -> Array[Dictionary]:
	match _phase:
		Phase.ROOFTOP:
			return _rooftop_lines
		Phase.OFFICE:
			return _office_lines
		_:
			return _base_lines


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


func _apply_speaker_portrait(speaker: Speaker, speaker_name: String) -> void:
	var tex: Texture2D = HeroRoster.get_story_portrait(speaker_name)
	if tex == null:
		return
	if speaker == Speaker.SQUAD:
		_merc_portrait.texture = tex
	else:
		_boss_portrait.texture = tex
	_update_portrait_focus(speaker)


func _update_portrait_focus(speaker: Speaker) -> void:
	var bright := Color.WHITE
	var dim := Color(0.45, 0.48, 0.55, 1.0)
	if speaker == Speaker.SQUAD:
		_merc_portrait.modulate = bright
		if _boss_side.visible:
			_boss_portrait.modulate = dim
	else:
		_boss_portrait.modulate = bright
		if _merc_side.visible:
			_merc_portrait.modulate = dim


func _unhandled_input(event: InputEvent) -> void:
	if _is_exiting or _fade.modulate.a > 0.01:
		return
	if event.is_action_pressed("ui_cancel"):
		_skip_current_phase()
		get_viewport().set_input_as_handled()
		return
	if _is_advance_dialogue_input(event):
		if _is_typing:
			_finish_typewriter()
			get_viewport().set_input_as_handled()
			return
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


func _skip_current_phase() -> void:
	if _is_exiting:
		return
	_finish_typewriter()
	_boss_label.text = ""
	_merc_label.text = ""
	_boss_side.visible = false
	_merc_side.visible = false
	match _phase:
		Phase.ROOFTOP:
			_line_index = _rooftop_lines.size() - 1
			_advance_line()
		Phase.OFFICE:
			_line_index = _office_lines.size() - 1
			_advance_line()
		_:
			_go_to_hideout_select()


func _advance_line() -> void:
	_line_index += 1
	var lines := _current_lines()
	if _line_index >= lines.size():
		match _phase:
			Phase.ROOFTOP:
				await _transition_to_office()
			Phase.OFFICE:
				await _transition_to_base()
			_:
				_go_to_hideout_select()
		return
	var entry: Dictionary = lines[_line_index]
	var speaker: Speaker = entry["speaker"]
	var text: String = str(entry["text"])
	var speaker_name: String = str(entry.get("name", ""))
	if speaker_name.is_empty():
		speaker_name = _fallback_speaker_name(speaker)
	_apply_speaker_portrait(speaker, speaker_name)
	_merc_label.text = ""
	_boss_label.text = ""
	if speaker == Speaker.OTHER:
		_boss_label.text = "%s\n\"%s\"" % [speaker_name, text]
		_start_typewriter(_boss_label)
	else:
		_merc_label.text = "%s\n\"%s\"" % [speaker_name, text]
		_start_typewriter(_merc_label)
	_show_only_speaker(speaker)
	_pulse_panel(speaker)
	_on_line_shown(entry)


func _on_line_shown(entry: Dictionary) -> void:
	if _phase == Phase.ROOFTOP and _line_index == 2:
		_bag_prop.visible = true
		_bag_prop.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(_bag_prop, "modulate:a", 1.0, 0.45)
	if _phase == Phase.OFFICE and _line_index == 5:
		_boss_portrait.modulate = Color(0.35, 0.35, 0.4, 0.55)


func _start_typewriter(label: Label) -> void:
	_finish_typewriter()
	_typing_label = label
	var total_chars := label.text.length()
	if total_chars <= 0:
		_is_typing = false
		return
	label.visible_characters = 0
	_is_typing = true
	_typing_tween = create_tween()
	var duration := float(total_chars) / _TYPEWRITER_CHARS_PER_SEC
	_typing_tween.tween_property(label, "visible_characters", total_chars, duration)
	_typing_tween.finished.connect(_on_typewriter_finished)


func _finish_typewriter() -> void:
	if _typing_tween != null:
		_typing_tween.kill()
		_typing_tween = null
	if _typing_label != null:
		_typing_label.visible_characters = -1
	_typing_label = null
	_is_typing = false


func _on_typewriter_finished() -> void:
	if _typing_label != null:
		_typing_label.visible_characters = -1
	_typing_tween = null
	_typing_label = null
	_is_typing = false


func _transition_to_office() -> void:
	_finish_typewriter()
	_line_index = -1
	_hint.visible = false
	_bag_prop.visible = false
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	_phase = Phase.OFFICE
	var office_tex: Texture2D = load(_TEXTURE_OFFICE) as Texture2D
	if office_tex:
		_scene_bg.texture = office_tex
	_background.color = _BG_OVERLAY_OFFICE
	_boss_label.text = ""
	_merc_label.text = ""
	_boss_side.visible = false
	_merc_side.visible = false
	tw = create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_hint.visible = true
	_advance_line()


func _transition_to_base() -> void:
	_finish_typewriter()
	_line_index = -1
	_hint.visible = false
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	_phase = Phase.BASE
	var base_tex: Texture2D = load(_TEXTURE_BASE) as Texture2D
	if base_tex:
		_scene_bg.texture = base_tex
	_background.color = _BG_OVERLAY_BASE
	_boss_side.visible = false
	_boss_label.text = ""
	_merc_label.text = ""
	_merc_side.visible = false
	tw = create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_hint.visible = true
	_advance_line()


func _fallback_speaker_name(speaker: Speaker) -> String:
	if speaker == Speaker.OTHER:
		match _phase:
			Phase.ROOFTOP:
				return "Custodian"
			Phase.OFFICE:
				return "Handler"
			_:
				return ""
	var names := ["Nova", "Kael", "Rin"]
	return names[randi() % names.size()]


func _show_only_speaker(speaker: Speaker) -> void:
	if _phase == Phase.BASE:
		_boss_side.visible = false
		_merc_side.visible = speaker == Speaker.SQUAD
		return
	_boss_side.visible = speaker == Speaker.OTHER
	_merc_side.visible = speaker == Speaker.SQUAD


func _pulse_panel(speaker: Speaker) -> void:
	var panel: PanelContainer = _boss_panel if speaker == Speaker.OTHER else _merc_panel
	var s := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if s == null:
		return
	var base := _BOX_BORDER
	var bright := Color(base.r, base.g, base.b, 1.0)
	s.border_color = bright
	var tw := create_tween()
	tw.tween_property(s, "border_color", base, 0.35).set_trans(Tween.TRANS_SINE)


func _go_to_hideout_select() -> void:
	if _is_exiting:
		return
	_finish_typewriter()
	_is_exiting = true
	_hint.visible = false
	MissionProgress.mark_hideout_select_ready()
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file(HIDEOUT_SELECT_SCENE)
