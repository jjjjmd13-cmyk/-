extends Node
const Main := preload("res://scenes/main.tscn")
const Sprites := preload("res://scripts/game/sprite_set.gd")
func _ready() -> void:
	_run()
func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
func _run() -> void:
	var specs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/art_sources/cast/specs.json"))
	for spec in specs:
		var model: Node = (load("res://assets/models/cast/%s/%s.glb" % [spec.group, spec.id]) as PackedScene).instantiate()
		add_child(model)
		var clips := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert(clips != null)
		for anim in ["idle", "run", "attack"]:
			assert(clips.has_animation(anim), spec.id + " missing " + anim)
		var name := "Wing-1" if spec.id == "bat" else ("Pelvis" if spec.family == "ghost" else "Thigh-1")
		var joint := model.find_child(name, true, false) as Node3D
		assert(joint != null)
		clips.play("run")
		clips.advance(0)
		var before := joint.transform
		clips.advance(0.19)
		assert(not joint.transform.is_equal_approx(before), spec.id + " static rig")
		model.queue_free()
		var sf := Sprites.frames_for(spec.group, spec.id)
		assert(sf != null)
		for anim in ["idle", "run", "attack"]:
			assert(sf.get_frame_count(anim) == (5 if anim == "idle" else 10))
			assert(sf.get_frame_texture(anim, 0).get_height() == int(spec.size))
			var alt := Image.load_from_file("res://assets/sprites/variants/8/%s/%s/%s.png" % [spec.group, spec.id, anim])
			assert(not alt.is_empty() and alt.get_width() == int(spec.size) * (4 if anim == "idle" else 8))
		if spec.group == "bosses":
			assert(sf.get_frame_count("cast") == 10 and not sf.get_animation_loop("cast"))
	var original := Game.settings.duplicate(true)
	Game.settings.auto_attack = false
	Game.settings.screen_shake = false
	var main: Node = Main.instantiate()
	add_child(main)
	await frames(4)
	for hero in ["knight", "ranger", "mage", "rogue"]:
		Game.selected_hero = hero
		main.start_run()
		await frames(5)
		var w: Node = main._current
		w._state_t = 999
		var p: Node = w.player
		p._using_pad = true
		p._invuln = 30
		Input.action_press("move_right")
		await frames(45)
		Input.action_release("move_right")
		var s: AnimatedSprite2D = p._visual._sprite
		assert(s.position == Vector2.ZERO and is_zero_approx(s.rotation))
		assert(is_equal_approx((s.material as ShaderMaterial).get_shader_parameter("stride"), 1.0))
		p._attack()
		await frames(2)
		assert(s.animation == "attack")
		main._on_exit("menu")
		await frames(3)
	Game.selected_hero = "knight"
	main.start_run()
	await frames(5)
	var world: Node = main._current
	world._state_t = 999
	for spec in specs:
		if spec.group == "heroes":
			continue
		var e: Node = world.spawn_enemy_at(spec.id, world.player.position + Vector2(500, 0), false)
		e.set_physics_process(false)
		e._visual.set_process(false)
		e._state = "chase"
		e._shot_cd = 10.0
		e.velocity = Vector2(50, 0)
		e._visual._process(0.016)
		var s: AnimatedSprite2D = e._visual.sprite
		assert(s.animation == "run")
		assert(e._visual.position.y == 0 and e._visual.rotation == 0)
		if spec.group == "bosses":
			e._state = "cast"
			e._state_t = 0.8
			e._visual._process(0.016)
			assert(s.animation == "cast")
			assert(is_equal_approx(s.speed_scale, (10.0 / s.sprite_frames.get_animation_speed("cast")) / 0.8))
		elif spec.id in ["archer", "cultist"]:
			e._shot_cd = 0.2
			e._visual._process(0.016)
			assert(s.animation == "attack" and s.self_modulate != Color.WHITE)
		else:
			e.contact_cd = 0.9
			e._visual._process(0.016)
			assert(s.animation == "attack")
		e.queue_free()
	main._on_exit("menu")
	await frames(5)
	Game.settings = original
	print("CAST MOTION OK: 17 animated GLBs, 34 atlas variants, 4 heroes and 13 enemies/bosses in live gameplay")
	Game.quit_game()
