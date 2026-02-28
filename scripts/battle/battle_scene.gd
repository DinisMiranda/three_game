extends Control
## Battle screen: layout (party left, enemies right), UI, input, and sample battle setup.
## Creates the BattleManager, builds the arena from BattlerSlots, applies sci-fi theme,
## and wires turn/attack/target/restart to the UI.

const BattlerSlotScene = preload("res://scenes/battle/battler_slot.tscn")

# Idle: party faces right, enemies face left. Attack: one sprite per side (facing).
var _texture_idle_party: Texture2D
var _texture_idle_enemy: Texture2D
var _texture_attack_party: Texture2D   # attack facing right (player)
var _texture_attack_enemy: Texture2D   # attack facing left (enemies)
var _placeholder_texture: Texture2D

# --- Node references (must match battle_scene.tscn tree) ---
@onready var turn_order_list: HBoxContainer = $Margin/VBox/TurnOrderBar/TurnOrderHBox/TurnOrderList
@onready var party_slots_container: VBoxContainer = $Margin/VBox/ArenaRow/PartyArena/PartySlots
@onready var enemy_slots_container: VBoxContainer = $Margin/VBox/ArenaRow/EnemyArena/EnemySlots
@onready var stats_list: VBoxContainer = $Margin/VBox/ArenaRow/PartyStatsPanel/StatsVBox/StatsList
@onready var log_label: Label = $Margin/VBox/BottomRow/LogPanel/Log
@onready var actions_panel: PanelContainer = $Margin/VBox/BottomRow/ActionsPanel
@onready var attack_btn: Button = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AttackBtn
@onready var end_turn_btn: Button = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/EndTurnBtn

var battle_manager: BattleManager
var _selected_target: Dictionary = {}  # { "stats", "index", "is_party" } for current attack target
var _party_slots: Array[BattlerSlot] = []
var _enemy_slots: Array[BattlerSlot] = []

# Sci-fi palette used by _apply_sci_fi_theme and turn order / stats
const _COLOR_PANEL := Color(0.08, 0.09, 0.12, 0.95)
const _COLOR_BORDER := Color(0.0, 0.85, 1.0, 0.6)
const _COLOR_TEXT := Color(0.9, 0.92, 0.95, 1)
const _COLOR_ACCENT := Color(0.0, 0.9, 1.0, 1)
const _COLOR_LOG := Color(0.0, 1.0, 0.55, 0.95)
const _COLOR_NEXT := Color(1.0, 0.75, 0.2, 1)

func _ready() -> void:
	_placeholder_texture = load("res://assets/character_placeholder.png") as Texture2D
	if _placeholder_texture == null:
		_placeholder_texture = preload("res://assets/character_placeholder.png") as Texture2D
	# Sevro: two facing directions (party = right, enemy = left) + attack sprite per side
	_texture_idle_party = load("res://assets/sevro_pixel_no_bg.png") as Texture2D
	_texture_idle_enemy = load("res://assets/sevro_pixel_no_bg-removebg-preview.png") as Texture2D
	_texture_attack_party = load("res://assets/sevro_atack_no_bg_1-removebg-preview.png") as Texture2D   # face right
	_texture_attack_enemy = load("res://assets/sevro_atack_no_bg.png") as Texture2D   # face left
	if _texture_idle_party == null:
		_texture_idle_party = _placeholder_texture
	if _texture_idle_enemy == null:
		_texture_idle_enemy = _placeholder_texture
	if _texture_attack_party == null:
		_texture_attack_party = _placeholder_texture
	if _texture_attack_enemy == null:
		_texture_attack_enemy = _placeholder_texture
	_apply_sci_fi_theme()
	battle_manager = BattleManager.new()
	add_child(battle_manager)
	battle_manager.turn_started.connect(_on_turn_started)
	battle_manager.turn_ended.connect(_on_turn_ended)
	battle_manager.turn_order_updated.connect(_on_turn_order_updated)
	battle_manager.battle_ended.connect(_on_battle_ended)
	attack_btn.pressed.connect(_on_attack_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_start_sample_battle()

# --- Apply dark panels, cyan borders, and text/button styles to all main UI elements ---
func _apply_sci_fi_theme() -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = _COLOR_PANEL
	panel_style.border_color = _COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(0)
	panel_style.set_content_margin_all(12)

	var turn_bar = $Margin/VBox/TurnOrderBar
	if turn_bar is PanelContainer:
		turn_bar.add_theme_stylebox_override("panel", panel_style.duplicate())
	$Margin/VBox/TurnOrderBar/TurnOrderHBox/TurnOrderLabel.add_theme_color_override("font_color", _COLOR_TEXT)

	$Margin/VBox/ArenaRow/PartyArena/PartyLabel.add_theme_color_override("font_color", _COLOR_TEXT)
	$Margin/VBox/ArenaRow/EnemyArena/EnemyLabel.add_theme_color_override("font_color", _COLOR_TEXT)

	var stats_panel_style = panel_style.duplicate()
	$Margin/VBox/ArenaRow/PartyStatsPanel.add_theme_stylebox_override("panel", stats_panel_style)
	$Margin/VBox/ArenaRow/PartyStatsPanel/StatsVBox/StatsTitle.add_theme_color_override("font_color", _COLOR_ACCENT)

	var actions_style = panel_style.duplicate()
	$Margin/VBox/BottomRow/ActionsPanel.add_theme_stylebox_override("panel", actions_style)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/ActionsLabel.add_theme_color_override("font_color", _COLOR_TEXT)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AttackBtn.add_theme_color_override("font_color", _COLOR_TEXT)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AttackBtn.add_theme_stylebox_override("normal", _make_btn_style(false))
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AttackBtn.add_theme_stylebox_override("hover", _make_btn_style(true))
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/EndTurnBtn.add_theme_color_override("font_color", _COLOR_TEXT)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/EndTurnBtn.add_theme_stylebox_override("normal", _make_btn_style(false))
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/EndTurnBtn.add_theme_stylebox_override("hover", _make_btn_style(true))

	var log_style = panel_style.duplicate()
	(log_style as StyleBoxFlat).bg_color = Color(0.04, 0.05, 0.08, 0.98)
	$Margin/VBox/BottomRow/LogPanel.add_theme_stylebox_override("panel", log_style)
	log_label.add_theme_color_override("font_color", _COLOR_LOG)

func _make_btn_style(hover: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.14, 0.18, 1) if not hover else Color(0.18, 0.22, 0.28, 1)
	s.border_color = _COLOR_BORDER
	s.set_border_width_all(1)
	s.set_content_margin_all(8)
	return s

# --- Create 4 heroes and 1–4 enemies, give to BattleManager, then build arena and UI ---
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

# --- Returns an HBoxContainer for a row of slots. If behind=true, wrap in MarginContainer (indent). ---
# Rows get size_flags_vertical = EXPAND so they fill the arena height and share space equally.
func _make_row(container: VBoxContainer, behind: bool) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 24)
	if behind:
		var m = MarginContainer.new()
		m.size_flags_vertical = Control.SIZE_EXPAND_FILL
		m.add_theme_constant_override("margin_left", 28)
		m.add_child(h)
		container.add_child(m)
	else:
		container.add_child(h)
	return h

# --- Clear slots, then create party formation (>) and enemy formation (<) with BattlerSlots ---
func _build_arena() -> void:
	for c in party_slots_container.get_children():
		c.queue_free()
	for c in enemy_slots_container.get_children():
		c.queue_free()
	_party_slots.clear()
	_enemy_slots.clear()

	var party = battle_manager.get_party()
	var enemies = battle_manager.get_enemies()
	var idle_party = _texture_idle_party if _texture_idle_party else _placeholder_texture
	var idle_enemy = _texture_idle_enemy if _texture_idle_enemy else _placeholder_texture
	var attack_party = _texture_attack_party if _texture_attack_party else _placeholder_texture
	var attack_enemy = _texture_attack_enemy if _texture_attack_enemy else _placeholder_texture

	# Party: idle face right + attack face right
	var party_back_row = _make_row(party_slots_container, true)
	var party_front_row = _make_row(party_slots_container, false)
	# Add to tree before setup() so @onready (texture_rect) is ready and texture applies immediately.
	for i in [0, 1]:
		if i < party.size():
			var slot: BattlerSlot = BattlerSlotScene.instantiate()
			slot.slot_index = i
			slot.is_party = true
			party_back_row.add_child(slot)
			slot.setup(party[i], idle_party, attack_party)
			_party_slots.append(slot)
	for i in [2, 3]:
		if i < party.size():
			var slot: BattlerSlot = BattlerSlotScene.instantiate()
			slot.slot_index = i
			slot.is_party = true
			party_front_row.add_child(slot)
			slot.setup(party[i], idle_party, attack_party)
			_party_slots.append(slot)

	# Enemies: idle face left + attack face left
	var n = enemies.size()
	var enemy_back_row = _make_row(enemy_slots_container, true)
	var enemy_front_row = _make_row(enemy_slots_container, false)
	if n >= 3:
		for i in [2, 3]:
			if i < n:
				var slot: BattlerSlot = BattlerSlotScene.instantiate()
				slot.slot_index = i
				slot.is_party = false
				slot.slot_clicked.connect(_on_enemy_slot_clicked)
				enemy_back_row.add_child(slot)
				slot.setup(enemies[i], idle_enemy, attack_enemy)
				_enemy_slots.append(slot)
	for i in [0, 1]:
		if i < n:
			var slot: BattlerSlot = BattlerSlotScene.instantiate()
			slot.slot_index = i
			slot.is_party = false
			slot.slot_clicked.connect(_on_enemy_slot_clicked)
			enemy_front_row.add_child(slot)
			slot.setup(enemies[i], idle_enemy, attack_enemy)
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

# --- Rebuild the right-hand party status list: name, HP bar, HP numbers ---
func _refresh_party_stats_panel() -> void:
	for c in stats_list.get_children():
		c.queue_free()
	var party = battle_manager.get_party()
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.06, 0.07, 0.1, 1)
	bar_bg.set_corner_radius_all(2)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = _COLOR_ACCENT
	bar_fill.set_corner_radius_all(2)
	for i in party.size():
		var s: BattlerStats = party[i]
		var row = HBoxContainer.new()
		var name_l = Label.new()
		name_l.text = s.display_name + ":"
		name_l.custom_minimum_size.x = 80
		name_l.add_theme_color_override("font_color", _COLOR_TEXT)
		row.add_child(name_l)
		var bar = ProgressBar.new()
		bar.max_value = float(s.max_hp)
		bar.value = float(s.current_hp)
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_theme_stylebox_override("background", bar_bg)
		bar.add_theme_stylebox_override("fill", bar_fill)
		row.add_child(bar)
		var hp_l = Label.new()
		hp_l.text = " %d/%d" % [s.current_hp, s.max_hp]
		hp_l.add_theme_color_override("font_color", _COLOR_TEXT)
		row.add_child(hp_l)
		stats_list.add_child(row)

# --- Rebuild the turn order bar: labels for each battler; current gets "TURN" panel + amber ---
func _on_turn_order_updated(_order_arg = null) -> void:
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
		var side = "P" if entry.is_party else "E"
		var is_current = (i == cur_idx)
		if is_current:
			var box = PanelContainer.new()
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.12, 0.1, 0.05, 0.95)
			style.border_color = _COLOR_NEXT
			style.set_border_width_all(2)
			style.set_content_margin_all(6)
			box.add_theme_stylebox_override("panel", style)
			var chip = Label.new()
			chip.text = "  ► TURN: %s %s  " % [side, s.display_name]
			chip.add_theme_color_override("font_color", _COLOR_NEXT)
			chip.add_theme_font_size_override("font_size", 16)
			box.add_child(chip)
			turn_order_list.add_child(box)
		else:
			var chip = Label.new()
			chip.text = "%s %s" % [side, s.display_name]
			chip.add_theme_color_override("font_color", _COLOR_TEXT)
			turn_order_list.add_child(chip)

	# Highlight in the arena the slot whose turn it is (amber border)
	var attacker_slot = _get_attacker_slot()
	for slot in _party_slots:
		slot.set_turn_highlight(slot == attacker_slot)
	for slot in _enemy_slots:
		slot.set_turn_highlight(slot == attacker_slot)

# --- When user clicks an enemy slot: set _selected_target and highlight that slot ---
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

# --- BattleManager said "this character's turn". Update UI; if party, show actions; if enemy, run AI after delay. ---
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

# --- Returns the BattlerSlot for the current attacker (for attack animation). ---
func _get_attacker_slot() -> BattlerSlot:
	var current = battle_manager.get_current_battler()
	if current.is_empty():
		return null
	if current.is_party:
		if current.index >= 0 and current.index < _party_slots.size():
			return _party_slots[current.index]
	else:
		if current.index >= 0 and current.index < _enemy_slots.size():
			return _enemy_slots[current.index]
	return null

# --- Simple AI: current enemy attacks first alive party member, then we advance_turn ---
func _ai_turn() -> void:
	var party = battle_manager.get_party()
	for i in party.size():
		var s: BattlerStats = party[i]
		if s.is_alive():
			var attacker = battle_manager.get_current_battler()
			var attacker_slot: BattlerSlot = _get_attacker_slot()
			if attacker_slot:
				await attacker_slot.play_attack_animation()
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

# --- Attack button: play attack animation on attacker, then damage, refresh, advance_turn ---
func _on_attack_pressed() -> void:
	if _selected_target.is_empty():
		_log("Select a target: click an enemy on the right.")
		return
	var attacker = battle_manager.get_current_battler()
	if attacker.is_empty() or not attacker.stats.is_alive():
		return
	var attacker_slot: BattlerSlot = _get_attacker_slot()
	if attacker_slot:
		await attacker_slot.play_attack_animation()
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
