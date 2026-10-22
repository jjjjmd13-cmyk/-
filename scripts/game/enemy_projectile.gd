extends Node2D
## Hostile projectile. Damages the player on contact.

var world: Node
var kind := "arrow"
var velocity := Vector2.ZERO
var damage := 8.0
var life := 4.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= life or not world.arena_rect.has_point(global_position):
		queue_free()
		return
	var player: Node2D = world.player
	if kind == "orb" and is_instance_valid(player) and not player.dead:
		# Cultist orbs gently seek the player.
		var want: Vector2 = (player.global_position + Vector2(0, -40) - global_position).normalized() * velocity.length()
		velocity = velocity.lerp(want, clampf(1.2 * delta, 0.0, 1.0))
	position += velocity * delta
	rotation = velocity.angle()
	if is_instance_valid(player) and not player.dead:
		var hit_r := 12.0 if kind == "arrow" else 16.0
		if global_position.distance_to(player.global_position + Vector2(0, -40)) < hit_r + 16.0:
			if player.take_damage(damage, self):
				queue_free()
				return
	queue_redraw()


func _draw() -> void:
	match kind:
		"arrow":
			draw_line(Vector2(-26, 0), Vector2(0, 0), Color(0.75, 0.7, 0.6), 2.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -4), Vector2(9, 0), Vector2(0, 4)]), Color(0.4, 0.9, 1.0))
		_:
			var pulse := 1.0 + sin(_t * 20.0) * 0.15
			var core := Color(1, 0.45, 0.9) if kind == "orb" else Color(1, 0.3, 0.25)
			draw_circle(Vector2.ZERO, 16.0 * pulse, Color(core.r, core.g * 0.5, core.b, 0.3))
			draw_circle(Vector2.ZERO, 9.0, core)
			draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.9))
