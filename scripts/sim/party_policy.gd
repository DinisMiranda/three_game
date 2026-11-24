extends RefCounted
class_name PartyPolicy
## Strategy that picks a party member's action for the headless simulator.
##
## Subclasses override [method policy_name] and [method choose]. Every policy
## chooses only from [method legal_actions], so a policy can be bad but never
## illegal. An action is [code]{ "kind": "attack"|"ability"|"pass", "id": String, "target": Dictionary }[/code].

const NAMES: Array[String] = ["random", "greedy", "attack_only"]


## Builds the policy registered under [param name], or null if unknown.
static func create(name: String) -> PartyPolicy:
	match name:
		"random":
			return RandomPolicy.new()
		"greedy":
			return GreedyPolicy.new()
		"attack_only":
			return AttackOnlyPolicy.new()
	return null


func policy_name() -> String:
	return "base"


## Chooses an action for [param actor] (a BattleManager battler dictionary).
## [param rng] is the run's seeded RNG; policies use it for every random choice.
func choose(_manager: BattleManager, _actor: Dictionary, _rng: RandomNumberGenerator) -> Dictionary:
	return pass_action()


static func pass_action() -> Dictionary:
	return { "kind": "pass", "id": "", "target": {} }


## Living enemies as BattleManager target dictionaries.
static func enemy_targets(manager: BattleManager) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var enemies: Array = manager.get_enemies()
	for i in enemies.size():
		var s: BattlerStats = enemies[i]
		if s.is_alive():
			out.append({ "stats": s, "index": i, "is_party": false })
	return out


## Every action [param actor] may take now: a basic attack on each reachable
## enemy, and each affordable kit ability with each valid target (or none).
static func legal_actions(manager: BattleManager, actor: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var targets := enemy_targets(manager)
	for t in targets:
		if manager.can_attack_target(actor, t):
			out.append({ "kind": "attack", "id": "attack", "target": t })
	for ability in HeroRoster.get_abilities(int(actor.index)):
		var id := str(ability.get("id", ""))
		if id.is_empty() or not manager.can_use_ability(actor, id):
			continue
		if manager.ability_needs_target(id):
			for t in targets:
				if manager.can_use_ability_on_target(actor, id, t):
					out.append({ "kind": "ability", "id": id, "target": t })
		else:
			out.append({ "kind": "ability", "id": id, "target": {} })
	return out


## True when [param action] is one BattleManager would accept for [param actor] now.
static func is_legal(manager: BattleManager, actor: Dictionary, action: Dictionary) -> bool:
	match str(action.get("kind", "")):
		"pass":
			return true
		"attack":
			return manager.can_attack_target(actor, action.get("target", {}))
		"ability":
			var id := str(action.get("id", ""))
			var in_kit := false
			for ability in HeroRoster.get_abilities(int(actor.index)):
				if str(ability.get("id", "")) == id:
					in_kit = true
			return in_kit and manager.can_use_ability_on_target(actor, id, action.get("target", {}))
	return false
