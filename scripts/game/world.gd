extends Node2D
## A single run: arena, wave director, combat resolution and overlays.

signal exit_requested(target: String)

const Player := preload("res://scripts/game/player.gd")
const Enemy := preload("res://scripts/game/enemy.gd")
const Boss := preload("res://scripts/game/boss.gd")
const Projectile := preload("res://scripts/game/projectile.gd")
const EnemyProjectile := preload("res://scripts/game/enemy_projectile.gd")
const Pickup := preload("res://scripts/game/pickup.gd")
const FX := preload("res://scripts/game/fx.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const LevelUpMenu := preload("res://scripts/ui/levelup_menu.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const EndScreen := preload("res://scripts/ui/end_screen.gd")

const TOTAL_WAVES := 15
## A boss appears every BOSS_EVERY waves (5, 10, 15, then 20, 25... in endless mode).
const BOSS_EVERY := 5
const ARENA := Rect2(-1700, -1300, 3400, 2600)
const MAX_ENEMIES := 170
const MAX_PICKUPS := 260

var arena_rect := ARENA.grow(200)
var player: Node2D
var enemies: Array = []
var boss: Node2D
var wave := 0
var wave_time := 0.0
var wave_duration := 40.0
var state := "intermission"
var run_time := 0.0
var kills := 0
var vacuum := false
## True after the player chose to keep going past the final wave.
var endless := false
var pending_levels := 0
var rng := RandomNumberGenerator.new()

var _state_t := 2.0
var _spawn_t := 0.0
var _shake := 0.0
var _camera: Camera2D
var _ground: Node2D
var _entities: Node2D
var _top: Node2D
var _hud: CanvasLayer
var _overlay: CanvasLayer
var _vignette: ColorRect
var _modal: Control
var _ended := false


func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_arena()

	player = Player.new()
	player.setup(Game.selected_hero, self)
	_entities.add_child(player)
	player.died.connect(_on_player_died)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 7.0
	# Slight zoom so the heroes read clearly on large screens.
	_camera.zoom = Vector2(1.2, 1.2)
	_camera.limit_left = int(ARENA.position.x - 220)
	_camera.limit_top = int(ARENA.position.y - 260)
	_camera.limit_right = int(ARENA.end.x + 220)
	_camera.limit_bottom = int(ARENA.end.y + 160)
	add_child(_camera)
	_camera.make_current()
	_camera.global_position = player.global_position
	_camera.reset_smoothing()

	var vig_layer := CanvasLayer.new()
	vig_layer.layer = 1
	add_child(vig_layer)
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float hurt = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.35, 0.85, length(uv * vec2(1.25, 1.0)));
	vec3 col = mix(vec3(0.0), vec3(0.45, 0.0, 0.02), hurt);
	COLOR = vec4(col, v * (0.72 + 0.25 * hurt));
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_vignette.material = mat
	vig_layer.add_child(_vignette)

	_hud = Hud.new()
	_hud.world = self
	add_child(_hud)

	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)

	_set_crosshair(true)
	Audio.play_music("battle")


func _exit_tree() -> void:
	_set_crosshair(false)
	get_tree().paused = false


# ------------------------------------------------------------------ arena
func _build_arena() -> void:
	var floor_node := ArenaFloor.new()
	floor_node.rect = ARENA
	floor_node.seed_value = rng.randi()
	floor_node.z_index = -10
	add_child(floor_node)

	_ground = Node2D.new()
	_ground.z_index = -5
	add_child(_ground)
	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	add_child(_entities)
	_top = Node2D.new()
	_top.z_index = 20
	add_child(_top)

	# Boundary walls.
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	add_child(walls)
	var t := 200.0
	for r in [
		Rect2(ARENA.position.x - t, ARENA.position.y - t, ARENA.size.x + 2 * t, t),
		Rect2(ARENA.position.x - t, ARENA.end.y, ARENA.size.x + 2 * t, t),
		Rect2(ARENA.position.x - t, ARENA.position.y, t, ARENA.size.y),
		Rect2(ARENA.end.x, ARENA.position.y, t, ARENA.size.y),
	]:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		cs.shape = rs
		cs.position = r.get_center()
		walls.add_child(cs)

	# Pillars, kept away from the spawn point and from each other.
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < 12 and tries < 400:
		tries += 1
		var p := Vector2(
			rng.randf_range(ARENA.position.x + 200, ARENA.end.x - 200),
			rng.randf_range(ARENA.position.y + 200, ARENA.end.y - 200))
		if p.length() < 450.0:
			continue
		var ok := true
		for q in placed:
			if q.distance_to(p) < 420.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var pillar := Pillar.new()
		pillar.position = p
		pillar.broken = rng.randf() < 0.4
		_entities.add_child(pillar)

	# Braziers mark the arena corners.
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var b := Brazier.new()
		b.position = c * (ARENA.size / 2.0 - Vector2(140, 140))
		_entities.add_child(b)


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	if _ended:
		_update_camera(delta)
		return
	run_time += delta
	_update_camera(delta)
	_update_waves(delta)
	var mat := _vignette.material as ShaderMaterial
	var low := 0.0
	if is_instance_valid(player) and not player.dead:
		var frac: float = player.hp / player.max_hp
		if frac < 0.35:
			low = (0.35 - frac) / 0.35 * (0.6 + 0.4 * sin(run_time * 6.0))
	mat.set_shader_parameter("hurt", low)


func _update_camera(delta: float) -> void:
	if is_instance_valid(player):
		_camera.global_position = player.global_position + Vector2(0, -40)
	_shake = maxf(0.0, _shake - 40.0 * delta)
	if _shake > 0.0 and Game.settings.screen_shake:
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		_camera.offset = Vector2.ZERO


func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 22.0)


func _update_waves(delta: float) -> void:
	match state:
		"intermission":
			_state_t -= delta
			if _state_t <= 0.0:
				_start_wave(wave + 1)
		"fighting":
			wave_time += delta
			_spawn_t -= delta
			if _spawn_t <= 0.0:
				_spawn_group()
			if not is_boss_wave(wave) and wave_time >= wave_duration:
				state = "intermission"
				_state_t = 2.0


func _start_wave(n: int) -> void:
	wave = n
	wave_time = 0.0
	state = "fighting"
	wave_duration = 30.0 + wave * 1.5
	_spawn_t = 0.5
	if is_boss_wave(wave):
		_hud.show_banner(Game.t("wave_banner") % wave, Game.t("boss_banner_" + boss_kind_for_wave(wave)))
		Audio.play("boss_roar")
		Audio.play_music("boss")
		_spawn_boss()
	else:
		var hint := ""
		if wave == 1:
			# First-wave reminder of the controls for the active input device.
			hint = Game.t("hint_pad" if Input.get_connected_joypads().size() > 0 else "hint_keys")
		_hud.show_banner(Game.t("wave_banner") % wave, hint, 6.0 if wave == 1 else 3.0)
		Audio.play("wave_horn")
		Audio.play_music("battle")


func is_boss_wave(w: int) -> bool:
	return w > 0 and w % BOSS_EVERY == 0


func _hp_mult() -> float:
	var w := float(wave - 1)
	return (1.0 + 0.18 * w + 0.013 * w * w) * float(Game.DIFFICULTY[Game.difficulty].hp)


func _dmg_mult() -> float:
	return (1.0 + 0.07 * float(wave - 1)) * float(Game.DIFFICULTY[Game.difficulty].damage)


func _spawn_group() -> void:
	var boss_alive: bool = is_instance_valid(boss) and not boss.dead
	var spawn_rate := float(Game.DIFFICULTY[Game.difficulty].spawn)
	var interval := maxf(0.25, 1.05 - 0.055 * wave) / spawn_rate
	var cap := mini(int((50 + wave * 9) * spawn_rate), MAX_ENEMIES)
	if boss_alive:
		# Fewer adds during boss fights so the duel stays the focus.
		interval *= 3.0
		cap = 12 + wave
	_spawn_t = interval
	if enemies.size() >= cap:
		return
	var group := 1 + wave / 3
	var center := _random_spawn_point()
	for i in group:
		if enemies.size() >= cap:
			break
		var kind := _pick_kind()
		var pos := center + Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60))
		var elite := wave >= 6 and rng.randf() < 0.035
		spawn_enemy_at(kind, pos, elite)


func _pick_kind() -> String:
	var w := float(wave)
	var table := {"ghoul": 10.0}
	if wave >= 2:
		table["bat"] = 5.0
	if wave >= 3:
		table["archer"] = 2.5 + w * 0.3
	if wave >= 4:
		table["brute"] = 0.8 + w * 0.22
	if wave >= 6:
		table["cultist"] = 1.5 + w * 0.2
	if wave >= 7:
		table["wraith"] = 1.5 + w * 0.15
	if wave >= 9:
		table["bomber"] = 1.2 + w * 0.12
	if wave >= 11:
		table["shield"] = 1.0 + w * 0.1
	if wave >= 13:
		table["necro"] = 0.5 + w * 0.05
	var total := 0.0
	for k in table:
		total += table[k]
	var roll := rng.randf() * total
	for k in table:
		roll -= table[k]
		if roll <= 0.0:
			return k
	return "ghoul"


func _random_spawn_point() -> Vector2:
	var view := get_viewport_rect().size / _camera.zoom
	var r := view.length() * 0.5 + 80.0
	var inner := ARENA.grow(-60)
	var best := Vector2.ZERO
	for attempt in 8:
		var p: Vector2 = player.global_position + Vector2.from_angle(rng.randf() * TAU) * r
		best = Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
		# Prefer points that stayed off-screen after clamping.
		if best.distance_to(player.global_position) > 500.0:
			return best
	return best


func clamp_to_arena(p: Vector2) -> Vector2:
	var inner := ARENA.grow(-60)
	return Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))


func boss_kind_for_wave(w: int) -> String:
	## Dread Knight, Blood Witch, Void Sovereign, then repeating in endless mode.
	return Boss.ORDER[(maxi(w / BOSS_EVERY, 1) - 1) % Boss.ORDER.size()]


func spawn_enemy_at(kind: String, pos: Vector2, elite: bool = false) -> Node2D:
	var e: Node2D = Boss.new() if Boss.BOSSES.has(kind) else Enemy.new()
	e.setup(kind, self, _hp_mult(), _dmg_mult(), elite)
	var inner := ARENA.grow(-40)
	e.position = Vector2(clampf(pos.x, inner.position.x, inner.end.x), clampf(pos.y, inner.position.y, inner.end.y))
	_entities.add_child(e)
	enemies.append(e)
	e.died.connect(_on_enemy_died)
	spawn_burst(e.position + Vector2(0, -10), Color(0.25, 0.05, 0.1), 8, 120.0)
	return e


func _spawn_boss() -> void:
	var pos: Vector2 = player.global_position + Vector2(0, -340)
	if not ARENA.grow(-150).has_point(pos):
		pos = player.global_position + Vector2(0, 340)
	var kind := boss_kind_for_wave(wave)
	boss = spawn_enemy_at(kind, pos)
	# Bosses scale less steeply than the horde so fights stay reasonable.
	var mult := 1.0 + 0.6 * float(wave / BOSS_EVERY - 1)
	boss.max_hp = Boss.BOSSES[kind].hp * 1.15 * mult * (1.0 + 0.05 * wave) * float(Game.DIFFICULTY[Game.difficulty].hp)
	boss.hp = boss.max_hp
	shake(10.0)


# ------------------------------------------------------------------ combat
func player_hit_enemy(e: Node, mult: float, knock: Vector2) -> void:
	if e.dead or not is_instance_valid(player):
		return
	var roll: Array = player.roll_damage(mult)
	var dealt := damage_enemy(e, roll[0], roll[1], knock)
	if player.lifesteal > 0.0:
		player.heal(dealt * player.lifesteal, false)
	if player.venom > 0:
		e.apply_bleed(player.damage * 0.25 * player.venom)


func damage_enemy(e: Node, amount: float, crit: bool, knock: Vector2, is_dot: bool = false) -> float:
	## Returns the damage actually dealt (shields can block part of it).
	if e.dead:
		return 0.0
	var blocked: bool = false
	var dealt: float = e.hit(amount, knock)
	if dealt < amount * 0.99:
		blocked = true
		amount = dealt
	if Game.settings.damage_numbers:
		var col := Color(1, 0.85, 0.3) if crit else (Color(0.7, 1, 0.5) if is_dot else Color.WHITE)
		if blocked:
			col = Color(0.6, 0.62, 0.7)
		show_damage(e.global_position + Vector2(0, -e.radius * 2.0 - 20.0), amount, col, crit)
	if not is_dot:
		Audio.play("crit" if crit else "hit", -4.0 if not crit else 0.0)
		spawn_burst(e.global_position + Vector2(0, -e.radius), Color(0.55, 0.05, 0.08), 4 if not crit else 8, 180.0)
	if crit:
		shake(3.0)
	if e.hp <= 0.0:
		e.die()
	return dealt


func _on_enemy_died(e: Node) -> void:
	enemies.erase(e)
	kills += 1
	if is_instance_valid(player):
		player.on_kill()
	Audio.play("enemy_die", -6.0)
	spawn_burst(e.global_position + Vector2(0, -e.radius), Color(0.5, 0.04, 0.08), 12, 260.0)
	if e.is_boss:
		_on_boss_killed(e)
		return
	drop_xp(e.global_position, e.xp)
	var potion_chance := 0.012
	if e.kind == "brute":
		potion_chance = 0.12
	if e.elite:
		potion_chance = 0.6
	if rng.randf() < potion_chance:
		_spawn_pickup("potion", e.global_position, 1)


func _on_boss_killed(e: Node) -> void:
	shake(20.0)
	Audio.play("explosion")
	spawn_ring(e.global_position, 320.0, Color(1, 0.4, 0.2), 0.8)
	for i in 3:
		_spawn_pickup("potion", e.global_position + Vector2.from_angle(TAU * i / 3.0) * 40.0, 1)
	drop_xp(e.global_position, e.xp)
	boss = null
	vacuum = true
	get_tree().create_timer(2.5, false).timeout.connect(func() -> void: vacuum = false)
	if wave >= TOTAL_WAVES and not endless:
		_win()
	else:
		state = "intermission"
		_state_t = 4.0
		_hud.show_banner(Game.t("wave_cleared"), "")
		Audio.play("levelup")


func drop_xp(pos: Vector2, value: int) -> void:
	if value <= 0:
		return
	if get_tree().get_node_count_in_group("pickups") >= MAX_PICKUPS:
		# Merge into an existing shard instead of creating more nodes.
		for c in _ground.get_children():
			if c is Pickup and c.kind == "xp" and not c.is_queued_for_deletion():
				c.value += value
				return
	_spawn_pickup("xp", pos, value)


func _spawn_pickup(kind: String, pos: Vector2, value: int) -> void:
	var p := Pickup.new()
	p.world = self
	p.kind = kind
	p.value = value
	p.position = pos
	_ground.add_child(p)


func collect(p: Node) -> void:
	if not is_instance_valid(player) or player.dead:
		return
	if p.kind == "potion":
		player.heal(player.max_hp * 0.3)
		Audio.play("levelup", -6.0, 0.0)
		return
	Audio.play("pickup", -8.0, 0.15)
	player.xp += p.value
	while player.xp >= player.xp_to_next():
		player.xp -= player.xp_to_next()
		player.level += 1
		pending_levels += 1
	if pending_levels > 0 and _modal == null:
		_open_levelup.call_deferred()


# ------------------------------------------------------------------ spawning helpers
func spawn_projectile(kind: String, pos: Vector2, vel: Vector2) -> Node2D:
	var p := Projectile.new()
	p.world = self
	p.kind = kind
	p.position = pos
	p.velocity = vel
	_top.add_child(p)
	return p


func spawn_enemy_projectile(pos: Vector2, vel: Vector2, dmg: float, kind: String) -> void:
	var p := EnemyProjectile.new()
	p.world = self
	p.kind = kind
	p.position = pos
	p.velocity = vel
	p.damage = dmg
	_top.add_child(p)
	if kind != "orb_fast":
		Audio.play("enemy_shot", -8.0)


func add_ground_fx(n: Node2D) -> void:
	_ground.add_child(n)


func add_top_fx(n: Node2D) -> void:
	_top.add_child(n)


func spawn_ring(pos: Vector2, radius: float, col: Color, life: float) -> void:
	var r := FX.Ring.new()
	r.position = pos
	r.radius = radius
	r.color = col
	r.life = life
	_ground.add_child(r)


func spawn_burst(pos: Vector2, col: Color, count: int, spd: float) -> void:
	if _top.get_child_count() > 400:
		return
	var b := FX.Burst.new()
	b.position = pos
	b.color = col
	b.count = count
	b.speed = spd
	_top.add_child(b)


func show_damage(pos: Vector2, amount: float, col: Color, big: bool) -> void:
	if _top.get_child_count() > 400:
		return
	var d := FX.DamageNumber.new()
	d.position = pos
	d.text = str(maxi(1, roundi(amount)))
	d.color = col
	d.font_size = 34 if big else 24
	_top.add_child(d)


func player_hidden() -> bool:
	return is_instance_valid(player) and player.is_hidden()


func nearest_enemy(pos: Vector2, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist * max_dist
	for e in enemies:
		if e.dead:
			continue
		var d: float = e.global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func enemies_in_radius(pos: Vector2, r: float) -> Array:
	var out: Array = []
	for e in enemies:
		if e.dead:
			continue
		var rr: float = r + e.radius
		if e.global_position.distance_squared_to(pos) <= rr * rr:
			out.append(e)
	return out


# ------------------------------------------------------------------ menus / flow
func _open_levelup() -> void:
	if _modal != null or _ended or pending_levels <= 0 or player.dead:
		return
	Audio.play("levelup")
	var m := LevelUpMenu.new()
	m.world = self
	m.chosen.connect(_on_upgrade_chosen)
	_show_modal(m)


func _on_upgrade_chosen(id: String) -> void:
	player.apply_upgrade(id)
	pending_levels -= 1
	_close_modal()
	if pending_levels > 0:
		_open_levelup.call_deferred()


func _show_modal(m: Control) -> void:
	_modal = m
	_overlay.add_child(m)
	get_tree().paused = true
	_set_crosshair(false)


func _close_modal() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null
	if not _ended:
		get_tree().paused = false
		_set_crosshair(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _modal == null and not _ended:
		get_viewport().set_input_as_handled()
		open_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _modal == null and not _ended and is_inside_tree():
		open_pause()


func open_pause() -> void:
	if _modal != null or _ended:
		return
	var m := PauseMenu.new()
	m.resumed.connect(_close_modal)
	m.quit_requested.connect(func(target: String) -> void: exit_requested.emit(target))
	_show_modal(m)


func _on_player_died() -> void:
	if _ended:
		return
	Audio.play("defeat")
	Audio.stop_music(1.5)
	shake(16.0)
	get_tree().create_timer(1.6, false).timeout.connect(func() -> void: _finish(false))


func _win() -> void:
	vacuum = true
	for e in enemies.duplicate():
		if not e.dead:
			e.die()
	Audio.stop_music(1.0)
	Audio.play("victory")
	get_tree().create_timer(2.5, false).timeout.connect(func() -> void: _finish(true))


func _finish(won: bool) -> void:
	if _ended:
		return
	if _modal:
		_modal.queue_free()
		_modal = null
	_ended = true
	var reached := wave if not won else TOTAL_WAVES
	# An endless run was already counted when the final wave was beaten.
	var new_best := Game.submit_run(Game.selected_hero, reached, kills, won, not endless)
	var m := EndScreen.new()
	m.won = won
	m.can_continue = won and not endless
	m.new_best = new_best
	m.wave = reached
	m.kills = kills
	m.level = player.level
	m.time = run_time
	m.choice.connect(func(target: String) -> void:
		if target == "endless":
			_continue_endless()
		else:
			exit_requested.emit(target))
	_overlay.add_child(m)
	_modal = m
	_set_crosshair(false)
	get_tree().paused = true


func _continue_endless() -> void:
	endless = true
	_ended = false
	if _modal:
		_modal.queue_free()
		_modal = null
	get_tree().paused = false
	_set_crosshair(true)
	vacuum = false
	state = "intermission"
	_state_t = 3.0
	_hud.show_banner(Game.t("endless_banner"), Game.t("endless_sub"), 3.0)
	Audio.play_music("battle")


func _set_crosshair(on: bool) -> void:
	if not on:
		Input.set_custom_mouse_cursor(null)
		return
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var c := Color(1, 0.92, 0.8)
	for i in 32:
		for j in 32:
			var d := Vector2(i - 15.5, j - 15.5).length()
			if absf(d - 9.0) < 1.3:
				img.set_pixel(i, j, c)
			elif d < 1.6:
				img.set_pixel(i, j, Color(1, 0.3, 0.3))
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW, Vector2(16, 16))


# ------------------------------------------------------------------ scenery
class ArenaFloor extends Node2D:
	var rect: Rect2
	var seed_value := 0

	func _draw() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = seed_value
		# Dark void beyond the arena.
		draw_rect(rect.grow(1200), Color(0.035, 0.028, 0.032))
		var tile := 96.0
		var cols := int(rect.size.x / tile)
		var rows := int(rect.size.y / tile)
		for y in rows:
			for x in cols:
				var p := rect.position + Vector2(x, y) * tile
				var v := r.randf_range(-0.018, 0.018)
				var base := Color(0.17 + v, 0.15 + v, 0.15 + v)
				# Darken towards the edges to focus the eye on the centre.
				var dist := (p + Vector2(tile, tile) / 2.0).length() / rect.size.length() * 2.0
				base = base.darkened(clampf(dist * 0.45, 0.0, 0.5))
				draw_rect(Rect2(p + Vector2(2, 2), Vector2(tile - 4, tile - 4)), base)
				if r.randf() < 0.12:
					var a := p + Vector2(r.randf() * tile, r.randf() * tile)
					draw_line(a, a + Vector2(r.randf_range(-30, 30), r.randf_range(-30, 30)), base.darkened(0.4), 2.0)
		# Blood stains and moss.
		for i in 70:
			var c := rect.position + Vector2(r.randf() * rect.size.x, r.randf() * rect.size.y)
			var col := Color(0.32, 0.04, 0.06, 0.35) if r.randf() < 0.6 else Color(0.18, 0.24, 0.12, 0.35)
			for k in 4:
				draw_circle(c + Vector2(r.randf_range(-24, 24), r.randf_range(-14, 14)), r.randf_range(8, 26), col)
		# Ritual circle in the middle.
		draw_arc(Vector2.ZERO, 300, 0, TAU, 96, Color(0.45, 0.08, 0.1, 0.5), 6.0, true)
		draw_arc(Vector2.ZERO, 260, 0, TAU, 96, Color(0.45, 0.08, 0.1, 0.35), 3.0, true)
		for i in 7:
			var a := TAU * i / 7.0
			var b := TAU * ((i + 3) % 7) / 7.0
			draw_line(Vector2.from_angle(a) * 260, Vector2.from_angle(b) * 260, Color(0.45, 0.08, 0.1, 0.3), 3.0)
		# Raised wall border.
		var wall := Color(0.1, 0.08, 0.09)
		var t := 60.0
		draw_rect(Rect2(rect.position - Vector2(t, t * 2.5), Vector2(rect.size.x + t * 2, t * 2.5)), wall)
		draw_rect(Rect2(rect.position + Vector2(-t, rect.size.y), Vector2(rect.size.x + t * 2, t)), wall)
		draw_rect(Rect2(rect.position - Vector2(t, 0), Vector2(t, rect.size.y)), wall)
		draw_rect(Rect2(Vector2(rect.end.x, rect.position.y), Vector2(t, rect.size.y)), wall)
		draw_rect(rect, Color(0.42, 0.33, 0.24, 0.6), false, 4.0)


class Pillar extends StaticBody2D:
	var broken := false

	func _ready() -> void:
		collision_layer = 1
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 36.0
		cs.shape = c
		add_child(cs)

	func _draw() -> void:
		draw_set_transform(Vector2(6, 4), 0.0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, 54.0, Color(0, 0, 0, 0.4))
		draw_set_transform(Vector2.ZERO)
		var h := 110.0 if broken else 190.0
		var stone := Color(0.36, 0.33, 0.32)
		draw_rect(Rect2(-46, -22, 92, 26), Color(0.26, 0.24, 0.24))
		draw_rect(Rect2(-34, -h, 68, h - 16), stone)
		for i in 4:
			var x := -24.0 + i * 16.0
			draw_line(Vector2(x, -h + 6), Vector2(x, -22), stone.darkened(0.25), 3.0)
		draw_rect(Rect2(-34, -h, 68, h - 16), Color(0.05, 0.04, 0.04), false, 2.0)
		if broken:
			draw_colored_polygon(PackedVector2Array([
				Vector2(-34, -h), Vector2(-10, -h - 22), Vector2(8, -h - 8), Vector2(34, -h - 18), Vector2(34, -h)]),
				stone.lightened(0.08))
		else:
			draw_rect(Rect2(-44, -h - 20, 88, 22), stone.lightened(0.1))
			draw_rect(Rect2(-44, -h - 20, 88, 22), Color(0.05, 0.04, 0.04), false, 2.0)
		draw_rect(Rect2(-46, -22, 92, 26), Color(0.05, 0.04, 0.04), false, 2.0)


class Brazier extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var flick := 1.0 + sin(_t * 13.0) * 0.08 + sin(_t * 7.3) * 0.06
		draw_circle(Vector2(0, -60), 150.0 * flick, Color(1, 0.45, 0.15, 0.06))
		draw_circle(Vector2(0, -60), 80.0 * flick, Color(1, 0.5, 0.2, 0.08))
		draw_rect(Rect2(-6, -50, 12, 50), Color(0.2, 0.16, 0.14))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-24, -62), Vector2(24, -62), Vector2(16, -48), Vector2(-16, -48)]), Color(0.3, 0.24, 0.2))
		for i in 3:
			var off := sin(_t * 9.0 + i * 2.0) * 4.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(-16 + i * 10, -62), Vector2(-8 + i * 10 + off, -96 + i * 8 * flick), Vector2(i * 10 - 2, -62)]),
				Color(1, 0.55 + i * 0.12, 0.15))
		draw_circle(Vector2(0, -68), 8.0 * flick, Color(1, 0.9, 0.5))
