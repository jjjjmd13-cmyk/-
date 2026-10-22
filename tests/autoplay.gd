extends Node
## Automated play-test: a bot plays full runs with every hero and reports
## errors, progress and balance numbers. Not included in exports.
##   godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- [hero|all] [max_minutes] [normal|hard]

const MainScene := preload("res://scenes/main.tscn")
const FX := preload("res://scripts/game/fx.gd")
const EnemyProjectile := preload("res://scripts/game/enemy_projectile.gd")

var _main: Node
var _heroes: Array = []
var _hero_idx := 0
var _max_time := 900.0
var _world: Node
var _frame := 0
var _results: Array = []
var _phase := "boot"
var _wait := 0
var _last_wave := 0
var _wave_start := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	_heroes = ["rogue", "mage", "ranger", "knight"]
	if args.size() > 0 and args[0] != "all":
		_heroes = [args[0]]
	if args.size() > 1:
		_max_time = float(args[1]) * 60.0
	Game.difficulty = args[2] if args.size() > 2 else "normal"
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
		_phase = "done"
		Game.quit_game()
		return
	Game.selected_hero = _heroes[_hero_idx]
	_hero_idx += 1
	_main.start_run()
	_world = _main._current
	_phase = "run"
	_last_wave = 0
	_wave_start = 0.0
	print("--- run: ", Game.selected_hero)


func _drive() -> void:
	if not is_instance_valid(_world):
		return
	var p: Node = _world.player
	# Finished?
	if _world._ended or _world.run_time > _max_time:
		var dmg := {}
		for k in p.damage_log:
			dmg[k] = roundi(p.damage_log[k])
		var rec := "%s: %s wave=%d level=%d kills=%d time=%.0fs hp=%.0f/%.0f\n    upgrades=%s\n    damage_taken=%s" % [
			p.hero_id, "WIN" if (_world._ended and not p.dead) else ("DEAD" if p.dead else "TIMEOUT"),
			_world.wave, p.level, _world.kills, _world.run_time, p.hp, p.max_hp, str(p.upgrades), str(dmg)]
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
	var danger := _danger(p)
	if p.data.attack_kind == "melee":
		# Fight at the edge of the crowd: engage the nearest enemy, back off when swarmed.
		var crowd: int = _world.enemies_in_radius(p.global_position, 170.0).size()
		var target: Node2D = _world.nearest_enemy(p.global_position, 900.0)
		if target and crowd < 4 and p.hp > p.max_hp * 0.3:
			var to: Vector2 = target.global_position - p.global_position
			dir = to.normalized() * (1.0 if to.length() > p.data.melee_range * 0.7 else -0.3) + away * 0.5
	if _world.wave != _last_wave:
		print("  wave %d reached at t=%.0f (prev took %.0fs) lvl=%d hp=%.0f/%.0f" % [
			_world.wave, _world.run_time, _world.run_time - _wave_start, p.level, p.hp, p.max_hp])
		_last_wave = _world.wave
		_wave_start = _world.run_time
	# Dodging telegraphed attacks and projectiles overrides everything else.
	if danger.length() > 0.1:
		dir = danger.normalized() * 2.0 + dir * 0.3
		if danger.length() > 1.0 and p.dash_timer <= 0.0:
			_set_move(dir.normalized())
			_tap("dash")
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


func _danger(p: Node2D) -> Vector2:
	## Direction away from incoming telegraphs and projectiles, scaled by urgency.
	var out := Vector2.ZERO
	var pos := p.global_position
	for c in _world._ground.get_children():
		if c is FX.Telegraph:
			var d: Vector2 = pos - c.global_position
			if d.length() < c.radius + 40.0:
				out += d.normalized() * (1.0 + (c.radius + 40.0 - d.length()) / c.radius)
		elif c is FX.LineTelegraph:
			var local: Vector2 = (pos - c.global_position).rotated(-c.rotation)
			if local.x > -40.0 and local.x < c.length + 40.0 and absf(local.y) < c.width:
				var side := Vector2(0, 1.0 if local.y >= 0.0 else -1.0).rotated(c.rotation)
				out += side * 1.5
	for c in _world._top.get_children():
		if c is EnemyProjectile:
			var rel: Vector2 = pos + Vector2(0, -40) - c.global_position
			var v: Vector2 = c.velocity
			if rel.length() > 260.0 or v.dot(rel) <= 0.0:
				continue
			var perp := rel - v.normalized() * rel.dot(v.normalized())
			if perp.length() < 50.0:
				out += (perp.normalized() if perp.length() > 1.0 else v.orthogonal().normalized()) * 0.8
	return out


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
