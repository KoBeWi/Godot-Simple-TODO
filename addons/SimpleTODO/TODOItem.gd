tool
extends HBoxContainer

onready var text_field = $Text
onready var label_hack = $Text/HackLabel
var item_placement_holder: Panel
var main: Control
var undo_redo: UndoRedo
var initial_item_index = 0
# The main TODO scene column container node
var main_column_container: HBoxContainer
var parent_column: PanelContainer
var next_parent_column: PanelContainer
var current_drag_item_index = 0
var is_dragging = false
var item_margin = 20

func _ready() -> void:
	undo_redo = main.undo_redo
	item_placement_holder = main.item_placement_holder
	next_parent_column = parent_column

	get_node("Button").icon = get_icon("Remove", "EditorIcons")
	call_deferred("text_changed")

func delete_pressed() -> void:
	delete_item()

func request_save() -> void:
	get_tree().get_nodes_in_group("__todo_plugin__").front().save_data()

func text_changed() -> void:
	label_hack.text = text_field.text
	text_field.rect_min_size.y = label_hack.get_minimum_size().y + 8

func _process(_delta):
	if is_dragging:
		var mouse_position = main.get_local_mouse_position()
		
		var item_under_mouse = get_column_item_from_mouse_position()
		if item_under_mouse:
			var column = item_under_mouse.column
			var column_items = column.item_container
			var item = item_under_mouse.item
			next_parent_column = column
			
			if column_items != item_placement_holder.get_parent():
				item_placement_holder.get_parent().remove_child(item_placement_holder)
				column_items.add_child(item_placement_holder)
			
			if item:
				var item_index = item.get_index()
				item_placement_holder.get_parent().move_child(item_placement_holder, item_index)
				current_drag_item_index = item_index
			elif column_items.get_child_count() <= 0:
				item_placement_holder.get_parent().move_child(item_placement_holder, 0)
				current_drag_item_index = 0
		
		rect_position = mouse_position

func get_column_from_mouse_position() -> PanelContainer:
	var mouse_position = main.column_container.get_local_mouse_position()
	
	for i in main.column_container.get_child_count():
		var child = main.column_container.get_child(i)
		var rect: Rect2 = child.get_rect()

		if rect.has_point(Vector2(mouse_position.x, 0)):
			return child
	return null

func get_column_item_from_mouse_position():
	var column_under_mouse = get_column_from_mouse_position()
	if column_under_mouse:
		var column_items = column_under_mouse.item_container
		var mouse_position = column_items.get_local_mouse_position()
		
		for i in column_items.get_child_count():
			var child: Control = column_items.get_child(i)
			
			var rect: Rect2 = child.get_rect()
			var top_rect: Rect2 = Rect2(rect.position - Vector2(0, item_margin), Vector2(rect.size.x, item_margin))
			var bottom_rect: Rect2 = Rect2(rect.position + Vector2(0, item_margin), Vector2(rect.size.x, item_margin))
			
			if top_rect.has_point(mouse_position) and i <= 0:
				return {"item": child, "column": column_under_mouse}
				
			if bottom_rect.has_point(mouse_position):
				return {"item": child, "column": column_under_mouse}
		
		# Likely we are dragging into a column with no items
		return {"item": null, "column": column_under_mouse}
	else:
		return null

# Handles left click being pressed on the drag panel
func _on_DragPanel_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed and !is_dragging:
			initial_item_index = get_index()
			
			get_parent().remove_child(self)
			
			parent_column.update_counter()
			
			rect_min_size = rect_size
			
			# Set the size vertical flags to none so that it doesn't stretch
			# when being dragged
			size_flags_vertical = 0
			
			main.add_child(self)

			set_process(true)
			
			# Set dragging to true to tell _process to now handle dragging
			is_dragging = true

			item_placement_holder.get_parent().remove_child(item_placement_holder)
			parent_column.item_container.add_child(item_placement_holder)
			item_placement_holder.get_parent().move_child(item_placement_holder, initial_item_index)
			
			item_placement_holder.visible = true
			item_placement_holder.rect_min_size = rect_min_size
			item_placement_holder.rect_size = rect_size

# Handles left click being released
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and !event.pressed and is_dragging:
			set_process(false)

			is_dragging = false
			
			get_parent().remove_child(self)
			
			size_flags_vertical = SIZE_FILL

			rect_min_size = Vector2.ZERO
			
			if item_placement_holder:
				item_placement_holder.visible = false
				item_placement_holder.get_parent().remove_child(item_placement_holder)
				main.add_child(item_placement_holder)

			move_item(current_drag_item_index)

			current_drag_item_index = 0
			initial_item_index = 0

# Used for undo redo, if we can't remove this item then don't error out
func remove_self_safe():
	var parent = get_parent()
	if parent:
		parent.remove_child(self)

func move_item(index):
	undo_redo.create_action("Move Item")

	var current_index = initial_item_index
	
	undo_redo.add_do_method(self, "remove_self_safe")
	undo_redo.add_do_method(next_parent_column.item_container, "add_child", self)
	undo_redo.add_do_method(next_parent_column.item_container, "move_child", self, index)
	undo_redo.add_do_method(next_parent_column, "request_save")
	undo_redo.add_do_property(self, "parent_column", next_parent_column)
	undo_redo.add_do_property(self, "next_parent_column", parent_column)
	
	undo_redo.add_undo_method(self, "remove_self_safe")
	undo_redo.add_undo_method(parent_column.item_container, "add_child", self)
	undo_redo.add_undo_method(parent_column.item_container, "move_child", self, current_index)
	undo_redo.add_undo_method(parent_column, "request_save")
	undo_redo.add_undo_property(self, "parent_column", parent_column)

	undo_redo.commit_action()

func delete_item():
	undo_redo.create_action("Delete Item")
	undo_redo.add_do_method(parent_column.item_container, "remove_child", self)
	undo_redo.add_do_method(parent_column, "request_save")
	undo_redo.add_undo_method(parent_column.item_container, "add_child", self)
	undo_redo.add_undo_method(parent_column, "request_save")
	undo_redo.commit_action()
