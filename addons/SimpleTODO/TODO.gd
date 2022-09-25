tool
extends Control

onready var column_container = $"%Columns"
onready var vbox_container = $VBoxContainer
onready var column_mirror = $"%ColumnMirror"
onready var scroll_container = $"%ScrollContainer"

var item_placement_holder: Panel
var undo_redo: UndoRedo

func _ready() -> void:
	item_placement_holder = create_drag_placement_holder()
	
	undo_redo = UndoRedo.new()
	
	scroll_container.get_v_scrollbar().connect("value_changed", self, "update_mirror")

func update_mirror(v: float):
	column_mirror.visible = v > column_mirror.get_child(0).rect_size.y

func connect_scrollbar(to_object, to_method):
	scroll_container.get_h_scrollbar().connect("value_changed", to_object, to_method)
	scroll_container.get_v_scrollbar().connect("value_changed", to_object, to_method)

func create_drag_placement_holder() -> Panel:
	var new_holder = preload("res://addons/SimpleTODO/ItemPlacementHolder.tscn").instance()
	new_holder.visible = false
	add_child(new_holder)
	
	return new_holder

func add_column(from_button := false) -> Control:
	var column = preload("res://addons/SimpleTODO/TODOColumn.tscn").instance()
	column.main = self
	column.undo_redo = undo_redo
	
	column.connect("delete", self, "delete_column", [column])
	
	undo_redo.create_action("Add Column")
	undo_redo.add_do_method(column_container, "add_child", column)
	undo_redo.add_do_reference(column)
	undo_redo.add_do_method(self, "request_save")
	undo_redo.add_undo_method(column_container, "remove_child", column)
	undo_redo.add_undo_method(self, "request_save")
	undo_redo.commit_action()
	
	if from_button:
		column.name_edit.call_deferred("grab_focus")
		column.name_edit.call_deferred("select_all")
	
	return column

func delete_column(column):
	undo_redo.create_action("Delete Column")
	undo_redo.add_do_method(column_container, "remove_child", column)
	undo_redo.add_do_method(self, "request_save")
	undo_redo.add_undo_method(column_container, "add_child", column)
	undo_redo.add_undo_reference(column)
	undo_redo.add_undo_method(self, "request_save")
	undo_redo.commit_action()

func request_save() -> void:
	get_tree().get_nodes_in_group("__todo_plugin__").front().save_data()

func refresh_mirrors():
	for column in column_container.get_children():
		column.call_deferred("update_mirror", 0)
