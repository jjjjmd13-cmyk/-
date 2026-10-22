extends Control
## Level-up choice: three upgrade cards. Input is briefly locked so a held
## attack button cannot pick a card by accident.

signal chosen(id: String)

const UI := preload("res://scripts/ui/ui.gd")
const UPGRADES := preload("res://scripts/data/upgrades.gd")
const INPUT_LOCK := 0.4

var world: Node
var _buttons: Array[Button] = []
var _ids: Array[String] = []
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.dim_background(0.65))
	var center := UI.full_center()
	add_child(center)
	var col := UI.centered_column(26)
	center.add_child(col)
	col.add_child(UI.title(Game.t("levelup_title"), 72))
	var hint := UI.label(Game.t("levelup_hint"), 28, Game.COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)

	var player: Node = world.player
	var options := UPGRADES.roll(player.hero_id, player.upgrades, 3, world.rng)
	for i in options.size():
		var u: Dictionary = options[i]
		var id: String = u.id
		var b := _card(id, int(player.upgrades.get(id, 0)) + 1, i + 1)
		row.add_child(b)
		_buttons.append(b)
		_ids.append(id)
		b.disabled = true
	for i in _buttons.size():
		var b := _buttons[i]
		b.focus_neighbor_left = _buttons[(i - 1 + _buttons.size()) % _buttons.size()].get_path()
		b.focus_neighbor_right = _buttons[(i + 1) % _buttons.size()].get_path()
	get_tree().create_timer(INPUT_LOCK, true, false, true).timeout.connect(_unlock)


func _unlock() -> void:
	for b in _buttons:
		b.disabled = false
	if _buttons.size() > 0:
		_buttons[0].grab_focus()


func _card(id: String, new_level: int, hotkey: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(380, 300)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void: _pick(id))
	b.focus_entered.connect(func() -> void: Audio.play("ui_move", -8.0, 0.0))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_right = -24
	v.offset_top = 22
	v.offset_bottom = -22
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var key := UI.label("[%d]" % hotkey, 20, Game.COLOR_DIM)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(key)
	var name_l := UI.label(Game.t("up_" + id), 36, Game.COLOR_GOLD, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	if id != "elixir":
		var lv := UI.label(Game.t("up_stack") % new_level, 22, Color(0.75, 0.6, 0.9))
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lv)
	var desc := UI.label(Game.t("up_" + id + "_d"), 26)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(desc)
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _unhandled_input(event: InputEvent) -> void:
	if _buttons.is_empty() or _buttons[0].disabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = event.physical_keycode - KEY_1
		if idx >= 0 and idx < _ids.size():
			get_viewport().set_input_as_handled()
			_pick(_ids[idx])


func _pick(id: String) -> void:
	if _done:
		return
	_done = true
	Audio.play("ui_click", 0.0, 0.0)
	chosen.emit(id)
