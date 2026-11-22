class_name TestBattleFx
extends GdUnitTestSuite
## Unit tests for BattleFx (scripts/battle/battle_fx.gd): speed scaling, the
## speed toggle, lunge direction and the death state. Phase 1A.

var _root: Node
var _fx: BattleFx


func before_test() -> void:
	_root = Node.new()
	get_tree().root.add_child(_root)
	_fx = BattleFx.new()
	_fx.feel = BattleFeel.new()
	_root.add_child(_fx)
	_fx.set_speed_index(0)


func after_test() -> void:
	if _fx:
		_fx.set_speed_index(0)  # speed is session-static; reset for other tests
	if _root:
		_root.get_parent().remove_child(_root)
		_root.free()
	_root = null
	_fx = null


func _make_slot(is_party: bool) -> BattlerSlot:
	var slot := (load("res://scenes/battle/battler_slot.tscn") as PackedScene).instantiate() as BattlerSlot
	slot.is_party = is_party
	_root.add_child(slot)
	var stats := BattlerStats.new()
	stats.max_hp = 10
	stats.current_hp = 0
	slot.setup(stats, null)
	return slot


func test_scale_duration_halves_at_2x() -> void:
	assert_float(BattleFx.scale_duration(1.0, 2.0)).is_equal_approx(0.5, 0.0001)


func test_scale_duration_unchanged_at_1x() -> void:
	assert_float(BattleFx.scale_duration(0.3, 1.0)).is_equal_approx(0.3, 0.0001)


func test_scale_duration_clamps_negative_and_ignores_bad_speed() -> void:
	assert_float(BattleFx.scale_duration(-1.0, 2.0)).is_equal(0.0)
	assert_float(BattleFx.scale_duration(0.4, 0.0)).is_equal_approx(0.4, 0.0001)


func test_cycle_speed_toggles_between_1x_and_2x() -> void:
	assert_float(_fx.get_speed_multiplier()).is_equal(1.0)
	assert_float(_fx.cycle_speed()).is_equal(2.0)
	assert_str(_fx.get_speed_label()).is_equal("2x")
	assert_float(_fx.cycle_speed()).is_equal(1.0)
	assert_str(_fx.get_speed_label()).is_equal("1x")


func test_scaled_uses_active_speed() -> void:
	_fx.set_speed_index(1)
	assert_float(_fx.scaled(_fx.feel.death_duration)).is_equal_approx(_fx.feel.death_duration / 2.0, 0.0001)


func test_cycle_speed_emits_speed_changed() -> void:
	var received: Array[float] = []
	_fx.speed_changed.connect(func(m: float) -> void: received.append(m))
	_fx.cycle_speed()
	assert_int(received.size()).is_equal(1)
	assert_float(received[0]).is_equal(2.0)


func test_lunge_offset_without_target_faces_the_other_side() -> void:
	var hero := _make_slot(true)
	var enemy := _make_slot(false)
	assert_float(BattleFx.lunge_offset(hero, null, 10.0).x).is_greater(0.0)
	assert_float(BattleFx.lunge_offset(enemy, null, 10.0).x).is_less(0.0)


func test_lunge_offset_has_requested_length() -> void:
	var hero := _make_slot(true)
	var enemy := _make_slot(false)
	enemy.position = hero.position + Vector2(300.0, 40.0)
	assert_float(BattleFx.lunge_offset(hero, enemy, 25.0).length()).is_equal_approx(25.0, 0.01)


func test_play_death_marks_slot_downed_once() -> void:
	var slot := _make_slot(false)
	assert_bool(slot.is_downed()).is_false()
	assert_object(_fx.play_death(slot)).is_not_null()
	assert_bool(slot.is_downed()).is_true()
	assert_object(_fx.play_death(slot)).is_null()


func test_dead_slot_stays_visible_without_bars() -> void:
	var slot := _make_slot(false)
	slot.refresh()
	assert_bool(slot.visible).is_true()
	assert_bool(slot.hp_bar.visible).is_false()
