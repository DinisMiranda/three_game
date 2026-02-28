extends Control
## Octopath-style battle: turn order bar at top, party left, enemies right.
## Placeholder sprite for all; enemies are flipped. Click enemy to target.

const BattlerSlotScene = preload("res://scenes/battle/battler_slot.tscn")
const PlaceholderTexture = preload("res://assets/character_placeholder.png")

@onready var turn_order_list: HBoxContainer = $Margin/VBox/TurnOrderBar/TurnOrderHBox/TurnOrderList
@onready var party_slots_container: FlowContainer = $Margin/VBox/ArenaRow/PartyArena/PartySlots
@onready var enemy_slots_container: FlowContainer = $Margin/VBox/ArenaRow/EnemyArena/EnemySlots
@onready var stats_list: VBoxContainer = $Margin/VBox/ArenaRow/PartyStatsPanel/StatsVBox/StatsList
@onready var log_label: Label = $Margin/VBox/BottomRow/LogPanel/Log
@onready var actions_panel: PanelContainer = $Margin/VBox/BottomRow/ActionsPanel
@onready var attack_btn: Button = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AttackBtn
@onready var end_turn_btn: Button = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/EndTurnBtn

var battle_manager: BattleManager
var _selected_target: Dictionary = {}
var _party_slots: Array[BattlerSlot] = []
var _enemy_slots: Array[BattlerSlot] = []

func _ready() -> void:
	battle_manager = BattleManager.new()
	add_child(battle_manager)
	battle_manager.turn_started.connect(_on_turn_started)
	battle_manager.turn_ended.connect(_on_turn_ended)
	battle_manager.turn_order_updated.connect(_on_turn_order_updated)
	battle_manager.battle_ended.connect(_on_battle_ended)
	attack_btn.pressed.connect(_on_attack_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
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
		s.speed = 8 + i * 2
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
	_build_arena()
	_refresh_party_stats_panel()
	_log("Battle start! Turn order is based on speed. Click an enemy to target.")

func _build_arena() -> void:
	# Clear existing
	for c in party_slots_container.get_children():
		c.queue_free()
	for c in enemy_slots_container.get_children():
		c.queue_free()
	_party_slots.clear()
	_enemy_slots.clear()

	var party = battle_manager.get_party()
	var enemies = battle_manager.get_enemies()
	var tex = PlaceholderTexture

	for i in party.size():
		var slot: BattlerSlot = BattlerSlotScene.instantiate()
		slot.slot_index = i
		slot.is_party = true
		slot.setup(party[i], tex)
		party_slots_container.add_child(slot)
		_party_slots.append(slot)

	for i in enemies.size():
		var slot: BattlerSlot = BattlerSlotScene.instantiate()
		slot.slot_index = i
		slot.is_party = false
		slot.setup(enemies[i], tex)
		slot.slot_clicked.connect(_on_enemy_slot_clicked)
		enemy_slots_container.add_child(slot)
		_enemy_slots.append(slot)
	_on_turn_order_updated(battle_manager.get_current_battler())

func _refresh_arena_slots() -> void:
	var party = battle_manager.get_party()
	var enemies = battle_manager.get_enemies()
	for i in _party_slots.size():
		if i < party.size():
			_party_slots[i].refresh()
	for i in _enemy_slots.size():
		if i < enemies.size():
			_enemy_slots[i].refresh()
	_refresh_party_stats_panel()

func _refresh_party_stats_panel() -> void:
	for c in stats_list.get_children():
		c.queue_free()
	var party = battle_manager.get_party()
	for i in party.size():
		var s: BattlerStats = party[i]
		var row = HBoxContainer.new()
		var name_l = Label.new()
		name_l.text = s.display_name + ":"
		name_l.custom_minimum_size.x = 70
		row.add_child(name_l)
		var bar = ProgressBar.new()
		bar.max_value = float(s.max_hp)
		bar.value = float(s.current_hp)
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		var hp_l = Label.new()
		hp_l.text = "%d/%d" % [s.current_hp, s.max_hp]
		row.add_child(hp_l)
		stats_list.add_child(row)

func _on_turn_order_updated(_order_arg = null) -> void:
	# Build turn order from manager
	var order: Array = []
	var party = battle_manager.get_party()
	var enemies = battle_manager.get_enemies()
	for i in party.size():
		if party[i].is_alive():
			order.append({ "stats": party[i], "index": i, "is_party": true })
	for i in enemies.size():
		if enemies[i].is_alive():
			order.append({ "stats": enemies[i], "index": i, "is_party": false })
	order.sort_custom(func(a, b): return a.stats.speed > b.stats.speed)

	for c in turn_order_list.get_children():
		c.queue_free()

	var current = battle_manager.get_current_battler()
	var cur_idx = -1
	if not current.is_empty():
		for i in order.size():
			var e = order[i]
			if e.is_party == current.is_party and e.index == current.index:
				cur_idx = i
				break

	for i in order.size():
		var entry: Dictionary = order[i]
		var s: BattlerStats = entry.stats
		var chip = Label.new()
		var side = "P" if entry.is_party else "E"
		chip.text = "%s %s" % [side, s.display_name]
		if i == cur_idx:
			chip.text += " [NEXT]"
			chip.add_theme_color_override("font_color", Color.YELLOW)
		turn_order_list.add_child(chip)

func _on_enemy_slot_clicked(slot_index: int, is_party: bool) -> void:
	if is_party:
		return
	var enemies = battle_manager.get_enemies()
	if slot_index < 0 or slot_index >= enemies.size():
		return
	var s: BattlerStats = enemies[slot_index]
	if not s.is_alive():
		return
	_selected_target = { "stats": s, "index": slot_index, "is_party": false }
	_highlight_selected_enemy()
	_log("Target: %s" % s.display_name)

func _highlight_selected_enemy() -> void:
	for i in _enemy_slots.size():
		var slot: BattlerSlot = _enemy_slots[i]
		if slot.get_stats() == _selected_target.get("stats", null):
			slot.modulate = Color(1.2, 1.2, 1.0)
		else:
			slot.modulate = Color.WHITE

func _on_turn_started(battler_index: int, is_party: bool) -> void:
	var current = battle_manager.get_current_battler()
	if current.is_empty():
		return
	var s: BattlerStats = current.stats
	if not s.is_alive():
		battle_manager.advance_turn()
		return
	_log("%s's turn (Speed: %d)" % [s.display_name, s.speed])
	_refresh_arena_slots()
	_on_turn_order_updated(null)
	if is_party:
		actions_panel.visible = true
		_selected_target = {}
		_highlight_selected_enemy()
	else:
		actions_panel.visible = false
		await get_tree().create_timer(0.8).timeout
		_ai_turn()

func _on_turn_ended(_battler_index: int, _is_party: bool) -> void:
	pass

func _ai_turn() -> void:
	var party = battle_manager.get_party()
	for i in party.size():
		var s: BattlerStats = party[i]
		if s.is_alive():
			var attacker = battle_manager.get_current_battler()
			var target = { "stats": s, "index": i, "is_party": true }
			var dmg = battle_manager.perform_attack(attacker, target)
			_log("%s attacks %s for %d damage!" % [attacker.stats.display_name, s.display_name, dmg])
			_refresh_arena_slots()
			break
	battle_manager.advance_turn()

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
		_log("Select a target: click an enemy on the right.")
		return
	var attacker = battle_manager.get_current_battler()
	if attacker.is_empty() or not attacker.stats.is_alive():
		return
	var dmg = battle_manager.perform_attack(attacker, _selected_target)
	_log("%s attacks %s for %d damage!" % [attacker.stats.display_name, _selected_target.stats.display_name, dmg])
	_refresh_arena_slots()
	_selected_target = {}
	_highlight_selected_enemy()
	battle_manager.advance_turn()

func _on_end_turn_pressed() -> void:
	battle_manager.advance_turn()

func _log(msg: String) -> void:
	log_label.text = msg + "\n" + log_label.text
	var lines = log_label.text.split("\n")
	if lines.size() > 10:
		log_label.text = "\n".join(lines.slice(0, 10))
