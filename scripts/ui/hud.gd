extends CanvasLayer
## Gothic combat HUD. Keyboard/gamepad bindings remain authoritative in Game.
const HEROES := preload("res://scripts/data/heroes.gd")
const ART := preload("res://scripts/game/combat_art.gd")
var world: Node
var _canvas: HudCanvas

func _ready() -> void:
	layer = 5
	_canvas = HudCanvas.new()
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_canvas.world = world
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.theme = Game.theme
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d: Dictionary = HEROES.DATA[Game.selected_hero]
	_canvas.portrait = load(d.portrait)
	_canvas.accent = d.accent
	add_child(_canvas)

func show_banner(text: String, sub: String, duration: float = 3.0) -> void:
	_canvas.banner = text
	_canvas.banner_sub = sub
	_canvas.banner_len = duration
	_canvas.banner_t = 0.0

class HudCanvas extends Control:
	var world: Node
	var portrait: Texture2D
	var accent := Color.WHITE
	var banner := ""
	var banner_sub := ""
	var banner_t := 99.0
	var banner_len := 3.0
	var _shown_hp := 1.0
	var _panel_styles: Dictionary = {}
	var _view := Vector2(1920, 1080)
	var _scale := 1.0
	const GOLD := Color(0.69, 0.54, 0.32)
	const LIGHT := Color(0.94, 0.86, 0.69)
	const INK := Color(0.025, 0.033, 0.044, 0.94)

	func _process(delta: float) -> void:
		banner_t += delta
		if is_instance_valid(world.player):
			var target: float = clampf(world.player.hp / world.player.max_hp, 0, 1)
			_shown_hp = lerpf(_shown_hp, target, 1.0 - exp(-delta * 5.0))
		queue_redraw()

	func _draw() -> void:
		var p: Node = world.player
		if not is_instance_valid(p):
			return
		_scale = minf(1.0, minf(size.x / 1600.0, size.y / 900.0))
		_view = size / _scale
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * _scale)
		_vitals(p)
		var cx := _view.x * 0.5
		var wave_txt := Game.t("hud_wave") % [maxi(world.wave, 1), world.TOTAL_WAVES]
		if world.endless:
			wave_txt = Game.t("hud_wave_endless") % world.wave
		_panel(Rect2(cx - 148, 20, 296, 78), GOLD.darkened(0.35))
		_text_center(wave_txt, Vector2(cx, 55), 23, LIGHT)
		var wb := Rect2(cx - 112, 72, 224, 3)
		draw_rect(wb, Color(0.18, 0.16, 0.13))
		if world.state == "fighting" and not world.is_boss_wave(world.wave):
			_bar(wb, clampf(world.wave_time / world.wave_duration, 0, 1), GOLD.lightened(0.2))
		_diamond(Vector2(cx, 98), 5, GOLD)
		_panel(Rect2(_view.x - 232, 20, 208, 94), GOLD.darkened(0.55))
		_text_right(preload("res://scripts/ui/ui.gd").format_time(world.run_time), Vector2(_view.x - 48, 55), 27, LIGHT)
		_text_right(Game.t("hud_kills") % world.kills, Vector2(_view.x - 48, 88), 18, Color(0.64, 0.65, 0.65))
		if Game.difficulty == "hard":
			_text_right(Game.t("diff_hard"), Vector2(_view.x - 48, 140), 17, Color(1, 0.45, 0.35))
		var boss: Node = world.boss
		if is_instance_valid(boss) and not boss.dead:
			var by := _view.y - 232
			var bw := minf(820.0, _view.x - 300)
			_panel(Rect2(cx - bw / 2 - 18, by - 12, bw + 36, 42), GOLD)
			var bb := Rect2(cx - bw / 2, by, bw, 16)
			_meter(bb, clampf(boss.hp / boss.max_hp, 0, 1), Color(0.62, 0.07, 0.13))
			_text_center(Game.t("boss_" + boss.kind), Vector2(cx, by - 27), 25, LIGHT)
			_boss_pointer(boss)
		_belt(p)
		if banner_t < banner_len:
			var a := clampf(banner_t / 0.3, 0, 1) * clampf((banner_len - banner_t) / 0.6, 0, 1)
			var y := _view.y * 0.28
			draw_rect(Rect2(cx - 460, y - 63, 920, 122), Color(0.02, 0.02, 0.025, 0.78 * a))
			draw_line(Vector2(cx - 380, y - 63), Vector2(cx + 380, y - 63), Color(GOLD, a), 1, true)
			_text_center(banner, Vector2(cx, y), 49, Color(LIGHT, a))
			if banner_sub != "":
				_text_center(banner_sub, Vector2(cx, y + 37), 22, Color(0.87, 0.7, 0.61, a))
		draw_set_transform(Vector2.ZERO)

	func _vitals(p: Node) -> void:
		_panel(Rect2(22, 20, 540, 132), GOLD.darkened(0.4))
		var pr := Rect2(36, 34, 100, 100)
		draw_rect(pr.grow(3), Color(0.02, 0.02, 0.025))
		if portrait:
			var tw := float(portrait.get_width())
			draw_texture_rect_region(portrait, pr, Rect2(tw * 0.22, 0, tw * 0.56, tw * 0.56))
		draw_rect(pr.grow(3), GOLD, false, 2)
		draw_rect(pr.grow(6), GOLD.darkened(0.5), false, 1)
		for x in [pr.position.x - 6, pr.end.x + 6]:
			for y in [pr.position.y - 6, pr.end.y + 6]:
				_diamond(Vector2(x, y), 4, LIGHT.darkened(0.2))
		_text(Game.t(HEROES.DATA[p.hero_id].name), Vector2(157, 49), 21, LIGHT)
		_text_right(Game.t("hud_level") % p.level, Vector2(538, 49), 16, GOLD.lightened(0.3))
		var hp_r := Rect2(157, 63, 380, 27)
		draw_rect(hp_r.grow(4), Color(0.02, 0.02, 0.025))
		_bar(hp_r, _shown_hp, Color(0.7, 0.54, 0.35, 0.7))
		var frac: float = clampf(p.hp / p.max_hp, 0, 1)
		var blood := Color(0.72, 0.08, 0.13)
		if frac < 0.3:
			blood = blood.lightened(0.12 + 0.12 * sin(banner_t * 6))
		_meter(hp_r, frac, blood, false)
		draw_rect(hp_r.grow(3), GOLD, false, 1)
		_text_center("%d / %d" % [ceili(p.hp), roundi(p.max_hp)], hp_r.get_center() + Vector2(0, 7), 18, Color(1, 0.92, 0.85))
		var shield_max: float = p.shield_max()
		var sr := Rect2(157, 99, 380, 5)
		draw_rect(sr, Color(0.08, 0.12, 0.17))
		if shield_max > 0:
			_bar(sr, p.shield / shield_max, Color(0.47, 0.75, 1))
			_text("+%d" % ceili(p.shield), Vector2(157, 125), 14, Color(0.55, 0.78, 1))
		var xp_r := Rect2(218 if shield_max > 0 else 157, 116, 319 if shield_max > 0 else 380, 4)
		draw_rect(xp_r, Color(0.12, 0.13, 0.13))
		_bar(xp_r, clampf(float(p.xp) / p.xp_to_next(), 0, 1), Color(0.72, 0.61, 0.37))

	func _belt(p: Node) -> void:
		var cx := _view.x * 0.5
		var top := _view.y - 167
		_panel(Rect2(cx - 300, top - 12, 600, 158), GOLD.darkened(0.35))
		# Short horizontal flourishes connect the belt to the battlefield.
		for side in [-1, 1]:
			draw_line(Vector2(cx + side * 310, top + 60), Vector2(cx + side * 365, top + 60), GOLD.darkened(0.2), 1, true)
			_diamond(Vector2(cx + side * 370, top + 60), 5, GOLD)
		var pre := "pad_" if Input.get_connected_joypads().size() > 0 else "key_"
		var slots := ["skill", "skill2", "ult", "dash"]
		for i in 4:
			var slot: String = slots[i]
			var ready: float = p.cooldown_ready(slot) if i < 3 else clampf(1.0 - p.dash_timer / p.dash_cd, 0, 1)
			var remaining: float = p.timers[slot] if i < 3 else p.dash_timer
			var name_key: String = HEROES.DATA[p.hero_id][slot] if i < 3 else "hud_dash"
			var title := Game.t(name_key).split(" - ")[0]
			var x := cx - 198 + i * 132
			var frame := Rect2(x - 42, top, 84, 84)
			var col := Color(0.94, 0.73, 0.35) if i == 2 else accent.lightened(0.12)
			var pressing := Input.is_action_pressed(slot)
			draw_rect(frame.grow(5), Color(0.01, 0.015, 0.02))
			draw_texture_rect(ART.icon(p.hero_id, i), frame, false, Color(0.75, 0.75, 0.75) if ready < 1 else Color.WHITE)
			if ready < 1:
				# A radial shadow, countdown, and bottom progress strip communicate CD.
				var pts := PackedVector2Array([frame.get_center()])
				for k in 41:
					var a := -PI / 2 + (1.0 - ready) * TAU * k / 40.0
					var d := Vector2.from_angle(a)
					pts.append(frame.get_center() + d * (42.0 / maxf(absf(d.x), absf(d.y))))
				if pts.size() > 2:
					draw_colored_polygon(pts, Color(0.015, 0.02, 0.04, 0.74))
				_text_center("%.1f" % remaining if remaining < 10 else str(ceili(remaining)), frame.get_center() + Vector2(0, 10), 27, Color(1, 0.96, 0.88))
			else:
				draw_rect(frame.grow(3), Color(col, 0.28 + 0.12 * sin(banner_t * 3)), false, 5)
			draw_rect(frame.grow(3), LIGHT if pressing else (col if ready >= 1 else GOLD.darkened(0.5)), false, 2)
			draw_line(frame.position + Vector2(0, -3), Vector2(frame.end.x, frame.position.y - 3), Color(1, 0.92, 0.74, 0.65), 1)
			for side in [-1, 1]:
				_diamond(Vector2(x + side * 46, top + 42), 4, col.darkened(0.2))
			var cap := Rect2(x - 29, top + 74, 58, 24)
			_panel(cap, GOLD)
			_text_center(Game.t(pre + slot), Vector2(x, top + 91), 14, LIGHT)
			var title_size := 15
			while title_size > 11 and Game.font_bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > 122:
				title_size -= 1
			_text_center(title, Vector2(x, top + 122), title_size, Color(0.83, 0.81, 0.75))
			_bar(Rect2(x - 38, top + 134, 76, 2), ready, col)

	func _panel(rect: Rect2, border: Color) -> void:
		var key := border.to_rgba32()
		if not _panel_styles.has(key):
			var box := StyleBoxFlat.new()
			box.bg_color = INK
			box.border_color = border
			box.set_border_width_all(1)
			box.set_corner_radius_all(5)
			box.shadow_color = Color(0, 0, 0, 0.38)
			box.shadow_size = 8
			_panel_styles[key] = box
		var style: StyleBoxFlat = _panel_styles[key]
		draw_style_box(style, rect)
		draw_line(rect.position + Vector2(9, 3), Vector2(rect.end.x - 9, rect.position.y + 3), Color(border.lightened(0.25), 0.42), 1, true)

	func _meter(rect: Rect2, frac: float, col: Color, background := true) -> void:
		if background:
			draw_rect(rect, Color(0.045, 0.02, 0.03))
		if frac <= 0:
			return
		for i in 12:
			var band := Rect2(rect.position + Vector2(0, rect.size.y * i / 12), Vector2(rect.size.x * frac, rect.size.y / 12 + 0.5))
			draw_rect(band, col.lightened(0.2 * sin(PI * i / 12.0)).darkened(0.28 * i / 12.0))
		draw_line(rect.position + Vector2(0, 2), rect.position + Vector2(rect.size.x * frac, 2), Color(1, 0.63, 0.48, 0.5), 1)
		draw_line(rect.position + Vector2(rect.size.x * frac, 1), rect.position + Vector2(rect.size.x * frac, rect.size.y - 1), Color(1, 0.86, 0.65, 0.65), 2)

	func _bar(rect: Rect2, frac: float, col: Color) -> void:
		if frac > 0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(frac, 0, 1), rect.size.y)), col)

	func _diamond(at: Vector2, radius: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0), at + Vector2(0, radius), at + Vector2(-radius, 0)]), col)

	func _text(t: String, pos: Vector2, fs: int, col: Color) -> void:
		draw_string_outline(Game.font_bold, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.8 * col.a))
		draw_string(Game.font_bold, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _text_center(t: String, pos: Vector2, fs: int, col: Color) -> void:
		_text(t, pos - Vector2(Game.font_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2, 0), fs, col)

	func _text_right(t: String, pos: Vector2, fs: int, col: Color) -> void:
		_text(t, pos - Vector2(Game.font_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, 0), fs, col)

	func _boss_pointer(boss: Node) -> void:
		var screen_pos: Vector2 = (get_viewport().get_canvas_transform() * (boss.global_position + Vector2(0, -80))) / _scale
		if Rect2(Vector2(50, 160), _view - Vector2(100, 430)).has_point(screen_pos):
			return
		var center := _view / 2
		var dir := (screen_pos - center).normalized()
		var edge := Vector2(clampf(center.x + dir.x * _view.x, 60, _view.x - 60), clampf(center.y + dir.y * _view.y, 170, _view.y - 270))
		draw_colored_polygon(PackedVector2Array([edge + dir * 20, edge + dir.orthogonal() * 12 - dir * 10, edge - dir.orthogonal() * 12 - dir * 10]), Color(0.85, 0.16, 0.18, 0.85 + 0.15 * sin(banner_t * 8)))
