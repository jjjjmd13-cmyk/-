extends RefCounted
const ART := preload("res://scripts/game/combat_art.gd")
## Lingering ground effects created by hero skills. Each frees itself.


## Mage: pulls monsters toward its centre and damages them.
class GravityWell extends Node2D:
	var _vortex: Sprite2D

	func _ready() -> void:
		_vortex = ART.stamp(self, "mage", 3, radius * 2.5)
	var world: Node
	var radius := 190.0
	var duration := 3.0
	var dmg_mult := 0.6
	## Collapse branch: implodes for heavy damage when it ends.
	var collapse := false
	var _t := 0.0
	var _tick := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			world.spawn_ring(global_position, radius, Color(0.55, 0.6, 1.0), 0.35)
			if collapse:
				Audio.play("explosion", -2.0)
				world.shake(10.0)
				world.spawn_burst(global_position, Color(0.6, 0.65, 1.0), 26, 460.0)
				for e in world.enemies_in_radius(global_position, radius * 0.7):
					world.player_hit_enemy(e, 3.5, (e.global_position - global_position).normalized() * 400.0)
			queue_free()
			return
		_tick -= delta
		var hit_now := _tick <= 0.0
		if hit_now:
			_tick = 0.5
		for e in world.enemies_in_radius(global_position, radius):
			var to: Vector2 = global_position - e.global_position
			e.add_pull(to.normalized() * minf(320.0, to.length() * 4.0))
			if hit_now:
				world.player_hit_enemy(e, dmg_mult, Vector2.ZERO)
		if _vortex:
			_vortex.rotation = -_t * 0.65
			_vortex.modulate.a = minf(_t * 4, 0.38) * clampf((duration - _t) / 0.4, 0, 1)
		queue_redraw()

	func _draw() -> void:
		var fade := clampf((duration - _t) / 0.4, 0.0, 1.0) * clampf(_t / 0.2, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(0.25, 0.3, 0.9, 0.035 * fade))
		for i in 4:
			var pts := PackedVector2Array()
			for k in 24:
				var f := float(k) / 23.0
				var a := _t * 5.0 + i * TAU / 4.0 + f * 4.0
				pts.append(Vector2.from_angle(a) * radius * (1.0 - f * 0.9))
			draw_polyline(pts, Color(0.6, 0.7, 1.0, 0.2 * fade), 1.5, true)
		draw_circle(Vector2.ZERO, 16.0, Color(0.05, 0.05, 0.2, 0.9 * fade))
		draw_arc(Vector2.ZERO, 18.0, 0, TAU, 24, Color(0.8, 0.85, 1.0, fade), 3.0, true)


## Ranger: arrows rain on an area, damaging and slowing everything inside.
class ArrowRain extends Node2D:
	var world: Node
	var radius := 220.0
	var duration := 4.0
	var dmg_mult := 0.55
	var _t := 0.0
	var _tick := 0.0
	var _streaks: Array = []

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.25
			Audio.play("arrow", -10.0, 0.2)
			for e in world.enemies_in_radius(global_position, radius):
				world.player_hit_enemy(e, dmg_mult, Vector2.ZERO)
				e.apply_slow(0.5, 0.5)
		# Falling arrow streaks for the visual.
		for i in 3:
			var p := Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
			_streaks.append({"p": p, "t": 0.0})
		for s in _streaks:
			s.t += delta
		_streaks = _streaks.filter(func(s) -> bool: return s.t < 0.18)
		queue_redraw()

	func _draw() -> void:
		var fade := clampf((duration - _t) / 0.4, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(0.4, 0.7, 0.3, 0.025 * fade))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.6, 0.9, 0.4, 0.35 * fade), 1.5, true)
		for s in _streaks:
			var k: float = s.t / 0.18
			var head: Vector2 = s.p + Vector2(-30, -160) * (1.0 - k)
			var dir := Vector2(0.2, 1).normalized()
			draw_line(head - dir * 65, head, Color(0.5, 0.95, 0.37, 0.12 * fade), 9, true)
			draw_line(head - dir * 44, head, Color(0.84, 0.96, 0.64, 0.85 * fade), 2.0, true)
			draw_colored_polygon(PackedVector2Array([head + dir * 8, head - dir * 5 + dir.orthogonal() * 3, head - dir * 5 - dir.orthogonal() * 3]), Color(0.9, 1, 0.74, fade))
			if k > 0.85:
				draw_circle(s.p, 5.0, Color(0.9, 0.9, 0.7, 0.6 * fade))


## Ranger: snare left behind by the vault; roots monsters standing in it.
class Snare extends Node2D:
	var _leaves: Sprite2D
	var world: Node
	var radius := 130.0
	var duration := 2.6
	## Thorn Trap branch: also cuts whatever stands in it.
	var thorny := false
	var _t := 0.0
	var _tick := 0.5

	func _ready() -> void:
		_leaves = ART.stamp(self, "ranger", 3, radius * 2.2)
		_leaves.modulate.a = 0.24
		for e in world.enemies_in_radius(global_position, radius):
			world.player_hit_enemy(e, 1.0, Vector2.ZERO)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		_tick -= delta
		var cut := thorny and _tick <= 0.0
		if cut:
			_tick = 0.5
		for e in world.enemies_in_radius(global_position, radius):
			e.apply_root(0.25)
			if cut:
				world.player_hit_enemy(e, 0.45, Vector2.ZERO)
		queue_redraw()

	func _draw() -> void:
		var fade := clampf((duration - _t) / 0.4, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(0.3, 0.5, 0.2, 0.025 * fade))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(0.55, 0.85, 0.35, 0.3 * fade), 1.5, true)
		for i in 10:
			var a := TAU * i / 10.0 + _t * 0.5
			var base := Vector2.from_angle(a) * radius * 0.75
			draw_line(base, base + Vector2.from_angle(a + PI * 0.6) * 26.0, Color(0.5, 0.75, 0.3, 0.9 * fade), 3.0, true)


## Rogue: smoke cloud around the hero while they are hidden.
class Smoke extends Node2D:
	var _mist: Sprite2D
	var duration := 3.0
	var _t := 0.0
	var _puffs: Array = []

	func _ready() -> void:
		_mist = ART.stamp(self, "rogue", 3, 300)
		_mist.position.y = -30
		for i in 14:
			_puffs.append({"p": Vector2.from_angle(randf() * TAU) * randf_range(10.0, 90.0), "r": randf_range(30.0, 60.0), "s": randf() * TAU})

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var fade := clampf((duration - _t) / 0.8, 0.0, 1.0) * clampf(_t / 0.15, 0.0, 1.0)
		if _mist:
			_mist.modulate.a = 0.28 * fade
			_mist.rotation = _t * 0.3
		for p in _puffs:
			var drift := Vector2(sin(_t * 1.5 + p.s) * 10.0, -_t * 14.0)
			draw_circle(p.p + drift, p.r * (1.0 + _t * 0.15), Color(0.22, 0.2, 0.24, 0.35 * fade))


## Rogue Choking Smoke: a lingering cloud that hurts and slows.
class SmokeField extends Node2D:
	var world: Node
	var radius := 170.0
	var duration := 3.5
	var _t := 0.0
	var _tick := 0.0
	var _puffs: Array = []

	func _ready() -> void:
		for i in 16:
			_puffs.append({"p": Vector2.from_angle(randf() * TAU) * randf_range(0.0, radius * 0.8),
				"r": randf_range(34.0, 64.0), "s": randf() * TAU})

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.5
			for e in world.enemies_in_radius(global_position, radius):
				world.player_hit_enemy(e, 0.5, Vector2.ZERO)
				e.apply_slow(0.5, 0.6)
		queue_redraw()

	func _draw() -> void:
		var fade := clampf((duration - _t) / 0.6, 0.0, 1.0) * clampf(_t / 0.2, 0.0, 1.0)
		for p in _puffs:
			var drift := Vector2(sin(_t * 1.3 + p.s) * 12.0, cos(_t * 1.1 + p.s) * 6.0)
			draw_circle(p.p + drift, p.r, Color(0.2, 0.17, 0.2, 0.28 * fade))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(0.75, 0.2, 0.28, 0.35 * fade), 1.5, true)


## Mage Scorched Earth: burning ground left by Starfall.
class Burn extends Node2D:
	var world: Node
	var radius := 160.0
	var duration := 3.0
	var _t := 0.0
	var _tick := 0.25

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.5
			for e in world.enemies_in_radius(global_position, radius):
				world.player_hit_enemy(e, 0.4, Vector2.ZERO)
		queue_redraw()

	func _draw() -> void:
		var fade := clampf((duration - _t) / 0.6, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(0.9, 0.35, 0.1, 0.1 * fade))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 56, Color(1.0, 0.55, 0.2, 0.5 * fade), 2.0, true)
		for i in 12:
			var a := i * 2.39996
			var base := Vector2.from_angle(a) * radius * (0.2 + 0.7 * fmod(i * 0.37, 1.0))
			var h := 10.0 + 8.0 * sin(_t * 9.0 + i)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-5, 0), base + Vector2(0, -h), base + Vector2(5, 0)]),
				Color(1.0, 0.6 + 0.2 * sin(_t * 7.0 + i), 0.2, 0.7 * fade))
