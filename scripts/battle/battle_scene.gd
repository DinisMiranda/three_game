extends Control
## Battle scene: 4 vs 1-4 enemies, turn-based, turn order by speed.

@onready var turn_order_list: Control = $UI/VBox/Content/Left/TurnOrderList
@onready var log_label: Label = $UI/VBox/Content/Right/Log
@onready var actions_panel: PanelContainer = $UI/VBox/Content/Right/ActionsPanel
@onready var party_list: ItemList = $UI/VBox/Content/Center/PartyList
@onready var enemy_list: ItemList = $UI/VBox/Content/Center/EnemyList
@onready var attack_btn: Button = $UI/VBox/Content/Right/ActionsPanel/VBox/AttackBtn
@onready var end_turn_btn: Button = $UI/VBox/Content/Right/ActionsPanel/VBox/EndTurnBtn

var battle_manager: BattleManager
var _selected_target: Dictionary = {}  # { "stats", "index", "is_party" }

func _ready() -> void:
	battle_manager = BattleManager.new()
	add_child(battle_manager)
	battle_manager.turn_started.connect(_on_turn_started)
	battle_manager.turn_ended.connect(_on_turn_ended)
	battle_manager.turn_order_updated.connect(_on_turn_order_updated)
	battle_manager.battle_ended.connect(_on_battle_ended)
	attack_btn.pressed.connect(_on_attack_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	party_list.item_selected.connect(_on_party_item_selected)
	enemy_list.item_selected.connect(_on_enemy_item_selected)
	_start_sample_battle()

func _start_sample_battle() -> void:
	var party: Array = []
	for i in 4:
		var s = BattlerStats.new()
		s.display_name = "Hero %d" % (i + 1)
		s.max_hp = 80 + i * 10
		s.current_hp = s.max_hp
		s.attack = 12 + i
		s.defense = 4
		s.speed = 8 + i * 2  # Different speeds so order varies
		s.is_party = true
		party.append(s)
	var enemies: Array = []
	var n_enemies = randi_range(1, 4)
	for i in n_enemies:
		var s = BattlerStats.new()
		s.display_name = "Enemy %d" % (i + 1)
		s.max_hp = 50 + i * 15
		s.current_hp = s.max_hp
		s.attack = 8 + i
		s.defense = 3
		s.speed = 5 + i * 3
		s.is_party = false
		enemies.append(s)
	battle_manager.setup_battle(party, enemies)
	_refresh_party_and_enemy_lists()
	_log("Battle start! Turn order is based on speed.")

func _refresh_party_and_enemy_lists() -> void:
	party_list.clear()
	for i in battle_manager.get_party().size():
		var s: BattlerStats = battle_manager.get_party()[i]
		var tag = " (DEAD)" if not s.is_alive() else ""
		party_list.add_item("%s HP:%d/%d Spd:%d%s" % [s.display_name, s.current_hp, s.max_hp, s.speed, tag])
	enemy_list.clear()
	for i in battle_manager.get_enemies().size():
		var s: BattlerStats = battle_manager.get_enemies()[i]
		var tag = " (DEAD)" if not s.is_alive() else ""
		enemy_list.add_item("%s HP:%d/%d Spd:%d%s" % [s.display_name, s.current_hp, s.max_hp, s.speed, tag])

func _on_turn_order_updated(order: Array) -> void:
	_update_turn_order_display(order)

func _update_turn_order_display(order: Array) -> void:
	for c in turn_order_list.get_children():
		c.queue_free()
	for i in order.size():
		var entry: Dictionary = order[i]
		var s: BattlerStats = entry.stats
		var side = "Party" if entry.is_party else "Enemy"
		var label = Label.new()
		label.text = "%d. %s (%s) Spd:%d" % [i + 1, s.display_name, side, s.speed]
		turn_order_list.add_child(label)

func _on_turn_started(battler_index: int, is_party: bool) -> void:
	var current = battle_manager.get_current_battler()
	if current.is_empty():
		return
	var s: BattlerStats = current.stats
	if not s.is_alive():
		battle_manager.advance_turn()
		return
	_log("%s's turn (Speed: %d)" % [s.display_name, s.speed])
	_refresh_party_and_enemy_lists()
	# If it's party turn, show actions; else auto-advance after a short delay (AI)
	if is_party:
		actions_panel.visible = true
		_selected_target = {}
	else:
		actions_panel.visible = false
		# Simple AI: pick first alive party member and attack
		await get_tree().create_timer(0.8).timeout
		_ai_turn()

func _ai_turn() -> void:
	var party = battle_manager.get_party()
	for i in party.size():
		var s: BattlerStats = party[i]
		if s.is_alive():
			var attacker = battle_manager.get_current_battler()
			var target = { "stats": s, "index": i, "is_party": true }
			var dmg = battle_manager.perform_attack(attacker, target)
			_log("%s attacks %s for %d damage!" % [attacker.stats.display_name, s.display_name, dmg])
			_refresh_party_and_enemy_lists()
			break
	battle_manager.advance_turn()

func _on_turn_ended(_battler_index: int, _is_party: bool) -> void:
	pass

func _on_battle_ended(party_wins: bool) -> void:
	actions_panel.visible = false
	if party_wins:
		_log("Victory! All enemies defeated.")
	else:
		_log("Defeat! Party was defeated.")
	end_turn_btn.text = "Restart"
	end_turn_btn.pressed.disconnect(_on_end_turn_pressed)
	end_turn_btn.pressed.connect(_on_restart_pressed)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_attack_pressed() -> void:
	if _selected_target.is_empty():
		_log("Select a target (click an enemy in the list).")
		return
	var attacker = battle_manager.get_current_battler()
	if attacker.is_empty() or not attacker.stats.is_alive():
		return
	var dmg = battle_manager.perform_attack(attacker, _selected_target)
	_log("%s attacks %s for %d damage!" % [attacker.stats.display_name, _selected_target.stats.display_name, dmg])
	_refresh_party_and_enemy_lists()
	_selected_target = {}
	battle_manager.advance_turn()

func _on_end_turn_pressed() -> void:
	battle_manager.advance_turn()

func _on_party_item_selected(index: int) -> void:
	# Optional: select party member for heal/target
	enemy_list.deselect_all()
	_selected_target = {}
	party_list.select(index)

func _on_enemy_item_selected(index: int) -> void:
	var enemies = battle_manager.get_enemies()
	if index < 0 or index >= enemies.size():
		return
	var s: BattlerStats = enemies[index]
	if not s.is_alive():
		return
	_selected_target = { "stats": s, "index": index, "is_party": false }
	party_list.deselect_all()

func _log(msg: String) -> void:
	log_label.text = msg + "\n" + log_label.text
	# Keep last 8 lines
	var lines = log_label.text.split("\n")
	if lines.size() > 8:
		log_label.text = "\n".join(lines.slice(0, 8))
