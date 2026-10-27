extends Node
## Procedural audio: every sound effect and music loop is synthesized at runtime,
## so the project ships with no audio files.
##   Sfx.play("explode")          one-shot effect (see SOUNDS for names)
##   Sfx.play_music("castle")     "menu" | "castle" | "dungeon" | "" (stop)

const RATE := 22050
const POOL_SIZE := 16

## name -> [wave, f_start, f_end, duration, volume, noise_mix, vibrato]
const SOUNDS := {
	"shoot": ["square", 880.0, 220.0, 0.09, 0.35, 0.2, 0.0],
	"shoot_big": ["saw", 300.0, 60.0, 0.22, 0.45, 0.4, 0.0],
	"zap": ["square", 1400.0, 600.0, 0.12, 0.3, 0.0, 30.0],
	"explode": ["noise", 200.0, 40.0, 0.4, 0.55, 1.0, 0.0],
	"explode_small": ["noise", 400.0, 80.0, 0.18, 0.4, 1.0, 0.0],
	"hit": ["square", 300.0, 120.0, 0.07, 0.4, 0.5, 0.0],
	"enemy_die": ["saw", 500.0, 80.0, 0.2, 0.4, 0.3, 0.0],
	"coin": ["square", 988.0, 1318.0, 0.1, 0.25, 0.0, 0.0],
	"key": ["triangle", 660.0, 1760.0, 0.25, 0.4, 0.0, 12.0],
	"jump": ["square", 260.0, 520.0, 0.12, 0.3, 0.0, 0.0],
	"flap": ["triangle", 200.0, 380.0, 0.1, 0.35, 0.3, 0.0],
	"dash": ["noise", 900.0, 200.0, 0.2, 0.4, 0.7, 0.0],
	"slam": ["noise", 150.0, 30.0, 0.35, 0.6, 0.9, 0.0],
	"hurt": ["saw", 220.0, 80.0, 0.3, 0.5, 0.4, 20.0],
	"die": ["saw", 400.0, 40.0, 0.9, 0.5, 0.3, 8.0],
	"arrow": ["noise", 2500.0, 1200.0, 0.08, 0.2, 1.0, 0.0],
	"bomb": ["triangle", 180.0, 90.0, 0.15, 0.4, 0.2, 0.0],
	"magic": ["sine", 600.0, 1200.0, 0.3, 0.3, 0.0, 25.0],
	"ice": ["sine", 1600.0, 900.0, 0.25, 0.3, 0.2, 40.0],
	"block": ["square", 1200.0, 1100.0, 0.06, 0.3, 0.3, 0.0],
	"slowmo_in": ["sine", 500.0, 150.0, 0.35, 0.35, 0.0, 0.0],
	"slowmo_out": ["sine", 150.0, 500.0, 0.25, 0.3, 0.0, 0.0],
	"chest": ["triangle", 523.0, 1046.0, 0.5, 0.45, 0.0, 6.0],
	"levelup": ["square", 523.0, 1568.0, 0.6, 0.35, 0.0, 10.0],
	"achievement": ["triangle", 784.0, 1568.0, 0.5, 0.4, 0.0, 14.0],
	"ui_click": ["square", 700.0, 700.0, 0.04, 0.25, 0.0, 0.0],
	"ui_hover": ["sine", 900.0, 900.0, 0.025, 0.15, 0.0, 0.0],
	"buy": ["square", 660.0, 1320.0, 0.25, 0.35, 0.0, 0.0],
	"error": ["square", 160.0, 120.0, 0.2, 0.35, 0.0, 0.0],
	"door": ["noise", 120.0, 60.0, 0.5, 0.5, 0.6, 0.0],
	"win": ["triangle", 392.0, 1568.0, 0.9, 0.45, 0.0, 6.0],
}

var _streams := {}
var _music_cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus("Music")
	_make_bus("SFX")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	for sound_name in SOUNDS.keys():
		_streams[sound_name] = _synth(SOUNDS[sound_name])
	apply_settings()


func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")


func apply_settings() -> void:
	var muted: bool = Game.get_setting("muted")
	_set_bus("Master", Game.get_setting("master"), muted)
	_set_bus("Music", Game.get_setting("music"), muted)
	_set_bus("SFX", Game.get_setting("sfx"), muted)


func _set_bus(bus_name: String, linear: float, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, muted or linear <= 0.001)


func play(sound_name: String, pitch_jitter := 0.08, volume_db := 0.0) -> void:
	if not _streams.has(sound_name):
		push_warning("Unknown sound: " + sound_name)
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[sound_name]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


func play_music(track: String) -> void:
	if track == _music_name:
		return
	_music_name = track
	if track == "":
		_music.stop()
		return
	if not _music_cache.has(track):
		_music_cache[track] = _compose(track)
	_music.stream = _music_cache[track]
	_music.play()


# ---------------------------------------------------------------- synthesis

func _wave(kind: String, phase: float) -> float:
	match kind:
		"square": return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"saw": return 2.0 * fmod(phase, 1.0) - 1.0
		"triangle": return 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0
		"noise": return randf_range(-1.0, 1.0)
	return sin(phase * TAU)


func _synth(def: Array) -> AudioStreamWAV:
	var wave: String = def[0]
	var f0: float = def[1]
	var f1: float = def[2]
	var dur: float = def[3]
	var vol: float = def[4]
	var noise_mix: float = def[5]
	var vib: float = def[6]
	var n := int(dur * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	var held := 0.0
	for i in n:
		var t := float(i) / n
		var freq := lerpf(f0, f1, t) + sin(t * dur * TAU * 18.0) * vib
		phase += freq / RATE
		var s: float
		if wave == "noise":
			# Sample-and-hold noise pitched by freq gives "crunchy" explosions.
			if fmod(phase, 1.0) < freq / RATE:
				held = randf_range(-1.0, 1.0)
			s = held
		else:
			s = lerpf(_wave(wave, phase), randf_range(-1.0, 1.0), noise_mix)
		var env := minf(1.0, t * 40.0) * pow(1.0 - t, 1.6)
		bytes.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32000.0))
	return _to_wav(bytes, false)


func _to_wav(bytes: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = bytes.size() / 2
	return w


## Tiny chiptune composer: bass + arpeggio + lead + drums over a chord loop.
func _compose(track: String) -> AudioStreamWAV:
	var bpm := 132.0
	var chords := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]  # Am F C G
	var lead_wave := "square"
	match track:
		"menu":
			bpm = 100.0
			chords = [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 49, 52]]  # Dm Bb C A
			lead_wave = "triangle"
		"dungeon":
			bpm = 120.0
			chords = [[52, 55, 59], [48, 52, 55], [50, 53, 57], [47, 51, 54]]  # Em C Dm B
			lead_wave = "saw"
	var beat := 60.0 / bpm
	var step := beat / 4.0  # 16th notes
	var steps := 16 * chords.size() * 2
	var n := int(steps * step * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(track)
	var melody := []
	for i in steps / 2:
		melody.append(rng.randi_range(0, 4) if rng.randf() < 0.55 else -1)
	for s in steps:
		var chord: Array = chords[(s / 16) % chords.size()]
		var start := int(s * step * RATE)
		var len_samples := int(step * RATE)
		# Bass on 8ths
		if s % 2 == 0:
			_add_note(buf, start, len_samples * 2, _midi(chord[0] - 12), "triangle", 0.28)
		# Arpeggio
		_add_note(buf, start, len_samples, _midi(chord[s % 3] + 12), "square", 0.07)
		# Lead every 8th note, repeating twice per loop
		if s % 2 == 0:
			var m: int = melody[(s / 2) % melody.size()]
			if m >= 0:
				var scale := [0, 2, 3, 5, 7]
				_add_note(buf, start, len_samples * 2, _midi(chord[0] + 12 + scale[m]), lead_wave, 0.09)
		# Drums
		if s % 8 == 0:
			_add_drum(buf, start, 0.12, 90.0, 0.5)
		elif s % 8 == 4:
			_add_drum(buf, start, 0.1, 0.0, 0.25)
		elif s % 2 == 0:
			_add_drum(buf, start, 0.03, 0.0, 0.08)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	return _to_wav(bytes, true)


func _midi(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


func _add_note(buf: PackedFloat32Array, start: int, length: int, freq: float, wave: String, vol: float) -> void:
	var phase := 0.0
	var end := mini(start + length, buf.size())
	for i in range(start, end):
		var t := float(i - start) / length
		phase += freq / RATE
		buf[i] += _wave(wave, phase) * vol * minf(1.0, t * 30.0) * (1.0 - t)


func _add_drum(buf: PackedFloat32Array, start: int, dur: float, tone: float, vol: float) -> void:
	var length := int(dur * RATE)
	var end := mini(start + length, buf.size())
	var phase := 0.0
	for i in range(start, end):
		var t := float(i - start) / length
		var s := randf_range(-1.0, 1.0)
		if tone > 0.0:
			phase += lerpf(tone * 2.0, tone * 0.5, t) / RATE
			s = lerpf(sin(phase * TAU), s, 0.25)
		buf[i] += s * vol * pow(1.0 - t, 2.0)
