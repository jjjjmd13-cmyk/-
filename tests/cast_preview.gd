extends Node2D
const Sprites := preload("res://scripts/game/sprite_set.gd")
var actors: Array[AnimatedSprite2D] = []
var output := ""
func label_at(text: String, at: Vector2, size := 22) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_override("font", Game.font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.modulate = Color(0.85, 0.8, 0.69)
	add_child(l)
func actor(group: String, id: String, at: Vector2, mult: float) -> void:
	var s := Sprites.make_sprite(group, id)
	assert(s != null)
	s.position = at
	s.scale *= mult
	add_child(s)
	actors.append(s)
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0] if args.size() else "user://cast-preview"
	DirAccess.make_dir_recursive_absolute(output)
	label_at("CRIMSON OATH / FULL CAST MOTION", Vector2(65, 25), 32)
	label_at("영웅 4 · 몬스터 10 · 보스 3 | 3D 포즈 가이드 + AI 마감 스프라이트 / Godot 실제 렌더", Vector2(65, 70), 20)
	for i in 4:
		var at := Vector2(280 + i * 450, 400)
		actor("heroes", ["knight", "ranger", "mage", "rogue"][i], at, 1.8)
		label_at(["레온 · 기사", "실바 · 궁수", "아스트라 · 마법사", "베스퍼 · 도적"][i], at + Vector2(-90, 14))
	var ids := ["ghoul", "bat", "archer", "brute", "cultist", "wraith", "bomber", "shield", "necro", "skeleton"]
	var names := ["구울", "박쥐", "해골 궁수", "거인", "사교도", "망령", "폭탄 시체", "방패병", "강령술사", "해골 병사"]
	for i in ids.size():
		var at := Vector2(110 + i * 188, 640)
		actor("enemies", ids[i], at, 1.2)
		label_at(names[i], at + Vector2(-42, 15), 18)
	for i in 3:
		var at := Vector2(355 + i * 600, 1000)
		actor("bosses", ["dread_knight", "blood_witch", "void_lord"][i], at, 1.15)
		label_at(["공포의 기사", "핏빛 마녀", "공허의 군주"][i], at + Vector2(-70, 15), 23)
	_run()
func grab(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(output.path_join(name + ".jpg"), 0.93)
func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
func _run() -> void:
	await frames(8)
	await grab("cast-idle")
	var index := 0
	for action in ["idle", "run", "attack"]:
		for s in actors:
			Sprites.play(s, action, 1.1 if action == "attack" else 0.0)
		for i in 30:
			if action == "attack" and i == 17:
				for s in actors:
					s.stop()
					Sprites.play(s, action, 1.1)
			await frames(4)
			await grab("frame_%04d" % index)
			index += 1
		await grab("cast-" + action)
	print("CAST PREVIEW OK: 17 runtime actors idle/run/attack")
	Game.quit_game()
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.035, 0.04, 0.055))
	for y in [115, 455, 695]:
		draw_line(Vector2(65, y), Vector2(1855, y), Color(0.3, 0.25, 0.17))
