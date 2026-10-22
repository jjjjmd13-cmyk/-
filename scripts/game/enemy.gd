extends CharacterBody2D
## Regular enemies, configured by `kind`. Bosses extend this in boss.gd.

signal died(enemy)

const FX := preload("res://scripts/game/fx.gd")
const SpriteSet := preload("res://scripts/game/sprite_set.gd")
## States during which sprite art plays its attack / cast animation.
const ACTION_STATES := ["windup", "charge", "fuse", "fade", "appear", "wind", "cast", "blink", "charging"]

const KINDS := {
	"ghoul": {"hp": 30.0, "speed": 108.0, "damage": 10.0, "radius": 17.0, "xp": 1},
	"bat": {"hp": 13.0, "speed": 170.0, "damage": 6.0, "radius": 12.0, "xp": 1},
	"archer": {"hp": 26.0, "speed": 96.0, "damage": 9.0, "radius": 16.0, "xp": 2,
		"range": 400.0, "shot_cd": 2.8},
	"brute": {"hp": 135.0, "speed": 72.0, "damage": 20.0, "radius": 27.0, "xp": 6},
	"cultist": {"hp": 44.0, "speed": 82.0, "damage": 12.0, "radius": 17.0, "xp": 3,
		"range": 440.0, "shot_cd": 3.2},
	"wraith": {"hp": 36.0, "speed": 100.0, "damage": 12.0, "radius": 16.0, "xp": 3},
	"bomber": {"hp": 42.0, "speed": 118.0, "damage": 26.0, "radius": 18.0, "xp": 3},
	"shield": {"hp": 95.0, "speed": 78.0, "damage": 16.0, "radius": 22.0, "xp": 5},
	"necro": {"hp": 62.0, "speed": 72.0, "damage": 10.0, "radius": 18.0, "xp": 6,
		"range": 480.0},
	"skeleton": {"hp": 18.0, "speed": 122.0, "damage": 8.0, "radius": 14.0, "xp": 0},
}

## Damage from the front is reduced by this much for shield bearers.
const SHIELD_BLOCK := 0.65
const BOMB_RADIUS := 115.0

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
var is_boss := false

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

# Shared state machine for brutes, wraiths, bombers, necromancers and bosses.
var _state := "chase"
var _state_t := 0.0
var _charge_dir := Vector2.ZERO
## Direction the shield bearer is facing (turns slowly so it can be flanked).
var _facing := Vector2.RIGHT
var _fuse_tel: Node2D
var _minions: Array = []


func _stats() -> Dictionary:
	return KINDS[kind]


func setup(p_kind: String, p_world: Node, hp_mult: float, dmg_mult: float, p_elite: bool) -> void:
	kind = p_kind
	world = p_world
	elite = p_elite
	var d: Dictionary = _stats()
	max_hp = d.hp * hp_mult * (3.2 if elite else 1.0)
	hp = max_hp
	speed = d.speed * randf_range(0.92, 1.08) * (1.1 if elite else 1.0)
	damage = d.damage * dmg_mult * (1.4 if elite else 1.0)
	radius = d.radius * (1.3 if elite else 1.0)
	xp = int(d.xp) * (5 if elite else 1)
	_shot_cd = randf_range(0.8, float(d.get("shot_cd", 2.0)))
	_wobble_seed = randf() * TAU
	if kind == "wraith":
		_state_t = randf_range(2.0, 4.0)
	elif kind == "necro":
		_state_t = randf_range(1.5, 3.0)


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
	var sprite := SpriteSet.make_sprite("bosses" if is_boss else "enemies", kind)
	if sprite:
		if elite:
			sprite.scale *= 1.3
		_visual.sprite = sprite
		_visual.add_child(sprite)


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
		desired = _think(to_player, dist, delta)

	velocity = desired + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	move_and_slide()

	if not is_instance_valid(player) or player.dead:
		return
	# Contact damage.
	var touch := _contact_damage()
	if touch > 0.0 and dist < radius + 20.0 and contact_cd <= 0.0 and stun <= 0.0:
		contact_cd = 0.9
		player.take_damage(touch, self)

	if absf(to_player.x) > 4.0 and kind != "shield":
		_visual.scale.x = signf(to_player.x)


## Damage dealt by touching the player (0 = harmless to touch).
func _contact_damage() -> float:
	match kind:
		"bomber":
			return 0.0
		"wraith":
			return damage if _state == "chase" else 0.0
	return damage


## Returns the desired velocity for this frame.
func _think(to_player: Vector2, dist: float, delta: float) -> Vector2:
	match kind:
		"archer", "cultist":
			return _ranged_ai(to_player, dist, delta)
		"brute":
			return _brute_ai(to_player, dist, delta)
		"bat":
			var side := to_player.orthogonal().normalized() * sin(_anim * 5.0 + _wobble_seed) * 0.7
			return (to_player.normalized() + side).normalized() * speed
		"wraith":
			return _wraith_ai(to_player, dist, delta)
		"bomber":
			return _bomber_ai(to_player, dist, delta)
		"shield":
			return _shield_ai(to_player, dist, delta)
		"necro":
			return _necro_ai(to_player, dist, delta)
	return to_player.normalized() * speed


func _ranged_ai(to_player: Vector2, dist: float, delta: float) -> Vector2:
	var d: Dictionary = _stats()
	var dir := to_player / maxf(dist, 1.0)
	_shot_cd -= delta
	if _shot_cd <= 0.0 and dist < d.range + 80.0:
		_shot_cd = d.shot_cd * randf_range(0.85, 1.15)
		if kind == "archer":
			world.spawn_enemy_projectile(global_position + Vector2(0, -30), dir * 330.0, damage, "arrow")
		else:
			world.spawn_enemy_projectile(global_position + Vector2(0, -40), dir * 210.0, damage, "orb")
	return _keep_range(dir, dist, d.range)


func _keep_range(dir: Vector2, dist: float, preferred: float) -> Vector2:
	# Keep at preferred range, strafing slightly.
	var strafe := dir.orthogonal() * sin(_anim * 0.8 + _wobble_seed) * 0.5
	if dist > preferred:
		return (dir + strafe * 0.3).normalized() * speed
	elif dist < preferred * 0.6:
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


func _wraith_ai(to_player: Vector2, dist: float, delta: float) -> Vector2:
	## Drifts toward the player, periodically vanishing and reappearing beside them.
	_state_t -= delta
	match _state:
		"fade":
			_visual.modulate.a = clampf(_state_t / 0.45, 0.0, 1.0) * 0.8
			if _state_t <= 0.0:
				var player: Node2D = world.player
				var spot: Vector2 = player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(130.0, 190.0)
				global_position = world.clamp_to_arena(spot)
				world.spawn_burst(global_position + Vector2(0, -30), Color(0.6, 0.75, 1.0), 10, 160.0)
				_state = "appear"
				_state_t = 0.45
			return Vector2.ZERO
		"appear":
			_visual.modulate.a = (1.0 - clampf(_state_t / 0.45, 0.0, 1.0)) * 0.8
			if _state_t <= 0.0:
				_state = "chase"
				_state_t = randf_range(3.5, 5.0)
			return Vector2.ZERO
	if _state_t <= 0.0 and dist > 160.0:
		_state = "fade"
		_state_t = 0.45
		return Vector2.ZERO
	var drift := to_player.orthogonal().normalized() * sin(_anim * 2.0 + _wobble_seed) * 0.4
	return (to_player.normalized() + drift).normalized() * speed


func _bomber_ai(to_player: Vector2, dist: float, _delta: float) -> Vector2:
	## Runs at the player, then stops and detonates after a visible fuse.
	if _state == "fuse":
		return Vector2.ZERO
	if dist < 95.0:
		_state = "fuse"
		Audio.play("enemy_shot", 0.0, 0.0)
		var tel = FX.Telegraph.new()
		tel.radius = BOMB_RADIUS
		tel.duration = 0.85
		tel.position = global_position
		tel.on_done = _explode
		world.add_ground_fx(tel)
		_fuse_tel = tel
		return Vector2.ZERO
	return to_player.normalized() * speed


func _explode() -> void:
	if dead:
		return
	_fuse_tel = null
	Audio.play("explosion", -2.0)
	world.shake(9.0)
	world.spawn_ring(global_position, BOMB_RADIUS, Color(1, 0.3, 0.15), 0.35)
	world.spawn_burst(global_position + Vector2(0, -20), Color(0.9, 0.15, 0.1), 18, 360.0)
	var player: Node2D = world.player
	if is_instance_valid(player) and not player.dead:
		if player.global_position.distance_to(global_position) < BOMB_RADIUS + 14.0:
			player.take_damage(damage, self)
	# The blast also hurts nearby monsters.
	for e in world.enemies_in_radius(global_position, BOMB_RADIUS):
		if e != self and not e.is_boss:
			world.damage_enemy(e, damage * 1.5, false, (e.global_position - global_position).normalized() * 200.0)
	xp = 0
	die()


func _shield_ai(to_player: Vector2, _dist: float, delta: float) -> Vector2:
	var want := to_player.normalized()
	# Turn slowly so dashing around the shield exposes its back.
	var ang := _facing.angle()
	ang = rotate_toward(ang, want.angle(), 1.6 * delta)
	_facing = Vector2.from_angle(ang)
	_visual.scale.x = 1.0 if _facing.x >= 0.0 else -1.0
	return want * speed


func _necro_ai(to_player: Vector2, dist: float, delta: float) -> Vector2:
	## Keeps its distance and keeps raising skeletons.
	_state_t -= delta
	_minions = _minions.filter(func(m) -> bool: return is_instance_valid(m) and not m.dead)
	if _state_t <= 0.0:
		_state_t = randf_range(4.5, 5.5)
		if _minions.size() < 6:
			Audio.play("magic", -6.0, 0.0)
			for i in 2:
				var p := global_position + Vector2.from_angle(randf() * TAU) * 60.0
				var m: Node = world.spawn_enemy_at("skeleton", p)
				_minions.append(m)
	return _keep_range(to_player / maxf(dist, 1.0), dist, _stats().range)


func hit(amount: float, knock: Vector2) -> float:
	## Applies damage and knockback; returns the damage actually taken.
	if kind == "shield" and knock.length() > 0.01 and knock.normalized().dot(_facing) < -0.4:
		amount *= 1.0 - SHIELD_BLOCK
		knock *= 0.2
		world.spawn_burst(global_position + _facing * 26.0 + Vector2(0, -34), Color(1, 0.85, 0.5), 3, 140.0)
	hp -= amount
	if kind == "brute" or kind == "shield":
		knock *= 0.35
	if elite:
		knock *= 0.5
	knockback += _scale_knockback(knock)
	_flash = 0.07
	_visual.material = Game.flash_material()
	return amount


func _scale_knockback(knock: Vector2) -> Vector2:
	return knock


func apply_bleed(dps: float) -> void:
	bleed_dps = maxf(bleed_dps, dps)
	if bleed_time <= 0.0:
		_bleed_tick = 0.5
	bleed_time = 2.5


func die() -> void:
	if dead:
		return
	dead = true
	if is_instance_valid(_fuse_tel):
		_fuse_tel.queue_free()
	died.emit(self)
	queue_free()


## Bosses draw themselves; overridden in boss.gd.
func draw_body(_v: Node2D) -> void:
	pass


## True for kinds whose drawing animates every frame.
func redraws_every_frame() -> bool:
	return kind in ["bat", "wraith", "bomber", "necro"]


## Draws the enemy. Static kinds draw once and animate via transform.
class Visual extends Node2D:
	var enemy: Node
	## Sprite-sheet art, when this kind has some (otherwise drawn in code).
	var sprite: AnimatedSprite2D

	func _process(_delta: float) -> void:
		var e = enemy
		if sprite:
			var action: bool = ACTION_STATES.has(e._state)
			if e._state == "intro":
				SpriteSet.play(sprite, "idle")
			elif action:
				SpriteSet.play(sprite, "cast" if e.is_boss else "attack")
			else:
				SpriteSet.play(sprite, "run")
			if e.elite:
				queue_redraw()
		elif e.redraws_every_frame():
			queue_redraw()
		# Cheap walk animation: bob and sway.
		var t: float = e._anim * 9.0 + e._wobble_seed
		match e.kind:
			"bat":
				position.y = sin(t * 0.5) * 6.0
			"wraith":
				position.y = sin(t * 0.3) * 5.0 - 6.0
			_:
				position.y = -absf(sin(t)) * 3.0
				rotation = sin(t) * 0.06

	func _draw() -> void:
		var e = enemy
		if sprite:
			draw_set_transform(Vector2(0, -position.y), 0.0, Vector2(1, 0.35))
			draw_circle(Vector2.ZERO, e.radius * 1.1, Color(0, 0, 0, 0.35))
			if e.elite:
				_elite_sigil(e.radius * 1.45, e._anim)
			draw_set_transform(Vector2.ZERO)
			return
		if e.is_boss:
			e.draw_body(self)
			return
		var r: float = e.radius
		var s: float = r / float(KINDS[e.kind].radius)
		# Shadow.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, r * 1.1, Color(0, 0, 0, 0.35 if e.kind != "wraith" else 0.15))
		if e.elite:
			_elite_sigil(r * 1.45, e._anim)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		match e.kind:
			"ghoul": _ghoul()
			"bat": _bat(e._anim)
			"archer": _archer()
			"brute": _brute()
			"cultist": _cultist()
			"wraith": _wraith(e._anim)
			"bomber": _bomber(e._anim, e._state == "fuse")
			"shield": _shield()
			"necro": _necro(e._anim)
			"skeleton": _skeleton()
		draw_set_transform(Vector2.ZERO)

	func _elite_sigil(r: float, t: float) -> void:
		## Golden rune circle under elites (drawn in the flattened shadow space).
		var gold := Color(1.0, 0.78, 0.32)
		draw_circle(Vector2.ZERO, r * 1.05, Color(1.0, 0.7, 0.2, 0.12))
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(gold.r, gold.g, gold.b, 0.95), 4.0, true)
		draw_arc(Vector2.ZERO, r * 0.78, 0, TAU, 40, Color(gold.r, gold.g, gold.b, 0.6), 2.0, true)
		for i in 12:
			var a := TAU * i / 12.0 + t * 0.6
			draw_line(Vector2.from_angle(a) * r * 0.8, Vector2.from_angle(a) * r * 0.98, gold, 2.0)

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

	func _wraith(t: float) -> void:
		## Pale blue spirit with a wispy, flowing tail.
		var body := Color(0.62, 0.74, 0.95, 0.55)
		var core := Color(0.82, 0.9, 1.0, 0.75)
		var tail := PackedVector2Array()
		for i in 7:
			var k := float(i) / 6.0
			tail.append(Vector2(-12 + 24 * k + sin(t * 5.0 + k * 6.0) * 3.0, -6 - sin(PI * k) * 4.0 + absf(sin(t * 4.0 + i)) * 6.0))
		var pts := PackedVector2Array([Vector2(-14, -40), Vector2(-9, -62), Vector2(0, -70), Vector2(10, -62), Vector2(14, -40)])
		for i in range(tail.size() - 1, -1, -1):
			pts.append(tail[i])
		pts.reverse()
		draw_colored_polygon(pts, body)
		draw_circle(Vector2(0, -56), 11.0, core)
		# Long trailing hair strands.
		for i in 4:
			var x := -10.0 + i * 6.0
			draw_line(Vector2(x, -64), Vector2(x - 8 + sin(t * 3.0 + i) * 4.0, -24), Color(0.85, 0.92, 1.0, 0.5), 2.0, true)
		draw_circle(Vector2(-3, -57), 2.4, Color(0.2, 0.5, 1.0))
		draw_circle(Vector2(4, -57), 2.4, Color(0.2, 0.5, 1.0))
		draw_circle(Vector2(0, -50), 22.0, Color(0.5, 0.7, 1.0, 0.08))
		# Reaching arms.
		draw_line(Vector2(8, -46), Vector2(24, -36 + sin(t * 3.0) * 3.0), core, 3.0, true)

	func _bomber(t: float, fuse: bool) -> void:
		## Bloated corpse with a pulsing red core; pulses fast while the fuse burns.
		var pulse := 0.5 + 0.5 * sin(t * (24.0 if fuse else 6.0))
		var flesh := Color(0.55, 0.3, 0.28)
		_poly([Vector2(-10, 0), Vector2(-6, -18), Vector2(0, -18), Vector2(-2, 0)], Color(0.35, 0.22, 0.2))
		_poly([Vector2(2, 0), Vector2(2, -18), Vector2(8, -18), Vector2(10, 0)], Color(0.35, 0.22, 0.2))
		draw_circle(Vector2(0, -36), 20.0 + pulse * (3.0 if fuse else 1.0), flesh)
		draw_arc(Vector2(0, -36), 20.0 + pulse * (3.0 if fuse else 1.0), 0, TAU, 24, Color(0.04, 0.03, 0.03), 2.0, true)
		# Cracks leaking light.
		for a in [0.3, 1.6, 2.7, 4.2, 5.4]:
			draw_line(Vector2(0, -36) + Vector2.from_angle(a) * 6.0, Vector2(0, -36) + Vector2.from_angle(a + 0.3) * 18.0,
				Color(1, 0.35 + 0.3 * pulse, 0.2), 2.0)
		draw_circle(Vector2(0, -36), 7.0 + pulse * 3.0, Color(1, 0.25, 0.15, 0.85))
		draw_circle(Vector2(0, -36), 26.0 + pulse * 6.0, Color(1, 0.15, 0.1, 0.12 + 0.2 * pulse))
		draw_circle(Vector2(6, -58), 8.0, flesh)
		draw_circle(Vector2(9, -60), 2.0, Color(1, 0.8, 0.3))

	func _shield() -> void:
		## Dark armoured soldier behind a tall tower shield (facing right).
		var plate := Color(0.2, 0.2, 0.23)
		var plate_hi := Color(0.36, 0.36, 0.4)
		_poly([Vector2(-12, 0), Vector2(-9, -26), Vector2(-1, -26), Vector2(-3, 0)], plate)
		_poly([Vector2(3, 0), Vector2(2, -26), Vector2(10, -26), Vector2(12, 0)], plate)
		_poly([Vector2(-14, -26), Vector2(14, -26), Vector2(16, -60), Vector2(-16, -60)], plate)
		draw_line(Vector2(-14, -44), Vector2(14, -44), Color(0.5, 0.1, 0.12), 3.0)
		# Helm with red visor slit.
		_poly([Vector2(-10, -60), Vector2(10, -60), Vector2(9, -78), Vector2(0, -84), Vector2(-9, -78)], plate_hi)
		draw_line(Vector2(0, -71), Vector2(9, -71), Color(1, 0.2, 0.15), 3.0)
		# Sword held low behind.
		draw_line(Vector2(-14, -40), Vector2(-30, -8), Color(0.75, 0.76, 0.8), 4.0, true)
		# Tower shield in front.
		_poly([Vector2(14, -78), Vector2(32, -74), Vector2(32, -12), Vector2(23, -2), Vector2(14, -10)], Color(0.28, 0.27, 0.3))
		draw_line(Vector2(15, -72), Vector2(31, -70), Color(0.6, 0.48, 0.3), 2.0)
		draw_line(Vector2(23, -74), Vector2(23, -8), Color(0.6, 0.48, 0.3), 2.0)
		draw_line(Vector2(15, -44), Vector2(31, -44), Color(0.6, 0.48, 0.3), 2.0)
		draw_circle(Vector2(23, -44), 4.0, Color(0.7, 0.12, 0.15))

	func _necro(t: float) -> void:
		## Skull-faced robed caster with a glowing red staff.
		var robe := Color(0.13, 0.08, 0.1)
		_poly([Vector2(-18, 0), Vector2(18, 0), Vector2(11, -50), Vector2(-11, -50)], robe)
		_poly([Vector2(-18, 0), Vector2(-6, 0), Vector2(-8, -30)], Color(0.45, 0.06, 0.1))
		_poly([Vector2(-12, -48), Vector2(-5, -72), Vector2(5, -74), Vector2(13, -48)], Color(0.1, 0.06, 0.08))
		draw_circle(Vector2(2, -58), 7.5, Color(0.86, 0.83, 0.74))
		draw_circle(Vector2(0, -59), 2.0, Color(1, 0.15, 0.1))
		draw_circle(Vector2(5, -59), 2.0, Color(1, 0.15, 0.1))
		# Staff with a pulsing skull-orb.
		draw_line(Vector2(18, 0), Vector2(18, -84), Color(0.3, 0.22, 0.18), 3.5, true)
		var pulse := 0.6 + 0.4 * sin(t * 4.0)
		draw_circle(Vector2(18, -90), 14.0 * pulse, Color(1, 0.1, 0.15, 0.25))
		draw_circle(Vector2(18, -90), 6.0, Color(1, 0.3, 0.3))
		draw_arc(Vector2(18, -90), 10.0, t * 2.0, t * 2.0 + 4.0, 10, Color(1, 0.2, 0.2, 0.8), 2.0, true)

	func _skeleton() -> void:
		var bone := Color(0.86, 0.83, 0.74)
		draw_line(Vector2(-4, -20), Vector2(-6, 0), bone, 3.0)
		draw_line(Vector2(4, -20), Vector2(6, 0), bone, 3.0)
		_poly([Vector2(-8, -20), Vector2(8, -20), Vector2(8, -40), Vector2(-8, -40)], Color(0.25, 0.2, 0.18))
		for i in 3:
			draw_line(Vector2(-6, -36 + i * 5), Vector2(6, -36 + i * 5), bone, 2.0)
		draw_circle(Vector2(1, -48), 8.0, bone)
		draw_circle(Vector2(4, -49), 2.0, Color(1, 0.2, 0.15))
		# Rusty blade.
		draw_line(Vector2(8, -32), Vector2(24, -50), Color(0.55, 0.4, 0.3), 3.0, true)
