extends Control

@export var left_surface: MappedSurface
@export var right_surface: MappedSurface
@export var overlap_width: float = 0.15 # 15% overlap
@export var gamma: float = 2.0

func _ready() -> void:
	_apply_edge_blending()

func _apply_edge_blending() -> void:
	var blend_shader = load("res://addons/openprojmap/shaders/edge_blend.gdshader")

	# Setup left surface overlap on the right edge
	if left_surface:
		var mat = ShaderMaterial.new()
		mat.shader = blend_shader
		mat.set_shader_parameter("blend_margins", Vector4(0.0, 0.0, overlap_width, 0.0))
		mat.set_shader_parameter("blend_gamma", gamma)
		left_surface.material = mat
		left_surface.recalculate_matrices()

	# Setup right surface overlap on the left edge
	if right_surface:
		var mat = ShaderMaterial.new()
		mat.shader = blend_shader
		mat.set_shader_parameter("blend_margins", Vector4(overlap_width, 0.0, 0.0, 0.0))
		mat.set_shader_parameter("blend_gamma", gamma)
		right_surface.material = mat
		right_surface.recalculate_matrices()
