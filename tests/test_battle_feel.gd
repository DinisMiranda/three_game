class_name TestBattleFeel
extends GdUnitTestSuite
## Unit tests for BattleFeel (scripts/battle/battle_feel.gd): defaults, speed
## lookup and combat text style selection. Phase 1A, docs/design/portfolio-plan.md.

const DEFAULT_FEEL_PATH := "res://resources/battle_feel_default.tres"


func test_default_resource_loads_as_battle_feel() -> void:
	var feel := load(DEFAULT_FEEL_PATH) as BattleFeel
	assert_object(feel).is_not_null()


func test_defaults_durations_are_positive() -> void:
	var feel := BattleFeel.new()
	for value in [
		feel.lunge_out_duration, feel.lunge_back_duration, feel.attack_anim_duration,
		feel.shake_duration, feel.shake_crit_duration, feel.hit_flash_out_duration,
		feel.death_duration, feel.enemy_intro_wait,
	]:
		assert_float(value).is_greater(0.0)
	assert_int(feel.hit_stop_ms).is_greater(0)
	assert_float(feel.lunge_distance_px).is_greater(0.0)


func test_defaults_crit_is_stronger_than_normal_hit() -> void:
	var feel := BattleFeel.new()
	assert_float(feel.shake_crit_strength_px).is_greater(feel.shake_strength_px)
	assert_float(feel.crit_text_scale).is_greater(1.0)
	assert_float(feel.get_shake(true).x).is_greater(feel.get_shake(false).x)


func test_defaults_dead_slot_stays_visible() -> void:
	var feel := BattleFeel.new()
	assert_float(feel.death_modulate.a).is_greater(0.0)
	assert_float(feel.death_modulate.a).is_less(1.0)


func test_hit_stop_ms_converts_to_seconds() -> void:
	var feel := BattleFeel.new()
	feel.hit_stop_ms = 60
	assert_float(feel.get_hit_stop_seconds()).is_equal_approx(0.06, 0.0001)


func test_default_speeds_are_1x_then_2x() -> void:
	var feel := BattleFeel.new()
	assert_float(feel.get_speed_multiplier(0)).is_equal(1.0)
	assert_float(feel.get_speed_multiplier(1)).is_equal(2.0)


func test_speed_multiplier_index_wraps() -> void:
	var feel := BattleFeel.new()
	assert_float(feel.get_speed_multiplier(2)).is_equal(feel.get_speed_multiplier(0))
	assert_float(feel.get_speed_multiplier(-1)).is_equal(feel.get_speed_multiplier(1))


func test_speed_multiplier_falls_back_to_1x_when_invalid() -> void:
	var feel := BattleFeel.new()
	feel.speed_multipliers = []
	assert_float(feel.get_speed_multiplier(0)).is_equal(1.0)
	feel.speed_multipliers = [0.0]
	assert_float(feel.get_speed_multiplier(0)).is_equal(1.0)


func test_crit_text_style_is_bigger_and_crit_coloured() -> void:
	var feel := BattleFeel.new()
	var crit := feel.get_combat_text_style("crit", 12)
	var hit := feel.get_combat_text_style("hit", 12)
	assert_str(crit.text).is_equal("-12!")
	assert_str(hit.text).is_equal("-12")
	assert_int(crit.font_size).is_greater(hit.font_size)
	assert_bool(crit.color == feel.crit_text_color).is_true()
	assert_bool(hit.color == feel.hit_text_color).is_true()


func test_miss_and_absorb_text_styles_are_distinct() -> void:
	var feel := BattleFeel.new()
	var miss := feel.get_combat_text_style("miss", 0)
	var absorb := feel.get_combat_text_style("absorb", 0)
	assert_str(miss.text).is_equal("MISS")
	assert_str(absorb.text).is_equal("ABSORB")
	assert_bool(miss.color == absorb.color).is_false()


func test_zero_damage_hit_shows_no_text() -> void:
	var feel := BattleFeel.new()
	assert_bool(feel.get_combat_text_style("hit", 0).is_empty()).is_true()


# --- Status bars (Phase 1E) ---

func test_hp_color_healthy_above_low_ratio() -> void:
	var feel := BattleFeel.new()
	assert_object(feel.get_hp_color(100, 100)).is_equal(feel.hp_color)
	assert_object(feel.get_hp_color(51, 100)).is_equal(feel.hp_color)


func test_hp_color_low_at_and_below_low_ratio() -> void:
	var feel := BattleFeel.new()
	feel.hp_low_ratio = 0.5
	feel.hp_critical_ratio = 0.25
	assert_object(feel.get_hp_color(50, 100)).is_equal(feel.hp_low_color)
	assert_object(feel.get_hp_color(26, 100)).is_equal(feel.hp_low_color)


func test_hp_color_critical_at_and_below_critical_ratio() -> void:
	var feel := BattleFeel.new()
	feel.hp_low_ratio = 0.5
	feel.hp_critical_ratio = 0.25
	assert_object(feel.get_hp_color(25, 100)).is_equal(feel.hp_critical_color)
	assert_object(feel.get_hp_color(0, 100)).is_equal(feel.hp_critical_color)


func test_hp_color_zero_max_reads_healthy() -> void:
	var feel := BattleFeel.new()
	assert_object(feel.get_hp_color(0, 0)).is_equal(feel.hp_color)


func test_energy_color_differs_from_every_hp_color() -> void:
	var feel := BattleFeel.new()
	for c in [feel.hp_color, feel.hp_low_color, feel.hp_critical_color]:
		assert_bool(feel.energy_color.is_equal_approx(c)).is_false()


func test_format_bar_value() -> void:
	assert_str(BattleFeel.format_bar_value(60, 100)).is_equal("60/100")
	assert_str(BattleFeel.format_bar_value(0, 100)).is_equal("0/100")


func test_format_bar_value_clamps_out_of_range() -> void:
	assert_str(BattleFeel.format_bar_value(130, 100)).is_equal("100/100")
	assert_str(BattleFeel.format_bar_value(-5, 100)).is_equal("0/100")
	assert_str(BattleFeel.format_bar_value(5, -1)).is_equal("0/0")
