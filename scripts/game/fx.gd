extends RefCounted
## Short-lived visual effects. Each class frees itself when finished.


## Crescent sword/dagger trail.
class Slash extends Node2D:
	var radius := 90.0
	var arc := deg_to_rad(140.0)
	var color := Color(1, 0.9, 0.8)
	var width := 22.0
	var life := 0.18
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		var sweep := arc * clampf(k * 2.2, 0.15, 1.0)
		var start := -arc / 2.0
		var alpha := 1.0 - k
		var steps := 18
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in steps + 1:
			var a := start + sweep * float(i) / steps
			# Thickest in the middle of the swept arc.
			var taper := maxf(sin(PI * float(i) / steps), 0.12)
			outer.append(Vector2.from_angle(a) * (radius + width * 0.25 * taper))
			inner.append(Vector2.from_angle(a) * (radius - width * taper))
		inner.reverse()
		var poly := outer + inner
		if poly.size() >= 3:
			draw_colored_polygon(poly, Color(color.r, color.g, color.b, 0.55 * alpha))
		draw_polyline(outer, Color(1, 1, 1, 0.85 * alpha), 3.0, true)


## Expanding shockwave ring.
class Ring extends Node2D:
	var radius := 150.0
	var color := Color(1, 0.8, 0.4)
	var life := 0.4
	var width := 10.0
	var filled := true
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		var r := radius * (0.25 + 0.75 * ease(k, 0.4))
		var a := 1.0 - k
		if filled:
			draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.18 * a))
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(color.r, color.g, color.b, 0.9 * a), width * (1.0 - k * 0.6), true)


## Burst of particles drawn as shrinking dots.
class Burst extends Node2D:
	var color := Color(0.6, 0.1, 0.1)
	var count := 10
	var speed := 260.0
	var life := 0.45
	var size := 6.0
	var gravity := 0.0
	var _parts: Array = []
	var _t := 0.0

	func _ready() -> void:
		for i in count:
			var dir := Vector2.from_angle(randf() * TAU)
			_parts.append({
				"p": Vector2.ZERO,
				"v": dir * speed * randf_range(0.35, 1.0),
				"s": size * randf_range(0.5, 1.2),
			})

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		for p in _parts:
			p.v *= 1.0 - 4.0 * delta
			p.v.y += gravity * delta
			p.p += p.v * delta
		queue_redraw()

	func _draw() -> void:
		var k := 1.0 - _t / life
		for p in _parts:
			draw_circle(p.p, p.s * k, Color(color.r, color.g, color.b, k))


## Floating damage number.
class DamageNumber extends Node2D:
	var text := ""
	var color := Color.WHITE
	var font_size := 26
	var life := 0.7
	var _t := 0.0
	var _vel := Vector2(0, -110)

	func _ready() -> void:
		_vel.x = randf_range(-40, 40)
		z_index = 50

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		position += _vel * delta
		_vel.y += 160.0 * delta
		queue_redraw()

	func _draw() -> void:
		var f: Font = Game.font_bold
		var k := _t / life
		var a := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
		var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - k * 6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string_outline(f, Vector2(-w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.8 * a))
		draw_string(f, Vector2(-w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.r, color.g, color.b, a))


## Danger zone shown before an attack lands. Calls `on_done` when it expires.
class Telegraph extends Node2D:
	var radius := 160.0
	var duration := 0.8
	var color := Color(0.9, 0.15, 0.1)
	var on_done: Callable
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			if on_done.is_valid():
				on_done.call()
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / duration
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.12))
		draw_circle(Vector2.ZERO, radius * k, Color(color.r, color.g, color.b, 0.22))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(color.r, color.g, color.b, 0.85), 3.0, true)


## Line telegraph for charges.
class LineTelegraph extends Node2D:
	var length := 600.0
	var width := 70.0
	var duration := 0.6
	var color := Color(0.9, 0.15, 0.1)
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / duration
		draw_rect(Rect2(0, -width / 2, length, width), Color(color.r, color.g, color.b, 0.12))
		draw_rect(Rect2(0, -width / 2, length * k, width), Color(color.r, color.g, color.b, 0.22))
		draw_rect(Rect2(0, -width / 2, length, width), Color(color.r, color.g, color.b, 0.8), false, 3.0)


## Falling star streak for the mage skill.
class StarStreak extends Node2D:
	var duration := 0.45
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / duration
		var start := Vector2(260, -900)
		var head := start.lerp(Vector2.ZERO, k * k)
		var tail := start.lerp(Vector2.ZERO, maxf(0.0, k * k - 0.25))
		draw_line(tail, head, Color(0.6, 0.7, 1.0, 0.5), 22.0, true)
		draw_line(tail, head, Color(1, 1, 1, 0.9), 8.0, true)
		draw_circle(head, 18.0, Color(0.85, 0.9, 1.0))
		draw_circle(head, 34.0, Color(0.5, 0.6, 1.0, 0.35))


## Ghostly afterimage left by dashes.
class Afterimage extends Node2D:
	var color := Color(0.6, 0.1, 0.15)
	var life := 0.25
	var texture: Texture2D
	var sprite_offset := Vector2.ZERO
	var sprite_scale := Vector2.ONE
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a := 0.45 * (1.0 - _t / life)
		if texture:
			draw_set_transform(Vector2.ZERO, 0.0, sprite_scale)
			draw_texture(texture, sprite_offset - texture.get_size() * 0.5, Color(color.r, color.g, color.b, a))
			return
		draw_colored_polygon(PackedVector2Array([
			Vector2(-16, 0), Vector2(16, 0), Vector2(12, -48), Vector2(0, -66), Vector2(-12, -48)]),
			Color(color.r, color.g, color.b, a))


## Lightweight animated heraldry. Geometry stays crisp at every area upgrade.
## Visual only: damage, cooldowns and enemy telegraphs are owned by gameplay.
class Sigil extends Node2D:
	var theme := "mage"
	var radius := 100.0
	var life := 0.65
	var intensity := 1.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / life, 0.0, 1.0)
		var fade := minf(k * 9.0, 1.0) * (1.0 - k) * intensity
		var r := radius * (0.78 + 0.22 * sin(k * PI * 0.5))
		var col := Color(0.6, 0.72, 1.0)
		match theme:
			"knight": col = Color(1.0, 0.76, 0.3)
			"ranger": col = Color(0.55, 0.9, 0.45)
			"rogue": col = Color(0.95, 0.16, 0.3)
		col.a = fade
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(col.r, col.g, col.b, fade * 0.2), 13.0, true)
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, col, 2.0, true)
		draw_arc(Vector2.ZERO, r * 0.83, -_t, TAU - _t, 64, col, 1.0, true)
		# Broken orbit and small angular runes instead of a solid opaque disk.
		for i in 12:
			var angle := TAU * i / 12.0 + _t * (0.45 if theme != "rogue" else -1.5)
			var dir := Vector2.from_angle(angle)
			var tangent := dir.orthogonal()
			var at := dir * r * 0.92
			draw_polyline(PackedVector2Array([at - tangent * 3.0, at + dir * 5.0,
				at + tangent * 3.0, at - dir * 3.0]), col, 1.5, true)
			draw_arc(Vector2.ZERO, r * 0.7, angle, angle + 0.25, 6, col, 2.0, true)
		match theme:
			"mage":
				# Six-point celestial seal and orbiting stars.
				for turn in 2:
					var points := PackedVector2Array()
					for i in 4:
						points.append(Vector2.from_angle(i * TAU / 3 + turn * PI + _t * 0.2) * r * 0.63)
					draw_polyline(points, col, 2.0, true)
				for i in 6:
					var at := Vector2.from_angle(i * TAU / 6 - _t) * r * 0.76
					draw_line(at - Vector2(4, 0), at + Vector2(4, 0), col, 1.5, true)
					draw_line(at - Vector2(0, 6), at + Vector2(0, 6), col, 1.5, true)
			"knight":
				# Crown, radiating mane and the central blade of judgment.
				for i in 16:
					var dir := Vector2.from_angle(i * TAU / 16)
					draw_line(dir * r * 0.38, dir * r * (0.62 if i % 2 == 0 else 0.5), col, 2.5, true)
				var crown := PackedVector2Array([Vector2(-.24, -.22), Vector2(-.3, -.48),
					Vector2(-.1, -.37), Vector2(0, -.59), Vector2(.1, -.37),
					Vector2(.3, -.48), Vector2(.24, -.22)])
				for j in crown.size():
					crown[j] *= r
				draw_polyline(crown, col, 2.5, true)
				draw_line(Vector2(0, -r * .22), Vector2(0, r * .5), col, 5.0, true)
				draw_line(Vector2(-r * .16, 0), Vector2(r * .16, 0), col, 3.0, true)
			"ranger":
				for i in 8:
					var dir := Vector2.from_angle(i * TAU / 8 + _t * .25)
					var at := dir * r * .5
					draw_line(dir * r * .22, dir * r * .67, col, 1.5, true)
					draw_colored_polygon(PackedVector2Array([at, at + dir.orthogonal() * r * .07,
						at + dir * r * .19, at - dir.orthogonal() * r * .07]), Color(col.r, col.g, col.b, fade * .5))
			"rogue":
				for i in 8:
					var dir := Vector2.from_angle(i * TAU / 8 - _t * 1.4)
					var side := dir.orthogonal() * r * .05
					draw_colored_polygon(PackedVector2Array([dir * r * .22 - side,
						dir * r * .22 + side, dir * r * .7]), col)
		# Outward sparks, deterministic so rendering does not alter gameplay RNG.
		for i in 18:
			var dir := Vector2.from_angle(i * 2.39996)
			var at := dir * r * (0.6 + k * (0.45 + (i % 3) * .1))
			draw_line(at, at + dir * (3.0 + 9.0 * k), Color(col.r, col.g, col.b, fade * .7), 1.5, true)


## Giant golden sword plunging from the sky (knight ultimate).
class SwordFall extends Node2D:
	var duration := 0.45
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / duration
		var y := lerpf(-900.0, -40.0, k * k)
		var gold := Color(1.0, 0.85, 0.4)
		draw_line(Vector2(0, y - 260), Vector2(0, y), Color(1, 0.9, 0.5, 0.25), 60.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-22, y - 220), Vector2(22, y - 220), Vector2(16, y - 20), Vector2(0, y + 30), Vector2(-16, y - 20)]),
			Color(0.95, 0.95, 1.0))
		draw_line(Vector2(0, y - 210), Vector2(0, y), Color(0.75, 0.75, 0.85), 4.0)
		draw_rect(Rect2(-70, y - 240, 140, 22), gold)
		draw_rect(Rect2(-12, y - 330, 24, 92), Color(0.55, 0.1, 0.12))
		draw_circle(Vector2(0, y - 340), 18.0, gold)
