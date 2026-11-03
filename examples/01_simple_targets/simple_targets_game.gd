extends Node2D

var score: int = 0
@onready var score_label: Label = $ScoreLabel
@onready var target: Area2D = $Target
@onready var target_shape: CollisionShape2D = $Target/CollisionShape2D

var screen_size: Vector2 = Vector2(1920, 1080)
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_update_score_ui()
	_spawn_target()
	target.input_event.connect(_on_target_input_event)

func _spawn_target() -> void:
	var margin: float = 120.0
	var new_x = rng.randf_range(margin, screen_size.x - margin)
	var new_y = rng.randf_range(margin, screen_size.y - margin)
	target.position = Vector2(new_x, new_y)

func _update_score_ui() -> void:
	if score_label:
		score_label.text = "SCORE: %d" % score

func _on_target_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		score += 10
		_update_score_ui()
		_spawn_target()
