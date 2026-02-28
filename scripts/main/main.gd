extends Control
## Main entry. Currently loads the battle scene directly.
## You can later add a main menu and start battle from here.

func _ready() -> void:
	# Battle is already instanced as child in main.tscn.
	# To switch to battle from a menu later: get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")
	pass
