@tool
extends PanelContainer

@onready var header: Control = %Header
@onready var item_container = %Items
@onready var foldable = [item_container, %TopSeparator, %BottomSeparator, %Actions]
@onready var delete_button = %DeleteColumn
@onready var timer = $Timer

var main: Control
var plugin: EditorPlugin
var undo_redo: UndoRedo

var item_placement_holder: Panel
var mirror_header_panel: PanelContainer
var mirror_header: Control

var minimized = false: set = set_minimized

var is_dragging := false
var initial_item_index := 0
var current_drag_item_index := 0
var item_margin := 20

signal delete
signal counter_updated

func set_minimized(val: bool):
	minimized = val
	
	if plugin:
		header.minimize_button.icon = get_theme_icon(&"ArrowDown" if minimized else &"ArrowUp", &"EditorIcons")
		mirror_header.minimize_button.icon = get_theme_icon(&"ArrowDown" if minimized else &"ArrowUp", &"EditorIcons")
	
	for node in foldable:
		node.visible = not minimized

func _ready() -> void:
	item_placement_holder = main.item_placement_holder
	if plugin:
		delete_button.icon = get_theme_icon(&"Remove", &"EditorIcons")
	
	mirror_header_panel = PanelContainer.new()
	main.column_mirror.add_child(mirror_header_panel)
	mirror_header_panel.add_theme_stylebox_override(&"panel", get_theme_stylebox(&"panel"))
	header.name_edit.text_changed.connect(name_changed)
	
	mirror_header = preload("res://addons/SimpleTODO/ColumnHeader.tscn").instantiate()
	mirror_header_panel.add_child(mirror_header)
	
	var toggle_minimized := func(): set_minimized(not minimized)
	
	header.minimize_button.pressed.connect(toggle_minimized)
	mirror_header.minimize_button.pressed.connect(toggle_minimized)
	mirror_header.name_edit.editable = false
	
	header.drag_panel.gui_input.connect(drag_panel_input)
	mirror_header.drag_panel.gui_input.connect(drag_panel_input)
	header.counter.custom_minimum_size.x = delete_button.get_minimum_size().x
	mirror_header.counter.custom_minimum_size.x = delete_button.get_minimum_size().x
	
	set_process(false)
	set_process_input(false)
	set_minimized(false)
	update_mirror(0)
	
	main.connect_scrollbar(update_mirror)
	item_container.child_entered_tree.connect(validate_unique_id)
	item_container.child_entered_tree.connect(update_counter.unbind(1), CONNECT_DEFERRED)
	item_container.child_exiting_tree.connect(update_counter.unbind(1), CONNECT_DEFERRED)

func set_title(column_name):
	header.name_edit.text = column_name
	mirror_header.name_edit.text = column_name

func update_mirror(v):
	if not is_inside_tree():
		return
	
	mirror_header_panel.custom_minimum_size = Vector2(size.x, header.size.y)
	await get_tree().process_frame
	await get_tree().process_frame
	mirror_header_panel.global_position.x = global_position.x

func _process(delta):
	if is_dragging:
		var mouse_position = main.get_local_mouse_position()
		
		var item_under_mouse = get_column_from_mouse_position()
		if item_under_mouse:
			if item_under_mouse:
				var item_index := item_under_mouse.get_index()
				
				if main.column_container != item_placement_holder.get_parent():
					item_placement_holder.get_parent().remove_child(item_placement_holder)
					main.column_container.add_child(item_placement_holder)
				
				item_placement_holder.get_parent().move_child(item_placement_holder, item_index)
				current_drag_item_index = item_index
		
		position = mouse_position

func create_item() -> Control:
	var item = preload("res://addons/SimpleTODO/TODOItem.tscn").instantiate()
	item.parent_column = self
	item.plugin = plugin
	item.main = main
	return item

func add_item(from_button := false) -> Control:
	var item := create_item()
	
	undo_redo.create_action("Add Item")
	undo_redo.add_do_method(item_container.add_child.bind(item))
	undo_redo.add_do_reference(item)
	undo_redo.add_do_method(request_save)
	undo_redo.add_undo_method(remove_child.bind(item))
	undo_redo.add_undo_method(request_save)
	undo_redo.commit_action()
	
	if from_button:
		item.text_field.grab_focus.call_deferred()
		item.text_field.select_all.call_deferred()
	
	return item

func delete_column() -> void:
	delete.emit()

func update_counter() -> void:
	header.counter.text = str(item_container.get_child_count())
	mirror_header.counter.text = str(item_container.get_child_count())
	counter_updated.emit()

func request_save() -> void:
	plugin.save_data()

func name_changed(_new_text: String) -> void:
	mirror_header.name_edit.text = _new_text
	timer.start()

# Handles left click being pressed on the drag panel.
func drag_panel_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and !is_dragging:
			initial_item_index = get_index()
			get_parent().remove_child(self)
			main.add_child(self)
			
			# Set the size vertical flags to none so that it doesn't stretch when being dragged.
			size_flags_vertical = SIZE_FILL
			
			set_process(true)
			set_process_input(true)
			is_dragging = true
			
			item_placement_holder.get_parent().remove_child(item_placement_holder)
			main.column_container.add_child(item_placement_holder)
			
			item_placement_holder.size_flags_vertical = 0
			item_placement_holder.visible = true
			item_placement_holder.custom_minimum_size = size
			item_placement_holder.size = size

# Handles left click being released.
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and is_dragging:
			set_process(false)
			set_process_input(false)
			is_dragging = false
			
			size_flags_vertical = SIZE_EXPAND
			reset_size()
			
			if item_placement_holder:
				item_placement_holder.size_flags_vertical = SIZE_FILL
				item_placement_holder.visible = false
				item_placement_holder.get_parent().remove_child(item_placement_holder)
				main.add_child(item_placement_holder)
			
			get_parent().remove_child(self)
			main.column_container.add_child(self)
			move_column(current_drag_item_index)
			
			current_drag_item_index = 0
			initial_item_index = 0
			main.refresh_mirrors()

func move_column(index):
	undo_redo.create_action("Move Column")

	undo_redo.add_do_method(main.column_container.move_child.bind(self, index))
	undo_redo.add_do_method(request_save)
	undo_redo.add_undo_method(main.column_container.move_child.bind(self, initial_item_index))
	undo_redo.add_undo_method(request_save)

	undo_redo.commit_action()

func get_column_from_mouse_position() -> PanelContainer:
	var mouse_position = main.column_container.get_local_mouse_position()
	
	for child in main.column_container.get_children():
		if not child is PanelContainer:
			continue
		
		if child.get_rect().has_point(Vector2(mouse_position.x, 0)):
			return child
	return null

func validate_unique_id(for_item: Control):
	if for_item.get_script() == null:
		return
	
	var is_unique := true
	for item in item_container.get_children():
		if item != for_item and item.id == for_item.id:
			is_unique = false
	
	if not is_unique:
		var id_list := item_container.get_children().map(func(item: Control): return item.id)
		
		for i in 1000000:
			if not i in id_list:
				for_item.id = i
				return
		
		push_error("Simple TODO: Unique ID could not be ensured. Farewell.")
