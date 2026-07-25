extends Node
class_name BattleManager
## Core battle logic: 4 party vs 1–4 enemies, turn-based.
## Turn order is recalculated each round by speed (higher first). Does not handle UI.

# --- Signals: the battle scene connects to these to update UI and input ---
signal turn_started(battler_index: int, is_party: bool)   # whose turn it is now
signal turn_ended(battler_index: int, is_party: bool)    # when we leave that turn
signal battle_ended(party_wins: bool)                    # true = party won
signal turn_order_updated(order: Array)                  # full order for this round

const PARTY_SIZE := 3
const MAX_ENEMIES := 4
const ENERGY_RESTORE_PER_TURN := 20

# Ability id -> energy cost. Used by both party and enemies.
const ABILITY_COSTS: Dictionary = {
	"fly": 25, "snipe": 30, "slash": 15, "grenade": 22, "guard": 20, "strike": 25, "shield": 20,
	"ranged_shot": 20, "barrage": 35, "focus": 18, "frenzy": 22
}

const TARGETED_ABILITIES: Array[String] = [
	"slash", "grenade", "strike", "snipe", "ranged_shot", "barrage", "frenzy"
]

const CRIT_CHANCE := 0.15
const CRIT_DAMAGE_MULT := 1.5

var last_ability_damage: int = 0
var last_hit_kind: String = "hit"
var last_hit_results: Array = []

# --- Internal state ---
# Party and enemies are arrays of BattlerStats (by index 0..3 and 0..n)
var _party: Array[BattlerStats] = []
var _enemies: Array[BattlerStats] = []
# Each entry: { "stats": BattlerStats, "index": int, "is_party": bool }
var _turn_order: Array = []
var _current_turn_index: int = 0

# --- Start a battle: copy in party and enemies, build first turn order, emit first turn ---
func setup_battle(party: Array, enemies: Array) -> void:
	# Duplicate so callers can pass get_party()/get_enemies() without clearing their own array.
	var party_in: Array = party.duplicate()
	var enemies_in: Array = enemies.duplicate()
	_party.clear()
	_enemies.clear()
	for i in mini(party_in.size(), PARTY_SIZE):
		var s: BattlerStats = party_in[i] if party_in[i] is BattlerStats else party_in[i].duplicate_stats()
		_party.append(s)
	for i in mini(enemies_in.size(), MAX_ENEMIES):
		var s: BattlerStats = enemies_in[i] if enemies_in[i] is BattlerStats else enemies_in[i].duplicate_stats()
		s.is_party = false
		_enemies.append(s)
	_build_turn_order()
	_current_turn_index = 0
	turn_order_updated.emit(_turn_order)
	if _turn_order.size() > 0:
		_emit_turn_started(0)

# --- Build turn order: all alive battlers, sorted by speed descending ---
func _build_turn_order() -> void:
	_turn_order.clear()
	for i in _party.size():
		if _party[i].is_alive():
			_turn_order.append({ "stats": _party[i], "index": i, "is_party": true })
	for i in _enemies.size():
		if _enemies[i].is_alive():
			_turn_order.append({ "stats": _enemies[i], "index": i, "is_party": false })
	_turn_order.sort_custom(func(a, b): return a.stats.speed > b.stats.speed)

func get_current_battler() -> Dictionary:
	if _turn_order.is_empty() or _current_turn_index < 0 or _current_turn_index >= _turn_order.size():
		return {}
	return _turn_order[_current_turn_index]

func get_party() -> Array:
	return _party

func get_enemies() -> Array:
	return _enemies

# --- Called after the current character finishes their action (or skip). ---
# Advances to next in order; if round is over, check win/lose and rebuild order.
func advance_turn() -> void:
	var current = get_current_battler()
	if current.is_empty():
		return
	turn_ended.emit(current.index, current.is_party)
	_current_turn_index += 1
	if _current_turn_index >= _turn_order.size():
		_check_battle_end()
		if _battle_finished():
			return
		_tick_round_effects()
		_build_turn_order()
		_current_turn_index = 0
		turn_order_updated.emit(_turn_order)
	_emit_turn_started(_current_turn_index)

func _emit_turn_started(idx: int) -> void:
	if idx < 0 or idx >= _turn_order.size():
		return
	var b = _turn_order[idx]
	b.stats.is_flying = false
	b.stats.guard_active = false
	b.stats.restore_energy(ENERGY_RESTORE_PER_TURN)
	turn_started.emit(b.index, b.is_party)

func get_ability_cost(ability_id: String) -> int:
	return ABILITY_COSTS.get(ability_id, 0)

func ability_needs_target(ability_id: String) -> bool:
	return ability_id in TARGETED_ABILITIES


func get_ability_hint(ability_id: String) -> String:
	match ability_id:
		"grenade":
			return "Direct hit + splash on other enemies"
		"slash":
			return "Strong melee hit"
		"strike":
			return "Ignores defense"
		"snipe":
			return "Anti-air shot"
		"guard":
			return "Halves damage until your next turn"
		"fly":
			return "Evade melee attacks"
		"shield":
			return "Absorb damage for 3 rounds"
		"focus":
			return "Boost attack for 2 rounds"
		"frenzy":
			return "Double strike when wounded"
		"ranged_shot":
			return "Ranged attack"
		"barrage":
			return "Two quick shots"
		_:
			return ""


func can_use_ability_on_target(battler: Dictionary, ability_id: String, target: Dictionary) -> bool:
	if not can_use_ability(battler, ability_id):
		return false
	if not ability_needs_target(ability_id):
		return true
	if target.is_empty() or not target.stats.is_alive():
		return false
	match ability_id:
		"snipe":
			return target.stats.is_flying
		"slash", "grenade", "strike", "frenzy":
			return can_attack_target(battler, target)
		"ranged_shot", "barrage":
			return can_attack_target(battler, target)
		_:
			return true


func has_valid_target_for_ability(battler: Dictionary, ability_id: String, opponents: Array) -> bool:
	for i in opponents.size():
		var s: BattlerStats = opponents[i]
		if not s.is_alive():
			continue
		var is_party_target := s.is_party
		var t := { "stats": s, "index": i, "is_party": is_party_target }
		if can_use_ability_on_target(battler, ability_id, t):
			return true
	return false


func can_use_ability(battler: Dictionary, ability_id: String) -> bool:
	if battler.is_empty():
		return false
	var cost: int = get_ability_cost(ability_id)
	return battler.stats.has_energy(cost)

# --- True if attacker can deal damage to target (flying targets only hittable by ranged). ---
func can_attack_target(attacker: Dictionary, target: Dictionary) -> bool:
	if attacker.is_empty() or target.is_empty():
		return false
	var tgt_stats: BattlerStats = target.stats
	if not tgt_stats.is_alive():
		return false
	if tgt_stats.is_flying and not attacker.stats.is_ranged:
		return false
	return true

# --- Resolve one attack. Options: damage_mult (float), ignore_defense (bool), allow_crit (bool). ---
func perform_attack(attacker: Dictionary, target: Dictionary, opts: Dictionary = {}) -> int:
	last_hit_kind = "miss"
	var anti_air: bool = bool(opts.get("anti_air", false))
	if anti_air:
		if target.is_empty() or not target.stats.is_alive() or not target.stats.is_flying:
			_record_hit(target, 0, "miss")
			return 0
	elif not can_attack_target(attacker, target):
		_record_hit(target, 0, "miss")
		return 0
	var atk_stats: BattlerStats = attacker.stats
	var tgt_stats: BattlerStats = target.stats
	var damage_mult: float = float(opts.get("damage_mult", 1.0))
	var ignore_defense: bool = bool(opts.get("ignore_defense", false))
	var allow_crit: bool = bool(opts.get("allow_crit", true))
	var is_crit := allow_crit and randf() < CRIT_CHANCE
	if is_crit:
		damage_mult *= CRIT_DAMAGE_MULT
	var half_defense := int(tgt_stats.defense / 2.0)
	var raw := int(float(atk_stats.get_attack_power()) * damage_mult) - half_defense
	var damage := maxi(1, raw)
	var shield_before := tgt_stats.shield_amount
	var actual := tgt_stats.take_damage(damage, ignore_defense)
	var kind := "hit"
	if actual <= 0 and shield_before > tgt_stats.shield_amount:
		kind = "absorb"
	elif actual <= 0:
		kind = "miss"
	elif is_crit:
		kind = "crit"
	last_hit_kind = kind
	_record_hit(target, actual, kind)
	return actual


func _record_hit(target: Dictionary, damage: int, kind: String) -> void:
	if target.is_empty():
		return
	last_hit_results.append({
		"target_index": target.index,
		"is_party": target.is_party,
		"damage": damage,
		"kind": kind,
	})


# --- Apply an ability. Costs energy; optional target for attack abilities. Returns true if used. ---
func perform_ability(attacker: Dictionary, ability_id: String, target: Dictionary = {}) -> bool:
	last_ability_damage = 0
	last_hit_results.clear()
	if attacker.is_empty():
		return false
	if not can_use_ability(attacker, ability_id):
		return false
	if ability_needs_target(ability_id) and not can_use_ability_on_target(attacker, ability_id, target):
		return false
	var cost: int = get_ability_cost(ability_id)
	if not attacker.stats.spend_energy(cost):
		return false
	if ability_id == "fly":
		attacker.stats.is_flying = true
		return true
	if ability_id == "shield":
		var shield_hp = attacker.stats.max_hp / 2
		attacker.stats.apply_shield(shield_hp, 3)
		return true
	if ability_id == "guard":
		attacker.stats.apply_guard()
		return true
	if ability_id == "focus":
		var bonus := int(attacker.stats.attack * 0.5)
		attacker.stats.apply_attack_buff(bonus, 2)
		return true
	if ability_id == "slash":
		last_ability_damage = perform_attack(attacker, target, { "damage_mult": 1.35 })
		return true
	if ability_id == "grenade":
		last_ability_damage = perform_attack(attacker, target, { "damage_mult": 1.0 })
		for i in _enemies.size():
			if i == target.index:
				continue
			if not _enemies[i].is_alive():
				continue
			var splash := { "stats": _enemies[i], "index": i, "is_party": false }
			last_ability_damage += perform_attack(attacker, splash, { "damage_mult": 0.45 })
		return true
	if ability_id == "strike":
		last_ability_damage = perform_attack(attacker, target, { "ignore_defense": true })
		return true
	if ability_id == "snipe":
		last_ability_damage = perform_attack(attacker, target, { "damage_mult": 1.8, "anti_air": true })
		return true
	if ability_id == "ranged_shot":
		last_ability_damage = perform_attack(attacker, target)
		return true
	if ability_id == "barrage":
		last_ability_damage = perform_attack(attacker, target)
		last_ability_damage += perform_attack(attacker, target)
		return true
	if ability_id == "frenzy":
		last_ability_damage = perform_attack(attacker, target)
		last_ability_damage += perform_attack(attacker, target)
		return true
	return false


# --- At end of round: decrement shield/buff durations. ---
func _tick_round_effects() -> void:
	for s in _party:
		s.tick_shield_round()
		s.tick_buff_rounds()
	for s in _enemies:
		s.tick_shield_round()
		s.tick_buff_rounds()

func _party_has_alive() -> bool:
	for s in _party:
		if s.is_alive():
			return true
	return false

func _enemies_has_alive() -> bool:
	for s in _enemies:
		if s.is_alive():
			return true
	return false

func _check_battle_end() -> void:
	if not _party_has_alive():
		battle_ended.emit(false)
	elif not _enemies_has_alive():
		battle_ended.emit(true)

func _battle_finished() -> bool:
	return not _party_has_alive() or not _enemies_has_alive()
