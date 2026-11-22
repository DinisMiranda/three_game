class_name FloorData
extends Resource
## One combat floor of a mission (Phase 3B): banner, background and enemy lineup.

## Banner / battle-log title, e.g. "Floor 1 — Corridor breach".
@export var title: String = ""
## res:// path of the arena background image.
@export_file("*.png", "*.jpg") var background: String = ""
## Enemy type ids (EnemyArchetype.id), in arena slot order. Repeats get " A"/" B" names.
@export var enemies: Array[String] = []


## Legacy dictionary view: { "bg", "title", "enemies" } (enemies as an untyped Array).
func to_dict() -> Dictionary:
	var e: Array = []
	e.append_array(enemies)
	return {"bg": background, "title": title, "enemies": e}
