class_name TestEnemyAI
extends GdUnitTestSuite
## Unit tests for EnemyAI (scripts/battle/enemy_ai.gd): per-profile action
## choice (pure) and target choice (against a real BattleManager).

func _enemy(type_id: String, hp_fraction: float) -> BattlerStats:
	var s := BattlerStats.new()
	s.enemy_type = type_id
	s.max_hp = 100
	s.current_hp = int(100.0 * hp_fraction)
	return s


## Predicate that allows exactly the listed ability ids.
func _usable(ids: Array) -> Callable:
	return func(id: String) -> bool: return id in ids


func test_tactician_opens_with_focus_when_healthy() -> void:
	var action := EnemyAI.choose_action(_enemy("warden", 1.0), _usable(["focus", "barrage", "ranged_shot"]))
	assert_str(action.id).is_equal("focus")
	assert_bool(action.has("needs_target")).is_false()


func test_tactician_goes_barrage_after_focus_unavailable() -> void:
	var action := EnemyAI.choose_action(_enemy("warden", 1.0), _usable(["barrage", "ranged_shot"]))
	assert_str(action.id).is_equal("barrage")
	assert_bool(action.needs_target).is_true()


func test_tactician_falls_back_to_ranged_shot_then_attack() -> void:
	var shot := EnemyAI.choose_action(_enemy("warden", 1.0), _usable(["ranged_shot"]))
	assert_str(shot.id).is_equal("ranged_shot")
	var plain := EnemyAI.choose_action(_enemy("warden", 1.0), _usable([]))
	assert_str(plain.kind).is_equal("attack")


func test_tactician_skips_focus_at_or_below_half_hp() -> void:
	var action := EnemyAI.choose_action(_enemy("warden", 0.5), _usable(["focus", "barrage"]))
	assert_str(action.id).is_equal("barrage")


func test_berserker_frenzies_below_half_hp_only() -> void:
	var low := EnemyAI.choose_action(_enemy("hound", 0.49), _usable(["frenzy"]))
	assert_str(low.id).is_equal("frenzy")
	assert_bool(low.needs_target).is_true()
	assert_str(EnemyAI.choose_action(_enemy("hound", 0.5), _usable(["frenzy"])).kind).is_equal("attack")


func test_berserker_attacks_when_frenzy_unaffordable() -> void:
	assert_str(EnemyAI.choose_action(_enemy("hound", 0.2), _usable([])).kind).is_equal("attack")


func test_soldier_guards_below_forty_percent_hp_only() -> void:
	var low := EnemyAI.choose_action(_enemy("enforcer", 0.39), _usable(["guard"]))
	assert_str(low.id).is_equal("guard")
	assert_bool(low.has("needs_target")).is_false()
	assert_str(EnemyAI.choose_action(_enemy("enforcer", 0.4), _usable(["guard"])).kind).is_equal("attack")


func test_basic_attack_needs_a_target() -> void:
	var action := EnemyAI.choose_action(_enemy("enforcer", 1.0), _usable(["guard"]))
	assert_str(action.kind).is_equal("attack")
	assert_bool(action.needs_target).is_true()


# --- Target choice -----------------------------------------------------------

func _manager_with_party() -> BattleManager:
	var m: BattleManager = auto_free(BattleManager.new())
	add_child(m)
	m.setup_battle(HeroRoster.build_party(), EnemyRoster.build_enemies(["warden"], 1))
	return m


func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng


func test_pick_target_returns_living_party_member() -> void:
	var m := _manager_with_party()
	var attacker := { "stats": m.get_enemies()[0], "index": 0, "is_party": false }
	var target := EnemyAI.new(m, _seeded_rng()).pick_target(attacker, "attack")
	assert_bool(target.is_party).is_true()
	assert_bool(target.stats.is_alive()).is_true()


func test_pick_target_skips_downed_members() -> void:
	var m := _manager_with_party()
	var party: Array = m.get_party()
	party[0].current_hp = 0
	party[1].current_hp = 0
	var attacker := { "stats": m.get_enemies()[0], "index": 0, "is_party": false }
	var target := EnemyAI.new(m, _seeded_rng()).pick_target(attacker, "attack")
	assert_int(target.index).is_equal(2)


func test_pick_target_empty_when_party_wiped() -> void:
	var m := _manager_with_party()
	for s in m.get_party():
		s.current_hp = 0
	var attacker := { "stats": m.get_enemies()[0], "index": 0, "is_party": false }
	assert_dict(EnemyAI.new(m, _seeded_rng()).pick_target(attacker, "attack")).is_empty()
