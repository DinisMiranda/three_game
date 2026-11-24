extends PartyPolicy
class_name AttackOnlyPolicy
## Baseline: basic attack on a uniformly random reachable enemy; never uses abilities.


func policy_name() -> String:
	return "attack_only"


func choose(manager: BattleManager, actor: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var attacks: Array[Dictionary] = []
	for a in legal_actions(manager, actor):
		if a.kind == "attack":
			attacks.append(a)
	if attacks.is_empty():
		return pass_action()
	return attacks[rng.randi() % attacks.size()]
