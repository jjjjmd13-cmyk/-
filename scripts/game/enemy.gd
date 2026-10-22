extends CharacterBody2D
## All regular enemies plus the Dread Knight boss, configured by `kind`.

signal died(enemy)

const FX := preload("res://scripts/game/fx.gd")

const KINDS := {
	"ghoul": {"hp": 30.0, "speed": 108.0, "damage": 10.0, "radius": 17.0, "xp": 1},
	"bat": {"hp": 13.0, "speed": 170.0, "damage": 6.0, "radius": 12.0, "xp": 1},
	"archer": {"hp": 26.0, "speed": 96.0, "damage": 9.0, "radius": 16.0, "xp": 2,
		"range": 400.0, "shot_cd": 2.8},
	"brute": {"hp": 135.0, "speed": 72.0, "damage": 20.0, "radius": 27.0, "xp": 6},
	"cultist": {"hp": 44.0, "speed": 82.0, "damage": 12.0, "radius": 17.0, "xp": 3,
		"range": 440.0, "shot_cd": 3.2},
	"boss": {"hp": 1500.0, "speed": 100.0, "damage": 24.0, "radius": 46.0, "xp": 80},
}

var kind := "ghoul"
var world: Node
var max_hp := 30.0
var hp := 30.0
var speed := 100.0
var damage := 10.0
var radius := 16.0
var xp := 1
var elite := false
var dead := false

var knockback := Vector2.ZERO
var stun := 0.0
var contact_cd := 0.0
var bleed_dps := 0.0
var bleed_time := 0.0
var _bleed_tick := 0.0
var _flash := 0.0
var _shot_cd := 0.0
var _anim := 0.0
var _wobble_seed := 0.0
var _visual: Node2D

# Brute charge / boss state machine.
var _state := "chase"
var _state_t := 0.0
var _charge_dir := Vector2.ZERO
var _boss_phase := 1
var _boss_cycle := 0


func setup(p_kind: String, p_world: Node, hp_mult: float, dmg_mult: float, p_elite: bool) -> void:
	kind = p_kind
	world = p_world
	elite = p_elite
	var d: Dictionary = KINDS[kind]
	max_hp = d.hp * hp_mult * (3.2 if elite else 1.0)
	hp = max_hp
	speed = d.speed * randf_range(0.92, 1.08) * (1.1 if elite else 1.0)
	damage = d.damage * dmg_mult * (1.4 if elite else 1.0)
	radius = d.radius * (1.3 if elite else 1.0)
	xp = int(d.xp) * (5 if elite else 1)
	_shot_cd = randf_range(0.8, float(d.get("shot_cd", 1.0)))
	_wobble_seed = randf() * TAU


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.8
	shape.shape = circle
	add_child(shape)
	_visual = Visual.new()
	_visual.enemy = self
	add_child(_visual)
	if kind == "boss":
		_state = "intro"
		_state_t = 1.2


func _physics_process(delta: float) -> void:
	if dead:
		return
	_anim += delta
	contact_cd = maxf(0.0, contact_cd - delta)
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_visual.material = null
	if bleed_time > 0.0:
		bleed_time -= delta
		_bleed_tick -= delta
		if _bleed_tick <= 0.0:
			_bleed_tick = 0.5
			world.damage_enemy(self, bleed_dps * 0.5, false, Vector2.ZERO, true)
			if dead:
				return

	var player: Node2D = world.player
	var to_player := Vector2.ZERO
	var dist := 99999.0
	if is_instance_valid(player) and not player.dead:
		to_player = player.global_position - global_position
		dist = to_player.length()

	var desired := Vector2.ZERO
	if stun > 0.0:
		stun -= delta
	elif dist < 99999.0:
		match kind:
			"archer", "cultist":
				desired = _ranged_ai(to_player, dist, delta)
			"brute":
				desired = _brute_ai(to_player, dist, delta)
			"boss":
				desired = _boss_ai(to_player, dist, delta)
			"bat":
				var side := to_player.orthogonal().normalized() * sin(_anim * 5.0 + _wobble_seed) * 0.7
				desired = (to_player.normalized() + side).normalized() * speed
			_:
				desired = to_player.normalized() * speed

	velocity = desired + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	move_and_slide()

	if not is_instance_valid(player) or player.dead:
		return
	# Contact damage.
	if dist < radius + 20.0 and contact_cd <= 0.0 and stun <= 0.0:
		contact_cd = 0.9
		# The boss's real threats are its telegraphed attacks; touching it hurts less.
		player.take_damage(damage * (0.55 if kind == "boss" else 1.0), self)

	if absf(to_player.x) > 4.0:
		_visual.scale.x = signf(to_player.x)


func _ranged_ai(to_player: Vector2, dist: float, delta: float) -> Vector2:
	var d: Dictionary = KINDS[kind]
	var dir := to_player / maxf(dist, 1.0)
	_shot_cd -= delta
	if _shot_cd <= 0.0 and dist < d.range + 80.0:
		_shot_cd = d.shot_cd * randf_range(0.85, 1.15)
		if kind == "archer":
			world.spawn_enemy_projectile(global_position + Vector2(0, -30), dir * 330.0, damage, "arrow")
		else:
			world.spawn_enemy_projectile(global_position + Vector2(0, -40), dir * 210.0, damage, "orb")
	# Keep at preferred range, strafing slightly.
	var strafe := dir.orthogonal() * sin(_anim * 0.8 + _wobble_seed) * 0.5
	if dist > d.range:
		return (dir + strafe * 0.3).normalized() * speed
	elif dist < d.range * 0.6:
		return (-dir + strafe).normalized() * speed * 0.8
	return strafe * speed


func _brute_ai(to_player: Vector2, dist: float, delta: float) -> Vector2:
	_state_t -= delta
	match _state:
		"windup":
			if _state_t <= 0.0:
				_state = "charge"
				_state_t = 0.55
			return Vector2.ZERO
		"charge":
			if _state_t <= 0.0:
				_state = "chase"
				_state_t = randf_range(2.5, 3.5)
			return _charge_dir * speed * 5.0
	if dist < 340.0 and _state_t <= 0.0:
		_state = "windup"
		_state_t = 0.65
		_charge_dir = to_player.normalized()
		var tel = FX.LineTelegraph.new()
		tel.length = speed * 5.0 * 0.55 + radius
		tel.width = radius * 2.0
		tel.duration = 0.65
		tel.rotation = _charge_dir.angle()
		tel.position = global_position
		world.add_ground_fx(tel)
		return Vector2.ZERO
	return to_player.normalized() * speed


func _boss_ai(to_player: Vector2, dist: float, delta: float) -> Vector2:
	if _boss_phase == 1 and hp < max_hp * 0.5:
		_boss_phase = 2
		Audio.play("boss_roar")
		world.shake(14.0)
		world.spawn_ring(global_position, 240.0, Color(0.7, 0.1, 0.15), 0.6)
	var fast := 1.35 if _boss_phase == 2 else 1.0
	var dir := to_player / maxf(dist, 1.0)
	_state_t -= delta * fast
	match _state:
		"intro":
			if _state_t <= 0.0:
				_state = "chase"
				_state_t = 1.5
			return Vector2.ZERO
		"chase":
			if _state_t <= 0.0:
				_pick_boss_attack(to_player, dist)
			return dir * speed * fast
		"slam_wind":
			if _state_t <= 0.0:
				_state = "recover"
				_state_t = 0.7
			return Vector2.ZERO
		"charge_wind":
			if _state_t <= 0.0:
				_state = "charging"
				_state_t = 0.6
				Audio.play("dash", 2.0, 0.0)
			return Vector2.ZERO
		"charging":
			if _state_t <= 0.0:
				_state = "recover"
				_state_t = 0.6
			return _charge_dir * 820.0
		"burst":
			if _state_t <= 0.0:
				_state = "recover"
				_state_t = 0.5
			return Vector2.ZERO
		"recover":
			if _state_t <= 0.0:
				_state = "chase"
				_state_t = randf_range(1.4, 2.2)
			return dir * speed * 0.4
	return Vector2.ZERO


func _pick_boss_attack(to_player: Vector2, dist: float) -> void:
	_boss_cycle += 1
	var options := ["slam", "burst", "charge"]
	if _boss_phase == 2 and _boss_cycle % 3 == 0:
		options.append("summon")
	var pick: String = options[randi() % options.size()]
	if dist < 220.0 and randf() < 0.6:
		pick = "slam"
	match pick:
		"slam":
			_state = "slam_wind"
			_state_t = 0.9
			var tel = FX.Telegraph.new()
			tel.radius = 210.0
			tel.duration = 0.9 / (1.35 if _boss_phase == 2 else 1.0)
			tel.position = global_position
			tel.on_done = _do_slam
			world.add_ground_fx(tel)
		"charge":
			_state = "charge_wind"
			_state_t = 0.7
			_charge_dir = to_player.normalized()
			var tel = FX.LineTelegraph.new()
			tel.length = 820.0 * 0.6
			tel.width = radius * 2.2
			tel.duration = 0.7 / (1.35 if _boss_phase == 2 else 1.0)
			tel.rotation = _charge_dir.angle()
			tel.position = global_position
			world.add_ground_fx(tel)
		"burst":
			_state = "burst"
			_state_t = 0.8
			_do_burst(0.0)
			if _boss_phase == 2:
				get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
					if not dead:
						_do_burst(PI / 16.0))
		"summon":
			_state = "recover"
			_state_t = 0.9
			Audio.play("boss_roar", -4.0)
			for i in 6:
				var p := global_position + Vector2.from_angle(TAU * i / 6.0) * 120.0
				world.spawn_enemy_at("ghoul", p)


func _do_slam() -> void:
	if dead:
		return
	Audio.play("explosion")
	world.shake(12.0)
	world.spawn_ring(global_position, 210.0, Color(0.9, 0.25, 0.15), 0.4)
	var player: Node2D = world.player
	if is_instance_valid(player) and not player.dead:
		if player.global_position.distance_to(global_position) < 210.0 + 14.0:
			player.take_damage(damage * 1.5, self)


func _do_burst(offset: float) -> void:
	Audio.play("enemy_shot", 2.0)
	var count := 20 if _boss_phase == 2 else 16
	for i in count:
		var dir := Vector2.from_angle(offset + TAU * i / count)
		world.spawn_enemy_projectile(global_position + Vector2(0, -50) + dir * 30.0, dir * 250.0, damage * 0.6, "orb_fast")


func hit(amount: float, knock: Vector2) -> void:
	hp -= amount
	if kind == "boss":
		knock *= 0.05
	elif kind == "brute":
		knock *= 0.35
	if elite:
		knock *= 0.5
	knockback += knock
	_flash = 0.07
	_visual.material = Game.flash_material()


func apply_bleed(dps: float) -> void:
	bleed_dps = maxf(bleed_dps, dps)
	if bleed_time <= 0.0:
		_bleed_tick = 0.5
	bleed_time = 2.5


func die() -> void:
	if dead:
		return
	dead = true
	died.emit(self)
	queue_free()


## Draws the enemy. Static kinds draw once and animate via transform.
class Visual extends Node2D:
	var enemy: Node

	func _process(_delta: float) -> void:
		var e = enemy
		if e.kind == "bat" or e.kind == "boss":
			queue_redraw()
		# Cheap walk animation: bob and sway.
		var t: float = e._anim * 9.0 + e._wobble_seed
		if e.kind != "bat":
			position.y = -absf(sin(t)) * 3.0
			rotation = sin(t) * 0.06
		else:
			position.y = sin(t * 0.5) * 6.0

	func _draw() -> void:
		var e = enemy
		var r: float = e.radius
		var s: float = r / float(KINDS[e.kind].radius)
		# Shadow (drawn relative to feet).
		draw_set_transform(Vector2(0, -position.y), 0.0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, r * 1.1, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		if e.elite:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s * 0.35))
			draw_arc(Vector2.ZERO, r * 1.3 / s, 0, TAU, 32, Color(1, 0.8, 0.3, 0.8), 3.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		match e.kind:
			"ghoul": _ghoul()
			"bat": _bat(e._anim)
			"archer": _archer()
			"brute": _brute()
			"cultist": _cultist()
			"boss": _boss(e._anim, e._state)
		draw_set_transform(Vector2.ZERO)

	func _poly(pts: Array, col: Color, outline := true) -> void:
		var p := PackedVector2Array(pts)
		draw_colored_polygon(p, col)
		if outline:
			p.append(p[0])
			draw_polyline(p, Color(0.04, 0.03, 0.03, 0.9), 2.0, true)

	func _ghoul() -> void:
		var skin := Color(0.5, 0.56, 0.47)
		var rag := Color(0.28, 0.24, 0.22)
		_poly([Vector2(-8, -2), Vector2(-4, -22), Vector2(2, -22), Vector2(4, -2)], Color(0.35, 0.38, 0.33))
		_poly([Vector2(-12, -20), Vector2(12, -22), Vector2(14, -46), Vector2(-10, -48)], rag)
		_poly([Vector2(-14, -22), Vector2(-6, -24), Vector2(-9, -12), Vector2(-15, -14), Vector2(-12, -18)], rag)
		# Hunched head jutting forward.
		draw_circle(Vector2(8, -50), 10.0, skin)
		draw_arc(Vector2(8, -50), 10.0, 0, TAU, 16, Color(0.04, 0.03, 0.03), 2.0, true)
		draw_circle(Vector2(12, -52), 2.2, Color(1.0, 0.85, 0.3))
		draw_line(Vector2(9, -44), Vector2(16, -45), Color(0.2, 0.05, 0.05), 2.0)
		# Reaching claws.
		draw_line(Vector2(8, -38), Vector2(26, -32), skin, 5.0, true)
		draw_line(Vector2(26, -32), Vector2(31, -29), Color(0.85, 0.82, 0.7), 2.0)

	func _bat(t: float) -> void:
		var flap := sin(t * 18.0) * 10.0
		var wing := Color(0.22, 0.12, 0.18)
		# Kept convex-ish for every flap value so the polygon always triangulates.
		_poly([Vector2(0, -36), Vector2(-26, -44 - flap), Vector2(-14, -30 - flap * 0.3), Vector2(-4, -28)], wing)
		_poly([Vector2(0, -36), Vector2(4, -28), Vector2(14, -30 - flap * 0.3), Vector2(26, -44 - flap)], wing)
		draw_circle(Vector2(0, -34), 8.0, Color(0.3, 0.16, 0.22))
		draw_circle(Vector2(3, -36), 2.0, Color(1, 0.2, 0.2))
		draw_circle(Vector2(-3, -36), 2.0, Color(1, 0.2, 0.2))

	func _archer() -> void:
		var bone := Color(0.86, 0.83, 0.74)
		var dark := Color(0.2, 0.18, 0.17)
		draw_line(Vector2(-4, -22), Vector2(-6, 0), bone, 3.5)
		draw_line(Vector2(4, -22), Vector2(6, 0), bone, 3.5)
		_poly([Vector2(-9, -22), Vector2(9, -22), Vector2(10, -46), Vector2(-10, -46)], dark)
		for i in 3:
			draw_line(Vector2(-7, -42 + i * 6), Vector2(7, -42 + i * 6), bone, 2.0)
		draw_circle(Vector2(1, -56), 9.0, bone)
		draw_arc(Vector2(1, -56), 9.0, 0, TAU, 16, Color(0.04, 0.03, 0.03), 2.0, true)
		draw_circle(Vector2(4, -57), 2.5, Color(0.05, 0.05, 0.05))
		draw_circle(Vector2(4, -57), 1.0, Color(0.4, 0.9, 1.0))
		# Hood remnants.
		_poly([Vector2(-10, -58), Vector2(-4, -67), Vector2(8, -66), Vector2(-12, -46)], Color(0.3, 0.12, 0.12))
		# Bow.
		draw_arc(Vector2(10, -40), 20.0, -1.3, 1.3, 12, Color(0.35, 0.25, 0.18), 3.0, true)
		draw_line(Vector2(10, -40) + Vector2.from_angle(-1.3) * 20.0, Vector2(10, -40) + Vector2.from_angle(1.3) * 20.0, Color(0.9, 0.9, 0.8), 1.0)

	func _brute() -> void:
		var skin := Color(0.45, 0.3, 0.3)
		var armor := Color(0.3, 0.28, 0.27)
		_poly([Vector2(-14, -2), Vector2(-10, -26), Vector2(-2, -26), Vector2(-4, -2)], Color(0.25, 0.2, 0.2))
		_poly([Vector2(4, -2), Vector2(2, -26), Vector2(10, -26), Vector2(14, -2)], Color(0.25, 0.2, 0.2))
		_poly([Vector2(-24, -26), Vector2(24, -26), Vector2(28, -66), Vector2(-26, -66)], skin)
		_poly([Vector2(-20, -40), Vector2(20, -40), Vector2(22, -64), Vector2(-22, -64)], armor)
		draw_line(Vector2(-22, -52), Vector2(22, -52), Color(0.55, 0.45, 0.3), 3.0)
		_poly([Vector2(-30, -62), Vector2(-14, -74), Vector2(-14, -58)], Color(0.6, 0.58, 0.55))
		_poly([Vector2(30, -62), Vector2(14, -74), Vector2(14, -58)], Color(0.6, 0.58, 0.55))
		draw_circle(Vector2(4, -74), 12.0, skin)
		draw_arc(Vector2(4, -74), 12.0, 0, TAU, 16, Color(0.04, 0.03, 0.03), 2.0, true)
		draw_circle(Vector2(9, -76), 2.5, Color(1, 0.5, 0.1))
		# Horns.
		_poly([Vector2(-4, -82), Vector2(-14, -96), Vector2(-2, -86)], Color(0.85, 0.8, 0.7))
		_poly([Vector2(10, -84), Vector2(18, -98), Vector2(13, -82)], Color(0.85, 0.8, 0.7))
		# Club.
		draw_line(Vector2(24, -40), Vector2(40, -78), Color(0.35, 0.24, 0.16), 7.0, true)
		draw_circle(Vector2(40, -80), 9.0, Color(0.35, 0.24, 0.16))

	func _cultist() -> void:
		var robe := Color(0.42, 0.06, 0.1)
		_poly([Vector2(-16, 0), Vector2(16, 0), Vector2(10, -44), Vector2(-10, -44)], robe)
		draw_line(Vector2(0, -44), Vector2(0, 0), Color(0.75, 0.6, 0.3), 2.0)
		_poly([Vector2(-11, -42), Vector2(-4, -64), Vector2(4, -66), Vector2(12, -42)], Color(0.3, 0.04, 0.07))
		draw_circle(Vector2(3, -50), 6.0, Color(0.05, 0.03, 0.03))
		draw_circle(Vector2(5, -51), 1.6, Color(1, 0.3, 0.8))
		# Glowing hand.
		draw_circle(Vector2(16, -32), 7.0, Color(0.9, 0.2, 0.7, 0.35))
		draw_circle(Vector2(16, -32), 3.5, Color(1, 0.5, 0.9))

	func _boss(t: float, state: String) -> void:
		var plate := Color(0.2, 0.19, 0.22)
		var plate_hi := Color(0.38, 0.36, 0.42)
		var red := Color(0.75, 0.08, 0.12)
		var sway := sin(t * 2.0) * 4.0
		# Tattered cape.
		_poly([Vector2(-24, -110), Vector2(20, -110), Vector2(34 + sway, -6), Vector2(18, -14),
			Vector2(6, -2), Vector2(-8, -12), Vector2(-24, 0), Vector2(-40 + sway, -10)], Color(0.15, 0.05, 0.07))
		# Legs.
		_poly([Vector2(-22, 0), Vector2(-18, -48), Vector2(-4, -48), Vector2(-6, 0)], plate)
		_poly([Vector2(6, 0), Vector2(4, -48), Vector2(18, -48), Vector2(22, 0)], plate)
		# Torso.
		_poly([Vector2(-30, -46), Vector2(30, -46), Vector2(36, -108), Vector2(-36, -108)], plate)
		_poly([Vector2(-12, -60), Vector2(12, -60), Vector2(16, -100), Vector2(-16, -100)], plate_hi)
		draw_circle(Vector2(0, -82), 7.0, red)
		draw_circle(Vector2(0, -82), 12.0, Color(1, 0.1, 0.1, 0.25 + 0.15 * sin(t * 4.0)))
		# Spiked pauldrons.
		for side in [-1, 1]:
			_poly([Vector2(26 * side, -98), Vector2(52 * side, -110), Vector2(46 * side, -88), Vector2(30 * side, -84)], plate_hi)
			_poly([Vector2(40 * side, -106), Vector2(52 * side, -132), Vector2(48 * side, -104)], Color(0.6, 0.58, 0.6))
		# Helm with glowing visor.
		_poly([Vector2(-18, -108), Vector2(18, -108), Vector2(16, -140), Vector2(0, -150), Vector2(-16, -140)], plate)
		draw_line(Vector2(-10, -128), Vector2(14, -128), Color(1, 0.15, 0.1), 4.0)
		_poly([Vector2(-14, -142), Vector2(-26, -162), Vector2(-8, -146)], Color(0.6, 0.58, 0.6))
		_poly([Vector2(14, -142), Vector2(26, -162), Vector2(8, -146)], Color(0.6, 0.58, 0.6))
		# Giant cursed blade; raised during wind-ups.
		var ang := -0.5
		if state == "slam_wind" or state == "charge_wind":
			ang = -1.9
		elif state == "recover":
			ang = 0.6
		draw_set_transform(Vector2(34, -74), ang)
		_poly([Vector2(0, -8), Vector2(120, -10), Vector2(140, 0), Vector2(120, 10), Vector2(0, 8)], Color(0.32, 0.3, 0.34))
		draw_line(Vector2(6, 0), Vector2(128, 0), Color(0.9, 0.15, 0.15, 0.8), 3.0)
		draw_line(Vector2(0, -18), Vector2(0, 18), Color(0.55, 0.1, 0.12), 8.0)
		draw_set_transform(Vector2.ZERO)
