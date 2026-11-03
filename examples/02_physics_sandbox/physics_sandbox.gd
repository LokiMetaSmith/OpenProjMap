extends Node2D

@export var ball_count: int = 15
var ball_scene = preload("res://examples/02_physics_sandbox/physics_ball.tscn")

func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(ball_count):
		var ball = ball_scene.instantiate() as RigidBody2D
		ball.position = Vector2(rng.randf_range(200, 1720), rng.randf_range(100, 600))
		add_child(ball)

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		apply_explosion_impulse(event.position, 600.0, 350.0)

func apply_explosion_impulse(epicenter: Vector2, radius: float, force: float) -> void:
	for child in get_children():
		if child is RigidBody2D:
			var diff = child.global_position - epicenter
			var dist = diff.length()
			if dist < radius and dist > 0.1:
				var dir = diff.normalized()
				var factor = 1.0 - (dist / radius)
				child.apply_central_impulse(dir * force * factor)
