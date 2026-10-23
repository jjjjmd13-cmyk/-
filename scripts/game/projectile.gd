extends Node2D
const ART := preload("res://scripts/game/combat_art.gd")
const FX := preload("res://scripts/game/fx.gd")
## Player projectile: arrows, star orbs, thrown daggers and cleave waves.

var world: Node
var kind := "arrow"
var velocity := Vector2.ZERO
var dmg_mult := 1.0
var pierce := 0
var life := 1.2
var radius := 10.0
var splash := 0.0
var homing := 0.0
var knockback := 80.0
## Slow applied to every enemy hit (0 = none).
var slow := 0.0

var _hit := {}
var _t := 0.0
var _trail: Array[Vector2] = []
var _aura: Sprite2D
## Arcane bolt glitter left behind in world space: {p, v, t}.
var _sparks: Array = []

func _ready() -> void:
	if kind == "orb":
		material = ART.additive()
		_aura = ART.stamp(self, "mage", 2, 58)
		_aura.modulate.a = 0.6
	elif kind == "wave":
		_aura = ART.stamp(self, "knight", 1, 110)
		_aura.modulate.a = 0.8



func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		_expire()
		return
	if homing > 0.0:
		var target: Node2D = world.nearest_enemy(global_position, 380.0)
		if target:
			var want: Vector2 = (target.global_position + Vector2(0, -30) - global_position).normalized() * velocity.length()
			velocity = velocity.lerp(want, clampf(homing * delta, 0.0, 1.0))
	_trail.append(global_position)
	if _trail.size() > 9:
		_trail.pop_front()
	if kind == "orb":
		for i in 2:
			_sparks.append({"p": global_position + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
				"v": Vector2.from_angle(randf() * TAU) * randf_range(10, 50) - velocity * 0.05, "t": 0.0})
		for sp in _sparks:
			sp.t += delta
			sp.p += sp.v * delta
		_sparks = _sparks.filter(func(sp) -> bool: return sp.t < 0.32)
	position += velocity * delta
	rotation = velocity.angle()
	if _aura:
		_aura.rotation = _t * 2 if kind == "orb" else 0.0
		_aura.modulate.a = 0.6 if kind == "orb" else (1.0 - _t / life) * 0.8
	if not world.arena_rect.has_point(global_position):
		_expire()
		return
	# Iterate a snapshot: hits can kill enemies and remove them from the list.
	for e in world.enemies.duplicate():
		if e.dead or _hit.has(e):
			continue
		var center: Vector2 = e.global_position + Vector2(0, -e.radius)
		if center.distance_squared_to(global_position) < (radius + e.radius) * (radius + e.radius):
			_hit[e] = true
			world.player_hit_enemy(e, dmg_mult, velocity.normalized() * knockback)
			if slow > 0.0 and not e.dead:
				e.apply_slow(slow, 1.2)
			if splash > 0.0:
				_explode(e)
			if pierce <= 0:
				_expire()
				return
			pierce -= 1
	queue_redraw()


func _explode(direct: Node) -> void:
	if kind == "orb":
		var burst := FX.ArcaneBurst.new()
		burst.position = global_position
		burst.radius = splash
		world.add_top_fx(burst)
		world.spawn_burst(global_position, Color(0.6, 0.72, 1.0), 10, 300.0)
		Audio.play("bolt_hit", -5.0, 0.08)
	else:
		world.spawn_ring(global_position, splash, Color(1.0, 0.7, 0.35), 0.35)
		world.spawn_burst(global_position, Color(1.0, 0.65, 0.3), 12, 320.0)
		Audio.play("explosion", -8.0, 0.1)
	for e in world.enemies_in_radius(global_position, splash):
		if e != direct and not e.dead:
			world.player_hit_enemy(e, dmg_mult * 0.6, (e.global_position - global_position).normalized() * knockback)


func _expire() -> void:
	if kind == "orb" and _hit.is_empty():
		# Fizzles out without a target.
		world.spawn_burst(global_position, Color(0.6, 0.7, 1.0), 6, 120.0)
	queue_free()


func _draw() -> void:
	if kind == "orb":
		_draw_bolt()
		return
	var trail_color := Color(0.58, 0.9, 0.42)
	match kind:
		"dagger": trail_color = Color(0.9, 0.12, 0.26)
		"wave": trail_color = Color(1.0, 0.8, 0.35)
	for i in range(1, _trail.size()):
		var alpha := float(i) / _trail.size()
		var a := to_local(_trail[i - 1])
		var b := to_local(_trail[i])
		draw_line(a, b, Color(trail_color.r, trail_color.g, trail_color.b, alpha * 0.12), 16.0 * alpha, true)
		draw_line(a, b, Color(trail_color.r, trail_color.g, trail_color.b, alpha * 0.75), 2.5 * alpha, true)
	match kind:
		"arrow":
			draw_line(Vector2(-34, 0), Vector2(0, 0), Color(0.5, 0.36, 0.22), 3.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -5), Vector2(12, 0), Vector2(0, 5)]), Color(0.85, 0.86, 0.9))
			draw_colored_polygon(PackedVector2Array([Vector2(-34, 0), Vector2(-42, -6), Vector2(-28, 0), Vector2(-42, 6)]), Color(0.95, 0.93, 0.88))
			draw_line(Vector2(-60, 0), Vector2(-36, 0), Color(1, 1, 1, 0.15), 3.0)
		"dagger":
			draw_set_transform(Vector2.ZERO, _t * 25.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-4, -3), Vector2(14, -2), Vector2(20, 0), Vector2(14, 2), Vector2(-4, 3)]), Color(0.85, 0.87, 0.92))
			draw_line(Vector2(-4, -6), Vector2(-4, 6), Color(0.66, 0.52, 0.34), 3.0)
			draw_line(Vector2(-10, 0), Vector2(-4, 0), Color(0.58, 0.08, 0.13), 3.0)
			draw_set_transform(Vector2.ZERO)
		"wave":
			var k := 1.0 - _t / life
			var col := Color(1, 0.9, 0.7, 0.75 * k)
			draw_arc(Vector2.ZERO, radius, -1.1, 1.1, 16, col, 8.0, true)
			draw_arc(Vector2(-6, 0), radius, -0.9, 0.9, 16, Color(1, 1, 1, 0.5 * k), 3.0, true)


func _draw_bolt() -> void:
	# Arcane comet: tapered blue tail, white-hot head, glitter in its wake.
	for sp in _sparks:
		var k: float = 1.0 - sp.t / 0.32
		var at := to_local(sp.p)
		var s := 4.0 * k
		draw_line(at - Vector2(s, 0), at + Vector2(s, 0), Color(0.75, 0.85, 1.0, k), 1.5)
		draw_line(at - Vector2(0, s), at + Vector2(0, s), Color(0.75, 0.85, 1.0, k), 1.5)
	var pulse := 1.0 + sin(_t * 40.0) * 0.1
	draw_colored_polygon(PackedVector2Array([Vector2(6, -11), Vector2(-78, 0), Vector2(6, 11)]),
		Color(0.3, 0.4, 1.0, 0.35))
	draw_colored_polygon(PackedVector2Array([Vector2(4, -6), Vector2(-48, 0), Vector2(4, 6)]),
		Color(0.7, 0.8, 1.0, 0.75))
	draw_circle(Vector2.ZERO, 17.0 * pulse, Color(0.35, 0.45, 1.0, 0.35))
	draw_circle(Vector2.ZERO, 9.0 * pulse, Color(0.75, 0.85, 1.0))
	draw_circle(Vector2(1, 0), 5.0, Color(1, 1, 1))
	for i in 2:
		var a := _t * 22.0 + i * PI
		draw_circle(Vector2.from_angle(a) * Vector2(9, 14), 2.2, Color(0.9, 0.95, 1.0, 0.9))
