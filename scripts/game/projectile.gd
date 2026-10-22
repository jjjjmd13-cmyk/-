extends Node2D
const ART := preload("res://scripts/game/combat_art.gd")
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

var _hit := {}
var _t := 0.0
var _trail: Array[Vector2] = []
var _aura: Sprite2D

func _ready() -> void:
	if kind == "orb" or kind == "wave":
		_aura = ART.stamp(self, "mage" if kind == "orb" else "knight", 2 if kind == "orb" else 1, 74 if kind == "orb" else 110)
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
	position += velocity * delta
	rotation = velocity.angle()
	if _aura:
		_aura.rotation = _t * 2 if kind == "orb" else 0.0
		_aura.modulate.a = 0.8 if kind == "orb" else (1.0 - _t / life) * 0.8
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
			if splash > 0.0:
				_explode(e)
			if pierce <= 0:
				_expire()
				return
			pierce -= 1
	queue_redraw()


func _explode(direct: Node) -> void:
	world.spawn_ring(global_position, splash, Color(0.55, 0.65, 1.0), 0.3)
	for e in world.enemies_in_radius(global_position, splash):
		if e != direct and not e.dead:
			world.player_hit_enemy(e, dmg_mult * 0.6, (e.global_position - global_position).normalized() * knockback)


func _expire() -> void:
	if kind == "orb":
		world.spawn_burst(global_position, Color(0.6, 0.7, 1.0), 8, 160.0)
	queue_free()


func _draw() -> void:
	var trail_color := Color(0.58, 0.9, 0.42)
	match kind:
		"dagger": trail_color = Color(0.9, 0.12, 0.26)
		"orb": trail_color = Color(0.5, 0.65, 1.0)
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
		"orb":
			var pulse := 1.0 + sin(_t * 30.0) * 0.15
			draw_circle(Vector2(-14, 0), 9.0, Color(0.4, 0.5, 1.0, 0.25))
			draw_circle(Vector2.ZERO, 18.0 * pulse, Color(0.45, 0.55, 1.0, 0.3))
			draw_circle(Vector2.ZERO, 10.0, Color(0.65, 0.75, 1.0))
			draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 1))
			for i in 4:
				var a := _t * 8.0 + i * TAU / 4.0
				draw_line(Vector2.ZERO, Vector2.from_angle(a) * 16.0, Color(1, 1, 1, 0.6), 1.5)
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
