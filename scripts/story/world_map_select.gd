extends Control
## Tactical city map: pan horizontally, click zones, walk marker to destination, deploy to mission.

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const MAP_TEXTURE_PATH := "res://assets/mapa.png"
const MAP_ZONE_SCENE := preload("res://scenes/story/map_zone.tscn")

const _NEON_CYAN := Color(0.0, 0.92, 1.0, 1.0)

## Normalized rects (x, y, w, h) on the map image. Only spire is playable for now.
const ZONES: Array[Dictionary] = [
	{
		"id": "spire",
		"title": "Meridian Spire",
		"subtitle": "Rooftop extraction — PRIMARY",
		"unlocked": true,
		"rect": Rect2(0.58, 0.08, 0.24, 0.32)
	},
	{
		"id": "grid",
		"title": "North Grid",
		"subtitle": "Locked — sector quarantine",
		"unlocked": false,
		"rect": Rect2(0.2, 0.06, 0.16, 0.2)
	},
	{
		"id": "archive",
		"title": "Central Archive",
		"subtitle": "Locked — data police",
		"unlocked": false,
		"rect": Rect2(0.36, 0.34, 0.18, 0.22)
	},
	{
		"id": "docks",
		"title": "South Docks",
		"subtitle": "Locked — L2 clearance",
		"unlocked": false,
		"rect": Rect2(0.04, 0.56, 0.2, 0.28)
	},
]

@onready var _fade: ColorRect = $FadeOverlay
@onready var _scroll: ScrollContainer = $Layout/MapScroll
@onready var _map_canvas: Control = $Layout/MapScroll/MapCanvas
@onready var _map_bg: TextureRect = $Layout/MapScroll/MapCanvas/MapBg
@onready var _zones_layer: Control = $Layout/MapScroll/MapCanvas/ZonesLayer
@onready var _player: Control = $Layout/MapScroll/MapCanvas/PlayerMarker
@onready var _zone_title: Label = $Layout/Hud/HudHBox/InfoPanel/ZoneTitle
@onready var _zone_subtitle: Label = $Layout/Hud/HudHBox/InfoPanel/ZoneSubtitle
@onready var _hint: Label = $Layout/Hud/Hint
@onready var _deploy_btn: Button = $Layout/Hud/HudHBox/DeployBtn

var _idle_tweens: Array[Tween] = []
var _zones_by_id: Dictionary = {}
var _selected_zone_id: String = "spire"
var _map_display_size := Vector2.ZERO
var _dragging: bool = false
var _drag_start_x: float = 0.0
var _scroll_start_x: float = 0.0
var _player_moving: bool = false


func _ready() -> void:
	MissionProgress.finish_meridian_spire()
	_scroll.gui_input.connect(_on_map_scroll_input)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.color = Color.BLACK
	_fade.modulate = Color(1, 1, 1, 1)
	_style_hud()
	_build_map()
	_deploy_btn.pressed.connect(_on_deploy_pressed)
	MusicPlayer.play_menu()
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_select_zone("spire", false)
	await get_tree().process_frame
	_center_on_player(false)
	_deploy_btn.grab_focus()


func _build_map() -> void:
	var tex: Texture2D = load(MAP_TEXTURE_PATH) as Texture2D
	if tex == null:
		push_error("Missing map texture: %s" % MAP_TEXTURE_PATH)
		return
	_map_bg.texture = tex
	var tex_size := tex.get_size()
	var view_h: float = maxf(640.0, get_viewport_rect().size.y - 200.0)
	var scale: float = view_h / tex_size.y
	# Wider than the viewport so the player can pan left/right across the city.
	_map_display_size = Vector2(tex_size.x * scale * 1.45, view_h)
	_map_canvas.custom_minimum_size = _map_display_size
	_map_bg.custom_minimum_size = _map_display_size
	_map_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_zones_layer.custom_minimum_size = _map_display_size

	for data: Dictionary in ZONES:
		var zone: MapZone = MAP_ZONE_SCENE.instantiate() as MapZone
		var rect: Rect2 = data.rect
		zone.zone_id = str(data.id)
		zone.zone_title = str(data.title)
		zone.zone_subtitle = str(data.subtitle)
		zone.unlocked = bool(data.unlocked)
		zone.position = Vector2(rect.position.x * _map_display_size.x, rect.position.y * _map_display_size.y)
		zone.size = Vector2(rect.size.x * _map_display_size.x, rect.size.y * _map_display_size.y)
		zone.zone_clicked.connect(_on_zone_clicked)
		_zones_layer.add_child(zone)
		_zones_by_id[zone.zone_id] = zone

	_player.z_index = 10
	_player.size = Vector2(28, 28)
	_player.pivot_offset = _player.size * 0.5


func _style_hud() -> void:
	_zone_title.add_theme_color_override("font_color", _NEON_CYAN)
	_zone_title.add_theme_font_size_override("font_size", 26)
	_zone_subtitle.add_theme_color_override("font_color", Color(0.65, 0.78, 0.9, 0.95))
	_zone_subtitle.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.5, 0.68, 0.82, 0.9))
	_hint.add_theme_font_size_override("font_size", 15)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.05, 0.12, 0.16, 0.95)
	btn_style.border_color = _NEON_CYAN
	btn_style.set_border_width_all(2)
	btn_style.set_content_margin_all(14)
	_deploy_btn.add_theme_stylebox_override("normal", btn_style)
	var hover := btn_style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.2, 0.24, 1.0)
	_deploy_btn.add_theme_stylebox_override("hover", hover)
	_deploy_btn.add_theme_color_override("font_color", Color(0.92, 1.0, 1.0, 1.0))
	_deploy_btn.add_theme_font_size_override("font_size", 20)


func _on_zone_clicked(zone_id: String) -> void:
	_select_zone(zone_id, true)


func _select_zone(zone_id: String, walk_player: bool) -> void:
	if not _zones_by_id.has(zone_id):
		return
	_selected_zone_id = zone_id
	for id: String in _zones_by_id:
		var z: MapZone = _zones_by_id[id]
		z.selected = id == zone_id
	var zone: MapZone = _zones_by_id[zone_id]
	_zone_title.text = zone.zone_title
	_zone_subtitle.text = zone.zone_subtitle
	_deploy_btn.disabled = not zone.unlocked
	_deploy_btn.text = "Deploy to zone" if zone.unlocked else "Zone locked"
	if walk_player:
		await _walk_player_to_zone(zone)
	_center_on_player(true)


func _walk_player_to_zone(zone: MapZone) -> void:
	if _player_moving:
		return
	_player_moving = true
	var target: Vector2 = zone.position + zone.get_center_point() - _player.size * 0.5
	var tw := create_tween()
	tw.tween_property(_player, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_player_moving = false


func _center_on_player(animated: bool) -> void:
	var max_scroll: float = maxf(0.0, _map_canvas.size.x - _scroll.size.x)
	var target_x: float = clampf(_player.position.x - _scroll.size.x * 0.5, 0.0, max_scroll)
	if animated:
		var tw := create_tween()
		tw.tween_property(_scroll, "scroll_horizontal", int(target_x), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_scroll.scroll_horizontal = int(target_x)


func _unhandled_input(event: InputEvent) -> void:
	if _fade.modulate.a > 0.5:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_pan_map(-120)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_pan_map(120)
	elif event.is_action_pressed("ui_accept"):
		if not _deploy_btn.disabled:
			_on_deploy_pressed()
			get_viewport().set_input_as_handled()


func _pan_map(delta_x: float) -> void:
	var max_scroll: float = maxf(0.0, _map_canvas.size.x - _scroll.size.x)
	_scroll.scroll_horizontal = int(clampf(_scroll.scroll_horizontal + delta_x, 0.0, max_scroll))


func _on_map_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_start_x = mb.position.x
				_scroll_start_x = float(_scroll.scroll_horizontal)
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var max_scroll: float = maxf(0.0, _map_canvas.size.x - _scroll.size.x)
		_scroll.scroll_horizontal = int(clampf(_scroll_start_x - (mm.position.x - _drag_start_x), 0.0, max_scroll))


func _on_deploy_pressed() -> void:
	if _selected_zone_id != "spire":
		return
	_stop_idle_motion()
	MissionProgress.start_meridian_spire()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _stop_idle_motion() -> void:
	for tw in _idle_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_idle_tweens.clear()


func _exit_tree() -> void:
	_stop_idle_motion()
