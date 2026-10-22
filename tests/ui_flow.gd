extends Node
## Clicks through every menu path a player can take and checks the game keeps
## working. Prints "UI FLOW OK" at the end; any script error shows in the log.
##   godot --headless --fixed-fps 60 res://tests/ui_flow.tscn

const MainScene := preload("res://scenes/main.tscn")
const SettingsMenu := preload("res://scripts/ui/settings_menu.gd")

var _main: Node
var _step := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = MainScene.instantiate()
	add_child(_main)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("UI FLOW FAILED at %s: %s" % [_step, what])


func _find(root: Node, type_name: String, text: String = "") -> Node:
	for c in root.get_children():
		if c.is_class(type_name) and (text == "" or ("text" in c and c.text == text)):
			return c
		var r := _find(c, type_name, text)
		if r:
			return r
	return null


func _press(root: Node, text: String) -> void:
	var b: Button = _find(root, "Button", text)
	_check(b != null, "button '%s' not found" % text)
	if b:
		_check(not b.disabled, "button '%s' disabled" % text)
		b.pressed.emit()


func _settings_round_trip(host: Node) -> void:
	var s: Node = _find(host, "Control")
	for c in host.get_children():
		if c is SettingsMenu:
			s = c
	_check(s is SettingsMenu, "settings menu opened")
	for slider in s.find_children("*", "HSlider", true, false):
		slider.value = 0.3
		slider.value = 0.8
	for toggle in s.find_children("*", "CheckButton", true, false):
		toggle.button_pressed = not toggle.button_pressed
		toggle.button_pressed = not toggle.button_pressed
	_press(s, "English")
	await _frames(3)
	_check(Game.settings.language == "en", "language switched to en")
	_press(s, "한국어")
	await _frames(3)
	_check(Game.settings.language == "ko", "language switched back to ko")
	_press(s, Game.t("back"))
	await _frames(3)


func _run() -> void:
	await _frames(30)
	_step = "main menu -> settings"
	var menu: Node = _main._current
	_press(menu, Game.t("menu_settings"))
	await _frames(3)
	await _settings_round_trip(menu)
	_step = "main menu -> controls"
	_press(menu, Game.t("menu_controls"))
	await _frames(3)
	_press(menu, Game.t("back"))
	await _frames(3)

	_step = "hero select"
	_press(_main._current, Game.t("menu_start"))
	await _frames(5)
	var select: Node = _main._current
	_check(select.has_signal("hero_chosen"), "hero select shown")
	var diff_before: String = Game.difficulty
	_press(select, "%s: %s" % [Game.t("difficulty"), Game.t("diff_hard" if diff_before == "hard" else "diff_normal")])
	_check(Game.difficulty != diff_before, "difficulty toggled")
	Game.difficulty = "normal"
	_press(select, Game.t("select_start"))
	await _frames(10)

	_step = "in game -> pause -> settings -> resume"
	var world: Node = _main._current
	_check(world.has_method("open_pause"), "world started")
	await _frames(60)
	world.open_pause()
	await _frames(3)
	_check(get_tree().paused, "tree paused")
	_press(world._modal, Game.t("menu_settings"))
	await _frames(3)
	await _settings_round_trip(world._modal)
	_press(world._modal, Game.t("pause_resume"))
	await _frames(3)
	_check(not get_tree().paused, "resumed")

	_step = "level up"
	world.pending_levels = 2
	world._open_levelup()
	await _frames(40)
	_check(world._modal != null, "level-up shown")
	world._modal._buttons[1].pressed.emit()
	await _frames(40)
	_check(world._modal != null, "second level-up shown")
	world._modal._buttons[0].pressed.emit()
	await _frames(5)
	_check(world._modal == null and not get_tree().paused, "level-ups done")

	_step = "victory -> endless mode -> boss 20 -> death"
	world._win()
	await _frames(200)
	_check(world._ended and get_tree().paused, "victory screen shown")
	await _frames(60)
	_press(world._modal, Game.t("end_endless"))
	await _frames(5)
	_check(world.endless and not world._ended and not get_tree().paused, "endless mode running")
	world._start_wave(20)
	await _frames(30)
	_check(is_instance_valid(world.boss) and world.boss.max_hp > 0.0, "wave 20 boss spawned")
	world.player.take_damage(99999.0, null)
	await _frames(220)
	_check(world._ended and _find(world._modal, "Button", Game.t("end_endless")) == null, "endless death screen")
	_press(world._modal, Game.t("end_retry"))
	await _frames(10)
	world = _main._current

	_step = "pause -> restart"
	world.open_pause()
	await _frames(3)
	_press(world._modal, Game.t("pause_restart"))
	await _frames(10)
	_check(_main._current != world and _main._current.has_method("open_pause"), "restarted run")

	_step = "death -> end screen -> change hero"
	world = _main._current
	await _frames(30)
	world.player.take_damage(99999.0, null)
	await _frames(220)
	_check(world._ended and get_tree().paused, "end screen shown")
	_press(world._modal, Game.t("end_heroes"))
	await _frames(10)
	_check(_main._current.has_signal("hero_chosen") and not get_tree().paused, "back to hero select")

	_step = "hero select -> back -> main menu"
	_press(_main._current, Game.t("back"))
	await _frames(10)
	_check(_main._current.has_signal("start_pressed"), "main menu shown")

	print("UI FLOW OK")
	Game.quit_game()
