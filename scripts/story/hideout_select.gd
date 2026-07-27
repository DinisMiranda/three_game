extends Control
## Pick a squad hideout after the Meridian epilogue; leads to debrief with Brick and Sage.

const DEBRIEF_SCENE := "res://scenes/story/hideout_debrief.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"

const _NEON_CYAN := Color(0.0, 0.92, 1.0, 1.0)
const _PANEL_BG := Color(0.05, 0.06, 0.12, 0.96)
const _PANEL_BORDER := Color(0.0, 0.88, 1.0, 0.72)

@onready var _fade: ColorRect = $FadeOverlay
@onready var _cards_row: HBoxContainer = $Layout/CardsWrap/CardsRow
@onready var _selected_title: Label = $Layout/Footer/SelectedTitle
@onready var _selected_subtitle: Label = $Layout/Footer/SelectedSubtitle
@onready var _rally_btn: Button = $Layout/Footer/RallyBtn
@onready var _hint: Label = $Layout/Hint

var _selected_id: String = ""


func _ready() -> void:
	if not MissionProgress.hideout_select_ready:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
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


func _style_ui() -> void:
	$Layout/Header/Title.add_theme_color_override("font_color", _NEON_CYAN)
	$Layout/Header/Title.add_theme_font_size_override("font_size", 38)
	$Layout/Header/Subtitle.add_theme_color_override("font_color", Color(0.65, 0.78, 0.9))
	_selected_title.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_selected_subtitle.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	_hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.08, 0.1, 0.14, 1)
	btn_style.border_color = _PANEL_BORDER
	btn_style.set_border_width_all(1)
	btn_style.set_content_margin_all(14)
	_rally_btn.add_theme_stylebox_override("normal", btn_style)
	_rally_btn.add_theme_stylebox_override("hover", btn_style.duplicate())
	_rally_btn.add_theme_stylebox_override("disabled", btn_style.duplicate())
	_rally_btn.add_theme_color_override("font_color", _NEON_CYAN)


func _build_cards() -> void:
	for child in _cards_row.get_children():
		child.queue_free()
	for hideout: Dictionary in MissionProgress.HIDEOUTS:
		var card := _make_card(hideout)
		_cards_row.add_child(card)


func _make_card(hideout: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 280)
	var style := StyleBoxFlat.new()
	style.bg_color = _PANEL_BG
	style.border_color = _PANEL_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = str(hideout.get("title", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", _NEON_CYAN)
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = str(hideout.get("subtitle", ""))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vbox.add_child(sub)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	var pick := Button.new()
	pick.text = "Select"
	pick.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	var pick_style := StyleBoxFlat.new()
	pick_style.bg_color = Color(0.06, 0.08, 0.12, 1)
	pick_style.border_color = _PANEL_BORDER
	pick_style.set_border_width_all(1)
	pick_style.set_content_margin_all(10)
	pick.add_theme_stylebox_override("normal", pick_style)
	pick.add_theme_stylebox_override("hover", pick_style.duplicate())
	var hid := str(hideout.get("id", ""))
	pick.pressed.connect(_on_hideout_selected.bind(hid, panel))
	panel.set_meta("hideout_id", hid)
	return panel


func _on_hideout_selected(hideout_id: String, panel: PanelContainer) -> void:
	_selected_id = hideout_id
	for child in _cards_row.get_children():
		if child is PanelContainer:
			var s := (child as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
			if s != null:
				s.border_color = _PANEL_BORDER if child != panel else Color(1.0, 0.82, 0.25, 1.0)
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
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.45)
	await tw.finished
	get_tree().change_scene_to_file(DEBRIEF_SCENE)
