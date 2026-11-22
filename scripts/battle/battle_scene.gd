extends Control
## Battle screen: layout (party left, enemies right), UI, input, and sample battle setup.
## Creates the BattleManager, builds the arena from BattlerSlots, applies sci-fi theme,
## and wires turn/attack/target/restart to the UI.

const BattlerSlotScene = preload("res://scenes/battle/battler_slot.tscn")
const OptionsMenuScene = preload("res://scenes/ui/options_menu.tscn")
const DEFAULT_BATTLE_FEEL: BattleFeel = preload("res://resources/battle_feel_default.tres")

## Combat feel tuning (impact, death, pacing, speed). Swap for another
## BattleFeel resource to retune without code changes.
@export var battle_feel: BattleFeel = DEFAULT_BATTLE_FEEL

# Idle: party and enemies each have per-character sprites (face right / left). Attack: one per side, with per-character overrides.
var _texture_idle_party: Array[Texture2D] = []
## Enemy textures by res:// path (EnemyRoster sprites), loaded on first use.
var _enemy_texture_cache: Dictionary = {}
var _texture_attack_party: Texture2D
var _texture_attack_enemy: Texture2D
var _placeholder_texture: Texture2D
var _hero2_attack_frames: Array[Texture2D] = []
var _hero3_attack_frames: Array[Texture2D] = []

# --- Node references (must match battle_scene.tscn tree) ---
@onready var battle_background: TextureRect = $Background
@onready var floor_banner: Label = $Margin/VBox/FloorBanner
@onready var turn_order_bar: TurnOrderBar = $Margin/VBox/TopBar/TopHBox/TurnOrderBar
@onready var party_slots_container: VBoxContainer = $Margin/VBox/ArenaRow/PartyArena/PartySlots
@onready var enemy_slots_container: VBoxContainer = $Margin/VBox/ArenaRow/EnemyArena/EnemySlots
@onready var stats_list: VBoxContainer = $Margin/VBox/BottomRow/PartyStatsPanel/StatsVBox/StatsList
@onready var battle_log: BattleLog = $Margin/VBox/BottomRow/LogPanel
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
@onready var speed_btn: Button = $Margin/VBox/TopBar/TopHBox/SpeedBtn
@onready var arena_margin: MarginContainer = $Margin
@onready var ability_sub_panel: VBoxContainer = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel
@onready var ability_buttons_container: HBoxContainer = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel/AbilityButtonsContainer
@onready var ability_back_btn: Button = $Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel/AbilityBackBtn

const ATTACK_ANIM_ABILITIES: Array[String] = [
	"grenade", "slash", "strike", "snipe", "ranged_shot", "barrage", "frenzy"
]

var battle_manager: BattleManager
## Presentation of combat feel (lunge, hit-stop, shake, flash, death, waits).
var battle_fx: BattleFx
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
const _COLOR_TURN_PARTY := Color(0.0, 0.85, 0.9, 1)  # turn-order chip accent, party (teal)
const _COLOR_TURN_ENEMY := Color(1.0, 0.42, 0.32, 1)  # turn-order chip accent, enemies (red-amber)
const _COLOR_LOG_BG := Color(0.04, 0.05, 0.08, 0.98)

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
	# Enemy sprites come from EnemyRoster per type (see _get_enemy_texture).
	_enemy_texture_cache.clear()
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
	battle_fx = BattleFx.new()
	battle_fx.name = "BattleFx"
	battle_fx.feel = battle_feel
	add_child(battle_fx)
	battle_fx.configure([arena_margin] as Array[Control], floating_text_layer)
	battle_fx.speed_changed.connect(_on_battle_speed_changed)
	turn_order_bar.feel = battle_feel
	speed_btn.pressed.connect(_on_speed_pressed)
	_on_battle_speed_changed(battle_fx.get_speed_multiplier())
	attack_btn.pressed.connect(_on_attack_pressed)
	abilities_btn.pressed.connect(_on_abilities_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	ability_back_btn.pressed.connect(_on_ability_back_pressed)
	ability_sub_panel.visibility_changed.connect(_on_ability_sub_panel_visibility_changed)
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

	var top_bar_style := panel_style.duplicate() as StyleBoxFlat
	top_bar_style.content_margin_top = 6
	top_bar_style.content_margin_bottom = 6
	$Margin/VBox/TopBar.add_theme_stylebox_override("panel", top_bar_style)
	$Margin/VBox/TopBar/TopHBox/TurnOrderLabel.add_theme_color_override("font_color", _COLOR_ACCENT)
	$Margin/VBox/TopBar/TopHBox/TurnOrderLabel.add_theme_font_size_override("font_size", 13)
	turn_order_bar.party_color = _COLOR_TURN_PARTY
	turn_order_bar.enemy_color = _COLOR_TURN_ENEMY
	turn_order_bar.active_color = _COLOR_NEXT
	turn_order_bar.chip_bg_color = _COLOR_PANEL
	turn_order_bar.text_color = _COLOR_TEXT

	$Margin/VBox/ArenaRow/PartyArena/PartyLabel.add_theme_color_override("font_color", _COLOR_TEXT)
	$Margin/VBox/ArenaRow/EnemyArena/EnemyLabel.add_theme_color_override("font_color", _COLOR_TEXT)

	var stats_panel_style = panel_style.duplicate()
	$Margin/VBox/BottomRow/PartyStatsPanel.add_theme_stylebox_override("panel", stats_panel_style)
	$Margin/VBox/BottomRow/PartyStatsPanel/StatsVBox/StatsTitle.add_theme_color_override("font_color", _COLOR_ACCENT)

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
	speed_btn.add_theme_color_override("font_color", _COLOR_ACCENT)
	speed_btn.add_theme_font_size_override("font_size", 18)
	speed_btn.add_theme_stylebox_override("normal", _make_compact_btn_style(false))
	speed_btn.add_theme_stylebox_override("hover", _make_compact_btn_style(true))
	speed_btn.add_theme_stylebox_override("pressed", _make_compact_btn_style(true))
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel/AbilityLabel.add_theme_color_override("font_color", _COLOR_TEXT)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel/AbilityBackBtn.add_theme_color_override("font_color", _COLOR_TEXT)
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel/AbilityBackBtn.add_theme_stylebox_override("normal", _make_btn_style(false))
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/AbilitySubPanel/AbilityBackBtn.add_theme_stylebox_override("hover", _make_btn_style(true))

	var log_style := panel_style.duplicate() as StyleBoxFlat
	log_style.bg_color = _COLOR_LOG_BG
	log_style.content_margin_top = 8
	log_style.content_margin_bottom = 8
	var history_style := log_style.duplicate() as StyleBoxFlat
	history_style.shadow_color = Color(0, 0, 0, 0.6)
	history_style.shadow_size = 12
	battle_log.apply_style(log_style, history_style, _COLOR_LOG, _COLOR_ACCENT,
		_make_compact_btn_style(false), _make_compact_btn_style(true))

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

## Small button style (speed toggle, log toggle): same look, tighter margins.
func _make_compact_btn_style(hover: bool) -> StyleBoxFlat:
	var s := _make_btn_style(hover)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

func _make_btn_style(hover: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.14, 0.18, 1) if not hover else Color(0.18, 0.22, 0.28, 1)
	s.border_color = _COLOR_BORDER
	s.set_border_width_all(1)
	s.set_content_margin_all(16)
	return s


## Shows or hides the actions panel without removing it from the layout, so
## the party status and log next to it do not jump on enemy turns. Hidden
## buttons are also disabled by _set_player_actions_enabled(false).
func _set_actions_panel_shown(shown: bool) -> void:
	actions_panel.modulate.a = 1.0 if shown else 0.0
	actions_panel.mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE
	if not shown:
		ability_sub_panel.visible = false


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


## Builds this fight's enemies from the floor lineup (MissionProgress.MERIDIAN_FLOORS
## "enemies"). Each BattlerStats carries its archetype id in enemy_type. Without
## an active mission this falls back to floor 1.
func _build_sample_enemies() -> Array:
	var floor_idx: int = MissionProgress.get_current_combat_floor()
	var types: Array = MissionProgress.get_current_floor_enemy_types()
	return EnemyRoster.build_enemies(types, floor_idx)


## Loads (and caches) a Texture2D for [param path]; null if missing.
func _get_enemy_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _enemy_texture_cache.has(path):
		return _enemy_texture_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_enemy_texture_cache[path] = tex
	return tex


## Idle + attack frames, scale and tint for one enemy slot, all read from the
## battler's archetype (stats.enemy_type), never from the slot index.
func _setup_enemy_slot(slot: BattlerSlot, stats: BattlerStats, attack_fallback: Texture2D) -> void:
	var type_id: String = stats.enemy_type
	var idle: Texture2D = _get_enemy_texture(EnemyRoster.get_idle_sprite_path(type_id))
	if idle == null:
		idle = _placeholder_texture
	# sprite_scale widens the 380x494 box only. Enemy art is width-limited in it
	# (KEEP_ASPECT_CENTERED), so the sprite grows by sprite_scale while the box
	# height, and therefore the arena row height, stays put (scaling the height
	# too pushed the floor banner off-screen on the boss floor).
	var size: Vector2 = Vector2(380.0 * EnemyRoster.get_sprite_scale(type_id), 494.0)
	slot.setup(stats, idle, attack_fallback, size)
	var frames: Array[Texture2D] = []
	for p in EnemyRoster.get_attack_frame_paths(type_id):
		var t: Texture2D = _get_enemy_texture(str(p))
		if t != null:
			frames.append(t)
	if not frames.is_empty():
		slot.set_attack_frames(frames)
	slot.set_sprite_tint(EnemyRoster.get_tint(type_id))
	slot.set_boss_visual(EnemyRoster.is_boss(type_id))


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
		slot.feel = battle_feel
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
	# The back row only exists with 3+ enemies; an empty row still cost the
	# EnemySlots separation (48 px) of arena height.
	if n >= 3:
		var enemy_back_row = _make_row(enemy_slots_container, true, true)
		for i in [2, 3]:
			if i < n:
				var slot: BattlerSlot = BattlerSlotScene.instantiate()
				slot.slot_index = i
				slot.is_party = false
				slot.slot_clicked.connect(_on_enemy_slot_clicked)
				slot.feel = battle_feel
				enemy_back_row.add_child(slot)
				_setup_enemy_slot(slot, enemies[i], attack_enemy)
				_enemy_slots.append(slot)
	var enemy_front_row = _make_row(enemy_slots_container, false, true)
	for i in [0, 1]:
		if i < n:
			var slot: BattlerSlot = BattlerSlotScene.instantiate()
			slot.slot_index = i
			slot.is_party = false
			slot.slot_clicked.connect(_on_enemy_slot_clicked)
			slot.feel = battle_feel
			enemy_front_row.add_child(slot)
			_setup_enemy_slot(slot, enemies[i], attack_enemy)
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

# --- Rebuild the Party status list: name, HP bar + numbers, EN bar + numbers ---
# Colours, tags and the "current/max" format come from BattleFeel, the same as
# the arena slots, so HP (cyan, orange/red when low) and energy (yellow) read
# the same everywhere.
func _refresh_party_stats_panel() -> void:
	for c in stats_list.get_children():
		c.queue_free()
	var party = battle_manager.get_party()
	var f: BattleFeel = battle_feel if battle_feel else DEFAULT_BATTLE_FEEL
	for i in party.size():
		var s: BattlerStats = party[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_l = Label.new()
		name_l.text = s.display_name + ":"
		name_l.custom_minimum_size.x = 80
		name_l.add_theme_color_override("font_color", HeroRoster.get_role_color(i))
		row.add_child(name_l)
		row.add_child(_make_stat_bar(s.current_hp, s.max_hp, f.get_hp_color(s.current_hp, s.max_hp), 12, 3.0))
		row.add_child(_make_stat_label(BattleFeel.format_bar_value(s.current_hp, s.max_hp), f.hp_text_color, 58))
		row.add_child(_make_stat_label(f.energy_tag, f.energy_text_color, 0))
		row.add_child(_make_stat_bar(s.current_energy, s.max_energy, f.energy_color, 9, 2.0))
		row.add_child(_make_stat_label(BattleFeel.format_bar_value(s.current_energy, s.max_energy), f.energy_text_color, 58))
		stats_list.add_child(row)


## One bar of a Party status row. [param stretch] shares the free width.
func _make_stat_bar(value: int, maximum: int, fill_color: Color, height: int, stretch: float) -> ProgressBar:
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.06, 0.07, 0.1, 1)
	bar_bg.set_corner_radius_all(2)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = fill_color
	bar_fill.set_corner_radius_all(2)
	var bar = ProgressBar.new()
	bar.max_value = float(maxi(1, maximum))
	bar.value = float(value)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_stretch_ratio = stretch
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, height)
	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", bar_fill)
	return bar


## A small right-aligned number or tag label for a Party status row.
func _make_stat_label(text: String, color: Color, min_width: int) -> Label:
	var l = Label.new()
	l.text = text
	l.custom_minimum_size.x = min_width
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override("font_color", color)
	return l

# --- Feed the turn order bar (sorted by speed, alive only) and highlight the active slot ---
func _on_turn_order_updated(_order_arg = null) -> void:
	var current: Dictionary = battle_manager.get_current_battler()
	var active_key := ""
	if not current.is_empty():
		active_key = _turn_key(bool(current.is_party), int(current.index))
	turn_order_bar.set_order(_build_turn_order_entries(), active_key)

	# Highlight in the arena the slot whose turn it is (amber border)
	var attacker_slot = _get_attacker_slot()
	for slot in _party_slots:
		slot.set_turn_highlight(slot == attacker_slot)
	for slot in _enemy_slots:
		slot.set_turn_highlight(slot == attacker_slot)

## Stable key of a battler in the turn order bar ("P0", "E1").
func _turn_key(is_party: bool, index: int) -> String:
	return "%s%d" % ["P" if is_party else "E", index]


## Turn order entries for TurnOrderBar: alive battlers sorted by speed (the
## same order rule as before), each with name, side and idle sprite.
func _build_turn_order_entries() -> Array:
	var order: Array = []
	var party: Array = battle_manager.get_party()
	var enemies: Array = battle_manager.get_enemies()
	for i in party.size():
		var ps: BattlerStats = party[i]
		if ps.is_alive():
			var tex: Texture2D = _texture_idle_party[i] if i < _texture_idle_party.size() else _placeholder_texture
			order.append({ "stats": ps, "key": _turn_key(true, i), "name": ps.display_name, "is_party": true, "texture": tex })
	for i in enemies.size():
		var es: BattlerStats = enemies[i]
		if es.is_alive():
			var etex: Texture2D = _get_enemy_texture(EnemyRoster.get_idle_sprite_path(es.enemy_type))
			order.append({ "stats": es, "key": _turn_key(false, i), "name": es.display_name, "is_party": false,
				"texture": etex if etex != null else _placeholder_texture })
	order.sort_custom(func(a, b): return a.stats.speed > b.stats.speed)
	return order

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
		_set_actions_panel_shown(true)
		ability_sub_panel.visible = false
		_selected_target = {}
		_highlight_selected_enemy()
	else:
		_action_busy = true
		_set_player_actions_enabled(false)
		_set_actions_panel_shown(false)
		ability_sub_panel.visible = false
		_enemy_turn_token += 1
		var token := _enemy_turn_token
		await _play_enemy_turn_intro(s, token)
		if token != _enemy_turn_token or not is_inside_tree():
			return
		_ai_turn()

func _play_enemy_turn_intro(_enemy_stats: BattlerStats, _token: int) -> void:
	await battle_fx.play_enemy_turn_intro(_get_attacker_slot(), enemy_turn_flash)


func _on_turn_ended(_battler_index: int, _is_party: bool) -> void:
	pass

# --- Returns the BattlerSlot for the current attacker (for attack animation). ---
func _get_attacker_slot() -> BattlerSlot:
	var current = battle_manager.get_current_battler()
	if current.is_empty():
		return null
	return _get_target_slot(current.index, current.is_party)

func _get_slot_for(battler: Dictionary) -> BattlerSlot:
	if battler.is_empty():
		return null
	return _get_target_slot(int(battler.index), bool(battler.is_party))

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
		var lunge_slot: BattlerSlot = attacker_slot if ability_id in ATTACK_ANIM_ABILITIES else null
		await battle_fx.play_lunge(lunge_slot, _get_slot_for(target))
		if not is_inside_tree() or not _is_current_battler(attacker):
			_ai_running = false
			return
		if not battle_manager.perform_ability(attacker, ability_id, target):
			await battle_fx.play_impact(lunge_slot, [])
			_ai_running = false
			if is_inside_tree():
				battle_manager.advance_turn()
			return
		_log_enemy_ability(attacker, ability_id, ability_name, target)
		_refresh_arena_slots()
		await _apply_hit_results(battle_manager.last_hit_results, lunge_slot)
		_ai_running = false
		if is_inside_tree():
			battle_manager.advance_turn()
		return
	var target: Dictionary = _pick_party_target_for_enemy(attacker, "attack")
	if target.is_empty():
		_ai_running = false
		battle_manager.advance_turn()
		return
	var attacker_slot: BattlerSlot = _get_attacker_slot()
	await battle_fx.play_lunge(attacker_slot, _get_slot_for(target))
	if not is_inside_tree() or not _is_current_battler(attacker):
		_ai_running = false
		return
	battle_manager.last_hit_results.clear()
	var dmg = battle_manager.perform_attack(attacker, target)
	_log_attack_result(attacker.stats.display_name, target.stats.display_name, dmg, battle_manager.last_hit_kind)
	_refresh_arena_slots()
	await _apply_hit_results(battle_manager.last_hit_results, attacker_slot)
	_ai_running = false
	if is_inside_tree():
		battle_manager.advance_turn()


func _choose_enemy_action(attacker: Dictionary) -> Dictionary:
	var hp_pct: float = float(attacker.stats.current_hp) / float(maxi(1, attacker.stats.max_hp))
	var profile: int = EnemyRoster.get_ai_profile(attacker.stats.enemy_type)
	if profile == EnemyRoster.AI_TACTICIAN:
		if hp_pct > 0.5 and battle_manager.can_use_ability(attacker, "focus"):
			return { "kind": "ability", "id": "focus", "name": "Focus" }
		if battle_manager.can_use_ability(attacker, "barrage"):
			return { "kind": "ability", "id": "barrage", "name": "Barrage", "needs_target": true }
		if battle_manager.can_use_ability(attacker, "ranged_shot"):
			return { "kind": "ability", "id": "ranged_shot", "name": "Ranged Shot", "needs_target": true }
	elif profile == EnemyRoster.AI_BERSERKER:
		if hp_pct < 0.5 and battle_manager.can_use_ability(attacker, "frenzy"):
			return { "kind": "ability", "id": "frenzy", "name": "Frenzy", "needs_target": true }
	elif profile == EnemyRoster.AI_SOLDIER:
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
	_set_actions_panel_shown(false)
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
	# Same scene, new floor: fade through black (SceneFader) and rebuild while
	# the screen is covered. Falls back to an instant rebuild if no fade runs.
	next_floor_btn.disabled = true
	if not SceneFader.fade_through(_advance_to_next_floor):
		_advance_to_next_floor()


func _advance_to_next_floor() -> void:
	end_screen.visible = false
	next_floor_btn.visible = false
	next_floor_btn.disabled = false
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
		SceneFader.change_scene("res://scenes/story/meridian_epilogue.tscn")
		return
	MissionProgress.finish_meridian_spire()
	SceneFader.change_scene("res://scenes/main_menu/main_menu.tscn")

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
	await battle_fx.play_lunge(attacker_slot, _get_slot_for(target))
	if not is_inside_tree() or not _is_current_party_battler(attacker):
		_action_busy = false
		if battle_manager.get_current_battler().get("is_party", false):
			_set_player_actions_enabled(true)
		return
	_maybe_hero_bark(attacker.index, "attack")
	battle_manager.last_hit_results.clear()
	var dmg = battle_manager.perform_attack(attacker, target)
	_log_attack_result(attacker.stats.display_name, target.stats.display_name, dmg, battle_manager.last_hit_kind)
	_refresh_arena_slots()
	_selected_target = {}
	_highlight_selected_enemy()
	await _apply_hit_results(battle_manager.last_hit_results, attacker_slot)
	if is_inside_tree():
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

## The ability list replaces the main action rows while open, so the actions
## panel keeps roughly the same height and the layout fits 1080 px.
func _on_ability_sub_panel_visibility_changed() -> void:
	var open: bool = ability_sub_panel.visible
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/Buttons.visible = not open
	$Margin/VBox/BottomRow/ActionsPanel/ActionsVBox/EndTurnRow.visible = not open

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
	var lunge_slot: BattlerSlot = attacker_slot if ability_id in ATTACK_ANIM_ABILITIES else null
	await battle_fx.play_lunge(lunge_slot, _get_slot_for(target))
	if not is_inside_tree() or not _is_current_party_battler(current):
		_action_busy = false
		_set_player_actions_enabled(true)
		return
	if not battle_manager.perform_ability(current, ability_id, target):
		await battle_fx.play_impact(lunge_slot, [])
		_action_busy = false
		_set_player_actions_enabled(true)
		ability_sub_panel.visible = false
		return
	_maybe_hero_bark(current.index, ability_id)
	_log_hero_ability(current, ability_id, ability_name, target)
	_refresh_arena_slots()
	_selected_target = {}
	_highlight_selected_enemy()
	ability_sub_panel.visible = false
	await _apply_hit_results(battle_manager.last_hit_results, lunge_slot)
	if is_inside_tree():
		battle_manager.advance_turn()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _options_menu.visible:
		_options_menu.show_menu()
		get_viewport().set_input_as_handled()

## Adds one coloured line to the battle log (newest on top; BattleLog keeps
## the history and shows the last few lines).
func _log(msg: String, kind: String = "normal") -> void:
	var color: Color = _log_color_for_kind(kind)
	battle_log.add_line("[color=#%s]%s[/color]" % [_color_to_hex(color), msg])


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


## Turns BattleManager hit results into BattleFx hits, plays the SFX, and
## awaits the impact presentation (hit-stop, shake, flash, numbers, death,
## lunge return and post-action pause). [param attacker_slot] is the slot that
## lunged, or null when the action had no lunge.
func _apply_hit_results(results: Array, attacker_slot: BattlerSlot = null) -> void:
	var hits: Array[Dictionary] = []
	for hit in results:
		var idx: int = int(hit.get("target_index", -1))
		var is_party: bool = bool(hit.get("is_party", false))
		var damage: int = int(hit.get("damage", 0))
		var kind: String = str(hit.get("kind", "hit"))
		var slot: BattlerSlot = _get_target_slot(idx, is_party)
		if slot == null:
			continue
		var stats: BattlerStats = slot.get_stats()
		hits.append({
			"slot": slot,
			"damage": damage,
			"kind": kind,
			"downed": stats != null and not stats.is_alive(),
		})
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
	await battle_fx.play_impact(attacker_slot, hits)
	# Downed battlers leave the turn order bar right away (fade + shrink).
	if is_inside_tree():
		_on_turn_order_updated()


# --- Battle speed toggle (1x / 2x); presentation only, rules are unaffected ---
func _on_speed_pressed() -> void:
	battle_fx.cycle_speed()


func _on_battle_speed_changed(_multiplier: float) -> void:
	speed_btn.text = battle_fx.get_speed_label()
	turn_order_bar.speed_multiplier = battle_fx.get_speed_multiplier()
	speed_btn.tooltip_text = "Battle speed: %s (click to change)" % battle_fx.get_speed_label()
