extends SceneTree

const MappedSurfaceClass = preload("res://addons/openprojmap/nodes/mapped_surface.gd")

func _init() -> void:
	print("--- Running test_stress_4k ---")
	call_deferred("_run_stress_benchmark")

func _run_stress_benchmark() -> void:
	# 4K Display Resolution: 3840 x 2160
	var surface = MappedSurfaceClass.new()
	surface.size = Vector2(3840, 2160)
	var quad: Array[Vector2] = [
		Vector2(0.05, 0.08),
		Vector2(0.92, 0.04),
		Vector2(0.88, 0.96),
		Vector2(0.08, 0.91)
	]
	surface.handles = quad
	root.add_child(surface)
	surface.recalculate_matrices()

	var iterations = 100000
	var start_time = Time.get_ticks_usec()
	for i in range(iterations):
		var p = Vector2(float(i % 1000) / 1000.0, float((i * 7) % 1000) / 1000.0)
		var _res = surface.HomographyClass.transform_point(surface.inv_h, p)
	var elapsed_ms = (Time.get_ticks_usec() - start_time) / 1000.0

	print("✓ 4K benchmark: %d point transforms completed in %.2f ms (%.3f µs/op)" % [iterations, elapsed_ms, (elapsed_ms * 1000.0) / iterations])
	assert(elapsed_ms < 500.0, "Benchmark took too long!")
	print("✓ test_stress_4k passed successfully!")
	quit(0)
