class_name TestBattleManager
extends GdUnitTestSuite
## Unit tests for BattleManager (scripts/battle/battle_manager.gd).

var _root: Node
var _manager: BattleManager

func before_test() -> void:
	_root = Node.new()
	_manager = BattleManager.new()
	_root.add_child(_manager)

func after_test() -> void:
	if _root:
		if _manager and _manager.get_parent() == _root:
			_root.remove_child(_manager)
			_manager.free()
		_manager = null
		_root.free()
		_root = null

func test_get_ability_cost() -> void:
	assert_int(_manager.get_ability_cost("shield")).is_equal(20)
	assert_int(_manager.get_ability_cost("fly")).is_equal(25)
	assert_int(_manager.get_ability_cost("unknown")).is_equal(0)

func test_can_attack_target_empty_fails() -> void:
	assert_bool(_manager.can_attack_target({}, { "stats": BattlerStats.new(), "index": 0, "is_party": false })).is_false()
	assert_bool(_manager.can_attack_target({ "stats": BattlerStats.new(), "index": 0, "is_party": true }, {})).is_false()

func test_setup_battle_builds_turn_order() -> void:
	var party := [BattlerStats.new(), BattlerStats.new()]
	party[0].speed = 10
	party[1].speed = 20
	var enemies := [BattlerStats.new()]
	enemies[0].is_party = false
	_manager.setup_battle(party, enemies)
	var order := _manager.get_party()
	assert_int(order.size()).is_equal(2)
	var current = _manager.get_current_battler()
	assert_bool(current.is_party).is_true()
	assert_int(current.stats.speed).is_equal(20)

func test_perform_attack_deals_damage() -> void:
	var party := [BattlerStats.new()]
	party[0].attack = 20
	party[0].defense = 0
	party[0].current_hp = 100
	var enemies := [BattlerStats.new()]
	enemies[0].defense = 0
	enemies[0].current_hp = 100
	enemies[0].is_party = false
	_manager.setup_battle(party, enemies)
	var attacker := _manager.get_current_battler()
	var target := { "stats": _manager.get_enemies()[0], "index": 0, "is_party": false }
	var damage := _manager.perform_attack(attacker, target)
	assert_int(damage).is_greater(0)
	assert_int(target.stats.current_hp).is_less(100)

func test_perform_ability_shield_grants_shield() -> void:
	var party := [BattlerStats.new()]
	party[0].max_hp = 100
	party[0].current_energy = 100
	var enemies: Array = []
	_manager.setup_battle(party, enemies)
	var battler := _manager.get_current_battler()
	assert_bool(_manager.perform_ability(battler, "shield")).is_true()
	assert_int(battler.stats.shield_amount).is_equal(50)
	assert_int(battler.stats.shield_rounds_left).is_equal(3)

func test_can_use_ability() -> void:
	var party := [BattlerStats.new()]
	party[0].current_energy = 100
	var enemies: Array = []
	_manager.setup_battle(party, enemies)
	var battler := _manager.get_current_battler()
	assert_bool(_manager.can_use_ability(battler, "shield")).is_true()
	battler.stats.spend_energy(85)
	assert_int(battler.stats.current_energy).is_equal(15)
	assert_bool(_manager.can_use_ability(battler, "shield")).is_false()
	assert_bool(_manager.can_use_ability({}, "shield")).is_false()

func test_can_attack_target_dead_fails() -> void:
	var party := [BattlerStats.new()]
	var enemy := BattlerStats.new()
	enemy.is_party = false
	enemy.current_hp = 0
	_manager.setup_battle(party, [enemy])
	var attacker := _manager.get_current_battler()
	var target := { "stats": _manager.get_enemies()[0], "index": 0, "is_party": false }
	assert_bool(_manager.can_attack_target(attacker, target)).is_false()

func test_can_attack_target_flying_requires_ranged() -> void:
	var party := [BattlerStats.new()]
	party[0].is_ranged = false
	var enemy := BattlerStats.new()
	enemy.is_party = false
	enemy.is_flying = true
	_manager.setup_battle(party, [enemy])
	var attacker := _manager.get_current_battler()
	var target := { "stats": _manager.get_enemies()[0], "index": 0, "is_party": false }
	assert_bool(_manager.can_attack_target(attacker, target)).is_false()
	party[0].is_ranged = true
	_manager.setup_battle(party, [enemy])
	attacker = _manager.get_current_battler()
	target = { "stats": _manager.get_enemies()[0], "index": 0, "is_party": false }
	assert_bool(_manager.can_attack_target(attacker, target)).is_true()

func test_perform_ability_fly() -> void:
	var party := [BattlerStats.new()]
	party[0].current_energy = 100
	_manager.setup_battle(party, [])
	var battler := _manager.get_current_battler()
	assert_bool(_manager.perform_ability(battler, "fly")).is_true()
	assert_bool(battler.stats.is_flying).is_true()

func test_perform_ability_guard() -> void:
	var party := [BattlerStats.new()]
	party[0].current_energy = 100
	_manager.setup_battle(party, [])
	var battler := _manager.get_current_battler()
	assert_bool(_manager.perform_ability(battler, "guard")).is_true()

func test_advance_turn_emits_and_advances() -> void:
	var party := [BattlerStats.new(), BattlerStats.new()]
	party[0].speed = 10
	party[1].speed = 5
	var enemies: Array = []
	_manager.setup_battle(party, enemies)
	var first := _manager.get_current_battler()
	assert_int(first.stats.speed).is_equal(10)
	_manager.advance_turn()
	var second := _manager.get_current_battler()
	assert_int(second.stats.speed).is_equal(5)

func test_advance_turn_new_round_rebuilds_order() -> void:
	var party := [BattlerStats.new()]
	var enemies := [BattlerStats.new()]
	enemies[0].is_party = false
	_manager.setup_battle(party, enemies)
	_manager.advance_turn()
	var current = _manager.get_current_battler()
	assert_bool(current.is_party).is_false()
	assert_int(current.index).is_equal(0)

func test_battle_ended_when_all_enemies_dead() -> void:
	var party := [BattlerStats.new()]
	party[0].attack = 100
	var enemy := BattlerStats.new()
	enemy.is_party = false
	enemy.current_hp = 10
	var state := { "emitted": false, "party_won": false }
	_manager.battle_ended.connect(func(won: bool) -> void:
		state.emitted = true
		state.party_won = won
	)
	_manager.setup_battle(party, [enemy])
	var attacker := _manager.get_current_battler()
	var target := { "stats": enemy, "index": 0, "is_party": false }
	_manager.perform_attack(attacker, target)
	_manager.advance_turn()
	_manager.advance_turn()
	assert_bool(state.emitted).is_true()
	assert_bool(state.party_won).is_true()

func test_battle_ended_when_all_party_dead() -> void:
	var party := [BattlerStats.new()]
	party[0].current_hp = 5
	party[0].speed = 5
	var enemy := BattlerStats.new()
	enemy.is_party = false
	enemy.attack = 100
	enemy.speed = 20
	var state := { "emitted": false, "party_won": true }
	_manager.battle_ended.connect(func(won: bool) -> void:
		state.emitted = true
		state.party_won = won
	)
	_manager.setup_battle(party, [enemy])
	var attacker := _manager.get_current_battler()
	assert_bool(attacker.is_party).is_false()
	var target := { "stats": _manager.get_party()[0], "index": 0, "is_party": true }
	_manager.perform_attack(attacker, target)
	_manager.advance_turn()
	_manager.advance_turn()
	assert_bool(state.emitted).is_true()
	assert_bool(state.party_won).is_false()

func test_perform_ability_ranged_shot() -> void:
	var party := [BattlerStats.new()]
	party[0].current_energy = 100
	party[0].attack = 50
	var enemy := BattlerStats.new()
	enemy.is_party = false
	enemy.current_hp = 100
	_manager.setup_battle(party, [enemy])
	var battler := _manager.get_current_battler()
	var target := { "stats": _manager.get_enemies()[0], "index": 0, "is_party": false }
	assert_bool(_manager.perform_ability(battler, "ranged_shot", target)).is_true()
	assert_int(_manager.get_enemies()[0].current_hp).is_less(100)

func test_perform_ability_barrage_hits_twice() -> void:
	var party := [BattlerStats.new()]
	party[0].current_energy = 100
	party[0].attack = 20
	var enemy := BattlerStats.new()
	enemy.is_party = false
	enemy.current_hp = 100
	enemy.defense = 0
	_manager.setup_battle(party, [enemy])
	var battler := _manager.get_current_battler()
	var target := { "stats": _manager.get_enemies()[0], "index": 0, "is_party": false }
	assert_bool(_manager.perform_ability(battler, "barrage", target)).is_true()
	assert_int(_manager.get_enemies()[0].current_hp).is_less(80)
