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
@export var is_ranged: bool = false  ## If true, can attack flying targets; melee cannot.

## Energy for abilities. Restored at start of each turn (see BattleManager). Abilities cost energy.
@export var max_energy: int = 100
var current_energy: int = 100

## Runtime state: when true, only ranged attackers can target this battler (cleared at start of owner's next turn).
var is_flying: bool = false

## Shield: absorbs damage before HP. Set by Shield ability; duration in rounds.
var shield_amount: int = 0
var shield_rounds_left: int = 0  ## 0 = no shield

## Guard: halves incoming damage until this battler's next turn begins.
var guard_active: bool = false

## Temporary attack buff (Focus and similar). Ticks down at round end.
var attack_buff_amount: int = 0
var attack_buff_rounds_left: int = 0

func get_attack_power() -> int:
	return attack + attack_buff_amount

func has_energy(cost: int) -> bool:
	return current_energy >= cost

func spend_energy(cost: int) -> bool:
	if not has_energy(cost):
		return false
	current_energy = maxi(0, current_energy - cost)
	return true

func restore_energy(amount: int) -> void:
	current_energy = mini(max_energy, current_energy + amount)

# --- Damage: shield absorbs first; guard halves damage; defense reduces HP loss. ---
func take_damage(amount: int, ignore_defense: bool = false) -> int:
	var incoming := amount
	if guard_active:
		incoming = int(ceil(incoming * 0.5))
	var to_hp := incoming
	if shield_amount > 0:
		var absorbed = mini(incoming, shield_amount)
		shield_amount -= absorbed
		if shield_amount <= 0:
			shield_rounds_left = 0
		to_hp = incoming - absorbed
	var actual := maxi(0, to_hp - (0 if ignore_defense else defense))
	current_hp = maxi(0, current_hp - actual)
	return actual

# --- Healing: cap at max_hp ---
func heal(amount: int) -> int:
	var actual = mini(amount, max_hp - current_hp)
	current_hp = mini(max_hp, current_hp + amount)
	return actual

func is_alive() -> bool:
	return current_hp > 0

# --- Shield: grant temporary HP that absorbs damage first. Lasts for `rounds` round-ends. ---
func apply_shield(amount: int, rounds: int) -> void:
	shield_amount = amount
	shield_rounds_left = rounds


func apply_guard() -> void:
	guard_active = true


func apply_attack_buff(bonus: int, rounds: int) -> void:
	attack_buff_amount = bonus
	attack_buff_rounds_left = rounds


func tick_buff_rounds() -> void:
	if attack_buff_rounds_left > 0:
		attack_buff_rounds_left -= 1
		if attack_buff_rounds_left <= 0:
			attack_buff_amount = 0

# --- Call at end of each round; decrements duration and clears shield when it expires. ---
func tick_shield_round() -> void:
	if shield_rounds_left > 0:
		shield_rounds_left -= 1
		if shield_rounds_left <= 0:
			shield_amount = 0

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
	s.is_ranged = is_ranged
	s.max_energy = max_energy
	s.current_energy = current_energy
	return s
