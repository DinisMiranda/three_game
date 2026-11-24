class_name BattleScene
extends Control
## Battle screen controller: creates the BattleManager, wires the components
## together and turns their signals into battle actions.
##
## Components (each owns one concern, this script only connects them):
##   [ActionPanel]       player buttons and ability list      (signals up)
##   [ArenaView]         slots, sprites, highlights           (calls down)
##   [PartyStatusPanel]  hero HP / energy rows
##   [BattleNarrator]    coloured log lines
##   [EnemyAI]           enemy action and target choice
##   [BattleEndScreen]   victory / defeat overlay
##   [BattleFx]          lunge, hit-stop, shake, damage numbers
## Rules live in [BattleManager]; this controller never computes damage.

const OptionsMenuScene = preload("res://scenes/ui/options_menu.tscn")
const DEFAULT_BATTLE_FEEL: BattleFeel = preload("res://resources/battle_feel_default.tres")
## Abilities that play the attacker's lunge animation.
const ATTACK_ANIM_ABILITIES: Array[String] = [
	"grenade", "slash", "strike", "snipe", "ranged_shot", "barrage", "frenzy"
]
const _MENU_BACKGROUND := "res://assets/andar.jpg"

## Combat feel tuning (impact, death, pacing, speed). Swap for another
## BattleFeel resource to retune without code changes.
@export var battle_feel: BattleFeel = DEFAULT_BATTLE_FEEL

@onready var battle_background: TextureRect = $Background
@onready var floor_banner: Label = $Margin/VBox/FloorBanner
@onready var turn_order_bar: TurnOrderBar = $Margin/VBox/TopBar/TopHBox/TurnOrderBar
@onready var speed_btn: Button = $Margin/VBox/TopBar/TopHBox/SpeedBtn
@onready var action_panel: ActionPanel = $Margin/VBox/BottomRow/ActionsPanel
@onready var party_status: PartyStatusPanel = $Margin/VBox/BottomRow/PartyStatsPanel/StatsVBox/StatsList
@onready var battle_log: BattleLog = $Margin/VBox/BottomRow/LogPanel
@onready var end_screen: BattleEndScreen = $EndScreen
@onready var enemy_turn_flash: ColorRect = $EnemyTurnFlash
@onready var floating_text_layer: CanvasLayer = $FloatingTextLayer

var battle_manager: BattleManager
## Presentation of combat feel (lunge, hit-stop, shake, flash, death, waits).
var battle_fx: BattleFx
var arena: ArenaView
var narrator: BattleNarrator
var _enemy_ai: EnemyAI
var _selected_target: Dictionary = {}  # { "stats", "index", "is_party" } for the current attack target
var _options_menu: CanvasLayer
var _enemy_turn_token: int = 0
var _action_busy: bool = false
var _ai_running: bool = false


func _ready() -> void:
	_create_components()
	_connect_signals()
	_apply_theme_colors()
	_on_battle_speed_changed(battle_fx.get_speed_multiplier())
	MusicPlayer.play_battle()
	_start_battle()
	_apply_mission_floor_visuals()


func _create_components() -> void:
	battle_manager = BattleManager.new()
	add_child(battle_manager)
	battle_fx = BattleFx.new()
	battle_fx.name = "BattleFx"
	battle_fx.feel = battle_feel
	add_child(battle_fx)
	battle_fx.configure([$Margin] as Array[Control], floating_text_layer)
	arena = ArenaView.new($Margin/VBox/ArenaRow/PartyArena/PartySlots, $Margin/VBox/ArenaRow/EnemyArena/EnemySlots, battle_feel)
	narrator = BattleNarrator.new(battle_log)
	_enemy_ai = EnemyAI.new(battle_manager)
	turn_order_bar.feel = battle_feel
	_options_menu = OptionsMenuScene.instantiate()
	add_child(_options_menu)


func _connect_signals() -> void:
	battle_manager.turn_started.connect(_on_turn_started)
	battle_manager.turn_order_updated.connect(_on_turn_order_updated)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_fx.speed_changed.connect(_on_battle_speed_changed)
	speed_btn.pressed.connect(battle_fx.cycle_speed)
	arena.enemy_slot_clicked.connect(_on_enemy_slot_clicked)
	action_panel.attack_requested.connect(_on_attack_requested)
	action_panel.abilities_requested.connect(_on_abilities_requested)
	action_panel.ability_selected.connect(_on_ability_selected)
	action_panel.end_turn_requested.connect(_on_end_turn_requested)
	end_screen.next_floor_requested.connect(_on_next_floor_requested)
	end_screen.back_to_menu_requested.connect(_on_back_to_menu_requested)


## Panels, buttons, labels and bars are styled by the project Theme
## (assets/ui/triad_theme.tres); this wires the runtime colours code owns.
func _apply_theme_colors() -> void:
	turn_order_bar.party_color = Palette.PARTY_TEAL
	turn_order_bar.enemy_color = Palette.ENEMY_RED
	turn_order_bar.active_color = Palette.SELECT_AMBER
	turn_order_bar.chip_bg_color = Palette.PANEL_FILL
	turn_order_bar.text_color = Palette.TEXT_PRIMARY
	floor_banner.add_theme_color_override("font_color", Palette.ACCENT_CYAN)


# --- Battle setup -------------------------------------------------------------

func _start_battle() -> void:
	battle_manager.setup_battle(HeroRoster.build_party(), _build_enemies(), _battle_context())
	_rebuild_arena()
	narrator.say("Battle start! Turn order is based on speed. Click an enemy to target.", "system")


func _rebuild_arena() -> void:
	arena.build(battle_manager.get_party(), battle_manager.get_enemies())
	party_status.refresh(battle_manager.get_party(), battle_feel)
	_on_turn_order_updated()


## This fight's enemies from the floor lineup (MissionProgress.MERIDIAN_FLOORS
## "enemies"); floor 1 when no mission is active.
func _build_enemies() -> Array:
	return EnemyRoster.build_enemies(MissionProgress.get_current_floor_enemy_types(), MissionProgress.get_current_combat_floor())


## Telemetry context for battle_start: combat floor and mission id ("" if none).
func _battle_context() -> Dictionary:
	var mission_id: String = MissionProgress.MERIDIAN_MISSION_ID if MissionProgress.is_meridian_spire_active() else ""
	return { "floor": MissionProgress.get_current_combat_floor(), "mission_id": mission_id }


func _apply_mission_floor_visuals() -> void:
	_apply_battle_background(_MENU_BACKGROUND)
	floor_banner.visible = MissionProgress.is_meridian_spire_active()
	if not floor_banner.visible:
		return
	var info: Dictionary = MissionProgress.get_meridian_floor_info()
	floor_banner.text = "MERIDIAN SPIRE · %s" % str(info.get("title", ""))
	var bg_path: String = str(info.get("bg", ""))
	if not bg_path.is_empty():
		_apply_battle_background(bg_path)


func _apply_battle_background(path: String) -> void:
	var tex := load(path) as Texture2D
	if tex != null:
		battle_background.texture = tex
	else:
		push_warning("Missing battle background: %s" % path)


# --- Turn flow ----------------------------------------------------------------

func _on_turn_started(_battler_index: int, is_party: bool) -> void:
	var current: Dictionary = battle_manager.get_current_battler()
	if current.is_empty():
		return
	var s: BattlerStats = current.stats
	if not s.is_alive():
		battle_manager.advance_turn()
		return
	narrator.say("%s's turn (Speed: %d)" % [s.display_name, s.speed], "turn" if is_party else "enemy_turn")
	_refresh_battlers()
	_on_turn_order_updated()
	_action_busy = not is_party
	action_panel.set_enabled(is_party)
	action_panel.show_panel(is_party)
	action_panel.close_abilities()
	if is_party:
		_set_selected_target({})
		return
	_enemy_turn_token += 1
	var token := _enemy_turn_token
	await battle_fx.play_enemy_turn_intro(arena.slot_for_battler(current), enemy_turn_flash)
	if token == _enemy_turn_token and is_inside_tree():
		_run_enemy_turn()


## Feeds the turn order bar (alive battlers sorted by speed) and highlights the
## active slot in the arena.
func _on_turn_order_updated(_order_arg = null) -> void:
	var current: Dictionary = battle_manager.get_current_battler()
	var active_key := "" if current.is_empty() else ArenaView.turn_key(bool(current.is_party), int(current.index))
	turn_order_bar.set_order(arena.turn_order_entries(battle_manager.get_party(), battle_manager.get_enemies()), active_key)
	arena.highlight_turn(arena.slot_for_battler(current))


func _refresh_battlers() -> void:
	arena.refresh()
	party_status.refresh(battle_manager.get_party(), battle_feel)


func _is_current_battler(battler: Dictionary) -> bool:
	var current: Dictionary = battle_manager.get_current_battler()
	if battler.is_empty() or current.is_empty():
		return false
	return current.index == battler.index and current.is_party == battler.is_party and current.stats == battler.stats


# --- Targeting ----------------------------------------------------------------

func _on_enemy_slot_clicked(slot_index: int, is_party: bool) -> void:
	var enemies: Array = battle_manager.get_enemies()
	if is_party or slot_index < 0 or slot_index >= enemies.size() or not enemies[slot_index].is_alive():
		return
	_set_selected_target({ "stats": enemies[slot_index], "index": slot_index, "is_party": false })
	narrator.say("Target: %s" % enemies[slot_index].display_name)


func _set_selected_target(target: Dictionary) -> void:
	_selected_target = target
	arena.highlight_targets(target.get("stats", null), battle_manager.get_current_battler(), battle_manager.can_attack_target)


## Living enemies the [param attacker] may use [param ability_id] on ("attack" = basic attack).
func _enemy_targets(attacker: Dictionary, ability_id: String) -> Array:
	var out: Array = []
	var enemies: Array = battle_manager.get_enemies()
	for i in enemies.size():
		var t := { "stats": enemies[i], "index": i, "is_party": false }
		if not enemies[i].is_alive():
			continue
		if battle_manager.can_attack_target(attacker, t) if ability_id == "attack" else battle_manager.can_use_ability_on_target(attacker, ability_id, t):
			out.append(t)
	return out


## The selected target if the ability can use it, else a random valid one; {} if none.
func _pick_player_target(attacker: Dictionary, ability_id: String) -> Dictionary:
	var candidates: Array = _enemy_targets(attacker, ability_id)
	if candidates.is_empty():
		return {}
	if ability_id != "attack" and not _selected_target.is_empty() and battle_manager.can_use_ability_on_target(attacker, ability_id, _selected_target):
		return _selected_target
	return candidates[randi() % candidates.size()]


# --- Player actions -------------------------------------------------------------

func _on_attack_requested() -> void:
	var attacker: Dictionary = battle_manager.get_current_battler()
	if _action_busy or attacker.is_empty() or not attacker.is_party or not attacker.stats.is_alive():
		return
	if _selected_target.is_empty():
		_set_selected_target(_pick_player_target(attacker, "attack"))
		if _selected_target.is_empty():
			narrator.say("No valid enemies to attack.")
			return
		narrator.say("No target selected, attacking %s." % _selected_target.stats.display_name)
	if not battle_manager.can_attack_target(attacker, _selected_target):
		narrator.say("Can't reach %s (flying) with a melee attack!" % _selected_target.stats.display_name)
		return
	_action_busy = true
	action_panel.set_enabled(false)
	var target: Dictionary = _selected_target.duplicate()
	var attacker_slot: BattlerSlot = arena.slot_for_battler(attacker)
	await battle_fx.play_lunge(attacker_slot, arena.slot_for_battler(target))
	if not _player_turn_still_active(attacker):
		return
	narrator.hero_bark(attacker.index, "attack")
	battle_manager.last_hit_results.clear()
	var dmg: int = battle_manager.perform_attack(attacker, target)
	narrator.attack_result(attacker.stats.display_name, target.stats.display_name, dmg, battle_manager.last_hit_kind)
	await _finish_player_action(attacker_slot)


func _on_end_turn_requested() -> void:
	if _action_busy:
		return
	_action_busy = true
	action_panel.set_enabled(false)
	battle_manager.advance_turn()


func _on_abilities_requested() -> void:
	var current: Dictionary = battle_manager.get_current_battler()
	if current.is_empty() or not current.is_party:
		return
	var abilities: Array = HeroRoster.get_abilities(current.index)
	if abilities.is_empty():
		narrator.say("%s has no abilities." % current.stats.display_name)
		return
	var entries: Array = []
	for ab in abilities:
		entries.append(_ability_entry(current, str(ab.get("id", "")), str(ab.get("name", ab.get("id", "")))))
	action_panel.open_abilities(entries)


## Ability-list entry for [ActionPanel.open_abilities].
func _ability_entry(current: Dictionary, ability_id: String, ability_name: String) -> Dictionary:
	var can_afford: bool = battle_manager.can_use_ability(current, ability_id)
	var can_use: bool = can_afford
	if battle_manager.ability_needs_target(ability_id):
		can_use = can_use and battle_manager.has_valid_target_for_ability(current, ability_id, battle_manager.get_enemies())
	return { "id": ability_id, "name": ability_name, "cost": battle_manager.get_ability_cost(ability_id),
		"can_afford": can_afford, "can_use": can_use, "hint": battle_manager.get_ability_hint(ability_id) }


func _on_ability_selected(ability_id: String, ability_name: String) -> void:
	var current: Dictionary = battle_manager.get_current_battler()
	if _action_busy:
		return
	if current.is_empty() or not current.is_party:
		action_panel.close_abilities()
		return
	var target: Dictionary = {}
	if battle_manager.ability_needs_target(ability_id):
		target = _pick_player_target(current, ability_id)
		if not _ability_target_ok(current, ability_id, ability_name, target):
			return
	if not battle_manager.can_use_ability(current, ability_id):
		narrator.say("Not enough energy for %s." % ability_name)
		action_panel.close_abilities()
		return
	_action_busy = true
	action_panel.set_enabled(false)
	var lunge_slot: BattlerSlot = arena.slot_for_battler(current) if ability_id in ATTACK_ANIM_ABILITIES else null
	await battle_fx.play_lunge(lunge_slot, arena.slot_for_battler(target))
	if not _player_turn_still_active(current):
		return
	if not battle_manager.perform_ability(current, ability_id, target):
		await battle_fx.play_impact(lunge_slot, [])
		_action_busy = false
		action_panel.set_enabled(true)
		action_panel.close_abilities()
		return
	narrator.hero_bark(current.index, ability_id)
	narrator.hero_ability(current, ability_id, ability_name, target, battle_manager.last_ability_damage)
	action_panel.close_abilities()
	await _finish_player_action(lunge_slot)


## Logs why an ability cannot be used on [param target] and returns false in that case.
func _ability_target_ok(current: Dictionary, ability_id: String, ability_name: String, target: Dictionary) -> bool:
	if target.is_empty():
		narrator.say("Snipe needs a flying enemy — use Fly first or wait for one." if ability_id == "snipe" else "No valid target for %s." % ability_name)
		return false
	if not battle_manager.can_use_ability_on_target(current, ability_id, target):
		narrator.say("Can't use %s on that target." % ability_name)
		return false
	return true


## After a lunge: false (and the buttons re-enabled) if the scene left the tree
## or the turn moved on while the animation played.
func _player_turn_still_active(attacker: Dictionary) -> bool:
	var current: Dictionary = battle_manager.get_current_battler() if is_inside_tree() else {}
	if not current.is_empty() and current.is_party and current.index == attacker.index and current.stats == attacker.stats:
		return true
	_action_busy = false
	if not current.is_empty() and current.is_party:
		action_panel.set_enabled(true)
	return false


## Shared tail of a player attack or ability: refresh, clear target, play the
## impact, then end the turn.
func _finish_player_action(lunge_slot: BattlerSlot) -> void:
	_refresh_battlers()
	_set_selected_target({})
	await _apply_hit_results(battle_manager.last_hit_results, lunge_slot)
	if is_inside_tree():
		battle_manager.advance_turn()


# --- Enemy turn -----------------------------------------------------------------

func _run_enemy_turn() -> void:
	var attacker: Dictionary = battle_manager.get_current_battler()
	if _ai_running or attacker.is_empty() or attacker.is_party:
		return
	_ai_running = true
	var end_turn: bool = await _perform_enemy_action(attacker)
	_ai_running = false
	if end_turn and is_inside_tree():
		battle_manager.advance_turn()


## Plays the AI's choice for [param attacker]. Returns false if the turn was
## interrupted (the caller then must not advance the turn).
func _perform_enemy_action(attacker: Dictionary) -> bool:
	var action: Dictionary = _enemy_ai.choose_for(attacker)
	var is_ability: bool = action.get("kind", "") == "ability"
	var ability_id: String = str(action.get("id", "attack"))
	var target: Dictionary = {}
	if bool(action.get("needs_target", false)):
		target = _enemy_ai.pick_target(attacker, ability_id)
		if target.is_empty():
			return true
	var lunge_slot: BattlerSlot = arena.slot_for_battler(attacker) if (not is_ability or ability_id in ATTACK_ANIM_ABILITIES) else null
	await battle_fx.play_lunge(lunge_slot, arena.slot_for_battler(target))
	if not is_inside_tree() or not _is_current_battler(attacker):
		return false
	if is_ability:
		if not battle_manager.perform_ability(attacker, ability_id, target):
			await battle_fx.play_impact(lunge_slot, [])
			return true
		narrator.enemy_ability(attacker, ability_id, str(action.get("name", ability_id)), target, battle_manager.last_ability_damage)
	else:
		battle_manager.last_hit_results.clear()
		var dmg: int = battle_manager.perform_attack(attacker, target)
		narrator.attack_result(attacker.stats.display_name, target.stats.display_name, dmg, battle_manager.last_hit_kind)
	_refresh_battlers()
	await _apply_hit_results(battle_manager.last_hit_results, lunge_slot)
	return true


## Turns BattleManager hit results into BattleFx hits, plays the SFX, and
## awaits the impact presentation. [param attacker_slot] is the slot that
## lunged, or null when the action had no lunge.
func _apply_hit_results(results: Array, attacker_slot: BattlerSlot = null) -> void:
	var hits: Array[Dictionary] = []
	for hit in results:
		var slot: BattlerSlot = arena.slot_for(int(hit.get("target_index", -1)), bool(hit.get("is_party", false)))
		if slot == null:
			continue
		var damage: int = int(hit.get("damage", 0))
		var kind: String = str(hit.get("kind", "hit"))
		var stats: BattlerStats = slot.get_stats()
		hits.append({ "slot": slot, "damage": damage, "kind": kind, "downed": stats != null and not stats.is_alive() })
		_play_hit_sfx(kind, damage)
	await battle_fx.play_impact(attacker_slot, hits)
	# Downed battlers leave the turn order bar right away (fade + shrink).
	if is_inside_tree():
		_on_turn_order_updated()


func _play_hit_sfx(kind: String, damage: int) -> void:
	match kind:
		"crit": BattleSfx.play_crit()
		"miss": BattleSfx.play_miss()
		"absorb": BattleSfx.play_absorb()
		_:
			if damage > 0:
				BattleSfx.play_hit()


# --- Battle end and floor transitions ------------------------------------------

func _on_battle_ended(party_wins: bool) -> void:
	_action_busy = true
	_ai_running = false
	action_panel.set_enabled(false)
	action_panel.show_panel(false)
	if party_wins:
		narrator.say("Victory! All enemies defeated.", "victory")
	else:
		narrator.say("Defeat! Party was defeated.", "defeat")
	end_screen.show_outcome(party_wins, get_viewport().get_visible_rect().size)


## Same scene, new floor: fade through black (SceneFader) and rebuild while the
## screen is covered. Falls back to an instant rebuild if no fade runs.
func _on_next_floor_requested() -> void:
	if not SceneFader.fade_through(_advance_to_next_floor):
		_advance_to_next_floor()


func _advance_to_next_floor() -> void:
	end_screen.close()
	MissionProgress.meridian_advance_floor()
	var party: Array = battle_manager.get_party()
	for s in party:
		(s as BattlerStats).restore_for_new_floor()
	battle_manager.setup_battle(party, _build_enemies(), _battle_context())
	_rebuild_arena()
	_apply_mission_floor_visuals()
	narrator.say("=== %s ===" % MissionProgress.get_meridian_floor_info().title, "system")


func _on_back_to_menu_requested() -> void:
	if MissionProgress.meridian_epilogue_pending:
		SceneFader.change_scene("res://scenes/story/meridian_epilogue.tscn")
		return
	MissionProgress.finish_meridian_spire()
	SceneFader.change_scene("res://scenes/main_menu/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _options_menu.visible:
		_options_menu.show_menu()
		get_viewport().set_input_as_handled()


func _on_battle_speed_changed(_multiplier: float) -> void:
	speed_btn.text = battle_fx.get_speed_label()
	turn_order_bar.speed_multiplier = battle_fx.get_speed_multiplier()
	speed_btn.tooltip_text = "Battle speed: %s (click to change)" % battle_fx.get_speed_label()
