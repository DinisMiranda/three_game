extends SceneTree
## Headless battle simulator CLI (Phase 4B). See docs/analytics/simulator.md.
##
##   Godot --headless --path . -s res://tools/sim/run_sim.gd -- \
##       --runs 500 --seed 1 --policy greedy --out analytics/data/raw/sim [--deterministic-ids]
##
## Writes <out>/<policy>_seed<seed>.jsonl (replaced on every run), every line
## source="sim", then prints a summary. Exit code 0 on success, 1 on bad args.

const DEFAULTS := { "runs": 500, "seed": 1, "policy": "greedy", "out": "analytics/data/raw/sim" }


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var args := parse_args(OS.get_cmdline_user_args())
	var policy := PartyPolicy.create(str(args.policy))
	if policy == null or int(args.runs) <= 0:
		printerr("run_sim: bad args %s (policies: %s)" % [args, PartyPolicy.NAMES])
		quit(1)
		return
	# Keep the player-facing autoload out of it, without touching saved settings.
	var auto := root.get_node_or_null("/root/Telemetry") as TelemetryService
	if auto != null:
		auto.configure(TelemetryMemorySink.new(), TelemetryService.SOURCE_PLAYER, false)
	var out_dir := resolve_dir(str(args.out))
	var prefix := "%s_seed%d" % [policy.policy_name(), int(args.seed)]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var out_path := out_dir.path_join(prefix + ".jsonl")
	if FileAccess.file_exists(out_path):
		DirAccess.remove_absolute(out_path)
	var sink := TelemetryFileSink.new(out_dir, prefix, 0, 512)
	sink.dated = false
	var t := TelemetryService.new()
	t.configure(sink, TelemetryService.SOURCE_SIM, true)
	t.use_virtual_clock(int(args.seed) if bool(args.deterministic_ids) else -1)
	var started := Time.get_ticks_msec()
	t.start_session()
	var sim := BattleSimulator.new(policy, int(args.seed), t)
	var s := sim.run_many(int(args.runs))
	t.close_session("quit")
	t.free()
	print_summary(s, policy.policy_name(), int(args.seed), out_path, Time.get_ticks_msec() - started)
	quit(0)


## Parses "--key value" pairs and the "--deterministic-ids" switch over [constant DEFAULTS].
static func parse_args(argv: PackedStringArray) -> Dictionary:
	var out := DEFAULTS.duplicate()
	out["deterministic_ids"] = false
	var i := 0
	while i < argv.size():
		var key := argv[i].trim_prefix("--").replace("-", "_")
		if key == "deterministic_ids":
			out[key] = true
		elif out.has(key) and i + 1 < argv.size():
			i += 1
			out[key] = int(argv[i]) if typeof(DEFAULTS[key]) == TYPE_INT else argv[i]
		i += 1
	return out


## Relative paths resolve against the project root; res://, user:// and absolute pass through.
static func resolve_dir(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://").path_join(path)


static func print_summary(s: Dictionary, policy_name: String, seed_value: int, out_path: String, wall_ms: int) -> void:
	print("== Triad Protocol sim: policy=%s seed=%d ==" % [policy_name, seed_value])
	print("runs=%d  completed=%d  failed=%d  abandoned=%d" % [s.runs, s.results.completed, s.results.failed, s.results.abandoned])
	print("floor | battles | wins | win_rate")
	for f in s.floors:
		print("%5d | %7d | %4d | %7.1f%%" % [f.floor, f.battles, f.wins, f.win_rate * 100.0])
	print("battles=%d  mean_turns_per_battle=%.2f  wall_time=%.2fs" % [s.battles, s.mean_turns, wall_ms / 1000.0])
	print("out=%s" % out_path)
