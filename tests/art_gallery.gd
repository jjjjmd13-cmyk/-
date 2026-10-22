extends Node2D
## A review image drawn by Godot using the same runtime SpriteFrames and VFX.
const Sprites := preload("res://scripts/game/sprite_set.gd")
const FX := preload("res://scripts/game/fx.gd")

func label_at(text: String, at: Vector2, size := 22, color := Color(0.84, 0.79, 0.68)) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font", Game.font_bold)
	label.add_theme_font_size_override("font_size", size)
	label.modulate = color
	add_child(label)

func actor(group: String, id: String, at: Vector2, mult := 1.0) -> void:
	var sprite := Sprites.make_sprite(group, id)
	assert(sprite != null)
	sprite.position = at
	sprite.scale *= mult
	add_child(sprite)

func _ready() -> void:
	label_at("CRIMSON OATH  /  CHARACTER & VFX PASS", Vector2(70, 34), 34)
	label_at("영웅 4명 · 일반/소환 몬스터 10종 · 보스 3종   |   게임 엔진 실시간 렌더링", Vector2(70, 84), 20)
	for i in 4:
		var id: String = ["knight", "ranger", "mage", "rogue"][i]
		var at := Vector2(300 + i * 440, 355)
		var seal := FX.Sigil.new()
		seal.theme = id
		seal.radius = 104.0
		seal.life = 10.0
		seal.position = at + Vector2(0, 20)
		seal.scale.y = 0.45
		add_child(seal)
		actor("heroes", id, at, 2.1)
		label_at(["레온 · 사자 기사", "실바 · 숲의 궁수", "아스트라 · 별의 마법사", "베스퍼 · 진홍의 그림자"][i], at + Vector2(-110, 30))
	var ids := ["ghoul", "bat", "archer", "brute", "cultist", "wraith", "bomber", "shield", "necro", "skeleton"]
	var names := ["구울", "박쥐", "해골 궁수", "거인", "사교도", "망령", "폭탄 시체", "방패병", "강령술사", "해골 병사"]
	for i in ids.size():
		var at := Vector2(115 + i * 188, 615)
		actor("enemies", ids[i], at, 1.5)
		label_at(names[i], at + Vector2(-42, 18), 19)
	for i in 3:
		var at := Vector2(380 + i * 580, 990)
		actor("bosses", ["dread_knight", "blood_witch", "void_lord"][i], at, 1.5 if i < 2 else 1.25)
		label_at(["공포의 기사", "핏빛 마녀", "공허의 군주"][i], at + Vector2(-70, 22), 24)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var output := args[0] if args.size() else "user://art_gallery.png"
	get_viewport().get_texture().get_image().save_png(output)
	print("GALLERY SAVED: ", output)
	Game.quit_game()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.035, 0.04, 0.055))
	for y in [130, 430, 685]:
		draw_line(Vector2(70, y), Vector2(1850, y), Color(0.35, 0.28, 0.18), 1.0)
