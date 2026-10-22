extends "res://scripts/game/enemy.gd"
## The three bosses: Dread Knight (wave 5), Blood Witch (wave 10) and
## Void Sovereign (wave 15). Endless mode cycles through them.

const BOSSES := {
	"dread_knight": {"hp": 1500.0, "speed": 100.0, "damage": 24.0, "radius": 46.0, "xp": 80},
	"blood_witch": {"hp": 1200.0, "speed": 115.0, "damage": 22.0, "radius": 40.0, "xp": 90},
	"void_lord": {"hp": 1750.0, "speed": 85.0, "damage": 26.0, "radius": 52.0, "xp": 120},
}
const ORDER := ["dread_knight", "blood_witch", "void_lord"]

var phase := 1
var _cycle := 0
## Seconds left on the Void Sovereign's gravity pull.
var _pull_t := 0.0
var _spiral_angle := 0.0
var _spiral_t := 0.0


func _stats() -> Dictionary:
	return BOSSES[kind]


func _ready() -> void:
	is_boss = true
	super._ready()
	_state = "intro"
	_state_t = 1.2


func _contact_damage() -> float:
	# The real threats are the telegraphed attacks; touching a boss hurts less.
	return damage * (0.3 if kind == "blood_witch" else 0.55)


func _scale_knockback(knock: Vector2) -> Vector2:
	return knock * 0.05


func redraws_every_frame() -> bool:
	return true


func _speed_mult() -> float:
	return 1.0 + 0.3 * float(phase - 1)


func _check_phase() -> void:
	var frac := hp / max_hp
	var next := phase
	if kind == "void_lord":
		next = 3 if frac < 0.33 else (2 if frac < 0.66 else 1)
	else:
		next = 2 if frac < 0.5 else 1
	if next > phase:
		phase = next
		Audio.play("boss_roar")
		world.shake(14.0)
		world.spawn_ring(global_position, 260.0, _theme_color(), 0.6)


func _theme_color() -> Color:
	match kind:
		"blood_witch":
			return Color(0.9, 0.1, 0.25)
		"void_lord":
			return Color(0.6, 0.3, 1.0)
	return Color(0.8, 0.1, 0.15)


# ------------------------------------------------------------------ brain
func _think(to_player: Vector2, dist: float, delta: float) -> Vector2:
	_check_phase()
	var fast := _speed_mult()
	var dir := to_player / maxf(dist, 1.0)
	_state_t -= delta * fast
	if _pull_t > 0.0:
		_pull_t -= delta
		var player: Node2D = world.player
		if is_instance_valid(player):
			player.apply_pull((global_position - player.global_position).normalized() * 170.0)
	if _spiral_t > 0.0:
		_spiral_t -= delta
		_spiral_tick(delta)
	match _state:
		"intro":
			if _state_t <= 0.0:
				_state = "chase"
				_state_t = 1.5
			return Vector2.ZERO
		"chase":
			if _state_t <= 0.0:
				_pick_attack(to_player, dist)
			if kind == "blood_witch":
				# The witch hovers at mid range instead of closing in.
				return _keep_range(dir, dist, 260.0) * 0.8
			return dir * speed * fast
		"charging":
			if _state_t <= 0.0:
				_state = "recover"
				_state_t = 0.6
			return _charge_dir * 820.0
		"blink":
			_visual.modulate.a = clampf(_state_t / 0.4, 0.0, 1.0)
			if _state_t <= 0.0:
				var player: Node2D = world.player
				var spot: Vector2 = player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(300.0, 420.0)
				global_position = world.clamp_to_arena(spot)
				world.spawn_burst(global_position + Vector2(0, -60), _theme_color(), 16, 260.0)
				_visual.modulate.a = 1.0
				_state = "recover"
				_state_t = 0.5
			return Vector2.ZERO
		"recover":
			if _state_t <= 0.0:
				_state = "chase"
				_state_t = randf_range(1.2, 2.0)
			return dir * speed * 0.4
		"wind", "cast":
			if _state_t <= 0.0:
				_state = "recover"
				_state_t = 0.6
			return Vector2.ZERO
	return Vector2.ZERO


func _pick_attack(to_player: Vector2, dist: float) -> void:
	_cycle += 1
	var options: Array = []
	match kind:
		"dread_knight":
			options = ["slam", "burst", "charge"]
			if phase >= 2 and _cycle % 3 == 0:
				options.append("summon_ghouls")
			if dist < 220.0 and randf() < 0.6:
				options = ["slam"]
		"blood_witch":
			options = ["spiral", "pools", "spears", "blink"]
			if phase >= 2 and _cycle % 3 == 0:
				options.append("summon_bats")
			# Escapes melee only half the time so close-range heroes get a window.
			if dist < 180.0 and randf() < 0.5:
				options = ["blink"]
		"void_lord":
			options = ["void_orbs", "tentacles"]
			if phase >= 2:
				options += ["charge", "spiral"]
			if phase >= 3 and _cycle % 2 == 0:
				options += ["gravity", "summon_wraiths"]
	var pick: String = options[randi() % options.size()]
	var tel_time := 1.0 / _speed_mult()
	match pick:
		"slam":
			_state = "wind"
			_state_t = 0.9
			_circle_attack(global_position, 210.0, 0.9 * tel_time, damage * 1.5, Color(0.9, 0.15, 0.1))
		"charge":
			_state = "wind"
			_state_t = 0.7
			_charge_dir = to_player.normalized()
			var tel = FX.LineTelegraph.new()
			tel.length = 820.0 * 0.6
			tel.width = radius * 2.2
			tel.duration = 0.7 * tel_time
			tel.rotation = _charge_dir.angle()
			tel.position = global_position
			world.add_ground_fx(tel)
			get_tree().create_timer(0.7 * tel_time, false).timeout.connect(func() -> void:
				if not dead:
					_state = "charging"
					_state_t = 0.6
					Audio.play("dash", 2.0, 0.0))
		"burst":
			_state = "cast"
			_state_t = 0.8
			_burst(0.0, 16 if phase == 1 else 20, "orb_fast")
			if phase >= 2:
				get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
					if not dead:
						_burst(PI / 16.0, 20, "orb_fast"))
		"summon_ghouls":
			_summon("ghoul", 6)
		"spiral":
			_state = "cast"
			_state_t = 2.4
			_spiral_t = 2.2
			Audio.play("magic", 0.0, 0.0)
		"pools":
			_state = "cast"
			_state_t = 1.2
			var player: Node2D = world.player
			var count := 5 if phase == 1 else 7
			for i in count:
				var at: Vector2 = player.global_position
				if i > 0:
					at += Vector2.from_angle(randf() * TAU) * randf_range(90.0, 260.0)
				_circle_attack(at, 95.0, 1.05 * tel_time, damage * 1.2, Color(0.8, 0.05, 0.2))
		"spears":
			_state = "cast"
			_state_t = 1.0
			var base := to_player.angle()
			var spread := [-0.35, 0.0, 0.35] if phase == 1 else [-0.5, -0.25, 0.0, 0.25, 0.5]
			for off in spread:
				_spear(base + off, 0.7 * tel_time)
		"blink":
			_state = "blink"
			_state_t = 0.4
			Audio.play("dash", 0.0, 0.0)
		"summon_bats":
			_summon("bat", 5)
		"void_orbs":
			_state = "cast"
			_state_t = 1.0
			Audio.play("magic", 0.0, 0.0)
			var n := 6 if phase == 1 else 8
			for i in n:
				var d := Vector2.from_angle(TAU * i / n)
				world.spawn_enemy_projectile(global_position + Vector2(0, -70) + d * 50.0, d * 150.0, damage * 0.7, "void_orb")
		"tentacles":
			_state = "cast"
			_state_t = 1.3
			var player: Node2D = world.player
			var n := 5 if phase == 1 else 7
			for i in n:
				var at: Vector2 = player.global_position
				if i > 0:
					at += Vector2.from_angle(randf() * TAU) * randf_range(110.0, 340.0)
				_circle_attack(at, 100.0, 1.1 * tel_time, damage * 1.3, Color(0.55, 0.25, 1.0))
		"gravity":
			_state = "cast"
			_state_t = 2.6
			_pull_t = 2.5
			Audio.play("boss_roar", -2.0)
			world.spawn_ring(global_position, 420.0, Color(0.5, 0.2, 1.0), 1.0)
			for k in 3:
				get_tree().create_timer(0.6 + k * 0.7, false).timeout.connect(func() -> void:
					if not dead:
						_burst(k * 0.2, 14, "void_orb_fast"))
		"summon_wraiths":
			_summon("wraith", 4)


func _summon(minion: String, count: int) -> void:
	_state = "cast"
	_state_t = 0.9
	Audio.play("boss_roar", -4.0)
	for i in count:
		var p := global_position + Vector2.from_angle(TAU * i / count) * 130.0
		world.spawn_enemy_at(minion, p)


func _circle_attack(at: Vector2, r: float, delay: float, dmg: float, col: Color) -> void:
	var tel = FX.Telegraph.new()
	tel.radius = r
	tel.duration = delay
	tel.color = col
	tel.position = at
	tel.on_done = func() -> void:
		if dead:
			return
		Audio.play("explosion", -6.0)
		world.shake(5.0)
		world.spawn_ring(at, r, col.lightened(0.2), 0.35)
		var player: Node2D = world.player
		if is_instance_valid(player) and not player.dead and player.global_position.distance_to(at) < r + 14.0:
			player.take_damage(dmg, self)
	world.add_ground_fx(tel)


func _spear(angle: float, delay: float) -> void:
	var tel = FX.LineTelegraph.new()
	tel.length = 900.0
	tel.width = 36.0
	tel.duration = delay
	tel.color = Color(0.9, 0.05, 0.25)
	tel.rotation = angle
	tel.position = global_position
	world.add_ground_fx(tel)
	var from := global_position + Vector2(0, -40)
	get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		if not dead:
			Audio.play("arrow", 0.0, 0.0)
			world.spawn_enemy_projectile(from, Vector2.from_angle(angle) * 1000.0, damage * 1.1, "spear"))


func _burst(offset: float, count: int, proj: String) -> void:
	Audio.play("enemy_shot", 2.0)
	for i in count:
		var d := Vector2.from_angle(offset + TAU * i / count)
		world.spawn_enemy_projectile(global_position + Vector2(0, -60) + d * 30.0, d * 250.0, damage * 0.6, proj)


func _spiral_tick(delta: float) -> void:
	## Rotating arms of blood bullets.
	_spiral_angle += delta * 2.4
	if fmod(_spiral_t, 0.09) > delta:
		return
	var arms := 3 if phase == 1 else 4
	var proj := "blood" if kind == "blood_witch" else "void_orb_fast"
	for a in arms:
		var d := Vector2.from_angle(_spiral_angle + TAU * a / arms)
		world.spawn_enemy_projectile(global_position + Vector2(0, -60) + d * 30.0, d * 230.0, damage * 0.45, proj)


func die() -> void:
	_pull_t = 0.0
	super.die()


# ------------------------------------------------------------------ drawing
func draw_body(v: Node2D) -> void:
	match kind:
		"dread_knight":
			_draw_knight(v)
		"blood_witch":
			_draw_witch(v)
		"void_lord":
			_draw_void(v)


func _poly(v: Node2D, pts: Array, col: Color) -> void:
	var p := PackedVector2Array(pts)
	v.draw_colored_polygon(p, col)
	p.append(p[0])
	v.draw_polyline(p, Color(0.04, 0.03, 0.03, 0.9), 2.0, true)


func _shadow(v: Node2D, r: float) -> void:
	v.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.35))
	v.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.4))
	v.draw_set_transform(Vector2.ZERO)


func _draw_knight(v: Node2D) -> void:
	var t := _anim
	_shadow(v, 52.0)
	var plate := Color(0.2, 0.19, 0.22)
	var plate_hi := Color(0.38, 0.36, 0.42)
	var red := Color(0.85, 0.08, 0.12)
	var sway := sin(t * 2.0) * 4.0
	# Tattered cape.
	_poly(v, [Vector2(-24, -110), Vector2(20, -110), Vector2(34 + sway, -6), Vector2(18, -14),
		Vector2(6, -2), Vector2(-8, -12), Vector2(-24, 0), Vector2(-40 + sway, -10)], Color(0.2, 0.04, 0.07))
	_poly(v, [Vector2(-22, 0), Vector2(-18, -48), Vector2(-4, -48), Vector2(-6, 0)], plate)
	_poly(v, [Vector2(6, 0), Vector2(4, -48), Vector2(18, -48), Vector2(22, 0)], plate)
	_poly(v, [Vector2(-30, -46), Vector2(30, -46), Vector2(36, -108), Vector2(-36, -108)], plate)
	_poly(v, [Vector2(-12, -60), Vector2(12, -60), Vector2(16, -100), Vector2(-16, -100)], plate_hi)
	v.draw_circle(Vector2(0, -82), 7.0, red)
	v.draw_circle(Vector2(0, -82), 13.0, Color(1, 0.1, 0.1, 0.25 + 0.15 * sin(t * 4.0)))
	for side in [-1, 1]:
		_poly(v, [Vector2(26 * side, -98), Vector2(52 * side, -110), Vector2(46 * side, -88), Vector2(30 * side, -84)], plate_hi)
		_poly(v, [Vector2(40 * side, -106), Vector2(52 * side, -132), Vector2(48 * side, -104)], Color(0.6, 0.58, 0.6))
	_poly(v, [Vector2(-18, -108), Vector2(18, -108), Vector2(16, -140), Vector2(0, -150), Vector2(-16, -140)], plate)
	v.draw_line(Vector2(-10, -128), Vector2(14, -128), Color(1, 0.15, 0.1), 4.0)
	_poly(v, [Vector2(-14, -142), Vector2(-26, -162), Vector2(-8, -146)], Color(0.6, 0.58, 0.6))
	_poly(v, [Vector2(14, -142), Vector2(26, -162), Vector2(8, -146)], Color(0.6, 0.58, 0.6))
	# Giant cursed blade glowing red; raised during wind-ups.
	var ang := -0.5
	if _state == "wind":
		ang = -1.9
	elif _state == "recover" or _state == "charging":
		ang = 0.6
	v.draw_set_transform(Vector2(34, -74), ang)
	v.draw_line(Vector2(6, 0), Vector2(140, 0), Color(1, 0.1, 0.1, 0.25), 18.0)
	_poly(v, [Vector2(0, -8), Vector2(120, -10), Vector2(142, 0), Vector2(120, 10), Vector2(0, 8)], Color(0.3, 0.26, 0.3))
	v.draw_line(Vector2(6, 0), Vector2(130, 0), Color(1, 0.2, 0.15, 0.9), 4.0)
	v.draw_line(Vector2(0, -18), Vector2(0, 18), Color(0.55, 0.1, 0.12), 8.0)
	v.draw_set_transform(Vector2.ZERO)


func _draw_witch(v: Node2D) -> void:
	## Floating crimson sorceress with flowing red hair and a blood sigil.
	var t := _anim
	var hover := sin(t * 2.0) * 6.0 - 18.0
	_shadow(v, 40.0)
	var dress := Color(0.55, 0.04, 0.12)
	var dress_dark := Color(0.3, 0.02, 0.07)
	var skin := Color(0.93, 0.82, 0.78)
	var hair := Color(0.72, 0.1, 0.12)
	v.draw_set_transform(Vector2(0, hover))
	# Blood sigil behind her.
	v.draw_arc(Vector2(0, -90), 64.0, t, t + TAU, 48, Color(0.9, 0.1, 0.2, 0.35), 3.0, true)
	v.draw_arc(Vector2(0, -90), 48.0, -t * 1.3, -t * 1.3 + TAU, 48, Color(0.9, 0.1, 0.2, 0.25), 2.0, true)
	# Flowing hair behind.
	var hair_pts := PackedVector2Array([Vector2(-14, -128), Vector2(14, -128), Vector2(22, -96),
		Vector2(28 + sin(t * 3.0) * 6.0, -60), Vector2(10, -70), Vector2(-10, -70), Vector2(-28 + sin(t * 3.0 + 1.0) * 6.0, -58), Vector2(-22, -96)])
	v.draw_colored_polygon(hair_pts, hair)
	# Dress flaring into a tattered hem.
	var hem := PackedVector2Array([Vector2(-12, -96), Vector2(12, -96)])
	var segs := 8
	for i in segs + 1:
		var k := float(i) / segs
		var x := lerpf(34.0, -34.0, k) + sin(t * 3.0 + k * 5.0) * 4.0
		var y := -6.0 - (10.0 if i % 2 == 1 else 0.0)
		hem.append(Vector2(x, y))
	_poly(v, Array(hem), dress)
	_poly(v, [Vector2(-6, -94), Vector2(6, -94), Vector2(14, -16), Vector2(-14, -16)], dress_dark)
	# Corset and shoulders.
	_poly(v, [Vector2(-14, -118), Vector2(14, -118), Vector2(11, -94), Vector2(-11, -94)], dress)
	v.draw_line(Vector2(-12, -100), Vector2(12, -100), Color(0.85, 0.65, 0.3), 2.0)
	# Arms outstretched; one holds a blood orb.
	var reach := sin(t * 1.5) * 6.0
	v.draw_line(Vector2(-12, -114), Vector2(-44, -100 + reach), skin, 4.0, true)
	v.draw_line(Vector2(12, -114), Vector2(46, -122 - reach), skin, 4.0, true)
	var pulse := 1.0 + sin(t * 6.0) * 0.15
	v.draw_circle(Vector2(52, -126 - reach), 16.0 * pulse, Color(1, 0.1, 0.2, 0.3))
	v.draw_circle(Vector2(52, -126 - reach), 7.0, Color(1, 0.35, 0.4))
	# Head, crown and eyes.
	v.draw_circle(Vector2(0, -132), 11.0, skin)
	v.draw_colored_polygon(PackedVector2Array([Vector2(-12, -134), Vector2(-4, -146), Vector2(10, -144), Vector2(13, -132), Vector2(6, -138)]), hair)
	for i in 5:
		var x := -10.0 + i * 5.0
		v.draw_colored_polygon(PackedVector2Array([Vector2(x - 2, -143), Vector2(x, -154 - (4.0 if i == 2 else 0.0)), Vector2(x + 2, -143)]), Color(0.85, 0.65, 0.3))
	v.draw_circle(Vector2(-3, -132), 1.8, Color(1, 0.1, 0.1))
	v.draw_circle(Vector2(4, -132), 1.8, Color(1, 0.1, 0.1))
	# Floating blood spears circling her.
	for i in 4:
		var a := t * 0.9 + TAU * i / 4.0
		var p := Vector2(0, -90) + Vector2(cos(a) * 70.0, sin(a) * 26.0)
		v.draw_line(p, p + Vector2(0, -28), Color(0.85, 0.1, 0.2), 3.0, true)
		v.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -28), p + Vector2(0, -38), p + Vector2(4, -28)]), Color(1, 0.3, 0.35))
	v.draw_set_transform(Vector2.ZERO)


func _draw_void(v: Node2D) -> void:
	## Crowned shadow sovereign wreathed in purple flame, with writhing tentacles.
	var t := _anim
	_shadow(v, 64.0)
	var dark := Color(0.08, 0.05, 0.12)
	var purple := Color(0.55, 0.25, 1.0)
	# Black sun halo.
	v.draw_circle(Vector2(0, -150), 52.0, Color(0.02, 0.0, 0.04))
	v.draw_arc(Vector2(0, -150), 54.0, 0, TAU, 48, Color(purple.r, purple.g, purple.b, 0.6 + 0.3 * sin(t * 3.0)), 5.0, true)
	v.draw_circle(Vector2(0, -150), 70.0, Color(purple.r, purple.g, purple.b, 0.08))
	# Tentacles.
	for i in 6:
		var side := -1.0 if i < 3 else 1.0
		var base := Vector2(side * (14.0 + (i % 3) * 10.0), -20)
		var pts := PackedVector2Array()
		for k in 9:
			var f := float(k) / 8.0
			var x := base.x + side * f * (70.0 + (i % 3) * 20.0)
			var y := base.y + sin(t * 2.5 + i + f * 4.0) * 16.0 * f + f * 14.0
			pts.append(Vector2(x, y))
		v.draw_polyline(pts, dark, 11.0 - (i % 3) * 2.0, true)
		v.draw_polyline(pts, Color(purple.r, purple.g, purple.b, 0.5), 2.0, true)
	# Robed body.
	_poly(v, [Vector2(-46, -4), Vector2(46, -4), Vector2(30, -120), Vector2(-30, -120)], dark)
	_poly(v, [Vector2(-10, -110), Vector2(10, -110), Vector2(18, -10), Vector2(-18, -10)], Color(0.16, 0.08, 0.24))
	for side in [-1, 1]:
		_poly(v, [Vector2(24 * side, -118), Vector2(58 * side, -128), Vector2(50 * side, -100), Vector2(28 * side, -96)], Color(0.2, 0.12, 0.3))
	# Hood and crown.
	_poly(v, [Vector2(-24, -116), Vector2(24, -116), Vector2(20, -150), Vector2(0, -162), Vector2(-20, -150)], dark)
	v.draw_circle(Vector2(-7, -138), 3.0, Color(0.8, 0.5, 1.0))
	v.draw_circle(Vector2(7, -138), 3.0, Color(0.8, 0.5, 1.0))
	for i in 7:
		var x := -21.0 + i * 7.0
		var h := 16.0 + (10.0 if i == 3 else (5.0 if i % 2 == 0 else 0.0))
		v.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, -158), Vector2(x, -158 - h), Vector2(x + 3, -158)]), Color(0.75, 0.6, 0.85))
	# Void core.
	var pulse := 0.6 + 0.4 * sin(t * 5.0)
	v.draw_circle(Vector2(0, -78), 12.0, Color(0.85, 0.6, 1.0, pulse))
	v.draw_circle(Vector2(0, -78), 24.0, Color(purple.r, purple.g, purple.b, 0.2 * pulse))
	if _pull_t > 0.0:
		for i in 3:
			var r := fmod(t * 260.0 + i * 140.0, 420.0)
			v.draw_arc(Vector2(0, -40), 420.0 - r, 0, TAU, 48, Color(purple.r, purple.g, purple.b, 0.35 * r / 420.0), 3.0, true)
