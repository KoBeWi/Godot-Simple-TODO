@tool
extends Control

@onready var column_container: Control = %Columns
@onready var column_mirror: Control = %ColumnMirror
@onready var scroll_container: ScrollContainer = %ScrollContainer

var plugin: EditorPlugin

var undo_redo: UndoRedo
var item_placement_holder: Panel
var counter_queued: bool

func _ready() -> void:
	undo_redo = UndoRedo.new()
	undo_redo.max_steps = 20
	
	item_placement_holder = create_drag_placement_holder()
	scroll_container.get_v_scroll_bar().value_changed.connect(update_mirror)
	update_full_counter()

func update_mirror(v: float):
	column_mirror.visible = v > column_mirror.get_child(0).size.y

func connect_scrollbar(to_method: Callable):
	scroll_container.get_h_scroll_bar().value_changed.connect(to_method)
	scroll_container.get_v_scroll_bar().value_changed.connect(to_method)

func create_drag_placement_holder() -> Panel:
	var new_holder: Panel = preload("res://addons/SimpleTODO/ItemPlacementHolder.tscn").instantiate()
	new_holder.visible = false
	add_child(new_holder)
	
	return new_holder

func create_column() -> Control:
	var column = preload("res://addons/SimpleTODO/TODOColumn.tscn").instantiate()
	column.main = self
	column.plugin = plugin
	column.undo_redo = undo_redo
	
	column.delete.connect(delete_column.bind(column))
	column.counter_updated.connect(update_full_counter)
	return column

func add_column(from_button := false) -> Control:
	var column := create_column()
	
	undo_redo.create_action("Add Column")
	undo_redo.add_do_method(column_container.add_child.bind(column))
	undo_redo.add_do_reference(column)
	undo_redo.add_do_method(request_save)
	undo_redo.add_undo_method(column_container.remove_child.bind(column))
	undo_redo.add_undo_method(request_save)
	undo_redo.commit_action()
	
	if from_button:
		column.header.name_edit.grab_focus.call_deferred()
		column.header.name_edit.select_all.call_deferred()
		get_tree().create_timer(0.1).timeout.connect(scroll_container.ensure_control_visible.bind(column))
	
	return column

func delete_column(column):
	undo_redo.create_action("Delete Column")
	undo_redo.add_do_method(column_container.remove_child.bind(column))
	undo_redo.add_do_method(request_save)
	undo_redo.add_undo_method(column_container.add_child.bind(column))
	undo_redo.add_undo_reference(column)
	undo_redo.add_undo_method(request_save)
	undo_redo.commit_action()

func request_save() -> void:
	plugin.save_data()

func refresh_mirrors():
	for column in column_container.get_children():
		column.update_mirror.call_deferred(0)

func filter_elements(new_text: String) -> void:
	new_text = new_text.to_lower()
	for column in column_container.get_children():
		for item in column.item_container.get_children():
			item.filter(new_text)

func update_full_counter():
	if counter_queued:
		return
	counter_queued = true
	
	_update_full_counter.call_deferred()

func _update_full_counter():
	%Total.text = str("Total: %d" % column_container.get_children().reduce(func(accum: int, column: Node) -> int: return accum + column.item_container.get_child_count(), 0))
	counter_queued = false
