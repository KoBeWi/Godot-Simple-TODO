@tool
extends HBoxContainer

@onready var drag_panel: Panel = $DragPanel
@onready var name_edit: LineEdit = $Name
@onready var counter: Label = $Counter
@onready var minimize_button: Button = $Minimize

func drag_panel_input(event: InputEvent) -> void:
	pass # Replace with function body.
