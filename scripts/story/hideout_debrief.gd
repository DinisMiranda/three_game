extends Control
## Full squad debrief at the chosen hideout: meet Brick & Sage, recap Meridian fallout.

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"

const _BOX_BG := Color(0.05, 0.06, 0.12, 0.96)
const _BOX_BORDER := Color(0.0, 0.88, 1.0, 0.72)
const _TEXT_COLOR := Color(0.95, 0.96, 1.0, 1.0)
const _TYPEWRITER_CHARS_PER_SEC := 48.0

enum SpeakerSide { SQUAD, RESERVE }

var _lines: Array[Dictionary] = [
	{
		"side": SpeakerSide.RESERVE,
		"name": "Brick",
		"text": "You're late. Comms died the second the Spire lit up — figured you were dust."
	},
	{
		"side": SpeakerSide.SQUAD,
		"name": "Nova",
		"text": "Handler's dead. Office ambush right after we brought the case in."
	},
	{
		"side": SpeakerSide.RESERVE,
		"name": "Sage",
		"text": "Anyone hit? Don't posture — put the bag where I can see it."
	},
	{
		"side": SpeakerSide.SQUAD,
		"name": "Rin",
		"text": "We're walking. Custodian dumped the case from a helo on the roof. Handler never opened it."
	},
	{
		"side": SpeakerSide.SQUAD,
		"name": "Kael",
		"text": "Whoever sent that hit team wanted him quiet more than they wanted the package."
	},
	{
		"side": SpeakerSide.RESERVE,
		"name": "Brick",
		"text": "Then we're on every watch-list in the grid. Five of us, one case, zero handler."
	},
	{
		"side": SpeakerSide.RESERVE,
		"name": "Sage",
		"text": "I'll sweep for trackers. You four breathe — that's not a suggestion."
	},
	{
		"side": SpeakerSide.SQUAD,
		"name": "Nova",
		"text": "No contracts. No rooftops. We figure out who killed him before we crack the seal."
	},
	{
		"side": SpeakerSide.SQUAD,
		"name": "Kael",
		"text": "Hideout's set. Full squad's accounted for. We're home."
	},
]

var _line_index: int = -1
var _is_exiting: bool = false
var _is_typing: bool = false
var _typing_tween: Tween
var _typing_label: Label = null

@onready var _scene_bg: TextureRect = $SceneBackground
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
@onready var _location_banner: Label = $LocationBanner


func _ready() -> void:
	if MissionProgress.selected_hideout_id.is_empty():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
	var hideout: Dictionary = MissionProgress.get_selected_hideout()
	var bg_path: String = str(hideout.get("bg", ""))
	var tex: Texture2D = load(bg_path) as Texture2D if not bg_path.is_empty() else null
	if tex:
		_scene_bg.texture = tex
	_background.color = hideout.get("overlay", Color(0.04, 0.05, 0.1, 0.55))
	_location_banner.text = "HIDEOUT · %s" % str(hideout.get("title", ""))
	MusicPlayer.play_menu()
	_apply_dialogue_panel_style(_boss_panel)
	_apply_dialogue_panel_style(_merc_panel)
	_boss_label.add_theme_color_override("font_color", _TEXT_COLOR)
	_merc_label.add_theme_color_override("font_color", _TEXT_COLOR)
	_setup_monospace(_boss_label)
	_setup_monospace(_merc_label)
	_location_banner.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0, 0.85))
	_boss_label.text = ""
	_merc_label.text = ""
	_boss_side.visible = false
	_merc_side.visible = false
	_hint.text = "Click, SPACE or ESC to continue"
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.color = Color.BLACK
	_fade.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.55)
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
	panel.add_theme_stylebox_override("panel", s)


func _unhandled_input(event: InputEvent) -> void:
	if _is_exiting or _fade.modulate.a > 0.01:
		return
	if event.is_action_pressed("ui_cancel"):
		_skip_to_end()
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


func _skip_to_end() -> void:
	_finish_typewriter()
	_line_index = _lines.size() - 1
	_advance_line()


func _advance_line() -> void:
	_line_index += 1
	if _line_index >= _lines.size():
		_go_to_main_menu()
		return
	var entry: Dictionary = _lines[_line_index]
	var side: SpeakerSide = entry.get("side", SpeakerSide.SQUAD)
	var speaker_name: String = str(entry.get("name", ""))
	var text: String = str(entry.get("text", ""))
	_apply_speaker_portrait(side, speaker_name)
	_merc_label.text = ""
	_boss_label.text = ""
	if side == SpeakerSide.RESERVE:
		_boss_label.text = "%s\n\"%s\"" % [speaker_name, text]
		_start_typewriter(_boss_label)
	else:
		_merc_label.text = "%s\n\"%s\"" % [speaker_name, text]
		_start_typewriter(_merc_label)
	_show_only_speaker(side)
	_pulse_panel(side)


func _apply_speaker_portrait(side: SpeakerSide, speaker_name: String) -> void:
	var tex: Texture2D = HeroRoster.get_story_portrait(speaker_name)
	if tex == null:
		return
	if side == SpeakerSide.SQUAD:
		_merc_portrait.texture = tex
	else:
		_boss_portrait.texture = tex
	_update_portrait_focus(side)


func _update_portrait_focus(side: SpeakerSide) -> void:
	var bright := Color.WHITE
	var dim := Color(0.45, 0.48, 0.55, 1.0)
	if side == SpeakerSide.SQUAD:
		_merc_portrait.modulate = bright
		_boss_portrait.modulate = dim
	else:
		_merc_portrait.modulate = dim
		_boss_portrait.modulate = bright


func _show_only_speaker(side: SpeakerSide) -> void:
	_boss_side.visible = side == SpeakerSide.RESERVE
	_merc_side.visible = side == SpeakerSide.SQUAD


func _pulse_panel(side: SpeakerSide) -> void:
	var panel: PanelContainer = _boss_panel if side == SpeakerSide.RESERVE else _merc_panel
	var s := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if s == null:
		return
	var base := _BOX_BORDER
	s.border_color = Color(base.r, base.g, base.b, 1.0)
	var tw := create_tween()
	tw.tween_property(s, "border_color", base, 0.35)


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


func _go_to_main_menu() -> void:
	if _is_exiting:
		return
	_finish_typewriter()
	_is_exiting = true
	_hint.visible = false
	MissionProgress.complete_meridian_story()
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.5)
	await tw.finished
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
