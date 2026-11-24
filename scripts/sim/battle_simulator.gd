extends RefCounted
class_name BattleSimulator
## Headless Meridian Spire runs: the party follows a [PartyPolicy], enemies use
## [EnemyAI], and BattleManager + a private MissionProgress instance emit the
## same telemetry the game does, into an injected [TelemetryService].
##
## No scenes, no autoload state: each run builds its own BattleManager and
## MissionProgress. Run [i] is seeded with [method run_seed]([member base_seed], i),
## and that one RNG drives crit rolls, enemy targeting and the policy.

const MissionProgressScript := preload("res://scripts/autoload/mission_progress.gd")
## A battle still running after this many manager turns is recorded as quit.
const MAX_TURNS_PER_BATTLE := 400
## Multiplier used to derive per-run seeds (prime, keeps runs well apart).
const RUN_SEED_STRIDE := 1000003

var policy: PartyPolicy
var base_seed: int
var telemetry: TelemetryService

## Aggregates for the summary: battles/wins per floor, turns, mission results.
var runs: int = 0
var floor_battles: Dictionary = {}
var floor_wins: Dictionary = {}
var battles: int = 0
var turns_total: int = 0
var results: Dictionary = { "completed": 0, "failed": 0, "abandoned": 0 }

var _ended: bool = false
var _party_won: bool = false


func _init(party_policy: PartyPolicy, seed_value: int, receiver: TelemetryService) -> void:
	policy = party_policy
	base_seed = seed_value
	telemetry = receiver


## Seed for run [param run_index]: stable, distinct per run, independent of run order.
static func run_seed(seed_value: int, run_index: int) -> int:
	return seed_value * RUN_SEED_STRIDE + run_index


## Plays runs [0, [param count]) and returns the aggregates as a Dictionary.
func run_many(count: int) -> Dictionary:
	for i in count:
		run_mission(i)
	telemetry.flush()
	return summary()


## Plays one full mission (floors 1..3, ends on defeat or after the rooftop).
## Returns the mission_end result: "completed", "failed" or "abandoned".
func run_mission(run_index: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed(base_seed, run_index)
	var mp: Node = MissionProgressScript.new()
	mp.telemetry = telemetry
	mp.telemetry_policy = policy.policy_name()
	var bm := BattleManager.new()
	bm.telemetry = telemetry
	bm.rng = rng
	bm.battle_ended.connect(_on_battle_ended)
	var ai := EnemyAI.new(bm, rng)
	mp.start_meridian_spire()
	var party: Array = HeroRoster.build_party()
	var result := ""
	while result.is_empty():
		var floor_num: int = mp.get_current_combat_floor()
		var enemies: Array = EnemyRoster.build_enemies(mp.get_current_floor_enemy_types(), floor_num)
		bm.setup_battle(party, enemies, {
			"floor": floor_num, "mission_id": mp.MERIDIAN_MISSION_ID, "policy": policy.policy_name(),
		})
		var outcome := _play_battle(bm, ai, rng)
		battles += 1
		turns_total += bm.get_turn_number()
		floor_battles[floor_num] = int(floor_battles.get(floor_num, 0)) + 1
		if outcome == "win":
			floor_wins[floor_num] = int(floor_wins.get(floor_num, 0)) + 1
			if mp.meridian_has_next_floor_after_clear():
				mp.meridian_advance_floor()
				party = bm.get_party()
				for s in party:
					(s as BattlerStats).restore_for_new_floor()
			else:
				mp.mark_rooftop_cleared()
				result = "completed"
		else:
			result = "failed" if outcome == "loss" else "abandoned"
	mp.finish_meridian_spire(result)
	runs += 1
	results[result] = int(results.get(result, 0)) + 1
	bm.free()
	mp.free()
	return result


## Turn loop mirroring BattleScene: skip downed battlers, party -> policy,
## enemies -> EnemyAI. Returns "win", "loss" or "quit" (turn cap).
func _play_battle(bm: BattleManager, ai: EnemyAI, rng: RandomNumberGenerator) -> String:
	_ended = false
	for _i in MAX_TURNS_PER_BATTLE:
		if _ended:
			break
		var cur: Dictionary = bm.get_current_battler()
		if cur.is_empty():
			break
		if cur.stats.is_alive():
			if cur.is_party:
				_party_turn(bm, cur, rng)
			else:
				_enemy_turn(bm, ai, cur)
		bm.advance_turn()
	if not _ended:
		bm.abandon_battle()
		return "quit"
	return "win" if _party_won else "loss"


func _party_turn(bm: BattleManager, actor: Dictionary, rng: RandomNumberGenerator) -> void:
	var action := policy.choose(bm, actor, rng)
	match str(action.get("kind", "pass")):
		"attack":
			bm.perform_attack(actor, action.target)
		"ability":
			bm.perform_ability(actor, str(action.id), action.target)


## Same decision path as BattleScene._perform_enemy_action.
func _enemy_turn(bm: BattleManager, ai: EnemyAI, actor: Dictionary) -> void:
	var action: Dictionary = ai.choose_for(actor)
	var ability_id := str(action.get("id", "attack"))
	var target: Dictionary = {}
	if bool(action.get("needs_target", false)):
		target = ai.pick_target(actor, ability_id)
		if target.is_empty():
			return
	if action.get("kind", "") == "ability":
		bm.perform_ability(actor, ability_id, target)
	else:
		bm.perform_attack(actor, target)


func _on_battle_ended(party_wins: bool) -> void:
	_ended = true
	_party_won = party_wins


## { runs, results, battles, mean_turns, floors: [{ floor, battles, wins, win_rate }] }
func summary() -> Dictionary:
	var floors: Array = []
	var keys: Array = floor_battles.keys()
	keys.sort()
	for f in keys:
		var n := int(floor_battles[f])
		var w := int(floor_wins.get(f, 0))
		floors.append({ "floor": f, "battles": n, "wins": w, "win_rate": float(w) / float(maxi(1, n)) })
	return {
		"runs": runs, "results": results.duplicate(), "battles": battles,
		"mean_turns": float(turns_total) / float(maxi(1, battles)), "floors": floors,
	}
