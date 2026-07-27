extends Node
## Tracks the first mission: three ascents up Meridian Spire (rooftop = floor 3). Started from the world map tower.

enum MissionId { NONE, MERIDIAN_SPIRE }

const MERIDIAN_MAX_FLOOR := 3

## One entry per floor (background + banner). Floor 3 = rooftop / skyline.
const MERIDIAN_FLOORS: Array[Dictionary] = [
	{"bg": "res://assets/andar.jpg", "title": "Floor 1 — Corridor breach"},
	{"bg": "res://assets/andar.jpg", "title": "Floor 2 — Security landing"},
	{"bg": "res://assets/e32ee0a6-a11a-4f0a-b8be-ec9723487b2b.png", "title": "Floor 3 — Rooftop extraction"},
]

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


func finish_meridian_spire() -> void:
	active_mission = MissionId.NONE
	meridian_floor = 1
	meridian_epilogue_pending = false


func mark_rooftop_cleared() -> void:
	meridian_epilogue_pending = true


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


func meridian_has_next_floor_after_clear() -> bool:
	return is_meridian_spire_active() and meridian_floor < MERIDIAN_MAX_FLOOR


func meridian_advance_floor() -> void:
	if meridian_floor < MERIDIAN_MAX_FLOOR:
		meridian_floor += 1
