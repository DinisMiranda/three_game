class_name TestBattlerSlot
extends GdUnitTestSuite
## Unit tests for BattlerSlot (scripts/battle/battler_slot.gd). Uses scene so @onready nodes exist.

var _root: Node
var _slot: BattlerSlot

func before_test() -> void:
	_root = Node.new()
	var scene = load("res://scenes/battle/battler_slot.tscn") as PackedScene
	_slot = scene.instantiate() as BattlerSlot
	_root.add_child(_slot)

func after_test() -> void:
	if _slot and _slot.get_parent() == _root:
		_root.remove_child(_slot)
		_slot.free()
	_slot = null
	if _root:
		_root.free()
		_root = null

func test_setup_with_stats_and_null_texture() -> void:
	var stats := BattlerStats.new()
	stats.display_name = "Test"
	stats.max_hp = 100
	stats.current_hp = 80
	stats.max_energy = 100
	stats.current_energy = 50
	_slot.setup(stats, null)
	assert_object(_slot).is_not_null()
	assert_int(stats.current_hp).is_equal(80)

func test_refresh_updates_display() -> void:
	var stats := BattlerStats.new()
	stats.max_hp = 100
	stats.current_hp = 60
	stats.max_energy = 100
	stats.current_energy = 30
	_slot.setup(stats, null)
	stats.current_hp = 50
	stats.current_energy = 20
	_slot.refresh()
	assert_int(stats.current_hp).is_equal(50)

func test_set_turn_highlight() -> void:
	var stats := BattlerStats.new()
	stats.max_hp = 100
	stats.current_hp = 100
	_slot.setup(stats, null)
	_slot.set_turn_highlight(true)
	assert_object(_slot).is_not_null()
	_slot.set_turn_highlight(false)
	assert_object(_slot).is_not_null()


func test_boss_visual_applies_and_removes_aura_material() -> void:
	assert_object(load("res://assets/shaders/boss_aura.gdshader")).is_not_null()
	# @onready nodes only exist once the slot is inside the tree.
	add_child(_root)
	_slot.set_boss_visual(true, Color(1.0, 0.3, 0.1), 1.25)
	assert_bool(_slot.is_boss_visual()).is_true()
	var mat := _slot.texture_rect.material as ShaderMaterial
	assert_object(mat).is_not_null()
	assert_str(mat.shader.resource_path).is_equal("res://assets/shaders/boss_aura.gdshader")
	_slot.set_boss_visual(false)
	assert_object(_slot.texture_rect.material).is_null()
	assert_bool(_slot.is_boss_visual()).is_false()


func _make_stats(hp: int, max_hp: int, en: int, max_en: int) -> BattlerStats:
	var stats := BattlerStats.new()
	stats.display_name = "Bar"
	stats.max_hp = max_hp
	stats.current_hp = hp
	stats.max_energy = max_en
	stats.current_energy = en
	return stats


## A slot inside the scene tree, so its @onready labels and bars exist.
func _tree_slot(stats: BattlerStats) -> BattlerSlot:
	var slot := (load("res://scenes/battle/battler_slot.tscn") as PackedScene).instantiate() as BattlerSlot
	add_child(slot)
	auto_free(slot)
	slot.setup(stats, null)
	return slot


func test_refresh_shows_hp_and_energy_numbers() -> void:
	var slot := _tree_slot(_make_stats(80, 100, 60, 100))
	assert_str(slot.hp_value_label.text).is_equal("80/100")
	assert_str(slot.energy_value_label.text).is_equal("60/100")
	assert_str(slot.energy_tag.text).is_equal(slot.feel.energy_tag)


func test_low_hp_recolours_hp_fill() -> void:
	var stats := _make_stats(100, 100, 50, 100)
	var slot := _tree_slot(stats)
	var fill := slot.hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	assert_object(fill.bg_color).is_equal(slot.feel.hp_color)
	stats.current_hp = 10
	slot.refresh()
	assert_object(fill.bg_color).is_equal(slot.feel.hp_critical_color)


func test_energy_fill_uses_energy_color() -> void:
	var slot := _tree_slot(_make_stats(100, 100, 50, 100))
	var fill := slot.energy_bar.get_theme_stylebox("fill") as StyleBoxFlat
	assert_object(fill.bg_color).is_equal(slot.feel.energy_color)


func test_dead_slot_hides_bar_numbers() -> void:
	var slot := _tree_slot(_make_stats(0, 100, 50, 100))
	assert_bool(slot.hp_value_label.visible).is_false()
	assert_bool(slot.energy_value_label.visible).is_false()


func test_boss_visual_toggles_info_plate() -> void:
	var slot := _tree_slot(_make_stats(100, 100, 50, 100))
	assert_bool(slot.has_info_plate()).is_false()
	slot.set_boss_visual(true, Color(1.0, 0.3, 0.08), 1.2)
	assert_bool(slot.has_info_plate()).is_true()
	slot.set_boss_visual(false)
	assert_bool(slot.has_info_plate()).is_false()
