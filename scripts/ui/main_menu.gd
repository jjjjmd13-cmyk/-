extends Control
## Title screen.

signal start_pressed

const UI := preload("res://scripts/ui/ui.gd")
const HEROES := preload("res://scripts/data/heroes.gd")
const SettingsMenu := preload("res://scripts/ui/settings_menu.gd")
const MenuBackground := preload("res://scripts/ui/menu_background.gd")

var _popup: Control
var _focus_after_popup: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Controls under a CanvasLayer do not inherit the window theme.
	theme = Game.theme
	Game.language_changed.connect(_build)
	_build()
	Audio.play_music("menu")


func _build() -> void:
	for c in get_children():
		if c != _popup:
			c.queue_free()
	var bg := MenuBackground.new()
	add_child(bg)
	move_child(bg, 0)

	# Hero line-up on the right.
	var lineup := Control.new()
	lineup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lineup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lineup)
	move_child(lineup, 1)
	var xs := [0.48, 0.6, 0.72, 0.84]
	for i in HEROES.ORDER.size():
		var tr := TextureRect.new()
		tr.texture = load(HEROES.DATA[HEROES.ORDER[i]].portrait)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.anchor_left = xs[i] - 0.1
		tr.anchor_right = xs[i] + 0.1
		tr.anchor_top = 0.16 if i % 2 == 0 else 0.1
		tr.anchor_bottom = 0.98 if i % 2 == 0 else 0.92
		tr.modulate = Color(0.75, 0.68, 0.68, 0.0)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lineup.add_child(tr)
		create_tween().tween_property(tr, "modulate:a", 0.92, 1.2).set_delay(0.15 * i)

	var left := VBoxContainer.new()
	left.anchor_left = 0.06
	left.anchor_right = 0.42
	left.anchor_top = 0.0
	left.anchor_bottom = 1.0
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 16)
	add_child(left)
	move_child(left, 2)

	var title := UI.title(Game.t("game_title"), 104)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(title)
	var sub := UI.label(Game.t("game_subtitle"), 32, Color(0.85, 0.35, 0.35))
	left.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	left.add_child(spacer)

	var start := UI.button(Game.t("menu_start"), func() -> void: start_pressed.emit())
	var buttons: Array[Button] = [
		start,
		UI.button(Game.t("menu_settings"), _open_settings),
		UI.button(Game.t("menu_controls"), func() -> void: _open_text(Game.t("controls_title"), Game.t("controls_body"))),
		UI.button(Game.t("menu_credits"), func() -> void: _open_text(Game.t("credits_title"), Game.t("credits_body"))),
	]
	if OS.get_name() != "Web":
		buttons.append(UI.button(Game.t("menu_quit"), func() -> void: Game.quit_game()))
	for b in buttons:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.add_child(b)

	var ver := UI.label("v" + str(ProjectSettings.get_setting("application/config/version", "1.0.0")), 20, Game.COLOR_DIM)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -160
	ver.offset_top = -50
	ver.offset_right = -24
	ver.offset_bottom = -16
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)
	if _popup == null:
		start.grab_focus.call_deferred()
	else:
		move_child(_popup, get_child_count() - 1)
	_focus_after_popup = start


func _open_settings() -> void:
	var s := SettingsMenu.new()
	s.closed.connect(_on_popup_closed)
	_popup = s
	add_child(s)


func _open_text(title_text: String, body: String) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(UI.dim_background(0.8))
	var center := UI.full_center()
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	panel.add_child(margin)
	var col := UI.centered_column(20)
	margin.add_child(col)
	col.add_child(UI.title(title_text, 56))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.text = body
	rt.add_theme_font_size_override("normal_font_size", 26)
	rt.add_theme_font_size_override("bold_font_size", 28)
	rt.add_theme_font_override("normal_font", Game.font)
	rt.add_theme_font_override("bold_font", Game.font_bold)
	rt.add_theme_color_override("default_color", Game.COLOR_TEXT)
	rt.custom_minimum_size = Vector2(820, 0)
	col.add_child(rt)
	var back := UI.button(Game.t("back"), func() -> void:
		root.queue_free()
		_on_popup_closed())
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(back)
	_popup = root
	add_child(root)
	back.grab_focus.call_deferred()


func _on_popup_closed() -> void:
	_popup = null
	if is_instance_valid(_focus_after_popup):
		_focus_after_popup.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _popup != null and not _popup is SettingsMenu and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_popup.queue_free()
		_on_popup_closed()
