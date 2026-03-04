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
