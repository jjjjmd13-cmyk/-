extends Node
## Automated play-test: a bot plays full runs with every hero and reports
## errors, progress and balance numbers. Not included in exports.
##   godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- [hero] [max_minutes]

const MainScene := preload("res://scenes/main.tscn")

var _main: Node
var _heroes: Array = []
var _hero_idx := 0
var _max_time := 900.0
var _world: Node
var _frame := 0
var _results: Array = []
var _phase := "boot"
var _wait := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	_heroes = ["rogue", "mage", "ranger", "knight"]
	if args.size() > 0 and args[0] != "all":
		_heroes = [args[0]]
	if args.size() > 1:
		_max_time = float(args[1]) * 60.0
	Game.settings.damage_numbers = true
	_main = MainScene.instantiate()
	add_child(_main)


func _process(_delta: float) -> void:
	_frame += 1
	match _phase:
		"boot":
			_wait += 1
			if _wait > 30:
				_start_next()
		"run":
			_drive()


func _start_next() -> void:
	if _hero_idx >= _heroes.size():
		print("=== RESULTS ===")
		for r in _results:
			print(r)
		get_tree().quit()
		return
	Game.selected_hero = _heroes[_hero_idx]
	_hero_idx += 1
	_main.start_run()
	_world = _main._current
	_phase = "run"
	print("--- run: ", Game.selected_hero)


func _drive() -> void:
	if not is_instance_valid(_world):
		return
	var p: Node = _world.player
	# Finished?
	if _world._ended or _world.run_time > _max_time:
		var rec := "%s: %s wave=%d level=%d kills=%d time=%.0fs hp=%.0f/%.0f upgrades=%s" % [
			p.hero_id, "WIN" if (_world._ended and not p.dead) else ("DEAD" if p.dead else "TIMEOUT"),
			_world.wave, p.level, _world.kills, _world.run_time, p.hp, p.max_hp, str(p.upgrades)]
		print(rec)
		_results.append(rec)
		_release_all()
		_phase = "boot"
		_wait = 0
		# Exercise the end screen -> menu path as a player would.
		_main._on_exit("menu")
		return
	# Level-up menu: pick the first card once it unlocks.
	var modal = _world._modal
	if modal != null and modal.has_method("_pick"):
		if not modal._buttons.is_empty() and not modal._buttons[0].disabled:
			modal._pick(modal._ids[_frame % modal._ids.size()])
		return
	if p.dead:
		_release_all()
		return
	p._using_pad = true
	# Kite: move away from the local crowd, orbit around the arena centre.
	var away := Vector2.ZERO
	for e in _world.enemies_in_radius(p.global_position, 360.0):
		var d: Vector2 = p.global_position - e.global_position
		away += d.normalized() * (360.0 - d.length()) / 360.0
	var orbit: Vector2 = (-p.global_position).orthogonal().normalized() * 0.6 + (-p.global_position) * 0.0006
	var dir := (away * 1.4 + orbit)
	if p.data.attack_kind == "melee" and away.length() < 1.6:
		var target: Node2D = _world.nearest_enemy(p.global_position, 900.0)
		if target and target.global_position.distance_to(p.global_position) > 70.0:
			dir = (target.global_position - p.global_position).normalized() + away
	for pick in _world.get_tree().get_nodes_in_group("pickups"):
		var to: Vector2 = pick.global_position - p.global_position
		if to.length() < 400.0:
			dir += to.normalized() * 0.5
			break
	_set_move(dir.normalized() if dir.length() > 0.05 else Vector2.ZERO)
	Input.action_press("attack")
	if p.skill_timer <= 0.0 and _world.enemies.size() > 3:
		_tap("skill")
	if p.dash_timer <= 0.0 and away.length() > 1.5:
		_tap("dash")
	if _frame % 600 == 0:
		print("  t=%.0f wave=%d lvl=%d hp=%.0f/%.0f enemies=%d kills=%d fps=%d nodes=%d" % [
			_world.run_time, _world.wave, p.level, p.hp, p.max_hp, _world.enemies.size(), _world.kills,
			Engine.get_frames_per_second(), get_tree().get_node_count()])


func _set_move(v: Vector2) -> void:
	for pair in [["move_left", -v.x], ["move_right", v.x], ["move_up", -v.y], ["move_down", v.y]]:
		if pair[1] > 0.0:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


func _tap(action: String) -> void:
	Input.action_press(action)
	get_tree().create_timer(0.05, true, false, true).timeout.connect(func() -> void: Input.action_release(action))


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "attack", "skill", "dash"]:
		Input.action_release(a)
