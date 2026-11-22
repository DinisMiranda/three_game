class_name TestRosterResources
extends GdUnitTestSuite
## Phase 3B: hero / enemy / mission data moved from GDScript tables to .tres
## Resources (HeroData, EnemyArchetype, MissionData + FloorData). These tests pin
## that every file loads with its required fields and that the roster getters
## return the exact pre-3B values (boundary values: the numbers ARE the point).

const MissionProgressScript = preload("res://scripts/autoload/mission_progress.gd")

## id -> [display_name, role_label, role_color, enabled, max_hp, attack, defense, speed, portrait]
const HERO_EXPECTED: Dictionary = {
	"kael": ["Kael", "Grenadier", "#ff8c3a", true, 92, 14, 5, 9, "res://assets/sevro_pixel_no_bg-removebg-preview.png"],
	"nova": ["Nova", "Skirmisher", "#5ce1ff", true, 78, 11, 3, 13, "res://assets/hero 2 no bg.png"],
	"rin": ["Rin", "Field Support", "#9dff7a", true, 86, 10, 5, 10, "res://assets/hero 3 no bg copy.png"],
	"brick": ["Brick", "Frontliner", "#c9a0ff", false, 120, 11, 9, 7, "res://assets/character_placeholder.png"],
	"sage": ["Sage", "Medic", "#7dffb8", false, 72, 8, 4, 11, "res://assets/character_placeholder.png"],
}
const HERO_ABILITIES: Array = [
	["grenade", "guard"], ["fly", "snipe"], ["strike", "shield"], ["guard", "strike"], ["shield", "strike"],
]
## id -> [display_name, ai_profile, is_ranged, base_hp, base_attack, defense, speed, sprite_scale, figure_height, is_boss]
const ENEMY_EXPECTED: Dictionary = {
	"warden": ["Spire Warden", 0, true, 40, 16, 3, 5, 1.0, 240.0, false],
	"hound": ["Sentry Hound", 1, false, 50, 18, 3, 8, 1.0, 240.0, false],
	"custodian": ["Custodian Unit", 0, false, 55, 20, 3, 7, 1.2, 360.0, true],
	"enforcer": ["Meridian Enforcer", 2, false, 45, 16, 4, 6, 1.0, 240.0, false],
}


func test_every_hero_tres_loads_with_required_fields() -> void:
	assert_int(HeroRoster.HERO_PATHS.size()).is_equal(HeroRoster.FULL_ROSTER_SIZE)
	for path in HeroRoster.HERO_PATHS:
		var h := load(path) as HeroData
		assert_object(h).override_failure_message("not HeroData: %s" % path).is_not_null()
		assert_str(h.id).is_not_empty()
		assert_str(h.display_name).is_not_empty()
		assert_int(h.max_hp).is_greater(0)
		assert_int(h.abilities.size()).is_equal(2)
		assert_bool(ResourceLoader.exists(h.portrait)).override_failure_message(
			"%s portrait missing: %s" % [h.id, h.portrait]).is_true()


func test_hero_getters_match_pre_resource_values() -> void:
	var ids: Array = HERO_EXPECTED.keys()
	for i in ids.size():
		var e: Array = HERO_EXPECTED[ids[i]]
		var d: Dictionary = HeroRoster.get_hero(i)
		assert_str(str(d.id)).is_equal(ids[i])
		assert_str(str(d.display_name)).is_equal(e[0])
		assert_str(HeroRoster.get_role_label(i)).is_equal(e[1])
		assert_str(str(d.role_color)).is_equal(e[2])
		assert_bool(HeroRoster.get_role_color(i).is_equal_approx(Color.from_string(e[2], Color.BLACK))).is_true()
		assert_bool(bool(d.enabled)).is_equal(e[3])
		assert_int(int(d.max_hp)).is_equal(e[4])
		assert_int(int(d.attack)).is_equal(e[5])
		assert_int(int(d.defense)).is_equal(e[6])
		assert_int(int(d.speed)).is_equal(e[7])
		assert_str(HeroRoster.get_portrait_path(i)).is_equal(e[8])
		assert_float(HeroRoster.get_figure_height(i)).is_equal(240.0)
		assert_int(HeroRoster.find_index_by_name(e[0])).is_equal(i)
		var ab: Array = []
		for a in HeroRoster.get_abilities(i):
			ab.append(str(a.id))
		assert_array(ab).is_equal(HERO_ABILITIES[i])


func test_hero_shader_grades_unchanged() -> void:
	assert_vector(HeroRoster.get_shader_grade(0)).is_equal_approx(Vector3(1.4, 1.25, -0.08), Vector3.ONE * 0.0001)
	for i in range(1, HeroRoster.FULL_ROSTER_SIZE):
		assert_vector(HeroRoster.get_shader_grade(i)).is_equal(Vector3(1.0, 1.0, 0.0))


func test_build_party_uses_resource_stats() -> void:
	var party: Array = HeroRoster.build_party()
	assert_int(party.size()).is_equal(HeroRoster.ACTIVE_PARTY_SIZE)
	var s: BattlerStats = party[0]
	assert_str(s.display_name).is_equal("Kael")
	assert_int(s.max_hp).is_equal(92)
	assert_int(s.max_energy).is_equal(100)
	assert_int(s.current_energy).is_equal(100)
	assert_bool(s.is_party).is_true()


func test_reserved_heroes_are_hideout_only() -> void:
	var names: Array = []
	for h in HeroRoster.get_hideout_heroes():
		names.append(str(h.display_name))
	assert_array(names).is_equal(["Brick", "Sage"])
	var stats := BattlerStats.new()
	assert_bool(HeroRoster.apply_to_stats(3, stats)).is_false()


func test_hero_barks_resolve() -> void:
	assert_array(["Fire in the hole!", "Brace for impact!"]).contains([HeroRoster.get_bark(0, "grenade")])
	assert_str(HeroRoster.get_bark(3, "attack")).is_empty()


func test_every_enemy_tres_loads_with_required_fields() -> void:
	assert_int(EnemyRoster.ARCHETYPE_PATHS.size()).is_equal(ENEMY_EXPECTED.size())
	for path in EnemyRoster.ARCHETYPE_PATHS:
		var a := load(path) as EnemyArchetype
		assert_object(a).override_failure_message("not EnemyArchetype: %s" % path).is_not_null()
		assert_bool(ENEMY_EXPECTED.has(a.id)).override_failure_message("unexpected id %s" % a.id).is_true()
		assert_str(a.idle_sprite).is_not_empty()
		assert_bool(a.attack_frames.is_empty()).is_false()


func test_enemy_getters_match_pre_resource_values() -> void:
	assert_array(EnemyRoster.get_type_ids()).is_equal(["warden", "hound", "custodian", "enforcer"])
	for tid in ENEMY_EXPECTED:
		var e: Array = ENEMY_EXPECTED[tid]
		assert_str(EnemyRoster.get_display_name(tid)).is_equal(e[0])
		assert_int(EnemyRoster.get_ai_profile(tid)).is_equal(e[1])
		assert_bool(bool(EnemyRoster.get_archetype(tid).is_ranged)).is_equal(e[2])
		assert_int(EnemyRoster.get_max_hp(tid, 1)).is_equal(e[3])
		assert_int(EnemyRoster.get_max_hp(tid, 3)).is_equal(e[3] + 20)
		assert_int(EnemyRoster.get_attack(tid, 1)).is_equal(e[4])
		assert_int(EnemyRoster.get_attack(tid, 3)).is_equal(e[4] + 4)
		assert_int(int(EnemyRoster.get_archetype(tid).defense)).is_equal(e[5])
		assert_int(int(EnemyRoster.get_archetype(tid).speed)).is_equal(e[6])
		assert_float(EnemyRoster.get_sprite_scale(tid)).is_equal_approx(e[7], 0.0001)
		assert_float(EnemyRoster.get_figure_height(tid)).is_equal(e[8])
		assert_bool(EnemyRoster.is_boss(tid)).is_equal(e[9])
		assert_vector(EnemyRoster.get_shader_grade(tid)).is_equal(Vector3(1.0, 1.0, 0.0))


func test_enemy_tint_and_aura_unchanged() -> void:
	assert_bool(EnemyRoster.get_tint("warden") == Color.WHITE).is_true()
	assert_bool(EnemyRoster.get_aura_color("warden") == Color.WHITE).is_true()
	assert_bool(EnemyRoster.get_tint("custodian").is_equal_approx(Color(1.0, 0.72, 0.6))).is_true()
	assert_bool(EnemyRoster.get_aura_color("custodian").is_equal_approx(Color(1.0, 0.3, 0.08))).is_true()
	assert_bool(EnemyRoster.get_archetype("warden").has("aura_color")).is_false()


func test_mission_tres_loads_three_floors() -> void:
	var m := load(MissionProgressScript.MERIDIAN_MISSION_PATH) as MissionData
	assert_object(m).is_not_null()
	assert_int(m.floors.size()).is_equal(MissionProgressScript.MERIDIAN_MAX_FLOOR)
	for f in m.floors:
		assert_str(f.title).is_not_empty()
		assert_bool(ResourceLoader.exists(f.background)).override_failure_message(
			"missing bg %s" % f.background).is_true()


func test_floor_lineups_and_titles_resolve() -> void:
	var floors: Array = MissionProgressScript.MERIDIAN_FLOORS
	assert_array(floors[0].enemies).is_equal(["warden"])
	assert_array(floors[1].enemies).is_equal(["warden", "hound"])
	assert_array(floors[2].enemies).is_equal(["custodian"])
	assert_str(str(floors[0].title)).is_equal("Floor 1 — Corridor breach")
	assert_str(str(floors[2].bg)).is_equal("res://assets/e32ee0a6-a11a-4f0a-b8be-ec9723487b2b.png")
