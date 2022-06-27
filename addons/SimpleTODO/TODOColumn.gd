tool
extends PanelContainer

onready var head = $VBoxContainer/Head
onready var top_separator = $VBoxContainer/TopSeparator
onready var bottom_separator = $VBoxContainer/BottomSeparator
onready var scroll_container = $VBoxContainer/ScrollContainer
onready var actions = $VBoxContainer/Actions
onready var minimize_button = $VBoxContainer/Head/Minimize

onready var name_edit = $VBoxContainer/Head/Name
onready var item_container = $VBoxContainer/ScrollContainer/Items
onready var counter = $VBoxContainer/Head/Counter
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

func set_minimized(val):
	minimized = val
	
	var new_text = "V"
	
	if not val:
		new_text = "^"

	minimize_button.text = new_text
	
	top_separator.visible = not val
	scroll_container.visible = not val
	bottom_separator.visible = not val
	actions.visible = not val

signal delete

func _ready() -> void:
	item_placement_holder = main.item_placement_holder
	delete_button.icon = get_icon("Remove", "EditorIcons")
	counter.rect_min_size.x = delete_button.get_minimum_size().x
	set_minimized(false)

func _process(delta):
	if is_dragging:
		var mouse_position = main.get_local_mouse_position()
		
		var item_under_mouse = get_column_from_mouse_position()
		if item_under_mouse:
			if item_under_mouse:
				var item_index = item_under_mouse.get_index()
				
				if not main.column_container == item_placement_holder.get_parent():
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

func request_save() -> void:
	update_counter()
	get_tree().get_nodes_in_group("__todo_plugin__").front().save_data()

func name_changed(new_text: String) -> void:
	timer.start()

func _on_Minimize_pressed():
	set_minimized(not minimized)

func get_column_from_mouse_position() -> PanelContainer:
	var mouse_position = main.column_container.get_local_mouse_position()
	
	for i in main.column_container.get_child_count():
		var child = main.column_container.get_child(i)
		var rect: Rect2 = child.get_rect()

		if rect.has_point(Vector2(mouse_position.x, 0)):
			return child
	return null

# Handles left click being pressed on the drag panel
func _on_DragPanel_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed and not is_dragging:
			initial_item_index = get_index()
			
			get_parent().remove_child(self)
			
			# Set the size vertical flags to none so that it doesn't stretch
			# when being dragged
			size_flags_vertical = SIZE_FILL
			
			main.add_child(self)
			
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
		if event.button_index == 1 and not event.pressed and is_dragging:
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

			move_item(current_drag_item_index)

			current_drag_item_index = 0
			initial_item_index = 0

func move_item(index):
	undo_redo.create_action("Move Column")

	var current_index = initial_item_index
	
	undo_redo.add_do_method(main.column_container, "move_child", self, index)
	undo_redo.add_do_method(self, "request_save")
	undo_redo.add_undo_method(main.column_container, "move_child", self, current_index)
	undo_redo.add_undo_method(self, "request_save")

	undo_redo.commit_action()
