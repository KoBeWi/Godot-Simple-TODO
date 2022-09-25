tool
extends PanelContainer

onready var header = $VBoxContainer/Header
onready var minimize_button = header.get_node("Minimize")
onready var name_edit = header.get_node("Name")
onready var counter = header.get_node("Counter")
onready var top_separator = $VBoxContainer/TopSeparator
onready var bottom_separator = $VBoxContainer/BottomSeparator
onready var scroll_container = $VBoxContainer/ScrollContainer
onready var actions = $VBoxContainer/Actions
onready var item_container = $VBoxContainer/ScrollContainer/Items
onready var delete_button = $VBoxContainer/Actions/DeleteColumn
onready var timer = $Timer

var undo_redo: UndoRedo
var minimized = false setget set_minimized
var main: Control
var item_placement_holder: Panel
var is_dragging = false
var initial_item_index = 0
var current_drag_item_index = 0
var item_margin = 20
var mirror_header
var mirror_counter

func set_minimized(val):
	minimized = val

	minimize_button.icon = get_icon("ArrowDown" if minimized else "ArrowUp", "EditorIcons")
	if mirror_header:
		mirror_header.get_node("Minimize").icon = get_icon("ArrowDown" if minimized else "ArrowUp", "EditorIcons")
	
	top_separator.visible = !val
	scroll_container.visible = !val
	bottom_separator.visible = !val
	actions.visible = !val

signal delete

func _ready() -> void:
	set_process(false)
	item_placement_holder = main.item_placement_holder
	delete_button.icon = get_icon("Remove", "EditorIcons")
	counter.rect_min_size.x = delete_button.get_minimum_size().x
	set_minimized(false)
	
	mirror_header = PanelContainer.new()
	main.column_mirror.add_child(mirror_header)
	mirror_header.add_stylebox_override("panel", get_stylebox("panel"))
	mirror_header.add_child(preload("res://addons/SimpleTODO/ColumnHeader.tscn").instance())
	mirror_header.get_child(0).get_node("Minimize").icon = get_icon("ArrowDown" if minimized else "ArrowUp", "EditorIcons")
	mirror_header.get_child(0).get_node("Name").editable = false
	mirror_counter = mirror_header.get_child(0).get_node("Counter")
	main.connect_scrollbar(self, "update_mirror")
	
	header.get_node("DragPanel").connect("gui_input", self, "_on_DragPanel_gui_input")
	mirror_header.get_child(0).get_node("DragPanel").connect("gui_input", self, "_on_DragPanel_gui_input")
	
	update_mirror(0)

func set_name(column_name):
	name_edit.text = column_name
	mirror_header.get_child(0).get_node("Name").text = column_name

func update_mirror(v):
	mirror_header.rect_min_size = Vector2(rect_size.x, header.rect_size.y)
	mirror_header.rect_global_position.x = rect_global_position.x

func _process(delta):
	if is_dragging:
		var mouse_position = main.get_local_mouse_position()
		
		var item_under_mouse = get_column_from_mouse_position()
		if item_under_mouse:
			if item_under_mouse:
				var item_index = item_under_mouse.get_index()
				
				if main.column_container != item_placement_holder.get_parent():
					item_placement_holder.get_parent().remove_child(item_placement_holder)
					main.column_container.add_child(item_placement_holder)
			
				item_placement_holder.get_parent().move_child(item_placement_holder, item_index)
			
				current_drag_item_index = item_index
		
		rect_position = mouse_position

func add_item(from_button := false) -> Control:
	var item = preload("res://addons/SimpleTODO/TODOItem.tscn").instance()
	item.parent_column = self
	item.main = main

	undo_redo.create_action("Add Item")
	undo_redo.add_do_method(item_container, "add_child", item)
	undo_redo.add_do_reference(item)
	undo_redo.add_do_method(self, "request_save")
	undo_redo.add_undo_method(item_container, "remove_child", item)
	undo_redo.add_undo_method(self, "request_save")
	undo_redo.commit_action()
	
	if from_button:
		item.get_node("Text").call_deferred("grab_focus")
		item.get_node("Text").call_deferred("select_all")
	
	return item

func delete_column() -> void:
	emit_signal("delete")

func update_counter() -> void:
	counter.text = str(item_container.get_child_count())
	mirror_counter.text = str(item_container.get_child_count())

func request_save() -> void:
	get_tree().get_nodes_in_group("__todo_plugin__").front().save_data()

func name_changed(_new_text: String) -> void:
	mirror_header.get_child(0).get_node("Name").text = _new_text
	timer.start()

func _on_Minimize_pressed():
	set_minimized(!minimized)

# Handles left click being pressed on the drag panel
func _on_DragPanel_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed and !is_dragging:
			initial_item_index = get_index()
			
			get_parent().remove_child(self)
			
			# Set the size vertical flags to none so that it doesn't stretch
			# when being dragged
			size_flags_vertical = SIZE_FILL
			
			main.add_child(self)
			
			set_process(true)

			# Set dragging to true to tell _process to now handle dragging
			is_dragging = true
			
			item_placement_holder.get_parent().remove_child(item_placement_holder)
			
			main.column_container.add_child(item_placement_holder)
			
			item_placement_holder.size_flags_vertical = 0
			item_placement_holder.visible = true
			item_placement_holder.rect_min_size = rect_size
			item_placement_holder.rect_size = rect_size

# Handles left click being released
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and !event.pressed and is_dragging:
			set_process(false)

			is_dragging = false
			
			get_parent().remove_child(self)
			
			size_flags_vertical = SIZE_EXPAND
			
			rect_size = Vector2.ZERO
			
			if item_placement_holder:
				item_placement_holder.size_flags_vertical = SIZE_FILL
				item_placement_holder.visible = false
				item_placement_holder.get_parent().remove_child(item_placement_holder)
				main.add_child(item_placement_holder)

			main.column_container.add_child(self)

			move_column(current_drag_item_index)

			current_drag_item_index = 0
			initial_item_index = 0
			main.refresh_mirrors()

func move_column(index):
	undo_redo.create_action("Move Column")

	var current_index = initial_item_index
	
	undo_redo.add_do_method(main.column_container, "move_child", self, index)
	undo_redo.add_do_method(self, "request_save")
	undo_redo.add_undo_method(main.column_container, "move_child", self, current_index)
	undo_redo.add_undo_method(self, "request_save")

	undo_redo.commit_action()

func get_column_from_mouse_position() -> PanelContainer:
	var mouse_position = main.column_container.get_local_mouse_position()
	
	for i in main.column_container.get_child_count():
		var child = main.column_container.get_child(i)
		var rect: Rect2 = child.get_rect()

		if rect.has_point(Vector2(mouse_position.x, 0)):
			return child
	return null

func _on_Items_child_entered_tree(node):
	update_counter()

func _on_Items_child_exited_tree(node):
	update_counter()
