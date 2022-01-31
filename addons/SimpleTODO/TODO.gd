tool
extends VBoxContainer

onready var column_container = $ScrollContainer/Columns

var undo_redo: UndoRedo

func _ready() -> void:
	undo_redo = UndoRedo.new()

func add_column(from_button := false) -> Control:
	var column = preload("res://addons/SimpleTODO/TODOColumn.tscn").instance()
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
		column.get_node("VBoxContainer/HBoxContainer2/Name").call_deferred("grab_focus")
		column.get_node("VBoxContainer/HBoxContainer2/Name").call_deferred("select_all")
	
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
