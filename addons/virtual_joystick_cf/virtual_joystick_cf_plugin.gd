@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type(
			"VirtualJoystickCF",
			"Control",
			preload("res://addons/virtual_joystick_cf/virtual_joystick_cf.gd"),
			preload("res://addons/virtual_joystick_cf/virtual_joystick_cf_icon.svg")
	)


func _exit_tree() -> void:
	remove_custom_type("VirtualJoystickCF")
