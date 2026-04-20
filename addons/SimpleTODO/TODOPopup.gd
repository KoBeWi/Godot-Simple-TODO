@tool
extends PopupMenu

var callbacks: Dictionary[int, Callable]
var validators: Dictionary[int, Callable]

func _init() -> void:
	index_pressed.connect(on_selected)

func create_item(text: String, callback: Callable, validator: Callable = Callable()):
	add_item(text)
	
	var id := get_item_id(item_count - 1)
	callbacks[id] = callback
	validators[id] = validator

func popup_menu(at: Control):
	for i in item_count:
		var id := get_item_id(i)
		var callable: Callable = validators.get(id, Callable())
		if callable.is_valid():
			set_item_disabled(i, not callable.call())
	
	reset_size()
	position = Vector2(at.get_screen_position().x, DisplayServer.mouse_get_position().y)
	popup()

func on_selected(index: int):
	var id := get_item_id(index)
	callbacks[id].call()
