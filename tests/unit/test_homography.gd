extends SceneTree

const HomographyClass = preload("res://addons/openprojmap/core/homography.gd")

func _init() -> void:
	print("--- Running test_homography ---")
	test_identity_transform()
	test_trapezoid_transform()
	test_singular_matrix()
	test_extreme_aspect_ratios()
	print("--- All homography tests passed! ---")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("ASSERTION FAILED: ", msg)
		quit(1)

func assert_approx_equal_v2(a: Vector2, b: Vector2, eps: float = 1e-4, msg: String = "") -> void:
	if a.distance_to(b) > eps:
		printerr("ASSERTION FAILED: expected %s, got %s (diff %f) - %s" % [str(b), str(a), a.distance_to(b), msg])
		quit(1)

func test_identity_transform() -> void:
	var unit_quad: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(1, 1),
		Vector2(0, 1)
	]
	var m = HomographyClass.get_unit_to_quad_matrix(unit_quad)
	for p in unit_quad:
		var mapped = HomographyClass.transform_point(m, p)
		assert_approx_equal_v2(mapped, p, 1e-5, "Unit square mapping identity")

	var inv = HomographyClass.invert_matrix_3x3(m)
	for p in unit_quad:
		var inv_p = HomographyClass.transform_point(inv, p)
		assert_approx_equal_v2(inv_p, p, 1e-5, "Inverse unit square identity")
	print("✓ test_identity_transform passed")

func test_trapezoid_transform() -> void:
	# Keystone / trapezoid quad
	var quad: Array[Vector2] = [
		Vector2(0.2, 0.1),
		Vector2(0.8, 0.1),
		Vector2(0.9, 0.9),
		Vector2(0.1, 0.9)
	]
	var unit_quad: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(1, 1),
		Vector2(0, 1)
	]
	var forward = HomographyClass.get_unit_to_quad_matrix(quad)
	var inv = HomographyClass.invert_matrix_3x3(forward)

	for i in range(4):
		var target = HomographyClass.transform_point(forward, unit_quad[i])
		assert_approx_equal_v2(target, quad[i], 1e-4, "Trapezoid forward corner %d" % i)
		var back = HomographyClass.transform_point(inv, target)
		assert_approx_equal_v2(back, unit_quad[i], 1e-4, "Trapezoid inverse corner %d" % i)

	# Test center point (0.5, 0.5)
	var center_uv = Vector2(0.5, 0.5)
	var screen_center = HomographyClass.transform_point(forward, center_uv)
	var roundtrip = HomographyClass.transform_point(inv, screen_center)
	assert_approx_equal_v2(roundtrip, center_uv, 1e-4, "Trapezoid center roundtrip")
	print("✓ test_trapezoid_transform passed")

func test_singular_matrix() -> void:
	var col_matrix: Array[Vector3] = [
		Vector3(1, 2, 3),
		Vector3(2, 4, 6), # row 2 is 2 * row 1
		Vector3(0, 0, 1)
	]
	var inv = HomographyClass.invert_matrix_3x3(col_matrix)
	assert_true(inv[0] == Vector3.ZERO and inv[1] == Vector3.ZERO and inv[2] == Vector3.ZERO, "Singular matrix handling")
	print("✓ test_singular_matrix passed")

func test_extreme_aspect_ratios() -> void:
	var quad: Array[Vector2] = [
		Vector2(0.4, 0.05),
		Vector2(0.6, 0.05),
		Vector2(1.0, 0.95),
		Vector2(0.0, 0.95)
	]
	var forward = HomographyClass.get_unit_to_quad_matrix(quad)
	var inv = HomographyClass.invert_matrix_3x3(forward)

	for p in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0.5, 0.5), Vector2(0.25, 0.75)]:
		var screen = HomographyClass.transform_point(forward, p)
		var recovered = HomographyClass.transform_point(inv, screen)
		assert_approx_equal_v2(recovered, p, 1e-4, "Extreme aspect roundtrip %s" % str(p))
	print("✓ test_extreme_aspect_ratios passed")
