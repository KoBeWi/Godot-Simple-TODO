tool
extends PanelContainer

onready var name_edit = $VBoxContainer/HBoxContainer2/Name
onready var item_container = $VBoxContainer/ScrollContainer/Items
onready var counter = $VBoxContainer/HBoxContainer2/Counter
onready var delete_button = $VBoxContainer/HBoxContainer/DeleteColumn
onready var timer = $Timer

var undo_redo: UndoRedo

signal delete

func _ready() -> void:
	delete_button.icon = get_icon("Remove", "EditorIcons")
	counter.rect_min_size.x = delete_button.get_minimum_size().x

func add_item(from_button := false) -> Control:
	var item = preload("res://addons/SimpleTODO/TODOItem.tscn").instance()
	item.connect("delete", self, "delete_item", [item])
	
	undo_redo.create_action("Add Item")
	undo_redo.add_do_method(item_container, "add_child", item)
	undo_redo.add_do_method(item, "add_child", item)
	undo_redo.add_do_reference(item)
	undo_redo.add_do_method(self, "request_save")
	undo_redo.add_undo_method(item_container, "remove_child", item)
	undo_redo.add_undo_method(self, "request_save")
	undo_redo.commit_action()
	
	if from_button:
		item.get_node("Text").call_deferred("grab_focus")
		item.get_node("Text").call_deferred("select_all")
	
	return item

func delete_item(item):
	undo_redo.create_action("Delete Item")
	undo_redo.add_do_method(item_container, "remove_child", item)
	undo_redo.add_do_method(self, "request_save")
	undo_redo.add_undo_method(item_container, "add_child", item)
	undo_redo.add_undo_reference(item)
	undo_redo.add_undo_method(self, "request_save")
	undo_redo.commit_action()

func delete_column() -> void:
	emit_signal("delete")

func request_save() -> void:
	counter.text = str(item_container.get_child_count())
	get_tree().get_nodes_in_group("__todo_plugin__").front().save_data()

func name_changed(new_text: String) -> void:
	timer.start()
