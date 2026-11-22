class_name HeroRoster
extends RefCounted
## Squad roster: 3 active heroes today, 2 reserved slots for future tank + healer.

const ACTIVE_PARTY_SIZE := 3
const FULL_ROSTER_SIZE := 5

static var _ROSTER: Array[Dictionary] = [
	{
		"id": "kael",
		"display_name": "Kael",
		"role_label": "Grenadier",
		"role_color": "#ff8c3a",
		"enabled": true,
		"max_hp": 92,
		"attack": 14,
		"defense": 5,
		"speed": 9,
		"portrait": "res://assets/sevro_pixel_no_bg-removebg-preview.png",
		# Art-direction Kael fix: low-res, near-monochrome sprite; push saturation and
		# contrast, pull mids down to the dark-armour range of Nova/Rin.
		"figure_height": 240.0,
		"shader_saturation": 1.4,
		"shader_contrast": 1.25,
		"shader_brightness": -0.08,
		"abilities": [
			{ "id": "grenade", "name": "Grenade" },
			{ "id": "guard", "name": "Guard" },
		],
		"barks": {
			"attack": ["Eat this!", "Coming in hot!"],
			"grenade": ["Fire in the hole!", "Brace for impact!"],
			"guard": ["Dig in!", "Cover me!"],
		},
	},
	{
		"id": "nova",
		"display_name": "Nova",
		"role_label": "Skirmisher",
		"role_color": "#5ce1ff",
		"enabled": true,
		"max_hp": 78,
		"attack": 11,
		"defense": 3,
		"speed": 13,
		"portrait": "res://assets/hero 2 no bg.png",
		"figure_height": 240.0,
		"shader_saturation": 1.0,
		"shader_contrast": 1.0,
		"shader_brightness": 0.0,
		"abilities": [
			{ "id": "fly", "name": "Fly" },
			{ "id": "snipe", "name": "Snipe" },
		],
		"barks": {
			"attack": ["On target.", "Keep them busy down there."],
			"fly": ["I've got the high ground!", "Up and out of reach."],
			"snipe": ["One shot.", "Dropping them."],
		},
	},
	{
		"id": "rin",
		"display_name": "Rin",
		"role_label": "Field Support",
		"role_color": "#9dff7a",
		"enabled": true,
		"max_hp": 86,
		"attack": 10,
		"defense": 5,
		"speed": 10,
		"portrait": "res://assets/hero 3 no bg copy.png",
		"figure_height": 240.0,
		"shader_saturation": 1.0,
		"shader_contrast": 1.0,
		"shader_brightness": 0.0,
		"abilities": [
			{ "id": "strike", "name": "Strike" },
			{ "id": "shield", "name": "Shield" },
		],
		"barks": {
			"attack": ["Opening the lane.", "Hold formation."],
			"strike": ["Through the gap!", "Armor won't save you."],
			"shield": ["Shield up!", "I've got you covered."],
		},
	},
	# Reserved — enable when art + kit are ready (FULL_ROSTER_SIZE = 5).
	{
		"id": "brick",
		"display_name": "Brick",
		"role_label": "Frontliner",
		"role_color": "#c9a0ff",
		"enabled": false,
		"max_hp": 120,
		"attack": 11,
		"defense": 9,
		"speed": 7,
		"portrait": "res://assets/character_placeholder.png",
		"figure_height": 240.0,
		"shader_saturation": 1.0,
		"shader_contrast": 1.0,
		"shader_brightness": 0.0,
		"abilities": [
			{ "id": "guard", "name": "Guard" },
			{ "id": "strike", "name": "Strike" },
		],
		"barks": {},
	},
	{
		"id": "sage",
		"display_name": "Sage",
		"role_label": "Medic",
		"role_color": "#7dffb8",
		"enabled": false,
		"max_hp": 72,
		"attack": 8,
		"defense": 4,
		"speed": 11,
		"portrait": "res://assets/character_placeholder.png",
		"figure_height": 240.0,
		"shader_saturation": 1.0,
		"shader_contrast": 1.0,
		"shader_brightness": 0.0,
		"abilities": [
			{ "id": "shield", "name": "Shield" },
			{ "id": "strike", "name": "Strike" },
		],
		"barks": {},
	},
]


static func get_hero(index: int) -> Dictionary:
	if index < 0 or index >= _ROSTER.size():
		return {}
	return _ROSTER[index]


static func apply_to_stats(index: int, stats: BattlerStats) -> bool:
	var hero: Dictionary = get_hero(index)
	if hero.is_empty() or not bool(hero.get("enabled", true)):
		return false
	stats.display_name = str(hero.display_name)
	stats.max_hp = int(hero.max_hp)
	stats.current_hp = stats.max_hp
	stats.attack = int(hero.attack)
	stats.defense = int(hero.defense)
	stats.speed = int(hero.speed)
	stats.max_energy = 100
	stats.current_energy = 100
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
