extends Node
## Captures frame sequences of each hero running and attacking, for checking
## animation feel. Needs a display (xvfb-run):
##   godot --rendering-driver opengl3 --fixed-fps 60 res://tests/motion_preview.tscn -- <out_dir> [hero]
const Main := preload("res://scenes/main.tscn")
var main: Node
var output := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	output = args[0] if args.size() else "user://motion"
	var heroes := [args[1]] if args.size() > 1 else ["knight", "ranger", "mage", "rogue"]
	DirAccess.make_dir_recursive_absolute(output)
	Game.settings.screen_shake = false
	Game.settings.auto_attack = false
	main = Main.instantiate()
	add_child(main)
	_run(heroes)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func grab(w: Node, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	# The camera follows the hero, so the hero is near the middle of the screen.
	var c := img.get_size() / 2
	var rect := Rect2i(c.x - img.get_width() / 5, c.y - img.get_height() / 4, img.get_width() * 2 / 5, img.get_height() / 3)
	img.get_region(rect).save_png(output.path_join(name + ".png"))

func _run(heroes: Array) -> void:
	await frames(4)
	for hero in heroes:
		seed(7)
		Game.selected_hero = hero
		main.start_run()
		await frames(5)
		var w: Node = main._current
		w._state_t = 999
		w.player._using_pad = true
		w._hud._canvas.banner_t = 99
		for c in w._entities.get_children():
			if c != w.player:
				c.queue_free()
		Input.action_press("move_right")
		await frames(20)
		for i in 8:
			await grab(w, "%s_run_%d" % [hero, i])
			await frames(3)
		Input.action_release("move_right")
		for i in 5:
			var e: Node = w.spawn_enemy_at("brute", w.player.position + Vector2(140 + i * 30, -20 + i * 15), false)
			e.hp = 100000
			e.max_hp = e.hp
			e.set_physics_process(false)
		await frames(10)
		Input.action_press("attack")
		for i in 12:
			await grab(w, "%s_attack_%02d" % [hero, i])
			await frames(2)
		Input.action_release("attack")
		main._on_exit("menu")
		await frames(4)
	print("MOTION PREVIEW OK")
	Game.quit_game()
