extends Control
## Victory / defeat summary.

signal choice(target: String)

const UI := preload("res://scripts/ui/ui.gd")

var won := false
var new_best := false
var wave := 1
var kills := 0
var level := 1
var time := 0.0
var _buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Controls under a CanvasLayer do not inherit the window theme.
	theme = Game.theme
	var bg := UI.dim_background(0.0)
	add_child(bg)
	create_tween().tween_property(bg, "color:a", 0.8, 0.8)
	var center := UI.full_center()
	add_child(center)
	var col := UI.centered_column(16)
	center.add_child(col)
	col.modulate.a = 0.0
	create_tween().tween_property(col, "modulate:a", 1.0, 0.6).set_delay(0.3)

	var t := UI.title(Game.t("victory_title" if won else "defeat_title"), 96)
	if not won:
		t.add_theme_color_override("font_color", Color(0.85, 0.2, 0.22))
	col.add_child(t)
	var sub := UI.label(Game.t("victory_sub" if won else "defeat_sub"), 30, Game.COLOR_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var stats := UI.label(Game.t("end_stats") % [wave, kills, level, UI.format_time(time)], 30)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(stats)
	if new_best:
		var nb := UI.label(Game.t("end_new_best"), 30, Game.COLOR_GOLD, true)
		nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nb)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	col.add_child(spacer)
	_buttons.append(UI.button(Game.t("end_retry"), func() -> void: choice.emit("retry")))
	_buttons.append(UI.button(Game.t("end_heroes"), func() -> void: choice.emit("select")))
	_buttons.append(UI.button(Game.t("end_menu"), func() -> void: choice.emit("menu")))
	for b in _buttons:
		b.disabled = true
		col.add_child(b)
	# Short delay so frantic button mashing at death does not skip the screen.
	get_tree().create_timer(0.9, true, false, true).timeout.connect(func() -> void:
		for b in _buttons:
			b.disabled = false
		_buttons[0].grab_focus())
