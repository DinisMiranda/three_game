class_name TestEnemyRoster
extends GdUnitTestSuite
## Unit tests for EnemyRoster (scripts/battle/enemy_roster.gd) and the floor
## enemy lineups in MissionProgress.MERIDIAN_FLOORS (Phase 1B data-driven enemies).

const MissionProgressScript = preload("res://scripts/autoload/mission_progress.gd")


func test_every_archetype_has_all_required_fields() -> void:
	for type_id in EnemyRoster.get_type_ids():
		var a: Dictionary = EnemyRoster.get_archetype(type_id)
		for field in EnemyRoster.REQUIRED_FIELDS:
			assert_bool(a.has(field)).override_failure_message(
				"%s missing field %s" % [type_id, field]).is_true()
		assert_bool(a.tint is Color).is_true()
		assert_float(float(a.sprite_scale)).is_greater(0.0)
		assert_bool(a.attack_frames is Array and not a.attack_frames.is_empty()).is_true()


func test_expected_archetypes_exist() -> void:
	for type_id in ["warden", "hound", "custodian", "enforcer"]:
		assert_bool(EnemyRoster.has_type(type_id)).is_true()
	assert_bool(EnemyRoster.has_type(EnemyRoster.FALLBACK_TYPE)).is_true()


func test_archetype_sprites_exist_on_disk() -> void:
	for type_id in EnemyRoster.get_type_ids():
		var idle: String = EnemyRoster.get_idle_sprite_path(type_id)
		assert_bool(ResourceLoader.exists(idle)).override_failure_message(
			"%s idle sprite missing: %s" % [type_id, idle]).is_true()
		for p in EnemyRoster.get_attack_frame_paths(type_id):
			assert_bool(ResourceLoader.exists(str(p))).override_failure_message(
				"%s attack frame missing: %s" % [type_id, p]).is_true()


func test_display_names_unique() -> void:
	var seen: Dictionary = {}
	for type_id in EnemyRoster.get_type_ids():
		var n: String = EnemyRoster.get_display_name(type_id)
		assert_bool(seen.has(n)).override_failure_message("duplicate name %s" % n).is_false()
		seen[n] = true


func test_ai_profiles_are_valid() -> void:
	var valid := [EnemyRoster.AI_TACTICIAN, EnemyRoster.AI_BERSERKER, EnemyRoster.AI_SOLDIER]
	for type_id in EnemyRoster.get_type_ids():
		assert_array(valid).contains([EnemyRoster.get_ai_profile(type_id)])


func test_only_custodian_is_boss() -> void:
	for type_id in EnemyRoster.get_type_ids():
		assert_bool(EnemyRoster.is_boss(type_id)).is_equal(type_id == "custodian")


# --- Duplicate-suffix rule (pure function) ---

func test_names_no_suffix_when_types_differ() -> void:
	var names := EnemyRoster.build_display_names(["warden", "hound"])
	assert_array(names).is_equal(["Spire Warden", "Sentry Hound"])


func test_names_suffix_when_type_repeats() -> void:
	var names := EnemyRoster.build_display_names(["hound", "warden", "hound"])
	assert_array(names).is_equal(["Sentry Hound A", "Spire Warden", "Sentry Hound B"])


func test_names_single_enemy_no_suffix() -> void:
	assert_array(EnemyRoster.build_display_names(["custodian"])).is_equal(["Custodian Unit"])


func test_names_empty_list() -> void:
	assert_array(EnemyRoster.build_display_names([])).is_empty()


# --- Floor lineups ---

func test_floor_lists_reference_existing_archetypes() -> void:
	var floors: Array = MissionProgressScript.MERIDIAN_FLOORS
	assert_int(floors.size()).is_equal(MissionProgressScript.MERIDIAN_MAX_FLOOR)
	for f in floors:
		var enemies: Array = f.get("enemies", [])
		assert_bool(enemies.is_empty()).is_false()
		for type_id in enemies:
			assert_bool(EnemyRoster.has_type(str(type_id))).override_failure_message(
				"unknown enemy type %s on %s" % [type_id, f.title]).is_true()


func test_floor_lineups_match_design() -> void:
	var floors: Array = MissionProgressScript.MERIDIAN_FLOORS
	assert_array(floors[0].enemies).is_equal(["warden"])
	assert_array(floors[1].enemies).is_equal(["warden", "hound"])
	assert_array(floors[2].enemies).is_equal(["custodian"])


# --- Stats: refactor must keep the pre-roster numbers identical (boundary values) ---

func test_floor1_warden_stats_unchanged() -> void:
	var e: Array = EnemyRoster.build_enemies(["warden"], 1)
	var s: BattlerStats = e[0]
	assert_str(s.enemy_type).is_equal("warden")
	assert_str(s.display_name).is_equal("Spire Warden")
	assert_int(s.max_hp).is_equal(40)
	assert_int(s.current_hp).is_equal(40)
	assert_int(s.attack).is_equal(16)
	assert_int(s.defense).is_equal(3)
	assert_int(s.speed).is_equal(5)
	assert_bool(s.is_ranged).is_true()
	assert_bool(s.is_party).is_false()


func test_floor2_lineup_stats_unchanged() -> void:
	var e: Array = EnemyRoster.build_enemies(["warden", "hound"], 2)
	var w: BattlerStats = e[0]
	var h: BattlerStats = e[1]
	assert_int(w.max_hp).is_equal(50)
	assert_int(w.attack).is_equal(18)
	assert_int(w.speed).is_equal(5)
	assert_bool(w.is_ranged).is_true()
	assert_str(h.enemy_type).is_equal("hound")
	assert_str(h.display_name).is_equal("Sentry Hound")
	assert_int(h.max_hp).is_equal(60)
	assert_int(h.attack).is_equal(20)
	assert_int(h.defense).is_equal(3)
	assert_int(h.speed).is_equal(8)
	assert_bool(h.is_ranged).is_false()


## Pins the rebalance v1 boss (docs/design/rebalance-v1.md, C1): HP 55->75 base
## (95 on floor 3), DEF 3->5, Tactician -> Berserker.
func test_floor3_custodian_stats_match_rebalance_v1() -> void:
	var e: Array = EnemyRoster.build_enemies(["custodian"], 3)
	var c: BattlerStats = e[0]
	assert_str(c.display_name).is_equal("Custodian Unit")
	assert_int(c.max_hp).is_equal(95)
	assert_int(c.attack).is_equal(24)
	assert_int(c.defense).is_equal(5)
	assert_int(c.speed).is_equal(7)
	assert_bool(c.is_ranged).is_false()
	assert_int(EnemyRoster.get_ai_profile("custodian")).is_equal(EnemyRoster.AI_BERSERKER)


func test_empty_lineup_falls_back() -> void:
	var e: Array = EnemyRoster.build_enemies([], 1)
	assert_int(e.size()).is_equal(1)
	assert_str((e[0] as BattlerStats).enemy_type).is_equal(EnemyRoster.FALLBACK_TYPE)


func test_unknown_type_falls_back() -> void:
	var s := BattlerStats.new()
	assert_bool(EnemyRoster.apply_to_stats("no_such_type", 1, s)).is_true()
	assert_str(s.enemy_type).is_equal(EnemyRoster.FALLBACK_TYPE)
	assert_str(s.display_name).is_equal(EnemyRoster.get_display_name(EnemyRoster.FALLBACK_TYPE))
