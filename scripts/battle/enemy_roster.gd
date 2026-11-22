class_name EnemyRoster
extends RefCounted
## Enemy archetype table (Phase 1B). Every enemy property — name, sprite, attack
## frames, AI profile, ranged flag, stats, scale, tint, boss flag — is keyed by a
## type id, never by arena slot. Floors list type ids in
## MissionProgress.MERIDIAN_FLOORS[i].enemies; BattleScene builds from that list.
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

static var ARCHETYPES: Dictionary = {
	"warden": {
		"display_name": "Spire Warden",
		"idle_sprite": "res://assets/enemy_1-removebg-preview.png",
		"attack_frames": [
			"res://assets/enemy_1_attack_animantion_part1-removebg-preview.png",
			"res://assets/enemy1_attack_animation_part2-removebg-preview.png",
		],
		"ai_profile": AI_TACTICIAN,
		"is_ranged": true,
		"base_hp": 40,
		"hp_per_floor": 10,
		"base_attack": 16,
		"attack_per_floor": 2,
		"defense": 3,
		"speed": 5,
		"sprite_scale": 1.0,
		"tint": Color.WHITE,
		"is_boss": false,
	},
	"hound": {
		"display_name": "Sentry Hound",
		"idle_sprite": "res://assets/enemy_2-removebg-preview.png",
		"attack_frames": [
			"res://assets/enemy_2_attack_animation.png",
		],
		"ai_profile": AI_BERSERKER,
		"is_ranged": false,
		"base_hp": 50,
		"hp_per_floor": 10,
		"base_attack": 18,
		"attack_per_floor": 2,
		"defense": 3,
		"speed": 8,
		"sprite_scale": 1.0,
		"tint": Color.WHITE,
		"is_boss": false,
	},
	"custodian": {
		"display_name": "Custodian Unit",
		"idle_sprite": "res://assets/enemy_1-removebg-preview.png",
		"attack_frames": [
			"res://assets/enemy_1_attack_animantion_part1-removebg-preview.png",
			"res://assets/enemy1_attack_animation_part2-removebg-preview.png",
		],
		"ai_profile": AI_TACTICIAN,
		# Not ranged today (pre-roster logic was `floor < 3`); kept as-is, no rebalance.
		"is_ranged": false,
		"base_hp": 55,
		"hp_per_floor": 10,
		"base_attack": 20,
		"attack_per_floor": 2,
		"defense": 3,
		"speed": 7,
		"sprite_scale": 1.3,
		"tint": Color(1.0, 0.72, 0.6),
		"aura_color": Color(1.0, 0.3, 0.08),
		"is_boss": true,
	},
	# Not placed on a floor yet. Stats chosen close to the warden.
	"enforcer": {
		"display_name": "Meridian Enforcer",
		"idle_sprite": "res://assets/inimigo_soldado.png",
		"attack_frames": [
			"res://assets/inimigo_soldado_ataque.png",
		],
		"ai_profile": AI_SOLDIER,
		"is_ranged": false,
		"base_hp": 45,
		"hp_per_floor": 10,
		"base_attack": 16,
		"attack_per_floor": 2,
		"defense": 4,
		"speed": 6,
		"sprite_scale": 1.0,
		"tint": Color.WHITE,
		"is_boss": false,
	},
}


## True if [param type_id] is a known archetype.
static func has_type(type_id: String) -> bool:
	return ARCHETYPES.has(type_id)


## Returns all archetype ids.
static func get_type_ids() -> Array:
	return ARCHETYPES.keys()


## Returns the archetype dictionary for [param type_id], or {} if unknown.
static func get_archetype(type_id: String) -> Dictionary:
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


## Sprite size multiplier for [param type_id] (1.0 = default size).
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
	stats.max_energy = 100
	stats.current_energy = 100
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
		out.append(s)
	return out
