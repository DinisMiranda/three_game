extends Node
## Tracks the first mission: three ascents up Meridian Spire (rooftop = floor 3). Started from the world map tower.

enum MissionId { NONE, MERIDIAN_SPIRE }

const MERIDIAN_MAX_FLOOR := 3

## One entry per floor (background + banner). Floor 3 = rooftop / skyline.
const MERIDIAN_FLOORS: Array[Dictionary] = [
	{"bg": "res://assets/andar.jpg", "title": "Floor 1 — Corridor breach"},
	{"bg": "res://assets/andar.jpg", "title": "Floor 2 — Security landing"},
	{"bg": "res://assets/menu_skyline_bg.png", "title": "Floor 3 — Rooftop extraction"},
]

var active_mission: MissionId = MissionId.NONE
## Current combat floor (1..3) while Meridian Spire run is active.
var meridian_floor: int = 1


func start_meridian_spire() -> void:
	active_mission = MissionId.MERIDIAN_SPIRE
	meridian_floor = 1


func finish_meridian_spire() -> void:
	active_mission = MissionId.NONE
	meridian_floor = 1


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
