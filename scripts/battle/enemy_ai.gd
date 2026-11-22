class_name EnemyAI
extends RefCounted
## Enemy action selection, kept free of scene and UI code so it can be unit tested.
##
## Each enemy archetype carries an AI profile (see [EnemyRoster]). The profile
## decides which ability, if any, an enemy opens with; every other turn is a
## plain attack. [method choose_action] is a pure function of the attacker's
## stats and an "is this ability usable" predicate. [method pick_target] needs
## the [BattleManager] to know who is reachable.

## Ability ids the AI can pick, with the display name and whether a target is needed.
const _ABILITIES: Dictionary = {
	"focus": { "name": "Focus", "needs_target": false },
	"barrage": { "name": "Barrage", "needs_target": true },
	"ranged_shot": { "name": "Ranged Shot", "needs_target": true },
	"frenzy": { "name": "Frenzy", "needs_target": true },
	"guard": { "name": "Guard", "needs_target": false },
}

## Tactician uses Focus while above this HP fraction.
const TACTICIAN_FOCUS_ABOVE_HP: float = 0.5
## Berserker enters Frenzy below this HP fraction.
const BERSERKER_FRENZY_BELOW_HP: float = 0.5
## Soldier raises Guard below this HP fraction.
const SOLDIER_GUARD_BELOW_HP: float = 0.4

var _manager: BattleManager
var _rng: RandomNumberGenerator


## [param manager] answers reachability and ability questions; [param rng] picks
## among equally valid targets (pass a seeded one in tests).
func _init(manager: BattleManager, rng: RandomNumberGenerator = null) -> void:
	_manager = manager
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()


## Chooses this turn's action for [param attacker] (a BattleManager battler
## dictionary). Returns [code]{ "kind": "attack"|"ability", "id", "name", "needs_target" }[/code].
func choose_for(attacker: Dictionary) -> Dictionary:
	return choose_action(attacker.stats, func(id: String) -> bool: return _manager.can_use_ability(attacker, id))


## Pure decision: [param can_use] is a Callable(ability_id: String) -> bool.
## Tactician: Focus above 50% HP, then Barrage, then Ranged Shot.
## Berserker: Frenzy below 50% HP. Soldier: Guard below 40% HP. Otherwise attack.
static func choose_action(stats: BattlerStats, can_use: Callable) -> Dictionary:
	var hp_pct: float = float(stats.current_hp) / float(maxi(1, stats.max_hp))
	var order: Array[String] = []
	match EnemyRoster.get_ai_profile(stats.enemy_type):
		EnemyRoster.AI_TACTICIAN:
			if hp_pct > TACTICIAN_FOCUS_ABOVE_HP:
				order.append("focus")
			order.append_array(["barrage", "ranged_shot"])
		EnemyRoster.AI_BERSERKER:
			if hp_pct < BERSERKER_FRENZY_BELOW_HP:
				order.append("frenzy")
		EnemyRoster.AI_SOLDIER:
			if hp_pct < SOLDIER_GUARD_BELOW_HP:
				order.append("guard")
	for id in order:
		if bool(can_use.call(id)):
			return _ability_action(id)
	return { "kind": "attack", "needs_target": true }


## Picks a living party member that [param attacker] can hit with
## [param ability_id] ("attack" for the basic attack). Returns {} if none.
func pick_target(attacker: Dictionary, ability_id: String) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var party: Array = _manager.get_party()
	for i in party.size():
		var s: BattlerStats = party[i]
		if not s.is_alive():
			continue
		var t := { "stats": s, "index": i, "is_party": true }
		var reachable: bool = _manager.can_attack_target(attacker, t) if ability_id == "attack" \
			else _manager.can_use_ability_on_target(attacker, ability_id, t)
		if reachable:
			candidates.append(t)
	if candidates.is_empty():
		return {}
	return candidates[_rng.randi() % candidates.size()]


static func _ability_action(id: String) -> Dictionary:
	var info: Dictionary = _ABILITIES[id]
	var action := { "kind": "ability", "id": id, "name": info.name }
	if bool(info.needs_target):
		action["needs_target"] = true
	return action
