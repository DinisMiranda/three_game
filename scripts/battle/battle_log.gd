class_name BattleLog
extends PanelContainer
## Compact battle log: shows only the newest few lines, with a toggle that
## opens the full history in an overlay above the panel.
##
## History is kept newest-first as BBCode lines. The compact view never grows,
## so the space the old 220 px log used goes back to the arena (Phase 1D).
## The history overlay is a [code]top_level[/code] panel positioned above this
## one, so opening it never reflows the battle layout.

## Emitted when the history overlay opens or closes.
signal expanded_changed(expanded: bool)

## Lines shown in the compact view.
@export_range(1, 20, 1) var collapsed_line_count: int = 3
## Oldest lines beyond this are dropped from the history.
@export_range(1, 1000, 1) var max_history: int = 50
## Height (px) of the history overlay.
@export_range(80.0, 1000.0, 1.0) var expanded_height: float = 380.0
## Gap (px) between the overlay and the top of the compact panel.
@export_range(0.0, 64.0, 1.0) var expanded_gap: float = 6.0
## Header text of the panel.
@export var title_text: String = "Battle log"
## Toggle label while collapsed.
@export var expand_text: String = "History ▲"
## Toggle label while the history is open.
@export var collapse_text: String = "Close ▼"

var _history: Array[String] = []
var _expanded: bool = false

var _title_label: Label
var _toggle_btn: Button
var _lines_label: RichTextLabel
var _history_panel: PanelContainer
var _history_scroll: ScrollContainer
var _history_label: RichTextLabel


func _init() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)
	var header := HBoxContainer.new()
	header.name = "Header"
	vbox.add_child(header)
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	_toggle_btn = Button.new()
	_toggle_btn.name = "ToggleBtn"
	_toggle_btn.focus_mode = Control.FOCUS_ALL
	_toggle_btn.pressed.connect(toggle_expanded)
	header.add_child(_toggle_btn)
	_lines_label = _make_rich_label("Lines")
	_lines_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_lines_label)

	_history_panel = PanelContainer.new()
	_history_panel.name = "History"
	_history_panel.top_level = true
	_history_panel.visible = false
	add_child(_history_panel)
	_history_scroll = ScrollContainer.new()
	_history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_history_panel.add_child(_history_scroll)
	_history_label = _make_rich_label("HistoryText")
	_history_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_scroll.add_child(_history_label)
	_update_texts()


func _ready() -> void:
	resized.connect(_place_history)
	_update_texts()


## Adds one already-formatted BBCode line to the top of the history.
func add_line(bbcode_line: String) -> void:
	_history.push_front(bbcode_line)
	if _history.size() > max_history:
		_history.resize(max_history)
	_render()


## Removes every line.
func clear() -> void:
	_history.clear()
	_render()


## Full history, newest first.
func get_history() -> Array[String]:
	return _history.duplicate()


## Lines the compact view shows: the newest [member collapsed_line_count].
func get_compact_lines() -> Array[String]:
	return _history.slice(0, collapsed_line_count)


## Lines currently on screen: all history when expanded, else the compact set.
func get_visible_lines() -> Array[String]:
	return get_history() if _expanded else get_compact_lines()


## Whether the history overlay is open.
func is_expanded() -> bool:
	return _expanded


## Opens or closes the history overlay.
func set_expanded(value: bool) -> void:
	if value == _expanded:
		return
	_expanded = value
	_history_panel.visible = value
	_update_texts()
	_render()
	_place_history()
	expanded_changed.emit(value)


## Flips the history overlay.
func toggle_expanded() -> void:
	set_expanded(not _expanded)


## The expand/collapse button, so the owner can theme it.
func get_toggle_button() -> Button:
	return _toggle_btn


## Applies the owner's theme: panel styles, text colour and toggle button styles.
func apply_style(panel_style: StyleBox, history_style: StyleBox, text_color: Color,
		title_color: Color, btn_normal: StyleBox, btn_hover: StyleBox) -> void:
	add_theme_stylebox_override("panel", panel_style)
	_history_panel.add_theme_stylebox_override("panel", history_style)
	_lines_label.add_theme_color_override("default_color", text_color)
	_history_label.add_theme_color_override("default_color", text_color)
	_title_label.add_theme_color_override("font_color", title_color)
	_toggle_btn.add_theme_color_override("font_color", title_color)
	_toggle_btn.add_theme_stylebox_override("normal", btn_normal)
	_toggle_btn.add_theme_stylebox_override("hover", btn_hover)
	_toggle_btn.add_theme_stylebox_override("pressed", btn_hover)


func _make_rich_label(node_name: String) -> RichTextLabel:
	var rl := RichTextLabel.new()
	rl.name = node_name
	rl.bbcode_enabled = true
	rl.fit_content = true
	rl.scroll_active = false
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rl.mouse_filter = Control.MOUSE_FILTER_PASS
	return rl


func _update_texts() -> void:
	_title_label.text = title_text
	_toggle_btn.text = collapse_text if _expanded else expand_text
	_toggle_btn.tooltip_text = "Show the full battle log" if not _expanded else "Hide the full battle log"


func _render() -> void:
	_lines_label.text = "\n".join(get_compact_lines())
	if _expanded:
		_history_label.text = "\n".join(_history)
		_history_scroll.scroll_vertical = 0


## Positions the overlay above this panel, same width, [member expanded_height] tall.
func _place_history() -> void:
	if not _expanded or not is_inside_tree():
		return
	var rect := get_global_rect()
	var h := minf(expanded_height, maxf(rect.position.y - expanded_gap, 80.0))
	_history_panel.global_position = Vector2(rect.position.x, rect.position.y - expanded_gap - h)
	_history_panel.size = Vector2(rect.size.x, h)
