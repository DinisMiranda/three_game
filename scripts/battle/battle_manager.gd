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

## Telemetry receiver. Null = resolve the Telemetry autoload lazily; tests and
## the simulator inject their own [TelemetryService] (with its own sink).
var telemetry: TelemetryService = null
## Optional seeded RNG for crit rolls (simulator, tests). Null = global randf().
var rng: RandomNumberGenerator = null

# --- Telemetry bookkeeping (per battle) ---
var _battle_active: bool = false
var _battle_start_ms: int = 0
var _turn_number: int = 0
var _round_number: int = 0
var _action_seq: int = 0
var _hit_index: int = 0
var _in_ability: bool = false
var _ability_id: String = "attack"
var _ability_cost: int = 0

# --- Internal state ---
# Party and enemies are arrays of BattlerStats (by index 0..3 and 0..n)
var _party: Array[BattlerStats] = []
var _enemies: Array[BattlerStats] = []
# Each entry: { "stats": BattlerStats, "index": int, "is_party": bool }
var _turn_order: Array = []
var _current_turn_index: int = 0

# --- Start a battle: copy in party and enemies, build first turn order, emit first turn ---
## [param context] feeds telemetry only: { "floor": int, "mission_id": String, "policy": String (simulator) }.
func setup_battle(party: Array, enemies: Array, context: Dictionary = {}) -> void:
	if _battle_active:
		_track_battle_end("quit")
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
	_track_battle_start(context)
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
		_round_number += 1
		turn_order_updated.emit(_turn_order)
	_emit_turn_started(_current_turn_index)

func _emit_turn_started(idx: int) -> void:
	if idx < 0 or idx >= _turn_order.size():
		return
	var b = _turn_order[idx]
	b.stats.is_flying = false
	b.stats.guard_active = false
	b.stats.restore_energy(ENERGY_RESTORE_PER_TURN)
	# The order is built per round, so a battler downed earlier in the round still
	# gets a slot; that is not a real turn and is not counted or recorded.
	var t := _tm() if b.stats.is_alive() else null
	if b.stats.is_alive():
		_turn_number += 1
	if t != null:
		t.track("turn_start", {
			"turn_number": _turn_number, "round_number": _round_number,
			"actor_id": _id_of(b.stats), "actor_side": _side_of(b.is_party),
			"actor_hp": b.stats.current_hp, "actor_energy": b.stats.current_energy,
		})
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
	if not _in_ability:
		# A basic attack called directly (player Attack button / AI) is its own decision.
		_action_seq += 1
		_hit_index = 0
		_ability_id = "attack"
		_ability_cost = 0
	var anti_air: bool = bool(opts.get("anti_air", false))
	if anti_air:
		if target.is_empty() or not target.stats.is_alive() or not target.stats.is_flying:
			_record_hit(target, 0, "miss")
			_track_hit(attacker, target, 0, "miss", false, 0, _hp_or_zero(target))
			return 0
	elif not can_attack_target(attacker, target):
		_record_hit(target, 0, "miss")
		_track_hit(attacker, target, 0, "miss", false, 0, _hp_or_zero(target))
		return 0
	var atk_stats: BattlerStats = attacker.stats
	var tgt_stats: BattlerStats = target.stats
	var damage_mult: float = float(opts.get("damage_mult", 1.0))
	var ignore_defense: bool = bool(opts.get("ignore_defense", false))
	var allow_crit: bool = bool(opts.get("allow_crit", true))
	var roll: float = rng.randf() if rng != null else randf()
	var is_crit := allow_crit and roll < CRIT_CHANCE
	if is_crit:
		damage_mult *= CRIT_DAMAGE_MULT
	var half_defense := int(tgt_stats.defense / 2.0)
	var raw := int(float(atk_stats.get_attack_power()) * damage_mult) - half_defense
	var damage := maxi(1, raw)
	var shield_before := tgt_stats.shield_amount
	var hp_before := tgt_stats.current_hp
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
	_track_hit(attacker, target, actual, kind, is_crit, maxi(0, shield_before - tgt_stats.shield_amount), hp_before)
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
		var t := _tm()
		if t != null:
			t.track("ability_unaffordable", {
				"turn_number": _turn_number, "actor_id": _id_of(attacker.stats),
				"actor_side": _side_of(attacker.is_party), "ability_id": ability_id,
				"energy_cost": get_ability_cost(ability_id), "energy_available": attacker.stats.current_energy,
			})
		return false
	if ability_needs_target(ability_id) and not can_use_ability_on_target(attacker, ability_id, target):
		return false
	var cost: int = get_ability_cost(ability_id)
	if not attacker.stats.spend_energy(cost):
		return false
	_action_seq += 1
	_hit_index = 0
	_ability_id = ability_id
	_ability_cost = cost
	_in_ability = true
	var used := _resolve_ability(attacker, ability_id, target)
	_in_ability = false
	if used and _hit_index == 0:
		# Self-targeted, non-damaging ability (fly, shield, guard, focus): one "effect" row.
		_track_hit(attacker, attacker, 0, "effect", false, 0, attacker.stats.current_hp)
	return used


## Applies [param ability_id] once energy is paid. Each perform_attack inside it
## records one telemetry hit row.
func _resolve_ability(attacker: Dictionary, ability_id: String, target: Dictionary) -> bool:
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
		_track_battle_end("loss")
		battle_ended.emit(false)
	elif not _enemies_has_alive():
		_track_battle_end("win")
		battle_ended.emit(true)


## Turns taken so far in the current battle (downed battlers' slots excluded).
func get_turn_number() -> int:
	return _turn_number


## Records an in-progress battle as result "quit" (simulator turn cap, callers
## tearing a battle down without freeing the manager). No-op once it ended.
func abandon_battle() -> void:
	if _battle_active:
		_track_battle_end("quit")


## A battle still in progress when the manager leaves the tree (scene change,
## quit) is recorded as result "quit".
func _exit_tree() -> void:
	if _battle_active:
		_track_battle_end("quit")


# --- Telemetry (docs/analytics/event-schema.md). All no-ops without a receiver. ---

func _tm() -> TelemetryService:
	if telemetry == null and is_inside_tree():
		telemetry = get_node_or_null("/root/Telemetry") as TelemetryService
	return telemetry


static func _side_of(is_party: bool) -> String:
	return "party" if is_party else "enemy"


static func _id_of(stats: BattlerStats) -> String:
	if not stats.battler_id.is_empty():
		return stats.battler_id
	return stats.enemy_type if not stats.enemy_type.is_empty() else stats.display_name


static func _hp_or_zero(target: Dictionary) -> int:
	return 0 if target.is_empty() else (target.stats as BattlerStats).current_hp


static func _ids(list: Array) -> Array[String]:
	var out: Array[String] = []
	for s in list:
		out.append(_id_of(s))
	return out


static func _hp_sum(list: Array) -> int:
	var total := 0
	for s in list:
		total += maxi(0, (s as BattlerStats).current_hp)
	return total


func _track_battle_start(context: Dictionary) -> void:
	_battle_active = true
	_turn_number = 0
	_round_number = 1
	_action_seq = 0
	var t := _tm()
	_battle_start_ms = t.now_ms() if t != null else Time.get_ticks_msec()
	if t == null:
		return
	t.begin_battle()
	var enemy_types: Array[String] = []
	for s in _enemies:
		enemy_types.append(s.enemy_type)
	var payload := {
		"floor": int(context.get("floor", 1)),
		"party_ids": _ids(_party), "enemy_ids": _ids(_enemies), "enemy_type_ids": enemy_types,
		"party_hp_total": _hp_sum(_party), "enemy_hp_total": _hp_sum(_enemies),
	}
	var mission_id := str(context.get("mission_id", ""))
	if not mission_id.is_empty():
		payload["mission_id"] = mission_id
	if rng != null:
		payload["seed"] = int(rng.seed)
	var policy := str(context.get("policy", ""))
	if not policy.is_empty():
		payload["policy"] = policy
	t.track("battle_start", payload)


func _track_battle_end(result: String) -> void:
	_battle_active = false
	var t := _tm()
	if t == null:
		return
	var survivors: Array[String] = []
	for s in _party:
		if s.is_alive():
			survivors.append(_id_of(s))
	var enemies_left := 0
	for s in _enemies:
		if s.is_alive():
			enemies_left += 1
	t.track("battle_end", {
		"result": result, "turns": _turn_number, "rounds": _round_number,
		"duration_ms": t.now_ms() - _battle_start_ms,
		"surviving_party": survivors, "party_hp_remaining": _hp_sum(_party),
		"enemies_remaining": enemies_left,
	})
	t.end_battle()


## One `action` row per resolved hit, plus `battler_down` when the hit kills.
func _track_hit(attacker: Dictionary, target: Dictionary, damage: int, kind: String, is_crit: bool, absorbed: int, hp_before: int) -> void:
	var hit := _hit_index
	_hit_index += 1
	var t := _tm()
	if t == null or attacker.is_empty() or target.is_empty():
		return
	var tgt: BattlerStats = target.stats
	var hp_after := maxi(0, tgt.current_hp)
	var is_kill := hp_before > 0 and hp_after == 0
	var actor_id := _id_of(attacker.stats)
	var actor_side := _side_of(attacker.is_party)
	t.track("action", {
		"turn_number": _turn_number, "action_seq": _action_seq, "hit_index": hit,
		"actor_id": actor_id, "actor_side": actor_side, "ability_id": _ability_id,
		"target_id": _id_of(tgt), "target_side": _side_of(target.is_party),
		"damage": damage, "hit_kind": kind, "is_crit": is_crit, "shield_absorbed": absorbed,
		"energy_cost": _ability_cost if hit == 0 else 0,
		"target_hp_before": hp_before, "target_hp_after": hp_after, "is_kill": is_kill,
	})
	if is_kill:
		t.track("battler_down", {
			"turn_number": _turn_number, "battler_id": _id_of(tgt), "side": _side_of(target.is_party),
			"killer_id": actor_id, "killer_side": actor_side, "ability_id": _ability_id,
		})

func _battle_finished() -> bool:
	return not _party_has_alive() or not _enemies_has_alive()
