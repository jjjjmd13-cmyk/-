extends Node
## Global state: settings, persistent records, localization, input map and UI theme.

signal language_changed

const SAVE_PATH := "user://save.cfg"
const HEROES := preload("res://scripts/data/heroes.gd")
const STRINGS := preload("res://scripts/data/strings.gd")

const DIFFICULTY := {
	"normal": {"hp": 1.0, "damage": 1.0, "spawn": 1.0},
	"hard": {"hp": 1.4, "damage": 1.3, "spawn": 1.25},
}

const COLOR_GOLD := Color(0.86, 0.71, 0.42)
const COLOR_CRIMSON := Color(0.62, 0.1, 0.14)
const COLOR_TEXT := Color(0.93, 0.89, 0.84)
const COLOR_DIM := Color(0.62, 0.57, 0.53)
const COLOR_PANEL := Color(0.08, 0.06, 0.07, 0.94)

var selected_hero := "knight"
## "normal" or "hard"; see DIFFICULTY for the multipliers.
var difficulty := "normal"
var settings := {
	"master": 0.8,
	"music": 0.6,
	"sfx": 0.8,
	"fullscreen": false,
	"vsync": true,
	"screen_shake": true,
	"auto_attack": false,
	"damage_numbers": true,
	"language": "",
}
## Per-hero records: {hero_id: {"best_wave": int, "wins": int, "best_kills": int, "runs": int}}
var records := {}

var font: Font
var font_bold: Font
var theme: Theme
var _flash_material: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Route window closing through quit_game() so audio is released cleanly.
	get_tree().auto_accept_quit = false
	_setup_input()
	_load()
	if settings.language == "":
		settings.language = "ko"
	_build_theme()
	get_tree().root.theme = theme
	_ensure_buses()
	apply_settings()


func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


## Shared white-flash material used when enemies are hit.
func flash_material() -> ShaderMaterial:
	if _flash_material == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(mix(COLOR.rgb, vec3(1.0), 0.6), COLOR.a); }"
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = sh
	return _flash_material


# --------------------------------------------------------------- localization
func t(key: String) -> String:
	var table: Dictionary = STRINGS.TEXT.get(settings.language, STRINGS.TEXT.en)
	if table.has(key):
		return table[key]
	return STRINGS.TEXT.en.get(key, key)


func set_language(lang: String) -> void:
	settings.language = lang
	save()
	language_changed.emit()


# --------------------------------------------------------------- settings
func apply_settings() -> void:
	_set_bus_volume("Master", settings.master)
	_set_bus_volume("Music", settings.music)
	_set_bus_volume("SFX", settings.sfx)
	if not DisplayServer.get_name() == "headless":
		if settings.fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)


func _set_bus_volume(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(idx, value <= 0.001)


func quit_game() -> void:
	save()
	Audio.shutdown()
	# Give the audio thread a moment to drop its playbacks before exiting.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func toggle_fullscreen() -> void:
	settings.fullscreen = not settings.fullscreen
	apply_settings()
	save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------- records
func get_record(hero_id: String) -> Dictionary:
	if not records.has(hero_id):
		records[hero_id] = {"best_wave": 0, "wins": 0, "hard_wins": 0, "best_kills": 0, "runs": 0}
	return records[hero_id]


func submit_run(hero_id: String, wave: int, kills: int, won: bool) -> bool:
	## Stores a finished run. Returns true when it set a new best wave.
	var rec := get_record(hero_id)
	var new_best := wave > int(rec.best_wave)
	rec.runs = int(rec.runs) + 1
	rec.best_wave = maxi(int(rec.best_wave), wave)
	rec.best_kills = maxi(int(rec.best_kills), kills)
	if won:
		rec.wins = int(rec.wins) + 1
		if difficulty == "hard":
			rec.hard_wins = int(rec.hard_wins) + 1
	save()
	return new_best


# --------------------------------------------------------------- persistence
func save() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	for h in records:
		cfg.set_value("records", h, records[h])
	cfg.set_value("meta", "selected_hero", selected_hero)
	cfg.set_value("meta", "difficulty", difficulty)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not write save file: %s" % error_string(err))


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in settings:
		var v = cfg.get_value("settings", k, settings[k])
		# Ignore values whose type does not match (corrupted / old saves).
		if typeof(v) == typeof(settings[k]) or (typeof(settings[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
			settings[k] = v
	if cfg.has_section("records"):
		for h in cfg.get_section_keys("records"):
			var rec = cfg.get_value("records", h)
			if rec is Dictionary and HEROES.ORDER.has(h):
				var clean := get_record(h)
				for field in clean:
					if rec.has(field):
						clean[field] = int(rec[field])
	var hero = cfg.get_value("meta", "selected_hero", selected_hero)
	if hero is String and HEROES.ORDER.has(hero):
		selected_hero = hero
	var diff = cfg.get_value("meta", "difficulty", difficulty)
	if diff is String and DIFFICULTY.has(diff):
		difficulty = diff


# --------------------------------------------------------------- input
func _setup_input() -> void:
	_add_action("move_left", [_key(KEY_A), _key(KEY_LEFT)], [_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action("move_right", [_key(KEY_D), _key(KEY_RIGHT)], [_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action("move_up", [_key(KEY_W), _key(KEY_UP)], [_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action("move_down", [_key(KEY_S), _key(KEY_DOWN)], [_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add_action("aim_left", [], [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add_action("aim_right", [], [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add_action("aim_up", [], [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add_action("aim_down", [], [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_add_action("attack", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J)],
		[_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _joy(JOY_BUTTON_X)])
	_add_action("skill", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_K), _key(KEY_E)],
		[_axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _joy(JOY_BUTTON_Y)])
	_add_action("dash", [_key(KEY_SPACE), _key(KEY_SHIFT), _key(KEY_L)],
		[_joy(JOY_BUTTON_A), _joy(JOY_BUTTON_RIGHT_SHOULDER)])
	_add_action("pause", [_key(KEY_ESCAPE), _key(KEY_P)], [_joy(JOY_BUTTON_START)])
	_add_action("fullscreen", [_key(KEY_F11)], [])
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		InputMap.action_set_deadzone(a, 0.25)
	for a in ["aim_left", "aim_right", "aim_up", "aim_down"]:
		InputMap.action_set_deadzone(a, 0.3)


func _add_action(action: String, keys: Array, pads: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for e in keys + pads:
		InputMap.action_add_event(action, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = -1
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = -1
	return e


# --------------------------------------------------------------- theme
func _build_theme() -> void:
	var base: FontFile = load("res://assets/fonts/NotoSansKR.ttf")
	# The font is variable; its default instance is the thinnest weight, so set
	# the weight axis explicitly (keyed by OpenType tag).
	var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
	var regular := FontVariation.new()
	regular.base_font = base
	regular.variation_opentype = {wght: 500}
	var bold := FontVariation.new()
	bold.base_font = base
	bold.variation_opentype = {wght: 800}
	font = regular
	font_bold = bold

	theme = Theme.new()
	theme.default_font = regular
	theme.default_font_size = 26

	theme.set_stylebox("normal", "Button", _box(Color(0.11, 0.08, 0.09, 0.95), Color(0.42, 0.33, 0.24), 2))
	theme.set_stylebox("hover", "Button", _box(Color(0.22, 0.08, 0.1, 0.98), COLOR_GOLD, 2))
	theme.set_stylebox("pressed", "Button", _box(Color(0.35, 0.07, 0.1, 1.0), COLOR_GOLD, 3))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), COLOR_GOLD, 3))
	theme.set_stylebox("disabled", "Button", _box(Color(0.08, 0.07, 0.07, 0.8), Color(0.25, 0.22, 0.2), 2))
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", Color(1, 0.95, 0.85))
	theme.set_color("font_focus_color", "Button", Color(1, 0.95, 0.85))
	theme.set_color("font_pressed_color", "Button", COLOR_GOLD)
	theme.set_color("font_disabled_color", "Button", Color(0.45, 0.42, 0.4))
	theme.set_font("font", "Button", bold)
	theme.set_font_size("font_size", "Button", 28)

	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 2)

	theme.set_stylebox("panel", "PanelContainer", _box(COLOR_PANEL, Color(0.42, 0.33, 0.24), 2, 10))
	theme.set_stylebox("panel", "Panel", _box(COLOR_PANEL, Color(0.42, 0.33, 0.24), 2, 10))

	var slider_bg := _box(Color(0.15, 0.12, 0.12), Color(0.3, 0.25, 0.2), 1, 6)
	slider_bg.content_margin_top = 6
	slider_bg.content_margin_bottom = 6
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", _box(COLOR_CRIMSON, COLOR_CRIMSON, 0, 6))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(Color(0.8, 0.15, 0.2), Color(0.8, 0.15, 0.2), 0, 6))
	var grab := _circle_texture(14, COLOR_GOLD)
	theme.set_icon("grabber", "HSlider", grab)
	theme.set_icon("grabber_highlight", "HSlider", _circle_texture(16, Color(1, 0.88, 0.6)))

	theme.set_font("font", "CheckButton", regular)
	theme.set_color("font_color", "CheckButton", COLOR_TEXT)
	theme.set_color("font_hover_color", "CheckButton", Color(1, 0.95, 0.85))
	theme.set_color("font_focus_color", "CheckButton", Color(1, 0.95, 0.85))
	theme.set_color("font_pressed_color", "CheckButton", COLOR_TEXT)
	theme.set_stylebox("focus", "CheckButton", _box(Color(0, 0, 0, 0), COLOR_GOLD, 2))
	theme.set_stylebox("focus", "HSlider", _box(Color(0, 0, 0, 0), COLOR_GOLD, 2))

	var bar_bg := _box(Color(0.05, 0.03, 0.04, 0.9), Color(0.35, 0.28, 0.2), 2, 4)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", _box(COLOR_CRIMSON, Color(0, 0, 0, 0), 0, 4))
	theme.set_color("font_color", "ProgressBar", COLOR_TEXT)
	theme.set_font_size("font_size", "ProgressBar", 18)


func _box(bg: Color, border: Color, border_w: int, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


func make_box(bg: Color, border: Color, border_w: int = 2, radius: int = 8) -> StyleBoxFlat:
	return _box(bg, border, border_w, radius)


func _circle_texture(r: int, col: Color) -> ImageTexture:
	var img := Image.create(r * 2, r * 2, false, Image.FORMAT_RGBA8)
	for y in r * 2:
		for x in r * 2:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)
