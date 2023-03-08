@tool
extends EditorPlugin

const DATA_FILE = "res://TODO.cfg"

var todo_screen: Control
var is_loading: bool

func _get_plugin_name():
	return "TODO"

func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_theme_icon(&"CheckBox", &"EditorIcons")

func _has_main_screen() -> bool:
	return true

func _enter_tree():
	todo_screen = preload("res://addons/SimpleTODO/TODO.tscn").instantiate()
	todo_screen.plugin = self
	todo_screen.hide()
	
	get_editor_interface().get_editor_main_screen().add_child(todo_screen)
	load_data()
	print("TODO loaded")

func _ready() -> void:
	set_process_input(false)

func _set_window_layout(configuration: ConfigFile):
	if configuration.has_section("SimpleTODO"):
		var minimized_tabs = configuration.get_value("SimpleTODO", "minimized_tabs")
		
		if minimized_tabs.size() <= 0:
			return
		
		for i in todo_screen.column_container.get_child_count():
			var column: PanelContainer = todo_screen.column_container.get_child(i)
			column.set_minimized.call_deferred(minimized_tabs[i])

func _get_window_layout(configuration: ConfigFile):
	var new_minimized_tabs = []
	
	for column in todo_screen.column_container.get_children():
		if not column is PanelContainer:
			continue
		
		new_minimized_tabs.append(column.minimized)
	
	configuration.set_value("SimpleTODO", "minimized_tabs", new_minimized_tabs)

func _exit_tree():
	todo_screen.queue_free()

func _make_visible(visible: bool) -> void:
	todo_screen.visible = visible
	set_process_input(visible)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if event.is_command_or_control_pressed():
				if event.keycode == KEY_Z:
					todo_screen.undo_redo.undo()
					get_viewport().set_input_as_handled()
				elif event.keycode == KEY_Y:
					todo_screen.undo_redo.redo()
					get_viewport().set_input_as_handled()

func save_data():
	if is_loading:
		return
	
	var data := ConfigFile.new()
	for column in todo_screen.column_container.get_children():
		var section = column.header.name_edit.text
		
		if column.item_container.get_child_count() > 0:
			for item in column.item_container.get_children():
				data.set_value(section, str("item", item.id), item.text_field.text)
		else:
			data.set_value(section, "__none__", "null")
	
	data.save(DATA_FILE)

func load_data():
	var data := ConfigFile.new()
	data.load(DATA_FILE)
	
	is_loading = true
	
	for section in data.get_sections():
		var column = todo_screen.add_column()
		column.set_name(section)
		
		for item in data.get_section_keys(section):
			if item == "__none__":
				continue
			
			var column_item = column.add_item()
			column_item.text_field.text = data.get_value(section, item)
			column_item.id = item.to_int()
	
	todo_screen.undo_redo.clear_history()
	is_loading = false
