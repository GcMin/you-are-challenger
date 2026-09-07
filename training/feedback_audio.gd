class_name FeedbackAudio
extends Node

var hit: AudioStreamWAV
var swing: AudioStreamWAV
var hurt: AudioStreamWAV
var players: Array[AudioStreamPlayer] = []
var cursor: int = 0

func _ready() -> void:
	hit = _tone(110.0, 0.12, true)
	swing = _tone(320.0, 0.10, true)
	hurt = _tone(72.0, 0.20, false)
	for i: int in range(4):
		var audio := AudioStreamPlayer.new()
		audio.volume_db = -15.0
		add_child(audio)
		players.append(audio)

func play(kind: StringName) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var audio: AudioStreamPlayer = players[cursor]
	cursor = (cursor + 1) % players.size()
	audio.stream = hit if kind == &"hit" else hurt if kind == &"hurt" else swing
	audio.play()

func _exit_tree() -> void:
	for audio: AudioStreamPlayer in players:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null

func _tone(frequency: float, duration: float, noise: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples: int = int(duration * stream.mix_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	for i: int in range(samples):
		var t: float = float(i) / stream.mix_rate
		var envelope: float = pow(1.0 - float(i) / samples, 2.0)
		var wave: float = sin(TAU * frequency * t) * 0.6 + (rng.randf_range(-0.4, 0.4) if noise else 0.0)
		data.encode_s16(i * 2, int(wave * envelope * 15000.0))
	stream.data = data
	return stream
