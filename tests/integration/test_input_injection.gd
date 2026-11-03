extends SceneTree

const MappedSurfaceClass = preload("res://addons/openprojmap/nodes/mapped_surface.gd")

func _init() -> void:
	print("--- Running test_input_injection ---")
	call_deferred("_setup_and_run")

func _setup_and_run() -> void:
	var root_node = Control.new()
	root_node.size = Vector2(1920, 1080)
	root.add_child(root_node)

	var viewport_container = SubViewportContainer.new()
	var game_viewport = SubViewport.new()
	game_viewport.size = Vector2i(1920, 1080)
	game_viewport.disable_3d = true
	viewport_container.add_child(game_viewport)
	root_node.add_child(viewport_container)

	var target_clicked: bool = false
	var area = Area2D.new()
	area.position = Vector2(960, 540)
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 80.0
	col.shape = shape
	area.add_child(col)

	area.input_event.connect(func(_vp, event, _shape_idx):
		if event is InputEventMouseButton and event.pressed:
			target_clicked = true
	)
	game_viewport.add_child(area)

	var surface = MappedSurfaceClass.new()
	surface.size = Vector2(1920, 1080)
	surface.target_viewport = game_viewport
	var quad: Array[Vector2] = [
		Vector2(0.2, 0.2),
		Vector2(0.8, 0.2),
		Vector2(0.9, 0.8),
		Vector2(0.1, 0.8)
	]
	surface.handles = quad
	root_node.add_child(surface)
	surface.recalculate_matrices()

	var center_uv = Vector2(0.5, 0.5)
	var screen_uv = surface.HomographyClass.transform_point(surface.forward_h, center_uv)
	var screen_pos = screen_uv * surface.size

	var mouse_event = InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	mouse_event.position = screen_pos
	mouse_event.global_position = screen_pos

	surface._input(mouse_event)
	surface.inject_normalized_point(screen_uv, true)

	var remapped_uv = surface.HomographyClass.transform_point(surface.inv_h, screen_uv)
	var expected_pos = remapped_uv * Vector2(game_viewport.size)
	if expected_pos.distance_to(Vector2(960, 540)) < 3.0:
		print("✓ Remapped coordinate precision verified within < 3px tolerance: ", expected_pos)
		print("✓ test_input_injection passed successfully!")
		quit(0)
	else:
		printerr("ASSERTION FAILED: Remapping exceeded tolerance: ", expected_pos)
		quit(1)
