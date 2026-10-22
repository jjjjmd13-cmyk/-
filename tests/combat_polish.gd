extends Node
## Real gameplay previews: four heroes x three separate abilities, idle HUD,
## a boss HUD, low HP, cooldowns, English, and a narrow window.
## godot --fixed-fps 60 res://tests/combat_polish.tscn -- /absolute/output
const Main := preload("res://scenes/main.tscn")
const ART := preload("res://scripts/game/combat_art.gd")
var main: Node
var output := ""
var original_settings: Dictionary

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	output = args[0] if args.size() else "user://combat-polish"
	DirAccess.make_dir_recursive_absolute(output)
	original_settings = Game.settings.duplicate(true)
	Game.settings.fullscreen = false
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	Game.settings.language = "ko"
	Game.settings.auto_attack = false
	Game.settings.screen_shake = false
	main = Main.instantiate()
	add_child(main)
	_run()

func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func shot(label: String, world: Node) -> void:
	world.player.set_physics_process(false)
	world.player._visual.invuln_blink = false
	await frames(2)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		assert(image.save_png(output.path_join(label + ".png")) == OK, "Failed to save " + label)
		assert(image.save_jpg(output.path_join(label + ".jpg"), 0.88) == OK)
	print("POLISH CAPTURE: ", label)

func prepare(hero: String) -> Node:
	Game.selected_hero = hero
	main.start_run()
	await frames(8)
	var w: Node = main._current
	w._state_t = 999.0
	w.player.level = 7
	w.player._invuln = 100
	w.player._using_pad = true
	w.player.hp = w.player.max_hp * 0.78
	w.player.xp = 24
	w._hud._canvas.banner_t = 99
	w.player.timers.ult = 0
	for i in 10:
		var at := Vector2.from_angle(i * TAU / 10) * 280
		var enemy: Node = w.spawn_enemy_at(["ghoul", "brute", "shield", "cultist", "skeleton"][i % 5], at, i == 2)
		enemy.max_hp = 100000
		enemy.hp = enemy.max_hp
		enemy.set_physics_process(false)
	return w

func _run() -> void:
	await frames(5)
	for hero in ["knight", "ranger", "mage", "rogue"]:
		for i in 4:
			assert(ART.icon(hero, i) != null)
			assert(ART.vfx(hero, i) != null)
		for slot in ["idle", "skill", "skill2", "ult"]:
			var w: Node = await prepare(hero)
			if slot != "idle":
				w.player.aim_dir = Vector2.RIGHT
				w.player._use_skill(slot)
				assert(w.player.timers[slot] > 0)
			var waits := {"idle": 16, "skill": 12, "skill2": 16, "ult": 23}
			if hero == "mage":
				waits = {"idle": 16, "skill": 20, "skill2": 20, "ult": 60}
			if hero == "rogue":
				waits.ult = 15
				waits.skill2 = 26
			await frames(waits[slot])
			await shot(hero + "_" + slot, w)
			main._on_exit("menu")
			await frames(4)
	var w: Node = await prepare("mage")
	w.player.hp = 18
	w.player.shield = 9
	w.player.timers = {"skill": 4.2, "skill2": 8.3, "ult": 37.0}
	w._start_wave(5)
	w._hud._canvas.banner_t = 99
	await frames(15)
	await shot("boss_low_hp", w)
	Game.settings.language = "en"
	await shot("english_hud", w)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await frames(8)
		assert(DisplayServer.window_get_size() == Vector2i(1280, 720))
		print("WINDOW SIZE: ", DisplayServer.window_get_size())
		await shot("hud_window_1280x720", w)
	main._on_exit("menu")
	await frames(4)
	Game.settings = original_settings
	print("COMBAT POLISH OK: 16 icons, 16 VFX cells, 12 skills, all HUD states")
	Game.quit_game()
