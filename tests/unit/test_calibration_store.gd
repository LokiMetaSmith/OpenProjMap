extends SceneTree

const CalibrationStoreClass = preload("res://addons/openprojmap/core/calibration_store.gd")
const CalibrationDataClass = preload("res://addons/openprojmap/core/calibration_data.gd")

func _init() -> void:
	print("--- Running test_calibration_store ---")
	test_save_and_load_handles()
	test_save_and_load_calibration_data()
	print("--- All calibration_store tests passed! ---")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("ASSERTION FAILED: ", msg)
		quit(1)

func test_save_and_load_handles() -> void:
	var path = "user://test_handles.json"
	var handles: Array[Vector2] = [
		Vector2(0.1, 0.1),
		Vector2(0.9, 0.15),
		Vector2(0.85, 0.95),
		Vector2(0.05, 0.8)
	]
	var saved = CalibrationStoreClass.save_calibration(path, handles)
	assert_true(saved, "Saving handles should succeed")

	var loaded = CalibrationStoreClass.load_calibration_handles(path)
	assert_true(loaded.size() == 4, "Loaded handles count should be 4")
	for i in range(4):
		assert_true(loaded[i].distance_to(handles[i]) < 1e-5, "Handle %d should match" % i)
	print("✓ test_save_and_load_handles passed")

func test_save_and_load_calibration_data() -> void:
	var path = "user://test_calib_data.json"
	var calib = CalibrationDataClass.new()
	calib.surface_name = "Wall_Projector"
	var h: Array[Vector2] = [
		Vector2(0.02, 0.03),
		Vector2(0.98, 0.04),
		Vector2(0.95, 0.96),
		Vector2(0.01, 0.92)
	]
	calib.handles = h
	calib.edge_blend_margins = Vector4(0.1, 0.0, 0.15, 0.0)

	var saved = CalibrationStoreClass.save_calibration(path, calib)
	assert_true(saved, "Saving calib data should succeed")

	var loaded = CalibrationStoreClass.load_calibration_data(path)
	assert_true(loaded != null, "Loaded calib data should not be null")
	assert_true(loaded.surface_name == "Wall_Projector", "Surface name matches")
	for i in range(4):
		assert_true(loaded.handles[i].distance_to(calib.handles[i]) < 1e-5, "Handle %d matches" % i)
	assert_true(loaded.edge_blend_margins.distance_to(calib.edge_blend_margins) < 1e-5, "Edge margins match")
	print("✓ test_save_and_load_calibration_data passed")
