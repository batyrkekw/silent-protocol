extends Node
## Original generated assets. Live events only: replay scrubbing never replays sounds.
const ROOT = "res://assets/audio/"
var music: AudioStreamPlayer
var hum: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var music_enabled = true
var effects_enabled = true
var volume = 0.65
var enabled = false
var last_tick = -1
var event_cursor = 0
var last_lasers = true
var last_hack_tick = -100
var last_event_kind = ""

func _ready() -> void:
	music = _player()
	hum = _player()
	for i in 8:
		pool.append(_player())
	for key in ["museum_night", "laser_hum", "laser_on", "laser_off", "hack", "signal", "diamond", "noise", "alarm", "success"]:
		clips[key] = load(ROOT + key + ".wav")
	for key in ["museum_night", "laser_hum"]:
		var stream: AudioStreamWAV = clips[key]
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / (4 if stream.stereo else 2)
	music.stream = clips.museum_night
	hum.stream = clips.laser_hum

func _player() -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	add_child(p)
	return p

func activate() -> void:
	enabled = DisplayServer.get_name() != "headless"
	if enabled and not music.playing:
		music.play()
		music.volume_db = -24

func reset_history() -> void:
	last_tick = -1
	event_cursor = 0
	last_lasers = true
	last_hack_tick = -100
	for p in pool:
		p.stop()

func play_effect(key: String) -> void:
	last_event_kind = key
	if not enabled or not effects_enabled:
		return
	for p in pool:
		if not p.playing:
			p.stream = clips[key]
			p.volume_db = linear_to_db(maxf(volume, 0.001)) - 7
			p.play()
			return

func update_audio(sim, paused: bool, replaying: bool, delta: float) -> void:
	if sim.tick < last_tick:
		reset_history()
	last_tick = sim.tick
	var live = sim.outcome == "running" and not paused and not replaying
	if replaying or paused or not effects_enabled:
		for p in pool:
			p.stop()
	if live:
		if sim.lasers_active() != last_lasers:
			play_effect("laser_on" if sim.lasers_active() else "laser_off")
		var hacking = false
		for r in sim.robots:
			if r.pc < sim.plans[r.id].size() and sim.plans[r.id][r.pc].type == "interact" and r.elapsed > 0 and r.status.begins_with("Взлом"):
				hacking = true
		if hacking and sim.tick - last_hack_tick >= 9:
			last_hack_tick = sim.tick
			play_effect("hack")
	last_lasers = sim.lasers_active()
	while event_cursor < sim.events.size():
		var event = sim.events[event_cursor]
		event_cursor += 1
		if replaying or paused:
			continue
		var key = {"signal": "signal", "take": "diamond", "noise": "noise", "won": "success", "lost": "alarm"}.get(event.kind, "")
		if not key.is_empty():
			play_effect(key)
	if not enabled:
		return
	var music_target = linear_to_db(maxf(volume, 0.001)) - (13 if live else 17)
	music.volume_db = lerpf(music.volume_db, music_target if music_enabled else -70.0, minf(1, delta * 5))
	var near_laser = false
	for r in sim.robots:
		for cell in sim.laser_cells:
			if r.pos.distance_to(cell) < 5:
				near_laser = true
	var humming = live and effects_enabled and sim.lasers_active() and near_laser
	if humming and not hum.playing:
		hum.play()
		hum.volume_db = -60
	hum.volume_db = lerpf(hum.volume_db, linear_to_db(maxf(volume, 0.001)) - 15 if humming else -70.0, minf(1, delta * 8))
	if not humming and hum.volume_db < -65:
		hum.stop()
