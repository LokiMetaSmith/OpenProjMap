extends SceneTree

const GridMappedSurfaceClass = preload("res://addons/openprojmap/nodes/grid_mapped_surface.gd")

func _init() -> void:
	print("--- Running test_grid_mapped_surface ---")
	test_grid_initialization_and_mesh()
	test_grid_serialization()
	print("--- All grid_mapped_surface tests passed! ---")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("ASSERTION FAILED: ", msg)
		quit(1)

func test_grid_initialization_and_mesh() -> void:
	var surface = GridMappedSurfaceClass.new()
	surface.grid_rows = 3
	surface.grid_cols = 3
	surface.size = Vector2(900, 900)
	surface._ready()

	assert_true(surface.control_points.size() == 9, "Grid has 9 control points")
	assert_true(surface.control_points[0] == Vector2(0, 0), "Corner 0,0 correct")
	assert_true(surface.control_points[4] == Vector2(0.5, 0.5), "Center 0.5,0.5 correct")
	assert_true(surface.control_points[8] == Vector2(1, 1), "Corner 1,1 correct")

	# Deform center handle
	surface.control_points[4] = Vector2(0.55, 0.52)
	surface.rebuild_mesh()
	assert_true(surface.mesh_instance != null, "MeshInstance exists")
	assert_true(surface.mesh_instance.mesh != null, "ArrayMesh generated")

	surface.free()
	print("✓ test_grid_initialization_and_mesh passed")

func test_grid_serialization() -> void:
	var path = "user://test_grid_calib.json"
	var surface = GridMappedSurfaceClass.new()
	surface.grid_rows = 2
	surface.grid_cols = 2
	surface.config_save_path = path
	surface._ready()

	surface.control_points[0] = Vector2(0.05, 0.08)
	surface.save_calibration()

	var loader = GridMappedSurfaceClass.new()
	loader.grid_rows = 2
	loader.grid_cols = 2
	loader.config_save_path = path
	loader._ready()

	assert_true(loader.control_points[0].distance_to(Vector2(0.05, 0.08)) < 1e-4, "Serialized grid loaded accurately")

	surface.free()
	loader.free()
	print("✓ test_grid_serialization passed")
