tool
extends HBoxContainer

onready var text_field = $Text
onready var label_hack = $Text/HackLabel

signal delete

func _ready() -> void:
	get_node("Button").icon = get_icon("Remove", "EditorIcons")
	call_deferred("text_changed")

func delete_pressed() -> void:
	emit_signal("delete")

func request_save() -> void:
	get_tree().get_nodes_in_group("__todo_plugin__").front().save_data()

func text_changed() -> void:
	label_hack.text = text_field.text
	text_field.rect_min_size.y = label_hack.get_minimum_size().y + 8
