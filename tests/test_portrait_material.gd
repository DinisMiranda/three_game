class_name TestPortraitMaterial
extends GdUnitTestSuite
## Phase 2C polish: portrait character shader (pure placement + material),
## battle slot label readability, tactical map view height, dialogue box.

const CHAR_SHADER := "res://assets/shaders/character_unify.gdshader"
const SLOT_SCENE := "res://scenes/battle/battler_slot.tscn"
const MAP_SCRIPT := preload("res://scripts/story/world_map_select.gd")
const TEX := Vector2(400.0, 800.0)
const TRIM := Rect2i(100, 100, 200, 600)


func _v4_eq(a: Vector4, b: Vector4) -> void:
	assert_vector(a).is_equal_approx(b, Vector4.ONE * 0.0001)


func test_contain_placement_crops_to_trim_and_bottom_aligns() -> void:
	var p: Dictionary = PortraitMaterial.compute_placement(TEX, TRIM, Vector2(204.0, 304.0))
	_v4_eq(p.crop_uv, Vector4(0.25, 0.125, 0.5, 0.75))
	# Fit 200x600 into 200x300 (2 px inset each side) -> 100x300, centred, feet at 302.
	_v4_eq(p.dest_rect, Vector4(52.0 / 204.0, 2.0 / 304.0, 100.0 / 204.0, 300.0 / 304.0))
	# 0.75 UV over 300 px * 2 px outline.
	assert_vector(p.outline_uv).is_equal_approx(Vector2(0.5 / 100.0, 0.75 / 300.0) * 2.0, Vector2.ONE * 0.00001)


func test_cover_placement_fills_rect_and_keeps_top() -> void:
	var p: Dictionary = PortraitMaterial.compute_placement(TEX, TRIM, Vector2(50.0, 50.0),
		Rect2(0.0, 0.0, 1.0, 0.5), true)
	_v4_eq(p.dest_rect, Vector4(0.0, 0.0, 1.0, 1.0))
	# Region 200x300 shrunk to square 200x200, top-anchored at trim top.
	_v4_eq(p.crop_uv, Vector4(0.25, 0.125, 0.5, 0.25))


func test_cover_wide_region_is_centred_horizontally() -> void:
	var p: Dictionary = PortraitMaterial.compute_placement(TEX, Rect2i(0, 0, 400, 200),
		Vector2(40.0, 40.0), PortraitMaterial.FULL_FIGURE, true)
	# 400x200 -> 200x200 centred: x from 100.
	_v4_eq(p.crop_uv, Vector4(0.25, 0.0, 0.5, 0.25))


func test_empty_inputs_return_identity() -> void:
	var p: Dictionary = PortraitMaterial.compute_placement(Vector2.ZERO, TRIM, Vector2(10, 10))
	_v4_eq(p.crop_uv, Vector4(0, 0, 1, 1))
	_v4_eq(p.dest_rect, Vector4(0, 0, 1, 1))
	var q: Dictionary = PortraitMaterial.compute_placement(TEX, TRIM, Vector2.ZERO)
	_v4_eq(q.dest_rect, Vector4(0, 0, 1, 1))


func test_empty_trim_uses_full_texture() -> void:
	var p: Dictionary = PortraitMaterial.compute_placement(TEX, Rect2i(), Vector2(10, 10),
		PortraitMaterial.FULL_FIGURE, true)
	_v4_eq(p.crop_uv, Vector4(0.0, 0.0, 1.0, 0.5))


func test_build_uses_roster_grade_and_side_rim() -> void:
	var g: Vector3 = HeroRoster.get_shader_grade(0)
	var mat := PortraitMaterial.build(g, true)
	assert_str(mat.shader.resource_path).is_equal(CHAR_SHADER)
	assert_float(float(mat.get_shader_parameter("saturation"))).is_equal_approx(g.x, 0.0001)
	assert_float(float(mat.get_shader_parameter("contrast"))).is_equal_approx(g.y, 0.0001)
	assert_float(float(mat.get_shader_parameter("brightness"))).is_equal_approx(g.z, 0.0001)
	assert_that(mat.get_shader_parameter("rim_color")).is_equal(BattlerSlot.PARTY_RIM_COLOR)
	var enemy := PortraitMaterial.build(Vector3(1, 1, 0), false)
	assert_that(enemy.get_shader_parameter("rim_color")).is_equal(BattlerSlot.ENEMY_RIM_COLOR)


func test_apply_and_clear_restore_stretch_mode() -> void:
	var rect := TextureRect.new()
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(60, 60)
	add_child(rect)
	auto_free(rect)
	var tex := ImageTexture.create_from_image(Image.create(8, 16, false, Image.FORMAT_RGBA8))
	PortraitMaterial.apply(rect, tex, Vector3(1, 1, 0), true)
	assert_object(rect.material as ShaderMaterial).is_not_null()
	assert_int(rect.stretch_mode).is_equal(TextureRect.STRETCH_SCALE)
	PortraitMaterial.clear(rect)
	assert_object(rect.material).is_null()
	assert_int(rect.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)


func test_apply_null_texture_clears() -> void:
	var rect := TextureRect.new()
	auto_free(rect)
	PortraitMaterial.apply(rect, null, Vector3(1, 1, 0), true)
	assert_object(rect.material).is_null()


func test_find_hero_index_by_name() -> void:
	var name0 := str(HeroRoster.get_hero(0).get("display_name", ""))
	assert_int(HeroRoster.find_index_by_name(name0)).is_equal(0)
	assert_int(HeroRoster.find_index_by_name("Handler")).is_equal(-1)


func test_slot_labels_readable_and_turn_border_amber() -> void:
	var slot := (load(SLOT_SCENE) as PackedScene).instantiate() as BattlerSlot
	add_child(slot)
	auto_free(slot)
	assert_int(slot.role_label.get_theme_font_size("font_size")).is_equal(14)
	assert_int(slot.name_label.get_theme_constant("outline_size")).is_equal(2)
	assert_int(slot.role_label.get_theme_constant("outline_size")).is_equal(2)
	slot.set_turn_highlight(true)
	var box := slot.get_theme_stylebox("panel") as StyleBoxFlat
	assert_that(box.border_color).is_equal(Palette.SELECT_AMBER)
	assert_int(box.corner_radius_top_left).is_equal(4)
	assert_int(box.border_width_top).is_equal(2)


func test_map_view_height_uses_bar_heights() -> void:
	assert_float(MAP_SCRIPT.map_view_height(1080.0, 120.0, 160.0)).is_equal(800.0)
	assert_float(MAP_SCRIPT.map_view_height(1080.0, 120.0, 160.0, 4.0)).is_equal(792.0)
	assert_float(MAP_SCRIPT.map_view_height(100.0, 120.0, 160.0)).is_equal(1.0)


func test_dialogue_box_fit_and_font_size() -> void:
	var panel := PanelContainer.new()
	auto_free(panel)
	DialogueBoxStyle.fit_box(panel)
	assert_float(panel.anchor_left).is_equal(DialogueBoxStyle.BOX_ANCHORS.x)
	assert_float(panel.anchor_bottom).is_equal(DialogueBoxStyle.BOX_ANCHORS.w)
	var theme := load(TriadThemeBuilder.THEME_PATH) as Theme
	assert_int(theme.get_font_size("font_size", "DialogueBody")).is_equal(TriadThemeBuilder.SIZE_DIALOGUE)
