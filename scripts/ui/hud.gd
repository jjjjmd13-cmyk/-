extends CanvasLayer
## In-game heads-up display, drawn directly for crisp, cheap rendering.

const HEROES := preload("res://scripts/data/heroes.gd")

var world: Node
var _canvas: HudCanvas


func _ready() -> void:
	layer = 5
	_canvas = HudCanvas.new()
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

	func _process(delta: float) -> void:
		banner_t += delta
		queue_redraw()

	func _draw() -> void:
		var p: Node = world.player
		if not is_instance_valid(p):
			return
		var size_v := size
		var f: Font = Game.font_bold
		var fr: Font = Game.font

		# ---- Portrait and bars (top-left).
		var origin := Vector2(28, 26)
		var pr := Rect2(origin, Vector2(112, 112))
		draw_rect(pr.grow(4), Color(0.05, 0.03, 0.04, 0.9))
		if portrait:
			var tw := float(portrait.get_width())
			draw_texture_rect_region(portrait, pr, Rect2(tw * 0.22, 0, tw * 0.56, tw * 0.56))
		draw_rect(pr.grow(4), accent, false, 3.0)

		var frac: float = clampf(p.hp / p.max_hp, 0.0, 1.0)
		_shown_hp = lerpf(_shown_hp, frac, 0.08)
		var bar := Rect2(origin + Vector2(130, 6), Vector2(420, 34))
		_bar(bar, 1.0, Color(0.06, 0.03, 0.04, 0.92))
		_bar(bar, _shown_hp, Color(0.9, 0.85, 0.75, 0.5))
		_bar(bar, frac, Color(0.75, 0.1, 0.14))
		var smax: float = p.shield_max()
		if smax > 0.0 and p.shield > 0.0:
			# Barrier shown as a blue strip along the top of the health bar.
			var sb := Rect2(bar.position, Vector2(bar.size.x, 9))
			_bar(sb, clampf(p.shield / smax, 0.0, 1.0), Color(0.45, 0.7, 1.0, 0.95))
		draw_rect(bar, Color(0.55, 0.42, 0.28), false, 2.0)
		var hp_txt := "%d / %d" % [ceili(p.hp), roundi(p.max_hp)]
		if p.shield >= 1.0:
			hp_txt += "  (+%d)" % floori(p.shield)
		_text_center(f, hp_txt, bar.get_center() + Vector2(0, 8), 22, Color.WHITE)

		var xbar := Rect2(origin + Vector2(130, 50), Vector2(420, 18))
		var xfrac: float = clampf(float(p.xp) / float(p.xp_to_next()), 0.0, 1.0)
		_bar(xbar, 1.0, Color(0.06, 0.03, 0.04, 0.92))
		_bar(xbar, xfrac, Color(0.35, 0.65, 1.0))
		draw_rect(xbar, Color(0.35, 0.3, 0.3), false, 1.5)
		_text(f, Game.t("hud_level") % p.level, origin + Vector2(132, 104), 26, Game.COLOR_GOLD)

		# ---- Wave info (top-centre).
		var cx := size_v.x / 2.0
		var wave_txt := Game.t("hud_wave") % [maxi(world.wave, 1), world.TOTAL_WAVES]
		if world.endless:
			wave_txt = Game.t("hud_wave_endless") % world.wave
		_text_center(f, wave_txt, Vector2(cx, 56), 34, Game.COLOR_TEXT)
		if world.state == "fighting" and not world.is_boss_wave(world.wave):
			var wb := Rect2(cx - 160, 70, 320, 8)
			_bar(wb, 1.0, Color(0.06, 0.03, 0.04, 0.9))
			_bar(wb, clampf(world.wave_time / world.wave_duration, 0.0, 1.0), Color(0.86, 0.71, 0.42))

		# Boss health.
		var boss: Node = world.boss
		if is_instance_valid(boss) and not boss.dead:
			# Souls-style bar at the bottom keeps the top of the arena clear.
			var bb := Rect2(cx - 450, size_v.y - 190, 900, 24)
			_bar(bb, 1.0, Color(0.06, 0.03, 0.04, 0.92))
			_bar(bb, clampf(boss.hp / boss.max_hp, 0.0, 1.0), Color(0.55, 0.05, 0.1))
			draw_rect(bb, Color(0.86, 0.71, 0.42), false, 2.0)
			_text_center(f, Game.t("boss_" + boss.kind), Vector2(cx, size_v.y - 202), 28, Color(1, 0.75, 0.7))
			_boss_pointer(boss)

		# ---- Time & kills (top-right).
		var rx := size_v.x - 30
		_text_right(f, preload("res://scripts/ui/ui.gd").format_time(world.run_time), Vector2(rx, 56), 34, Game.COLOR_TEXT)
		_text_right(fr, Game.t("hud_kills") % world.kills, Vector2(rx, 94), 24, Game.COLOR_DIM)
		if Game.difficulty == "hard":
			_text_right(f, Game.t("diff_hard"), Vector2(rx, 128), 22, Color(1, 0.4, 0.35))

		# ---- Cooldowns (bottom-centre).
		var by := size_v.y - 90
		var pre := "pad_" if Input.get_connected_joypads().size() > 0 else "key_"
		_cooldown(Vector2(cx - 210, by), Game.t(pre + "skill"), p.cooldown_ready("skill"), accent)
		_cooldown(Vector2(cx - 70, by), Game.t(pre + "skill2"), p.cooldown_ready("skill2"), accent)
		_cooldown(Vector2(cx + 70, by), Game.t(pre + "ult"), p.cooldown_ready("ult"), Game.COLOR_GOLD)
		if p.cooldown_ready("ult") >= 1.0:
			draw_arc(Vector2(cx + 70, by), 48.0 + 3.0 * sin(banner_t * 6.0), 0, TAU, 48, Color(1, 0.85, 0.4, 0.8), 3.0, true)
		_cooldown(Vector2(cx + 210, by), Game.t(pre + "dash"), 1.0 - p.dash_timer / p.dash_cd, Color(0.8, 0.8, 0.85))

		# ---- Banner.
		if banner_t < banner_len:
			var a := clampf(banner_t / 0.3, 0.0, 1.0) * clampf((banner_len - banner_t) / 0.6, 0.0, 1.0)
			var y := size_v.y * 0.32
			draw_rect(Rect2(0, y - 70, size_v.x, 130 if banner_sub != "" else 100), Color(0, 0, 0, 0.45 * a))
			_text_center(f, banner, Vector2(cx, y), 64, Color(Game.COLOR_GOLD.r, Game.COLOR_GOLD.g, Game.COLOR_GOLD.b, a), true)
			if banner_sub != "":
				_text_center(fr, banner_sub, Vector2(cx, y + 46), 28, Color(1, 0.7, 0.65, a))

	func _bar(r: Rect2, frac: float, col: Color) -> void:
		if frac <= 0.0:
			return
		draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), col)

	func _text(font: Font, t: String, pos: Vector2, fs: int, col: Color) -> void:
		draw_string_outline(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.75 * col.a))
		draw_string(font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _text_center(font: Font, t: String, pos: Vector2, fs: int, col: Color, big_outline := false) -> void:
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(font, pos - Vector2(w / 2, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			10 if big_outline else 6, Color(0.1, 0.0, 0.02, 0.85 * col.a))
		draw_string(font, pos - Vector2(w / 2, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _text_right(font: Font, t: String, pos: Vector2, fs: int, col: Color) -> void:
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_text(font, t, pos - Vector2(w, 0), fs, col)

	func _cooldown(c: Vector2, label_text: String, ready_frac: float, col: Color) -> void:
		ready_frac = clampf(ready_frac, 0.0, 1.0)
		var r := 40.0
		draw_circle(c, r + 4, Color(0.05, 0.03, 0.04, 0.85))
		if ready_frac >= 1.0:
			draw_circle(c, r, Color(col.r, col.g, col.b, 0.35))
			draw_arc(c, r, 0, TAU, 48, col, 4.0, true)
		else:
			var pts := PackedVector2Array([c])
			var steps := 32
			for i in steps + 1:
				pts.append(c + Vector2.from_angle(-PI / 2 + TAU * ready_frac * i / steps) * r)
			if pts.size() >= 3 and ready_frac > 0.01:
				draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.25))
			draw_arc(c, r, -PI / 2, -PI / 2 + TAU * ready_frac, 48, Color(col.r, col.g, col.b, 0.7), 4.0, true)
		_text_center(Game.font_bold, label_text, c + Vector2(0, 8), 20, Color.WHITE if ready_frac >= 1.0 else Game.COLOR_DIM)

	func _boss_pointer(boss: Node) -> void:
		var cam := get_viewport().get_camera_2d()
		if cam == null:
			return
		var screen_pos: Vector2 = get_viewport().get_canvas_transform() * (boss.global_position + Vector2(0, -80))
		var vr := Rect2(Vector2.ZERO, size)
		if vr.grow(-40).has_point(screen_pos):
			return
		var center := size / 2.0
		var dir := (screen_pos - center).normalized()
		var edge := Vector2(
			clampf(center.x + dir.x * size.x, 60, size.x - 60),
			clampf(center.y + dir.y * size.y, 150, size.y - 230))
		var pts := PackedVector2Array([
			edge + dir * 24, edge + dir.orthogonal() * 16 - dir * 10, edge - dir.orthogonal() * 16 - dir * 10])
		draw_colored_polygon(pts, Color(0.9, 0.15, 0.15, 0.85 + 0.15 * sin(banner_t * 8.0)))
