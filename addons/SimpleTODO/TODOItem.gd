@tool
extends HBoxContainer

enum { PASTE_IMAGE, DELETE_IMAGE }

@onready var text_field: TextEdit = %Text
@onready var image_field: TextureRect = %Image
@onready var button: Button = $Button
@onready var drag_panel: Panel = $DragPanel

var main: Control
var plugin: EditorPlugin
var undo_redo: UndoRedo

var item_placement_holder: Panel
var main_column_container: HBoxContainer
var parent_column: PanelContainer
var next_parent_column: PanelContainer

var initial_item_index := 0
var current_drag_item_index := 0
var is_dragging := false
var item_margin := 20

var id: int
var is_marked: bool
var context_menu: PopupMenu
var image_data: Image
var image_popup: PopupPanel

func _ready() -> void:
	undo_redo = main.undo_redo
	item_placement_holder = main.item_placement_holder
	next_parent_column = parent_column
	if plugin:
		button.icon = get_theme_icon(&"Remove", &"EditorIcons")
	
	set_process(false)
	set_process_input(false)

func delete_pressed() -> void:
	delete_item()

func request_save() -> void:
	plugin.save_data()

func _process(_delta):
	if is_dragging:
		var mouse_position = main.get_local_mouse_position()
		
		var item_under_mouse = get_column_item_from_mouse_position()
		if not item_under_mouse.is_empty():
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
		
		position = mouse_position

func get_column_from_mouse_position() -> PanelContainer:
	var mouse_position = main.column_container.get_local_mouse_position()
	
	for i in main.column_container.get_child_count():
		var child = main.column_container.get_child(i)
		var rect: Rect2 = child.get_rect()
	
		if rect.has_point(Vector2(mouse_position.x, 0)):
			return child
	return null

func get_column_item_from_mouse_position() -> Dictionary:
	var column_under_mouse := get_column_from_mouse_position()
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
		
		# Likely we are dragging into a column with no items.
		return {"item": null, "column": column_under_mouse}
	else:
		return {}

# Handles left click being pressed on the drag panel.
func drag_panel_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not is_dragging:
			initial_item_index = get_index()
			get_parent().remove_child(self)
			main.add_child(self)
			
			# Set the size vertical flags to none so that it doesn't stretch when being dragged.
			size_flags_vertical = 0
			custom_minimum_size = size
			is_dragging = true
			
			set_process(true)
			set_process_input(true)
			
			item_placement_holder.get_parent().remove_child(item_placement_holder)
			parent_column.item_container.add_child(item_placement_holder)
			item_placement_holder.get_parent().move_child(item_placement_holder, initial_item_index)
			
			item_placement_holder.visible = true
			item_placement_holder.custom_minimum_size = custom_minimum_size
			item_placement_holder.size = size
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if is_marked:
				$DragPanel.modulate = Color.WHITE
				is_marked = false
			else:
				$DragPanel.modulate = Color.RED
				is_marked = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not context_menu:
				context_menu = PopupMenu.new()
				context_menu.add_item("Paste Image")
				context_menu.add_item("Delete Image")
				add_child(context_menu)
				context_menu.id_pressed.connect(menu_action)
			
			context_menu.set_item_disabled(PASTE_IMAGE, not DisplayServer.clipboard_has_image())
			context_menu.set_item_disabled(DELETE_IMAGE, not image_field.visible)
			
			context_menu.reset_size()
			context_menu.position = Vector2(drag_panel.get_screen_position().x, DisplayServer.mouse_get_position().y)
			context_menu.popup()

# Handles left click being released.
func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and is_dragging:
			set_process(false)
			set_process_input(false)
			
			get_parent().remove_child(self)
			
			is_dragging = false
			size_flags_vertical = SIZE_FILL
			custom_minimum_size = Vector2.ZERO
			
			if item_placement_holder:
				item_placement_holder.visible = false
				item_placement_holder.get_parent().remove_child(item_placement_holder)
				main.add_child(item_placement_holder)
			
			move_item(current_drag_item_index)
			
			current_drag_item_index = 0
			initial_item_index = 0

# Used for undo redo, if we can't remove this item then don't error out.
func remove_self_safe():
	var parent := get_parent()
	if parent:
		parent.remove_child(self)

func move_item(index):
	index = mini(index, next_parent_column.item_container.get_child_count())
	
	undo_redo.create_action("Move Item")
	
	undo_redo.add_do_method(remove_self_safe)
	undo_redo.add_do_method(next_parent_column.item_container.add_child.bind(self))
	undo_redo.add_do_method(next_parent_column.item_container.move_child.bind(self, index))
	undo_redo.add_do_method(next_parent_column.request_save)
	undo_redo.add_do_property(self, &"parent_column", next_parent_column)
	undo_redo.add_do_property(self, &"next_parent_column", parent_column)
	
	undo_redo.add_undo_method(remove_self_safe)
	undo_redo.add_undo_method(parent_column.item_container.add_child.bind(self))
	undo_redo.add_undo_method(parent_column.item_container.move_child.bind(self, initial_item_index))
	undo_redo.add_undo_method(parent_column.request_save)
	undo_redo.add_undo_property(self, &"parent_column", parent_column)
	
	undo_redo.commit_action()

func delete_item():
	undo_redo.create_action("Delete Item")
	undo_redo.add_do_method(parent_column.item_container.remove_child.bind(self))
	undo_redo.add_do_method(parent_column.request_save)
	undo_redo.add_undo_method(parent_column.item_container.add_child.bind(self))
	undo_redo.add_undo_method(parent_column.item_container.move_child.bind(self, get_index()))
	undo_redo.add_undo_method(parent_column.request_save)
	undo_redo.commit_action()

func filter(text: String):
	if text.is_empty() or text_field.text.to_lower().contains(text):
		show()
	else:
		hide()

func initialize(text: String, p_id: int):
	text_field.text = text
	id = p_id
	
	if image_data:
		create_texture()

func add_to_column(column: Control):
	column.item_container.add_child(self)

func menu_action(id: int):
	match id:
		PASTE_IMAGE:
			var image := DisplayServer.clipboard_get_image()
			assert(image)
			
			undo_redo.create_action("Paste image")
			undo_redo.add_do_property(self, &"image_data", image)
			undo_redo.add_do_method(create_texture)
			undo_redo.add_do_method(delete_image_popup)
			undo_redo.add_do_method(request_save)
			undo_redo.add_undo_property(self, &"image_data", image_data)
			undo_redo.add_undo_method(create_texture)
			undo_redo.add_undo_method(delete_image_popup)
			undo_redo.add_undo_method(request_save)
			undo_redo.commit_action()
		DELETE_IMAGE:
			undo_redo.create_action("Delete image")
			undo_redo.add_do_property(self, &"image_data", null)
			undo_redo.add_do_method(create_texture)
			undo_redo.add_do_method(delete_image_popup)
			undo_redo.add_do_method(request_save)
			undo_redo.add_undo_property(self, &"image_data", image_data)
			undo_redo.add_undo_method(create_texture)
			undo_redo.add_undo_method(delete_image_popup)
			undo_redo.add_undo_method(request_save)
			undo_redo.commit_action()

func create_texture():
	if image_data:
		image_field.texture = ImageTexture.create_from_image(image_data)
		image_field.show()
	else:
		image_field.texture = null
		image_field.hide()

func delete_image_popup():
	if image_popup:
		image_popup.queue_free()
		image_popup = null

func image_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not image_popup:
				image_popup = PopupPanel.new()
				image_popup.add_theme_stylebox_override(&"panel", get_theme_stylebox(&"panel", &"Tree"))
				add_child(image_popup)
				
				var pattern := TextureRect.new()
				pattern.texture = get_theme_icon(&"Checkerboard", &"EditorIcons")
				pattern.stretch_mode = TextureRect.STRETCH_TILE
				image_popup.add_child(pattern)
				
				var big_image := TextureRect.new()
				big_image.texture = image_field.texture
				
				image_popup.add_child(big_image)
			
			image_popup.popup_centered()

func text_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_ENTER and event.ctrl_pressed:
				var item = parent_column.add_item()
				item.text_field.grab_focus()
				item.text_field.select_all()
				accept_event()
			elif event.keycode == KEY_ESCAPE:
				text_field.release_focus()
				accept_event()
