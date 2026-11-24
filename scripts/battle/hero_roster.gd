class_name HeroRoster
extends RefCounted
## Squad roster: 3 active heroes today, 2 reserved slots for future tank + healer.
## Phase 3B: hero data lives in [HeroData] resources (resources/heroes/*.tres);
## this class is a thin static loader that keeps the pre-3B API. Balance or art
## changes are .tres edits; adding a hero is a .tres plus one line in HERO_PATHS.

const ACTIVE_PARTY_SIZE := 3
const FULL_ROSTER_SIZE := 5

## Roster order (index = party slot). An explicit list, not a directory scan:
## DirAccess listing is unreliable in exported / web builds.
const HERO_PATHS: Array[String] = [
	"res://resources/heroes/kael.tres",
	"res://resources/heroes/nova.tres",
	"res://resources/heroes/rin.tres",
	# Reserved (enabled = false) until art + kit are ready.
	"res://resources/heroes/brick.tres",
	"res://resources/heroes/sage.tres",
]

static var _heroes: Array[HeroData] = []
## Legacy dictionary view of each hero (HeroData.to_dict()), same order as _heroes.
static var _ROSTER: Array[Dictionary] = []


## Loads HERO_PATHS once. Missing or wrong-typed files are skipped with an error.
static func _ensure_loaded() -> void:
	if not _heroes.is_empty():
		return
	for path in HERO_PATHS:
		var h := load(path) as HeroData
		if h == null:
			push_error("HeroRoster: cannot load HeroData at %s" % path)
			continue
		_heroes.append(h)
		_ROSTER.append(h.to_dict())


## All loaded heroes in roster order.
static func get_all() -> Array[HeroData]:
	_ensure_loaded()
	return _heroes


## The [HeroData] at roster [param index], or null.
static func get_data(index: int) -> HeroData:
	_ensure_loaded()
	if index < 0 or index >= _heroes.size():
		return null
	return _heroes[index]


## Legacy dictionary view of hero [param index] (keys as HeroData.to_dict()), or {}.
static func get_hero(index: int) -> Dictionary:
	_ensure_loaded()
	if index < 0 or index >= _ROSTER.size():
		return {}
	return _ROSTER[index]


static func apply_to_stats(index: int, stats: BattlerStats) -> bool:
	var hero: Dictionary = get_hero(index)
	if hero.is_empty() or not bool(hero.get("enabled", true)):
		return false
	stats.display_name = str(hero.display_name)
	var hero_id := str(hero.get("id", ""))
	stats.battler_id = hero_id if not hero_id.is_empty() else "hero_%d" % index
	stats.max_hp = int(hero.max_hp)
	stats.current_hp = stats.max_hp
	stats.attack = int(hero.attack)
	stats.defense = int(hero.defense)
	stats.speed = int(hero.speed)
	stats.max_energy = int(hero.get("max_energy", 100))
	stats.current_energy = stats.max_energy
	stats.is_party = true
	return true


static func get_abilities(index: int) -> Array:
	var hero: Dictionary = get_hero(index)
	return hero.get("abilities", [])


static func get_role_label(index: int) -> String:
	return str(get_hero(index).get("role_label", ""))


static func get_role_color(index: int) -> Color:
	return Color.from_string(str(get_hero(index).get("role_color", "#ffffff")), Color.WHITE)


static func get_portrait_path(index: int) -> String:
	return str(get_hero(index).get("portrait", ""))


## Roster index of the hero named [param display_name], or -1.
static func find_index_by_name(display_name: String) -> int:
	_ensure_loaded()
	for i in _ROSTER.size():
		if str(_ROSTER[i].get("display_name", "")) == display_name:
			return i
	return -1


static func get_portrait_path_for_name(display_name: String) -> String:
	match display_name:
		"Handler":
			return "res://assets/mission guy.png"
		"Custodian", "Helicopter":
			return "res://assets/enemy_1-removebg-preview.png"
		_:
			_ensure_loaded()
			for hero in _ROSTER:
				if str(hero.get("display_name", "")) == display_name:
					return str(hero.get("portrait", ""))
	return "res://assets/character_placeholder.png"


static func get_story_portrait(display_name: String) -> Texture2D:
	var path: String = get_portrait_path_for_name(display_name)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Per-sprite grade for the character shader: Vector3(saturation, contrast,
## brightness). Defaults 1 / 1 / 0 (no change) for missing keys or bad index.
static func get_shader_grade(index: int) -> Vector3:
	var hero: Dictionary = get_hero(index)
	return Vector3(
		float(hero.get("shader_saturation", 1.0)),
		float(hero.get("shader_contrast", 1.0)),
		float(hero.get("shader_brightness", 0.0)))


## Visible (trimmed) figure height in px at 1920x1080 for hero [param index].
static func get_figure_height(index: int) -> float:
	return float(get_hero(index).get("figure_height", 240.0))


static func get_hideout_heroes() -> Array[Dictionary]:
	## Brick + Sage — story roster, not yet in combat party.
	_ensure_loaded()
	var out: Array[Dictionary] = []
	for i in range(ACTIVE_PARTY_SIZE, _ROSTER.size()):
		out.append(_ROSTER[i])
	return out


static func get_bark(index: int, context: String) -> String:
	var hero: Dictionary = get_hero(index)
	var barks: Dictionary = hero.get("barks", {})
	var lines: Array = barks.get(context, [])
	if lines.is_empty():
		return ""
	return str(lines[randi() % lines.size()])


## Builds the active party's [BattlerStats] (ACTIVE_PARTY_SIZE heroes); a
## generic hero stands in for any roster entry that cannot be applied.
static func build_party() -> Array:
	var party: Array = []
	for i in ACTIVE_PARTY_SIZE:
		var s := BattlerStats.new()
		if not apply_to_stats(i, s):
			s.display_name = "Hero %d" % (i + 1)
			s.battler_id = "hero_%d" % i
			s.max_hp = 80 + i * 10
			s.current_hp = s.max_hp
			s.max_energy = 100
			s.current_energy = 100
			s.attack = 12 + i
			s.defense = 4
			s.speed = 8 + i * 2
			s.is_party = true
		party.append(s)
	return party
