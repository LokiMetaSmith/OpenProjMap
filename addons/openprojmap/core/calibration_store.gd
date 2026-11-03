class_name CalibrationStore
extends RefCounted

const CalibrationDataClass = preload("res://addons/openprojmap/core/calibration_data.gd")

## Saves CalibrationData or handle arrays to a JSON file.
static func save_calibration(path: String, handles_or_data) -> bool:
	var payload
	if handles_or_data is CalibrationDataClass:
		payload = handles_or_data.to_dict()
	elif handles_or_data is Array:
		var raw_points: Array = []
		for p in handles_or_data:
			raw_points.append({"x": p.x, "y": p.y})
		payload = raw_points
	elif handles_or_data is Dictionary:
		payload = handles_or_data
	else:
		push_error("Unsupported data format for save_calibration")
		return false

	var dir_path: String = path.get_base_dir()
	if not dir_path.is_empty() and not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: %s (Error: %d)" % [path, FileAccess.get_open_error()])
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

## Loads calibration from a JSON file, returning an Array of Vector2 handles or empty Array on error.
static func load_calibration_handles(path: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not FileAccess.file_exists(path):
		return result

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return result

	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return result

	if json.data is Array:
		var arr: Array = json.data
		if arr.size() == 4:
			for item in arr:
				result.append(Vector2(float(item["x"]), float(item["y"])))
	elif json.data is Dictionary:
		var dict: Dictionary = json.data
		if dict.has("handles") and dict["handles"] is Array and dict["handles"].size() == 4:
			for item in dict["handles"]:
				result.append(Vector2(float(item["x"]), float(item["y"])))

	return result

## Loads calibration as a CalibrationData resource.
static func load_calibration_data(path: String) -> Resource:
	if not FileAccess.file_exists(path):
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null

	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return null

	var calib = CalibrationDataClass.new()
	if json.data is Dictionary:
		calib.from_dict(json.data)
		return calib
	elif json.data is Array and json.data.size() == 4:
		var arr: Array = json.data
		var new_handles: Array[Vector2] = [
			Vector2(arr[0]["x"], arr[0]["y"]),
			Vector2(arr[1]["x"], arr[1]["y"]),
			Vector2(arr[2]["x"], arr[2]["y"]),
			Vector2(arr[3]["x"], arr[3]["y"])
		]
		calib.handles = new_handles
		return calib

	return null
