class_name TestSim
extends GdUnitTestSuite
## Headless simulator (scripts/sim/): policy legality, determinism, event
## counts and schema validity, and the committed CI sample.

const SAMPLE_PATH := "res://analytics/data/sample/greedy_seed1.jsonl"
const SAMPLE_RUNS := 20


## Wraps a policy and counts any chosen action BattleManager would reject, and
## any pass while a basic attack was available. (Passing with only self-buffs
## legal, e.g. every enemy already down mid-round, is allowed: attack_only does it.)
class LegalityProbe extends PartyPolicy:
	var inner: PartyPolicy
	var decisions: int = 0
	var illegal: int = 0
	var passed_with_options: int = 0

	func _init(wrapped: PartyPolicy) -> void:
		inner = wrapped

	func policy_name() -> String:
		return inner.policy_name()

	func choose(manager: BattleManager, actor: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
		var action := inner.choose(manager, actor, rng)
		decisions += 1
		if not PartyPolicy.is_legal(manager, actor, action):
			illegal += 1
		if action.kind == "pass":
			for a in PartyPolicy.legal_actions(manager, actor):
				if a.kind == "attack":
					passed_with_options += 1
					break
		return action


func _service(deterministic_seed: int = -1) -> TelemetryService:
	var t: TelemetryService = auto_free(TelemetryService.new())
	t.configure(TelemetryMemorySink.new(), TelemetryService.SOURCE_SIM, true)
	t.use_virtual_clock(deterministic_seed)
	return t


func _sim(policy_name: String, seed_value: int, t: TelemetryService, runs: int) -> BattleSimulator:
	var sim := BattleSimulator.new(PartyPolicy.create(policy_name), seed_value, t)
	sim.run_many(runs)
	return sim


func test_every_policy_chooses_only_legal_actions() -> void:
	for policy_name in PartyPolicy.NAMES:
		var probe := LegalityProbe.new(PartyPolicy.create(policy_name))
		var sim := BattleSimulator.new(probe, 3, _service())

		sim.run_many(5)

		assert_int(probe.decisions).is_greater(0)
		assert_int(probe.illegal).override_failure_message("%s chose an illegal action" % policy_name).is_equal(0)
		assert_int(probe.passed_with_options).is_equal(0)


func test_unknown_policy_name_returns_null() -> void:
	assert_object(PartyPolicy.create("nope")).is_null()


func test_same_seed_with_deterministic_ids_is_byte_identical() -> void:
	var a := _service(11)
	var b := _service(11)

	_sim("random", 11, a, 3)
	_sim("random", 11, b, 3)

	var la: PackedStringArray = (a.get_sink() as TelemetryMemorySink).lines
	var lb: PackedStringArray = (b.get_sink() as TelemetryMemorySink).lines
	assert_int(la.size()).is_greater(0)
	assert_array(Array(la)).is_equal(Array(lb))


func test_different_seed_changes_the_data() -> void:
	var a := _service(11)
	var b := _service(11)

	_sim("random", 11, a, 3)
	_sim("random", 12, b, 3)

	assert_array(Array((a.get_sink() as TelemetryMemorySink).lines)).is_not_equal(Array((b.get_sink() as TelemetryMemorySink).lines))


func test_five_runs_emit_expected_counts_and_valid_lines() -> void:
	var t := _service()

	var sim := _sim("greedy", 1, t, 5)

	var sink := t.get_sink() as TelemetryMemorySink
	assert_int(sink.of("mission_start").size()).is_equal(5)
	assert_int(sink.of("mission_end").size()).is_equal(5)
	assert_int(sink.of("battle_start").size()).is_equal(sim.battles)
	assert_int(sink.of("battle_end").size()).is_equal(sim.battles)
	assert_int(sink.of("floor_reached").size()).is_equal(sim.battles)
	for e in sink.events:
		assert_str(TelemetryService.validate(str(e.event_name), e.payload)).is_equal("")
		assert_str(str(e.source)).is_equal("sim")
		assert_array(e.keys()).contains_exactly(TelemetryService.ENVELOPE_KEYS)
	for e in sink.of("battle_start") + sink.of("mission_start"):
		assert_str(str(e.payload.policy)).is_equal("greedy")
	for line in sink.lines:
		assert_bool(JSON.parse_string(line) is Dictionary).is_true()


func test_mission_end_results_add_up_to_runs() -> void:
	var t := _service()

	var sim := _sim("random", 5, t, 5)

	var tally := { "completed": 0, "failed": 0, "abandoned": 0 }
	for e in (t.get_sink() as TelemetryMemorySink).of("mission_end"):
		tally[str(e.payload.result)] += 1
	assert_int(tally.completed + tally.failed + tally.abandoned).is_equal(5)
	assert_dict(tally).is_equal(sim.results)


func test_run_seed_is_distinct_per_run() -> void:
	assert_int(BattleSimulator.run_seed(1, 0)).is_not_equal(BattleSimulator.run_seed(1, 1))
	assert_int(BattleSimulator.run_seed(1, 1)).is_not_equal(BattleSimulator.run_seed(2, 0))


## Godot's JSON parser returns every number as float; whole floats become int
## again (as a typed loader would cast them) before schema validation.
static func _ints_from_json(payload: Dictionary) -> Dictionary:
	var out := {}
	for k in payload:
		var v: Variant = payload[k]
		out[k] = int(v) if typeof(v) == TYPE_FLOAT and v == floorf(v) else v
	return out


func test_committed_sample_validates() -> void:
	assert_bool(FileAccess.file_exists(SAMPLE_PATH)).is_true()
	var lines := FileAccess.get_file_as_string(SAMPLE_PATH).strip_edges().split("\n")
	var missions := 0
	for line in lines:
		var e: Dictionary = JSON.parse_string(line)
		assert_str(TelemetryService.validate(str(e.event_name), _ints_from_json(e.payload))).is_equal("")
		assert_str(str(e.source)).is_equal("sim")
		if e.event_name == "mission_start":
			missions += 1
	assert_int(missions).is_equal(SAMPLE_RUNS)
