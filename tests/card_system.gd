extends Node
## Exercises every level-up card: skill branches, evolutions, boss rewards,
## reroll/banish and the level-up screen. Prints "CARD SYSTEM OK".
##   godot --headless --fixed-fps 60 res://tests/card_system.tscn [-- <screenshot_dir>]
const Main := preload("res://scenes/main.tscn")
const UPGRADES := preload("res://scripts/data/upgrades.gd")
var main: Node
var failed := false
var shots := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() else ""
	main = Main.instantiate()
	add_child(main)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func check(cond: bool, what: String) -> void:
	if not cond:
		failed = true
		push_error("CARD SYSTEM FAILED: " + what)

func _start(hero: String) -> Node:
	seed(11)
	Game.selected_hero = hero
	main.start_run()
	await frames(5)
	var w: Node = main._current
	w._state_t = 999
	w.player._invuln = 9999.0
	for i in 12:
		var e: Node = w.spawn_enemy_at("ghoul", w.player.position + Vector2.from_angle(i) * (120 + 15 * i))
		e.hp = 100000
		e.max_hp = 100000
	return w

func _use_all(w: Node) -> void:
	for slot in ["skill", "skill2", "ult"]:
		w.player.timers[slot] = 0.0
		w.player._use_skill(slot)
		await frames(20)
	w.player._start_dash(Vector2.RIGHT)
	for i in 8:
		w.player._attack()
		await frames(4)
	await frames(240)

func _shot(name: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))

func _run() -> void:
	await frames(4)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	# Exclusive branches close each other.
	var taken := {"knight_skill_a": 1}
	var avail: Array = UPGRADES.available("knight", taken, [], false).map(func(u): return u.id)
	check(not avail.has("knight_skill_b"), "branch B closed after A")
	check(not avail.has("rogue_skill_a"), "other heroes' branches hidden")
	# Evolutions need both cards maxed.
	check(not UPGRADES.available("knight", {"might": 5}, [], false).map(func(u): return u.id).has("evo_executioner"), "evo locked")
	check(UPGRADES.roll("knight", {"might": 5, "ferocity": 3}, 3, RandomNumberGenerator.new())[0].id == "evo_executioner", "ready evo offered first")
	# Boss rolls only offer boss cards.
	for u in UPGRADES.roll("mage", {}, 3, RandomNumberGenerator.new(), [], false, true):
		check(u.get("boss", false), "boss roll gives boss cards")
	# Every fifth level guarantees a rare-or-better card.
	var rng := RandomNumberGenerator.new()
	for i in 30:
		rng.seed = i
		var r := UPGRADES.roll("ranger", {}, 3, rng, [], true)
		check(r.any(func(u): return UPGRADES.rarity_of(u) != "common"), "rare guaranteed")
	check(UPGRADES.is_choice_level(2) and not UPGRADES.is_choice_level(3) and UPGRADES.is_choice_level(5), "choice levels")

	for hero in ["rogue", "mage", "ranger", "knight"]:
		for branch in ["a", "b"]:
			var w: Node = await _start(hero)
			for slot in ["skill", "skill2", "ult"]:
				w.player.apply_upgrade("%s_%s_%s" % [hero, slot, branch])
			await _use_all(w)
			check(not w.player.dead, "%s branch %s ran" % [hero, branch])
			main._on_exit("menu")
			await frames(4)
		# Evolutions and boss rewards that fit this hero.
		var w2: Node = await _start(hero)
		for u in UPGRADES.POOL:
			if u.has("needs") or u.get("boss", false):
				w2.player.apply_upgrade(u.id)
		w2.player.venom = 2
		w2.player.thorns = 1
		w2.player.shadowstep = 1
		w2.player.extra_projectiles = 1
		await _use_all(w2)
		check(w2.player.undying == 1, "undying stored")
		main._on_exit("menu")
		await frames(4)

	# Level-up screen: auto levels, reroll, banish and boss rewards.
	var w3: Node = await _start("mage")
	w3.player._invuln = 0.0
	var lv_before: int = w3.player.level
	w3.player.xp = w3.player.xp_to_next() - 1
	w3._spawn_pickup("xp", w3.player.global_position, 1)
	await frames(30)
	check(w3.player.level == lv_before + 1, "levelled up")
	check(w3._modal != null, "level 2 asks for a card")
	await frames(30)
	await _shot("levelup")
	var menu: Node = w3._modal
	var first: Array = menu._ids.duplicate()
	menu._reroll()
	await frames(2)
	check(w3.rerolls_left == 2 and menu._ids != first, "reroll deals new cards")
	menu._toggle_banish()
	var gone: String = menu._ids[1]
	menu._banish(1)
	await frames(2)
	check(w3.banned.has(gone) and w3.banishes_left == 1 and not menu._ids.has(gone), "banish")
	menu._pick(menu._ids[0])
	await frames(10)
	check(w3._modal == null, "card taken")
	w3.pending_boss_rewards = 1
	w3._open_levelup()
	await frames(40)
	await _shot("boss_reward")
	check(w3._modal != null and w3._modal.mode == "boss" and w3._modal._tools == null, "boss reward screen")
	w3._modal._pick(w3._modal._ids[0])
	await frames(10)
	check(w3.pending_boss_rewards == 0 and w3._modal == null, "boss reward taken")
	# A level without a choice applies a small boost instead.
	w3.player.level = 2
	w3.player.xp = w3.player.xp_to_next() - 1
	w3._spawn_pickup("xp", w3.player.global_position, 1)
	await frames(30)
	check(w3.player.level == 3 and w3._modal == null and not w3.player.minor_ups.is_empty(), "level 3 auto boost")
	main._on_exit("menu")
	await frames(4)
	print("CARD SYSTEM OK" if not failed else "CARD SYSTEM FAILED")
	Game.quit_game()
