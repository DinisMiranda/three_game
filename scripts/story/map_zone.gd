extends Control
class_name MapZone
## Clickable zone overlay on the tactical map. Draws a pulsing highlight when active or hovered.

signal zone_clicked(zone_id: String)

@export var zone_id: String = ""
@export var zone_title: String = ""
@export var zone_subtitle: String = ""
@export var unlocked: bool = false

var _hovered: bool = false
var hovered: bool:
	get:
		return _hovered
	set(value):
		_hovered = value
		queue_redraw()

var _selected: bool = false
var selected: bool:
	get:
		return _selected
	set(value):
		_selected = value
		queue_redraw()

const _COLOR_UNLOCKED := Color(0.0, 0.95, 1.0, 1.0)
const _COLOR_LOCKED := Color(0.55, 0.58, 0.65, 1.0)
const _FILL_UNLOCKED := Color(0.0, 0.85, 1.0, 0.14)
const _FILL_LOCKED := Color(0.15, 0.18, 0.22, 0.22)
const _FILL_HOVER := Color(0.0, 1.0, 0.85, 0.22)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	var label := Label.new()
	label.text = zone_title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Color(0.85, 0.98, 1.0, 0.92))
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func get_center_point() -> Vector2:
	return size * 0.5


func _process(_delta: float) -> void:
	if selected or hovered:
		queue_redraw()


func _on_mouse_entered() -> void:
	hovered = true


func _on_mouse_exited() -> void:
	hovered = false


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			zone_clicked.emit(zone_id)
			accept_event()


func _draw() -> void:
	var accent := _COLOR_UNLOCKED if unlocked else _COLOR_LOCKED
	var fill := _FILL_UNLOCKED if unlocked else _FILL_LOCKED
	if hovered and unlocked:
		fill = _FILL_HOVER
	elif hovered:
		fill = Color(_FILL_LOCKED.r, _FILL_LOCKED.g, _FILL_LOCKED.b, 0.32)

	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, fill, true)

	var border_w := 3.0 if selected else 2.0
	var alpha := 1.0 if selected or hovered else 0.55
	if not unlocked:
		alpha *= 0.65
	draw_rect(r, Color(accent.r, accent.g, accent.b, alpha), false, border_w)

	# Corner brackets for tactical HUD feel.
	var corner := minf(size.x, size.y) * 0.14
	var c := Color(accent.r, accent.g, accent.b, alpha * 0.9)
	draw_line(Vector2.ZERO, Vector2(corner, 0), c, 2.0)
	draw_line(Vector2.ZERO, Vector2(0, corner), c, 2.0)
	draw_line(Vector2(size.x, 0), Vector2(size.x - corner, 0), c, 2.0)
	draw_line(Vector2(size.x, 0), Vector2(size.x, corner), c, 2.0)
	draw_line(Vector2(0, size.y), Vector2(corner, size.y), c, 2.0)
	draw_line(Vector2(0, size.y), Vector2(0, size.y - corner), c, 2.0)
	draw_line(Vector2(size.x, size.y), Vector2(size.x - corner, size.y), c, 2.0)
	draw_line(Vector2(size.x, size.y), Vector2(size.x, size.y - corner), c, 2.0)

	if selected or (hovered and unlocked):
		var pulse := 0.35 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
		draw_rect(r.grow(6), Color(accent.r, accent.g, accent.b, pulse), false, 1.0)
