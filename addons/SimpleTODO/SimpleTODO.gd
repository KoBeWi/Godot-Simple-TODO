@tool
extends EditorPlugin

const TEXT_DATA_SETTING = "addons/simple_todo/text_data_file"
const IMAGE_DATA_SETTING = "addons/simple_todo/image_data_file"

var text_data_file := "res://TODO.cfg"
var image_data_file := "res://TODO.bin"

var pending_columns: Array[Control]

var todo_screen: Control
var image_database: Dictionary#[Image, String]

func _get_plugin_name():
	return "TODO"

func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_theme_icon(&"CheckBox", &"EditorIcons")

func _has_main_screen() -> bool:
	return true

func setup_setting(setting: String, initial_value: String):
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, initial_value)
	
	ProjectSettings.add_property_info({ "name": setting, "type": TYPE_STRING, "hint": PROPERTY_HINT_SAVE_FILE })
	ProjectSettings.set_initial_value(setting, initial_value)

func _enter_tree():
	setup_setting(TEXT_DATA_SETTING, text_data_file)
	text_data_file = ProjectSettings.get_setting(TEXT_DATA_SETTING)
	setup_setting(IMAGE_DATA_SETTING, image_data_file)
	image_data_file = ProjectSettings.get_setting(IMAGE_DATA_SETTING)
	ProjectSettings.settings_changed.connect(on_settings_changed)
	
	todo_screen = preload("res://addons/SimpleTODO/TODO.tscn").instantiate()
	todo_screen.plugin = self
	todo_screen.hide()
	
	get_editor_interface().get_editor_main_screen().add_child(todo_screen)
	load_data()

func _ready() -> void:
	set_process_input(false)

func on_settings_changed():
	var new_text_data_file: String = ProjectSettings.get_setting(TEXT_DATA_SETTING)
	if new_text_data_file != text_data_file:
		var da := DirAccess.open("res://")
		if da.rename(text_data_file, new_text_data_file) == OK:
			text_data_file = new_text_data_file
	
	var new_image_data_file: String = ProjectSettings.get_setting(IMAGE_DATA_SETTING)
	if new_image_data_file != image_data_file:
		var da := DirAccess.open("res://")
		if da.rename(image_data_file, new_image_data_file) == OK:
			image_data_file = new_image_data_file

func _process(delta: float) -> void:
	if pending_columns.is_empty():
		set_process(false)
		print("TODO loaded")
		return
	
	var column = pending_columns.pop_front()
	todo_screen.column_container.add_child(column)

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
	if get_viewport().gui_get_focus_owner() is TextEdit:
		return
	
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
	var image_database_updated: bool
	var used_images: Dictionary#[Image, bool]
	
	var data := ConfigFile.new()
	for column in todo_screen.column_container.get_children():
		var section = column.header.name_edit.text
		
		if column.item_container.get_child_count() > 0:
			
			for item in column.item_container.get_children():
				var item_id := str("item", item.id)
				data.set_value(section, item_id, item.text_field.text)
				
				var image: Image = item.image_data
				if image:
					if not image in image_database:
						var id: PackedStringArray
						for i in 8:
							id.append(char(randi_range(33, 125)))
						image_database[image] = "".join(id)
						image_database_updated = true
					
					used_images[image] = true
					item_id += ".image"
					data.set_value(section, item_id, image_database[image])
				
				for imag in image_database.keys():
					if not imag in used_images:
						image_database.erase(imag)
						image_database_updated = true
		else:
			data.set_value(section, "__none__", "null")
	
	data.save(text_data_file)
	
	if image_database_updated:
		var data_to_save: Dictionary#[String, PackedByteArray]
		
		for imag in image_database:
			data_to_save[image_database[imag]] = imag.save_png_to_buffer()
		
		var image_file := FileAccess.open(image_data_file, FileAccess.WRITE)
		image_file.store_var(data_to_save)

func load_data():
	var data := ConfigFile.new()
	data.load(text_data_file)
	
	var image_data: Dictionary#[String, PackedByteArray]
	var image_dataf := FileAccess.open(image_data_file, FileAccess.READ)
	if image_dataf:
		var loaded = image_dataf.get_var()
		if loaded is Dictionary:
			image_data = loaded
	
	for section in data.get_sections():
		var column = todo_screen.create_column()
		column.ready.connect(column.set_title.bind(section))
		pending_columns.append(column)
		
		for item in data.get_section_keys(section):
			if item == "__none__" or item.ends_with(".image"):
				continue
			
			var image_id = data.get_value(section, item + ".image", "")
			var image_bytes = image_data.get(image_id)
			var image: Image
			
			if image_bytes is PackedByteArray:
				image = Image.new()
				image.load_png_from_buffer(image_bytes)
				image_database[image] = image_id
			
			var column_item = column.create_item()
			column_item.image_data = image
			column_item.ready.connect(column_item.initialize.bind(data.get_value(section, item), item.to_int()), CONNECT_DEFERRED)
			column.ready.connect(column_item.add_to_column.bind(column))
