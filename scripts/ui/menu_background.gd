extends Control
## Shared key-art backdrop. UI stays native and localized over the illustration.

const KEY_ART := preload("res://assets/menu/title-screen.png")
var dim := 0.0

var _embers: Array = []
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 90:
		_embers.append(_new_ember(true))


func _new_ember(anywhere: bool) -> Dictionary:
	return {
		"x": randf(),
		"y": randf() if anywhere else 1.05,
		"s": randf_range(1.5, 4.5),
		"v": randf_range(0.02, 0.07),
		"w": randf() * TAU,
	}


func _process(delta: float) -> void:
	_t += delta
	for i in _embers.size():
		var e: Dictionary = _embers[i]
		e.y -= e.v * delta
		e.x += sin(_t * 0.8 + e.w) * 0.008 * delta
		if e.y < -0.05:
			_embers[i] = _new_ember(false)
	queue_redraw()


func _draw() -> void:
	var s := size
	# Cover the viewport without distortion; centre-crop at wider/narrower aspects.
	var image_size := KEY_ART.get_size()
	var cover := maxf(s.x / image_size.x, s.y / image_size.y)
	var drawn_size := image_size * cover
	draw_texture_rect(KEY_ART, Rect2((s - drawn_size) * 0.5, drawn_size), false)
	# Quiet the button side while keeping the heroes' armour and faces visible.
	for i in 48:
		var k := float(i) / 47.0
		var alpha := 0.34 * pow(1.0 - k, 2.0)
		draw_rect(Rect2(s.x * k, 0, s.x / 47.0 + 1, s.y), Color(0.015, 0.012, 0.02, alpha))
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.015, 0.012, 0.02, dim))
	for e in _embers:
		var p := Vector2(e.x * s.x, e.y * s.y)
		var flick := 0.6 + 0.4 * sin(_t * 6.0 + e.w * 3.0)
		draw_circle(p, e.s * 2.5, Color(1, 0.4, 0.1, 0.08 * flick))
		draw_circle(p, e.s, Color(1, 0.6 + 0.3 * flick, 0.3, 0.8 * flick))
