class_name TestBattleLog
extends GdUnitTestSuite
## Unit tests for BattleLog (scripts/battle/battle_log.gd): compact last-N view,
## full history, history cap and expand toggle. Phase 1D.


func _log_with(n: int) -> BattleLog:
	var log: BattleLog = auto_free(BattleLog.new())
	for i in n:
		log.add_line("line %d" % i)
	return log


func test_compact_view_shows_last_three_newest_first() -> void:
	var log := _log_with(5)
	assert_array(log.get_compact_lines()).is_equal(["line 4", "line 3", "line 2"])
	assert_array(log.get_visible_lines()).is_equal(["line 4", "line 3", "line 2"])


func test_compact_view_with_fewer_lines() -> void:
	var log := _log_with(2)
	assert_array(log.get_compact_lines()).is_equal(["line 1", "line 0"])


func test_history_keeps_all_lines() -> void:
	var log := _log_with(5)
	assert_int(log.get_history().size()).is_equal(5)
	assert_str(log.get_history()[4]).is_equal("line 0")


func test_history_is_capped() -> void:
	var log: BattleLog = auto_free(BattleLog.new())
	log.max_history = 4
	for i in 10:
		log.add_line("line %d" % i)
	assert_int(log.get_history().size()).is_equal(4)
	assert_str(log.get_history()[0]).is_equal("line 9")


func test_expand_shows_full_history_and_emits() -> void:
	var log := _log_with(5)
	var monitor := monitor_signals(log)
	log.toggle_expanded()
	assert_bool(log.is_expanded()).is_true()
	assert_int(log.get_visible_lines().size()).is_equal(5)
	await assert_signal(monitor).is_emitted("expanded_changed", [true])
	log.toggle_expanded()
	assert_bool(log.is_expanded()).is_false()
	assert_int(log.get_visible_lines().size()).is_equal(3)


func test_collapsed_line_count_is_configurable() -> void:
	var log := _log_with(5)
	log.collapsed_line_count = 1
	assert_array(log.get_compact_lines()).is_equal(["line 4"])


func test_clear() -> void:
	var log := _log_with(3)
	log.clear()
	assert_int(log.get_history().size()).is_equal(0)
