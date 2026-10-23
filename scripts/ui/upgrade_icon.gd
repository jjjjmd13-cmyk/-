extends Control
## Vector glyph for a level-up card. Skill branch cards show the skill's own icon.

const ART := preload("res://scripts/game/combat_art.gd")
const UPGRADES := preload("res://scripts/data/upgrades.gd")
const SLOT_INDEX := {"skill": 0, "skill2": 1, "ult": 2}
const GLYPH := {
	"might": "sword", "temper": "sword", "boss_berserk": "sword", "evo_executioner": "axe",
	"frenzy": "haste", "swift": "boot", "swiftstep": "boot", "evo_tempest": "wind",
	"vitality": "heart", "fortitude": "heart", "elixir": "flask", "boss_colossus": "heart",
	"precision": "target", "boss_hunter": "target", "ferocity": "claw",
	"vampirism": "drop", "evo_blood_armor": "drop", "regeneration": "plus",
	"ironskin": "shield", "thorns": "spikes", "magnet": "magnet", "boss_crown": "crown",
	"focus": "hourglass", "boss_ascendance": "hourglass", "reach": "rings",
	"cleave": "crescent", "evo_whirlwind": "crescent", "multishot": "arrows",
	"evo_barrage": "arrows", "piercing": "pierce", "shadowstep": "dagger",
	"evo_nightblade": "dagger", "venom": "venom", "evo_plague": "venom", "boss_undying": "flame",
}

var id := "might"
var hero_id := "knight"
var color := Color(1, 0.8, 0.4)


func _ready() -> void:
	custom_minimum_size = Vector2(84, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var u: Dictionary = UPGRADES.card(id)
	draw_circle(c, 40.0, Color(0.04, 0.03, 0.04, 0.9))
	draw_arc(c, 40.0, 0, TAU, 48, Color(color, 0.9), 2.5, true)
	if u.has("slot"):
		var tex := ART.icon(hero_id, SLOT_INDEX[u.slot])
		draw_texture_rect(tex, Rect2(c - Vector2(30, 30), Vector2(60, 60)), false)
		return
	_glyph(GLYPH.get(id, "plus"), c, color.lightened(0.25))


func _glyph(g: String, c: Vector2, col: Color) -> void:
	var w := 4.0
	match g:
		"sword":
			draw_line(c + Vector2(-18, 18), c + Vector2(16, -16), col, w + 2, true)
			draw_line(c + Vector2(-20, 8), c + Vector2(-8, 20), col, w, true)
			draw_line(c + Vector2(-24, 24), c + Vector2(-17, 17), col, w + 2, true)
		"axe":
			draw_line(c + Vector2(-16, 20), c + Vector2(12, -14), col, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(4, -22), c + Vector2(22, -12), c + Vector2(14, 6), c + Vector2(6, -6)]), col)
		"haste":
			for i in 3:
				var x := -14.0 + i * 12.0
				draw_polyline(PackedVector2Array([c + Vector2(x, -14), c + Vector2(x + 10, 0), c + Vector2(x, 14)]), col, w, true)
		"boot", "wind":
			draw_polyline(PackedVector2Array([c + Vector2(-8, -20), c + Vector2(-8, 10), c + Vector2(16, 12), c + Vector2(16, 4), c + Vector2(2, 0), c + Vector2(2, -20)]), col, w, true)
			for i in 3:
				draw_line(c + Vector2(-26, -10 + i * 8), c + Vector2(-14, -10 + i * 8), Color(col, 0.7), 2.5, true)
		"heart":
			draw_circle(c + Vector2(-8, -6), 10, col)
			draw_circle(c + Vector2(8, -6), 10, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-17, -2), c + Vector2(17, -2), c + Vector2(0, 20)]), col)
		"flask":
			draw_circle(c + Vector2(0, 6), 14, col)
			draw_rect(Rect2(c + Vector2(-5, -20), Vector2(10, 14)), col)
		"target":
			draw_arc(c, 18, 0, TAU, 32, col, w, true)
			draw_arc(c, 8, 0, TAU, 24, col, w, true)
			draw_line(c + Vector2(-26, 0), c + Vector2(26, 0), col, 2.0)
			draw_line(c + Vector2(0, -26), c + Vector2(0, 26), col, 2.0)
		"claw":
			for i in 3:
				var x := -12.0 + i * 12.0
				draw_line(c + Vector2(x - 6, 18), c + Vector2(x + 6, -18), col, w, true)
		"drop", "venom":
			var vc := col if g == "drop" else Color(0.55, 1.0, 0.4)
			draw_circle(c + Vector2(0, 6), 14, vc)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 0), c + Vector2(0, -22), c + Vector2(12, 0)]), vc)
		"plus":
			draw_rect(Rect2(c + Vector2(-6, -20), Vector2(12, 40)), col)
			draw_rect(Rect2(c + Vector2(-20, -6), Vector2(40, 12)), col)
		"shield", "spikes":
			var pts := PackedVector2Array([c + Vector2(-18, -18), c + Vector2(18, -18), c + Vector2(16, 4), c + Vector2(0, 22), c + Vector2(-16, 4)])
			draw_colored_polygon(pts, Color(col, 0.35))
			draw_polyline(pts + PackedVector2Array([pts[0]]), col, w, true)
			if g == "spikes":
				for a in [-2.4, -1.57, -0.7]:
					var d := Vector2.from_angle(a)
					draw_line(c + d * 22, c + d * 32, col, 3.0, true)
		"magnet":
			draw_arc(c + Vector2(0, -2), 14, 0, PI, 24, col, 8.0)
			draw_rect(Rect2(c + Vector2(-18, -20), Vector2(8, 18)), col)
			draw_rect(Rect2(c + Vector2(10, -20), Vector2(8, 18)), col)
		"crown":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-20, 14), c + Vector2(-20, -10), c + Vector2(-10, 2), c + Vector2(0, -16), c + Vector2(10, 2), c + Vector2(20, -10), c + Vector2(20, 14)]), col)
		"hourglass":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -20), c + Vector2(14, -20), c + Vector2(0, 0)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 20), c + Vector2(14, 20), c + Vector2(0, 0)]), col)
		"rings":
			for r in [8.0, 16.0, 24.0]:
				draw_arc(c, r, 0, TAU, 32, Color(col, 1.0 - r / 40.0), 3.0, true)
		"crescent":
			draw_arc(c, 20, -2.4, 0.9, 24, col, 7.0, true)
		"arrows":
			for a in [-0.35, 0.0, 0.35]:
				var d := Vector2.from_angle(a - PI / 4)
				draw_line(c - d * 18, c + d * 20, col, 3.0, true)
				draw_circle(c + d * 20, 4.0, col)
		"pierce":
			draw_arc(c, 12, 0, TAU, 24, Color(col, 0.6), 3.0, true)
			draw_line(c + Vector2(-26, 0), c + Vector2(24, 0), col, 3.5, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(24, -7), c + Vector2(32, 0), c + Vector2(24, 7)]), col)
		"dagger":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 8), c + Vector2(0, -24), c + Vector2(4, 8)]), col)
			draw_line(c + Vector2(-10, 8), c + Vector2(10, 8), col, 3.0)
			draw_line(c + Vector2(0, 8), c + Vector2(0, 20), col, 4.0)
		"flame":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 18), c + Vector2(-16, 0), c + Vector2(-4, -22), c + Vector2(2, -6), c + Vector2(10, -16), c + Vector2(16, 2), c + Vector2(14, 18)]), col)
