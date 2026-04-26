extends Node
## Tracks the first mission: five ascents up Meridian Spire (rooftop = floor 5). Started from the world map tower.

enum MissionId { NONE, MERIDIAN_SPIRE }

const MERIDIAN_MAX_FLOOR := 5

## One entry per floor (background + banner). Floor 5 = rooftop / skyline.
const MERIDIAN_FLOORS: Array[Dictionary] = [
	{"bg": "res://assets/alley.png", "title": "Floor 1 — Street ingress"},
	{"bg": "res://assets/menu_street_bg.png", "title": "Floor 2 — Lobby perimeter"},
	{"bg": "res://assets/escritorio.png", "title": "Floor 3 — Corporate offices"},
	{"bg": "res://assets/background_blue.png", "title": "Floor 4 — Transit deck"},
	{"bg": "res://assets/menu_skyline_bg.png", "title": "Floor 5 — Rooftop extraction"},
]

var active_mission: MissionId = MissionId.NONE
## Current combat floor (1..5) while Meridian Spire run is active.
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
	return MERIDIAN_FLOORS[meridian_floor - 1]


func meridian_has_next_floor_after_clear() -> bool:
	return is_meridian_spire_active() and meridian_floor < MERIDIAN_MAX_FLOOR


func meridian_advance_floor() -> void:
	if meridian_floor < MERIDIAN_MAX_FLOOR:
		meridian_floor += 1
