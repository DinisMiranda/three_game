extends Node
class_name BattleManager
## Core battle logic: 4 party vs 1–4 enemies, turn-based.
## Turn order is recalculated each round by speed (higher first). Does not handle UI.

# --- Signals: the battle scene connects to these to update UI and input ---
signal turn_started(battler_index: int, is_party: bool)   # whose turn it is now
signal turn_ended(battler_index: int, is_party: bool)    # when we leave that turn
signal battle_ended(party_wins: bool)                    # true = party won
signal turn_order_updated(order: Array)                  # full order for this round

const PARTY_SIZE := 4
const MAX_ENEMIES := 4

# --- Internal state ---
# Party and enemies are arrays of BattlerStats (by index 0..3 and 0..n)
var _party: Array[BattlerStats] = []
var _enemies: Array[BattlerStats] = []
# Each entry: { "stats": BattlerStats, "index": int, "is_party": bool }
var _turn_order: Array = []
var _current_turn_index: int = 0

# --- Start a battle: copy in party and enemies, build first turn order, emit first turn ---
func setup_battle(party: Array, enemies: Array) -> void:
	_party.clear()
	_enemies.clear()
	for i in mini(party.size(), PARTY_SIZE):
		var s: BattlerStats = party[i] if party[i] is BattlerStats else party[i].duplicate_stats()
		_party.append(s)
	for i in mini(enemies.size(), MAX_ENEMIES):
		var s: BattlerStats = enemies[i] if enemies[i] is BattlerStats else enemies[i].duplicate_stats()
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
		_build_turn_order()
		_current_turn_index = 0
		turn_order_updated.emit(_turn_order)
	_emit_turn_started(_current_turn_index)

func _emit_turn_started(idx: int) -> void:
	if idx < 0 or idx >= _turn_order.size():
		return
	var b = _turn_order[idx]
	turn_started.emit(b.index, b.is_party)

# --- Resolve one attack: damage = max(1, attack - defense/2), applied to target's take_damage ---
func perform_attack(attacker: Dictionary, target: Dictionary) -> int:
	if attacker.is_empty() or target.is_empty():
		return 0
	var atk_stats: BattlerStats = attacker.stats
	var tgt_stats: BattlerStats = target.stats
	if not atk_stats.is_alive() or not tgt_stats.is_alive():
		return 0
	var damage = maxi(1, atk_stats.attack - (tgt_stats.defense / 2))
	return tgt_stats.take_damage(damage)

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
