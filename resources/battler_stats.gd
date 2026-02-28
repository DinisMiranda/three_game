extends Resource
class_name BattlerStats
## Data for one character in battle. Used by BattleManager and UI.
## Turn order is determined by speed: higher speed = acts earlier each round.

# --- Exported (editable in Inspector or from code) ---
@export var display_name: String = "Character"
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var attack: int = 10
@export var defense: int = 5
@export var speed: int = 10  ## Higher = earlier in turn order
@export var is_party: bool = true  ## true = ally (1 of 4), false = enemy (1–4)

# --- Damage: raw amount is reduced by defense; we clamp so HP never goes negative ---
func take_damage(amount: int) -> int:
	var actual = maxi(0, amount - defense)
	current_hp = maxi(0, current_hp - actual)
	return actual

# --- Healing: cap at max_hp ---
func heal(amount: int) -> int:
	var actual = mini(amount, max_hp - current_hp)
	current_hp = mini(max_hp, current_hp + amount)
	return actual

func is_alive() -> bool:
	return current_hp > 0

# --- Copy stats for a new battle (e.g. from a template resource) ---
func duplicate_stats() -> BattlerStats:
	var s = BattlerStats.new()
	s.display_name = display_name
	s.max_hp = max_hp
	s.current_hp = current_hp
	s.attack = attack
	s.defense = defense
	s.speed = speed
	s.is_party = is_party
	return s
