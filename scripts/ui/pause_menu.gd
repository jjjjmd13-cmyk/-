extends Control
## Pause overlay shown during a run.

signal resumed
signal quit_requested(target: String)

const UI := preload("res://scripts/ui/ui.gd")
const SettingsMenu := preload("res://scripts/ui/settings_menu.gd")

var _settings_open := false
var _resume_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Game.language_changed.connect(_build)


func _build() -> void:
	for c in get_children():
		if not c is SettingsMenu:
			c.queue_free()
	var bg := UI.dim_background(0.7)
	add_child(bg)
	move_child(bg, 0)
	var center := UI.full_center()
	add_child(center)
	move_child(center, 1)
	var col := UI.centered_column(16)
	center.add_child(col)
	col.add_child(UI.title(Game.t("pause_title"), 80))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	col.add_child(spacer)
	_resume_button = UI.button(Game.t("pause_resume"), _resume)
	col.add_child(_resume_button)
	col.add_child(UI.button(Game.t("menu_settings"), _open_settings))
	col.add_child(UI.button(Game.t("pause_restart"), func() -> void: quit_requested.emit("retry")))
	col.add_child(UI.button(Game.t("pause_menu"), func() -> void: quit_requested.emit("menu")))
	if not _settings_open:
		_resume_button.grab_focus.call_deferred()


func _resume() -> void:
	resumed.emit()


func _open_settings() -> void:
	_settings_open = true
	var s := SettingsMenu.new()
	s.closed.connect(func() -> void:
		_settings_open = false
		if is_instance_valid(_resume_button):
			_resume_button.grab_focus())
	add_child(s)


func _unhandled_input(event: InputEvent) -> void:
	if _settings_open:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_resume()
