extends Node
## Regression checks for the 2026-10-24 playtest report. Prints "PLAYTEST FIXES OK".
##   godot --headless --fixed-fps 60 res://tests/playtest_fixes.tscn
const Main := preload("res://scenes/main.tscn")
const UPGRADES := preload("res://scripts/data/upgrades.gd")
var main: Node
var failed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = Main.instantiate()
	add_child(main)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func check(cond: bool, what: String) -> void:
	if not cond:
		failed = true
		push_error("PLAYTEST FIX FAILED: " + what)

func _start(hero: String) -> Node:
	Game.selected_hero = hero
	main.start_run()
	await frames(5)
	var w: Node = main._current
	w._state_t = 999
	return w

func _run() -> void:
	await frames(4)
	# Level-up always offers three cards, even with every upgrade maxed.
	var taken := {}
	for u in UPGRADES.POOL:
		taken[u.id] = UPGRADES.max_of(u)
	check(UPGRADES.roll("knight", taken, 3, RandomNumberGenerator.new()).size() == 3, "three fallback cards")

	# Thousand Cuts with nobody around keeps its cooldown.
	var w: Node = await _start("rogue")
	for e in w.enemies.duplicate():
		e.die()
	await frames(2)
	w.player.timers.ult = 0.0
	w.player._use_skill("ult")
	check(w.player.timers.ult == 0.0, "rogue ult refused without targets")

	# Summons stop at the enemy cap.
	for i in w.MAX_ENEMIES + 10:
		if not w.has_room_for_enemy():
			break
		var e: Node = w.spawn_enemy_at("ghoul", w.player.position + Vector2(900, 0))
		e.set_physics_process(false)
	check(w.enemies.size() <= w.MAX_ENEMIES + 1, "cap reached")
	var before: int = w.enemies.size()
	var boss: Node = w.spawn_enemy_at("dread_knight", w.player.position + Vector2(0, -600))
	boss._summon("ghoul", 6)
	check(w.enemies.size() == before + 1, "boss summons respect the cap")
	main._on_exit("menu")
	await frames(4)

	# Winning: no damage and no level-up window before the victory screen.
	w = await _start("knight")
	w.pending_levels = 0
	w.drop_xp(w.player.position, 500)
	w._win()
	await frames(2)
	check(w.player.take_damage(9999.0, null) == false, "hero invincible after the final boss")
	await frames(200)
	check(w._ended and w._modal != null and w._modal.get_script() == w.EndScreen, "victory screen, not a level-up window")
	check(not w.player.dead, "hero alive at victory")
	main._on_exit("menu")
	await frames(4)
	print("PLAYTEST FIXES OK" if not failed else "PLAYTEST FIXES FAILED")
	Game.quit_game()
