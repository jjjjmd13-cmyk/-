extends Node
## Root scene: switches between the title screen, hero select and a run.

const MainMenu := preload("res://scripts/ui/main_menu.gd")
const HeroSelect := preload("res://scripts/ui/hero_select.gd")
const World := preload("res://scripts/game/world.gd")

var _current: Node
var _ui_layer: CanvasLayer


func _ready() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	show_menu()


func _swap(node: Node, in_ui: bool) -> void:
	get_tree().paused = false
	if is_instance_valid(_current):
		_current.queue_free()
	_current = node
	if in_ui:
		_ui_layer.add_child(node)
	else:
		add_child(node)


func show_menu() -> void:
	var m := MainMenu.new()
	m.start_pressed.connect(func() -> void: show_select.call_deferred())
	_swap(m, true)


func show_select() -> void:
	Audio.play_music("menu")
	var s := HeroSelect.new()
	s.hero_chosen.connect(func(_id: String) -> void: start_run.call_deferred())
	s.back_pressed.connect(func() -> void: show_menu.call_deferred())
	_swap(s, true)


func start_run() -> void:
	var w := World.new()
	w.exit_requested.connect(func(target: String) -> void: _on_exit.call_deferred(target))
	_swap(w, false)


func _on_exit(target: String) -> void:
	match target:
		"retry":
			start_run()
		"select":
			show_select()
		_:
			show_menu()
