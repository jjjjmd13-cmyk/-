extends Control
## Hero selection: four portrait cards plus a detail panel for the focused hero.

signal hero_chosen(hero_id: String)
signal back_pressed

const UI := preload("res://scripts/ui/ui.gd")
const HEROES := preload("res://scripts/data/heroes.gd")
const MenuBackground := preload("res://scripts/ui/menu_background.gd")

var _cards := {}
var _current := ""
var _name_l: Label
var _title_l: Label
var _desc_l: Label
var _attack_l: Label
var _skill_l: Label
var _record_l: Label
var _stat_bars: Array = []
var _started := false
## Card picked by a mouse click; a second click on it (or the start button) begins.
var _clicked := ""
var _mouse_press := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Controls under a CanvasLayer do not inherit the window theme.
	theme = Game.theme
	var backdrop := MenuBackground.new()
	backdrop.dim = 0.6
	add_child(backdrop)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 36
	root.offset_bottom = -36
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	root.add_child(UI.title(Game.t("select_title"), 64))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	var buttons: Array[Button] = []
	for id in HEROES.ORDER:
		var card := _make_card(id)
		row.add_child(card)
		_cards[id] = card
		buttons.append(card)
	for i in buttons.size():
		buttons[i].focus_neighbor_left = buttons[(i - 1 + buttons.size()) % buttons.size()].get_path()
		buttons[i].focus_neighbor_right = buttons[(i + 1) % buttons.size()].get_path()

	# Detail panel.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 270)
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	margin.add_child(cols)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	cols.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 18)
	info.add_child(name_row)
	_name_l = UI.label("", 40, Game.COLOR_GOLD, true)
	name_row.add_child(_name_l)
	_title_l = UI.label("", 26, Game.COLOR_DIM)
	_title_l.size_flags_vertical = Control.SIZE_SHRINK_END
	name_row.add_child(_title_l)
	_desc_l = UI.label("", 24)
	_desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_desc_l)
	_attack_l = UI.label("", 22, Color(0.9, 0.82, 0.7))
	_attack_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_attack_l)
	_skill_l = UI.label("", 22, Color(0.9, 0.82, 0.7))
	_skill_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_skill_l)
	_record_l = UI.label("", 20, Game.COLOR_DIM)
	info.add_child(_record_l)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 460
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	for key in ["stat_toughness", "stat_damage", "stat_speed", "stat_range"]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 14)
		var l := UI.label(Game.t(key), 22)
		l.custom_minimum_size.x = 130
		r.add_child(l)
		var pips := StatPips.new()
		pips.custom_minimum_size = Vector2(300, 26)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(pips)
		_stat_bars.append(pips)
		right.add_child(r)
	var diff_btn := UI.button("", func() -> void: pass, 454)
	diff_btn.custom_minimum_size.y = 56
	diff_btn.pressed.connect(func() -> void:
		Game.difficulty = "hard" if Game.difficulty == "normal" else "normal"
		Game.save()
		_update_difficulty(diff_btn))
	_update_difficulty(diff_btn)
	right.add_child(diff_btn)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 14)
	right.add_child(btns)
	var back := UI.button(Game.t("back"), func() -> void: back_pressed.emit(), 200)
	btns.add_child(back)
	var go := UI.button(Game.t("select_start"), _confirm, 240)
	go.add_theme_color_override("font_color", Game.COLOR_GOLD)
	btns.add_child(go)

	_focus_hero(Game.selected_hero)
	(_cards[Game.selected_hero] as Button).grab_focus.call_deferred()


func _update_difficulty(b: Button) -> void:
	var hard := Game.difficulty == "hard"
	b.text = "%s: %s" % [Game.t("difficulty"), Game.t("diff_hard" if hard else "diff_normal")]
	b.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if hard else Game.COLOR_TEXT)
	b.add_theme_color_override("font_focus_color", Color(1, 0.45, 0.4) if hard else Color(1, 0.95, 0.85))
	b.add_theme_color_override("font_hover_color", Color(1, 0.45, 0.4) if hard else Color(1, 0.95, 0.85))


func _make_card(id: String) -> Button:
	var d: Dictionary = HEROES.DATA[id]
	var b := Button.new()
	b.custom_minimum_size = Vector2(380, 0)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	b.add_theme_stylebox_override("focus", Game.make_box(Color(0, 0, 0, 0), d.accent, 4, 10))
	b.add_theme_stylebox_override("hover", Game.make_box(Color(0.16, 0.07, 0.08, 0.9), Game.COLOR_GOLD, 2, 10))
	b.add_theme_stylebox_override("normal", Game.make_box(Color(0.08, 0.06, 0.07, 0.85), Color(0.3, 0.24, 0.2), 2, 10))
	b.add_theme_stylebox_override("pressed", Game.make_box(Color(0.25, 0.06, 0.08, 0.95), Game.COLOR_GOLD, 3, 10))
	var tr := TextureRect.new()
	tr.texture = load(d.portrait)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_top = 10
	tr.offset_bottom = -64
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tr)
	var name_l := UI.label(Game.t(d.name), 32, Game.COLOR_TEXT, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_l.offset_top = -60
	name_l.offset_bottom = -12
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_l)
	b.focus_entered.connect(func() -> void:
		Audio.play("ui_move", -8.0, 0.0)
		_focus_hero(id))
	# Hovering only previews a hero; it takes a click to pick and a second click to start.
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.mouse_exited.connect(func() -> void:
		# Leaving the cards shows the picked hero again.
		if _clicked != "" and _clicked != id:
			_cards[_clicked].grab_focus())
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_mouse_press = true)
	b.pressed.connect(func() -> void:
		var by_mouse := _mouse_press
		_mouse_press = false
		if by_mouse and _clicked != id:
			_clicked = id
			b.grab_focus()
			_tint_cards()
			return
		if _current == id:
			_confirm()
		else:
			b.grab_focus())
	return b


func _focus_hero(id: String) -> void:
	if _current == id:
		return
	_current = id
	var d: Dictionary = HEROES.DATA[id]
	_name_l.text = Game.t(d.name)
	_name_l.add_theme_color_override("font_color", d.accent.lightened(0.25))
	_title_l.text = Game.t(d.title)
	_desc_l.text = Game.t(d.desc)
	_attack_l.text = "%s  |  %s" % [Game.t("label_attack"), Game.t(d.attack)]
	_skill_l.text = "%s  |  %s\n%s  |  %s\n%s  |  %s" % [
		Game.t("label_skill"), Game.t(d.skill), Game.t("label_skill2"), Game.t(d.skill2),
		Game.t("label_ult"), Game.t(d.ult)]
	var rec := Game.get_record(id)
	_record_l.text = Game.t("record_best") % [int(rec.best_wave), int(rec.wins), int(rec.hard_wins), int(rec.get("best_kills", 0)), int(rec.get("runs", 0))]
	for i in _stat_bars.size():
		_stat_bars[i].value = d.ratings[i]
		_stat_bars[i].color = d.accent
		_stat_bars[i].queue_redraw()
	_tint_cards()


func _tint_cards() -> void:
	for k in _cards:
		var tr: TextureRect = _cards[k].get_child(0)
		tr.modulate = Color.WHITE if k == _current or k == _clicked else Color(0.55, 0.5, 0.5)


func _confirm() -> void:
	if _started:
		return
	_started = true
	Audio.play("ui_click", 0.0, 0.0)
	var id := _clicked if _clicked != "" else _current
	Game.selected_hero = id
	Game.save()
	hero_chosen.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()


class StatPips extends Control:
	var value := 3
	var color := Color.WHITE

	func _draw() -> void:
		var w := (size.x - 4 * 8) / 5.0
		for i in 5:
			var r := Rect2(i * (w + 8), 0, w, size.y)
			draw_rect(r, color if i < value else Color(0.18, 0.14, 0.14))
			draw_rect(r, Color(0, 0, 0, 0.6), false, 2.0)
