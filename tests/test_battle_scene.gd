class_name TestBattleScene
extends GdUnitTestSuite
## Unit tests for BattleScene (scripts/battle/battle_scene.gd). Loads scene so _ready runs.

var _root: Node
var _scene: Control

func before_test() -> void:
	_root = Node.new()
	var packed = load("res://scenes/battle/battle_scene.tscn") as PackedScene
	_scene = packed.instantiate() as Control
	_root.add_child(_scene)

func after_test() -> void:
	if _scene and _scene.get_parent() == _root:
		_root.remove_child(_scene)
		_scene.free()
	_scene = null
	if _root:
		_root.free()
		_root = null

func test_battle_scene_has_manager() -> void:
	# battle_scene.gd exposes battle_manager after _ready
	assert_object(_scene).is_not_null()
	assert_object(_scene.battle_manager).is_not_null()

func test_battle_scene_manager_is_setup() -> void:
	var manager: BattleManager = _scene.battle_manager
	var party = manager.get_party()
	var enemies = manager.get_enemies()
	# Scene sets up sample battle in _ready
	assert_int(party.size()).is_greater_equal(1)
	assert_int(enemies.size()).is_greater_equal(1)
