@tool
extends PopupMenu

var callbacks: Array[Callable]
var validators: Array[Callable]

func _init() -> void:
	index_pressed.connect(on_selected)

func create_item(text: String, callback: Callable, validator: Callable):
	add_item(text)
	callbacks.append(callback)
	validators.append(validator)

func popup_menu(at: Control):
	for i in validators.size():
		if validators[i].is_valid():
			set_item_disabled(i, not validators[i].call())
	
	reset_size()
	position = Vector2(at.get_screen_position().x, DisplayServer.mouse_get_position().y)
	popup()

func on_selected(index: int):
	callbacks[index].call()
