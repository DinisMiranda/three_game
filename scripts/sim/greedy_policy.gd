extends PartyPolicy
class_name GreedyPolicy
## One-step greedy: protect self when low, otherwise the action with the highest
## expected damage this turn, preferring the lowest-HP target on ties.
##
## The kits have no heals and Shield/Guard only target the caster, so "protect
## an ally below the threshold" reduces to protecting the actor itself.

## Use a protective ability when the actor is below this HP fraction.
const PROTECT_BELOW_HP := 0.4
## Protective abilities in preference order (self-targeted).
const PROTECT_ABILITIES: Array[String] = ["shield", "guard"]
## Per-ability hit list: [damage_mult, ignore_defense] per hit on the main target.
const HITS: Dictionary = {
	"attack": [[1.0, false]],
	"slash": [[1.35, false]],
	"grenade": [[1.0, false]],
	"strike": [[1.0, true]],
	"snipe": [[1.8, false]],
	"ranged_shot": [[1.0, false]],
	"barrage": [[1.0, false], [1.0, false]],
	"frenzy": [[1.0, false], [1.0, false]],
}
## Grenade splash multiplier on every other living enemy (BattleManager.perform_ability).
const GRENADE_SPLASH_MULT := 0.45


func policy_name() -> String:
	return "greedy"


func choose(manager: BattleManager, actor: Dictionary, _rng: RandomNumberGenerator) -> Dictionary:
	var actions := legal_actions(manager, actor)
	if actions.is_empty():
		return pass_action()
	var me: BattlerStats = actor.stats
	var hp_pct := float(me.current_hp) / float(maxi(1, me.max_hp))
	if hp_pct < PROTECT_BELOW_HP and me.shield_amount <= 0 and not me.guard_active:
		for id in PROTECT_ABILITIES:
			for a in actions:
				if a.id == id:
					return a
	var best: Dictionary = {}
	var best_ev := -1.0
	for a in actions:
		if not HITS.has(a.id) or (a.target as Dictionary).is_empty():
			continue
		var ev := expected_damage(manager, actor, a.id, a.target)
		var better := ev > best_ev + 0.0001
		var tie := absf(ev - best_ev) <= 0.0001 and not best.is_empty() \
			and (a.target.stats as BattlerStats).current_hp < (best.target.stats as BattlerStats).current_hp
		if better or tie:
			best = a
			best_ev = ev
	return best if not best.is_empty() else actions[0]


## Expected HP removed by [param ability_id] on [param target] this turn,
## including crit odds and (for grenade) splash on the other living enemies.
static func expected_damage(manager: BattleManager, actor: Dictionary, ability_id: String, target: Dictionary) -> float:
	var atk: BattlerStats = actor.stats
	var total := 0.0
	var tgt: BattlerStats = target.stats
	var hp_left := float(tgt.current_hp)
	for hit in HITS.get(ability_id, []):
		var ev := minf(hp_left, hit_ev(atk, tgt, float(hit[0]), bool(hit[1])))
		hp_left -= ev
		total += ev
	if ability_id == "grenade":
		for other in enemy_targets(manager):
			if other.index != target.index:
				var o: BattlerStats = other.stats
				total += minf(float(o.current_hp), hit_ev(atk, o, GRENADE_SPLASH_MULT, false))
	return total


## Expected damage of one hit, mirroring BattleManager.perform_attack and
## BattlerStats.take_damage (guard, shield, defense), crit-weighted.
static func hit_ev(atk: BattlerStats, tgt: BattlerStats, mult: float, ignore_defense: bool) -> float:
	var crit := BattleManager.CRIT_CHANCE
	return (1.0 - crit) * float(_hit(atk, tgt, mult, ignore_defense)) \
		+ crit * float(_hit(atk, tgt, mult * BattleManager.CRIT_DAMAGE_MULT, ignore_defense))


static func _hit(atk: BattlerStats, tgt: BattlerStats, mult: float, ignore_defense: bool) -> int:
	var raw := maxi(1, int(float(atk.get_attack_power()) * mult) - int(tgt.defense / 2.0))
	var incoming := int(ceil(raw * 0.5)) if tgt.guard_active else raw
	var to_hp := maxi(0, incoming - tgt.shield_amount)
	return mini(tgt.current_hp, maxi(0, to_hp - (0 if ignore_defense else tgt.defense)))
