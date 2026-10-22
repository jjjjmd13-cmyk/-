extends Node
## Same seeded crowded scene before/after; exercises real skills and warnings.
const Main := preload("res://scenes/main.tscn")
const FX := preload("res://scripts/game/fx.gd")
var main: Node
var output := ""
var verify := false
var original: Dictionary

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	output = args[0] if args.size() else "user://readability"
	verify = args.size() > 1 and args[1] == "verify"
	DirAccess.make_dir_recursive_absolute(output)
	original = Game.settings.duplicate(true)
	Game.settings.language = "ko"
	Game.settings.auto_attack = false
	Game.settings.screen_shake = false
	Game.settings.fullscreen = false
	main = Main.instantiate()
	add_child(main)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(label: String, w: Node) -> void:
	w.player.set_physics_process(false)
	w.player._visual.invuln_blink = false
	await frames(2)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		assert(image.save_png(output.path_join(label + ".png")) == OK)
		assert(image.save_jpg(output.path_join(label + ".jpg"), 0.9) == OK)
	print("READABILITY CAPTURE: ", label)

func _run() -> void:
	await frames(4)
	for hero in ["knight", "ranger", "mage", "rogue"]:
		seed(48217)
		Game.selected_hero = hero
		main.start_run()
		await frames(5)
		var w: Node = main._current
		w._state_t = 999
		w.player.level = 7
		w.player._invuln = 100
		w.player._using_pad = true
		w.player.timers.ult = 0
		w._hud._canvas.banner_t = 99
		# Replace random scenery to make the before/after layout identical.
		for c in w._entities.get_children():
			if c != w.player:
				c.queue_free()
		await frames(1)
		for i in 22:
			var at := Vector2.from_angle(i * 2.39996) * (105 + 13 * i)
			var e: Node = w.spawn_enemy_at(["ghoul", "archer", "shield", "brute", "wraith", "cultist", "skeleton"][i % 7], at, i % 8 == 0)
			e.hp = 100000
			e.max_hp = e.hp
			e.set_physics_process(false)
		await frames(8)
		await shot(hero + "_crowd", w)
		w.player.set_physics_process(true)
		for slot in ["skill", "skill2", "ult"]:
			w.player._use_skill(slot)
			await frames(4)
		await frames(9)
		var at: Vector2 = w.player.position
		var circle := FX.Telegraph.new()
		circle.position = at + Vector2(145, -15)
		circle.radius = 165
		circle.duration = 1.2
		var callbacks := [0]
		circle.on_done = func() -> void: callbacks[0] += 1
		w.add_ground_fx(circle)
		var line := FX.LineTelegraph.new()
		line.position = at + Vector2(-410, 125)
		line.length = 850
		line.width = 90
		line.rotation = -0.2
		line.duration = 1.2
		w.add_ground_fx(line)
		w.spawn_enemy_projectile(at + Vector2(-145, -70), Vector2(180, 0), 1, "arrow")
		var arrow: Node = w._top.get_child(w._top.get_child_count() - 1)
		arrow.set_process(false)
		await frames(24)
		await shot(hero + "_overlap", w)
		if verify:
			assert(circle.z_index > w._top.z_index and not circle.z_as_relative)
			assert(line.z_index == circle.z_index)
			assert(arrow.z_index > circle.z_index)
			assert(w.player._visual._sprite.material != null)
			assert(circle.radius == 165 and line.length == 850 and line.width == 90)
		assert(callbacks[0] == 0)
		await frames(55)
		assert(callbacks[0] == 1, "Danger callback must fire exactly once")
		main._on_exit("menu")
		await frames(4)
	Game.settings = original
	print("READABILITY OK: four heroes, overlapping skills, circular/line warnings, callback timing")
	Game.quit_game()
