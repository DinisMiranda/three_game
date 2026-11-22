class_name TestActionPanel
extends GdUnitTestSuite
## Unit tests for ActionPanel (scripts/battle/action_panel.gd): signals and the
## main-rows / ability-list swap. The panel is taken from the real battle scene.

var _root: Node
var _panel: ActionPanel
var _events: Array = []


func before_test() -> void:
	_root = Node.new()
	get_tree().root.add_child(_root)
	var scene := (load("res://scenes/battle/battle_scene.tscn") as PackedScene).instantiate() as Control
	_root.add_child(scene)
	_panel = scene.action_panel
	_events.clear()
	_panel.attack_requested.connect(func() -> void: _events.append("attack"))
	_panel.end_turn_requested.connect(func() -> void: _events.append("end"))
	_panel.abilities_requested.connect(func() -> void: _events.append("abilities"))
	_panel.ability_selected.connect(func(id: String, n: String) -> void: _events.append([id, n]))


func after_test() -> void:
	if _root:
		_root.get_parent().remove_child(_root)
		_root.free()


func test_buttons_emit_their_signals() -> void:
	_panel.attack_btn.pressed.emit()
	_panel.end_turn_btn.pressed.emit()
	_panel.abilities_btn.pressed.emit()
	assert_array(_events).is_equal(["attack", "end", "abilities"])


func test_ability_button_emits_id_and_name() -> void:
	_panel.open_abilities([{ "id": "slash", "name": "Slash", "cost": 10, "can_afford": true, "can_use": true, "hint": "" }])
	await get_tree().process_frame
	var btn: Button = _panel.get_node("ActionsVBox/AbilitySubPanel/AbilityButtonsContainer").get_child(0)
	assert_str(btn.text).is_equal("Slash (10)")
	btn.pressed.emit()
	assert_array(_events).is_equal([["slash", "Slash"]])


func test_unusable_ability_button_is_disabled() -> void:
	_panel.open_abilities([{ "id": "x", "name": "X", "cost": 99, "can_afford": false, "can_use": false, "hint": "" }])
	await get_tree().process_frame
	var btn: Button = _panel.get_node("ActionsVBox/AbilitySubPanel/AbilityButtonsContainer").get_child(0)
	assert_bool(btn.disabled).is_true()


func test_ability_list_hides_main_rows_until_closed() -> void:
	_panel.open_abilities([])
	assert_bool(_panel.is_abilities_open()).is_true()
	assert_bool(_panel.get_node("ActionsVBox/Buttons").visible).is_false()
	_panel.close_abilities()
	assert_bool(_panel.get_node("ActionsVBox/Buttons").visible).is_true()


func test_hiding_panel_closes_ability_list_and_disables_input() -> void:
	_panel.open_abilities([])
	_panel.show_panel(false)
	assert_bool(_panel.is_abilities_open()).is_false()
	assert_int(_panel.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_set_enabled_toggles_main_buttons() -> void:
	_panel.set_enabled(false)
	assert_bool(_panel.attack_btn.disabled and _panel.abilities_btn.disabled and _panel.end_turn_btn.disabled).is_true()
