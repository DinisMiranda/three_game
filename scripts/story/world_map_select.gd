extends Control
## After the briefing: loud cyber-dispatch world map. Only Meridian Spire is playable; the rest is locked chrome.

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"

const _NEON_CYAN := Color(0.0, 0.92, 1.0, 1.0)
const _PANEL_BG := Color(0.03, 0.04, 0.09, 0.94)

@onready var _fade: ColorRect = $FadeOverlay
@onready var _btn_tower: Button = $Margin/Center/MapBoard/MainVBox/MapRow/DestColumn/BtnTower
@onready var _btn_docks: Button = $Margin/Center/MapBoard/MainVBox/MapRow/DestColumn/BtnDocks
@onready var _btn_archive: Button = $Margin/Center/MapBoard/MainVBox/MapRow/DestColumn/BtnArchive
@onready var _map_board: PanelContainer = $Margin/Center/MapBoard
@onready var _title: Label = $Margin/Center/MapBoard/MainVBox/TitleBlock/Title
@onready var _kicker: Label = $Margin/Center/MapBoard/MainVBox/TitleBlock/Kicker
@onready var _pin_glow: ColorRect = $Margin/Center/MapBoard/MainVBox/MapRow/DestColumn/PinGlow


func _ready() -> void:
	# Always enter tower run from floor 1; avoid stale state from previous sessions.
	MissionProgress.finish_meridian_spire()
	_pin_glow.modulate = Color(1, 1, 1, 0.22)
	_apply_panel_hologram(_map_board)
	_style_chip_buttons()
	_style_tower_button()
	_style_locked_button(_btn_docks)
	_style_locked_button(_btn_archive)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.color = Color.BLACK
	_fade.modulate = Color(1, 1, 1, 1)
	_btn_tower.pressed.connect(_on_tower_pressed)
	MusicPlayer.play_menu()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_map_board, "scale", Vector2(1.0, 1.0), 0.6).from(Vector2(0.94, 0.94)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_tower.grab_focus()
	_start_idle_motion()


func _start_idle_motion() -> void:
	var tw_pin := create_tween()
	tw_pin.set_loops()
	tw_pin.tween_property(_pin_glow, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
	tw_pin.tween_property(_pin_glow, "modulate:a", 0.12, 0.9).set_trans(Tween.TRANS_SINE)
	var tw_title := create_tween()
	tw_title.set_loops()
	tw_title.tween_property(_title, "modulate", Color(1.05, 1.08, 1.12, 1.0), 1.2).set_trans(Tween.TRANS_SINE)
	tw_title.tween_property(_title, "modulate", Color(0.92, 0.98, 1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE)
	var tw_k := create_tween()
	tw_k.set_loops()
	tw_k.tween_property(_kicker, "modulate", Color(1.0, 1.0, 1.0, 0.95), 0.85)
	tw_k.tween_property(_kicker, "modulate", Color(0.75, 0.95, 1.0, 0.65), 0.55)


func _apply_panel_hologram(panel: PanelContainer) -> void:
	var outer := StyleBoxFlat.new()
	outer.bg_color = _PANEL_BG
	outer.border_color = _NEON_CYAN
	outer.set_border_width_all(3)
	outer.set_corner_radius_all(4)
	outer.set_content_margin_all(28)
	outer.shadow_color = Color(_NEON_CYAN.r, _NEON_CYAN.g, _NEON_CYAN.b, 0.45)
	outer.shadow_size = 18
	outer.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", outer)


func _style_chip_buttons() -> void:
	for n: Node in get_tree().get_nodes_in_group("map_status_chip"):
		if n is Label:
			var lb := n as Label
			lb.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0, 0.88))
			lb.add_theme_font_size_override("font_size", 13)


func _style_tower_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.12, 0.16, 0.95)
	normal.border_color = _NEON_CYAN
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 16
	normal.content_margin_bottom = 16
	normal.shadow_color = Color(_NEON_CYAN.r, _NEON_CYAN.g, _NEON_CYAN.b, 0.55)
	normal.shadow_size = 14
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.2, 0.24, 1.0)
	hover.border_color = Color(0.5, 1.0, 1.0, 1.0)
	hover.shadow_size = 22
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.02, 0.08, 0.1, 1.0)
	_btn_tower.add_theme_stylebox_override("normal", normal)
	_btn_tower.add_theme_stylebox_override("hover", hover)
	_btn_tower.add_theme_stylebox_override("pressed", pressed)
	_btn_tower.add_theme_color_override("font_color", Color(0.92, 1.0, 1.0, 1.0))
	_btn_tower.add_theme_color_override("font_hover_color", Color.WHITE)
	_btn_tower.add_theme_font_size_override("font_size", 22)


func _style_locked_button(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.05, 0.07, 0.75)
	s.border_color = Color(0.35, 0.38, 0.45, 0.55)
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	btn.add_theme_stylebox_override("disabled", s)
	btn.add_theme_color_override("font_disabled_color", Color(0.42, 0.46, 0.52, 0.9))
	btn.add_theme_font_size_override("font_size", 17)


func _on_tower_pressed() -> void:
	MissionProgress.start_meridian_spire()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file(BATTLE_SCENE)
