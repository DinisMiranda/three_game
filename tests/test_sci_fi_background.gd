class_name TestSciFiBackground
extends GdUnitTestSuite
## Unit tests for SciFiBackground (scripts/battle/sci_fi_background.gd).

var _root: Node

func before_test() -> void:
	_root = Node.new()

func after_test() -> void:
	if _root:
		_root.free()
		_root = null

func test_sci_fi_background_instantiates_and_draws() -> void:
	var script_class = load("res://scripts/battle/sci_fi_background.gd") as GDScript
	var node := Control.new()
	node.set_script(script_class)
	_root.add_child(node)
	node.set_size(Vector2(800, 600))
	node.queue_redraw()
	assert_object(node).is_not_null()
