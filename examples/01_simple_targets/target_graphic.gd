extends Node2D

func _draw() -> void:
	# Draw concentric target rings
	draw_circle(Vector2.ZERO, 70.0, Color.RED)
	draw_circle(Vector2.ZERO, 50.0, Color.WHITE)
	draw_circle(Vector2.ZERO, 30.0, Color.RED)
	draw_circle(Vector2.ZERO, 10.0, Color.YELLOW)
