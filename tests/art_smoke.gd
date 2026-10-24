extends Node
## Exercises real gameplay consumers, all skill slots, both facings and elites.
## Optional screenshots: -- /absolute/output/directory (requires a display).
const Main := preload("res://scenes/main.tscn")
const Sprites := preload("res://scripts/game/sprite_set.gd")
var main: Node
var output := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_user_args().size() > 0:
		output = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(output)
	main = Main.instantiate()
	add_child(main)
	_run()

func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func shot(label: String) -> void:
	if output.is_empty():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(label + ".png"))

func _run() -> void:
	await frames(5)
	for hero in ["knight", "ranger", "mage", "rogue"]:
		Game.selected_hero = hero
		main.start_run()
		await frames(5)
		var world: Node = main._current
		var player: Node = world.player
		player.level = 200
		player._invuln = 30.0
		player._using_pad = true
		assert(player._visual.has_sprite(), "Hero is still using fallback art: " + hero)
		for action in ["idle", "run", "attack"]:
			var expected := 10 if hero == "knight" and action != "idle" else 4
			assert(player._visual._sprite.sprite_frames.get_frame_count(action) == expected)
		for side in [-1, 1]:
			player.aim_dir = Vector2(side, 0)
			player._visual.facing = side
			player._attack()
			player._start_dash(Vector2(side, 0))
			await frames(20)
		player.set_physics_process(false)
		player._visual.invuln_blink = false
		player._visual.dashing = false
		player._visual.attack_t = -1.0
		player._visual.moving = false
		await frames(4)
		await shot(hero + "_idle")
		player.set_physics_process(true)
		for i in 10:
			var kind: String = ["ghoul", "bat", "archer", "brute", "cultist", "wraith", "bomber", "shield", "necro", "skeleton"][i]
			var enemy: Node = world.spawn_enemy_at(kind, player.position + Vector2.from_angle(i * TAU / 10.0) * 240.0, i % 2 == 0)
			assert(enemy._visual.sprite != null, "Missing monster art: " + kind)
		for slot in ["skill", "skill2", "ult"]:
			player._use_skill(slot)
			await frames(15)
		player.set_physics_process(false)
		player._visual.invuln_blink = false
		await frames(2)
		await shot(hero + "_skills")
		player.set_physics_process(true)
		await frames(210)
		player._rogue_skill2() if hero == "rogue" else player._start_dash(Vector2.LEFT)
		await frames(2)
		if hero == "rogue":
			assert(is_equal_approx(player._visual.stealth_alpha, 0.45), "Stealth alpha was overwritten")
		main._on_exit("menu")
		await frames(5)
	for id in ["dread_knight", "blood_witch", "void_lord"]:
		var sprite := Sprites.make_sprite("bosses", id)
		assert(sprite != null, "Missing boss art: " + id)
		sprite.free()
	Game.selected_hero = "knight"
	main.start_run()
	await frames(5)
	var w: Node = main._current
	w.player.level = 200
	w.player._invuln = 60.0
	for wave in [5, 10, 15]:
		w._start_wave(wave)
		await frames(40)
		assert(is_instance_valid(w.boss) and w.boss._visual.sprite != null)
		w.boss.hp = w.boss.max_hp * 0.2
		await frames(180)
		await shot("boss_wave_" + str(wave))
		w.boss.die()
		await frames(10)
	main._on_exit("menu")
	await frames(10)
	print("ART SMOKE OK: 4 heroes, 12 skills, 10 enemy kinds, elites, 3 bosses")
	Game.quit_game()
