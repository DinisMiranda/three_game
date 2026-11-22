class_name BattleNarrator
extends RefCounted
## Writes the battle's coloured log lines: turn announcements, attack results,
## ability messages and hero barks.
##
## Line colours are semantic (combat text only); chrome colours come from
## [Palette]. Kinds: "normal", "system", "turn", "enemy_turn", "damage", "crit",
## "absorb", "miss", "bark", "ability", "victory", "defeat".

## Default log text green: the log's own semantic colour (art-direction 1, log only).
const COLOR_LOG := Color(0.0, 1.0, 0.55, 0.95)
const _COLOR_ENEMY := Color(1.0, 0.45, 0.42, 1)
const _COLOR_CRIT := Color(1.0, 0.55, 0.2, 1)
const _COLOR_ABSORB := Color(0.45, 0.75, 1.0, 1)
const _COLOR_MISS := Color(0.65, 0.68, 0.75, 1)
const _COLOR_VICTORY := Color(0.35, 1.0, 0.65, 1)
const _COLOR_DEFEAT := Color(1.0, 0.35, 0.4, 1)
const _COLOR_BARK := Color(0.95, 0.88, 0.45, 1)

var _log: BattleLog


## [param battle_log] is the node the lines are written to.
func _init(battle_log: BattleLog) -> void:
	_log = battle_log
	_log.set_text_color(COLOR_LOG)


## Adds one coloured line (newest on top; BattleLog keeps the history).
func say(msg: String, kind: String = "normal") -> void:
	_log.add_line("[color=#%s]%s[/color]" % [color_for_kind(kind).to_html(false), msg])


## Colour used for a log [param kind].
func color_for_kind(kind: String) -> Color:
	match kind:
		"turn": return Palette.SELECT_AMBER
		"enemy_turn": return _COLOR_ENEMY
		"damage", "crit": return _COLOR_CRIT
		"absorb": return _COLOR_ABSORB
		"miss": return _COLOR_MISS
		"bark": return _COLOR_BARK
		"ability": return Palette.ACCENT_CYAN
		"victory": return _COLOR_VICTORY
		"defeat": return _COLOR_DEFEAT
		"system": return Palette.TEXT_PRIMARY
	return COLOR_LOG


## Result of a basic attack; [param kind] is BattleManager.last_hit_kind.
func attack_result(attacker_name: String, target_name: String, damage: int, kind: String) -> void:
	match kind:
		"miss":
			say("%s attacks %s — MISS!" % [attacker_name, target_name], "miss")
		"absorb":
			say("%s attacks %s — absorbed by shield!" % [attacker_name, target_name], "absorb")
		"crit":
			say("CRITICAL! %s hits %s for %d damage!" % [attacker_name, target_name, damage], "crit")
		_:
			say("%s attacks %s for %d damage!" % [attacker_name, target_name, damage], "damage")


## An enemy used [param ability_id]; [param damage] is BattleManager.last_ability_damage.
func enemy_ability(attacker: Dictionary, ability_id: String, ability_name: String, target: Dictionary, damage: int) -> void:
	var who: String = attacker.stats.display_name
	match ability_id:
		"focus":
			say("%s uses Focus! Attack boosted for 2 rounds." % who)
		"guard":
			say("%s braces for impact! Damage halved until its next turn." % who)
		"frenzy":
			say("%s enters Frenzy on %s for %d total damage!" % [who, target.stats.display_name, damage])
		"barrage":
			say("%s barrages %s for %d total damage!" % [who, target.stats.display_name, damage])
		_:
			if target.is_empty():
				say("%s uses %s!" % [who, ability_name])
			else:
				say("%s uses %s on %s for %d damage!" % [who, ability_name, target.stats.display_name, damage])


## A hero used [param ability_id]; [param damage] is BattleManager.last_ability_damage.
func hero_ability(attacker: Dictionary, ability_id: String, ability_name: String, target: Dictionary, damage: int) -> void:
	var who: String = attacker.stats.display_name
	match ability_id:
		"fly":
			say("%s is flying! Only ranged attacks can hit." % who, "ability")
		"shield":
			say("%s gains a shield (%d HP) for 3 rounds." % [who, attacker.stats.shield_amount], "ability")
		"guard":
			say("%s takes a defensive stance! Incoming damage halved until next turn." % who, "ability")
		"grenade":
			say("%s lobs a grenade at %s for %d total damage!" % [who, target.stats.display_name, damage], "damage")
		"slash":
			say("%s slashes %s for %d damage!" % [who, target.stats.display_name, damage], "damage")
		"strike":
			say("%s strikes through armor on %s for %d damage!" % [who, target.stats.display_name, damage], "damage")
		"snipe":
			say("%s snipes the airborne %s for %d damage!" % [who, target.stats.display_name, damage], "damage")
		_:
			say("%s uses %s!" % [who, ability_name], "ability")


## Logs a hero's quip for [param context] ("attack" or an ability id), if any,
## and plays the bark sound.
func hero_bark(hero_index: int, context: String) -> void:
	var line: String = HeroRoster.get_bark(hero_index, context)
	if line.is_empty():
		return
	var hero_name: String = str(HeroRoster.get_hero(hero_index).get("display_name", "Hero"))
	say('%s: "%s"' % [hero_name, line], "bark")
	BattleSfx.play_bark()
