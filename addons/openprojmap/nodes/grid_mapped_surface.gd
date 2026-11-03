@tool
class_name GridMappedSurface
extends Control

@export var target_viewport: SubViewport
@export var grid_rows: int = 4:
	set(val):
		grid_rows = max(2, val)
		_init_grid_points()
		rebuild_mesh()
@export var grid_cols: int = 4:
	set(val):
		grid_cols = max(2, val)
		_init_grid_points()
		rebuild_mesh()

@export var config_save_path: String = "user://grid_calibration.json"
@export var handle_radius: float = 10.0

# Normalized control points (row * grid_cols + col)
var control_points: Array[Vector2] = []
var selected_handle_index: int = -1
var is_calibrating: bool = false:
	set(val):
		is_calibrating = val
		queue_redraw()

var mesh_instance: MeshInstance2D

func _ready() -> void:
	if control_points.size() != grid_rows * grid_cols:
		_init_grid_points()

	if not mesh_instance:
		mesh_instance = MeshInstance2D.new()
		add_child(mesh_instance)

	load_calibration()
	rebuild_mesh()

func _init_grid_points() -> void:
	control_points.clear()
	for r in range(grid_rows):
		for c in range(grid_cols):
			var u = float(c) / float(grid_cols - 1)
			var v = float(r) / float(grid_rows - 1)
			control_points.append(Vector2(u, v))

func rebuild_mesh() -> void:
	if control_points.size() != grid_rows * grid_cols:
		return

	var s = size
	if s.x <= 0 or s.y <= 0:
		s = get_viewport_rect().size if is_inside_tree() else Vector2(1920, 1080)
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for r in range(grid_rows):
		for c in range(grid_cols):
			var idx = r * grid_cols + c
			var pt = control_points[idx]
			vertices.append(pt * s)
			var canonical_u = float(c) / float(grid_cols - 1)
			var canonical_v = float(r) / float(grid_rows - 1)
			uvs.append(Vector2(canonical_u, canonical_v))

	for r in range(grid_rows - 1):
		for c in range(grid_cols - 1):
			var i0 = r * grid_cols + c
			var i1 = r * grid_cols + (c + 1)
			var i2 = (r + 1) * grid_cols + (c + 1)
			var i3 = (r + 1) * grid_cols + c

			# Triangle 1
			indices.append(i0)
			indices.append(i1)
			indices.append(i2)

			# Triangle 2
			indices.append(i0)
			indices.append(i2)
			indices.append(i3)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if not mesh_instance:
		mesh_instance = MeshInstance2D.new()
		add_child(mesh_instance)
	mesh_instance.mesh = arr_mesh

	if target_viewport:
		mesh_instance.texture = target_viewport.get_texture()

	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			is_calibrating = !is_calibrating
			accept_event()
			return
		elif event.keycode == KEY_S and event.ctrl_pressed:
			save_calibration()
			accept_event()
			return

	if is_calibrating:
		_process_calibration_input(event)
	else:
		_process_gameplay_input(event)

func _process_calibration_input(event: InputEvent) -> void:
	var s: Vector2 = size if size.x > 0 and size.y > 0 else get_viewport_rect().size
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_uv = event.position / s
			selected_handle_index = -1
			for i in range(control_points.size()):
				if control_points[i].distance_to(mouse_uv) < (handle_radius / s.y):
					selected_handle_index = i
					break
		else:
			selected_handle_index = -1
		accept_event()

	elif event is InputEventMouseMotion and selected_handle_index != -1:
		control_points[selected_handle_index] = (event.position / s).clamp(Vector2.ZERO, Vector2.ONE)
		rebuild_mesh()
		accept_event()

func _process_gameplay_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and target_viewport:
		var s: Vector2 = size if size.x > 0 and size.y > 0 else get_viewport_rect().size
		var screen_uv = event.position / s
		var game_uv = map_screen_uv_to_game_uv(screen_uv)
		if Rect2(0, 0, 1, 1).has_point(game_uv):
			var target_pos = game_uv * Vector2(target_viewport.size)
			var cloned = event.duplicate()
			if cloned is InputEventMouse:
				cloned.position = target_pos
				cloned.global_position = target_pos
			target_viewport.push_input(cloned)
			accept_event()

func map_screen_uv_to_game_uv(uv: Vector2) -> Vector2:
	# Approximate inverse bilinear cell mapping across grid
	for r in range(grid_rows - 1):
		for c in range(grid_cols - 1):
			var p0 = control_points[r * grid_cols + c]
			var p1 = control_points[r * grid_cols + (c + 1)]
			var p2 = control_points[(r + 1) * grid_cols + (c + 1)]
			var p3 = control_points[(r + 1) * grid_cols + c]

			# Check if uv is within cell bounding box
			var min_x = min(p0.x, min(p1.x, min(p2.x, p3.x)))
			var max_x = max(p0.x, max(p1.x, max(p2.x, p3.x)))
			var min_y = min(p0.y, min(p1.y, min(p2.y, p3.y)))
			var max_y = max(p0.y, max(p1.y, max(p2.y, p3.y)))

			if uv.x >= min_x and uv.x <= max_x and uv.y >= min_y and uv.y <= max_y:
				var cell_u = clamp((uv.x - min_x) / max(max_x - min_x, 1e-5), 0.0, 1.0)
				var cell_v = clamp((uv.y - min_y) / max(max_y - min_y, 1e-5), 0.0, 1.0)
				var u_norm = (float(c) + cell_u) / float(grid_cols - 1)
				var v_norm = (float(r) + cell_v) / float(grid_rows - 1)
				return Vector2(u_norm, v_norm)

	return uv

func inject_touch_point(touch_id: int, uv: Vector2, is_pressed: bool) -> void:
	if not target_viewport:
		return
	var game_uv = map_screen_uv_to_game_uv(uv)
	if Rect2(0, 0, 1, 1).has_point(game_uv):
		var target_pos = game_uv * Vector2(target_viewport.size)
		var touch_ev = InputEventScreenTouch.new()
		touch_ev.index = touch_id
		touch_ev.pressed = is_pressed
		touch_ev.position = target_pos
		target_viewport.push_input(touch_ev)

		if touch_id == 0:
			var mouse_ev = InputEventMouseButton.new()
			mouse_ev.button_index = MOUSE_BUTTON_LEFT
			mouse_ev.pressed = is_pressed
			mouse_ev.position = target_pos
			mouse_ev.global_position = target_pos
			target_viewport.push_input(mouse_ev)

func inject_normalized_point(uv: Vector2, is_pressed: bool) -> void:
	inject_touch_point(0, uv, is_pressed)

func save_calibration() -> void:
	var raw_points: Array = []
	for p in control_points:
		raw_points.append({"x": p.x, "y": p.y})
	var dict = {
		"grid_rows": grid_rows,
		"grid_cols": grid_cols,
		"control_points": raw_points
	}
	var file = FileAccess.open(config_save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(dict, "\t"))
		file.close()

func load_calibration() -> void:
	if not FileAccess.file_exists(config_save_path):
		return
	var file = FileAccess.open(config_save_path, FileAccess.READ)
	if not file:
		return
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var d = json.data
		grid_rows = d.get("grid_rows", grid_rows)
		grid_cols = d.get("grid_cols", grid_cols)
		if d.has("control_points") and d["control_points"] is Array:
			var pts: Array[Vector2] = []
			for item in d["control_points"]:
				pts.append(Vector2(float(item["x"]), float(item["y"])))
			if pts.size() == grid_rows * grid_cols:
				control_points = pts

func _draw() -> void:
	if not is_calibrating:
		return
	var s: Vector2 = size if size.x > 0 and size.y > 0 else get_viewport_rect().size

	# Draw grid lines
	for r in range(grid_rows):
		for c in range(grid_cols):
			var p = control_points[r * grid_cols + c] * s
			if c + 1 < grid_cols:
				var p_right = control_points[r * grid_cols + (c + 1)] * s
				draw_line(p, p_right, Color(1, 1, 0, 0.6), 1.5)
			if r + 1 < grid_rows:
				var p_down = control_points[(r + 1) * grid_cols + c] * s
				draw_line(p, p_down, Color(1, 1, 0, 0.6), 1.5)

	# Draw control handles
	for i in range(control_points.size()):
		var p = control_points[i] * s
		var col = Color.MAGENTA if selected_handle_index == i else Color.CYAN
		draw_circle(p, handle_radius, col)
		draw_circle(p, max(handle_radius - 2.0, 1.0), Color.BLACK)
