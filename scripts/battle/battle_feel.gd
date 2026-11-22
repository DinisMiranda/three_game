class_name BattleFeel
extends Resource
## Tuning data for battle "game feel": impact, death, pacing and battle speed.
##
## Every timing and strength value used by BattleFx and BattleScene for combat
## presentation lives here so it can be tuned in the inspector without touching
## code (portfolio plan, Phase 1A "Combat feel and pacing"). Nothing here changes
## battle rules: damage, crit chance and energy stay in BattleManager.
##
## Durations are in seconds at 1x speed. BattleFx divides them by the active
## speed multiplier, so 2x speed halves every wait and tween.

@export_group("Lunge")
## How far (px) the attacker's sprite travels toward its target.
@export_range(0.0, 200.0, 1.0) var lunge_distance_px: float = 56.0
## Time to travel out to the impact point.
@export_range(0.01, 1.0, 0.01) var lunge_out_duration: float = 0.12
## Time to travel back to the idle position after impact.
@export_range(0.01, 1.0, 0.01) var lunge_back_duration: float = 0.16
## Total length of the attack sprite frames (was a fixed 0.75 s in BattlerSlot).
@export_range(0.05, 2.0, 0.01) var attack_anim_duration: float = 0.4

@export_group("Impact")
## Freeze at the moment of impact, in milliseconds.
@export_range(0, 300, 1) var hit_stop_ms: int = 60
## Screen shake amplitude (px) on a normal hit.
@export_range(0.0, 40.0, 0.5) var shake_strength_px: float = 5.0
## Screen shake amplitude (px) on a critical hit.
@export_range(0.0, 40.0, 0.5) var shake_crit_strength_px: float = 12.0
## Screen shake length on a normal hit.
@export_range(0.01, 1.0, 0.01) var shake_duration: float = 0.16
## Screen shake length on a critical hit.
@export_range(0.01, 1.0, 0.01) var shake_crit_duration: float = 0.26
## Modulate applied to the target sprite for the hit flash. Values above 1
## over-brighten the sprite so it reads as a white flash without a shader.
@export var hit_flash_color: Color = Color(3.0, 3.0, 3.0, 1.0)
## Time to reach the flash colour (kept tiny so the flash is on during hit-stop).
@export_range(0.0, 0.5, 0.01) var hit_flash_in_duration: float = 0.02
## Time to fade from the flash colour back to normal.
@export_range(0.01, 1.0, 0.01) var hit_flash_out_duration: float = 0.16

@export_group("Combat Text")
## Base font size of floating damage numbers.
@export_range(8, 96, 1) var text_font_size: int = 26
## Crit numbers are this many times bigger than normal hits.
@export_range(1.0, 3.0, 0.05) var crit_text_scale: float = 1.5
## Colour of normal damage numbers.
@export var hit_text_color: Color = Color(1.0, 0.92, 0.55)
## Colour of critical damage numbers (warm orange).
@export var crit_text_color: Color = Color(1.0, 0.55, 0.15)
## Colour of the "MISS" label.
@export var miss_text_color: Color = Color(0.65, 0.68, 0.75)
## Colour of the "ABSORB" label (shield took the whole hit).
@export var absorb_text_color: Color = Color(0.45, 0.75, 1.0)
## Vertical gap (px) between repeated numbers on the same target (Barrage, Frenzy).
@export_range(0.0, 80.0, 1.0) var multi_hit_text_offset_px: float = 30.0
## Miss and absorb labels are this many times the base size (smaller = less shouty).
@export_range(0.5, 2.0, 0.05) var status_text_scale: float = 0.85

@export_group("Death")
## Length of the fade and slump when a battler is downed.
@export_range(0.05, 3.0, 0.01) var death_duration: float = 0.55
## How far (px) the sprite sinks as it slumps.
@export_range(0.0, 120.0, 1.0) var death_slump_px: float = 18.0
## Final sprite scale of a downed battler (squashed vertically).
@export var death_scale: Vector2 = Vector2(0.95, 0.82)
## Final modulate of a downed slot: dim and desaturated, but still visible so
## the dead slot stays readable.
@export var death_modulate: Color = Color(0.6, 0.6, 0.68, 0.72)

@export_group("Pacing")
## Pause after an action resolves, before the next turn starts.
@export_range(0.0, 2.0, 0.01) var post_action_wait: float = 0.2
## Pause while the enemy turn flash plays, before the enemy acts (was 0.9 s).
@export_range(0.0, 2.0, 0.01) var enemy_intro_wait: float = 0.45
## Fade-in of the red full-screen flash at the start of an enemy turn.
@export_range(0.0, 1.0, 0.01) var enemy_flash_in_duration: float = 0.1
## Fade-out of the red full-screen flash at the start of an enemy turn.
@export_range(0.0, 1.0, 0.01) var enemy_flash_out_duration: float = 0.28

@export_group("Turn Order")
## Fade-and-shrink length when a downed battler's chip leaves the turn order bar.
@export_range(0.0, 2.0, 0.01) var turn_chip_remove_duration: float = 0.3
## Final scale of a leaving chip (it shrinks toward its centre while fading).
@export_range(0.0, 1.0, 0.05) var turn_chip_remove_scale: float = 0.5
## Length of the small "pop" when a chip becomes the active battler (0 = off).
@export_range(0.0, 1.0, 0.01) var turn_chip_activate_duration: float = 0.16
## Scale the active chip pops from before settling at 1.0.
@export_range(0.5, 1.5, 0.05) var turn_chip_activate_from_scale: float = 0.85

@export_group("Status Bars")
## HP fill colour while the battler is healthy (the sci-fi cyan).
@export var hp_color: Color = Color(0.0, 0.9, 1.0, 0.85)
## HP fill colour at or below [member hp_low_ratio] of max HP.
@export var hp_low_color: Color = Color(1.0, 0.58, 0.16, 0.9)
## HP fill colour at or below [member hp_critical_ratio] of max HP.
@export var hp_critical_color: Color = Color(1.0, 0.26, 0.24, 0.95)
## HP fraction at or below which the bar turns [member hp_low_color].
@export_range(0.0, 1.0, 0.01) var hp_low_ratio: float = 0.5
## HP fraction at or below which the bar turns [member hp_critical_color].
@export_range(0.0, 1.0, 0.01) var hp_critical_ratio: float = 0.25
## Energy fill colour (yellow, so it never reads as HP).
@export var energy_color: Color = Color(1.0, 0.84, 0.22, 0.92)
## Colour of the "EN" tag and energy numbers.
@export var energy_text_color: Color = Color(1.0, 0.88, 0.45, 1.0)
## Colour of the "HP" tag and HP numbers.
@export var hp_text_color: Color = Color(0.78, 0.92, 1.0, 1.0)
## Font size of the bar tags and numbers in a BattlerSlot (1920x1080 space).
@export_range(8, 32, 1) var bar_text_font_size: int = 14
## Short tag shown before the energy bar.
@export var energy_tag: String = "EN"
## Short tag shown before the HP bar.
@export var hp_tag: String = "HP"

@export_group("Battle Speed")
## Speeds the speed toggle cycles through. Index 0 is the default.
@export var speed_multipliers: Array[float] = [1.0, 2.0]


## Returns the speed multiplier at [param index], wrapping around the list.
## Falls back to 1.0 when the list is empty or the value is not positive.
func get_speed_multiplier(index: int) -> float:
	if speed_multipliers.is_empty():
		return 1.0
	var value: float = speed_multipliers[posmod(index, speed_multipliers.size())]
	return value if value > 0.0 else 1.0


## Returns the hit-stop length in seconds (1x speed).
func get_hit_stop_seconds() -> float:
	return float(hit_stop_ms) / 1000.0


## Returns the floating-text style for one hit result.
## [param kind] is a BattleManager hit kind ("hit", "crit", "miss", "absorb").
## The result is { "text": String, "color": Color, "font_size": int }, or an
## empty Dictionary when nothing should be shown (a 0-damage normal hit).
func get_combat_text_style(kind: String, damage: int) -> Dictionary:
	match kind:
		"miss":
			return _style("MISS", miss_text_color, status_text_scale)
		"absorb":
			return _style("ABSORB", absorb_text_color, status_text_scale)
		"crit":
			return _style("-%d!" % damage, crit_text_color, crit_text_scale)
		_:
			if damage <= 0:
				return {}
			return _style("-%d" % damage, hit_text_color, 1.0)


## Returns the shake amplitude (px) and length (s, 1x speed) for an impact.
func get_shake(is_crit: bool) -> Vector2:
	if is_crit:
		return Vector2(shake_crit_strength_px, shake_crit_duration)
	return Vector2(shake_strength_px, shake_duration)


## Returns the HP fill colour for [param current] of [param maximum] HP:
## [member hp_color] when healthy, [member hp_low_color] at or below
## [member hp_low_ratio], [member hp_critical_color] at or below
## [member hp_critical_ratio]. A non-positive maximum reads as healthy.
func get_hp_color(current: int, maximum: int) -> Color:
	if maximum <= 0:
		return hp_color
	var ratio: float = clampf(float(current) / float(maximum), 0.0, 1.0)
	if ratio <= hp_critical_ratio:
		return hp_critical_color
	if ratio <= hp_low_ratio:
		return hp_low_color
	return hp_color


## Formats a bar value as "current/max" (e.g. "60/100"). Current is clamped to
## 0..max and a negative max is shown as 0, so the read never looks broken.
static func format_bar_value(current: int, maximum: int) -> String:
	var m: int = maxi(0, maximum)
	return "%d/%d" % [clampi(current, 0, m), m]


func _style(text: String, color: Color, size_scale: float) -> Dictionary:
	return {
		"text": text,
		"color": color,
		"font_size": maxi(1, roundi(float(text_font_size) * size_scale)),
	}
