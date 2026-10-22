extends Node
## Sound effect pool and music player with crossfading.

const SFX_NAMES := [
	"swing", "swing_heavy", "hit", "crit", "arrow", "magic", "explosion", "hurt",
	"pickup", "levelup", "dash", "enemy_die", "boss_roar", "enemy_shot", "ui_move",
	"ui_click", "roar", "knives", "wave_horn", "victory", "defeat",
]
const MUSIC := {
	"menu": "res://assets/audio/music_menu.wav",
	"battle": "res://assets/audio/music_battle.wav",
	"boss": "res://assets/audio/music_boss.wav",
}
const POOL_SIZE := 24
## Minimum seconds between two plays of the same effect, to avoid ear-splitting stacking.
const MIN_GAP := 0.045

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music := ""
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in SFX_NAMES:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
		else:
			push_warning("Missing sound: " + path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	# WAV files are not flagged as looping, so restart them manually.
	p.finished.connect(func() -> void:
		if p.stream and p.volume_db > -79.0:
			p.play())
	return p


func play(sfx_name: String, volume_db: float = 0.0, pitch_var: float = 0.08) -> void:
	if not _streams.has(sfx_name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sfx_name, -1.0)) < MIN_GAP:
		return
	_last_played[sfx_name] = now
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[sfx_name]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func play_music(track: String, fade: float = 1.0) -> void:
	if track == _current_music or not MUSIC.has(track):
		return
	_current_music = track
	var incoming := _music_b if _music_a.playing and _music_a.volume_db > -79.0 else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	incoming.stream = load(MUSIC[track])
	incoming.volume_db = -40.0
	incoming.play()
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", 0.0, fade)
	_music_tween.tween_property(outgoing, "volume_db", -80.0, fade)
	_music_tween.chain().tween_callback(outgoing.stop)


func stop_music(fade: float = 1.0) -> void:
	_current_music = ""
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	for p in [_music_a, _music_b]:
		_music_tween.tween_property(p, "volume_db", -80.0, fade)
	_music_tween.chain().tween_callback(func() -> void:
		_music_a.stop()
		_music_b.stop())
