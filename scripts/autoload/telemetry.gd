extends Node
class_name TelemetryService
## Opt-in, anonymous gameplay telemetry (autoload name: [code]Telemetry[/code]).
##
## [method track] wraps a payload in the versioned envelope documented in
## [code]docs/analytics/event-schema.md[/code], validates it against
## [constant EVENT_SCHEMAS] and hands the JSON line to a [TelemetrySink].
## Invalid events are dropped with a warning, never raised. While the player is
## opted out (the default) [method track] is a no-op and nothing is written.
##
## Gameplay code emits from the data seams (BattleManager, MissionProgress), so
## the headless simulator gets identical events: it builds its own instance via
## [method configure] with a separate sink and [code]source = "sim"[/code].

const SCHEMA_VERSION := 1
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "telemetry"
const SETTINGS_KEY_OPT_IN := "opt_in"
const SOURCE_PLAYER := "player"
const SOURCE_SIM := "sim"

## Field-type tokens used by [constant EVENT_SCHEMAS].
const T_INT := "int"
const T_BOOL := "bool"
const T_STRING := "string"
const T_STRINGS := "string[]"

## Event name -> { "required": {field: type}, "optional": {field: type} }.
## Any field not listed here is rejected (schema drift guard).
const EVENT_SCHEMAS: Dictionary = {
	"session_start": {
		"required": { "build": T_STRING, "headless": T_BOOL },
		"optional": {},
	},
	"session_end": {
		"required": { "reason": T_STRING, "duration_ms": T_INT, "events_emitted": T_INT },
		"optional": {},
	},
	"mission_start": {
		"required": { "mission_id": T_STRING, "max_floor": T_INT },
		"optional": { "policy": T_STRING },
	},
	"floor_reached": {
		"required": { "mission_id": T_STRING, "floor": T_INT },
		"optional": {},
	},
	"mission_end": {
		"required": { "mission_id": T_STRING, "result": T_STRING, "max_floor_reached": T_INT },
		"optional": {},
	},
	"battle_start": {
		"required": {
			"floor": T_INT, "party_ids": T_STRINGS, "enemy_ids": T_STRINGS,
			"enemy_type_ids": T_STRINGS, "party_hp_total": T_INT, "enemy_hp_total": T_INT,
		},
		"optional": { "mission_id": T_STRING, "seed": T_INT, "policy": T_STRING },
	},
	"turn_start": {
		"required": {
			"turn_number": T_INT, "round_number": T_INT, "actor_id": T_STRING,
			"actor_side": T_STRING, "actor_hp": T_INT, "actor_energy": T_INT,
		},
		"optional": {},
	},
	"action": {
		"required": {
			"turn_number": T_INT, "action_seq": T_INT, "hit_index": T_INT,
			"actor_id": T_STRING, "actor_side": T_STRING, "ability_id": T_STRING,
			"target_id": T_STRING, "target_side": T_STRING, "damage": T_INT,
			"hit_kind": T_STRING, "is_crit": T_BOOL, "shield_absorbed": T_INT,
			"energy_cost": T_INT, "target_hp_before": T_INT, "target_hp_after": T_INT,
			"is_kill": T_BOOL,
		},
		"optional": {},
	},
	"battler_down": {
		"required": {
			"turn_number": T_INT, "battler_id": T_STRING, "side": T_STRING,
			"killer_id": T_STRING, "killer_side": T_STRING, "ability_id": T_STRING,
		},
		"optional": {},
	},
	"ability_unaffordable": {
		"required": {
			"turn_number": T_INT, "actor_id": T_STRING, "actor_side": T_STRING,
			"ability_id": T_STRING, "energy_cost": T_INT, "energy_available": T_INT,
		},
		"optional": {},
	},
	"battle_end": {
		"required": {
			"result": T_STRING, "turns": T_INT, "rounds": T_INT, "duration_ms": T_INT,
			"surviving_party": T_STRINGS, "party_hp_remaining": T_INT, "enemies_remaining": T_INT,
		},
		"optional": {},
	},
}

## Envelope keys, in serialisation order.
const ENVELOPE_KEYS: Array[String] = [
	"schema_version", "event_id", "event_name", "event_seq", "ts_utc", "session_id",
	"run_id", "battle_id", "source", "game_version", "platform", "payload",
]

## Anonymous, random per launch. Never derived from hardware or account ids.
var session_id: String = ""
## Current mission attempt, or "" outside a mission (serialised as null).
var run_id: String = ""
## Current battle, or "" outside a battle (serialised as null).
var battle_id: String = ""
var source: String = SOURCE_PLAYER
## Where the opt-in flag persists. "" disables persistence (tests, simulator).
var settings_path: String = SETTINGS_PATH

var _opted_in: bool = false
var _sink: TelemetrySink
var _event_seq: int = 0
var _accepted: int = 0
var _session_start_ms: int = 0
var _session_closed: bool = false
## Deterministic mode (simulator --deterministic-ids): UUIDs come from this RNG
## and time from a virtual clock, so identical runs produce identical bytes.
var _id_rng: RandomNumberGenerator = null
## Virtual clock (ms) used instead of wall time when >= 0. Advances 1 ms per event.
var _virtual_ms: int = -1

## Fixed origin of the virtual clock: 2026-01-01T00:00:00Z.
const VIRTUAL_EPOCH_UNIX := 1767225600


func _init() -> void:
	session_id = new_uuid_v4()
	_session_start_ms = Time.get_ticks_msec()


## Autoload start-up: load the persisted opt-in, default file sink, scene-change flush.
func _ready() -> void:
	if _sink == null:
		_sink = TelemetryFileSink.new()
	if settings_path != "":
		_opted_in = load_opt_in(settings_path)
	var tree := get_tree()
	if tree != null and tree.has_signal("scene_changed"):
		tree.connect("scene_changed", flush)
	if _opted_in:
		_emit_session_start()


## Reconfigures this instance: [param sink] receives events, [param event_source]
## is "player" or "sim", [param opted_in] sets the flag without persisting it.
## Used by tests and the headless simulator.
func configure(sink: TelemetrySink, event_source: String = SOURCE_PLAYER, opted_in: bool = true) -> void:
	_sink = sink
	source = event_source
	settings_path = ""
	_opted_in = opted_in


func get_sink() -> TelemetrySink:
	return _sink


func is_opted_in() -> bool:
	return _opted_in


## Sets and persists the player's choice. Opting in starts a session record;
## opting out flushes what was already accepted and stops collection at once.
func set_opted_in(value: bool) -> void:
	if value == _opted_in:
		return
	if not value:
		flush()
	_opted_in = value
	if settings_path != "":
		save_opt_in(settings_path, value)
	if value:
		_emit_session_start()


## Reads the opt-in flag from [param path] (false when absent: opt-in by default OFF).
static func load_opt_in(path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	return bool(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY_OPT_IN, false))


## Writes the opt-in flag to [param path], keeping any other sections in the file.
static func save_opt_in(path: String, value: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY_OPT_IN, value)
	var err := cfg.save(path)
	if err != OK:
		push_warning("Telemetry: cannot save settings to %s (%s)" % [path, error_string(err)])


## Switches durations (duration_ms) to a virtual clock that advances 1 ms per
## event, so simulator output does not depend on machine speed. With
## [param id_seed] >= 0, UUIDs and ts_utc are also derived from the seed
## (ts_utc = 2026-01-01T00:00:00Z + virtual ms). Simulator only.
func use_virtual_clock(id_seed: int = -1) -> void:
	_virtual_ms = 0
	if id_seed >= 0:
		_id_rng = RandomNumberGenerator.new()
		_id_rng.seed = id_seed
		session_id = _uuid()


## Milliseconds for durations: virtual clock when enabled, else engine ticks.
func now_ms() -> int:
	return _virtual_ms if _virtual_ms >= 0 else Time.get_ticks_msec()


func _uuid() -> String:
	if _id_rng == null:
		return new_uuid_v4()
	var b := PackedByteArray()
	b.resize(16)
	for i in 16:
		b[i] = _id_rng.randi() & 0xff
	return uuid_from_bytes(b)


## Opens a mission attempt; subsequent events carry the new run_id.
func begin_run() -> String:
	run_id = _uuid()
	return run_id


func end_run() -> void:
	run_id = ""


## Opens a battle; subsequent events carry the new battle_id.
func begin_battle() -> String:
	battle_id = _uuid()
	return battle_id


## Closes the battle and flushes (battle_end is a flush point).
func end_battle() -> void:
	battle_id = ""
	flush()


## Validates and records one event. Returns true when the event was accepted.
## Opted out: no-op, returns false. Invalid: warning, dropped, returns false.
func track(event_name: String, payload: Dictionary = {}) -> bool:
	if not _opted_in or _sink == null:
		return false
	var problem := validate(event_name, payload)
	if problem != "":
		push_warning("Telemetry: dropped '%s': %s" % [event_name, problem])
		return false
	_event_seq += 1
	if _virtual_ms >= 0:
		_virtual_ms += 1
	var event := build_envelope(event_name, payload)
	_sink.write_event(event, JSON.stringify(event, "", false))
	_accepted += 1
	return true


## Envelope for [param payload] from the current session/run/battle state (no validation).
func build_envelope(event_name: String, payload: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"event_id": _uuid(),
		"event_name": event_name,
		"event_seq": _event_seq,
		"ts_utc": utc_timestamp_ms() if _id_rng == null else format_utc_ms(VIRTUAL_EPOCH_UNIX * 1000 + _virtual_ms),
		"session_id": session_id,
		"run_id": null if run_id == "" else run_id,
		"battle_id": null if battle_id == "" else battle_id,
		"source": source,
		"game_version": game_version(),
		"platform": OS.get_name(),
		"payload": payload,
	}


## application/config/version, or "dev" when the project sets none.
static func game_version() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	return v if not v.is_empty() else "dev"


## "" when [param payload] satisfies the schema of [param event_name], else the reason.
static func validate(event_name: String, payload: Dictionary) -> String:
	if not EVENT_SCHEMAS.has(event_name):
		return "unknown event"
	var schema: Dictionary = EVENT_SCHEMAS[event_name]
	var required: Dictionary = schema.required
	var optional: Dictionary = schema.optional
	for field in required:
		if not payload.has(field) or payload[field] == null:
			return "missing required field '%s'" % field
		if not _is_type(payload[field], str(required[field])):
			return "field '%s' is not %s" % [field, required[field]]
	for field in payload:
		if required.has(field):
			continue
		if not optional.has(field):
			return "unexpected field '%s'" % field
		if payload[field] != null and not _is_type(payload[field], str(optional[field])):
			return "field '%s' is not %s" % [field, optional[field]]
	return ""


static func _is_type(value: Variant, type_token: String) -> bool:
	match type_token:
		T_INT:
			return typeof(value) == TYPE_INT
		T_BOOL:
			return typeof(value) == TYPE_BOOL
		T_STRING:
			return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
		T_STRINGS:
			if typeof(value) == TYPE_PACKED_STRING_ARRAY:
				return true
			if typeof(value) != TYPE_ARRAY:
				return false
			for item in value:
				if typeof(item) != TYPE_STRING:
					return false
			return true
	return false


func flush() -> void:
	if _sink != null:
		_sink.flush()


## Random RFC 4122 version-4 UUID from the OS CSPRNG.
static func new_uuid_v4() -> String:
	return uuid_from_bytes(Crypto.new().generate_random_bytes(16))


## Formats 16 bytes as a version-4 UUID (sets the version and variant bits).
static func uuid_from_bytes(b: PackedByteArray) -> String:
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


## [param unix_ms] (milliseconds since the Unix epoch) as ISO-8601 UTC with ms.
static func format_utc_ms(unix_ms: int) -> String:
	return "%s.%03dZ" % [Time.get_datetime_string_from_unix_time(unix_ms / 1000, false), unix_ms % 1000]


## Current UTC time as ISO-8601 with milliseconds, e.g. 2026-11-24T14:03:07.512Z.
static func utc_timestamp_ms() -> String:
	var unix := Time.get_unix_time_from_system()
	var secs := int(floor(unix))
	var ms := clampi(int((unix - secs) * 1000.0), 0, 999)
	return "%s.%03dZ" % [Time.get_datetime_string_from_unix_time(secs, false), ms]


## Records session_start (the simulator calls this; the game does it on opt-in).
func start_session() -> void:
	_emit_session_start()


func _emit_session_start() -> void:
	track("session_start", {
		"build": "debug" if OS.is_debug_build() else "release",
		"headless": DisplayServer.get_name() == "headless",
	})


## Records session_end once and flushes. Called on window close and tree exit.
func close_session(reason: String = "quit") -> void:
	if _session_closed:
		return
	_session_closed = true
	track("session_end", {
		"reason": reason,
		"duration_ms": now_ms() - (_session_start_ms if _virtual_ms < 0 else 0),
		"events_emitted": _accepted,
	})
	flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		close_session("quit")


func _exit_tree() -> void:
	close_session("quit")
