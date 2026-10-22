extends Node2D
## Hostile projectile. Damages the player on contact.
## Kinds: arrow, orb (homing), orb_fast, spear, blood, void_orb (homing), void_orb_fast.

const HOMING := {"orb": 1.2, "void_orb": 0.9}

var world: Node
var kind := "arrow"
var velocity := Vector2.ZERO
var damage := 8.0
var life := 4.0
var _t := 0.0


func _ready() -> void:
	if kind == "void_orb":
		life = 6.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= life or not world.arena_rect.has_point(global_position):
		queue_free()
		return
	var player: Node2D = world.player
	if HOMING.has(kind) and is_instance_valid(player) and not player.dead:
		# Orbs gently seek the player.
		var want: Vector2 = (player.global_position + Vector2(0, -40) - global_position).normalized() * velocity.length()
		velocity = velocity.lerp(want, clampf(HOMING[kind] * delta, 0.0, 1.0))
	position += velocity * delta
	rotation = velocity.angle()
	if is_instance_valid(player) and not player.dead:
		var hit_r := 16.0
		match kind:
			"arrow", "spear":
				hit_r = 12.0
			"blood", "void_orb_fast":
				hit_r = 11.0
		if global_position.distance_to(player.global_position + Vector2(0, -40)) < hit_r + 16.0:
			if player.take_damage(damage, self):
				queue_free()
				return
	queue_redraw()


func _draw() -> void:
	match kind:
		"arrow":
			# Bigger, glowing arrow so it reads clearly on the detailed floor.
			draw_line(Vector2(-44, 0), Vector2(4, 0), Color(0.3, 0.85, 1.0, 0.22), 12.0, true)
			draw_line(Vector2(-36, 0), Vector2(0, 0), Color(0.92, 0.88, 0.78), 3.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(15, 0), Vector2(0, 7)]), Color(0.45, 0.95, 1.0))
			draw_circle(Vector2(6, 0), 9.0, Color(0.4, 0.9, 1.0, 0.25))
		"spear":
			draw_line(Vector2(-70, 0), Vector2(0, 0), Color(1, 0.1, 0.2, 0.3), 12.0, true)
			draw_line(Vector2(-60, 0), Vector2(0, 0), Color(0.85, 0.1, 0.18), 4.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(18, 0), Vector2(0, 7)]), Color(1, 0.4, 0.45))
		"blood":
			draw_circle(Vector2.ZERO, 12.0, Color(0.9, 0.05, 0.15, 0.3))
			draw_circle(Vector2.ZERO, 6.0, Color(0.95, 0.15, 0.25))
			draw_circle(Vector2(-2, -2), 2.0, Color(1, 0.7, 0.7))
		"void_orb", "void_orb_fast":
			var pulse := 1.0 + sin(_t * 14.0) * 0.15
			var big := kind == "void_orb"
			draw_circle(Vector2.ZERO, (20.0 if big else 13.0) * pulse, Color(0.5, 0.2, 1.0, 0.3))
			draw_circle(Vector2.ZERO, 10.0 if big else 6.0, Color(0.12, 0.02, 0.2))
			draw_arc(Vector2.ZERO, 10.0 if big else 6.0, 0, TAU, 20, Color(0.75, 0.5, 1.0), 2.0, true)
		_:
			var pulse := 1.0 + sin(_t * 20.0) * 0.15
			var core := Color(1, 0.45, 0.9) if kind == "orb" else Color(1, 0.3, 0.25)
			draw_circle(Vector2.ZERO, 16.0 * pulse, Color(core.r, core.g * 0.5, core.b, 0.3))
			draw_circle(Vector2.ZERO, 9.0, core)
			draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.9))
