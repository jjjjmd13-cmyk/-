extends Node
## Captures screenshots of every screen (menus, each hero in combat, boss, overlays).
## Needs a real display (or Xvfb):
##   godot --fixed-fps 60 --resolution 1920x1080 res://tests/screenshot.tscn -- <output_dir>

const MainScene := preload("res://scenes/main.tscn")

var _out := "user://screenshots"
var _main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_main = MainScene.instantiate()
	add_child(_main)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("saved ", name)


func _run() -> void:
	await _frames(90)
	await _shot("01_main_menu")
	var menu: Node = _main._current
	menu._open_text(Game.t("credits_title"), Game.t("credits_body") + menu._license_text(), true)
	await _frames(20)
	await _shot("01b_credits")
	menu._popup.queue_free()
	menu._on_popup_closed()
	_main.show_select()
	await _frames(40)
	await _shot("02_hero_select")

	var i := 3
	for hero in ["rogue", "mage", "ranger", "knight"]:
		Game.selected_hero = hero
		_main.start_run()
		await _frames(5)
		var w: Node = _main._current
		w._start_wave(4)
		var p: Node = w.player
		for k in 14:
			w.spawn_enemy_at(["ghoul", "bat", "archer", "brute", "cultist"][k % 5],
				p.global_position + Vector2.from_angle(TAU * k / 14.0) * randf_range(260, 420))
		Input.action_press("attack")
		await _frames(150)
		if hero == "mage" or hero == "knight":
			Input.action_press("skill")
			await _frames(12)
			Input.action_release("skill")
		await _frames(10)
		await _shot("%02d_combat_%s" % [i, hero])
		Input.action_release("attack")
		i += 1

	# Boss, level-up, pause and result screens on the last run.
	var w: Node = _main._current
	w._start_wave(5)
	await _frames(200)
	await _shot("%02d_boss" % i)
	i += 1
	w.pending_levels = 1
	w._open_levelup()
	await _frames(40)
	await _shot("%02d_levelup" % i)
	i += 1
	w._modal._pick(w._modal._ids[0])
	await _frames(5)
	w.open_pause()
	await _frames(20)
	await _shot("%02d_pause" % i)
	i += 1
	w._close_modal()
	w._finish(true)
	await _frames(90)
	await _shot("%02d_victory" % i)
	Game.quit_game()
