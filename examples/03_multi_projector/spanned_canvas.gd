extends Node2D

var elapsed: float = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	# Spanned canvas: 3840 x 1080
	draw_rect(Rect2(0, 0, 3840, 1080), Color(0.05, 0.07, 0.1), true)

	# Grid lines across entire spanned canvas
	for x in range(0, 3840, 120):
		var col = Color(0.2, 0.4, 0.8, 0.4) if (x % 480 == 0) else Color(0.15, 0.2, 0.3, 0.3)
		draw_line(Vector2(x, 0), Vector2(x, 1080), col, 2.0)

	for y in range(0, 1080, 120):
		draw_line(Vector2(0, y), Vector2(3840, y), Color(0.15, 0.2, 0.3, 0.3), 2.0)

	# Seam indicator (Projector 1 & 2 overlap zone at center: 1720..2120)
	draw_rect(Rect2(1720, 0, 400, 1080), Color(0.8, 0.8, 0.1, 0.08), true)
	draw_line(Vector2(1920, 0), Vector2(1920, 1080), Color(1, 1, 0, 0.5), 3.0)

	# Moving panoramic shapes crossing the overlap seam
	var cx = fmod(elapsed * 200.0, 3840.0)
	draw_circle(Vector2(cx, 540.0), 120.0, Color(0.9, 0.3, 0.2, 0.9))
	draw_circle(Vector2(fmod(cx + 1200.0, 3840.0), 300.0), 80.0, Color(0.2, 0.8, 0.5, 0.9))
	draw_circle(Vector2(fmod(cx + 2400.0, 3840.0), 780.0), 100.0, Color(0.3, 0.5, 0.9, 0.9))
