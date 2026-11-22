class_name TestBattleScene
extends GdUnitTestSuite
## Unit tests for BattleScene (scripts/battle/battle_scene.gd). Loads scene so _ready runs.

var _root: Node
var _scene: Control

func before_test() -> void:
	_root = Node.new()
	get_tree().root.add_child(_root)
	var packed = load("res://scenes/battle/battle_scene.tscn") as PackedScene
	_scene = packed.instantiate() as Control
	_root.add_child(_scene)

func after_test() -> void:
	if _scene:
		if _scene.get_parent() == _root:
			_root.remove_child(_scene)
		_scene.free()
		_scene = null
	if _root:
		if _root.get_parent():
			_root.get_parent().remove_child(_root)
		_root.free()
		_root = null

func test_battle_scene_has_manager() -> void:
	# Wait one frame so _ready() and @onready are fully applied
	await get_tree().process_frame
	assert_object(_scene).is_not_null()
	assert_object(_scene.battle_manager).is_not_null()

func test_battle_scene_manager_is_setup() -> void:
	await get_tree().process_frame
	var manager: BattleManager = _scene.battle_manager
	var party = manager.get_party()
	var enemies = manager.get_enemies()
	# Scene sets up sample battle in _ready
	assert_int(party.size()).is_greater_equal(1)
	assert_int(enemies.size()).is_greater_equal(1)

func test_battle_scene_direct_launch_uses_floor1_roster() -> void:
	# No mission active: the standalone battle falls back to floor 1 (one Spire Warden).
	await get_tree().process_frame
	if MissionProgress.is_meridian_spire_active():
		return
	var enemies: Array = _scene.battle_manager.get_enemies()
	assert_int(enemies.size()).is_equal(1)
	var s: BattlerStats = enemies[0]
	assert_str(s.enemy_type).is_equal("warden")
	assert_str(s.display_name).is_equal("Spire Warden")
	var slot: BattlerSlot = _scene.arena.get_enemy_slots()[0]
	assert_bool(slot.is_boss_visual()).is_false()
	assert_object(slot.get_sprite_tint()).is_equal(Color.WHITE)

func test_battle_scene_turn_order_bar_has_one_chip_per_living_battler() -> void:
	await get_tree().process_frame
	var bar: TurnOrderBar = _scene.turn_order_bar
	var m: BattleManager = _scene.battle_manager
	assert_int(bar.get_chip_count()).is_equal(m.get_party().size() + m.get_enemies().size())
	var cur: Dictionary = m.get_current_battler()
	assert_str(bar.get_active_key()).is_equal(ArenaView.turn_key(cur.is_party, cur.index))

func test_battle_scene_speed_button_outside_actions_panel() -> void:
	await get_tree().process_frame
	assert_bool(_scene.action_panel.is_ancestor_of(_scene.speed_btn)).is_false()
	_scene.action_panel.show_panel(false)
	assert_bool(_scene.speed_btn.is_visible_in_tree()).is_true()

func test_battle_scene_log_writes_to_battle_log() -> void:
	await get_tree().process_frame
	_scene.narrator.say("hello log")
	assert_str(_scene.battle_log.get_history()[0]).contains("hello log")
