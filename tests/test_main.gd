class_name TestMain
extends GdUnitTestSuite
## Unit tests for main entry (scripts/main/main.gd).

var _root: Node
var _main: Control

func before_test() -> void:
	_root = Node.new()
	var script_class = load("res://scripts/main/main.gd") as GDScript
	_main = Control.new()
	_main.set_script(script_class)
	_root.add_child(_main)

func after_test() -> void:
	if _main and _main.get_parent() == _root:
		_root.remove_child(_main)
		_main.free()
	_main = null
	if _root:
		_root.free()
		_root = null

func test_main_ready_does_not_crash() -> void:
	# _ready() is just pass; ensures script loads
	assert_object(_main).is_not_null()
