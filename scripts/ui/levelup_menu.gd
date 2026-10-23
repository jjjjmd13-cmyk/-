extends Control
## Level-up choice: three cards, plus per-run reroll and banish. In "boss" mode
## it offers legendary boss rewards instead. Input is briefly locked so a held
## attack button cannot pick a card by accident.

signal chosen(id: String)

const UI := preload("res://scripts/ui/ui.gd")
const UPGRADES := preload("res://scripts/data/upgrades.gd")
const UpgradeIcon := preload("res://scripts/ui/upgrade_icon.gd")
const INPUT_LOCK := 0.4

var world: Node
## "normal" or "boss".
var mode := "normal"
## At least one rare-or-better card (every fifth level).
var need_rare := false
var _buttons: Array[Button] = []
var _ids: Array[String] = []
var _done := false
var _row: HBoxContainer
var _tools: HBoxContainer
var _reroll_b: Button
var _banish_b: Button
var _banishing := false
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Controls under a CanvasLayer do not inherit the window theme.
	theme = Game.theme
	# Dark enough that damage numbers and the wave banner below don't fight the title.
	add_child(UI.dim_background(0.82))
	var center := UI.full_center()
	add_child(center)
	var col := UI.centered_column(22)
	center.add_child(col)
	var boss := mode == "boss"
	var title := UI.title(Game.t("boss_reward_title" if boss else "levelup_title"), 72)
	if boss:
		title.add_theme_color_override("font_color", UPGRADES.RARITY_COLOR.legendary)
	col.add_child(title)
	_hint = UI.label(Game.t("boss_reward_hint" if boss else "levelup_hint"), 28, Game.COLOR_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 28)
	col.add_child(_row)

	if not boss:
		_tools = HBoxContainer.new()
		_tools.alignment = BoxContainer.ALIGNMENT_CENTER
		_tools.add_theme_constant_override("separation", 24)
		col.add_child(_tools)
		_reroll_b = UI.button("", _reroll, 300)
		_banish_b = UI.button("", _toggle_banish, 300)
		_tools.add_child(_reroll_b)
		_tools.add_child(_banish_b)

	_show(_roll(3, []))
	for b in _all_buttons():
		b.disabled = true
	_update_tools()
	get_tree().create_timer(INPUT_LOCK, true, false, true).timeout.connect(_unlock)


func _roll(count: int, exclude: Array) -> Array:
	var p: Node = world.player
	var banned: Array = world.banned + exclude
	return UPGRADES.roll(p.hero_id, p.upgrades, count, world.rng, banned, need_rare, mode == "boss")


func _show(options: Array) -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_ids.clear()
	for i in options.size():
		var u: Dictionary = options[i]
		var b := _card(u, i + 1)
		_row.add_child(b)
		_buttons.append(b)
		_ids.append(u.id)
	for i in _buttons.size():
		var b := _buttons[i]
		b.focus_neighbor_left = _buttons[(i - 1 + _buttons.size()) % _buttons.size()].get_path()
		b.focus_neighbor_right = _buttons[(i + 1) % _buttons.size()].get_path()
		if _tools:
			b.focus_neighbor_bottom = _reroll_b.get_path()
	if _tools and not _buttons.is_empty():
		_reroll_b.focus_neighbor_top = _buttons[0].get_path()
		_banish_b.focus_neighbor_top = _buttons[_buttons.size() - 1].get_path()


func _all_buttons() -> Array[Button]:
	var out: Array[Button] = _buttons.duplicate()
	if _tools:
		out.append(_reroll_b)
		out.append(_banish_b)
	return out


func _unlock() -> void:
	var start := 0
	for b in _all_buttons():
		b.disabled = false
	_update_tools()
	for i in _buttons.size():
		var b := _buttons[i]
		if b.get_global_rect().has_point(b.get_global_mouse_position()):
			start = i
	if _buttons.size() > 0:
		_buttons[start].grab_focus()


func _update_tools() -> void:
	if not _tools:
		return
	_reroll_b.text = Game.t("levelup_reroll") % world.rerolls_left
	_banish_b.text = Game.t("levelup_banish_on" if _banishing else "levelup_banish") % world.banishes_left
	if not _buttons.is_empty() and not _buttons[0].disabled:
		_reroll_b.disabled = world.rerolls_left <= 0
		_banish_b.disabled = world.banishes_left <= 0 and not _banishing
	_hint.text = Game.t("levelup_banish_hint" if _banishing else "levelup_hint")
	_hint.add_theme_color_override("font_color", Color(1, 0.5, 0.45) if _banishing else Game.COLOR_DIM)


func _reroll() -> void:
	if world.rerolls_left <= 0 or _done:
		return
	world.rerolls_left -= 1
	_banishing = false
	Audio.play("ui_click", 0.0, 0.0)
	_show(_roll(3, _ids))
	_update_tools()
	_buttons[0].grab_focus()


func _toggle_banish() -> void:
	if world.banishes_left <= 0 and not _banishing:
		return
	_banishing = not _banishing
	Audio.play("ui_move", -4.0, 0.0)
	_update_tools()
	if _banishing and not _buttons.is_empty():
		_buttons[0].grab_focus()


func _banish(index: int) -> void:
	## Removes a card for the rest of the run and deals a replacement.
	var gone := _ids[index]
	world.banned.append(gone)
	world.banishes_left -= 1
	_banishing = false
	Audio.play("hurt", -10.0, 0.0)
	var fresh := _roll(1, _ids)
	var options: Array = []
	for i in _ids.size():
		if i == index:
			if not fresh.is_empty():
				options.append(fresh[0])
		else:
			options.append(UPGRADES.card(_ids[i]))
	_show(options)
	_update_tools()
	_buttons[mini(index, _buttons.size() - 1)].grab_focus()


func _card(u: Dictionary, hotkey: int) -> Button:
	var id: String = u.id
	var p: Node = world.player
	var rarity := UPGRADES.rarity_of(u)
	var rcol: Color = UPGRADES.RARITY_COLOR[rarity]
	var have := int(p.upgrades.get(id, 0))
	var b := Button.new()
	b.custom_minimum_size = Vector2(400, 430)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		var i := _ids.find(id)
		if _banishing and i >= 0:
			_banish(i)
		else:
			_pick(id))
	b.focus_entered.connect(func() -> void: Audio.play("ui_move", -8.0, 0.0))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	# Rarity border; only the focused card lights up.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		var focused: bool = state == "focus"
		sb.bg_color = Color(0.07, 0.055, 0.06, 0.96).lerp(rcol, 0.12 if focused else 0.0)
		sb.border_color = rcol.lightened(0.35) if focused else Color(rcol, 0.75)
		sb.set_border_width_all(6 if focused else 3)
		sb.set_corner_radius_all(10)
		if focused:
			sb.shadow_color = Color(rcol, 0.45)
			sb.shadow_size = 14
		b.add_theme_stylebox_override(state, sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 22
	v.offset_right = -22
	v.offset_top = 16
	v.offset_bottom = -18
	v.add_theme_constant_override("separation", 8)
	b.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var rl := UI.label(Game.t("rarity_" + rarity), 20, rcol, true)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rl)
	top.add_child(UI.label("[%d]" % hotkey, 20, Game.COLOR_DIM))
	var icon := UpgradeIcon.new()
	icon.id = id
	icon.hero_id = p.hero_id
	icon.color = rcol
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	var name_l := UI.label(Game.t("up_" + id), 34, Game.COLOR_GOLD, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	var sub := ""
	if u.has("slot"):
		sub = Game.t("branch_of") % Game.t(p.data[u.slot]).split(" - ")[0]
	elif u.has("needs"):
		sub = Game.t("evo_from") % [Game.t("up_" + u.needs[0]), Game.t("up_" + u.needs[1])]
	elif UPGRADES.max_of(u) > 1 and UPGRADES.max_of(u) < 100:
		sub = Game.t("up_stage") % [have + 1, UPGRADES.max_of(u)]
	if sub != "":
		var sl := UI.label(sub, 21, Color(0.78, 0.68, 0.95))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(sl)
	var pv := _preview(id)
	if pv != "":
		var pl := UI.label(pv, 24, Color(0.62, 0.95, 0.62), true)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(pl)
	var desc := UI.label(Game.t("up_" + id + "_d"), 23)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(desc)
	_ignore_mouse(v)
	return b


func _ignore_mouse(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(c)
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _preview(id: String) -> String:
	## "stat  current → next" for cards that change a number.
	var p: Node = world.player
	var n := int(p.upgrades.get(id, 0))
	match id:
		"might": return _fmt("stat_damage", p.damage, p.damage * 1.15)
		"temper": return _fmt("stat_damage", p.damage, p.damage * 1.05)
		"boss_berserk": return _fmt("stat_damage", p.damage, p.damage * 1.25)
		"frenzy": return _fmt("stat_aps", 1.0 / p.attack_cd, 1.12 / p.attack_cd, "%.2f")
		"swift": return _fmt("stat_move", p.move_speed, p.move_speed * 1.08)
		"vitality": return _fmt("stat_hp", p.max_hp, p.max_hp + 25.0)
		"fortitude": return _fmt("stat_hp", p.max_hp, p.max_hp + 10.0)
		"boss_colossus": return _fmt("stat_hp", p.max_hp, p.max_hp + 60.0)
		"elixir": return _fmt("stat_heal", p.hp, minf(p.max_hp, p.hp + p.max_hp * 0.5))
		"precision": return _fmt("stat_crit", p.crit_chance * 100.0, p.crit_chance * 100.0 + 8.0, "%d%%")
		"boss_hunter": return _fmt("stat_crit", p.crit_chance * 100.0, p.crit_chance * 100.0 + 15.0, "%d%%")
		"ferocity": return _fmt("stat_crit_dmg", p.crit_mult * 100.0, p.crit_mult * 100.0 + 40.0, "%d%%")
		"vampirism": return _fmt("stat_lifesteal", p.lifesteal * 100.0, p.lifesteal * 100.0 + 2.0, "%d%%")
		"regeneration": return _fmt("stat_regen", p.regen, p.regen + 0.8, "%.1f")
		"ironskin": return _fmt("stat_armor", p.armor * 100.0, p.armor * 100.0 + 6.0, "%d%%")
		"magnet": return _fmt("stat_pickup", p.pickup_range, p.pickup_range * 1.4)
		"focus": return _fmt("stat_cd", p.cd_mult * 100.0, p.cd_mult * 88.0, "%d%%")
		"boss_ascendance": return _fmt("stat_cd", p.cd_mult * 100.0, p.cd_mult * 75.0, "%d%%")
		"reach": return _fmt("stat_area", p.area_mult * 100.0, p.area_mult * 115.0, "%d%%")
		"swiftstep": return _fmt("stat_dash_cd", p.dash_cd, p.dash_cd * 0.85, "%.2f")
		"multishot": return _fmt("stat_projectiles", n, n + 1, "+%d")
		"piercing": return _fmt("stat_pierce", n, n + 1, "+%d")
		"shadowstep": return _fmt("stat_dash_dmg", 0.0 if n == 0 else 100.0 + 60.0 * n, 100.0 + 60.0 * (n + 1), "%d%%")
		"venom": return _fmt("stat_bleed", p.damage * 0.25 * n, p.damage * 0.25 * (n + 1))
		"thorns": return _fmt("stat_thorns", 50.0 * n, 50.0 * (n + 1), "%d%%")
		"rogue_ult_a", "mage_ult_a", "ranger_ult_a", "knight_ult_a":
			var cd: float = p.cooldowns.ult * p.cd_mult
			return _fmt("stat_ult_cd", cd, cd * 0.65, "%.0f")
	return ""


func _fmt(label: String, a: float, b: float, pattern := "%d") -> String:
	return "%s  %s → %s" % [Game.t(label), pattern % a, pattern % b]


func _unhandled_input(event: InputEvent) -> void:
	if _buttons.is_empty() or _buttons[0].disabled or _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = event.physical_keycode - KEY_1
		if idx >= 0 and idx < _ids.size():
			get_viewport().set_input_as_handled()
			if _banishing:
				_banish(idx)
			else:
				_pick(_ids[idx])
		elif _tools and event.physical_keycode == KEY_R:
			get_viewport().set_input_as_handled()
			_reroll()
		elif _tools and event.physical_keycode == KEY_X:
			get_viewport().set_input_as_handled()
			_toggle_banish()


func _pick(id: String) -> void:
	if _done:
		return
	_done = true
	Audio.play("ui_click", 0.0, 0.0)
	chosen.emit(id)
