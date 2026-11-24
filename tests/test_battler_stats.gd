class_name TestBattlerStats
extends GdUnitTestSuite
## Unit tests for BattlerStats (resources/battler_stats.gd).

func test_take_damage_reduces_hp() -> void:
	var stats := BattlerStats.new()
	stats.max_hp = 100
	stats.current_hp = 100
	stats.defense = 0
	stats.take_damage(20)
	assert_int(stats.current_hp).is_equal(80)

func test_take_damage_respects_defense() -> void:
	var stats := BattlerStats.new()
	stats.current_hp = 100
	stats.defense = 10
	stats.take_damage(20)
	# to_hp = 20, actual = max(0, 20 - 10) = 10
	assert_int(stats.current_hp).is_equal(90)

func test_take_damage_shield_absorbs_first() -> void:
	var stats := BattlerStats.new()
	stats.current_hp = 100
	stats.defense = 0
	stats.shield_amount = 15
	stats.shield_rounds_left = 3
	stats.take_damage(20)
	assert_int(stats.current_hp).is_equal(95)  # 5 got through to HP
	assert_int(stats.shield_amount).is_equal(0)
	assert_int(stats.shield_rounds_left).is_equal(0)

func test_take_damage_guard_halves_incoming() -> void:
	var stats := BattlerStats.new()
	stats.current_hp = 100
	stats.defense = 0
	stats.apply_guard()
	stats.take_damage(20)
	assert_int(stats.current_hp).is_equal(90)

func test_apply_attack_buff_increases_attack_power() -> void:
	var stats := BattlerStats.new()
	stats.attack = 20
	stats.apply_attack_buff(10, 2)
	assert_int(stats.get_attack_power()).is_equal(30)

func test_heal_caps_at_max_hp() -> void:
	var stats := BattlerStats.new()
	stats.max_hp = 100
	stats.current_hp = 80
	var actual := stats.heal(50)
	assert_int(actual).is_equal(20)
	assert_int(stats.current_hp).is_equal(100)

func test_is_alive() -> void:
	var stats := BattlerStats.new()
	stats.current_hp = 1
	assert_bool(stats.is_alive()).is_true()
	stats.current_hp = 0
	assert_bool(stats.is_alive()).is_false()

func test_apply_shield_sets_amount_and_rounds() -> void:
	var stats := BattlerStats.new()
	stats.apply_shield(50, 3)
	assert_int(stats.shield_amount).is_equal(50)
	assert_int(stats.shield_rounds_left).is_equal(3)

func test_tick_shield_round_decrements_and_clears() -> void:
	var stats := BattlerStats.new()
	stats.apply_shield(10, 2)
	stats.tick_shield_round()
	assert_int(stats.shield_rounds_left).is_equal(1)
	assert_int(stats.shield_amount).is_equal(10)
	stats.tick_shield_round()
	assert_int(stats.shield_rounds_left).is_equal(0)
	assert_int(stats.shield_amount).is_equal(0)

func test_has_energy_and_spend_energy() -> void:
	var stats := BattlerStats.new()
	stats.max_energy = 100
	stats.current_energy = 50
	assert_bool(stats.has_energy(30)).is_true()
	assert_bool(stats.spend_energy(30)).is_true()
	assert_int(stats.current_energy).is_equal(20)
	assert_bool(stats.has_energy(30)).is_false()
	assert_bool(stats.spend_energy(30)).is_false()

func test_restore_energy_caps_at_max() -> void:
	var stats := BattlerStats.new()
	stats.max_energy = 100
	stats.current_energy = 90
	stats.restore_energy(50)
	assert_int(stats.current_energy).is_equal(100)

func test_duplicate_stats_copies_values() -> void:
	var stats := BattlerStats.new()
	stats.display_name = "Hero"
	stats.max_hp = 80
	stats.current_hp = 60
	stats.attack = 15
	var dup := stats.duplicate_stats()
	assert_str(dup.display_name).is_equal("Hero")
	assert_int(dup.max_hp).is_equal(80)
	assert_int(dup.current_hp).is_equal(60)
	assert_int(dup.attack).is_equal(15)
	assert_bool(dup.is_party).is_equal(stats.is_party)


func _floor_survivor(hp: int) -> BattlerStats:
	var s := BattlerStats.new()
	s.max_hp = 100
	s.current_hp = hp
	s.max_energy = 60
	s.current_energy = 5
	s.shield_amount = 7
	s.guard_active = true
	s.is_flying = true
	return s


func test_restore_for_new_floor_default_is_full_heal() -> void:
	# Arrange
	var s := _floor_survivor(30)
	# Act
	s.restore_for_new_floor()
	# Assert
	assert_int(s.current_hp).is_equal(100)
	assert_int(s.current_energy).is_equal(60)
	assert_int(s.shield_amount).is_equal(0)
	assert_bool(s.guard_active).is_false()
	assert_bool(s.is_flying).is_false()


func test_restore_for_new_floor_partial_adds_share_of_max_hp() -> void:
	# Arrange
	var s := _floor_survivor(30)
	# Act
	s.restore_for_new_floor(0.35)
	# Assert: 30 + ceil(0.35 * 100) = 65, energy still refills
	assert_int(s.current_hp).is_equal(65)
	assert_int(s.current_energy).is_equal(60)


func test_restore_for_new_floor_partial_caps_at_max_hp() -> void:
	# Arrange
	var s := _floor_survivor(90)
	# Act
	s.restore_for_new_floor(0.35)
	# Assert
	assert_int(s.current_hp).is_equal(100)


func test_restore_for_new_floor_revives_downed_hero_with_share() -> void:
	# Arrange
	var s := _floor_survivor(0)
	assert_bool(s.is_alive()).is_false()
	# Act
	s.restore_for_new_floor(0.35)
	# Assert
	assert_int(s.current_hp).is_equal(35)
	assert_bool(s.is_alive()).is_true()


func test_restore_for_new_floor_zero_fraction_still_revives_with_one_hp() -> void:
	# Arrange
	var s := _floor_survivor(0)
	# Act
	s.restore_for_new_floor(0.0)
	# Assert
	assert_int(s.current_hp).is_equal(1)


func test_meridian_mission_uses_partial_restore_from_data() -> void:
	# Arrange / Act
	var mission := load("res://resources/missions/meridian_spire.tres") as MissionData
	# Assert: rebalance v2 value, read by MissionProgress for both game and sim
	assert_float(mission.between_floor_hp_restore).is_equal_approx(0.25, 0.0001)
	assert_float(preload("res://scripts/autoload/mission_progress.gd").MERIDIAN_BETWEEN_FLOOR_HP_RESTORE).is_equal_approx(0.25, 0.0001)
