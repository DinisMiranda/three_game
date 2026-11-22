class_name HeroData
extends Resource
## One squad hero (Phase 3B). Every balance or presentation value for a hero
## lives in a .tres under resources/heroes/; HeroRoster loads them in the order
## listed in HeroRoster.HERO_PATHS. Editing a .tres needs no code change.

@export_group("Identity")
## Stable id (lowercase), e.g. "kael". Used by code and save data, never shown.
@export var id: String = ""
## Name shown in UI, battle log and story scenes. Also the hero's BattlerStats name.
@export var display_name: String = "Hero"
## Role subtitle shown under the name (e.g. "Grenadier").
@export var role_label: String = ""
## Colour of the role label and role accents.
@export var role_color: Color = Color.WHITE
## False = reserved roster slot (Brick, Sage): shown in the hideout, never in combat.
@export var enabled: bool = true

@export_group("Stats")
## Max HP; the hero starts every battle at full HP.
@export var max_hp: int = 80
## Base attack before buffs.
@export var attack: int = 10
## Flat damage reduction per hit.
@export var defense: int = 4
## Turn order: higher acts earlier each round.
@export var speed: int = 10
## Energy pool for abilities; the hero starts full.
@export var max_energy: int = 100

@export_group("Kit")
## Ability buttons, in order. Each entry: { "id": String (BattleManager ability id), "name": String (button label) }.
@export var abilities: Array[Dictionary] = []
## Battle barks: context ("attack" or an ability id) -> Array of lines; one is picked at random.
@export var barks: Dictionary = {}

@export_group("Visuals")
## res:// path of the portrait / battle sprite.
@export_file("*.png", "*.jpg") var portrait: String = "res://assets/character_placeholder.png"
## Visible (trimmed) figure height in px at 1920x1080.
@export var figure_height: float = 240.0
## Character shader grade: saturation multiplier (1 = unchanged).
@export var shader_saturation: float = 1.0
## Character shader grade: contrast multiplier (1 = unchanged).
@export var shader_contrast: float = 1.0
## Character shader grade: brightness offset (0 = unchanged).
@export var shader_brightness: float = 0.0


## Shader grade as Vector3(saturation, contrast, brightness).
func get_shader_grade() -> Vector3:
	return Vector3(shader_saturation, shader_contrast, shader_brightness)


## Legacy dictionary view (same keys as the pre-3B HeroRoster table).
## "role_color" is a "#rrggbb" string, as before.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"role_label": role_label,
		"role_color": "#" + role_color.to_html(false),
		"enabled": enabled,
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"max_energy": max_energy,
		"portrait": portrait,
		"figure_height": figure_height,
		"shader_saturation": shader_saturation,
		"shader_contrast": shader_contrast,
		"shader_brightness": shader_brightness,
		"abilities": abilities.duplicate(true),
		"barks": barks.duplicate(true),
	}
