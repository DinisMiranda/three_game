extends Control
## Main menu: title, Continue / New Mission / Options / Quit, and a mission
## teaser (squad portraits from HeroRoster, the Meridian Spire hook, status).
## Styled by the project Theme (assets/ui/triad_theme.tres) on the root.

const OptionsMenuScene = preload("res://scenes/ui/options_menu.tscn")
const BRIEFING_SCENE := "res://scenes/story/briefing_dialogue.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const EPILOGUE_SCENE := "res://scenes/story/meridian_epilogue.tscn"
const HIDEOUT_SELECT_SCENE := "res://scenes/story/hideout_select.tscn"

## Portrait box per hero in the teaser.
const _PORTRAIT_SIZE := Vector2(176, 200)
## Mission hook and status lines reuse the briefing / map wording.
const _STATUS_IDLE := "Rooftop extraction — PRIMARY · %d floors"
const _STATUS_ACTIVE := "In progress · %s"

@onready var title_label: Label = $Margin/ContentRow/MenuColumn/Title
@onready var subtitle_label: Label = $Margin/ContentRow/MenuColumn/Subtitle
@onready var continue_btn: Button = $Margin/ContentRow/MenuColumn/ContinueBtn
@onready var new_mission_btn: Button = $Margin/ContentRow/MenuColumn/NewMissionBtn
@onready var options_btn: Button = $Margin/ContentRow/MenuColumn/OptionsBtn
@onready var quit_btn: Button = $Margin/ContentRow/MenuColumn/QuitBtn
@onready var teaser_panel: PanelContainer = $Margin/ContentRow/TeaserPanel
@onready var mission_status: Label = $Margin/ContentRow/TeaserPanel/TeaserVBox/MissionStatus
@onready var hero_row: HBoxContainer = $Margin/ContentRow/TeaserPanel/TeaserVBox/HeroRow

var _options_menu: CanvasLayer
var _continue_scene: String = ""


## Scene that "Continue" resumes, or "" when there is nothing to continue.
## Pure: takes the MissionProgress flags so it can be unit-tested.
static func get_continue_scene(mission_active: bool, epilogue_pending: bool, hideout_select_ready: bool) -> String:
	if epilogue_pending:
		return EPILOGUE_SCENE
	if mission_active:
		return BATTLE_SCENE
	if hideout_select_ready:
		return HIDEOUT_SELECT_SCENE
	return ""


func _ready() -> void:
	randomize()
	_options_menu = OptionsMenuScene.instantiate()
	add_child(_options_menu)
	continue_btn.pressed.connect(_on_continue_pressed)
	new_mission_btn.pressed.connect(_on_new_mission_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	# get_tree().quit() does nothing in a browser tab.
	quit_btn.visible = not OS.has_feature("web")
	subtitle_label.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_continue_scene = get_continue_scene(MissionProgress.is_meridian_spire_active(),
		MissionProgress.meridian_epilogue_pending, MissionProgress.hideout_select_ready)
	continue_btn.visible = not _continue_scene.is_empty()
	_refresh_status()
	_build_hero_row()
	MusicPlayer.play_menu()
	_play_intro_animation()
	(continue_btn if continue_btn.visible else new_mission_btn).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _options_menu.visible:
		_options_menu.show_menu()
		get_viewport().set_input_as_handled()


func _refresh_status() -> void:
	if MissionProgress.is_meridian_spire_active():
		mission_status.text = _STATUS_ACTIVE % str(MissionProgress.get_meridian_floor_info().get("title", ""))
	else:
		mission_status.text = _STATUS_IDLE % MissionProgress.MERIDIAN_MAX_FLOOR


## One card per active hero: portrait on a plate, name, one-line role.
func _build_hero_row() -> void:
	for c in hero_row.get_children():
		c.queue_free()
	for i in HeroRoster.ACTIVE_PARTY_SIZE:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 4)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var plate := PanelContainer.new()
		plate.theme_type_variation = &"PlatePanel"
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = _PORTRAIT_SIZE
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path := HeroRoster.get_portrait_path(i)
		if not path.is_empty() and ResourceLoader.exists(path):
			portrait.texture = load(path) as Texture2D
		plate.add_child(portrait)
		card.add_child(plate)
		var name_l := Label.new()
		name_l.theme_type_variation = &"SubheadingLabel"
		name_l.text = str(HeroRoster.get_hero(i).get("display_name", ""))
		card.add_child(name_l)
		var role_l := Label.new()
		role_l.theme_type_variation = &"CaptionLabel"
		role_l.text = HeroRoster.get_role_label(i)
		card.add_child(role_l)
		hero_row.add_child(card)


func _play_intro_animation() -> void:
	var column: Control = $Margin/ContentRow/MenuColumn
	column.modulate = Color(1, 1, 1, 0)
	teaser_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(column, "modulate:a", 1.0, 0.4)
	tween.tween_property(teaser_panel, "modulate:a", 1.0, 0.4)


func _set_buttons_disabled(value: bool) -> void:
	for b: Button in [continue_btn, new_mission_btn, options_btn, quit_btn]:
		b.disabled = value


func _on_continue_pressed() -> void:
	if _continue_scene.is_empty():
		return
	_set_buttons_disabled(true)
	SceneFader.change_scene(_continue_scene)


func _on_new_mission_pressed() -> void:
	_set_buttons_disabled(true)
	SceneFader.change_scene(BRIEFING_SCENE)


func _on_options_pressed() -> void:
	_options_menu.show_menu()


func _on_quit_pressed() -> void:
	get_tree().quit()
