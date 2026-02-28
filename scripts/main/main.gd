extends Control
## Main entry scene. The battle is instanced as a child in main.tscn, so the game
## starts directly in battle. You can later add a main menu and call
## get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn") to start a battle.

func _ready() -> void:
	# Battle is already a child node in main.tscn; no code needed to show it.
	# To start battle from a menu later: get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")
	pass
