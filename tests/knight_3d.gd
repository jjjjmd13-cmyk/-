extends Node
## Verifies the exported 3D rig and the actual 2D gameplay consumer together.
## With a display: -- /absolute/output captures the short gameplay sequence.
const Main := preload("res://scenes/main.tscn")
var main: Node
var output := ""
var capture_index := 0
var original: Dictionary

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		output = args[0]
		DirAccess.make_dir_recursive_absolute(output)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func capture() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(output.path_join("frame_%04d.jpg" % capture_index), 0.9)
	capture_index += 1

func segment(n: int) -> void:
	for i in n:
		await frames(2)
		if i % 2 == 0:
			await capture()

func _run() -> void:
	var packed: PackedScene = load("res://assets/models/leon/leon.glb")
	assert(packed != null)
	var model := packed.instantiate()
	add_child(model)
	var clips := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(clips != null)
	for clip in ["run", "idle", "attack"]:
		assert(clips.has_animation(clip), "Missing real 3D animation: " + clip)
	var joint := model.find_child("Thigh-1", true, false) as Node3D
	assert(joint != null)
	clips.play("run")
	clips.advance(0.0)
	var before := joint.transform
	clips.advance(0.3)
	assert(not joint.transform.is_equal_approx(before), "3D thigh joint is not animated")
	model.queue_free()
	original = Game.settings.duplicate(true)
	Game.settings.auto_attack = false
	Game.settings.screen_shake = false
	Game.settings.fullscreen = false
	main = Main.instantiate()
	add_child(main)
	await frames(5)
	Game.selected_hero = "knight"
	seed(27)
	main.start_run()
	await frames(5)
	var world: Node = main._current
	world._state_t = 999
	world._hud._canvas.banner_t = 99
	for child in world._entities.get_children():
		if child != world.player:
			child.queue_free()
	var player: Node = world.player
	player._invuln = 0
	player._using_pad = true
	player.aim_dir = Vector2.RIGHT
	var visual: Node = player._visual
	var sprite: AnimatedSprite2D = visual._sprite
	var sf := sprite.sprite_frames
	assert(sf.get_frame_count("idle") == 4)
	assert(sf.get_frame_count("run") == 10)
	assert(sf.get_frame_count("attack") == 10)
	assert(sf.get_frame_texture("run", 0).get_height() == 512)
	assert(is_equal_approx(sf.get_frame_count("run") / sf.get_animation_speed("run"), 0.65))
	var footsteps := [0]
	visual.footstep.connect(func() -> void: footsteps[0] += 1)
	await segment(15)
	Input.action_press("move_right")
	await segment(40)
	Input.action_release("move_right")
	assert(footsteps[0] >= 3 and footsteps[0] <= 5, "Authored run must emit two steps per cycle")
	assert(is_equal_approx((sprite.material as ShaderMaterial).get_shader_parameter("stride"), 1.0))
	assert(sprite.position == Vector2.ZERO, "Procedural bob was applied twice")
	player.aim_dir = Vector2.LEFT
	Input.action_press("move_left")
	await segment(35)
	Input.action_release("move_left")
	assert(sprite.flip_h)
	player.aim_dir = Vector2.RIGHT
	for i in 5:
		var enemy: Node = world.spawn_enemy_at("brute", player.position + Vector2(130 + i*28, (i-2)*45), false)
		enemy.hp = 100000
		enemy.max_hp = enemy.hp
		enemy.set_physics_process(false)
	Input.action_press("attack")
	await segment(55)
	assert(sprite.animation == "attack" or visual.attack_t < 0)
	Input.action_release("attack")
	player.level = 7
	player._use_skill("skill")
	await segment(20)
	player._use_skill("ult")
	await segment(30)
	Game.settings = original
	main._on_exit("menu")
	await frames(5)
	print("KNIGHT 3D OK: GLB run/idle/attack, animated thigh, runtime 4/10/10, two footfalls, no double warp, both facings and skills")
	Game.quit_game()
