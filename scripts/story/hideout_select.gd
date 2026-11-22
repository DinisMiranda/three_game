extends Control
## Pick a squad hideout after the Meridian epilogue; leads to debrief with Brick and Sage.

const DEBRIEF_SCENE := "res://scenes/story/hideout_debrief.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"


@onready var _fade: ColorRect = $FadeOverlay
@onready var _cards_row: HBoxContainer = $Layout/CardsWrap/CardsRow
@onready var _selected_title: Label = $Layout/Footer/VBox/SelectedTitle
@onready var _selected_subtitle: Label = $Layout/Footer/VBox/SelectedSubtitle
@onready var _rally_btn: Button = $Layout/Footer/VBox/RallyBtn
@onready var _hint: Label = $Layout/Hint

var _selected_id: String = ""


func _ready() -> void:
	if not MissionProgress.hideout_select_ready:
		SceneFader.change_scene.call_deferred(MAIN_MENU_SCENE)
		return
	MusicPlayer.play_menu()
	_style_ui()
	_build_cards()
	_rally_btn.pressed.connect(_on_rally_pressed)
	_rally_btn.disabled = true
	_hint.text = "Choose where the squad regroups"
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.color = Color.BLACK
	_fade.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.55)
	await tw.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Panels, buttons and labels come from the Theme; code sets the token colours.
func _style_ui() -> void:
	var title: Label = $Layout/Header/VBox/Title
	title.theme_type_variation = &"HeadingLabel"
	title.add_theme_color_override("font_color", Palette.ACCENT_CYAN)
	$Layout/Header/VBox/Subtitle.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_selected_subtitle.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	_hint.theme_type_variation = &"CaptionLabel"


func _build_cards() -> void:
	for child in _cards_row.get_children():
		child.queue_free()
	for hideout: Dictionary in MissionProgress.HIDEOUTS:
		var card := _make_card(hideout)
		_cards_row.add_child(card)


func _make_card(hideout: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 280)
	# Own copy of the themed panel so the selection border can change per card.
	panel.add_theme_stylebox_override("panel", TriadThemeBuilder.make_panel_box())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = str(hideout.get("title", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.theme_type_variation = &"SubheadingLabel"
	title.add_theme_color_override("font_color", Palette.ACCENT_CYAN)
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = str(hideout.get("subtitle", ""))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_color_override("font_color", Palette.TEXT_SECONDARY)
	vbox.add_child(sub)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	var pick := Button.new()
	pick.text = "Select"
	var hid := str(hideout.get("id", ""))
	pick.pressed.connect(_on_hideout_selected.bind(hid, panel))
	vbox.add_child(pick)
	panel.set_meta("hideout_id", hid)
	return panel


func _on_hideout_selected(hideout_id: String, panel: PanelContainer) -> void:
	_selected_id = hideout_id
	for child in _cards_row.get_children():
		if child is PanelContainer:
			var s := (child as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
			if s != null:
				s.border_color = Palette.LINE_CYAN if child != panel else Palette.SELECT_AMBER
	for hideout: Dictionary in MissionProgress.HIDEOUTS:
		if str(hideout.get("id", "")) == hideout_id:
			_selected_title.text = str(hideout.get("title", ""))
			_selected_subtitle.text = str(hideout.get("subtitle", ""))
			break
	_rally_btn.disabled = false
	_rally_btn.grab_focus()


func _on_rally_pressed() -> void:
	if _selected_id.is_empty():
		return
	MissionProgress.select_hideout(_selected_id)
	SceneFader.change_scene(DEBRIEF_SCENE)
