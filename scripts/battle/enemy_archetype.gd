class_name EnemyArchetype
extends Resource
## One enemy archetype (Phase 3B). Every enemy property is keyed by type id
## (never arena slot) and lives in a .tres under resources/enemies/; EnemyRoster
## loads the files listed in EnemyRoster.ARCHETYPE_PATHS.
##
## Stat scaling per floor (1-based):
##   max_hp = base_hp + hp_per_floor * (floor - 1)
##   attack = base_attack + attack_per_floor * (floor - 1)

@export_group("Identity")
## Type id used by floor lineups (FloorData.enemies) and BattlerStats.enemy_type.
@export var id: String = ""
## Name shown in UI and the battle log (" A"/" B" is appended for duplicates).
@export var display_name: String = "Enemy"
## True for bosses: aura shader, info plate (BattlerSlot.set_boss_visual).
@export var is_boss: bool = false

@export_group("Behaviour")
## AI profile read by EnemyAI (values match EnemyRoster.AI_TACTICIAN / AI_BERSERKER / AI_SOLDIER).
@export_enum("Tactician", "Berserker", "Soldier") var ai_profile: int = 2
## Ranged attackers can hit flying targets; melee cannot.
@export var is_ranged: bool = false

@export_group("Stats")
## Max HP on floor 1.
@export var base_hp: int = 40
## Max HP added per floor above 1.
@export var hp_per_floor: int = 10
## Attack on floor 1.
@export var base_attack: int = 16
## Attack added per floor above 1.
@export var attack_per_floor: int = 2
## Flat damage reduction per hit (does not scale).
@export var defense: int = 3
## Turn order: higher acts earlier each round (does not scale).
@export var speed: int = 5
## Energy pool for abilities; starts full.
@export var max_energy: int = 100

@export_group("Sprites")
## res:// path of the idle sprite.
@export_file("*.png") var idle_sprite: String = ""
## res:// paths of the attack animation frames, in play order (at least one).
@export var attack_frames: Array[String] = []

@export_group("Visuals")
## Sprite box WIDTH multiplier (1 = default); height comes from figure_height.
@export var sprite_scale: float = 1.0
## Sprite tint (white = untinted).
@export var tint: Color = Color.WHITE
## If true, the boss aura uses aura_color; otherwise it falls back to tint.
@export var has_aura_color: bool = false
## Boss aura glow colour (only used when has_aura_color is true).
@export var aura_color: Color = Color.WHITE
## Visible (trimmed) figure height in px at 1920x1080.
@export var figure_height: float = 240.0
## Character shader grade: saturation multiplier (1 = unchanged).
@export var shader_saturation: float = 1.0
## Character shader grade: contrast multiplier (1 = unchanged).
@export var shader_contrast: float = 1.0
## Character shader grade: brightness offset (0 = unchanged).
@export var shader_brightness: float = 0.0


## Max HP on [param floor_idx] (1-based).
func get_max_hp(floor_idx: int) -> int:
	return base_hp + hp_per_floor * maxi(0, floor_idx - 1)


## Attack on [param floor_idx] (1-based).
func get_attack(floor_idx: int) -> int:
	return base_attack + attack_per_floor * maxi(0, floor_idx - 1)


## Shader grade as Vector3(saturation, contrast, brightness).
func get_shader_grade() -> Vector3:
	return Vector3(shader_saturation, shader_contrast, shader_brightness)


## Boss aura colour: aura_color if set, else tint.
func get_aura_color() -> Color:
	return aura_color if has_aura_color else tint


## Legacy dictionary view (same keys as the pre-3B ARCHETYPES table).
func to_dict() -> Dictionary:
	var frames: Array = []
	frames.append_array(attack_frames)
	var d: Dictionary = {
		"id": id,
		"display_name": display_name,
		"idle_sprite": idle_sprite,
		"attack_frames": frames,
		"ai_profile": ai_profile,
		"is_ranged": is_ranged,
		"base_hp": base_hp,
		"hp_per_floor": hp_per_floor,
		"base_attack": base_attack,
		"attack_per_floor": attack_per_floor,
		"defense": defense,
		"speed": speed,
		"max_energy": max_energy,
		"sprite_scale": sprite_scale,
		"tint": tint,
		"figure_height": figure_height,
		"shader_saturation": shader_saturation,
		"shader_contrast": shader_contrast,
		"shader_brightness": shader_brightness,
		"is_boss": is_boss,
	}
	if has_aura_color:
		d["aura_color"] = aura_color
	return d
