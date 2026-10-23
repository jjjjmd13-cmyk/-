extends RefCounted
const ART := preload("res://scripts/game/combat_art.gd")
## Short-lived visual effects. Each class frees itself when finished.


## Crescent sword/dagger trail.
class Slash extends Node2D:
	var theme := "knight"
	var _blade: Sprite2D
	var _base_scale := Vector2.ONE

	func _ready() -> void:
		_blade = ART.stamp(self, theme, 1, radius * 2.6)
		_base_scale = _blade.scale
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
		if _blade:
			_blade.modulate.a = sin(k * PI) * 0.85
			_blade.rotation = -0.3 + k * 0.6
			_blade.scale = _base_scale * (0.8 + k * 0.3)
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
			draw_colored_polygon(poly, Color(color.r, color.g, color.b, 0.18 * alpha))
		draw_polyline(outer, Color(1, 1, 1, 0.65 * alpha), 1.8, true)


## Expanding shockwave ring.
class Ring extends Node2D:
	var _flare: Sprite2D
	var _base_scale := Vector2.ONE

	func _ready() -> void:
		_flare = ART.stamp(self, ART.color_theme(color), 2, radius * 2.6)
		_base_scale = _flare.scale
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
		if _flare:
			_flare.scale = _base_scale * (0.55 + 0.45 * k)
			_flare.modulate.a = a * 0.75
		if filled:
			draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.04 * a))
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(color.r, color.g, color.b, 0.9 * a), width * 0.38 * (1.0 - k * 0.6), true)


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
			draw_circle(p.p, p.s * k, Color(color.r, color.g, color.b, color.a * k))


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
	var hostile := true

	func _ready() -> void:
		z_as_relative = false
		z_index = 35 if hostile else -4
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
		var k := clampf(_t / duration, 0, 1)
		if not hostile:
			draw_circle(Vector2.ZERO, radius, Color(color, 0.045))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 72, Color(color, 0.45), 1.5, true)
			return
		# Quiet crimson boundary; urgency rises only in the final fifth.
		var urgency := smoothstep(0.78, 1.0, k)
		var edge := Color(0.85, 0.16, 0.19).lerp(Color(1.0, 0.42, 0.35), urgency)
		# Readable on the dark floor: a visible fill and a firm edge, brighter near impact.
		draw_circle(Vector2.ZERO, radius, Color(0.7, 0.05, 0.08, 0.12 + 0.08 * urgency))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 96, Color(edge, 0.18 + 0.12 * urgency), 6.0, true)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 96, Color(edge, 0.75 + 0.25 * urgency), 2.5, true)
		# Timing ring that grows to the edge: impact when it meets the boundary.
		if k > 0.02:
			draw_circle(Vector2.ZERO, radius * k, Color(0.8, 0.08, 0.1, 0.07))
			draw_arc(Vector2.ZERO, radius * k, 0, TAU, 72, Color(edge, 0.35 + 0.35 * urgency), 2.0, true)


## Line telegraph for charges.
class LineTelegraph extends Node2D:
	func _ready() -> void:
		z_as_relative = false
		z_index = 35
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
		var k := clampf(_t / duration, 0, 1)
		var rect := Rect2(0, -width / 2, length, width)
		var urgency := smoothstep(0.78, 1.0, k)
		var edge := Color(0.85, 0.16, 0.19).lerp(Color(1.0, 0.42, 0.35), urgency)
		draw_rect(rect, Color(0.7, 0.05, 0.08, 0.12 + 0.08 * urgency))
		draw_rect(Rect2(0, -width / 2, length * k, width), Color(0.8, 0.08, 0.1, 0.07))
		draw_rect(rect, Color(edge, 0.18 + 0.12 * urgency), false, 6.0, true)
		draw_rect(rect, Color(edge, 0.75 + 0.25 * urgency), false, 2.5, true)
		# Timing sweep: the charge starts when it reaches the far end.
		var x := length * k
		draw_line(Vector2(x, -width / 2), Vector2(x, width / 2), Color(edge, 0.25 + 0.3 * urgency), 2.0, true)


## Falling star streak for the mage skill.
class StarStreak extends Node2D:
	var _head: Sprite2D

	func _ready() -> void:
		_head = ART.stamp(self, "mage", 2, 125)
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
		if _head:
			_head.position = head
			_head.rotation = _t * 3
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


## Animated painted heraldry, additive so the ground and enemies remain visible.
class Sigil extends Node2D:
	var theme := "mage"
	var radius := 100.0
	var life := 0.65
	var intensity := 1.0
	var _t := 0.0
	var _seal: Sprite2D
	var _base_scale := Vector2.ONE

	func _ready() -> void:
		_seal = ART.stamp(self, theme, 0, radius * 2.35)
		_base_scale = _seal.scale
		_seal.modulate.a = 0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		var fade := clampf(_t / 0.12, 0, 1) * clampf((life - _t) / minf(0.5, life * 0.6), 0, 1)
		_seal.modulate.a = fade * intensity * (0.3 if life > 1 else 0.44)
		_seal.scale = _base_scale * (0.85 + 0.15 * minf(_t * 5, 1))
		_seal.rotation = _t * (-0.22 if theme == "rogue" else 0.10)
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		var fade := sin(PI * k) * intensity
		var col := Color(0.68, 0.77, 1.0, fade * 0.65)
		match theme:
			"knight": col = Color(1, 0.8, 0.38, fade * 0.65)
			"ranger": col = Color(0.64, 0.9, 0.46, fade * 0.65)
			"rogue": col = Color(1, 0.22, 0.31, fade * 0.65)
		for i in 14:
			var dir := Vector2.from_angle(i * 2.39996 + _t * 0.15)
			var at := dir * radius * (0.72 + k * 0.65)
			draw_line(at, at + dir * (2 + 8 * (1 - k)), col, 1.5, true)


## Giant golden sword plunging from the sky (knight ultimate).
class SwordFall extends Node2D:
	var duration := 0.45
	var _t := 0.0
	var _sword: Sprite2D

	func _ready() -> void:
		_sword = ART.stamp(self, "knight", 3, 550)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		var k := _t / duration
		_sword.position = Vector2(0, lerpf(-650, -170, k * k))
		_sword.modulate.a = minf(k * 4, 1)


## Mage basic attack: flash at the staff as the arcane bolt leaves.
class CastFlash extends Node2D:
	var life := 0.16
	var _t := 0.0

	func _ready() -> void:
		material = ART.additive()

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		var a := 1.0 - k
		draw_circle(Vector2.ZERO, 24.0 * (0.6 + k), Color(0.35, 0.45, 1.0, 0.35 * a))
		draw_circle(Vector2.ZERO, 11.0 * (1.0 - k * 0.6), Color(0.85, 0.9, 1.0, a))
		for i in 5:
			var dir := Vector2.from_angle((i - 2) * 0.32)
			draw_line(dir * 8.0, dir * (16.0 + 26.0 * k), Color(0.7, 0.8, 1.0, 0.8 * a), 2.0, true)


## Mage basic attack impact: white flash, star rays and an arcane ring the size of the splash.
class ArcaneBurst extends Node2D:
	var radius := 70.0
	var life := 0.34
	var _t := 0.0
	var _rays: Array = []

	func _ready() -> void:
		material = ART.additive()
		for i in 9:
			_rays.append({"a": i * TAU / 9.0 + randf_range(-0.2, 0.2), "l": randf_range(0.55, 1.0)})

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		var a := 1.0 - k
		var grow := ease(k, 0.35)
		draw_circle(Vector2.ZERO, 30.0 * (1.0 - k), Color(1, 1, 1, a * a))
		draw_circle(Vector2.ZERO, radius * grow, Color(0.3, 0.4, 1.0, 0.12 * a))
		draw_arc(Vector2.ZERO, radius * grow, 0, TAU, 48, Color(0.65, 0.78, 1.0, 0.9 * a), 3.5 * a + 1.0, true)
		for r in _rays:
			var dir := Vector2.from_angle(r.a)
			var outer: float = radius * r.l * (0.35 + 0.75 * grow)
			draw_line(dir * outer * 0.45, dir * outer, Color(0.85, 0.9, 1.0, a), 2.5 * a + 0.5, true)
