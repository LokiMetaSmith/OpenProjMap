@tool
class_name MappedSurface
extends ColorRect

const HomographyClass = preload("res://addons/openprojmap/core/homography.gd")
const CalibrationStoreClass = preload("res://addons/openprojmap/core/calibration_store.gd")

@export var target_viewport: SubViewport
@export var config_save_path: String = "user://projection_calibration.json"
@export var handle_radius: float = 12.0
@export var auto_recalculate_on_resize: bool = true

var handles: Array[Vector2] = [
	Vector2(0.05, 0.05), # Top-Left
	Vector2(0.95, 0.05), # Top-Right
	Vector2(0.95, 0.95), # Bottom-Right
	Vector2(0.05, 0.95)  # Bottom-Left
]

var inv_h: Array[Vector3] = []
var forward_h: Array[Vector3] = []
var selected_handle_index: int = -1
var is_calibrating: bool = false:
	set(val):
		is_calibrating = val
		queue_redraw()

func _ready() -> void:
	if not material:
		var shader = load("res://addons/openprojmap/shaders/projection_warp.gdshader")
		var sm = ShaderMaterial.new()
		sm.shader = shader
		material = sm

	load_calibration()
	recalculate_matrices()

	if not is_connected("item_rect_changed", Callable(self, "_on_item_rect_changed")):
		item_rect_changed.connect(_on_item_rect_changed)

func _on_item_rect_changed() -> void:
	if auto_recalculate_on_resize:
		recalculate_matrices()

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

func recalculate_matrices() -> void:
	forward_h = HomographyClass.get_unit_to_quad_matrix(handles)
	inv_h = HomographyClass.invert_matrix_3x3(forward_h)

	var proj := HomographyClass.to_projection(inv_h)

	var mat = material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("inv_homography", proj)
		if target_viewport:
			mat.set_shader_parameter("source_texture", target_viewport.get_texture())
	queue_redraw()

func _process_calibration_input(event: InputEvent) -> void:
	var vp_size: Vector2 = size if size.x > 0 and size.y > 0 else get_viewport_rect().size
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_uv: Vector2 = event.position / vp_size
			selected_handle_index = -1
			for i in range(handles.size()):
				if handles[i].distance_to(mouse_uv) < (handle_radius / vp_size.y):
					selected_handle_index = i
					break
		else:
			selected_handle_index = -1
		accept_event()

	elif event is InputEventMouseMotion and selected_handle_index != -1:
		handles[selected_handle_index] = (event.position / vp_size).clamp(Vector2.ZERO, Vector2.ONE)
		recalculate_matrices()
		accept_event()

func _process_gameplay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_forward_interactive_input(event)

func _forward_interactive_input(event: InputEvent) -> void:
	if not target_viewport or inv_h.is_empty():
		return

	var vp_size: Vector2 = size if size.x > 0 and size.y > 0 else get_viewport_rect().size
	var screen_uv: Vector2 = event.position / vp_size
	var game_uv: Vector2 = HomographyClass.transform_point(inv_h, screen_uv)

	if Rect2(0, 0, 1, 1).has_point(game_uv):
		var internal_pos: Vector2 = game_uv * Vector2(target_viewport.size)
		var cloned: InputEvent = event.duplicate()
		if cloned is InputEventMouse:
			cloned.position = internal_pos
			cloned.global_position = internal_pos
		target_viewport.push_input(cloned)
		accept_event()

func inject_normalized_point(uv: Vector2, is_pressed: bool) -> void:
	if not target_viewport or inv_h.is_empty():
		return
	var game_uv: Vector2 = HomographyClass.transform_point(inv_h, uv)
	if Rect2(0, 0, 1, 1).has_point(game_uv):
		var target_pos: Vector2 = game_uv * Vector2(target_viewport.size)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = is_pressed
		ev.position = target_pos
		ev.global_position = target_pos
		target_viewport.push_input(ev)

func save_calibration() -> void:
	CalibrationStoreClass.save_calibration(config_save_path, handles)

func load_calibration() -> void:
	var loaded = CalibrationStoreClass.load_calibration_handles(config_save_path)
	if loaded.size() == 4:
		handles = loaded

func _draw() -> void:
	if not is_calibrating:
		return
	var vp_size: Vector2 = size if size.x > 0 and size.y > 0 else get_viewport_rect().size
	for i in range(4):
		var p1: Vector2 = handles[i] * vp_size
		var p2: Vector2 = handles[(i + 1) % 4] * vp_size
		draw_line(p1, p2, Color.YELLOW, 2.0, true)
		draw_circle(p1, handle_radius, Color.CYAN)
		draw_circle(p1, handle_radius - 3.0, Color.BLACK)
