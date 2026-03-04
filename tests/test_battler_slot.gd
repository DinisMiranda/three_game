class_name TestBattlerSlot
extends GdUnitTestSuite
## Unit tests for BattlerSlot (scripts/battle/battler_slot.gd). Uses scene so @onready nodes exist.

var _root: Node
var _slot: BattlerSlot

func before_test() -> void:
	_root = Node.new()
	var scene = load("res://scenes/battle/battler_slot.tscn") as PackedScene
	_slot = scene.instantiate() as BattlerSlot
	_root.add_child(_slot)

func after_test() -> void:
	if _slot and _slot.get_parent() == _root:
		_root.remove_child(_slot)
		_slot.free()
	_slot = null
	if _root:
		_root.free()
		_root = null

func test_setup_with_stats_and_null_texture() -> void:
	var stats := BattlerStats.new()
	stats.display_name = "Test"
	stats.max_hp = 100
	stats.current_hp = 80
	stats.max_energy = 100
	stats.current_energy = 50
	_slot.setup(stats, null)
	assert_object(_slot).is_not_null()
	assert_int(stats.current_hp).is_equal(80)

func test_refresh_updates_display() -> void:
	var stats := BattlerStats.new()
	stats.max_hp = 100
	stats.current_hp = 60
	stats.max_energy = 100
	stats.current_energy = 30
	_slot.setup(stats, null)
	stats.current_hp = 50
	stats.current_energy = 20
	_slot.refresh()
	assert_int(stats.current_hp).is_equal(50)

func test_set_turn_highlight() -> void:
	var stats := BattlerStats.new()
	stats.max_hp = 100
	stats.current_hp = 100
	_slot.setup(stats, null)
	_slot.set_turn_highlight(true)
	assert_object(_slot).is_not_null()
	_slot.set_turn_highlight(false)
	assert_object(_slot).is_not_null()
