extends CharacterBody2D
## Player-controlled hero: movement, aiming, attacks, skills, dash and stats.

signal died
signal hp_changed

const HEROES := preload("res://scripts/data/heroes.gd")
const HeroVisual := preload("res://scripts/game/hero_visual.gd")
const FX := preload("res://scripts/game/fx.gd")

const DASH_TIME := 0.18
const DASH_SPEED_MULT := 3.4
const HIT_INVULN := 0.6
const AIM_ASSIST_RANGE := 750.0

var world: Node
var hero_id := "knight"
var data: Dictionary

# Stats (base values come from the hero, upgrades modify them).
var max_hp := 100.0
var hp := 100.0
var move_speed := 220.0
var damage := 15.0
var attack_cd := 0.5
var crit_chance := 0.1
var crit_mult := 1.75
var armor := 0.0
var regen := 0.0
var lifesteal := 0.0
var pickup_range := 130.0
var skill_cd := 6.0
var dash_cd := 1.5
var area_mult := 1.0
var extra_projectiles := 0
var extra_pierce := 0
var shadowstep := 0
var venom := 0
var thorns := 0
var cleave := 0
var upgrades := {}
## Damage taken per source kind, for the end-of-run summary and balancing.
var damage_log := {}

var level := 1
var xp := 0
var dead := false

var attack_timer := 0.0
var skill_timer := 0.0
var dash_timer := 0.0
var aim_dir := Vector2.RIGHT

var _invuln := 0.0
var _dash_t := 0.0
var _dash_dir := Vector2.ZERO
var _dash_hits := {}
var _attack_anim := -1.0
var _attack_anim_len := 0.25
var _combo := 0
var _using_pad := false
var _afterimage_t := 0.0
var _heal_accum := 0.0
## External pull applied this frame (Void Sovereign's gravity). Dashing ignores it.
var _pull := Vector2.ZERO
var _visual: Node2D


func setup(p_hero: String, p_world: Node) -> void:
	hero_id = p_hero
	world = p_world
	data = HEROES.DATA[hero_id]
	max_hp = data.max_hp
	hp = max_hp
	move_speed = data.speed
	damage = data.damage
	attack_cd = data.attack_cd
	crit_chance = data.crit
	armor = data.armor
	lifesteal = data.get("lifesteal", 0.0)
	skill_cd = data.skill_cd
	dash_cd = data.dash_cd


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle
	add_child(shape)
	_visual = HeroVisual.new()
	_visual.hero_id = hero_id
	_visual.ring_color = data.accent.lightened(0.2)
	# Always draw the hero above enemies so it never gets lost in a crowd.
	z_index = 1
	add_child(_visual)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.35:
			return
		_using_pad = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		_using_pad = false


func _physics_process(delta: float) -> void:
	if dead:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	skill_timer = maxf(0.0, skill_timer - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	_invuln = maxf(0.0, _invuln - delta)
	if regen > 0.0 and hp < max_hp:
		heal(regen * delta, false)

	_update_aim()
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if _dash_t > 0.0:
		_dash_t -= delta
		velocity = _dash_dir * move_speed * DASH_SPEED_MULT
		_afterimage_t -= delta
		if _afterimage_t <= 0.0:
			_afterimage_t = 0.03
			var ai = FX.Afterimage.new()
			ai.color = data.accent
			ai.position = global_position
			world.add_ground_fx(ai)
		if shadowstep > 0:
			_shadowstep_hits()
	else:
		velocity = move * move_speed + _pull
		if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
			_start_dash(move)
		if (Input.is_action_pressed("attack") or Game.settings.auto_attack) and attack_timer <= 0.0:
			_attack()
		if Input.is_action_just_pressed("skill") and skill_timer <= 0.0:
			_skill()
	move_and_slide()
	_pull = Vector2.ZERO

	# Animation state.
	if _attack_anim >= 0.0:
		_attack_anim += delta / _attack_anim_len
		if _attack_anim >= 1.0:
			_attack_anim = -1.0
	_visual.attack_t = _attack_anim
	_visual.aim_angle = aim_dir.angle()
	_visual.moving = velocity.length() > 10.0
	_visual.invuln_blink = _invuln > 0.0 and _dash_t <= 0.0
	if absf(aim_dir.x) > 0.15:
		_visual.facing = signf(aim_dir.x)
	_visual.flash = maxf(0.0, _visual.flash - delta * 5.0)


func _update_aim() -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > 0.3:
		_using_pad = true
		aim_dir = stick.normalized()
		return
	if _using_pad:
		# Aim assist: face the nearest enemy, else the movement direction.
		var target: Node2D = world.nearest_enemy(global_position, AIM_ASSIST_RANGE)
		if target:
			aim_dir = (target.global_position + Vector2(0, -target.radius) - (global_position + Vector2(0, -40))).normalized()
		else:
			var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if move.length() > 0.2:
				aim_dir = move.normalized()
		return
	var to_mouse := get_global_mouse_position() - (global_position + Vector2(0, -40))
	if to_mouse.length() > 4.0:
		aim_dir = to_mouse.normalized()


func aim_point(max_dist: float) -> Vector2:
	## World point the hero is targeting (mouse position, or assisted target on pad).
	if not _using_pad:
		var m := get_global_mouse_position()
		var off := m - global_position
		return global_position + off.limit_length(max_dist)
	var target: Node2D = world.nearest_enemy(global_position, max_dist)
	if target:
		return target.global_position
	return global_position + aim_dir * max_dist * 0.6


# ------------------------------------------------------------------ attacks
func _attack() -> void:
	var speed_cd := attack_cd
	attack_timer = speed_cd
	_attack_anim = 0.0
	_attack_anim_len = clampf(speed_cd * 0.85, 0.12, 0.4)
	var origin := global_position + Vector2(0, -40)
	match data.attack_kind:
		"melee":
			_combo += 1
			var mult := 1.0
			if hero_id == "rogue" and _combo % 3 == 0:
				mult = 2.0
			var reach: float = data.melee_range * area_mult
			var arc: float = data.melee_arc
			_visual.attack_arc = deg_to_rad(arc)
			_melee(origin, reach, arc, mult, data.knockback)
			if hero_id == "knight":
				Audio.play("swing_heavy")
			else:
				Audio.play("swing", -2.0, 0.15)
			if cleave > 0:
				_fire("wave", origin, aim_dir, 620.0, 0.25 + 0.15 * cleave, 99, 0.42, 26.0 * area_mult)
		"orb":
			Audio.play("magic", -3.0)
			_fire_spread("orb", origin, data.proj_speed, 1.0, data.pierce + extra_pierce, 1.6, 12.0, 1 + extra_projectiles, 0.22)
		"arrow":
			Audio.play("arrow", -2.0)
			_fire_spread("arrow", origin, data.proj_speed, 1.0, data.pierce + extra_pierce, 1.0, 10.0, 1 + extra_projectiles, 0.12)


func _melee(origin: Vector2, reach: float, arc_deg: float, mult: float, knock: float) -> void:
	var slash = FX.Slash.new()
	slash.radius = reach * 0.85
	slash.arc = deg_to_rad(arc_deg)
	slash.width = 34.0 if hero_id == "knight" else 22.0
	slash.color = data.accent if hero_id != "knight" else Color(1, 0.92, 0.75)
	slash.rotation = aim_dir.angle()
	slash.position = origin
	if _visual.facing < 0:
		slash.scale.y = -1
	world.add_top_fx(slash)
	var half := deg_to_rad(arc_deg) * 0.5
	for e in world.enemies.duplicate():
		if e.dead:
			continue
		var to: Vector2 = e.global_position + Vector2(0, -e.radius) - origin
		if to.length() > reach + e.radius:
			continue
		if absf(aim_dir.angle_to(to)) > half and to.length() > e.radius + 20.0:
			continue
		world.player_hit_enemy(e, mult, to.normalized() * knock)


func _fire_spread(kind: String, origin: Vector2, spd: float, mult: float, pierce: int, life: float,
		radius: float, count: int, spread: float) -> void:
	for i in count:
		var off := (i - (count - 1) / 2.0) * spread
		_fire(kind, origin, aim_dir.rotated(off), spd, mult, pierce, life, radius)


func _fire(kind: String, origin: Vector2, dir: Vector2, spd: float, mult: float, pierce: int,
		life: float, radius: float) -> Node2D:
	var p: Node2D = world.spawn_projectile(kind, origin + dir * 20.0, dir * spd)
	p.dmg_mult = mult
	p.pierce = pierce
	p.life = life
	p.radius = radius
	p.knockback = data.knockback
	if kind == "orb":
		p.splash = data.splash * area_mult
		p.homing = 3.0
	return p


func _skill() -> void:
	skill_timer = skill_cd
	_attack_anim = 0.0
	_attack_anim_len = 0.3
	var origin := global_position + Vector2(0, -40)
	match hero_id:
		"rogue":
			Audio.play("knives")
			var n := 14 + 2 * extra_projectiles
			for i in n:
				var dir := Vector2.from_angle(TAU * i / n + randf() * 0.1)
				_fire("dagger", origin, dir, 760.0, 1.5, 2, 0.6, 14.0)
		"mage":
			var target := aim_point(620.0)
			var r := 160.0 * area_mult
			var streak = FX.StarStreak.new()
			streak.position = target
			world.add_top_fx(streak)
			var tel = FX.Telegraph.new()
			tel.radius = r
			tel.duration = 0.45
			tel.color = Color(0.5, 0.6, 1.0)
			tel.position = target
			tel.on_done = func() -> void: _starfall_impact(target, r)
			world.add_ground_fx(tel)
			Audio.play("magic", 2.0, 0.0)
		"ranger":
			Audio.play("arrow", 2.0, 0.0)
			var n := 9 + 2 * extra_projectiles
			_fire_spread("arrow", origin, data.proj_speed * 1.1, 1.2, 2 + extra_pierce, 0.9, 12.0, n, deg_to_rad(70.0) / (n - 1))
		"knight":
			Audio.play("roar")
			var r := 200.0 * area_mult
			world.shake(10.0)
			world.spawn_ring(global_position + Vector2(0, -20), r, Color(1, 0.8, 0.4), 0.45)
			_invuln = maxf(_invuln, 0.5)
			for e in world.enemies_in_radius(global_position, r):
				var dir: Vector2 = (e.global_position - global_position).normalized()
				e.stun = maxf(e.stun, 1.3)
				world.player_hit_enemy(e, 2.5, dir * 520.0)


func _starfall_impact(at: Vector2, r: float) -> void:
	if dead or not is_instance_valid(world):
		return
	Audio.play("explosion")
	world.shake(9.0)
	world.spawn_ring(at, r, Color(0.55, 0.65, 1.0), 0.45)
	world.spawn_burst(at, Color(0.7, 0.8, 1.0), 22, 420.0)
	for e in world.enemies_in_radius(at, r):
		world.player_hit_enemy(e, 4.0, (e.global_position - at).normalized() * 300.0)


func _start_dash(move: Vector2) -> void:
	_dash_dir = move.normalized() if move.length() > 0.1 else aim_dir
	_dash_t = DASH_TIME
	dash_timer = dash_cd
	_invuln = maxf(_invuln, DASH_TIME + 0.08)
	_dash_hits.clear()
	_afterimage_t = 0.0
	Audio.play("dash")


func _shadowstep_hits() -> void:
	for e in world.enemies_in_radius(global_position, 46.0):
		if _dash_hits.has(e):
			continue
		_dash_hits[e] = true
		world.player_hit_enemy(e, 1.0 + 0.6 * shadowstep, _dash_dir * 120.0)


# ------------------------------------------------------------------ damage
func apply_pull(v: Vector2) -> void:
	_pull = v


func roll_damage(mult: float) -> Array:
	## Returns [amount, is_crit].
	var amount := damage * mult * randf_range(0.9, 1.1)
	var crit := randf() < crit_chance
	if crit:
		amount *= crit_mult
	return [amount, crit]


func take_damage(amount: float, source: Node) -> bool:
	if dead or _invuln > 0.0 or _dash_t > 0.0:
		return false
	var final := amount * (1.0 - clampf(armor, 0.0, 0.7))
	hp -= final
	var src_kind := "unknown"
	if is_instance_valid(source) and "kind" in source:
		src_kind = str(source.kind)
	damage_log[src_kind] = float(damage_log.get(src_kind, 0.0)) + final
	_invuln = HIT_INVULN
	_visual.flash = 1.0
	Audio.play("hurt")
	world.shake(7.0)
	world.show_damage(global_position + Vector2(0, -90), final, Color(1, 0.35, 0.3), false)
	if thorns > 0 and is_instance_valid(source) and source.has_method("hit") and not source.dead:
		world.damage_enemy(source, amount * 0.5 * thorns, false, Vector2.ZERO)
	hp_changed.emit()
	if hp <= 0.0:
		hp = 0.0
		dead = true
		_visual.flash = 0.0
		_visual.modulate = Color(0.6, 0.3, 0.3, 0.8)
		_visual.rotation = deg_to_rad(80.0 * _visual.facing)
		died.emit()
	return true


func heal(amount: float, show: bool = true) -> void:
	if dead or amount <= 0.0:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	if show:
		_heal_accum += hp - before
		if _heal_accum >= 1.0:
			world.show_damage(global_position + Vector2(0, -100), _heal_accum, Color(0.4, 1.0, 0.5), false)
			_heal_accum = 0.0
	hp_changed.emit()


func xp_to_next() -> int:
	return int(5.0 + level * 4.5 + pow(level, 1.6) * 0.6)


# ------------------------------------------------------------------ upgrades
func apply_upgrade(id: String) -> void:
	upgrades[id] = int(upgrades.get(id, 0)) + 1
	match id:
		"might": damage *= 1.15
		"frenzy": attack_cd *= 1.0 / 1.12
		"swift": move_speed *= 1.08
		"vitality":
			max_hp += 25.0
			heal(25.0)
		"precision": crit_chance += 0.08
		"ferocity": crit_mult += 0.4
		"vampirism": lifesteal += 0.02
		"regeneration": regen += 0.8
		"ironskin": armor += 0.06
		"magnet": pickup_range *= 1.4
		"focus": skill_cd *= 0.88
		"reach": area_mult *= 1.15
		"swiftstep": dash_cd *= 0.85
		"multishot": extra_projectiles += 1
		"piercing": extra_pierce += 1
		"shadowstep": shadowstep += 1
		"venom": venom += 1
		"thorns": thorns += 1
		"cleave": cleave += 1
		"elixir": heal(max_hp * 0.5)
	hp_changed.emit()
