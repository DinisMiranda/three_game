class_name TestCharacterVisuals
extends GdUnitTestSuite
## Phase 2A character treatment: shaders load, BattlerSlot applies the right
## material per side, roster grade data, trim + baseline helpers (pure).

const CHAR_SHADER := "res://assets/shaders/character_unify.gdshader"
const AURA_SHADER := "res://assets/shaders/boss_aura.gdshader"
const SLOT_SCENE := "res://scenes/battle/battler_slot.tscn"


func _slot(is_party: bool, slot_index: int, stats: BattlerStats) -> BattlerSlot:
	var slot := (load(SLOT_SCENE) as PackedScene).instantiate() as BattlerSlot
	slot.is_party = is_party
	slot.slot_index = slot_index
	add_child(slot)
	auto_free(slot)
	slot.setup(stats, null)
	return slot


func _shader_path(slot: BattlerSlot) -> String:
	var mat := slot.texture_rect.material as ShaderMaterial
	return mat.shader.resource_path if mat and mat.shader else ""


func test_shaders_load() -> void:
	assert_object(load(CHAR_SHADER) as Shader).is_not_null()
	assert_object(load(AURA_SHADER) as Shader).is_not_null()


func test_hero_slot_gets_character_shader_and_roster_grade() -> void:
	var stats := BattlerStats.new()
	HeroRoster.apply_to_stats(0, stats)  # Kael
	var slot := _slot(true, 0, stats)
	assert_str(_shader_path(slot)).is_equal(CHAR_SHADER)
	var mat := slot.texture_rect.material as ShaderMaterial
	var g: Vector3 = HeroRoster.get_shader_grade(0)
	assert_float(float(mat.get_shader_parameter("saturation"))).is_equal_approx(g.x, 0.0001)
	assert_float(float(mat.get_shader_parameter("contrast"))).is_equal_approx(g.y, 0.0001)
	assert_float(float(mat.get_shader_parameter("brightness"))).is_equal_approx(g.z, 0.0001)
	assert_object(mat.get_shader_parameter("rim_color")).is_equal(BattlerSlot.PARTY_RIM_COLOR)


func test_enemy_slot_gets_character_shader_with_enemy_rim() -> void:
	var stats := BattlerStats.new()
	EnemyRoster.apply_to_stats("warden", 1, stats)
	var slot := _slot(false, 0, stats)
	assert_str(_shader_path(slot)).is_equal(CHAR_SHADER)
	var mat := slot.texture_rect.material as ShaderMaterial
	assert_object(mat.get_shader_parameter("rim_color")).is_equal(BattlerSlot.ENEMY_RIM_COLOR)
	assert_float(slot.get_figure_height()).is_equal(EnemyRoster.get_figure_height("warden"))


func test_boss_slot_gets_aura_and_boss_height() -> void:
	var stats := BattlerStats.new()
	EnemyRoster.apply_to_stats("custodian", 3, stats)
	var slot := _slot(false, 0, stats)
	slot.set_boss_visual(true)
	assert_str(_shader_path(slot)).is_equal(AURA_SHADER)
	assert_float(slot.get_figure_height()).is_equal(320.0)


func test_roster_grade_defaults_and_kael_fix() -> void:
	assert_object(HeroRoster.get_shader_grade(0)).is_equal(Vector3(1.4, 1.25, -0.08))
	assert_object(HeroRoster.get_shader_grade(1)).is_equal(Vector3(1.0, 1.0, 0.0))
	assert_object(HeroRoster.get_shader_grade(99)).is_equal(Vector3(1.0, 1.0, 0.0))
	assert_object(EnemyRoster.get_shader_grade("hound")).is_equal(Vector3(1.0, 1.0, 0.0))
	assert_object(EnemyRoster.get_shader_grade("nope")).is_equal(Vector3(1.0, 1.0, 0.0))


func test_figure_heights_from_data() -> void:
	assert_float(HeroRoster.get_figure_height(0)).is_equal(240.0)
	assert_float(EnemyRoster.get_figure_height("hound")).is_equal(240.0)
	assert_float(EnemyRoster.get_figure_height("custodian")).is_equal(320.0)


func test_fit_figure_scales_to_target_height() -> void:
	# Kael's trimmed figure (290 x 497) at 240 px tall.
	var fig := BattlerSlot.fit_figure(Vector2(290, 497), 240.0, 1000.0)
	assert_float(fig.y).is_equal_approx(240.0, 0.001)
	assert_float(fig.x).is_equal_approx(290.0 * 240.0 / 497.0, 0.001)


func test_fit_figure_caps_width() -> void:
	var fig := BattlerSlot.fit_figure(Vector2(600, 200), 240.0, 360.0)
	assert_float(fig.x).is_equal_approx(360.0, 0.001)
	assert_float(fig.y).is_equal_approx(120.0, 0.001)


func test_fit_figure_degenerate_is_zero() -> void:
	assert_object(BattlerSlot.fit_figure(Vector2.ZERO, 240.0, 100.0)).is_equal(Vector2.ZERO)


func test_place_figure_bottom_aligned_on_floor_line() -> void:
	var r := BattlerSlot.place_figure(Vector2(200, 248), Vector2(140, 240), 8.0)
	assert_float(r.position.x).is_equal_approx(30.0, 0.001)
	assert_float(r.end.y).is_equal_approx(240.0, 0.001)  # 248 - 8 floor margin


func test_compute_trim_rect_ignores_padding_and_faint_noise() -> void:
	var img := Image.create(20, 30, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(5, 10, 6, 15), Color(1, 1, 1, 1))
	img.set_pixel(0, 0, Color(1, 1, 1, 0.05))  # below the threshold
	assert_object(BattlerSlot.compute_trim_rect(img, 0.1)).is_equal(Rect2i(5, 10, 6, 15))


func test_compute_trim_rect_opaque_and_empty() -> void:
	var rgb := Image.create(8, 4, false, Image.FORMAT_RGB8)
	assert_object(BattlerSlot.compute_trim_rect(rgb)).is_equal(Rect2i(0, 0, 8, 4))
	var clear := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	clear.fill(Color(0, 0, 0, 0))
	assert_object(BattlerSlot.compute_trim_rect(clear)).is_equal(Rect2i())
