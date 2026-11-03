# OpenProjMap API Reference

## 1. Core GDScript Classes

### `Homography` (`RefCounted`)
Located at `addons/openprojmap/core/homography.gd`.

- `static func get_unit_to_quad_matrix(p: Array[Vector2]) -> Array[Vector3]`
  Computes the 3x3 projective homography mapping the unit square `[ (0,0), (1,0), (1,1), (0,1) ]` to 4 arbitrary quadrilateral points.
- `static func invert_matrix_3x3(m: Array[Vector3]) -> Array[Vector3]`
  Computes the analytical adjoint/Gaussian inverse of a row-major 3x3 matrix.
- `static func transform_point(m: Array[Vector3], p: Vector2) -> Vector2`
  Transforms a 2D coordinate through a 3x3 homography matrix with perspective division `(x/w, y/w)`.
- `static func to_projection(m: Array[Vector3]) -> Projection`
  Packs a row-major 3x3 homography matrix into a Godot 4 `Projection` (4x4 matrix).

---

### `CalibrationStore` (`RefCounted`)
Located at `addons/openprojmap/core/calibration_store.gd`.

- `static func save_calibration(path: String, handles_or_data) -> bool`
  Serializes calibration handles or `CalibrationData` into JSON.
- `static func load_calibration_handles(path: String) -> Array[Vector2]`
  Loads 4 corner handles from JSON file.
- `static func load_calibration_data(path: String) -> CalibrationData`
  Loads calibration settings into a `CalibrationData` resource object.

---

### `MappedSurface` (`ColorRect`)
Located at `addons/openprojmap/nodes/mapped_surface.gd`.

- **Properties:**
  - `target_viewport: SubViewport`: Offscreen viewport whose texture is warped onto this surface.
  - `config_save_path: String`: Calibration JSON save path (default `user://projection_calibration.json`).
  - `handle_radius: float`: Radius of interactive corner handles in pixels (default `12.0`).
  - `handles: Array[Vector2]`: 4 corner UV coordinates.
  - `is_calibrating: bool`: Toggles calibration overlay and handle manipulation.
- **Methods:**
  - `recalculate_matrices()`: Re-computes forward/inverse homographies and updates shader uniforms.
  - `inject_normalized_point(uv: Vector2, is_pressed: bool)`: Injects an external normalized touch/laser position into the SubViewport (touch index 0).
  - `inject_touch_point(touch_id: int, uv: Vector2, is_pressed: bool)`: Injects multi-touch input events (`InputEventScreenTouch` and `InputEventMouseButton`).
  - `save_calibration()`: Persists handle positions to disk.
  - `load_calibration()`: Restores handle positions from disk.

---

### `GridMappedSurface` (`Control`)
Located at `addons/openprojmap/nodes/grid_mapped_surface.gd`.

Supports non-planar and curved surface mapping using an editable NxM control point grid with dynamic `ArrayMesh` reconstruction.

- **Properties:**
  - `grid_rows: int`: Number of vertical grid control points (default `4`).
  - `grid_cols: int`: Number of horizontal grid control points (default `4`).
  - `control_points: Array[Vector2]`: Editable grid handles in normalized UV space.
  - `config_save_path: String`: Calibration JSON file path.
- **Methods:**
  - `rebuild_mesh()`: Reconstructs triangle geometry and UV coordinates for the `ArrayMesh`.
  - `map_screen_uv_to_game_uv(uv: Vector2) -> Vector2`: Bilinear cell coordinate remapping for input inversion.
  - `inject_touch_point(touch_id: int, uv: Vector2, is_pressed: bool)`: Injects multi-touch points into the mapped SubViewport.

---

### `OSCInputReceiver` (`Node`)
Located at `addons/openprojmap/nodes/osc_input_receiver.gd`.

- **Properties:**
  - `port: int`: UDP listen port (default `9000`).
  - `surface: MappedSurface`: Target mapped surface to forward injected coordinates to.

---

## 2. Shaders

### `projection_warp.gdshader`
- `uniform sampler2D source_texture`: Viewport texture input.
- `uniform mat4 inv_homography`: Row-major 3x3 inverse matrix packed into a 4x4 projection matrix. Discards out-of-bounds fragments and renders black border scan-out.

### `edge_blend.gdshader`
- `uniform vec4 blend_margins`: Normalized overlap margins `(left, top, right, bottom)`.
- `uniform float blend_gamma`: Non-linear falloff exponent for multi-projector overlapping seams.
