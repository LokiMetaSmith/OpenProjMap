class_name Homography
extends RefCounted

## Computes a 3x3 homography matrix mapping unit square (0..1) to 4 arbitrary quad points.
## Points must be provided in order: [Top-Left, Top-Right, Bottom-Right, Bottom-Left].
static func get_unit_to_quad_matrix(p: Array[Vector2]) -> Array[Vector3]:
	assert(p.size() == 4, "Homography requires exactly 4 points.")

	var x0: float = p[0].x; var y0: float = p[0].y
	var x1: float = p[1].x; var y1: float = p[1].y
	var x2: float = p[2].x; var y2: float = p[2].y
	var x3: float = p[3].x; var y3: float = p[3].y

	var dx1: float = x1 - x2
	var dy1: float = y1 - y2
	var dx2: float = x3 - x2
	var dy2: float = y3 - y2
	var sx: float = x0 - x1 + x2 - x3
	var sy: float = y0 - y1 + y2 - y3

	var g: float = 0.0
	var h: float = 0.0

	var det: float = dx1 * dy2 - dx2 * dy1
	if abs(det) > 1e-7:
		g = (sx * dy2 - sy * dx2) / det
		h = (dx1 * sy - dy1 * sx) / det

	var a: float = x1 - x0 + g * x1
	var b: float = x3 - x0 + h * x3
	var c: float = x0
	var d: float = y1 - y0 + g * y1
	var e: float = y3 - y0 + h * y3
	var f: float = y0

	return [
		Vector3(a, b, c),
		Vector3(d, e, f),
		Vector3(g, h, 1.0)
	]

## Computes the analytical inverse of a row-major 3x3 matrix.
static func invert_matrix_3x3(m: Array[Vector3]) -> Array[Vector3]:
	if m.size() != 3:
		push_error("Homography invert expects 3 rows.")
		return [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]

	var a: float = m[0].x; var b: float = m[0].y; var c: float = m[0].z
	var d: float = m[1].x; var e: float = m[1].y; var f: float = m[1].z
	var g: float = m[2].x; var h: float = m[2].y; var k: float = m[2].z

	var det: float = a * (e * k - f * h) - b * (d * k - f * g) + c * (d * h - e * g)
	if abs(det) < 1e-9:
		push_error("Degenerate quad points: Homography matrix is non-invertible.")
		return [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]

	var inv_det: float = 1.0 / det
	return [
		Vector3((e * k - f * h) * inv_det, (c * h - b * k) * inv_det, (b * f - c * e) * inv_det),
		Vector3((f * g - d * k) * inv_det, (a * k - c * g) * inv_det, (c * d - a * f) * inv_det),
		Vector3((d * h - e * g) * inv_det, (b * g - a * h) * inv_det, (a * e - b * d) * inv_det)
	]

## Multiplies two 3x3 row-major matrices: result = A * B.
static func multiply_matrices_3x3(a: Array[Vector3], b: Array[Vector3]) -> Array[Vector3]:
	var r: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	for row in range(3):
		var row_vec = a[row]
		var rx: float = row_vec.x * b[0].x + row_vec.y * b[1].x + row_vec.z * b[2].x
		var ry: float = row_vec.x * b[0].y + row_vec.y * b[1].y + row_vec.z * b[2].y
		var rz: float = row_vec.x * b[0].z + row_vec.y * b[1].z + row_vec.z * b[2].z
		r[row] = Vector3(rx, ry, rz)
	return r

## Derives 3x3 homography matrix mapping arbitrary quad A to arbitrary quad B.
static func get_quad_to_quad_matrix(src: Array[Vector2], dst: Array[Vector2]) -> Array[Vector3]:
	var u_to_src: Array[Vector3] = get_unit_to_quad_matrix(src)
	var src_to_u: Array[Vector3] = invert_matrix_3x3(u_to_src)
	var u_to_dst: Array[Vector3] = get_unit_to_quad_matrix(dst)
	return multiply_matrices_3x3(u_to_dst, src_to_u)

## Transforms a 2D coordinate through a 3x3 homography matrix with perspective division.
static func transform_point(m: Array[Vector3], p: Vector2) -> Vector2:
	if m.size() != 3:
		return Vector2.ZERO
	var x: float = m[0].x * p.x + m[0].y * p.y + m[0].z
	var y: float = m[1].x * p.x + m[1].y * p.y + m[1].z
	var w: float = m[2].x * p.x + m[2].y * p.y + m[2].z
	if abs(w) > 1e-7:
		return Vector2(x / w, y / w)
	return Vector2.ZERO

## Packs a 3x3 row-major homography matrix into a Godot Projection (mat4)
static func to_projection(m: Array[Vector3]) -> Projection:
	if m.size() != 3:
		return Projection.IDENTITY
	return Projection(
		Vector4(m[0].x, m[0].y, m[0].z, 0.0),
		Vector4(m[1].x, m[1].y, m[1].z, 0.0),
		Vector4(m[2].x, m[2].y, m[2].z, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0)
	)
