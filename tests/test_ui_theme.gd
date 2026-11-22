class_name TestUiTheme
extends GdUnitTestSuite
## Phase 2B: Palette tokens match docs/design/art-direction.md §1, the Theme
## resource loads with Exo 2 as default font, and the main menu shows
## Continue only when there is progress to resume.

const MainMenuScript = preload("res://scripts/main_menu/main_menu.gd")
const THEME_PATH := "res://assets/ui/triad_theme.tres"


func _hex(c: Color) -> String:
	return c.to_html(false).to_upper()


func test_palette_tokens_match_spec_hex() -> void:
	var expected := {
		"BG_DEEP": "0A0D14", "PANEL_FILL": "141720", "PANEL_RAISED": "1F242E",
		"PANEL_HOVER": "2E3847", "LINE_CYAN": "00D9FF", "ACCENT_CYAN": "00E5FF",
		"TEXT_PRIMARY": "E6EBF2", "TEXT_SECONDARY": "A6B8CC", "TEXT_DISABLED": "6B7380",
		"PARTY_TEAL": "00D9E6", "ENEMY_RED": "FF6B52", "SELECT_AMBER": "FFBF33",
		"ENERGY_YELLOW": "FFD638", "HP_LOW": "FF9429", "HP_CRIT": "FF423D",
		"BOSS_EMBER": "FF5919",
	}
	var consts: Dictionary = (Palette as Script).get_script_constant_map()
	for key: String in expected:
		assert_bool(consts.has(key)).override_failure_message("missing token " + key).is_true()
		assert_str(_hex(consts[key])).override_failure_message(key).is_equal(expected[key])


func test_palette_alpha_tokens() -> void:
	assert_float(Palette.PANEL_FILL.a).is_equal_approx(0.95, 0.005)
	assert_float(Palette.LINE_CYAN.a).is_equal_approx(0.6, 0.005)
	assert_float(Palette.ACCENT_CYAN.a).is_equal(1.0)


func test_theme_loads_with_default_font() -> void:
	var theme := load(THEME_PATH) as Theme
	assert_object(theme).is_not_null()
	assert_object(theme.default_font).is_not_null()
	assert_int(theme.default_font_size).is_equal(TriadThemeBuilder.SIZE_BODY)
	var fv := theme.default_font as FontVariation
	assert_object(fv).is_not_null()
	assert_str(fv.base_font.resource_path).is_equal(TriadThemeBuilder.EXO2_PATH)


func test_theme_panel_and_button_styles_use_tokens() -> void:
	var theme := load(THEME_PATH) as Theme
	var panel := theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	assert_bool(panel.bg_color.is_equal_approx(Palette.PANEL_FILL)).is_true()
	assert_bool(panel.border_color.is_equal_approx(Palette.LINE_CYAN)).is_true()
	assert_int(panel.corner_radius_top_left).is_equal(4)
	var focus := theme.get_stylebox("focus", "Button") as StyleBoxFlat
	assert_int(focus.border_width_left).is_equal(2)
	assert_bool(focus.border_color.is_equal_approx(Palette.SELECT_AMBER)).is_true()
	assert_bool(focus.draw_center).is_false()
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		assert_bool(theme.has_stylebox(state, "Button")).override_failure_message(state).is_true()


func test_theme_matches_builder() -> void:
	# Guards against the .tres drifting from TriadThemeBuilder.
	var saved := load(THEME_PATH) as Theme
	var built := TriadThemeBuilder.build()
	assert_array(saved.get_type_variation_list("Label")).contains_exactly_in_any_order(
		built.get_type_variation_list("Label"))
	var a := saved.get_stylebox("normal", "Button") as StyleBoxFlat
	var b := built.get_stylebox("normal", "Button") as StyleBoxFlat
	assert_bool(a.bg_color.is_equal_approx(b.bg_color)).is_true()


func test_continue_hidden_without_progress() -> void:
	assert_str(MainMenuScript.get_continue_scene(false, false, false)).is_empty()


func test_continue_resumes_active_mission_in_battle() -> void:
	assert_str(MainMenuScript.get_continue_scene(true, false, false)).is_equal(MainMenuScript.BATTLE_SCENE)


func test_continue_prefers_pending_epilogue() -> void:
	assert_str(MainMenuScript.get_continue_scene(true, true, false)).is_equal(MainMenuScript.EPILOGUE_SCENE)


func test_continue_goes_to_hideout_select_when_ready() -> void:
	assert_str(MainMenuScript.get_continue_scene(false, false, true)).is_equal(MainMenuScript.HIDEOUT_SELECT_SCENE)


func test_dialogue_speaker_tag_format() -> void:
	assert_str(DialogueBoxStyle.format_speaker("Nova")).is_equal("NOVA")
	assert_str(DialogueBoxStyle.format_line("Move.")).is_equal("\"Move.\"")
