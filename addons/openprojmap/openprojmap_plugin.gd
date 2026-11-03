@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("MappedSurface", "ColorRect", preload("nodes/mapped_surface.gd"), null)
	add_custom_type("OSCInputReceiver", "Node", preload("nodes/osc_input_receiver.gd"), null)
	add_custom_type("CalibrationOverlay", "Control", preload("nodes/calibration_overlay.gd"), null)

func _exit_tree() -> void:
	remove_custom_type("MappedSurface")
	remove_custom_type("OSCInputReceiver")
	remove_custom_type("CalibrationOverlay")
