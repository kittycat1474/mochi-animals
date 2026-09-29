extends Node
## Small, locally synthesized plucks. No downloads, microphone or network.
var enabled := true
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var music_enabled := false
var music_player: AudioStreamPlayer

func _ready() -> void:
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -15.0
		add_child(player)
		voices.append(player)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -27.0
	add_child(music_player)

func set_music(on: bool) -> void:
	music_enabled = on
	if not is_instance_valid(music_player):
		return
	if not on:
		music_player.stop()
		return
	if music_player.stream == null:
		var notes := [261.63, 329.63, 392.0, 523.25, 440.0, 392.0, 329.63, 293.66, 261.63, 329.63, 392.0, 440.0, 392.0, 329.63, 293.66, 196.0]
		var rate := 22050
		var beat := 0.65
		var count := int(notes.size() * beat * rate)
		var bytes := PackedByteArray()
		bytes.resize(count * 2)
		for i in count:
			var time := float(i) / rate
			var note_index := int(time / beat)
			var phase := fmod(time, beat)
			var frequency: float = notes[note_index]
			var envelope := minf(phase * 80.0, 1.0) * exp(-phase * 6.5)
			var sample := sin(TAU * frequency * phase) * envelope * 0.35
			bytes.encode_s16(i * 2, int(sample * 32767.0))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = rate
		stream.data = bytes
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
		music_player.stream = stream
	music_player.play()

func play_tone(frequency: float, duration: float = 0.17, strength: float = 0.45) -> void:
	if not enabled or voices.is_empty():
		return
	var sample_rate := 22050
	var count := int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / sample_rate
		var envelope := minf(t / 0.008, 1.0) * exp(-t * 21.0) * (1.0 - t / duration)
		var sample := (sin(TAU * frequency * t) + 0.24 * sin(TAU * frequency * 2.0 * t)) * envelope * strength
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	var player := voices[cursor % voices.size()]
	cursor += 1
	player.stream = stream
	player.play()

func drop() -> void:
	play_tone(260.0, 0.11, 0.32)

func merge(level: int) -> void:
	var scale := [392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 1046.5]
	play_tone(scale[level], 0.26, 0.5)

func tap() -> void:
	play_tone(660.0, 0.08, 0.15)
