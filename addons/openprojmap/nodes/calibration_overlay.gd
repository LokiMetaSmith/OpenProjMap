@tool
class_name CalibrationOverlay
extends Control

@export var mapped_surface: MappedSurface
@export var handle_color: Color = Color.CYAN
@export var line_color: Color = Color.YELLOW
@export var line_width: float = 2.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS

func _process(_delta: float) -> void:
	if mapped_surface and mapped_surface.is_calibrating:
		visible = true
		queue_redraw()
	else:
		visible = false

func _draw() -> void:
	if not mapped_surface or not mapped_surface.is_calibrating:
		return

	var handles = mapped_surface.handles
	if handles.size() < 4:
		return

	var s = size if size.x > 0 and size.y > 0 else get_viewport_rect().size
	var radius = mapped_surface.handle_radius

	for i in range(4):
		var p1 = handles[i] * s
		var p2 = handles[(i + 1) % 4] * s
		draw_line(p1, p2, line_color, line_width, true)

	for i in range(4):
		var p = handles[i] * s
		var is_selected = (mapped_surface.selected_handle_index == i)
		var col = Color.MAGENTA if is_selected else handle_color
		draw_circle(p, radius, col)
		draw_circle(p, max(radius - 3.0, 1.0), Color.BLACK)
