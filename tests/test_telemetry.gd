class_name TestTelemetry
extends GdUnitTestSuite
## Unit tests for TelemetryService (scripts/autoload/telemetry.gd), its sinks
## (scripts/telemetry/) and the BattleManager instrumentation.

const UUID_V4 := "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
const TS_UTC_MS := "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$"
const VALID_TURN := {
	"turn_number": 1, "round_number": 1, "actor_id": "kael", "actor_side": "party",
	"actor_hp": 80, "actor_energy": 100,
}

var _svc: TelemetryService
var _sink: TelemetryMemorySink
var _root: Node
var _manager: BattleManager
var _tmp_dir: String = ""


func before_test() -> void:
	_svc = TelemetryService.new()
	_sink = TelemetryMemorySink.new()
	_svc.configure(_sink, TelemetryService.SOURCE_SIM, true)
	_root = Node.new()
	_manager = BattleManager.new()
	_manager.telemetry = _svc
	_root.add_child(_manager)


func after_test() -> void:
	_root.free()
	_svc.free()
	if _tmp_dir != "":
		_remove_dir(_tmp_dir)
		_tmp_dir = ""


# --- Fixtures ---

static func _matches(pattern: String, text: String) -> bool:
	var re := RegEx.new()
	re.compile(pattern)
	return re.search(text) != null


static func _battler(id: String, is_party: bool, hp: int, attack: int, speed: int) -> BattlerStats:
	var s := BattlerStats.new()
	s.battler_id = id
	s.display_name = id
	s.is_party = is_party
	s.max_hp = hp
	s.current_hp = hp
	s.attack = attack
	s.defense = 0
	s.speed = speed
	return s


func _new_tmp_dir() -> String:
	_tmp_dir = "user://test_telemetry_%s" % TelemetryService.new_uuid_v4()
	return _tmp_dir


static func _remove_dir(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	for f in DirAccess.get_files_at(dir_path):
		DirAccess.remove_absolute(dir_path.path_join(f))
	DirAccess.remove_absolute(dir_path)


## Seed whose first randf() is below CRIT_CHANCE, found deterministically.
static func _crit_seed() -> int:
	for candidate in range(1, 1000):
		var r := RandomNumberGenerator.new()
		r.seed = candidate
		if r.randf() < BattleManager.CRIT_CHANCE:
			return candidate
	return -1


# --- Envelope ---

func test_envelope_has_all_keys_and_formats() -> void:
	_svc.begin_battle()
	assert_bool(_svc.track("turn_start", VALID_TURN)).is_true()
	var e: Dictionary = _sink.events[0]
	assert_array(e.keys()).contains_exactly(TelemetryService.ENVELOPE_KEYS)
	assert_int(int(e.schema_version)).is_equal(TelemetryService.SCHEMA_VERSION)
	assert_str(str(e.event_name)).is_equal("turn_start")
	assert_int(int(e.event_seq)).is_equal(1)
	assert_bool(_matches(UUID_V4, str(e.event_id))).is_true()
	assert_bool(_matches(UUID_V4, str(e.session_id))).is_true()
	assert_bool(_matches(UUID_V4, str(e.battle_id))).is_true()
	assert_bool(_matches(TS_UTC_MS, str(e.ts_utc))).is_true()
	assert_object(e.run_id).is_null()
	assert_str(str(e.source)).is_equal("sim")
	assert_str(str(e.platform)).is_equal(OS.get_name())
	assert_dict(e.payload).is_equal(VALID_TURN)


func test_event_ids_unique_and_seq_monotonic() -> void:
	_svc.track("turn_start", VALID_TURN)
	_svc.track("turn_start", VALID_TURN)
	assert_str(str(_sink.events[0].event_id)).is_not_equal(str(_sink.events[1].event_id))
	assert_int(int(_sink.events[1].event_seq)).is_equal(2)


func test_run_and_battle_ids_clear_after_end() -> void:
	_svc.begin_run()
	_svc.begin_battle()
	_svc.end_battle()
	_svc.end_run()
	_svc.track("turn_start", VALID_TURN)
	assert_object(_sink.events[0].battle_id).is_null()
	assert_object(_sink.events[0].run_id).is_null()
	assert_int(_sink.flush_count).is_equal(1)


# --- Validation ---

func test_unknown_event_dropped() -> void:
	assert_bool(_svc.track("not_an_event", {})).is_false()
	assert_int(_sink.events.size()).is_equal(0)


func test_missing_required_field_dropped() -> void:
	var p := VALID_TURN.duplicate()
	p.erase("actor_id")
	assert_bool(_svc.track("turn_start", p)).is_false()
	assert_str(TelemetryService.validate("turn_start", p)).contains("actor_id")
	assert_int(_sink.events.size()).is_equal(0)


func test_wrong_type_and_unexpected_field_dropped() -> void:
	var wrong := VALID_TURN.duplicate()
	wrong["turn_number"] = "1"
	var extra := VALID_TURN.duplicate()
	extra["player_name"] = "nope"
	assert_bool(_svc.track("turn_start", wrong)).is_false()
	assert_bool(_svc.track("turn_start", extra)).is_false()
	assert_int(_sink.events.size()).is_equal(0)


func test_optional_field_may_be_absent() -> void:
	var p := {
		"floor": 1, "party_ids": ["kael"], "enemy_ids": ["drone_0"], "enemy_type_ids": ["drone"],
		"party_hp_total": 80, "enemy_hp_total": 40,
	}
	assert_str(TelemetryService.validate("battle_start", p)).is_equal("")
	p["seed"] = 7
	assert_str(TelemetryService.validate("battle_start", p)).is_equal("")


# --- Opt-in / opt-out ---

func test_opted_out_writes_nothing() -> void:
	var dir := _new_tmp_dir()
	var file_sink := TelemetryFileSink.new(dir, "events", TelemetryFileSink.DEFAULT_MAX_BYTES, 1)
	_svc.configure(file_sink, TelemetryService.SOURCE_PLAYER, false)
	assert_bool(_svc.track("turn_start", VALID_TURN)).is_false()
	_svc.flush()
	assert_bool(DirAccess.dir_exists_absolute(dir)).is_false()


func test_opt_in_persists_and_defaults_off() -> void:
	var dir := _new_tmp_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("settings.cfg")
	assert_bool(TelemetryService.load_opt_in(path)).is_false()
	TelemetryService.save_opt_in(path, true)
	assert_bool(TelemetryService.load_opt_in(path)).is_true()


# --- File sink ---

func test_jsonl_lines_are_valid_json_with_envelope() -> void:
	var dir := _new_tmp_dir()
	var file_sink := TelemetryFileSink.new(dir)
	_svc.configure(file_sink, TelemetryService.SOURCE_PLAYER, true)
	_svc.track("turn_start", VALID_TURN)
	_svc.track("session_end", { "reason": "quit", "duration_ms": 10, "events_emitted": 1 })
	assert_int(file_sink.pending_lines()).is_equal(2)
	_svc.flush()
	var text := FileAccess.get_file_as_string(file_sink.current_path())
	var lines := text.strip_edges().split("\n")
	assert_int(lines.size()).is_equal(2)
	for line in lines:
		var parsed: Variant = JSON.parse_string(line)
		assert_bool(parsed is Dictionary).is_true()
		for key in TelemetryService.ENVELOPE_KEYS:
			assert_bool((parsed as Dictionary).has(key)).is_true()


func test_file_sink_rotates_over_max_bytes() -> void:
	var dir := _new_tmp_dir()
	var file_sink := TelemetryFileSink.new(dir, "events", 50, 1)
	file_sink.write_event({}, "x".repeat(60))
	var first := file_sink.current_path()
	assert_bool(first.ends_with("_1.jsonl")).is_true()
	file_sink.write_event({}, "y")
	assert_bool(FileAccess.file_exists(first)).is_true()
	assert_int(DirAccess.get_files_at(dir).size()).is_equal(2)


# --- BattleManager instrumentation ---

## Enemy (faster) hits the hero, the hero kills the enemy, the round ends: win.
func test_scripted_battle_emits_expected_sequence() -> void:
	var hero := _battler("kael", true, 80, 100, 5)
	var enemy := _battler("drone_0", false, 30, 10, 20)
	enemy.enemy_type = "drone"
	_manager.setup_battle([hero], [enemy], { "floor": 2, "mission_id": "meridian_spire" })
	var enemy_turn := _manager.get_current_battler()
	var party: Array = _manager.get_party()
	var enemy_dmg := _manager.perform_attack(enemy_turn, { "stats": party[0], "index": 0, "is_party": true }, { "allow_crit": false })
	_manager.advance_turn()
	var hero_turn := _manager.get_current_battler()
	var enemies: Array = _manager.get_enemies()
	_manager.perform_attack(hero_turn, { "stats": enemies[0], "index": 0, "is_party": false })
	_manager.advance_turn()

	assert_array(Array(_sink.names())).contains_exactly([
		"battle_start", "turn_start", "action", "turn_start", "action", "battler_down", "battle_end",
	])
	var start: Dictionary = _sink.of("battle_start")[0].payload
	assert_int(int(start.floor)).is_equal(2)
	assert_array(start.party_ids).contains_exactly(["kael"])
	assert_array(start.enemy_type_ids).contains_exactly(["drone"])
	var actions := _sink.of("action")
	var hit: Dictionary = actions[0].payload
	assert_str(str(hit.actor_id)).is_equal("drone_0")
	assert_str(str(hit.ability_id)).is_equal("attack")
	assert_int(int(hit.damage)).is_equal(enemy_dmg)
	assert_int(int(hit.target_hp_before) - int(hit.target_hp_after)).is_equal(enemy_dmg)
	assert_bool(bool(hit.is_crit)).is_false()
	assert_bool(bool(hit.is_kill)).is_false()
	var kill: Dictionary = actions[1].payload
	assert_bool(bool(kill.is_kill)).is_true()
	assert_int(int(kill.target_hp_after)).is_equal(0)
	assert_int(int(kill.turn_number)).is_equal(2)
	var down: Dictionary = _sink.of("battler_down")[0].payload
	assert_str(str(down.battler_id)).is_equal("drone_0")
	assert_str(str(down.killer_id)).is_equal("kael")
	var end: Dictionary = _sink.of("battle_end")[0].payload
	assert_str(str(end.result)).is_equal("win")
	assert_int(int(end.turns)).is_equal(2)
	assert_array(end.surviving_party).contains_exactly(["kael"])
	var bid: Variant = _sink.events[0].battle_id
	for e in _sink.events:
		assert_str(str(e.battle_id)).is_equal(str(bid))


func test_seeded_crit_is_recorded() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = _crit_seed()
	_manager.rng = r
	var hero := _battler("kael", true, 80, 20, 20)
	var enemy := _battler("drone_0", false, 200, 1, 1)
	_manager.setup_battle([hero], [enemy])
	_manager.perform_attack(_manager.get_current_battler(), { "stats": _manager.get_enemies()[0], "index": 0, "is_party": false })
	var hit: Dictionary = _sink.of("action")[0].payload
	assert_bool(bool(hit.is_crit)).is_true()
	assert_str(str(hit.hit_kind)).is_equal("crit")
	assert_int(int(_sink.of("battle_start")[0].payload.seed)).is_equal(r.seed)


func test_multi_hit_ability_shares_action_seq_and_charges_once() -> void:
	var hero := _battler("brick", true, 80, 20, 20)
	var e0 := _battler("drone_0", false, 200, 1, 1)
	var e1 := _battler("drone_1", false, 200, 1, 1)
	_manager.setup_battle([hero], [e0, e1])
	_manager.perform_ability(_manager.get_current_battler(), "grenade", { "stats": _manager.get_enemies()[0], "index": 0, "is_party": false })
	var actions := _sink.of("action")
	assert_int(actions.size()).is_equal(2)
	assert_int(int(actions[0].payload.action_seq)).is_equal(int(actions[1].payload.action_seq))
	assert_int(int(actions[1].payload.hit_index)).is_equal(1)
	assert_int(int(actions[0].payload.energy_cost)).is_equal(_manager.get_ability_cost("grenade"))
	assert_int(int(actions[1].payload.energy_cost)).is_equal(0)
	assert_str(str(actions[1].payload.target_id)).is_equal("drone_1")


func test_self_ability_and_unaffordable() -> void:
	var hero := _battler("sage", true, 80, 10, 20)
	_manager.setup_battle([hero], [_battler("drone_0", false, 50, 1, 1)])
	var current := _manager.get_current_battler()
	assert_bool(_manager.perform_ability(current, "guard")).is_true()
	var fx: Dictionary = _sink.of("action")[0].payload
	assert_str(str(fx.hit_kind)).is_equal("effect")
	assert_str(str(fx.target_id)).is_equal("sage")
	current.stats.current_energy = 0
	assert_bool(_manager.perform_ability(current, "shield")).is_false()
	var denied: Dictionary = _sink.of("ability_unaffordable")[0].payload
	assert_str(str(denied.ability_id)).is_equal("shield")
	assert_int(int(denied.energy_available)).is_equal(0)


func test_leaving_mid_battle_records_quit() -> void:
	_manager.setup_battle([_battler("kael", true, 80, 10, 20)], [_battler("drone_0", false, 50, 1, 1)])
	_manager.setup_battle([_battler("kael", true, 80, 10, 20)], [_battler("drone_0", false, 50, 1, 1)])
	var ends := _sink.of("battle_end")
	assert_int(ends.size()).is_equal(1)
	assert_str(str(ends[0].payload.result)).is_equal("quit")


## Party of two (fast, slow) vs one enemy that dies mid-round: the downed
## enemy's remaining slot is not a turn.
func test_downed_battler_slot_is_not_a_turn() -> void:
	var hero := _battler("kael", true, 80, 100, 20)
	var enemy := _battler("drone_0", false, 30, 1, 10)
	_manager.setup_battle([hero, _battler("nova", true, 80, 10, 1)], [enemy])
	_manager.perform_attack(_manager.get_current_battler(), { "stats": _manager.get_enemies()[0], "index": 0, "is_party": false })
	_manager.advance_turn()
	assert_int(_sink.of("turn_start").size()).is_equal(1)

	_manager.advance_turn()
	assert_int(_sink.of("turn_start").size()).is_equal(2)
	assert_str(str(_sink.of("turn_start")[1].payload.actor_id)).is_equal("nova")


func test_no_receiver_is_silent() -> void:
	var lone := BattleManager.new()
	lone.setup_battle([_battler("kael", true, 80, 10, 20)], [_battler("drone_0", false, 50, 1, 1)])
	lone.perform_attack(lone.get_current_battler(), { "stats": lone.get_enemies()[0], "index": 0, "is_party": false })
	assert_int(_sink.events.size()).is_equal(0)
	lone.free()
