class_name CalibrationData
extends Resource

@export var surface_name: String = "Surface_0"
@export var handles: Array[Vector2] = [
	Vector2(0.05, 0.05), # Top-Left
	Vector2(0.95, 0.05), # Top-Right
	Vector2(0.95, 0.95), # Bottom-Right
	Vector2(0.05, 0.95)  # Bottom-Left
]
@export var edge_blend_margins: Vector4 = Vector4(0.0, 0.0, 0.0, 0.0) # Left, Top, Right, Bottom

func to_dict() -> Dictionary:
	var h_arr: Array = []
	for p in handles:
		h_arr.append({"x": p.x, "y": p.y})
	return {
		"surface_name": surface_name,
		"handles": h_arr,
		"edge_blend_margins": {
			"left": edge_blend_margins.x,
			"top": edge_blend_margins.y,
			"right": edge_blend_margins.z,
			"bottom": edge_blend_margins.w
		}
	}

func from_dict(data: Dictionary) -> void:
	if data.has("surface_name"):
		surface_name = str(data["surface_name"])
	if data.has("handles") and data["handles"] is Array:
		var arr: Array = data["handles"]
		if arr.size() == 4:
			var new_handles: Array[Vector2] = [
				Vector2(arr[0].get("x", 0.05), arr[0].get("y", 0.05)),
				Vector2(arr[1].get("x", 0.95), arr[1].get("y", 0.05)),
				Vector2(arr[2].get("x", 0.95), arr[2].get("y", 0.95)),
				Vector2(arr[3].get("x", 0.05), arr[3].get("y", 0.95))
			]
			handles = new_handles
	if data.has("edge_blend_margins") and data["edge_blend_margins"] is Dictionary:
		var m = data["edge_blend_margins"]
		edge_blend_margins = Vector4(
			float(m.get("left", 0.0)),
			float(m.get("top", 0.0)),
			float(m.get("right", 0.0)),
			float(m.get("bottom", 0.0))
		)
