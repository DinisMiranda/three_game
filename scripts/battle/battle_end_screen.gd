class_name BattleEndScreen
extends CanvasLayer
## Victory / defeat overlay with its Next Floor and Back buttons.
##
## [method show_outcome] decides the title and button labels from the result and
## the Meridian Spire progress (and records spire clears in [MissionProgress]).
## The buttons only emit signals; [BattleScene] performs the scene change or
## floor rebuild.

## Next Floor was pressed. The button disables itself until [method close].
signal next_floor_requested
## The back / continue button was pressed.
signal back_to_menu_requested

@onready var _title: Label = $Center/Panel/VBox/EndTitle
@onready var _next_floor_btn: Button = $Center/Panel/VBox/NextFloorBtn
@onready var _back_btn: Button = $Center/Panel/VBox/BackToMenuBtn


func _ready() -> void:
	_title.add_theme_color_override("font_color", Palette.ACCENT_CYAN)
	_back_btn.pressed.connect(back_to_menu_requested.emit)
	_next_floor_btn.pressed.connect(_on_next_floor_pressed)


## Shows the overlay for a finished battle, sized to [param viewport_size]
## (CanvasLayer children need manual sizing).
func show_outcome(party_wins: bool, viewport_size: Vector2) -> void:
	_next_floor_btn.visible = false
	if party_wins:
		_show_victory()
	else:
		_title.text = "Defeat!"
		_back_btn.text = "Back to Main Menu"
		MissionProgress.finish_meridian_spire()
	for node_name in ["Overlay", "Center"]:
		var c: Control = get_node(node_name)
		c.set_position(Vector2.ZERO)
		c.set_size(viewport_size)
	visible = true


## Hides the overlay and re-arms Next Floor (called when the next floor loads).
func close() -> void:
	visible = false
	_next_floor_btn.visible = false
	_next_floor_btn.disabled = false


func _show_victory() -> void:
	_back_btn.text = "Back to Main Menu"
	if MissionProgress.meridian_has_next_floor_after_clear():
		_title.text = "Floor clear!"
		_next_floor_btn.visible = true
		_back_btn.text = "Abort to menu"
	elif MissionProgress.is_meridian_spire_active() and MissionProgress.meridian_floor >= MissionProgress.MERIDIAN_MAX_FLOOR:
		_title.text = "Rooftop secured!"
		MissionProgress.mark_rooftop_cleared()
		_back_btn.text = "Continue"
	elif MissionProgress.is_meridian_spire_active():
		_title.text = "Meridian Spire secured!"
		MissionProgress.finish_meridian_spire()
	else:
		_title.text = "Victory!"


func _on_next_floor_pressed() -> void:
	_next_floor_btn.disabled = true
	next_floor_requested.emit()
