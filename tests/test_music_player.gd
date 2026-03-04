class_name TestMusicPlayer
extends GdUnitTestSuite
## Unit tests for MusicPlayer (scripts/audio/music_player.gd).

var _root: Node
var _player: Node

func before_test() -> void:
	_root = Node.new()
	var script_class = load("res://scripts/audio/music_player.gd") as GDScript
	_player = Node.new()
	_player.set_script(script_class)
	_root.add_child(_player)

func after_test() -> void:
	if _player and _player.get_parent() == _root:
		_root.remove_child(_player)
		_player.free()
	_player = null
	if _root:
		_root.free()
		_root = null

func test_play_menu_does_not_crash() -> void:
	_player.play_menu()
	# No stream files in test env is ok; _play_path just returns
	assert_object(_player).is_not_null()

func test_play_battle_does_not_crash() -> void:
	_player.play_battle()
	assert_object(_player).is_not_null()

func test_stop_does_not_crash() -> void:
	_player.stop()
	assert_object(_player).is_not_null()

func test_set_volume_db() -> void:
	_player.set_volume_db(-10.0)
	assert_object(_player).is_not_null()
