extends Control
## Victory / defeat summary.

signal choice(target: String)

const UI := preload("res://scripts/ui/ui.gd")

var won := false
## Offer to keep playing in endless mode (after a first victory).
var can_continue := false
## The run ended during endless mode (past the final wave).
var endless := false
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

	var title_key := "victory_title" if won else ("endless_over_title" if endless else "defeat_title")
	var t := UI.title(Game.t(title_key), 96)
	if endless and not won:
		t.add_theme_color_override("font_color", Game.COLOR_GOLD)
	elif not won:
		t.add_theme_color_override("font_color", Color(0.85, 0.2, 0.22))
	col.add_child(t)
	var sub_text := Game.t("victory_sub" if won else "defeat_sub")
	if endless and not won:
		sub_text = Game.t("endless_over_sub") % wave
	var sub := UI.label(sub_text, 30, Game.COLOR_DIM)
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
	if can_continue:
		var cont := UI.button(Game.t("end_endless"), func() -> void: choice.emit("endless"))
		cont.add_theme_color_override("font_color", Game.COLOR_GOLD)
		_buttons.append(cont)
	_buttons.append(UI.button(Game.t("end_retry"), func() -> void: choice.emit("retry")))
	_buttons.append(UI.button(Game.t("end_heroes"), func() -> void: choice.emit("select")))
	_buttons.append(UI.button(Game.t("end_menu"), func() -> void: choice.emit("menu")))
	for b in _buttons:
		b.disabled = true
		col.add_child(b)
	# Delay so mashing attack/dash keys at death does not skip the results.
	get_tree().create_timer(1.6, true, false, true).timeout.connect(func() -> void:
		for b in _buttons:
			b.disabled = false
		_buttons[0].grab_focus())
