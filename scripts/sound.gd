extends Node
## User-provided looping MP3 and locally synthesized sound effects.
const MUSIC = preload("res://assets/audio/puzzle_song.mp3")
const MUSIC_ID := "puzzle-song-v1"
const MUSIC_VOLUME := 0.30
const MERGE_NOTES := [392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 1046.5, 1174.66, 1318.51, 1567.98]
var enabled := true
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var music_enabled := true
var music_player: AudioStreamPlayer

func _ready() -> void:
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -15.0
		add_child(player)
		voices.append(player)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = linear_to_db(MUSIC_VOLUME)
	var stream := MUSIC.duplicate() as AudioStreamMP3
	stream.loop = true
	stream.loop_offset = 0.0
	music_player.stream = stream
	add_child(music_player)
	set_music(music_enabled)

func set_music(on: bool) -> void:
	music_enabled = on
	if not is_instance_valid(music_player):
		return
	if not on:
		music_player.stop()
		return
	if not music_player.playing:
		music_player.play()

func restore_music(config: ConfigFile) -> void:
	# The previous synthesized track defaulted to off. Enable this new track on
	# first upgrade, then respect the user's music switch on subsequent launches.
	var same_track := str(config.get_value("audio", "track", "")) == MUSIC_ID
	set_music(bool(config.get_value("game", "music", true)) if same_track else true)

func store_music(config: ConfigFile) -> void:
	config.set_value("audio", "track", MUSIC_ID)
	config.set_value("game", "music", music_enabled)

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
	play_tone(MERGE_NOTES[clampi(level, 0, MERGE_NOTES.size() - 1)], 0.26, 0.5)

func tap() -> void:
	play_tone(660.0, 0.08, 0.15)
