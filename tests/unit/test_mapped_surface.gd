extends SceneTree

const MappedSurfaceClass = preload("res://addons/openprojmap/nodes/mapped_surface.gd")

func _init() -> void:
	print("--- Running test_mapped_surface ---")
	test_mapped_surface_logic()
	print("--- All mapped_surface tests passed! ---")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("ASSERTION FAILED: ", msg)
		quit(1)

func test_mapped_surface_logic() -> void:
	var surface = MappedSurfaceClass.new()
	surface.size = Vector2(1000, 1000)
	var h: Array[Vector2] = [
		Vector2(0.1, 0.1),
		Vector2(0.9, 0.1),
		Vector2(0.9, 0.9),
		Vector2(0.1, 0.9)
	]
	surface.handles = h
	surface.recalculate_matrices()

	assert_true(surface.forward_h.size() == 3, "Forward H matrix computed")
	assert_true(surface.inv_h.size() == 3, "Inverse H matrix computed")

	# Test Tab key input toggling calibration
	var key_tab = InputEventKey.new()
	key_tab.keycode = KEY_TAB
	key_tab.pressed = true
	assert_true(not surface.is_calibrating, "Initial is_calibrating should be false")
	surface._input(key_tab)
	assert_true(surface.is_calibrating, "TAB should toggle is_calibrating to true")

	# Test corner handle dragging
	var click_handle = InputEventMouseButton.new()
	click_handle.button_index = MOUSE_BUTTON_LEFT
	click_handle.pressed = true
	click_handle.position = Vector2(100, 100) # (0.1, 0.1) * 1000
	surface._input(click_handle)
	assert_true(surface.selected_handle_index == 0, "Selected handle index should be 0")

	var drag_motion = InputEventMouseMotion.new()
	drag_motion.position = Vector2(120, 110)
	surface._input(drag_motion)
	assert_true(surface.handles[0].distance_to(Vector2(0.12, 0.11)) < 1e-4, "Handle 0 moved correctly")

	var release_click = InputEventMouseButton.new()
	release_click.button_index = MOUSE_BUTTON_LEFT
	release_click.pressed = false
	release_click.position = Vector2(120, 110)
	surface._input(release_click)
	assert_true(surface.selected_handle_index == -1, "Handle deselected on release")

	surface.free()
	print("✓ test_mapped_surface_logic passed")
