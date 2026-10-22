extends Node2D
## Procedurally drawn hero sprite. Origin is at the feet.
## Palettes and silhouettes follow the hero concept art.

const PALETTES := {
	"rogue": {
		"cape": Color(0.13, 0.1, 0.1), "lining": Color(0.58, 0.08, 0.13),
		"body": Color(0.2, 0.16, 0.15), "body_dark": Color(0.12, 0.09, 0.09),
		"trim": Color(0.66, 0.52, 0.34), "skin": Color(0.9, 0.74, 0.64),
		"hair": Color(0.24, 0.16, 0.12), "boot": Color(0.16, 0.12, 0.11),
	},
	"mage": {
		"cape": Color(0.17, 0.2, 0.46), "lining": Color(0.9, 0.87, 0.8),
		"body": Color(0.88, 0.85, 0.78), "body_dark": Color(0.2, 0.2, 0.42),
		"trim": Color(0.88, 0.72, 0.4), "skin": Color(0.95, 0.82, 0.74),
		"hair": Color(0.86, 0.76, 0.56), "boot": Color(0.18, 0.15, 0.16),
	},
	"ranger": {
		"cape": Color(0.29, 0.34, 0.2), "lining": Color(0.2, 0.25, 0.14),
		"body": Color(0.38, 0.25, 0.17), "body_dark": Color(0.25, 0.16, 0.11),
		"trim": Color(0.78, 0.62, 0.36), "skin": Color(0.9, 0.73, 0.6),
		"hair": Color(0.42, 0.27, 0.16), "boot": Color(0.27, 0.17, 0.12),
	},
	"knight": {
		"cape": Color(0.58, 0.1, 0.13), "lining": Color(0.4, 0.06, 0.09),
		"body": Color(0.74, 0.76, 0.8), "body_dark": Color(0.32, 0.33, 0.37),
		"trim": Color(0.88, 0.71, 0.38), "skin": Color(0.88, 0.7, 0.58),
		"hair": Color(0.3, 0.2, 0.13), "boot": Color(0.4, 0.41, 0.45),
	},
}
const OUTLINE := Color(0.05, 0.03, 0.03, 0.9)
const ART := preload("res://scripts/game/combat_art.gd")
const SpriteSet := preload("res://scripts/game/sprite_set.gd")

var hero_id := "knight"
var facing := 1.0
var aim_angle := 0.0
var moving := false
var walk_phase := 0.0
## 0..1 progress of the current attack animation, or -1 when idle.
var attack_t := -1.0
var attack_arc := deg_to_rad(150.0)
var flash := 0.0
var dashing := false
var invuln_blink := false
var time := 0.0
## Colour of the ring under the hero's feet that keeps them visible in crowds.
var ring_color := Color(0, 0, 0, 0)
## Which one-shot animation the current attack_t refers to: "attack" or "skill".
var action_anim := "attack"
## Seconds the current attack animation should last (sprite art is retimed to fit).
var action_len := 0.25
var dead := false
## 0..1 fill of the hero's barrier, drawn as a faint bubble.
var shield_frac := 0.0
var stealth_alpha := 1.0

var _p: Dictionary
## Sprite-sheet art, when the hero has some (otherwise the hero is drawn in code).
var _sprite: AnimatedSprite2D
var _last_attack_t := -1.0


func _ready() -> void:
	_p = PALETTES[hero_id]
	_sprite = SpriteSet.make_sprite("heroes", hero_id)
	if _sprite:
		_sprite.use_parent_material = false
		_sprite.material = ART.actor_material(true)
		add_child(_sprite)


func has_sprite() -> bool:
	return _sprite != null


func _process(delta: float) -> void:
	time += delta
	if moving:
		walk_phase += delta * 11.0
	if _sprite:
		_update_sprite()
	queue_redraw()


func _update_sprite() -> void:
	_sprite.flip_h = facing < 0.0
	(_sprite.material as ShaderMaterial).set_shader_parameter("hit_flash", 1.0 if flash > 0.35 else 0.0)
	if dead:
		SpriteSet.play(_sprite, "death")
		return
	if dashing:
		SpriteSet.play(_sprite, "dash")
	elif attack_t >= 0.0:
		# A new swing restarts the animation even if the previous one was still playing.
		if attack_t < _last_attack_t or _last_attack_t < 0.0:
			_sprite.stop()
		SpriteSet.play(_sprite, action_anim, action_len)
	elif moving:
		SpriteSet.play(_sprite, "run")
	else:
		SpriteSet.play(_sprite, "idle")
	_last_attack_t = attack_t


func _c(col: Color) -> Color:
	if flash > 0.0:
		return col.lerp(Color.WHITE, flash)
	return col


func _draw() -> void:
	if _p.is_empty():
		_p = PALETTES[hero_id]
	if invuln_blink and int(time * 20.0) % 2 == 0:
		modulate.a = 0.45 * stealth_alpha
	else:
		modulate.a = stealth_alpha
	var bob := absf(sin(walk_phase)) * -3.0 if moving else sin(time * 2.2) * 1.0
	# Shadow.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if shield_frac > 0.01:
		var c := Vector2(0, -52)
		draw_circle(c, 58.0, Color(0.45, 0.65, 1.0, 0.07 + 0.06 * shield_frac))
		draw_arc(c, 58.0, -PI / 2, -PI / 2 + TAU * shield_frac, 48, Color(0.6, 0.8, 1.0, 0.55), 2.5, true)
	if _sprite:
		return

	var aim_dir := Vector2.from_angle(aim_angle)
	# Weapons held "behind" the body when aiming upward.
	var weapon_behind := aim_dir.y < -0.35
	if weapon_behind:
		_draw_weapon(bob)

	draw_set_transform(Vector2(0, bob), 0.0, Vector2(facing, 1))
	_draw_cape(bob)
	_draw_legs(bob)
	if hero_id == "ranger":
		_draw_quiver()
	_draw_torso()
	_draw_head()
	draw_set_transform(Vector2.ZERO)

	if not weapon_behind:
		_draw_weapon(bob)


# ------------------------------------------------------------------ body parts
func _draw_cape(_bob: float) -> void:
	var sway := sin(time * 3.0 + walk_phase * 0.5) * 3.0
	var trail := 8.0 if moving else 0.0
	var top_l := Vector2(-13, -70)
	var top_r := Vector2(9, -70)
	var length := 62.0
	if hero_id == "mage":
		length = 68.0
	var pts := PackedVector2Array([top_r, top_l])
	var bottom_y := -70.0 + length
	var left_x := -22.0 - trail + sway
	pts.append(Vector2(left_x + 2, -40))
	# Tattered hem.
	var segs := 7
	for i in segs + 1:
		var k := float(i) / segs
		var x := lerpf(left_x, 8.0 - trail * 0.3, k)
		var y := bottom_y - (8.0 if i % 2 == 1 else 0.0) - sin(time * 4.0 + i) * 2.0
		pts.append(Vector2(x, y))
	pts.append(Vector2(10, -40))
	draw_colored_polygon(pts, _c(_p.cape))
	draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 2.0, true)
	# Lining visible on the inner edge.
	var lining := PackedVector2Array([
		Vector2(-12, -66), Vector2(-17 - trail * 0.6 + sway, -36),
		Vector2(-16 - trail + sway, bottom_y - 4), Vector2(-9 - trail * 0.7 + sway, bottom_y - 10),
		Vector2(-8, -40)])
	draw_colored_polygon(lining, _c(_p.lining))


func _draw_legs(_bob: float) -> void:
	var swing := sin(walk_phase) * 9.0 if moving else 0.0
	var lift_a := maxf(0.0, sin(walk_phase)) * 4.0 if moving else 0.0
	var lift_b := maxf(0.0, -sin(walk_phase)) * 4.0 if moving else 0.0
	var leg_col: Color = _p.body_dark
	if hero_id == "mage":
		# Long robe covers the legs; only boots peek out.
		_boot(Vector2(-6 + swing * 0.5, -lift_a))
		_boot(Vector2(7 - swing * 0.5, -lift_b))
		var robe := PackedVector2Array([
			Vector2(-11, -42), Vector2(11, -42), Vector2(18, -6), Vector2(4, -10),
			Vector2(-4, -5), Vector2(-17, -8)])
		draw_colored_polygon(robe, _c(_p.body))
		draw_polyline(robe + PackedVector2Array([robe[0]]), OUTLINE, 2.0, true)
		var panel := PackedVector2Array([Vector2(-4, -42), Vector2(5, -42), Vector2(9, -9), Vector2(-7, -8)])
		draw_colored_polygon(panel, _c(_p.body_dark))
		draw_line(Vector2(-4, -42), Vector2(-7, -8), _c(_p.trim), 1.5)
		draw_line(Vector2(5, -42), Vector2(9, -9), _c(_p.trim), 1.5)
		return
	for side in [-1, 1]:
		var off: float = swing * side
		var lift: float = lift_a if side == -1 else lift_b
		var hip := Vector2(6 * side, -40)
		var foot := Vector2(6 * side + off, -lift)
		var knee := hip.lerp(foot, 0.5) + Vector2(2, 0)
		_limb(hip, knee, 9.0, leg_col)
		_limb(knee, foot + Vector2(0, -8), 8.5, leg_col)
		# Knee guard.
		draw_circle(knee, 4.5, _c(_p.trim if hero_id != "knight" else _p.body))
		_boot(foot)


func _boot(foot: Vector2) -> void:
	var b := PackedVector2Array([
		foot + Vector2(-5, -14), foot + Vector2(5, -14), foot + Vector2(6, -3),
		foot + Vector2(12, 0), foot + Vector2(-5, 0)])
	draw_colored_polygon(b, _c(_p.boot))
	draw_polyline(b + PackedVector2Array([b[0]]), OUTLINE, 1.5, true)
	draw_line(foot + Vector2(-5, -14), foot + Vector2(5, -14), _c(_p.trim), 2.0)


func _limb(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(a, b, OUTLINE, w + 3.0, true)
	draw_line(a, b, _c(col), w, true)
	draw_circle(a, w * 0.5, _c(col))
	draw_circle(b, w * 0.5, _c(col))


func _draw_quiver() -> void:
	var q := PackedVector2Array([Vector2(-16, -82), Vector2(-8, -84), Vector2(-2, -50), Vector2(-10, -48)])
	draw_colored_polygon(q, _c(_p.body_dark))
	draw_polyline(q + PackedVector2Array([q[0]]), OUTLINE, 1.5, true)
	for i in 4:
		var base := Vector2(-15 + i * 2.5, -82)
		draw_line(base, base + Vector2(-3 + i, -12), _c(Color(0.5, 0.35, 0.2)), 1.5)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-3 + i, -12), base + Vector2(-6 + i, -18), base + Vector2(i, -16)]),
			_c(Color(0.92, 0.9, 0.85)))


func _draw_torso() -> void:
	var torso := PackedVector2Array([
		Vector2(-12, -70), Vector2(12, -70), Vector2(10, -52), Vector2(9, -40),
		Vector2(-9, -40), Vector2(-10, -52)])
	draw_colored_polygon(torso, _c(_p.body))
	draw_polyline(torso + PackedVector2Array([torso[0]]), OUTLINE, 2.0, true)
	match hero_id:
		"rogue":
			# Leather corset with crisscross straps.
			draw_line(Vector2(-9, -66), Vector2(9, -44), _c(_p.body_dark), 3.0)
			draw_line(Vector2(9, -66), Vector2(-9, -44), _c(_p.body_dark), 3.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-12, -71), Vector2(4, -71), Vector2(-6, -58)]), _c(_p.lining))
		"mage":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-12, -70), Vector2(-3, -70), Vector2(-5, -42), Vector2(-9, -40), Vector2(-10, -52)]),
				_c(_p.cape))
			draw_circle(Vector2(1, -48), 5.0, _c(_p.trim))
			draw_circle(Vector2(1, -48), 2.5, _c(Color(0.45, 0.6, 1.0)))
		"ranger":
			draw_line(Vector2(-11, -68), Vector2(10, -45), _c(_p.body_dark), 4.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-13, -72), Vector2(12, -72), Vector2(8, -63), Vector2(-9, -62)]), _c(_p.cape))
			# Belt pouch.
			draw_rect(Rect2(3, -47, 8, 7), _c(_p.body_dark))
		"knight":
			# Breastplate highlight, lion emblem and fur collar.
			draw_colored_polygon(PackedVector2Array([
				Vector2(-4, -68), Vector2(8, -68), Vector2(6, -52), Vector2(-2, -50)]),
				_c(Color(0.9, 0.92, 0.95)))
			draw_circle(Vector2(1, -56), 4.0, _c(_p.trim))
			for i in 6:
				draw_circle(Vector2(-12 + i * 4.8, -71 + sin(i * 1.7) * 1.5), 5.0, _c(Color(0.8, 0.76, 0.7)))
	# Belt.
	draw_line(Vector2(-10, -42), Vector2(10, -42), _c(Color(0.3, 0.2, 0.13)), 4.0)
	draw_rect(Rect2(-2, -44, 4, 4), _c(_p.trim))
	# Shoulder guard (back shoulder drawn here, front with the arm).
	if hero_id == "knight":
		_pauldron(Vector2(-10, -68), 1.0)
	elif hero_id != "mage":
		draw_circle(Vector2(-10, -67), 6.5, _c(_p.body_dark))


func _pauldron(at: Vector2, s: float) -> void:
	var p := PackedVector2Array([
		at + Vector2(-9, 2) * s, at + Vector2(-6, -7) * s, at + Vector2(6, -8) * s,
		at + Vector2(10, 2) * s, at + Vector2(0, 7) * s])
	draw_colored_polygon(p, _c(_p.body))
	draw_polyline(p + PackedVector2Array([p[0]]), OUTLINE, 2.0, true)
	draw_line(at + Vector2(-6, -6) * s, at + Vector2(6, -7) * s, _c(_p.trim), 2.0)


func _draw_head() -> void:
	var hc := Vector2(2, -82)
	# Neck.
	draw_rect(Rect2(-3, -73, 7, 5), _c(_p.skin))
	match hero_id:
		"rogue":
			# Hood with mask - only the eyes show.
			var hood := PackedVector2Array([
				hc + Vector2(-14, 10), hc + Vector2(-14, -4), hc + Vector2(-8, -14),
				hc + Vector2(4, -16), hc + Vector2(13, -8), hc + Vector2(14, 6), hc + Vector2(10, 12)])
			draw_colored_polygon(hood, _c(_p.cape))
			draw_polyline(hood + PackedVector2Array([hood[0]]), OUTLINE, 2.0, true)
			draw_circle(hc + Vector2(3, 0), 9.0, _c(_p.skin))
			draw_rect(Rect2(hc + Vector2(-5, 1), Vector2(16, 8)), _c(Color(0.08, 0.07, 0.07)))
			draw_line(hc + Vector2(-6, -7), hc + Vector2(12, -7), _c(_p.trim), 1.5)
			_eye(hc + Vector2(7, -2))
		"mage":
			# Long flowing blonde hair.
			var hair := PackedVector2Array([
				hc + Vector2(-12, -6), hc + Vector2(-2, -13), hc + Vector2(10, -10),
				hc + Vector2(12, 2), hc + Vector2(6, 4), hc + Vector2(-4, 34 + sin(time * 3.0) * 2.0),
				hc + Vector2(-16, 30 + sin(time * 3.0 + 1.0) * 2.0), hc + Vector2(-15, 6)])
			draw_colored_polygon(hair, _c(_p.hair))
			draw_polyline(hair + PackedVector2Array([hair[0]]), OUTLINE, 1.5, true)
			draw_circle(hc + Vector2(2, 0), 9.5, _c(_p.skin))
			draw_colored_polygon(PackedVector2Array([
				hc + Vector2(-8, -6), hc + Vector2(0, -12), hc + Vector2(11, -7), hc + Vector2(4, -4)]),
				_c(_p.hair))
			_eye(hc + Vector2(7, -1))
			draw_circle(hc + Vector2(-5, 3), 2.0, _c(Color(0.45, 0.6, 1.0)))
		"ranger":
			var hair := PackedVector2Array([
				hc + Vector2(-13, -3), hc + Vector2(-4, -13), hc + Vector2(9, -11),
				hc + Vector2(12, -1), hc + Vector2(-2, 6), hc + Vector2(-14, 12)])
			draw_colored_polygon(hair, _c(_p.hair))
			draw_circle(hc + Vector2(2, 0), 9.5, _c(_p.skin))
			draw_colored_polygon(PackedVector2Array([
				hc + Vector2(-9, -5), hc + Vector2(-2, -12), hc + Vector2(11, -7), hc + Vector2(5, -5)]),
				_c(_p.hair))
			# Braid swinging behind.
			for i in 4:
				draw_circle(hc + Vector2(-12 - i * 1.5 + sin(time * 4.0 + i) * 1.5, 6 + i * 6), 3.5, _c(_p.hair))
			_eye(hc + Vector2(7, -1))
			# Elf ear.
			draw_colored_polygon(PackedVector2Array([
				hc + Vector2(-3, -2), hc + Vector2(-11, -8), hc + Vector2(-4, 3)]), _c(_p.skin))
		"knight":
			draw_circle(hc + Vector2(2, 0), 10.0, _c(_p.skin))
			var hair := PackedVector2Array([
				hc + Vector2(-9, -2), hc + Vector2(-7, -11), hc + Vector2(3, -14),
				hc + Vector2(12, -8), hc + Vector2(9, -5), hc + Vector2(0, -7), hc + Vector2(-4, 2)])
			draw_colored_polygon(hair, _c(_p.hair))
			# Stubble and a scar.
			draw_arc(hc + Vector2(3, 3), 7.0, 0.2, 2.6, 8, _c(Color(0.45, 0.35, 0.3, 0.6)), 2.0)
			draw_line(hc + Vector2(8, -6), hc + Vector2(10, 0), _c(Color(0.7, 0.4, 0.38)), 1.2)
			_eye(hc + Vector2(7, -2))
	draw_arc(hc + Vector2(2, 0), 10.0, 0, TAU, 20, OUTLINE, 1.5, true)


func _eye(at: Vector2) -> void:
	draw_circle(at, 1.8, _c(Color(0.1, 0.08, 0.08)))


# ------------------------------------------------------------------ weapons
func _swing_offset() -> float:
	if attack_t < 0.0:
		return 0.0
	var k := ease(attack_t, 0.5)
	return lerpf(-attack_arc * 0.5, attack_arc * 0.5, k) * facing


func _draw_weapon(bob: float) -> void:
	var shoulder := Vector2(6 * facing, -64 + bob)
	var aim_dir := Vector2.from_angle(aim_angle)
	match hero_id:
		"rogue":
			var ang := aim_angle + _swing_offset()
			var hand := shoulder + Vector2.from_angle(ang) * 18.0
			_arm(shoulder, hand)
			_dagger(hand, ang)
			# Off-hand dagger, held reversed.
			var off_shoulder := Vector2(-8 * facing, -64 + bob)
			var off_ang := aim_angle - _swing_offset() * 0.6 + 0.6 * facing
			var off_hand := off_shoulder + Vector2.from_angle(off_ang) * 14.0
			_arm(off_shoulder, off_hand)
			_dagger(off_hand, off_ang + PI * 0.15 * facing)
		"knight":
			var ang := aim_angle + _swing_offset()
			if attack_t < 0.0:
				# Rest the greatsword low and forward.
				ang = aim_angle + 0.9 * facing
			var hand := shoulder + Vector2.from_angle(ang) * 16.0
			_arm(shoulder, hand)
			_greatsword(hand, ang)
			_pauldron(shoulder + Vector2(0, -2), 1.15)
		"mage":
			var hand := shoulder + Vector2(10 * facing, 14)
			_arm(shoulder, hand)
			_staff(hand)
			# Floating orb near the off hand, pointing at the aim.
			var orb := Vector2(0, -60 + bob) + aim_dir * 34.0
			var pulse := 1.0 + sin(time * 6.0) * 0.12
			draw_circle(orb, 13.0 * pulse, Color(0.4, 0.5, 1.0, 0.25))
			draw_circle(orb, 7.0 * pulse, _c(Color(0.62, 0.7, 1.0)))
			draw_circle(orb, 3.5, Color(1, 1, 1, 0.95))
			if attack_t >= 0.0:
				draw_arc(orb, 18.0 * (0.5 + attack_t), 0, TAU, 24, Color(0.7, 0.8, 1.0, 1.0 - attack_t), 2.0, true)
		"ranger":
			var hand := shoulder + aim_dir * 24.0
			_arm(shoulder, hand)
			var draw_k := 0.0
			if attack_t >= 0.0:
				draw_k = 1.0 - attack_t
			_bow(hand, aim_angle, draw_k)
			var pull_hand := shoulder + aim_dir * (12.0 - 10.0 * draw_k)
			_arm(Vector2(-6 * facing, -64 + bob), pull_hand)


func _arm(from: Vector2, to: Vector2) -> void:
	var col: Color = _p.body
	if hero_id == "mage":
		col = _p.lining
	elif hero_id == "rogue" or hero_id == "ranger":
		col = _p.body_dark
	_limb(from, to, 7.0, col)
	draw_circle(to, 4.5, _c(_p.skin if hero_id == "mage" else _p.boot))


func _dagger(at: Vector2, ang: float) -> void:
	draw_set_transform(at, ang)
	# Curved blade.
	var blade := PackedVector2Array([
		Vector2(4, -3), Vector2(18, -6), Vector2(30, -3), Vector2(36, 2), Vector2(26, 2), Vector2(4, 3)])
	draw_colored_polygon(blade, _c(Color(0.82, 0.84, 0.88)))
	draw_polyline(blade + PackedVector2Array([blade[0]]), OUTLINE, 1.5, true)
	draw_line(Vector2(6, -1), Vector2(28, -1), _c(Color(1, 1, 1, 0.7)), 1.0)
	draw_line(Vector2(3, -6), Vector2(3, 6), _c(_p.trim), 3.0)
	draw_line(Vector2(-6, 0), Vector2(3, 0), _c(_p.lining), 4.0)
	draw_set_transform(Vector2.ZERO)


func _greatsword(at: Vector2, ang: float) -> void:
	draw_set_transform(at, ang)
	var blade := PackedVector2Array([
		Vector2(10, -6), Vector2(78, -6), Vector2(92, 0), Vector2(78, 6), Vector2(10, 6)])
	draw_colored_polygon(blade, _c(Color(0.78, 0.8, 0.84)))
	draw_polyline(blade + PackedVector2Array([blade[0]]), OUTLINE, 2.0, true)
	draw_line(Vector2(12, 0), Vector2(84, 0), _c(Color(0.55, 0.57, 0.62)), 2.0)
	draw_line(Vector2(12, -3), Vector2(76, -3), _c(Color(1, 1, 1, 0.6)), 1.0)
	# Crossguard with lion head.
	draw_line(Vector2(8, -15), Vector2(8, 15), OUTLINE, 7.0)
	draw_line(Vector2(8, -14), Vector2(8, 14), _c(_p.trim), 5.0)
	draw_circle(Vector2(10, 0), 5.0, _c(_p.trim))
	draw_line(Vector2(-12, 0), Vector2(6, 0), _c(_p.cape), 5.0)
	draw_circle(Vector2(-13, 0), 4.0, _c(_p.trim))
	draw_set_transform(Vector2.ZERO)


func _staff(hand: Vector2) -> void:
	var top := hand + Vector2(4 * facing, -58)
	var bottom := hand + Vector2(-3 * facing, 46)
	draw_line(top, bottom, OUTLINE, 6.0, true)
	draw_line(top, bottom, _c(Color(0.22, 0.16, 0.14)), 4.0, true)
	for i in 4:
		var p := top.lerp(bottom, 0.15 + i * 0.2)
		draw_circle(p, 3.0, _c(_p.trim))
	# Crescent head holding the star orb.
	var head := top + Vector2(0, -12)
	draw_arc(head, 14.0, PI * 0.15, PI * 1.6, 16, _c(_p.trim), 4.0, true)
	var pulse := 1.0 + sin(time * 5.0) * 0.1
	draw_circle(head, 16.0 * pulse, Color(0.4, 0.5, 1.0, 0.25))
	draw_circle(head, 8.0, _c(Color(0.45, 0.55, 1.0)))
	draw_circle(head + Vector2(-2, -2), 3.0, Color(1, 1, 1, 0.9))


func _bow(hand: Vector2, ang: float, draw_k: float) -> void:
	draw_set_transform(hand, ang)
	var pts := PackedVector2Array()
	for i in 13:
		var k := float(i) / 12.0
		var y := lerpf(-40, 40, k)
		var x := 12.0 * sin(PI * k) - 2.0
		pts.append(Vector2(x, y))
	draw_polyline(pts, OUTLINE, 7.0, true)
	draw_polyline(pts, _c(Color(0.3, 0.2, 0.14)), 4.5, true)
	draw_circle(Vector2(10, 0), 4.0, _c(_p.trim))
	draw_line(Vector2(-3, -36), Vector2(-3, 36), _c(_p.trim), 2.5)
	var pull := -2.0 - 16.0 * draw_k
	draw_line(pts[0], Vector2(pull, 0), Color(0.9, 0.88, 0.8), 1.2, true)
	draw_line(pts[12], Vector2(pull, 0), Color(0.9, 0.88, 0.8), 1.2, true)
	if draw_k > 0.05:
		draw_line(Vector2(pull, 0), Vector2(pull + 46, 0), _c(Color(0.55, 0.4, 0.25)), 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(pull + 46, -3), Vector2(pull + 54, 0), Vector2(pull + 46, 3)]), _c(Color(0.8, 0.8, 0.85)))
	draw_set_transform(Vector2.ZERO)


## The local player's locator stays legible while the sprite is in stealth.
class Locator extends Node2D:
	var actor: Node

	func _ready() -> void:
		z_as_relative = false
		z_index = 36

	func _process(_delta: float) -> void:
		visible = is_instance_valid(actor) and not actor.dead
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.35))
		draw_arc(Vector2.ZERO, 34, 0, TAU, 48, Color(0.01, 0.025, 0.04, 0.95), 8, true)
		draw_arc(Vector2.ZERO, 34, 0, TAU, 48, Color(0.68, 0.94, 1, 0.95), 2.5, true)
		draw_set_transform(Vector2.ZERO)
