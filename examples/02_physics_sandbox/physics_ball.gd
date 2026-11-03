extends RigidBody2D

@export var radius: float = 30.0
@export var ball_color: Color = Color.ORANGE

func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	ball_color = Color.from_hsv(rng.randf(), 0.8, 0.95)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.25, Color(1, 1, 1, 0.6))
