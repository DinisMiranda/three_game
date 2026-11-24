extends PartyPolicy
class_name RandomPolicy
## Uniform over all legal actions (attacks and affordable abilities, every valid target).


func policy_name() -> String:
	return "random"


func choose(manager: BattleManager, actor: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var actions := legal_actions(manager, actor)
	if actions.is_empty():
		return pass_action()
	return actions[rng.randi() % actions.size()]
