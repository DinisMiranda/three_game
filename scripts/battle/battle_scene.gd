extends Control
## Battle screen: layout (party left, enemies right), UI, input, and sample battle setup.
## Creates the BattleManager, builds the arena from BattlerSlots, applies sci-fi theme,
## and wires turn/attack/target/restart to the UI.

const BattlerSlotScene = preload("res://scenes/battle/battler_slot.tscn")
const OptionsMenuScene = preload("res://scenes/ui/options_menu.tscn")

# Idle: party and enemies each have per-character sprites (face right / left). Attack: one per side, with per-character overrides.
var _texture_idle_party: Array[Texture2D] = []
var _texture_idle_enemy: Array[Texture2D] = []   # one texture per enemy (face left)
var _texture_attack_party: Texture2D
var _texture_attack_enemy: Texture2D
var _placeholder_texture: Texture2D
var _hero2_attack_frames: Array[Texture2D] = []
var _hero3_attack_frames: Array[Texture2D] = []
var _enemy0_attack_frames: Array[Texture2D] = []
var _enemy1_attack_frames: Array[Texture2D] = []
var _enemy2_attack_frames: Array[Texture2D] = []

# --- Node references (must match battle_scene.tscn tree) ---
@onready var battle_background: TextureRect = $Background
@onready var floor_banner: Label = $Margin/VBox/FloorBanner
@onready var turn_order_list: HBoxContainer = $Margin/VBox/TurnOrderBar/TurnOrderHBox/TurnOrderList
@onready var party_slots_container: VBoxContainer = $Margin/VBox/ArenaRow/PartyArena/PartySlots
@onready var enemy_slots_container: VBoxContainer = $Margin/VBox/ArenaRow/EnemyArena/EnemySlots
@onready var stats_list: VBoxContainer = $Margin/VBox/ArenaRow/PartyStatsPanel/StatsVBox/StatsList
@onready var log_scroll: ScrollContainer = $Margin/VBox/BottomRow/LogPanel/LogScroll
@onready var log_label: RichTextLabel = $Margin/VBox/BottomRow/LogPanel/LogScroll/Log
@onready var enemy_turn_flash: ColorRect = $EnemyTurnFlash
@onready var floating_text_layer: CanvasLayer = $FloatingTextLayer
@onready var end_screen: CanvasLayer = $EndScreen
@onready var end_title: Label = $EndScreen/Center/Panel/VBox/EndTitle
@onready var next_floor_btn: Button = $EndScreen/Center/Panel/VBox/NextFloorBtn
@onready var back_to_menu_btn: Button = $EndScreen/Center/Panel/VBox/BackToMenuBtn
@onready var actions_panel: PanelContainer = $Margin/VBox/BottomRow/ActionsPanel
@onready var attack_btn: Button = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AttackBtn
@onready var abilities_btn: Button = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AbilitiesBtn
@onready var end_turn_btn: Button = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/EndTurnRow/EndTurnBtn
@onready var ability_sub_panel: VBoxContainer = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel
@onready var ability_buttons_container: HBoxContainer = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel/AbilityButtonsContainer
@onready var ability_back_btn: Button = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel/AbilityBackBtn

const ATTACK_ANIM_ABILITIES: Array[String] = [
	"grenade", "slash", "strike", "snipe", "ranged_shot", "barrage", "frenzy"
]

var battle_manager: BattleManager
var _selected_target: Dictionary = {}  # { "stats", "index", "is_party" } for current attack target
var _party_slots: Array[BattlerSlot] = []
var _enemy_slots: Array[BattlerSlot] = []
var _options_menu: CanvasLayer
var _enemy_turn_token: int = 0
var _action_busy: bool = false
var _ai_running: bool = false

# Sci-fi palette used by _apply_sci_fi_theme and turn order / stats
const _COLOR_PANEL := Color(0.08, 0.09, 0.12, 0.95)
const _COLOR_BORDER := Color(0.0, 0.85, 1.0, 0.6)
const _COLOR_TEXT := Color(0.9, 0.92, 0.95, 1)
const _COLOR_ACCENT := Color(0.0, 0.9, 1.0, 1)
const _COLOR_LOG := Color(0.0, 1.0, 0.55, 0.95)
const _COLOR_NEXT := Color(1.0, 0.75, 0.2, 1)

const _COLOR_LOG_ENEMY := Color(1.0, 0.45, 0.42, 1)
const _COLOR_LOG_CRIT := Color(1.0, 0.55, 0.2, 1)
const _COLOR_LOG_ABSORB := Color(0.45, 0.75, 1.0, 1)
const _COLOR_LOG_MISS := Color(0.65, 0.68, 0.75, 1)
const _COLOR_LOG_VICTORY := Color(0.35, 1.0, 0.65, 1)
const _COLOR_LOG_DEFEAT := Color(1.0, 0.35, 0.4, 1)
const _COLOR_LOG_BARK := Color(0.95, 0.88, 0.45, 1)

func _ready() -> void:
	_placeholder_texture = load("res://assets/character_placeholder.png") as Texture2D
	if _placeholder_texture == null:
		_placeholder_texture = preload("res://assets/character_placeholder.png") as Texture2D
	# Heroes: 3 idle sprites (face right). Enemies: per-enemy idle sprites (face left).
	_texture_idle_party.clear()
	for i in HeroRoster.ACTIVE_PARTY_SIZE:
		var path: String = HeroRoster.get_portrait_path(i)
		var tex: Texture2D = load(path) as Texture2D if not path.is_empty() else null
		_texture_idle_party.append(tex if tex != null else _placeholder_texture)
	_texture_idle_enemy.clear()
	var enemy_paths := [
		"res://assets/enemy_1-removebg-preview.png",
		"res://assets/enemy_2-removebg-preview.png",
		"res://assets/enemy_2-removebg-preview copy.png",
		"res://assets/inimigo_soldado.png"
	]
	for path in enemy_paths:
		var tex = load(path) as Texture2D
		_texture_idle_enemy.append(tex if tex != null else _placeholder_texture)
	if _texture_idle_enemy.is_empty():
		_texture_idle_enemy.append(_placeholder_texture)
	_texture_attack_party = load("res://assets/sevro_atack_no_bg_1-removebg-preview.png") as Texture2D
	_texture_attack_enemy = load("res://assets/sevro_atack_no_bg.png") as Texture2D
	var hero2_attack_tex = load("res://assets/hero2_attack_animation.png") as Texture2D
	_hero2_attack_frames.clear()
	if hero2_attack_tex != null:
		_hero2_attack_frames.append(hero2_attack_tex)
	var hero3_attack_tex = load("res://assets/hero3_attack-removebg copy.png") as Texture2D
	_hero3_attack_frames.clear()
	if hero3_attack_tex != null:
		_hero3_attack_frames.append(hero3_attack_tex)
	var enemy_attack_1 = load("res://assets/enemy_1_attack_animantion_part1-removebg-preview.png") as Texture2D
	var enemy_attack_2 = load("res://assets/enemy1_attack_animation_part2-removebg-preview.png") as Texture2D
	var enemy2_attack = load("res://assets/enemy_2_attack_animation.png") as Texture2D
	var soldier_attack = load("res://assets/inimigo_soldado_ataque.png") as Texture2D
	_enemy0_attack_frames.clear()
	if enemy_attack_1 != null:
		_enemy0_attack_frames.append(enemy_attack_1)
	if enemy_attack_2 != null:
		_enemy0_attack_frames.append(enemy_attack_2)
	_enemy1_attack_frames.clear()
	if enemy2_attack != null:
		_enemy1_attack_frames.append(enemy2_attack)
	_enemy2_attack_frames.clear()
	if soldier_attack != null:
		_enemy2_attack_frames.append(soldier_attack)
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
	abilities_btn.pressed.connect(_on_abilities_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	ability_back_btn.pressed.connect(_on_ability_back_pressed)
	back_to_menu_btn.pressed.connect(_on_back_to_menu_pressed)
	next_floor_btn.pressed.connect(_on_next_floor_pressed)
	_apply_end_screen_theme()
	_options_menu = OptionsMenuScene.instantiate()
	add_child(_options_menu)
	MusicPlayer.play_battle()
	_start_sample_battle()
	_apply_mission_floor_visuals()

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
	(actions_style as StyleBoxFlat).set_content_margin_all(20)
	$Margin/VBox/BottomRow/ActionsPanel.add_theme_stylebox_override("panel", actions_style)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AttackBtn.add_theme_color_override("font_color", _COLOR_TEXT)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AttackBtn.add_theme_font_size_override("font_size", 20)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AttackBtn.add_theme_stylebox_override("normal", _make_btn_style(false))
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AttackBtn.add_theme_stylebox_override("hover", _make_btn_style(true))
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AbilitiesBtn.add_theme_color_override("font_color", _COLOR_TEXT)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AbilitiesBtn.add_theme_font_size_override("font_size", 20)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AbilitiesBtn.add_theme_stylebox_override("normal", _make_btn_style(false))
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons/AbilitiesBtn.add_theme_stylebox_override("hover", _make_btn_style(true))
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/EndTurnRow/EndTurnBtn.add_theme_color_override("font_color", _COLOR_TEXT)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/EndTurnRow/EndTurnBtn.add_theme_font_size_override("font_size", 22)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/EndTurnRow/EndTurnBtn.add_theme_stylebox_override("normal", _make_btn_style(false))
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/EndTurnRow/EndTurnBtn.add_theme_stylebox_override("hover", _make_btn_style(true))
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel/AbilityLabel.add_theme_color_override("font_color", _COLOR_TEXT)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel/AbilityBackBtn.add_theme_color_override("font_color", _COLOR_TEXT)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel/AbilityBackBtn.add_theme_stylebox_override("normal", _make_btn_style(false))
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel/AbilityBackBtn.add_theme_stylebox_override("hover", _make_btn_style(true))

	var log_style = panel_style.duplicate()
	(log_style as StyleBoxFlat).bg_color = Color(0.04, 0.05, 0.08, 0.98)
	$Margin/VBox/BottomRow/LogPanel.add_theme_stylebox_override("panel", log_style)
	log_label.add_theme_color_override("default_color", _COLOR_LOG)

func _apply_end_screen_theme() -> void:
	var panel = $EndScreen/Center/Panel
	if panel is PanelContainer:
		var s = StyleBoxFlat.new()
		s.bg_color = _COLOR_PANEL
		s.border_color = _COLOR_BORDER
		s.set_border_width_all(2)
		s.set_content_margin_all(24)
		panel.add_theme_stylebox_override("panel", s)
	end_title.add_theme_color_override("font_color", _COLOR_ACCENT)
	end_title.add_theme_font_size_override("font_size", 36)
	next_floor_btn.add_theme_color_override("font_color", _COLOR_TEXT)
	next_floor_btn.add_theme_stylebox_override("normal", _make_btn_style(false))
	next_floor_btn.add_theme_stylebox_override("hover", _make_btn_style(true))
	back_to_menu_btn.add_theme_color_override("font_color", _COLOR_TEXT)
	back_to_menu_btn.add_theme_stylebox_override("normal", _make_btn_style(false))
	back_to_menu_btn.add_theme_stylebox_override("hover", _make_btn_style(true))

func _make_btn_style(hover: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.14, 0.18, 1) if not hover else Color(0.18, 0.22, 0.28, 1)
	s.border_color = _COLOR_BORDER
	s.set_border_width_all(1)
	s.set_content_margin_all(16)
	return s


func _set_player_actions_enabled(enabled: bool) -> void:
	attack_btn.disabled = not enabled
	abilities_btn.disabled = not enabled
	end_turn_btn.disabled = not enabled


func _is_current_party_battler(battler: Dictionary) -> bool:
	if battler.is_empty():
		return false
	var current = battle_manager.get_current_battler()
	if current.is_empty() or not current.is_party:
		return false
	return current.index == battler.index and current.stats == battler.stats


func _is_current_battler(battler: Dictionary) -> bool:
	if battler.is_empty():
		return false
	var current = battle_manager.get_current_battler()
	if current.is_empty():
		return false
	return current.index == battler.index and current.is_party == battler.is_party and current.stats == battler.stats


func _apply_mission_floor_visuals() -> void:
	_apply_battle_background("res://assets/andar.jpg")
	if not MissionProgress.is_meridian_spire_active():
		floor_banner.visible = false
		return
	floor_banner.visible = true
	var info: Dictionary = MissionProgress.get_meridian_floor_info()
	var title: String = str(info.get("title", ""))
	floor_banner.text = "MERIDIAN SPIRE · %s" % title
	var bg_path: String = str(info.get("bg", ""))
	if not bg_path.is_empty():
		_apply_battle_background(bg_path)


func _apply_battle_background(path: String) -> void:
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		battle_background.texture = tex
	else:
		push_warning("Missing battle background: %s" % path)


func _build_sample_party() -> Array:
	var party: Array = []
	for i in HeroRoster.ACTIVE_PARTY_SIZE:
		var s = BattlerStats.new()
		if not HeroRoster.apply_to_stats(i, s):
			s.display_name = "Hero %d" % (i + 1)
			s.max_hp = 80 + i * 10
			s.current_hp = s.max_hp
			s.max_energy = 100
			s.current_energy = 100
			s.attack = 12 + i
			s.defense = 4
			s.speed = 8 + i * 2
			s.is_party = true
		party.append(s)
	return party


func _build_sample_enemies() -> Array:
	var enemies: Array = []
	var hp_bonus: int = 0
	var floor_idx: int = 1
	if MissionProgress.is_meridian_spire_active():
		floor_idx = MissionProgress.meridian_floor
		hp_bonus = (MissionProgress.meridian_floor - 1) * 10
	var enemy_count: int = 1
	match floor_idx:
		1:
			enemy_count = 1
		2:
			enemy_count = 2
		_:
			enemy_count = 1
	for i in enemy_count:
		var s = BattlerStats.new()
		if floor_idx >= 3 and i == 0:
			s.display_name = "Custodian Unit"
			s.max_hp = 55 + hp_bonus
			s.attack = 20 + (MissionProgress.meridian_floor - 1) * 2
			s.speed = 7
		else:
			s.display_name = "Enemy %d" % (i + 1)
			s.max_hp = 40 + i * 10 + hp_bonus
			s.attack = 16 + i * 2 + (MissionProgress.meridian_floor - 1) * 2
			s.speed = 5 + i * 3
		s.current_hp = s.max_hp
		s.max_energy = 100
		s.current_energy = 100
		s.defense = 3
		s.is_party = false
		s.is_ranged = floor_idx < 3 and (i % 3) == 0
		enemies.append(s)
	return enemies


# --- Create 3 heroes and 1 enemy, give to BattleManager, then build arena and UI ---
func _start_sample_battle() -> void:
	var party: Array = _build_sample_party()
	var enemies: Array = _build_sample_enemies()
	battle_manager.setup_battle(party, enemies)
	_build_arena()
	_refresh_party_stats_panel()
	_log("Battle start! Turn order is based on speed. Click an enemy to target.", "system")

# --- Returns an HBoxContainer for a row of slots. If behind=true, wrap in MarginContainer (indent). ---
# If add_leading_spacer=true, prepend an expanding spacer (e.g. to push enemy slots to the right).
# top_margin: optional extra top margin (e.g. to push back row down so Hero 1 is "on the ground").
func _make_row(container: VBoxContainer, behind: bool, add_leading_spacer: bool = false, top_margin: int = 0) -> HBoxContainer:
	var h = HBoxContainer.new()
	# Don't expand vertically — row height = content height, so we can align rows to bottom ("on the ground").
	h.size_flags_vertical = 0
	h.add_theme_constant_override("separation", 48)
	if add_leading_spacer:
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(spacer)
	if behind:
		var m = MarginContainer.new()
		m.size_flags_vertical = 0
		m.add_theme_constant_override("margin_left", 28)
		if top_margin > 0:
			m.add_theme_constant_override("margin_top", top_margin)
		m.add_child(h)
		container.add_child(m)
	else:
		container.add_child(h)
	return h

# --- Clear slots, then create party formation (>) and enemy formation (<) with BattlerSlots ---
func _clear_arena_container(container: Node) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()

func _build_arena() -> void:
	_clear_arena_container(party_slots_container)
	_clear_arena_container(enemy_slots_container)
	_party_slots.clear()
	_enemy_slots.clear()

	var party = battle_manager.get_party()
	var enemies = battle_manager.get_enemies()
	var attack_party = _texture_attack_party if _texture_attack_party else _placeholder_texture
	var attack_enemy = _texture_attack_enemy if _texture_attack_enemy else _placeholder_texture

	# Party: 3 heroes in one row on the ground — Hero 2 (left), Hero 1 (center), Hero 3 (right).
	var party_row = _make_row(party_slots_container, false)
	party_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var party_visual_order := [1, 0, 2]  # Hero 2, Hero 1, Hero 3 — Hero 1 in the middle
	for idx in party_visual_order.size():
		var i: int = party_visual_order[idx]
		if i >= party.size():
			continue
		var idle_i: Texture2D = _placeholder_texture
		if i < _texture_idle_party.size() and _texture_idle_party[i] != null:
			idle_i = _texture_idle_party[i]
		var slot: BattlerSlot = BattlerSlotScene.instantiate()
		slot.slot_index = i
		slot.is_party = true
		party_row.add_child(slot)
		slot.setup(party[i], idle_i, attack_party)
		slot.set_role_display(HeroRoster.get_role_label(i), HeroRoster.get_role_color(i))
		if i == 1 and not _hero2_attack_frames.is_empty():
			slot.set_attack_frames(_hero2_attack_frames)
		elif i == 2 and not _hero3_attack_frames.is_empty():
			slot.set_attack_frames(_hero3_attack_frames)
		_party_slots.append(slot)
	# Keep _party_slots indexed by party index for _get_attacker_slot()
	_party_slots.sort_custom(func(a, b): return a.slot_index < b.slot_index)
	party_slots_container.alignment = BoxContainer.ALIGNMENT_END

	# Enemies: idle face left + attack face left; leading spacer pushes them to the right
	var n = enemies.size()
	var enemy_back_row = _make_row(enemy_slots_container, true, true)
	var enemy_front_row = _make_row(enemy_slots_container, false, true)
	var get_enemy_idle = func(idx: int) -> Texture2D:
		if idx < _texture_idle_enemy.size() and _texture_idle_enemy[idx] != null:
			return _texture_idle_enemy[idx]
		return _placeholder_texture
	if n >= 3:
		for i in [2, 3]:
			if i < n:
				var slot: BattlerSlot = BattlerSlotScene.instantiate()
				slot.slot_index = i
				slot.is_party = false
				slot.slot_clicked.connect(_on_enemy_slot_clicked)
				enemy_back_row.add_child(slot)
				slot.setup(enemies[i], get_enemy_idle.call(i), attack_enemy, Vector2(380, 494))
				_enemy_slots.append(slot)
	for i in [0, 1]:
		if i < n:
			var slot: BattlerSlot = BattlerSlotScene.instantiate()
			slot.slot_index = i
			slot.is_party = false
			slot.slot_clicked.connect(_on_enemy_slot_clicked)
			enemy_front_row.add_child(slot)
			slot.setup(enemies[i], get_enemy_idle.call(i), attack_enemy, Vector2(380, 494))
			if i == 0 and not _enemy0_attack_frames.is_empty():
				slot.set_attack_frames(_enemy0_attack_frames)
			elif i == 1 and not _enemy1_attack_frames.is_empty():
				slot.set_attack_frames(_enemy1_attack_frames)
			elif i == 2 and not _enemy2_attack_frames.is_empty():
				slot.set_attack_frames(_enemy2_attack_frames)
			_enemy_slots.append(slot)
	enemy_slots_container.alignment = BoxContainer.ALIGNMENT_END
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
		name_l.custom_minimum_size.x = 96
		name_l.add_theme_color_override("font_color", HeroRoster.get_role_color(i))
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
		hp_l.text = " %d/%d  E:%d/%d" % [s.current_hp, s.max_hp, s.current_energy, s.max_energy]
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
	var attacker = battle_manager.get_current_battler()
	for i in _enemy_slots.size():
		var slot: BattlerSlot = _enemy_slots[i]
		var tgt = { "stats": slot.get_stats(), "index": i, "is_party": false }
		if slot.get_stats() == _selected_target.get("stats", null):
			slot.modulate = Color(1.2, 1.2, 1.0)
		elif not attacker.is_empty() and not battle_manager.can_attack_target(attacker, tgt):
			slot.modulate = Color(0.5, 0.5, 0.55)
		else:
			slot.modulate = Color.WHITE

# --- BattleManager said "this character's turn". Update UI; if party, show actions; if enemy, run AI after delay. ---
func _on_turn_started(_battler_index: int, is_party: bool) -> void:
	var current = battle_manager.get_current_battler()
	if current.is_empty():
		return
	var s: BattlerStats = current.stats
	if not s.is_alive():
		battle_manager.advance_turn()
		return
	_log("%s's turn (Speed: %d)" % [s.display_name, s.speed], "turn" if is_party else "enemy_turn")
	_refresh_arena_slots()
	_on_turn_order_updated(null)
	if is_party:
		_action_busy = false
		_set_player_actions_enabled(true)
		actions_panel.visible = true
		ability_sub_panel.visible = false
		_selected_target = {}
		_highlight_selected_enemy()
	else:
		_action_busy = true
		_set_player_actions_enabled(false)
		actions_panel.visible = false
		ability_sub_panel.visible = false
		_enemy_turn_token += 1
		var token := _enemy_turn_token
		await _play_enemy_turn_intro(s, token)
		if token != _enemy_turn_token or not is_inside_tree():
			return
		_ai_turn()

func _play_enemy_turn_intro(_enemy_stats: BattlerStats, token: int) -> void:
	var attacker_slot: BattlerSlot = _get_attacker_slot()
	if attacker_slot:
		attacker_slot.play_enemy_turn_flash()
	if enemy_turn_flash:
		enemy_turn_flash.visible = true
		enemy_turn_flash.modulate = Color(1, 1, 1, 0)
		var flash_tw := create_tween()
		flash_tw.tween_property(enemy_turn_flash, "modulate:a", 1.0, 0.12)
		flash_tw.tween_property(enemy_turn_flash, "modulate:a", 0.0, 0.35)
		flash_tw.finished.connect(func(): enemy_turn_flash.visible = false)
	await get_tree().create_timer(0.55).timeout
	if token != _enemy_turn_token:
		return
	await get_tree().create_timer(0.35).timeout


func _on_turn_ended(_battler_index: int, _is_party: bool) -> void:
	pass

# --- Returns the BattlerSlot for the current attacker (for attack animation). ---
func _get_attacker_slot() -> BattlerSlot:
	var current = battle_manager.get_current_battler()
	if current.is_empty():
		return null
	return _get_target_slot(current.index, current.is_party)

func _get_target_slot(index: int, is_party: bool) -> BattlerSlot:
	if is_party:
		for slot in _party_slots:
			if slot.slot_index == index:
				return slot
	else:
		for slot in _enemy_slots:
			if slot.slot_index == index:
				return slot
	return null

# --- AI: pattern-based enemy turns (ranged tactician, berserker, soldier). ---
func _ai_turn() -> void:
	if _ai_running:
		return
	_ai_running = true
	var attacker = battle_manager.get_current_battler()
	if attacker.is_empty() or attacker.is_party:
		_ai_running = false
		return
	var action: Dictionary = _choose_enemy_action(attacker)
	if action.is_empty():
		_ai_running = false
		battle_manager.advance_turn()
		return
	if action.get("kind", "") == "ability":
		var ability_id: String = str(action.get("id", ""))
		var ability_name: String = str(action.get("name", ability_id))
		var target: Dictionary = {}
		if bool(action.get("needs_target", false)):
			target = _pick_party_target_for_enemy(attacker, ability_id)
			if target.is_empty():
				_ai_running = false
				battle_manager.advance_turn()
				return
		var attacker_slot: BattlerSlot = _get_attacker_slot()
		if ability_id in ATTACK_ANIM_ABILITIES and attacker_slot:
			await attacker_slot.play_attack_animation()
		if not is_inside_tree() or not _is_current_battler(attacker):
			_ai_running = false
			return
		if not battle_manager.perform_ability(attacker, ability_id, target):
			_ai_running = false
			battle_manager.advance_turn()
			return
		_log_enemy_ability(attacker, ability_id, ability_name, target)
		_apply_hit_results(battle_manager.last_hit_results)
		_refresh_arena_slots()
		_ai_running = false
		battle_manager.advance_turn()
		return
	var target: Dictionary = _pick_party_target_for_enemy(attacker, "attack")
	if target.is_empty():
		_ai_running = false
		battle_manager.advance_turn()
		return
	var attacker_slot: BattlerSlot = _get_attacker_slot()
	if attacker_slot:
		await attacker_slot.play_attack_animation()
	if not is_inside_tree() or not _is_current_battler(attacker):
		_ai_running = false
		return
	battle_manager.last_hit_results.clear()
	var dmg = battle_manager.perform_attack(attacker, target)
	_apply_hit_results(battle_manager.last_hit_results)
	_log_attack_result(attacker.stats.display_name, target.stats.display_name, dmg, battle_manager.last_hit_kind)
	_refresh_arena_slots()
	_ai_running = false
	battle_manager.advance_turn()


func _choose_enemy_action(attacker: Dictionary) -> Dictionary:
	var idx: int = attacker.index
	var hp_pct: float = float(attacker.stats.current_hp) / float(maxi(1, attacker.stats.max_hp))
	var profile: int = idx % 3
	if profile == 0:
		if hp_pct > 0.5 and battle_manager.can_use_ability(attacker, "focus"):
			return { "kind": "ability", "id": "focus", "name": "Focus" }
		if battle_manager.can_use_ability(attacker, "barrage"):
			return { "kind": "ability", "id": "barrage", "name": "Barrage", "needs_target": true }
		if battle_manager.can_use_ability(attacker, "ranged_shot"):
			return { "kind": "ability", "id": "ranged_shot", "name": "Ranged Shot", "needs_target": true }
	elif profile == 1:
		if hp_pct < 0.5 and battle_manager.can_use_ability(attacker, "frenzy"):
			return { "kind": "ability", "id": "frenzy", "name": "Frenzy", "needs_target": true }
	elif profile == 2:
		if hp_pct < 0.4 and battle_manager.can_use_ability(attacker, "guard"):
			return { "kind": "ability", "id": "guard", "name": "Guard" }
	return { "kind": "attack", "needs_target": true }


func _pick_party_target_for_enemy(attacker: Dictionary, ability_id: String) -> Dictionary:
	var party: Array = battle_manager.get_party()
	var candidates: Array = []
	for i in party.size():
		var s: BattlerStats = party[i]
		if not s.is_alive():
			continue
		var t := { "stats": s, "index": i, "is_party": true }
		if ability_id == "attack":
			if battle_manager.can_attack_target(attacker, t):
				candidates.append(t)
		elif battle_manager.can_use_ability_on_target(attacker, ability_id, t):
			candidates.append(t)
	if candidates.is_empty():
		return {}
	return candidates[int(randi() % candidates.size())]


func _pick_ability_target(attacker: Dictionary, ability_id: String) -> Dictionary:
	var enemies: Array = battle_manager.get_enemies()
	var candidates: Array = []
	for i in enemies.size():
		var s: BattlerStats = enemies[i]
		if not s.is_alive():
			continue
		var t := { "stats": s, "index": i, "is_party": false }
		if battle_manager.can_use_ability_on_target(attacker, ability_id, t):
			candidates.append(t)
	if candidates.is_empty():
		return {}
	if not _selected_target.is_empty() and battle_manager.can_use_ability_on_target(attacker, ability_id, _selected_target):
		return _selected_target
	return candidates[int(randi() % candidates.size())]


func _log_enemy_ability(attacker: Dictionary, ability_id: String, ability_name: String, target: Dictionary) -> void:
	match ability_id:
		"focus":
			_log("%s uses Focus! Attack boosted for 2 rounds." % attacker.stats.display_name)
		"guard":
			_log("%s braces for impact! Damage halved until its next turn." % attacker.stats.display_name)
		"frenzy":
			_log("%s enters Frenzy on %s for %d total damage!" % [
				attacker.stats.display_name, target.stats.display_name, battle_manager.last_ability_damage
			])
		"barrage":
			_log("%s barrages %s for %d total damage!" % [
				attacker.stats.display_name, target.stats.display_name, battle_manager.last_ability_damage
			])
		_:
			if target.is_empty():
				_log("%s uses %s!" % [attacker.stats.display_name, ability_name])
			else:
				_log("%s uses %s on %s for %d damage!" % [
					attacker.stats.display_name, ability_name, target.stats.display_name, battle_manager.last_ability_damage
				])


func _log_hero_ability(attacker: Dictionary, ability_id: String, ability_name: String, target: Dictionary) -> void:
	match ability_id:
		"fly":
			_log("%s is flying! Only ranged attacks can hit." % attacker.stats.display_name, "ability")
		"shield":
			_log("%s gains a shield (%d HP) for 3 rounds." % [attacker.stats.display_name, attacker.stats.shield_amount], "ability")
		"guard":
			_log("%s takes a defensive stance! Incoming damage halved until next turn." % attacker.stats.display_name, "ability")
		"grenade":
			_log("%s lobs a grenade at %s for %d total damage!" % [
				attacker.stats.display_name, target.stats.display_name, battle_manager.last_ability_damage
			], "damage")
		"slash":
			_log("%s slashes %s for %d damage!" % [
				attacker.stats.display_name, target.stats.display_name, battle_manager.last_ability_damage
			], "damage")
		"strike":
			_log("%s strikes through armor on %s for %d damage!" % [
				attacker.stats.display_name, target.stats.display_name, battle_manager.last_ability_damage
			], "damage")
		"snipe":
			_log("%s snipes the airborne %s for %d damage!" % [
				attacker.stats.display_name, target.stats.display_name, battle_manager.last_ability_damage
			], "damage")
		_:
			_log("%s uses %s!" % [attacker.stats.display_name, ability_name], "ability")

func _pick_random_enemy_target(attacker: Dictionary) -> Dictionary:
	var enemies = battle_manager.get_enemies()
	var candidates: Array = []
	for i in enemies.size():
		var s: BattlerStats = enemies[i]
		if not s.is_alive():
			continue
		var t := { "stats": s, "index": i, "is_party": false }
		if battle_manager.can_attack_target(attacker, t):
			candidates.append(t)
	if candidates.is_empty():
		return {}
	var target_index: int = int(randi() % candidates.size())
	return candidates[target_index]

func _on_battle_ended(party_wins: bool) -> void:
	_action_busy = true
	_ai_running = false
	_set_player_actions_enabled(false)
	actions_panel.visible = false
	next_floor_btn.visible = false
	if party_wins:
		_log("Victory! All enemies defeated.", "victory")
		if MissionProgress.meridian_has_next_floor_after_clear():
			end_title.text = "Floor clear!"
			next_floor_btn.visible = true
			back_to_menu_btn.text = "Abort to menu"
		else:
			if MissionProgress.is_meridian_spire_active() and MissionProgress.meridian_floor >= MissionProgress.MERIDIAN_MAX_FLOOR:
				end_title.text = "Rooftop secured!"
				MissionProgress.mark_rooftop_cleared()
				back_to_menu_btn.text = "Continue"
			elif MissionProgress.is_meridian_spire_active():
				end_title.text = "Meridian Spire secured!"
				MissionProgress.finish_meridian_spire()
				back_to_menu_btn.text = "Back to Main Menu"
			else:
				end_title.text = "Victory!"
				back_to_menu_btn.text = "Back to Main Menu"
	else:
		_log("Defeat! Party was defeated.", "defeat")
		end_title.text = "Defeat!"
		back_to_menu_btn.text = "Back to Main Menu"
		MissionProgress.finish_meridian_spire()
	# Size overlay and center to viewport (CanvasLayer children need manual sizing)
	var vp = get_viewport().get_visible_rect().size
	$EndScreen/Overlay.set_position(Vector2.ZERO)
	$EndScreen/Overlay.set_size(vp)
	$EndScreen/Center.set_position(Vector2.ZERO)
	$EndScreen/Center.set_size(vp)
	end_screen.visible = true

func _on_next_floor_pressed() -> void:
	end_screen.visible = false
	next_floor_btn.visible = false
	MissionProgress.meridian_advance_floor()
	var party: Array = battle_manager.get_party()
	for s in party:
		if s is BattlerStats:
			var st: BattlerStats = s as BattlerStats
			st.current_hp = st.max_hp
			st.current_energy = st.max_energy
			st.is_flying = false
			st.guard_active = false
			st.shield_amount = 0
			st.shield_rounds_left = 0
	var enemies: Array = _build_sample_enemies()
	battle_manager.setup_battle(party, enemies)
	_build_arena()
	_apply_mission_floor_visuals()
	_refresh_party_stats_panel()
	_log("=== %s ===" % MissionProgress.get_meridian_floor_info().title, "system")


func _on_back_to_menu_pressed() -> void:
	if MissionProgress.meridian_epilogue_pending:
		get_tree().change_scene_to_file("res://scenes/story/meridian_epilogue.tscn")
		return
	MissionProgress.finish_meridian_spire()
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

# --- Attack button: play attack animation on attacker, then damage (if target not flying or attacker ranged), refresh, advance_turn ---
func _on_attack_pressed() -> void:
	if _action_busy:
		return
	var attacker = battle_manager.get_current_battler()
	if attacker.is_empty() or not attacker.is_party or not attacker.stats.is_alive():
		return
	if _selected_target.is_empty():
		_selected_target = _pick_random_enemy_target(attacker)
		if _selected_target.is_empty():
			_log("No valid enemies to attack.")
			return
		_log("No target selected, attacking %s." % _selected_target.stats.display_name)
		_highlight_selected_enemy()
	if not battle_manager.can_attack_target(attacker, _selected_target):
		_log("Can't reach %s (flying) with a melee attack!" % _selected_target.stats.display_name)
		return
	_action_busy = true
	_set_player_actions_enabled(false)
	var target: Dictionary = _selected_target.duplicate()
	var attacker_slot: BattlerSlot = _get_attacker_slot()
	if attacker_slot:
		await attacker_slot.play_attack_animation()
	if not is_inside_tree() or not _is_current_party_battler(attacker):
		_action_busy = false
		if battle_manager.get_current_battler().get("is_party", false):
			_set_player_actions_enabled(true)
		return
	_maybe_hero_bark(attacker.index, "attack")
	battle_manager.last_hit_results.clear()
	var dmg = battle_manager.perform_attack(attacker, target)
	_apply_hit_results(battle_manager.last_hit_results)
	_log_attack_result(attacker.stats.display_name, target.stats.display_name, dmg, battle_manager.last_hit_kind)
	_refresh_arena_slots()
	_selected_target = {}
	_highlight_selected_enemy()
	battle_manager.advance_turn()

func _on_end_turn_pressed() -> void:
	if _action_busy:
		return
	_action_busy = true
	_set_player_actions_enabled(false)
	battle_manager.advance_turn()

func _on_abilities_pressed() -> void:
	var current = battle_manager.get_current_battler()
	if current.is_empty() or not current.is_party:
		return
	var abilities: Array = HeroRoster.get_abilities(current.index)
	if abilities.is_empty():
		_log("%s has no abilities." % current.stats.display_name)
		return
	ability_sub_panel.visible = true
	for c in ability_buttons_container.get_children():
		c.queue_free()
	for ab in abilities:
		var ability_id: String = str(ab.get("id", ""))
		var ability_name: String = str(ab.get("name", ability_id))
		var cost: int = battle_manager.get_ability_cost(ability_id)
		var can_afford: bool = battle_manager.can_use_ability(current, ability_id)
		var can_use: bool = can_afford
		if battle_manager.ability_needs_target(ability_id):
			can_use = can_use and battle_manager.has_valid_target_for_ability(
				current, ability_id, battle_manager.get_enemies()
			)
		var btn = Button.new()
		btn.text = "%s (%d)" % [ability_name, cost]
		btn.tooltip_text = battle_manager.get_ability_hint(ability_id)
		btn.disabled = not can_use
		btn.add_theme_color_override("font_color", _COLOR_TEXT if can_afford else Color(0.5, 0.5, 0.5, 1))
		btn.add_theme_stylebox_override("normal", _make_btn_style(false))
		btn.add_theme_stylebox_override("hover", _make_btn_style(true))
		btn.pressed.connect(_on_ability_used.bind(ability_id, ability_name))
		ability_buttons_container.add_child(btn)

func _on_ability_back_pressed() -> void:
	ability_sub_panel.visible = false

func _on_ability_used(ability_id: String, ability_name: String) -> void:
	if _action_busy:
		return
	var current = battle_manager.get_current_battler()
	if current.is_empty() or not current.is_party:
		ability_sub_panel.visible = false
		return
	var target: Dictionary = {}
	if battle_manager.ability_needs_target(ability_id):
		target = _pick_ability_target(current, ability_id)
		if target.is_empty():
			if ability_id == "snipe":
				_log("Snipe needs a flying enemy — use Fly first or wait for one.")
			else:
				_log("No valid target for %s." % ability_name)
			return
		if not battle_manager.can_use_ability_on_target(current, ability_id, target):
			_log("Can't use %s on that target." % ability_name)
			return
	if not battle_manager.can_use_ability(current, ability_id):
		_log("Not enough energy for %s." % ability_name)
		ability_sub_panel.visible = false
		return
	_action_busy = true
	_set_player_actions_enabled(false)
	var attacker_slot: BattlerSlot = _get_attacker_slot()
	if ability_id in ATTACK_ANIM_ABILITIES and attacker_slot:
		await attacker_slot.play_attack_animation()
	if not is_inside_tree() or not _is_current_party_battler(current):
		_action_busy = false
		_set_player_actions_enabled(true)
		return
	if not battle_manager.perform_ability(current, ability_id, target):
		_action_busy = false
		_set_player_actions_enabled(true)
		ability_sub_panel.visible = false
		return
	_maybe_hero_bark(current.index, ability_id)
	_log_hero_ability(current, ability_id, ability_name, target)
	_apply_hit_results(battle_manager.last_hit_results)
	_refresh_arena_slots()
	_selected_target = {}
	_highlight_selected_enemy()
	ability_sub_panel.visible = false
	battle_manager.advance_turn()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _options_menu.visible:
		_options_menu.show_menu()
		get_viewport().set_input_as_handled()

const _LOG_MAX_LINES := 50

func _log(msg: String, kind: String = "normal") -> void:
	var color: Color = _log_color_for_kind(kind)
	var line := "[color=#%s]%s[/color]\n" % [_color_to_hex(color), msg]
	log_label.text = line + log_label.text
	var lines := log_label.text.split("\n", false)
	if lines.size() > _LOG_MAX_LINES:
		log_label.text = "\n".join(lines.slice(0, _LOG_MAX_LINES))
	log_scroll.scroll_vertical = 0


func _log_color_for_kind(kind: String) -> Color:
	match kind:
		"turn":
			return _COLOR_NEXT
		"enemy_turn":
			return _COLOR_LOG_ENEMY
		"damage", "crit":
			return _COLOR_LOG_CRIT
		"absorb":
			return _COLOR_LOG_ABSORB
		"miss":
			return _COLOR_LOG_MISS
		"bark":
			return _COLOR_LOG_BARK
		"ability":
			return _COLOR_ACCENT
		"victory":
			return _COLOR_LOG_VICTORY
		"defeat":
			return _COLOR_LOG_DEFEAT
		"system":
			return _COLOR_TEXT
		_:
			return _COLOR_LOG


func _color_to_hex(color: Color) -> String:
	return color.to_html(false)


func _log_attack_result(attacker_name: String, target_name: String, damage: int, kind: String) -> void:
	match kind:
		"miss":
			_log("%s attacks %s — MISS!" % [attacker_name, target_name], "miss")
		"absorb":
			_log("%s attacks %s — absorbed by shield!" % [attacker_name, target_name], "absorb")
		"crit":
			_log("CRITICAL! %s hits %s for %d damage!" % [attacker_name, target_name, damage], "crit")
		_:
			_log("%s attacks %s for %d damage!" % [attacker_name, target_name, damage], "damage")


func _maybe_hero_bark(hero_index: int, context: String) -> void:
	var line: String = HeroRoster.get_bark(hero_index, context)
	if line.is_empty():
		return
	var hero_name: String = str(HeroRoster.get_hero(hero_index).get("display_name", "Hero"))
	_log('%s: "%s"' % [hero_name, line], "bark")
	BattleSfx.play_bark()


func _apply_hit_results(results: Array) -> void:
	for hit in results:
		var idx: int = int(hit.get("target_index", -1))
		var is_party: bool = bool(hit.get("is_party", false))
		var damage: int = int(hit.get("damage", 0))
		var kind: String = str(hit.get("kind", "hit"))
		var slot: BattlerSlot = _get_target_slot(idx, is_party)
		if slot == null:
			continue
		if damage > 0:
			slot.play_hit_flash()
		_spawn_floating_text(slot, damage, kind)
		match kind:
			"crit":
				BattleSfx.play_crit()
			"miss":
				BattleSfx.play_miss()
			"absorb":
				BattleSfx.play_absorb()
			_:
				if damage > 0:
					BattleSfx.play_hit()


func _spawn_floating_text(slot: BattlerSlot, damage: int, kind: String) -> void:
	if floating_text_layer == null or slot == null:
		return
	var text := ""
	var color := Color.WHITE
	match kind:
		"miss":
			text = "MISS"
			color = _COLOR_LOG_MISS
		"absorb":
			text = "ABSORB"
			color = _COLOR_LOG_ABSORB
		"crit":
			text = "-%d!" % damage
			color = _COLOR_LOG_CRIT
		_:
			if damage <= 0:
				return
			text = "-%d" % damage
			color = Color(1.0, 0.92, 0.55)
	FloatingCombatText.spawn(floating_text_layer, slot.get_combat_text_position(), text, color)
