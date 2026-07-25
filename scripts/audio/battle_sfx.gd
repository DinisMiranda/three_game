extends Node
## Lightweight procedural combat SFX until dedicated audio assets exist.

var _player: AudioStreamPlayer
var _streams: Dictionary = {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	add_child(_player)
	_streams["hit"] = _make_tone(440.0, 0.07, 0.22)
	_streams["crit"] = _make_tone(660.0, 0.11, 0.28)
	_streams["miss"] = _make_tone(180.0, 0.09, 0.16)
	_streams["absorb"] = _make_tone(320.0, 0.12, 0.2)
	_streams["bark"] = _make_tone(520.0, 0.04, 0.08)


func play_hit() -> void:
	_play("hit")


func play_crit() -> void:
	_play("crit")


func play_miss() -> void:
	_play("miss")


func play_absorb() -> void:
	_play("absorb")


func play_bark() -> void:
	_play("bark")


func _play(kind: String) -> void:
	if _player == null:
		return
	var stream: AudioStream = _streams.get(kind, null)
	if stream == null:
		return
	_player.stream = stream
	_player.play()


func _make_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_hz := 22050
	var sample_count := int(sample_hz * duration)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = sample_hz
	audio.stereo = false
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in sample_count:
		var t := float(i) / float(sample_hz)
		var envelope := exp(-t * 10.0)
		var sample := sin(TAU * freq * t) * envelope * volume
		data[i] = int(clamp(sample * 127.0 + 128.0, 0.0, 255.0))
	audio.data = data
	return audio
