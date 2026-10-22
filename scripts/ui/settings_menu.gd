extends Control
## Settings panel. Usable from the main menu and from the pause menu.

signal closed

const UI := preload("res://scripts/ui/ui.gd")
const LANGUAGES := [["ko", "한국어"], ["en", "English"]]

var _first: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	add_child(UI.dim_background(0.8))
	var center := UI.full_center()
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)
	var col := UI.centered_column(14)
	margin.add_child(col)
	col.add_child(UI.title(Game.t("settings_title"), 56))

	_first = _slider(col, "set_master", "master")
	_slider(col, "set_music", "music")
	_slider(col, "set_sfx", "sfx")
	_toggle(col, "set_fullscreen", "fullscreen")
	_toggle(col, "set_vsync", "vsync")
	_toggle(col, "set_shake", "screen_shake")
	_toggle(col, "set_auto_attack", "auto_attack")
	_toggle(col, "set_damage_numbers", "damage_numbers")

	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	col.add_child(lang_row)
	var ll := UI.label(Game.t("set_language"), 26)
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(ll)
	for pair in LANGUAGES:
		var code: String = pair[0]
		var b := UI.button(pair[1], func() -> void: _set_language(code), 150)
		b.custom_minimum_size.y = 52
		if Game.settings.language == code:
			b.add_theme_color_override("font_color", Game.COLOR_GOLD)
		lang_row.add_child(b)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	col.add_child(spacer)
	var back := UI.button(Game.t("back"), _close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(back)
	_first.grab_focus.call_deferred()


func _slider(parent: Control, label_key: String, setting: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)
	var l := UI.label(Game.t(label_key), 26)
	l.custom_minimum_size.x = 300
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Game.settings[setting]
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(300, 32)
	s.focus_mode = Control.FOCUS_ALL
	var pct := UI.label("%d%%" % roundi(s.value * 100), 24, Game.COLOR_DIM)
	pct.custom_minimum_size.x = 80
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v: float) -> void:
		Game.settings[setting] = v
		pct.text = "%d%%" % roundi(v * 100)
		Game.apply_settings()
		if setting == "sfx":
			Audio.play("pickup", 0.0, 0.0))
	s.drag_ended.connect(func(_c: bool) -> void: Game.save())
	s.focus_exited.connect(Game.save)
	row.add_child(s)
	row.add_child(pct)
	return s


func _toggle(parent: Control, label_key: String, setting: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = Game.t(label_key)
	c.button_pressed = Game.settings[setting]
	c.add_theme_font_size_override("font_size", 26)
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(on: bool) -> void:
		Game.settings[setting] = on
		Audio.play("ui_click", -2.0, 0.0)
		Game.apply_settings()
		Game.save())
	parent.add_child(c)
	return c


func _set_language(code: String) -> void:
	if Game.settings.language == code:
		return
	Game.set_language(code)
	_build()


func _close() -> void:
	Game.save()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()
