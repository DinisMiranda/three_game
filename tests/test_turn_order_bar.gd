class_name TestTurnOrderBar
extends GdUnitTestSuite
## Unit tests for TurnOrderBar (scripts/battle/turn_order_bar.gd): chip view
## model, keyed chip updates, active marking, side colours and removal.
## Phase 1D, docs/design/portfolio-plan.md.


func _entries() -> Array:
	return [
		{ "key": "P0", "name": "Kael", "is_party": true },
		{ "key": "E0", "name": "Spire Warden", "is_party": false },
		{ "key": "P1", "name": "Nova", "is_party": true },
	]


func _bar() -> TurnOrderBar:
	var bar: TurnOrderBar = auto_free(TurnOrderBar.new())
	return bar


func test_build_chip_specs_one_per_entry_in_order() -> void:
	var specs := _bar().build_chip_specs(_entries(), "E0")
	assert_int(specs.size()).is_equal(3)
	assert_str(specs[0].key).is_equal("P0")
	assert_str(specs[1].key).is_equal("E0")
	assert_str(specs[2].key).is_equal("P1")


func test_build_chip_specs_marks_only_active() -> void:
	var specs := _bar().build_chip_specs(_entries(), "E0")
	assert_bool(specs[0].is_active).is_false()
	assert_bool(specs[1].is_active).is_true()
	assert_bool(specs[2].is_active).is_false()


func test_build_chip_specs_empty_active_key_marks_none() -> void:
	for spec in _bar().build_chip_specs(_entries(), ""):
		assert_bool(spec.is_active).is_false()


func test_build_chip_specs_side_colour_per_team() -> void:
	var bar := _bar()
	var specs := bar.build_chip_specs(_entries(), "")
	assert_object(specs[0].side_color).is_equal(bar.party_color)
	assert_object(specs[1].side_color).is_equal(bar.enemy_color)
	assert_object(bar.party_color).is_not_equal(bar.enemy_color)


func test_build_chip_specs_skips_missing_and_duplicate_keys() -> void:
	var entries := _entries()
	entries.append({ "name": "No key", "is_party": false })
	entries.append({ "key": "P0", "name": "Dup", "is_party": true })
	assert_int(_bar().build_chip_specs(entries, "").size()).is_equal(3)


func test_shorten_name() -> void:
	assert_str(TurnOrderBar.shorten_name("Kael", 10)).is_equal("Kael")
	assert_str(TurnOrderBar.shorten_name("Meridian Enforcer", 8)).is_equal("Meridia…")
	assert_int(TurnOrderBar.shorten_name("Meridian Enforcer", 8).length()).is_equal(8)


func test_set_order_builds_n_chips_and_active() -> void:
	var bar := _bar()
	bar.set_order(_entries(), "P1")
	assert_int(bar.get_chip_count()).is_equal(3)
	assert_array(bar.get_chip_keys()).is_equal(["P0", "E0", "P1"])
	assert_str(bar.get_active_key()).is_equal("P1")
	assert_bool(bar.is_chip_active("P1")).is_true()
	assert_bool(bar.is_chip_active("P0")).is_false()
	assert_object(bar.get_chip_side_color("E0")).is_equal(bar.enemy_color)
	assert_str(bar.get_chip_name("E0")).is_equal("Spire Warden")


func test_set_order_moves_active_without_rebuilding() -> void:
	var bar := _bar()
	bar.set_order(_entries(), "P0")
	var first_children := bar.get_children()
	bar.set_order(_entries(), "E0")
	assert_array(bar.get_children()).is_equal(first_children)
	assert_bool(bar.is_chip_active("P0")).is_false()
	assert_bool(bar.is_chip_active("E0")).is_true()


func test_set_order_removes_missing_battler() -> void:
	var bar := _bar()
	bar.set_order(_entries(), "P0")
	var entries := _entries()
	entries.remove_at(1)  # E0 downed
	bar.set_order(entries, "P0")
	assert_int(bar.get_chip_count()).is_equal(2)
	assert_array(bar.get_chip_keys()).is_equal(["P0", "P1"])


func test_removed_chip_animates_out_when_in_tree() -> void:
	var bar := _bar()
	bar.feel = BattleFeel.new()
	add_child(bar)
	bar.set_order(_entries(), "P0")
	var entries := _entries()
	entries.remove_at(1)
	bar.set_order(entries, "P0")
	assert_int(bar.get_chip_count()).is_equal(2)
	assert_int(bar.get_dying_count()).is_equal(1)
	await await_millis(int(bar.feel.turn_chip_remove_duration * 1000.0) + 200)
	assert_int(bar.get_dying_count()).is_equal(0)
	assert_int(bar.get_child_count()).is_equal(2)
