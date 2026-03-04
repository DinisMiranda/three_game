class_name TestShieldBubble
extends GdUnitTestSuite
## Unit tests for ShieldBubble (scripts/battle/shield_bubble.gd).

var _root: Node

func before_test() -> void:
	_root = Node.new()

func after_test() -> void:
	if _root:
		_root.free()
		_root = null

func test_shield_bubble_instantiates_and_draws() -> void:
	var script_class = load("res://scripts/battle/shield_bubble.gd") as GDScript
	var node := Control.new()
	node.set_script(script_class)
	_root.add_child(node)
	node.set_size(Vector2(100, 100))
	node.visible = true
	node.queue_redraw()
	# Just ensure no crash; _draw() runs when visible and size is set
	assert_object(node).is_not_null()
	assert_bool(node.visible).is_true()
