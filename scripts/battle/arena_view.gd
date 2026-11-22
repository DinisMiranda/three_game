class_name ArenaView
extends RefCounted
## Builds and owns the battlers' arena: the BattlerSlots of both sides, the
## sprite textures they use, and slot-level highlights.
##
## Layout: three heroes in one row on the ground (Hero 1 in the middle), enemies
## in a front row of two plus a back row for a third and fourth. The view holds
## no combat rules; [BattleScene] tells it what to build and what to highlight.

## An enemy slot was clicked (only enemy slots are clickable).
signal enemy_slot_clicked(slot_index: int, is_party: bool)

const BattlerSlotScene = preload("res://scenes/battle/battler_slot.tscn")
const _PLACEHOLDER_PATH := "res://assets/character_placeholder.png"
const _ATTACK_PARTY_PATH := "res://assets/sevro_atack_no_bg_1-removebg-preview.png"
const _ATTACK_ENEMY_PATH := "res://assets/sevro_atack_no_bg.png"
const _HERO2_ATTACK_PATH := "res://assets/hero2_attack_animation.png"
const _HERO3_ATTACK_PATH := "res://assets/hero3_attack-removebg copy.png"
## Left to right: Hero 2, Hero 1, Hero 3 (Hero 1 in the middle).
const _PARTY_VISUAL_ORDER: Array[int] = [1, 0, 2]
const _ENEMY_BOX := Vector2(380.0, 494.0)
const _ROW_SEPARATION := 48
const _BACK_ROW_INDENT := 28
const _TARGET_SELECTED_TINT := Color(1.2, 1.2, 1.0)
const _TARGET_UNREACHABLE_TINT := Color(0.5, 0.5, 0.55)

var _party_container: VBoxContainer
var _enemy_container: VBoxContainer
var _feel: BattleFeel
var _party_slots: Array[BattlerSlot] = []
var _enemy_slots: Array[BattlerSlot] = []
var _placeholder: Texture2D
var _idle_party: Array[Texture2D] = []
var _enemy_texture_cache: Dictionary = {}  # res:// path -> Texture2D (or null)
var _attack_party: Texture2D
var _attack_enemy: Texture2D
var _hero_attack_frames: Dictionary = {}  # hero index -> Array[Texture2D]


## [param party_container] and [param enemy_container] receive the slot rows;
## [param feel] is handed to every slot.
func _init(party_container: VBoxContainer, enemy_container: VBoxContainer, feel: BattleFeel) -> void:
	_party_container = party_container
	_enemy_container = enemy_container
	_feel = feel
	_load_textures()


## Builds fresh slots for [param party] and [param enemies] (Arrays of [BattlerStats]).
func build(party: Array, enemies: Array) -> void:
	_clear(_party_container)
	_clear(_enemy_container)
	_party_slots.clear()
	_enemy_slots.clear()
	_build_party(party)
	_build_enemies(enemies)


## Re-reads every slot's stats (HP, energy, status).
func refresh() -> void:
	for slot in _party_slots + _enemy_slots:
		slot.refresh()


## The slot for battler [param index] on the given side, or null.
func slot_for(index: int, is_party: bool) -> BattlerSlot:
	for slot in (_party_slots if is_party else _enemy_slots):
		if slot.slot_index == index:
			return slot
	return null


## The slot for a BattleManager battler dictionary, or null for {}.
func slot_for_battler(battler: Dictionary) -> BattlerSlot:
	if battler.is_empty():
		return null
	return slot_for(int(battler.index), bool(battler.is_party))


## Enemy slots, in build order (back row first).
func get_enemy_slots() -> Array[BattlerSlot]:
	return _enemy_slots


## Party slots, sorted by party index.
func get_party_slots() -> Array[BattlerSlot]:
	return _party_slots


## Idle portrait of hero [param index], placeholder if missing.
func party_idle_texture(index: int) -> Texture2D:
	if index >= 0 and index < _idle_party.size():
		return _idle_party[index]
	return _placeholder


## Idle sprite of an enemy archetype, placeholder if missing.
func enemy_idle_texture(type_id: String) -> Texture2D:
	var tex: Texture2D = _enemy_texture(EnemyRoster.get_idle_sprite_path(type_id))
	return tex if tex != null else _placeholder


## Turn order entries for [TurnOrderBar]: alive battlers sorted by speed, each
## with key ("P0", "E1"), name, side, idle sprite and shader grade.
func turn_order_entries(party: Array, enemies: Array) -> Array:
	var order: Array = []
	for i in party.size():
		if party[i].is_alive():
			order.append({ "stats": party[i], "key": turn_key(true, i), "name": party[i].display_name, "is_party": true,
				"texture": party_idle_texture(i), "grade": HeroRoster.get_shader_grade(i) })
	for i in enemies.size():
		if enemies[i].is_alive():
			var type_id: String = enemies[i].enemy_type
			order.append({ "stats": enemies[i], "key": turn_key(false, i), "name": enemies[i].display_name, "is_party": false,
				"texture": enemy_idle_texture(type_id), "grade": EnemyRoster.get_shader_grade(type_id) })
	order.sort_custom(func(a, b): return a.stats.speed > b.stats.speed)
	return order


## Stable key of a battler in the turn order bar ("P0", "E1").
static func turn_key(is_party: bool, index: int) -> String:
	return "%s%d" % ["P" if is_party else "E", index]


## Amber-highlights [param active] (the slot whose turn it is), clears the rest.
func highlight_turn(active: BattlerSlot) -> void:
	for slot in _party_slots + _enemy_slots:
		slot.set_turn_highlight(slot == active)


## Tints enemy slots: the selected one bright, ones [param attacker] cannot
## reach dim. [param can_attack] is Callable(attacker, target) -> bool.
func highlight_targets(selected: BattlerStats, attacker: Dictionary, can_attack: Callable) -> void:
	for slot in _enemy_slots:
		var target := { "stats": slot.get_stats(), "index": slot.slot_index, "is_party": false }
		if slot.get_stats() == selected:
			slot.modulate = _TARGET_SELECTED_TINT
		elif not attacker.is_empty() and not bool(can_attack.call(attacker, target)):
			slot.modulate = _TARGET_UNREACHABLE_TINT
		else:
			slot.modulate = Color.WHITE


func _load_textures() -> void:
	_placeholder = load(_PLACEHOLDER_PATH) as Texture2D
	for i in HeroRoster.ACTIVE_PARTY_SIZE:
		var path: String = HeroRoster.get_portrait_path(i)
		var tex: Texture2D = load(path) as Texture2D if not path.is_empty() else null
		_idle_party.append(tex if tex != null else _placeholder)
	_attack_party = _load_or(_ATTACK_PARTY_PATH, _placeholder)
	_attack_enemy = _load_or(_ATTACK_ENEMY_PATH, _placeholder)
	for pair in [[1, _HERO2_ATTACK_PATH], [2, _HERO3_ATTACK_PATH]]:
		var frame := load(pair[1]) as Texture2D
		if frame != null:
			_hero_attack_frames[pair[0]] = [frame] as Array[Texture2D]


func _load_or(path: String, fallback: Texture2D) -> Texture2D:
	var tex := load(path) as Texture2D
	return tex if tex != null else fallback


## Loads (and caches) a Texture2D for [param path]; null if missing.
func _enemy_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not _enemy_texture_cache.has(path):
		_enemy_texture_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _enemy_texture_cache[path]


func _clear(container: Node) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()


## One row of slots. [param behind] indents it; [param push_right] adds a
## leading spacer that pushes the slots to the right edge.
func _make_row(container: VBoxContainer, behind: bool, push_right: bool = false) -> HBoxContainer:
	var h := HBoxContainer.new()
	# Row height = content height, so rows align to the bottom ("on the ground").
	h.size_flags_vertical = 0
	h.add_theme_constant_override("separation", _ROW_SEPARATION)
	if push_right:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(spacer)
	if behind:
		var m := MarginContainer.new()
		m.size_flags_vertical = 0
		m.add_theme_constant_override("margin_left", _BACK_ROW_INDENT)
		m.add_child(h)
		container.add_child(m)
	else:
		container.add_child(h)
	return h


func _new_slot(index: int, is_party: bool) -> BattlerSlot:
	var slot: BattlerSlot = BattlerSlotScene.instantiate()
	slot.slot_index = index
	slot.is_party = is_party
	slot.feel = _feel
	if not is_party:
		slot.slot_clicked.connect(enemy_slot_clicked.emit)
	return slot


func _build_party(party: Array) -> void:
	var row := _make_row(_party_container, false)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in _PARTY_VISUAL_ORDER:
		if i >= party.size():
			continue
		var slot := _new_slot(i, true)
		row.add_child(slot)
		slot.setup(party[i], party_idle_texture(i), _attack_party)
		slot.set_role_display(HeroRoster.get_role_label(i), HeroRoster.get_role_color(i))
		if _hero_attack_frames.has(i):
			slot.set_attack_frames(_hero_attack_frames[i])
		_party_slots.append(slot)
	_party_slots.sort_custom(func(a: BattlerSlot, b: BattlerSlot) -> bool: return a.slot_index < b.slot_index)
	_party_container.alignment = BoxContainer.ALIGNMENT_END


func _build_enemies(enemies: Array) -> void:
	# The back row only exists with 3+ enemies; an empty row would still cost
	# the container separation of arena height.
	if enemies.size() >= 3:
		_build_enemy_row(_make_row(_enemy_container, true, true), [2, 3], enemies)
	_build_enemy_row(_make_row(_enemy_container, false, true), [0, 1], enemies)
	_enemy_container.alignment = BoxContainer.ALIGNMENT_END


func _build_enemy_row(row: HBoxContainer, indices: Array, enemies: Array) -> void:
	for i in indices:
		if i >= enemies.size():
			continue
		var slot := _new_slot(i, false)
		row.add_child(slot)
		_setup_enemy_slot(slot, enemies[i])
		_enemy_slots.append(slot)


## Idle + attack frames, scale and tint for one enemy slot, all read from the
## battler's archetype (stats.enemy_type), never from the slot index.
func _setup_enemy_slot(slot: BattlerSlot, stats: BattlerStats) -> void:
	var type_id: String = stats.enemy_type
	# sprite_scale widens the box only. Enemy art is width-limited in it
	# (KEEP_ASPECT_CENTERED), so the sprite grows while the box height, and
	# therefore the arena row height, stays put (a taller box pushed the floor
	# banner off-screen on the boss floor).
	var size := Vector2(_ENEMY_BOX.x * EnemyRoster.get_sprite_scale(type_id), _ENEMY_BOX.y)
	slot.setup(stats, enemy_idle_texture(type_id), _attack_enemy, size)
	var frames: Array[Texture2D] = []
	for p in EnemyRoster.get_attack_frame_paths(type_id):
		var t: Texture2D = _enemy_texture(str(p))
		if t != null:
			frames.append(t)
	if not frames.is_empty():
		slot.set_attack_frames(frames)
	slot.set_sprite_tint(EnemyRoster.get_tint(type_id))
	slot.set_boss_visual(EnemyRoster.is_boss(type_id))
