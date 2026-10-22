extends Node2D
## Soul shard (experience) or health potion lying on the ground.

var world: Node
var kind := "xp"
var value := 1
var _vel := Vector2.ZERO
var _attracted := false
var _t := 0.0


func _ready() -> void:
	add_to_group("pickups")
	_t = randf() * TAU
	_vel = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 160.0)


func _process(delta: float) -> void:
	_t += delta
	var player: Node2D = world.player
	if not is_instance_valid(player) or player.dead:
		return
	var to := player.global_position + Vector2(0, -20) - global_position
	var dist := to.length()
	if not _attracted and (dist < player.pickup_range or world.vacuum):
		_attracted = true
	if _attracted:
		_vel = _vel.lerp(to.normalized() * (520.0 + _t * 40.0), clampf(8.0 * delta, 0.0, 1.0))
		_t += delta * 6.0
	else:
		_vel = _vel.move_toward(Vector2.ZERO, 400.0 * delta)
	position += _vel * delta
	if dist < 26.0:
		world.collect(self)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 3.0) * 3.0
	if kind == "potion":
		draw_set_transform(Vector2(0, -12 + bob))
		draw_circle(Vector2.ZERO, 18.0, Color(1, 0.2, 0.25, 0.2))
		draw_circle(Vector2(0, 2), 9.0, Color(0.85, 0.12, 0.18))
		draw_rect(Rect2(-3, -12, 6, 7), Color(0.85, 0.85, 0.9))
		draw_rect(Rect2(-4, -14, 8, 3), Color(0.5, 0.35, 0.2))
		draw_circle(Vector2(-3, 0), 2.5, Color(1, 0.7, 0.7))
		draw_set_transform(Vector2.ZERO)
		return
	var col := Color(0.35, 0.7, 1.0)
	var s := 6.0
	if value >= 20:
		col = Color(1.0, 0.75, 0.25)
		s = 11.0
	elif value >= 5:
		col = Color(0.9, 0.3, 0.45)
		s = 9.0
	elif value >= 2:
		col = Color(0.4, 0.95, 0.55)
		s = 7.5
	var c := Vector2(0, -8 + bob)
	draw_circle(c, s * 2.2, Color(col.r, col.g, col.b, 0.18))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s * 1.4), c + Vector2(s, 0), c + Vector2(0, s * 1.4), c + Vector2(-s, 0)]), col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s * 1.4), c + Vector2(s * 0.4, 0), c + Vector2(0, s * 0.5), c + Vector2(-s * 0.4, 0)]),
		Color(1, 1, 1, 0.55))
