extends Node
## Autoload: plays background music across scenes. Call play_menu() or play_battle() from each scene's _ready().
## Add OGG or MP3 files to assets/music/. Options: menu + battle, or a single background.* for both.

const PATHS_MENU := ["res://assets/music/menu.ogg", "res://assets/music/menu.mp3"]
const PATHS_BATTLE := ["res://assets/music/battle.ogg", "res://assets/music/battle.mp3"]
const PATHS_FALLBACK := ["res://assets/music/background.ogg", "res://assets/music/background.mp3"]

var _player: AudioStreamPlayer
var _current_path: String = ""

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	add_child(_player)
	# Optional: use a "Music" bus for volume control
	if Engine.get_main_loop() is SceneTree:
		var idx = AudioServer.get_bus_index(&"Music")
		if idx >= 0:
			_player.bus = &"Music"

func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream

func _play_path(path: String) -> void:
	if path.is_empty():
		return
	if path == _current_path and _player.playing:
		return
	var stream: AudioStream = _load_stream(path)
	if stream == null:
		return
	_current_path = path
	_player.stream = stream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).set_loop(true)
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).set_loop(true)
	_player.play()

func _first_existing_path(paths: Array) -> String:
	for p in paths:
		if ResourceLoader.exists(p):
			return p
	return ""

func play_menu() -> void:
	var path = _first_existing_path(PATHS_MENU)
	if path.is_empty():
		path = _first_existing_path(PATHS_FALLBACK)
	_play_path(path)

func play_battle() -> void:
	var path = _first_existing_path(PATHS_BATTLE)
	if path.is_empty():
		path = _first_existing_path(PATHS_FALLBACK)
	_play_path(path)

func stop() -> void:
	_player.stop()
	_current_path = ""

func set_volume_db(db: float) -> void:
	_player.volume_db = db
