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
		_update_label()
		queue_redraw()

var _selected: bool = false
var selected: bool:
	get:
		return _selected
	set(value):
		_selected = value
		_update_label()
		queue_redraw()

## Zone states (art-direction §5): unlocked = line_cyan border + accent_cyan
## 14% fill; hover = accent_cyan 2 px border + 22% fill; locked = text_disabled.
const _FILL_UNLOCKED := Color(Palette.ACCENT_CYAN, 0.14)
const _FILL_HOVER := Color(Palette.ACCENT_CYAN, 0.22)
const _FILL_LOCKED := Color(Palette.BG_DEEP, 0.35)
const _FILL_LOCKED_HOVER := Color(Palette.BG_DEEP, 0.5)
## Godot 4.7 draws CanvasItem lines without the AA feather, so widths are
## one step wider than the 4.6 look.
const _BORDER_PX := 2.0
const _BORDER_SELECTED_PX := 3.0
const _BRACKET_PX := 3.0

var _label: Label
var _plate: PanelContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	# Name plate: dark plate with a thin border, centred on the bottom edge.
	_plate = PanelContainer.new()
	_plate.theme_type_variation = &"PlatePanel"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.text = zone_title
	_label.theme_type_variation = &"CaptionLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_label)
	add_child(_plate)
	_plate.resized.connect(_place_plate)
	resized.connect(_place_plate)
	_update_label()
	_place_plate.call_deferred()


func _place_plate() -> void:
	if _plate == null:
		return
	var ps := _plate.get_combined_minimum_size()
	_plate.size = ps
	_plate.position = Vector2((size.x - ps.x) * 0.5, size.y - ps.y - 8.0)


func _update_label() -> void:
	if _label == null:
		return
	var col := Palette.TEXT_SECONDARY
	if not unlocked:
		col = Palette.TEXT_DISABLED
	elif hovered or selected:
		col = Palette.TEXT_PRIMARY
	_label.add_theme_color_override("font_color", col)
	var ps := _plate.get_theme_stylebox("panel") as StyleBoxFlat
	if ps != null:
		var plate_style := ps.duplicate() as StyleBoxFlat
		plate_style.border_color = Palette.LINE_CYAN if unlocked else Color(Palette.TEXT_DISABLED, 0.6)
		if unlocked and (hovered or selected):
			plate_style.border_color = Palette.ACCENT_CYAN
		_plate.add_theme_stylebox_override("panel", plate_style)


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
	var r := Rect2(Vector2.ZERO, size)
	var fill: Color
	var border: Color
	var border_w := _BORDER_PX
	if unlocked:
		fill = _FILL_HOVER if hovered else _FILL_UNLOCKED
		border = Palette.ACCENT_CYAN if (hovered or selected) else Palette.LINE_CYAN
		if selected:
			border_w = _BORDER_SELECTED_PX
	else:
		fill = _FILL_LOCKED_HOVER if hovered else _FILL_LOCKED
		border = Color(Palette.TEXT_DISABLED, 0.9 if hovered else 0.7)
	draw_rect(r, fill, true)
	draw_rect(r.grow(-border_w * 0.5), border, false, border_w)

	# Corner brackets for the tactical HUD feel.
	var corner := minf(size.x, size.y) * 0.14
	var c := Palette.ACCENT_CYAN if unlocked else Palette.TEXT_SECONDARY
	if not unlocked:
		c = Color(c, 0.8)
	var w := _BRACKET_PX
	var h := w * 0.5
	draw_line(Vector2(0, h), Vector2(corner, h), c, w)
	draw_line(Vector2(h, 0), Vector2(h, corner), c, w)
	draw_line(Vector2(size.x, h), Vector2(size.x - corner, h), c, w)
	draw_line(Vector2(size.x - h, 0), Vector2(size.x - h, corner), c, w)
	draw_line(Vector2(0, size.y - h), Vector2(corner, size.y - h), c, w)
	draw_line(Vector2(h, size.y), Vector2(h, size.y - corner), c, w)
	draw_line(Vector2(size.x, size.y - h), Vector2(size.x - corner, size.y - h), c, w)
	draw_line(Vector2(size.x - h, size.y), Vector2(size.x - h, size.y - corner), c, w)

	if unlocked and (selected or hovered):
		var pulse := 0.35 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
		draw_rect(r.grow(6), Color(Palette.ACCENT_CYAN, pulse), false, 2.0)
