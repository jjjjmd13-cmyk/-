extends CharacterBody2D
## Player-controlled hero: movement, aiming, attacks, skills, dash and stats.

signal died
signal hp_changed

const HEROES := preload("res://scripts/data/heroes.gd")
const HeroVisual := preload("res://scripts/game/hero_visual.gd")
const FX := preload("res://scripts/game/fx.gd")
const Zones := preload("res://scripts/game/zones.gd")
## Skill slots: right click / Q / R.
const SLOTS := ["skill", "skill2", "ult"]

const DASH_TIME := 0.18
const DASH_SPEED_MULT := 3.4
const HIT_INVULN := 0.6
## Barrier (Astra's passive): regrows after this many seconds without being hit.
const BARRIER_DELAY := 6.0
const BARRIER_REGEN := 15.0
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
## Damage-absorbing barrier; heroes without the passive keep it at 0.
var shield := 0.0
var _shield_delay := 0.0
var lifesteal := 0.0
var pickup_range := 130.0
## Multiplier on every skill cooldown (the Focus upgrade lowers it).
var cd_mult := 1.0
var cooldowns := {"skill": 6.0, "skill2": 10.0, "ult": 50.0}
var timers := {"skill": 0.0, "skill2": 0.0, "ult": 0.0}
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

# Skill states.
var _hidden_t := 0.0
var _sure_crits := 0
var _force_crit := false
var _awaken_t := 0.0
var _charge_t := 0.0
var _charge_dir := Vector2.ZERO
var _charge_hits := {}
var _dance_left := 0
var _dance_t := 0.0
var _dance_hit := {}


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
	cooldowns = {"skill": data.skill_cd, "skill2": data.skill2_cd, "ult": data.ult_cd}
	# The ultimate starts half charged so it shows up early in a run.
	timers = {"skill": 0.0, "skill2": 0.0, "ult": data.ult_cd * 0.5}
	dash_cd = data.dash_cd
	shield = shield_max()


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
	for slot in SLOTS:
		timers[slot] = maxf(0.0, timers[slot] - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_hidden_t = maxf(0.0, _hidden_t - delta)
	_awaken_t = maxf(0.0, _awaken_t - delta)
	if regen > 0.0 and hp < max_hp:
		heal(regen * delta, false)
	if shield_max() > 0.0:
		_shield_delay -= delta
		if _shield_delay <= 0.0:
			shield = minf(shield_max(), shield + BARRIER_REGEN * delta)
	_visual.shield_frac = shield / shield_max() if shield_max() > 0.0 else 0.0

	_update_aim()
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if _dance_left > 0:
		_blade_dance(delta)
	elif _charge_t > 0.0:
		_shield_charge(delta)
	elif _dash_t > 0.0:
		_dash_t -= delta
		velocity = _dash_dir * move_speed * DASH_SPEED_MULT
		_afterimage_t -= delta
		if _afterimage_t <= 0.0:
			_afterimage_t = 0.03
			var ai = _afterimage(global_position, data.accent)
			world.add_ground_fx(ai)
		if shadowstep > 0:
			_shadowstep_hits()
	else:
		var spd := move_speed * (1.6 if _hidden_t > 0.0 else 1.0)
		velocity = move * spd + _pull
		if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
			_start_dash(move)
		if (Input.is_action_pressed("attack") or Game.settings.auto_attack) and attack_timer <= 0.0:
			_attack()
		for slot in SLOTS:
			if Input.is_action_just_pressed(slot) and timers[slot] <= 0.0:
				_use_skill(slot)
				break
	move_and_slide()
	_pull = Vector2.ZERO

	# Animation state.
	if _attack_anim >= 0.0:
		_attack_anim += delta / _attack_anim_len
		if _attack_anim >= 1.0:
			_attack_anim = -1.0
	_visual.attack_t = _attack_anim
	_visual.action_len = _attack_anim_len
	_visual.dashing = _dash_t > 0.0 or _charge_t > 0.0 or _dance_left > 0
	_visual.stealth_alpha = 0.45 if _hidden_t > 0.0 else 1.0
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
	var speed_cd := attack_cd * (0.75 if _awaken_t > 0.0 else 1.0)
	attack_timer = speed_cd
	_force_crit = _sure_crits > 0
	if _force_crit:
		_sure_crits -= 1
	_attack_anim = 0.0
	_visual.action_anim = "attack"
	_attack_anim_len = clampf(speed_cd * 0.85, 0.12, 0.4)
	var origin := global_position + Vector2(0, -40)
	match data.attack_kind:
		"melee":
			_combo += 1
			var mult := 1.0
			if hero_id == "rogue" and _combo % 3 == 0:
				mult = 2.0
			var reach: float = data.melee_range * area_mult * (1.3 if _awaken_t > 0.0 else 1.0)
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
	_force_crit = false


func _melee(origin: Vector2, reach: float, arc_deg: float, mult: float, knock: float) -> void:
	var slash = FX.Slash.new()
	slash.theme = hero_id
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


func cooldown_ready(slot: String) -> float:
	## 0..1 how charged a skill slot is (1 = ready).
	var total: float = cooldowns[slot] * cd_mult
	return 1.0 - clampf(timers[slot] / maxf(total, 0.01), 0.0, 1.0)


func on_kill() -> void:
	# Every kill brings the ultimate a little closer.
	timers.ult = maxf(0.0, timers.ult - 0.3)


func is_hidden() -> bool:
	return _hidden_t > 0.0


func _use_skill(slot: String) -> void:
	timers[slot] = cooldowns[slot] * cd_mult
	_attack_anim = 0.0
	_visual.action_anim = "skill"
	_attack_anim_len = 0.3
	if slot == "ult":
		world.shake(6.0)
	_sigil(global_position, 100.0 if slot != "ult" else 155.0, 0.65)
	call("_%s_%s" % [hero_id, slot])


# --- Vesper (rogue)
func _rogue_skill() -> void:
	Audio.play("knives")
	var origin := global_position + Vector2(0, -40)
	var n := 14 + 2 * extra_projectiles
	for i in n:
		var dir := Vector2.from_angle(TAU * i / n + randf() * 0.1)
		_fire("dagger", origin, dir, 760.0, 1.5, 2, 0.6, 14.0)


func _rogue_skill2() -> void:
	## Smoke Veil: vanish, move faster and land three guaranteed critical hits.
	Audio.play("dash", 2.0, 0.0)
	_hidden_t = 3.0
	_sure_crits = 3
	var smoke := Zones.Smoke.new()
	smoke.duration = 3.0
	add_child(smoke)


func _rogue_ult() -> void:
	## Thousand Cuts: blink between nearby enemies, slashing each one.
	_dance_left = 12
	_dance_t = 0.0
	_dance_hit.clear()
	_invuln = maxf(_invuln, 0.2)
	Audio.play("knives", 2.0, 0.0)


func _blade_dance(delta: float) -> void:
	velocity = Vector2.ZERO
	_invuln = maxf(_invuln, 0.1)
	_dance_t -= delta
	if _dance_t > 0.0:
		return
	_dance_t = 0.07
	var target: Node2D = null
	var best := 520.0 * 520.0
	for e in world.enemies:
		if e.dead or _dance_hit.has(e):
			continue
		var d: float = e.global_position.distance_squared_to(global_position)
		if d < best:
			best = d
			target = e
	if target == null:
		_dance_left = 0
		return
	_dance_hit[target] = true
	_dance_left -= 1
	var from := global_position
	var side := (from - target.global_position).normalized()
	if side == Vector2.ZERO:
		side = Vector2.LEFT
	global_position = world.clamp_to_arena(target.global_position + side * 40.0)
	aim_dir = (target.global_position - global_position).normalized()
	var ai = _afterimage(from, data.accent)
	world.add_ground_fx(ai)
	var slash = FX.Slash.new()
	slash.theme = hero_id
	slash.radius = 60.0
	slash.color = data.accent
	slash.rotation = aim_dir.angle()
	slash.position = global_position + Vector2(0, -40)
	world.add_top_fx(slash)
	Audio.play("swing", 0.0, 0.2)
	world.player_hit_enemy(target, 3.0, aim_dir * 150.0)


# --- Astra (mage)
func _mage_skill() -> void:
	_starfall(aim_point(620.0), 160.0 * area_mult, 4.0)
	Audio.play("magic", 2.0, 0.0)


func _mage_skill2() -> void:
	## Gravity Well: a vortex that drags enemies together.
	Audio.play("magic", 0.0, 0.0)
	var well := Zones.GravityWell.new()
	well.world = world
	well.radius = 190.0 * area_mult
	well.position = aim_point(560.0)
	world.add_ground_fx(well)
	_sigil(well.position, well.radius, well.duration)


func _mage_ult() -> void:
	## Meteor Shower: a storm of falling stars around the target area.
	var center := aim_point(560.0)
	Audio.play("boss_roar", -8.0, 0.0)
	for i in 14:
		get_tree().create_timer(0.2 * i, false).timeout.connect(func() -> void:
			if dead:
				return
			var at := center + Vector2.from_angle(randf() * TAU) * 360.0 * sqrt(randf())
			_starfall(at, 120.0 * area_mult, 3.0))


func _starfall(target: Vector2, r: float, mult: float) -> void:
	_sigil(target, r, 0.85)
	var streak = FX.StarStreak.new()
	streak.position = target
	world.add_top_fx(streak)
	var tel = FX.Telegraph.new()
	tel.radius = r
	tel.duration = 0.45
	tel.color = Color(0.5, 0.6, 1.0)
	tel.position = target
	tel.on_done = func() -> void: _starfall_impact(target, r, mult)
	world.add_ground_fx(tel)


# --- Sylva (ranger)
func _ranger_skill() -> void:
	Audio.play("arrow", 2.0, 0.0)
	var origin := global_position + Vector2(0, -40)
	var n := 9 + 2 * extra_projectiles
	_fire_spread("arrow", origin, data.proj_speed * 1.1, 1.2, 2 + extra_pierce, 0.9, 12.0, n, deg_to_rad(70.0) / (n - 1))


func _ranger_skill2() -> void:
	## Vault Shot: leap backwards leaving a snare, firing three heavy arrows.
	var snare := Zones.Snare.new()
	snare.world = world
	snare.radius = 130.0 * area_mult
	snare.position = global_position
	world.add_ground_fx(snare)
	_sigil(snare.position, snare.radius, snare.duration)
	_dash_dir = -aim_dir
	_dash_t = DASH_TIME * 1.3
	_invuln = maxf(_invuln, _dash_t + 0.1)
	Audio.play("dash")
	var origin := global_position + Vector2(0, -40)
	_fire_spread("arrow", origin, data.proj_speed * 1.2, 2.0, 4 + extra_pierce, 1.0, 14.0, 3, 0.1)


func _ranger_ult() -> void:
	## Arrow Rain: a long volley over the target area that slows everything in it.
	var rain := Zones.ArrowRain.new()
	rain.world = world
	rain.radius = 230.0 * area_mult
	rain.position = aim_point(600.0)
	world.add_ground_fx(rain)
	_sigil(rain.position, rain.radius, rain.duration)
	Audio.play("knives", 0.0, 0.0)


# --- Leon (knight)
func _knight_skill() -> void:
	Audio.play("roar")
	var r := 200.0 * area_mult
	world.shake(10.0)
	world.spawn_ring(global_position + Vector2(0, -20), r, Color(1, 0.8, 0.4), 0.45)
	_invuln = maxf(_invuln, 0.5)
	for e in world.enemies_in_radius(global_position, r):
		var dir: Vector2 = (e.global_position - global_position).normalized()
		e.stun = maxf(e.stun, 1.3)
		world.player_hit_enemy(e, 2.5, dir * 520.0)


func _knight_skill2() -> void:
	## Shield Charge: rush forward, bowling enemies aside.
	_charge_dir = aim_dir
	_charge_t = 0.32
	_charge_hits.clear()
	_invuln = maxf(_invuln, 0.42)
	Audio.play("swing_heavy", 2.0, 0.0)


func _shield_charge(delta: float) -> void:
	_charge_t -= delta
	velocity = _charge_dir * 1250.0
	_afterimage_t -= delta
	if _afterimage_t <= 0.0:
		_afterimage_t = 0.03
		var ai = _afterimage(global_position, Color(1, 0.85, 0.45))
		world.add_ground_fx(ai)
	for e in world.enemies_in_radius(global_position, 70.0 * area_mult):
		if _charge_hits.has(e):
			continue
		_charge_hits[e] = true
		var side := _charge_dir.orthogonal()
		if side.dot(e.global_position - global_position) < 0.0:
			side = -side
		e.stun = maxf(e.stun, 0.8)
		world.player_hit_enemy(e, 1.8, (side + _charge_dir * 0.5).normalized() * 420.0)


func _knight_ult() -> void:
	## Lion King's Judgment: a giant blade falls, then Leon is empowered for 6 s.
	var at := global_position
	var r := 260.0 * area_mult
	var sword = FX.SwordFall.new()
	sword.position = at
	world.add_top_fx(sword)
	_invuln = maxf(_invuln, 0.6)
	get_tree().create_timer(0.45, false).timeout.connect(func() -> void:
		if dead:
			return
		Audio.play("explosion")
		Audio.play("roar", -2.0, 0.0)
		world.shake(16.0)
		world.spawn_ring(at, r, Color(1, 0.85, 0.4), 0.6)
		world.spawn_burst(at + Vector2(0, -30), Color(1, 0.85, 0.4), 26, 460.0)
		for e in world.enemies_in_radius(at, r):
			e.stun = maxf(e.stun, 1.5)
			world.player_hit_enemy(e, 5.0, (e.global_position - at).normalized() * 500.0)
		_awaken_t = 6.0)


func _starfall_impact(at: Vector2, r: float, mult: float) -> void:
	if dead or not is_instance_valid(world):
		return
	Audio.play("explosion")
	world.shake(9.0)
	world.spawn_ring(at, r, Color(0.55, 0.65, 1.0), 0.45)
	world.spawn_burst(at, Color(0.7, 0.8, 1.0), 22, 420.0)
	for e in world.enemies_in_radius(at, r):
		world.player_hit_enemy(e, mult, (e.global_position - at).normalized() * 300.0)


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
func shield_max() -> float:
	var base: float = data.get("barrier", 0.0)
	return base + max_hp * 0.08 if base > 0.0 else 0.0


func apply_pull(v: Vector2) -> void:
	_pull = v


func roll_damage(mult: float) -> Array:
	## Returns [amount, is_crit].
	var amount := damage * mult * randf_range(0.9, 1.1)
	if _awaken_t > 0.0:
		amount *= 1.4
	var crit := _force_crit or randf() < crit_chance
	if crit:
		amount *= crit_mult
	return [amount, crit]


func take_damage(amount: float, source: Node) -> bool:
	if dead or _invuln > 0.0 or _dash_t > 0.0 or _charge_t > 0.0 or _dance_left > 0:
		return false
	var final := amount * (1.0 - clampf(armor, 0.0, 0.7))
	if _awaken_t > 0.0:
		final *= 0.7
	if shield_max() > 0.0:
		_shield_delay = BARRIER_DELAY
		var soaked := minf(shield, final)
		if soaked > 0.0:
			shield -= soaked
			final -= soaked
			world.show_damage(global_position + Vector2(0, -110), soaked, Color(0.55, 0.75, 1.0), false)
			if final <= 0.0:
				# Fully absorbed: brief protection, no health lost.
				_invuln = HIT_INVULN * 0.5
				Audio.play("magic", -8.0, 0.2)
				return true
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
		_visual.dead = true
		if not _visual.has_sprite() or _visual.SpriteSet.resolve(_visual._sprite, "death") == "":
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
		"focus": cd_mult *= 0.88
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


func _afterimage(at: Vector2, color: Color) -> Node2D:
	var image := FX.Afterimage.new()
	image.position = at
	image.color = color
	if _visual.has_sprite():
		var sprite: AnimatedSprite2D = _visual._sprite
		image.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		image.sprite_offset = sprite.offset
		image.sprite_scale = sprite.scale * Vector2(-1.0 if sprite.flip_h else 1.0, 1.0)
	return image


func _sigil(at: Vector2, radius: float, duration: float) -> void:
	var seal := FX.Sigil.new()
	seal.theme = hero_id
	seal.position = at
	seal.radius = radius
	seal.life = duration
	seal.intensity = 0.7 if duration > 1.0 else 1.0
	world.add_ground_fx(seal)
