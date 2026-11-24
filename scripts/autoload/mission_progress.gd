extends Node
## Tracks the first mission: three ascents up Meridian Spire (rooftop = floor 3). Started from the world map tower.

enum MissionId { NONE, MERIDIAN_SPIRE }

const MERIDIAN_MAX_FLOOR := 3
## Telemetry mission id (mission_start / floor_reached / mission_end).
const MERIDIAN_MISSION_ID := "meridian_spire"

## Meridian Spire data (Phase 3B): floor titles, backgrounds and enemy lineups
## live in this [MissionData] resource. Floor 3 = rooftop / skyline.
const MERIDIAN_MISSION_PATH := "res://resources/missions/meridian_spire.tres"

## Legacy view, one Dictionary per floor: {"bg", "title", "enemies"} (FloorData.to_dict()).
## "enemies" lists EnemyArchetype type ids, in arena slot order.
static var MERIDIAN_FLOORS: Array[Dictionary] = _load_floors(MERIDIAN_MISSION_PATH)


## Builds the floor dictionaries from the MissionData at [param path] ([] + error if missing).
static func _load_floors(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mission := load(path) as MissionData
	if mission == null:
		push_error("MissionProgress: cannot load MissionData at %s" % path)
		return out
	for f in mission.floors:
		if f != null:
			out.append(f.to_dict())
	return out

var active_mission: MissionId = MissionId.NONE
## Current combat floor (1..3) while Meridian Spire run is active.
var meridian_floor: int = 1
## Set after rooftop victory; battle end screen routes to epilogue instead of menu.
var meridian_epilogue_pending: bool = false
## Story outcome flags (persist until next mission reset).
var package_secured: bool = false
var handler_dead: bool = false
var hideout_select_ready: bool = false
var selected_hideout_id: String = ""
var story_debrief_complete: bool = false
## Highest floor reached this run and whether the rooftop fell (mission_end telemetry).
var _max_floor_reached: int = 0
var _rooftop_cleared: bool = false
## Injected telemetry receiver (simulator). Null = the Telemetry autoload.
var telemetry: TelemetryService = null
## Simulator party policy, logged on mission_start; "" for human play.
var telemetry_policy: String = ""

const HIDEOUTS: Array[Dictionary] = [
	{
		"id": "alley",
		"title": "Rust Alley Safehouse",
		"subtitle": "Smuggler routes · low profile",
		"bg": "res://assets/alley.png",
		"overlay": Color(0.04, 0.05, 0.12, 0.52),
	},
	{
		"id": "grid",
		"title": "North Grid Substation",
		"subtitle": "Brick's bolt-hole · reinforced",
		"bg": "res://assets/background_blue.png",
		"overlay": Color(0.03, 0.06, 0.14, 0.58),
	},
	{
		"id": "docks",
		"title": "South Dock Cellar",
		"subtitle": "Sage's clinic · off the books",
		"bg": "res://assets/escritorio.png",
		"overlay": Color(0.05, 0.05, 0.1, 0.62),
	},
]


func start_meridian_spire() -> void:
	active_mission = MissionId.MERIDIAN_SPIRE
	meridian_floor = 1
	meridian_epilogue_pending = false
	package_secured = false
	handler_dead = false
	hideout_select_ready = false
	selected_hideout_id = ""
	story_debrief_complete = false
	_max_floor_reached = 1
	_rooftop_cleared = false
	var t := _telemetry()
	if t != null:
		t.begin_run()
		var start := { "mission_id": MERIDIAN_MISSION_ID, "max_floor": MERIDIAN_MAX_FLOOR }
		if not telemetry_policy.is_empty():
			start["policy"] = telemetry_policy
		t.track("mission_start", start)
		t.track("floor_reached", { "mission_id": MERIDIAN_MISSION_ID, "floor": 1 })


## Ends the run. [param result] is "completed", "failed" or "abandoned"; empty
## derives it ("completed" once the rooftop is cleared, else "abandoned").
func finish_meridian_spire(result: String = "") -> void:
	if active_mission != MissionId.NONE:
		var t := _telemetry()
		if t != null:
			if result.is_empty():
				result = "completed" if _rooftop_cleared else "abandoned"
			t.track("mission_end", { "mission_id": MERIDIAN_MISSION_ID, "result": result, "max_floor_reached": _max_floor_reached })
			t.end_run()
	active_mission = MissionId.NONE
	meridian_floor = 1
	meridian_epilogue_pending = false


func mark_rooftop_cleared() -> void:
	meridian_epilogue_pending = true
	_rooftop_cleared = true


func mark_hideout_select_ready() -> void:
	package_secured = true
	handler_dead = true
	meridian_epilogue_pending = false
	hideout_select_ready = true
	finish_meridian_spire()


func select_hideout(hideout_id: String) -> void:
	selected_hideout_id = hideout_id


func get_selected_hideout() -> Dictionary:
	for h in HIDEOUTS:
		if str(h.get("id", "")) == selected_hideout_id:
			return h
	return HIDEOUTS[0]


func complete_meridian_story() -> void:
	hideout_select_ready = false
	story_debrief_complete = true
	selected_hideout_id = ""


func is_meridian_spire_active() -> bool:
	return active_mission == MissionId.MERIDIAN_SPIRE


func get_meridian_floor_info() -> Dictionary:
	var idx := clampi(meridian_floor - 1, 0, MERIDIAN_MAX_FLOOR - 1)
	return MERIDIAN_FLOORS[idx]


## Enemy type ids for the current battle. Without an active mission (e.g. the
## battle scene launched on its own) this is floor 1's lineup.
func get_current_floor_enemy_types() -> Array:
	var idx: int = 0
	if is_meridian_spire_active():
		idx = clampi(meridian_floor - 1, 0, MERIDIAN_MAX_FLOOR - 1)
	return MERIDIAN_FLOORS[idx].get("enemies", [])


## Combat floor (1-based) used for enemy stat scaling; 1 when no mission is active.
func get_current_combat_floor() -> int:
	if is_meridian_spire_active():
		return clampi(meridian_floor, 1, MERIDIAN_MAX_FLOOR)
	return 1


func meridian_has_next_floor_after_clear() -> bool:
	return is_meridian_spire_active() and meridian_floor < MERIDIAN_MAX_FLOOR


func meridian_advance_floor() -> void:
	if meridian_floor < MERIDIAN_MAX_FLOOR:
		meridian_floor += 1
		_max_floor_reached = maxi(_max_floor_reached, meridian_floor)
		var t := _telemetry()
		if t != null and is_meridian_spire_active():
			t.track("floor_reached", { "mission_id": MERIDIAN_MISSION_ID, "floor": meridian_floor })


## The injected receiver, else the Telemetry autoload, else null.
func _telemetry() -> TelemetryService:
	if telemetry != null:
		return telemetry
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/Telemetry") as TelemetryService
