class_name EnemyRoster
extends RefCounted
## Enemy archetype table (Phase 1B; data in [EnemyArchetype] .tres files since 3B). Every enemy property — name, sprite, attack
## frames, AI profile, ranged flag, stats, scale, tint, boss flag — is keyed by a
## type id, never by arena slot. Floors list type ids in
## FloorData.enemies (resources/missions/*.tres); BattleScene builds from that list.
##
## Stat scaling per floor (unchanged from the pre-roster slot logic):
##   max_hp = base_hp + hp_per_floor * (floor - 1)
##   attack = base_attack + attack_per_floor * (floor - 1)

## AI profile ids read by BattleScene._choose_enemy_action().
const AI_TACTICIAN := 0  ## Focus (HP > 50%) -> Barrage -> Ranged Shot -> attack
const AI_BERSERKER := 1  ## Frenzy below 50% HP, otherwise attack
const AI_SOLDIER := 2    ## Guard below 40% HP, otherwise attack

## Type used when a floor list is empty or a type id is unknown.
const FALLBACK_TYPE := "warden"

## Required keys every archetype must define (checked by tests).
const REQUIRED_FIELDS: Array[String] = [
	"display_name", "idle_sprite", "attack_frames", "ai_profile", "is_ranged",
	"base_hp", "hp_per_floor", "base_attack", "attack_per_floor", "defense",
	"speed", "sprite_scale", "tint", "is_boss",
]

## Archetype files, in type-id order. An explicit list, not a directory scan:
## DirAccess listing is unreliable in exported / web builds. Each file's
## EnemyArchetype.id is its type id.
const ARCHETYPE_PATHS: Array[String] = [
	"res://resources/enemies/warden.tres",
	"res://resources/enemies/hound.tres",
	"res://resources/enemies/custodian.tres",
	# Not placed on a floor yet. Stats chosen close to the warden.
	"res://resources/enemies/enforcer.tres",
]

static var _archetypes: Dictionary = {}  ## type id -> EnemyArchetype
## Legacy dictionary view: type id -> EnemyArchetype.to_dict(). Filled on first use.
static var ARCHETYPES: Dictionary = {}


## Loads ARCHETYPE_PATHS once. Missing, wrong-typed or id-less files are skipped with an error.
static func _ensure_loaded() -> void:
	if not _archetypes.is_empty():
		return
	for path in ARCHETYPE_PATHS:
		var a := load(path) as EnemyArchetype
		if a == null or a.id.is_empty():
			push_error("EnemyRoster: cannot load EnemyArchetype (with an id) at %s" % path)
			continue
		_archetypes[a.id] = a
		ARCHETYPES[a.id] = a.to_dict()


## The [EnemyArchetype] for [param type_id], or null if unknown.
static func get_data(type_id: String) -> EnemyArchetype:
	_ensure_loaded()
	return _archetypes.get(type_id, null)


## True if [param type_id] is a known archetype.
static func has_type(type_id: String) -> bool:
	_ensure_loaded()
	return ARCHETYPES.has(type_id)


## Returns all archetype ids.
static func get_type_ids() -> Array:
	_ensure_loaded()
	return ARCHETYPES.keys()


## Returns the archetype dictionary for [param type_id], or {} if unknown.
static func get_archetype(type_id: String) -> Dictionary:
	_ensure_loaded()
	return ARCHETYPES.get(type_id, {})


## Display name of [param type_id] (falls back to the type id itself).
static func get_display_name(type_id: String) -> String:
	return str(get_archetype(type_id).get("display_name", type_id))


## res:// path of the idle sprite for [param type_id] ("" if unknown).
static func get_idle_sprite_path(type_id: String) -> String:
	return str(get_archetype(type_id).get("idle_sprite", ""))


## res:// paths of the attack frames for [param type_id].
static func get_attack_frame_paths(type_id: String) -> Array:
	return get_archetype(type_id).get("attack_frames", [])


## AI profile id (AI_TACTICIAN / AI_BERSERKER / AI_SOLDIER) for [param type_id].
static func get_ai_profile(type_id: String) -> int:
	return int(get_archetype(type_id).get("ai_profile", AI_SOLDIER))


## Sprite box WIDTH multiplier for [param type_id] (1.0 = default). BattleScene
## widens the slot box with it; figure height comes from get_figure_height().
static func get_sprite_scale(type_id: String) -> float:
	return float(get_archetype(type_id).get("sprite_scale", 1.0))


## Sprite tint for [param type_id] (white = untinted).
static func get_tint(type_id: String) -> Color:
	var c: Variant = get_archetype(type_id).get("tint", Color.WHITE)
	return c if c is Color else Color.WHITE


## Boss aura glow colour for [param type_id]; falls back to the tint.
static func get_aura_color(type_id: String) -> Color:
	var a: Dictionary = get_archetype(type_id)
	var c: Variant = a.get("aura_color", a.get("tint", Color.WHITE))
	return c if c is Color else Color.WHITE


## Per-sprite grade for the character shader: Vector3(saturation, contrast,
## brightness). Defaults 1 / 1 / 0. (Bosses use boss_aura, which has its own grade.)
static func get_shader_grade(type_id: String) -> Vector3:
	var a: Dictionary = get_archetype(type_id)
	return Vector3(
		float(a.get("shader_saturation", 1.0)),
		float(a.get("shader_contrast", 1.0)),
		float(a.get("shader_brightness", 0.0)))


## Visible (trimmed) figure height in px at 1920x1080: 240 for regular enemies,
## 320 for bosses, unless the archetype sets "figure_height".
static func get_figure_height(type_id: String) -> float:
	var a: Dictionary = get_archetype(type_id)
	var fallback: float = 320.0 if bool(a.get("is_boss", false)) else 240.0
	return float(a.get("figure_height", fallback))


## True if [param type_id] is a boss (BattlerSlot.set_boss_visual hook).
static func is_boss(type_id: String) -> bool:
	return bool(get_archetype(type_id).get("is_boss", false))


## Max HP of [param type_id] on [param floor_idx] (1-based).
static func get_max_hp(type_id: String, floor_idx: int) -> int:
	var a: Dictionary = get_archetype(type_id)
	return int(a.get("base_hp", 40)) + int(a.get("hp_per_floor", 0)) * maxi(0, floor_idx - 1)


## Attack of [param type_id] on [param floor_idx] (1-based).
static func get_attack(type_id: String, floor_idx: int) -> int:
	var a: Dictionary = get_archetype(type_id)
	return int(a.get("base_attack", 16)) + int(a.get("attack_per_floor", 0)) * maxi(0, floor_idx - 1)


## Fills [param stats] from archetype [param type_id] scaled for [param floor_idx].
## Unknown ids fall back to FALLBACK_TYPE. [param display_name] overrides the
## archetype name (used for " A"/" B" suffixes). Returns false only if even the
## fallback is missing.
static func apply_to_stats(type_id: String, floor_idx: int, stats: BattlerStats, display_name: String = "") -> bool:
	var tid: String = type_id
	if not has_type(tid):
		push_warning("EnemyRoster: unknown enemy type '%s', using '%s'" % [type_id, FALLBACK_TYPE])
		tid = FALLBACK_TYPE
		display_name = ""
	var a: Dictionary = get_archetype(tid)
	if a.is_empty():
		return false
	stats.enemy_type = tid
	stats.display_name = display_name if not display_name.is_empty() else get_display_name(tid)
	stats.max_hp = get_max_hp(tid, floor_idx)
	stats.current_hp = stats.max_hp
	stats.attack = get_attack(tid, floor_idx)
	stats.defense = int(a.get("defense", 3))
	stats.speed = int(a.get("speed", 5))
	stats.max_energy = int(a.get("max_energy", 100))
	stats.current_energy = stats.max_energy
	stats.is_party = false
	stats.is_ranged = bool(a.get("is_ranged", false))
	return true


## Display names for a fight's type list. A " A"/" B"/... suffix is added only
## when the same type appears more than once in [param type_ids]. Pure function.
## Example: ["warden","hound"] -> ["Spire Warden","Sentry Hound"];
##          ["hound","hound"]  -> ["Sentry Hound A","Sentry Hound B"].
static func build_display_names(type_ids: Array) -> Array[String]:
	var counts: Dictionary = {}
	for t in type_ids:
		counts[t] = int(counts.get(t, 0)) + 1
	var seen: Dictionary = {}
	var out: Array[String] = []
	for t in type_ids:
		var base: String = get_display_name(str(t))
		if int(counts[t]) > 1:
			var n: int = int(seen.get(t, 0))
			seen[t] = n + 1
			out.append("%s %s" % [base, char(65 + n)])
		else:
			out.append(base)
	return out


## Builds the enemy BattlerStats for a fight from [param type_ids] on [param floor_idx].
## An empty list falls back to a single FALLBACK_TYPE enemy.
static func build_enemies(type_ids: Array, floor_idx: int) -> Array:
	var ids: Array = type_ids.duplicate()
	if ids.is_empty():
		ids = [FALLBACK_TYPE]
	var names: Array[String] = build_display_names(ids)
	var out: Array = []
	for i in ids.size():
		var s := BattlerStats.new()
		apply_to_stats(str(ids[i]), floor_idx, s, names[i])
		s.battler_id = "%s_%d" % [str(ids[i]), i]
		out.append(s)
	return out
