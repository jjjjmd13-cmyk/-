extends RefCounted
## Small helpers for building consistent UI in code.


static func button(text: String, on_pressed: Callable, min_width: float = 420.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 68)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void: Audio.play("ui_click", -2.0, 0.0))
	b.pressed.connect(on_pressed)
	b.focus_entered.connect(func() -> void: Audio.play("ui_move", -8.0, 0.0))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b


static func label(text: String, size: int = 26, color: Color = Game.COLOR_TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", Game.font_bold)
	return l


static func title(text: String, size: int = 72) -> Label:
	var l := label(text, size, Game.COLOR_GOLD, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.03))
	return l


static func dim_background(alpha: float = 0.72) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.02, 0.01, 0.015, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


static func centered_column(separation: int = 18) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", separation)
	return v


static func full_center() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
