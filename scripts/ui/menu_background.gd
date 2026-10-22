extends Control
## Animated backdrop for menus: dark gradient with drifting embers.

var _embers: Array = []
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	# Vertical gradient built from bands.
	var bands := 24
	for i in bands:
		var k := float(i) / bands
		var col := Color(0.05, 0.035, 0.045).lerp(Color(0.2, 0.04, 0.06), pow(k, 2.2))
		draw_rect(Rect2(0, s.y * k, s.x, s.y / bands + 1), col)
	# Red glow behind the heroes.
	for r in [900.0, 650.0, 420.0]:
		draw_circle(Vector2(s.x * 0.68, s.y * 0.72), r, Color(0.5, 0.05, 0.08, 0.06))
	for e in _embers:
		var p := Vector2(e.x * s.x, e.y * s.y)
		var flick := 0.6 + 0.4 * sin(_t * 6.0 + e.w * 3.0)
		draw_circle(p, e.s * 2.5, Color(1, 0.4, 0.1, 0.08 * flick))
		draw_circle(p, e.s, Color(1, 0.6 + 0.3 * flick, 0.3, 0.8 * flick))
