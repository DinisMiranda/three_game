class_name TestSceneFader
extends GdUnitTestSuite
## Unit tests for the SceneFader autoload (scripts/autoload/scene_fader.gd).
## Exercises the parts that need no running fade: data defaults, duration
## clamping and the refusal paths. Phase 1E.

const FADER_SCENE := "res://scenes/ui/scene_fader.tscn"
const FADER_SCRIPT := "res://scripts/autoload/scene_fader.gd"

var _fader: CanvasLayer


func before_test() -> void:
	_fader = (load(FADER_SCENE) as PackedScene).instantiate() as CanvasLayer


func after_test() -> void:
	if _fader:
		_fader.free()
		_fader = null


func test_scene_has_positive_durations() -> void:
	assert_float(_fader.fade_out_duration).is_greater(0.0)
	assert_float(_fader.fade_in_duration).is_greater(0.0)


func test_starts_idle() -> void:
	assert_bool(_fader.is_busy()).is_false()
	assert_int(_fader.get_state()).is_equal(0)


func test_clamp_duration_never_negative() -> void:
	var script: GDScript = load(FADER_SCRIPT)
	assert_float(script.clamp_duration(-1.0)).is_equal(0.0)
	assert_float(script.clamp_duration(0.4)).is_equal(0.4)


func test_change_scene_refuses_empty_path() -> void:
	assert_bool(_fader.change_scene("")).is_false()
	assert_bool(_fader.is_busy()).is_false()


func test_change_scene_refuses_outside_tree() -> void:
	assert_bool(_fader.change_scene("res://scenes/main_menu/main_menu.tscn")).is_false()
	assert_bool(_fader.is_busy()).is_false()


func test_fade_through_refuses_invalid_callable_and_does_not_call() -> void:
	var called := [false]
	assert_bool(_fader.fade_through(Callable())).is_false()
	# Outside the tree a valid callable is refused too, and not called.
	assert_bool(_fader.fade_through(func () -> void: called[0] = true)).is_false()
	assert_bool(called[0]).is_false()
