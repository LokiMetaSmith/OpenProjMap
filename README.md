# OpenProjMap
Open-Source Interactive Projection Mapping Engine
# Project Genesis: Open-Source Interactive Projection Mapping Engine (OpenProjMap)

**Target Framework:** Godot 4.x (Core Rendering & Gameplay) + Python/OpenCV (Computer Vision Tracking Bridge)

**Distribution Model:** MIT License

**Scope:** Hackathon-ready, zero-cost, fully open-source framework enabling developers to build projection-mapped games with plug-and-play camera touch/laser tracking.

---

## 1. System Architecture Overview

The system bridges physical projection geometry, off-screen game logic, and external spatial tracking through an decoupled pipeline:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PHYSICAL ENVIRONMENT                            │
│   [ Projector Display ] ◄─────────────────────────┐                   │
│   [ Interactive Surface (Wall/Floor/Table) ]      │                   │
│   [ Camera / IR Sensor / Webcam ] ──────┐          │                   │
└─────────────────────────────────────────┼──────────┼───────────────────┘
                                          │          │
                                   Raw Video Feed    │ Calibrated Output
                                          │          │
┌─────────────────────────────────────────▼──────────┴───────────────────┐
│                    OPENPROJMAP RUNTIME (GODOT 4)                       │
│                                                                        │
│  ┌─────────────────────────┐      SubViewport Texture                  │
│  │     Game Viewport       │ ────────────────────────┐                 │
│  │  (Isolated Game Scene)  │                         │                 │
│  │   - Fixed 1080p Canvas  │                         │                 │
│  │   - Standard 2D/3D APIs │                         ▼                 │
│  └────────────▲────────────┘              ┌──────────────────────┐     │
│               │ Injected Input Events     │ Projective Shader    │     │
│  ┌────────────┴────────────┐              │ (Fragment Warp via   │     │
│  │  Input Remapping Layer  │              │  Homography Inverse) │     │
│  │  - UDP / OSC Listener   │              └──────────┬───────────┘     │
│  │  - Mouse/Touch Fallback │                         │                 │
│  │  - Inverse H Transform  │                         ▼                 │
│  └────────────▲────────────┘              ┌──────────────────────┐     │
│               │                           │ Physical Display Out │     │
│               │ Normalized (x, y)         │ (Fullscreen Keystoned│     │
│  ┌────────────┴────────────┐              │  Surfaces)           │     │
│  │ External CV Bridge      │              └──────────────────────┘     │
│  │ (Python/C++ OpenCV Node)│                                           │
│  └─────────────────────────┘                                           │
└────────────────────────────────────────────────────────────────────────┘

```

### Core Design Invariants

1. **Game Code Isolation:** Game logic lives entirely inside standard Godot scenes within an offscreen `SubViewport`. Game developers never write custom projection, keystone, or distortion code.
2. **Transparent Input Injection:** External touch/pointer events from cameras or mice are transformed via inverse projective homography ($H^{-1}$) and pushed directly into the `SubViewport` event queue via `push_input()`. To the game, all inputs appear as standard local mouse/touch inputs.
3. **Pure Mathematical Projection:** Quad warping uses an 8-DOF projective transformation matrix ($3 \times 3$) executed in fragment shaders, eliminating the diagonal affine seam artifacts common in 2-triangle affine warping.

---

## 2. Directory Layout

```text
openprojmap/
├── addons/
│   └── openprojmap/
│       ├── plugin.cfg
│       ├── core/
│       │   ├── homography.gd               # 3x3 Projective Math Engine
│       │   ├── calibration_data.gd         # Resource schema for save/load
│       │   └── calibration_store.gd        # JSON serialization handler
│       ├── shaders/
│       │   ├── projection_warp.gdshader    # Perspective fragment warper
│       │   └── edge_blend.gdshader         # Multi-projector overlap feathering
│       ├── nodes/
│       │   ├── mapped_surface.gd           # CanvasItem host node
│       │   ├── calibration_overlay.gd      # Corner-pin drag handles UI
│       │   └── osc_input_receiver.gd       # UDP/OSC coordinate decoder
│       └── scenes/
│           ├── calibration_gizmo.tscn      # Handle visualizer
│           └── default_viewport_host.tscn  # Out-of-the-box game wrapper
├── tracking_bridge/
│   ├── python/
│   │   ├── requirements.txt
│   │   ├── cv_touch_tracker.py         # OpenCV camera/IR laser blob tracker
│   │   └── camera_calibration.py       # Camera homography aligner
│   └── cpp/                            # Optional low-latency bridge
├── tests/
│   ├── unit/
│   │   ├── test_homography.gd          # GUT math unit tests
│   │   └── test_calibration_store.gd  # Serialization tests
│   └── integration/
│       └── test_input_injection.gd     # Viewport event delivery tests
├── examples/
│   ├── 01_simple_targets/              # Whack-a-mole demo
│   ├── 02_physics_sandbox/             # RigidBody interaction demo
│   └── 03_multi_projector/             # 2-screen spanned setup
├── docs/
│   ├── HACKATHON_QUICKSTART.md
│   ├── CAMERA_TRACKING_SETUP.md
│   └── API_REFERENCE.md
├── project.godot
└── README.md

```

---

## 3. Mathematical Specifications

### 3.1 Direct Linear Transformation (DLT) for Perspective Homography

To map an arbitrary convex quadrilateral with points $P_i = (x_i, y_i)$ for $i \in \{0, 1, 2, 3\}$ from the unit square $(0,0), (1,0), (1,1), (0,1)$, solve for matrix $H$:

$$H = \begin{bmatrix} a & b & c \\ d & e & f \\ g & h & 1 \end{bmatrix}$$

Given:


$$\Delta x_1 = x_1 - x_2, \quad \Delta x_2 = x_3 - x_2, \quad \Sigma x = x_0 - x_1 + x_2 - x_3$$

$$\Delta y_1 = y_1 - y_2, \quad \Delta y_2 = y_3 - y_2, \quad \Sigma y = y_0 - y_1 + y_2 - y_3$$

When $\Sigma x = 0$ and $\Sigma y = 0$ (affine):


$$a = x_1 - x_0, \quad b = x_2 - x_1, \quad c = x_0, \quad d = y_1 - y_0, \quad e = y_2 - y_1, \quad f = y_0, \quad g = 0, \quad h = 0$$

Otherwise (projective):


$$g = \frac{\Sigma x \cdot \Delta y_2 - \Sigma y \cdot \Delta x_2}{\Delta x_1 \cdot \Delta y_2 - \Delta y_1 \cdot \Delta x_2}$$

$$h = \frac{\Delta x_1 \cdot \Sigma y - \Delta y_1 \cdot \Sigma x}{\Delta x_1 \cdot \Delta y_2 - \Delta y_1 \cdot \Delta x_2}$$

$$a = x_1 - x_0 + g \cdot x_1, \quad b = x_3 - x_0 + h \cdot x_3, \quad c = x_0$$

$$d = y_1 - y_0 + g \cdot y_1, \quad e = y_3 - y_0 + h \cdot y_3, \quad f = y_0$$

### 3.2 Coordinate Inversion for Physical Inputs

Screen-to-Game coordinate translation requires inverting $H$:


$$H^{-1} = \frac{1}{\det(H)} \text{adj}(H)$$

Given any raw screen coordinate $P_{\text{screen}} = [u, v, 1]^T$:


$$\begin{bmatrix} x' \\ y' \\ w' \end{bmatrix} = H^{-1} \begin{bmatrix} u \\ v \\ 1 \end{bmatrix}$$

$$P_{\text{game\_uv}} = \left( \frac{x'}{w'}, \frac{y'}{w'} \right)$$

---

## 4. Production Code Implementation

### 4.1 Projective Mathematics Engine (`addons/openprojmap/core/homography.gd`)

```gdscript
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

## Transforms a 2D coordinate through a 3x3 homography matrix with perspective division.
static func transform_point(m: Array[Vector3], p: Vector2) -> Vector2:
	var x: float = m[0].x * p.x + m[0].y * p.y + m[0].z
	var y: float = m[1].x * p.x + m[1].y * p.y + m[1].z
	var w: float = m[2].x * p.x + m[2].y * p.y + m[2].z
	if abs(w) > 1e-7:
		return Vector2(x / w, y / w)
	return Vector2.ZERO

```

---

### 4.2 Fragment Shader (`addons/openprojmap/shaders/projection_warp.gdshader`)

```glsl
shader_type canvas_item;

uniform sampler2D source_texture : filter_linear_mipmap, repeat_disable;
// Row-major 3x3 Inverse Homography matrix packed as Projection/mat4
uniform mat4 inv_homography;

void fragment() {
    vec4 screen_coord = vec4(UV.x, UV.y, 1.0, 0.0);
    
    // Matrix multiplication: H_inv * [u, v, 1]^T
    float mapped_x = inv_homography[0][0] * screen_coord.x + inv_homography[0][1] * screen_coord.y + inv_homography[0][2];
    float mapped_y = inv_homography[1][0] * screen_coord.x + inv_homography[1][1] * screen_coord.y + inv_homography[1][2];
    float mapped_w = inv_homography[2][0] * screen_coord.x + inv_homography[2][1] * screen_coord.y + inv_homography[2][2];

    if (abs(mapped_w) < 0.00001) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 game_uv = vec2(mapped_x, mapped_y) / mapped_w;

    // Discard fragments outside the active game viewport boundaries
    if (game_uv.x < 0.0 || game_uv.x > 1.0 || game_uv.y < 0.0 || game_uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        COLOR = texture(source_texture, game_uv);
    }
}

```

---

### 4.3 Calibration and Surface Manager (`addons/openprojmap/nodes/mapped_surface.gd`)

```gdscript
@tool
class_name MappedSurface
extends ColorRect

@export var target_viewport: SubViewport
@export var config_save_path: String = "user://projection_calibration.json"
@export var handle_radius: float = 12.0

var handles: Array[Vector2] = [
	Vector2(0.05, 0.05), # Top-Left
	Vector2(0.95, 0.05), # Top-Right
	Vector2(0.95, 0.95), # Bottom-Right
	Vector2(0.05, 0.95)  # Bottom-Left
]

var inv_h: Array[Vector3] = []
var forward_h: Array[Vector3] = []
var selected_handle_index: int = -1
var is_calibrating: bool = false:
	set(val):
		is_calibrating = val
		queue_redraw()

func _ready() -> void:
	load_calibration()
	recalculate_matrices()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			is_calibrating = !is_calibrating
			accept_event()
			return
		elif event.keycode == KEY_S and event.ctrl_pressed:
			save_calibration()
			accept_event()
			return

	if is_calibrating:
		_process_calibration_input(event)
	else:
		_process_gameplay_input(event)

func recalculate_matrices() -> void:
	forward_h = Homography.get_unit_to_quad_matrix(handles)
	inv_h = Homography.invert_matrix_3x3(forward_h)

	var proj := Projection(
		Vector4(inv_h[0].x, inv_h[0].y, inv_h[0].z, 0.0),
		Vector4(inv_h[1].x, inv_h[1].y, inv_h[1].z, 0.0),
		Vector4(inv_h[2].x, inv_h[2].y, inv_h[2].z, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0)
	)

	var mat = material as ShaderMaterial
	if mat and target_viewport:
		mat.set_shader_parameter("inv_homography", proj)
		mat.set_shader_parameter("source_texture", target_viewport.get_texture())
	queue_redraw()

func _process_calibration_input(event: InputEvent) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_uv: Vector2 = event.position / vp_size
			selected_handle_index = -1
			for i in range(handles.size()):
				if handles[i].distance_to(mouse_uv) < (handle_radius / vp_size.y):
					selected_handle_index = i
					break
		else:
			selected_handle_index = -1
		accept_event()

	elif event is InputEventMouseMotion and selected_handle_index != -1:
		handles[selected_handle_index] = (event.position / vp_size).clamp(Vector2.ZERO, Vector2.ONE)
		recalculate_matrices()
		accept_event()

func _process_gameplay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		var screen_uv: Vector2 = event.position / get_viewport_rect().size
		var game_uv: Vector2 = Homography.transform_point(inv_h, screen_uv)

		if Rect2(0, 0, 1, 1).has_point(game_uv):
			var internal_pos: Vector2 = game_uv * Vector2(target_viewport.size)
			var cloned: InputEvent = event.duplicate()
			cloned.position = internal_pos
			cloned.global_position = internal_pos
			target_viewport.push_input(cloned)
			accept_event()

func inject_normalized_point(uv: Vector2, is_pressed: bool) -> void:
	if not target_viewport or inv_h.is_empty():
		return
	var game_uv: Vector2 = Homography.transform_point(inv_h, uv)
	if Rect2(0, 0, 1, 1).has_point(game_uv):
		var target_pos: Vector2 = game_uv * Vector2(target_viewport.size)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = is_pressed
		ev.position = target_pos
		ev.global_position = target_pos
		target_viewport.push_input(ev)

func save_calibration() -> void:
	var raw_points: Array = []
	for p in handles:
		raw_points.append({"x": p.x, "y": p.y})
	var file := FileAccess.open(config_save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(raw_points, "\t"))
		file.close()

func load_calibration() -> void:
	if not FileAccess.file_exists(config_save_path):
		return
	var file := FileAccess.open(config_save_path, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Array:
		var arr: Array = json.data
		if arr.size() == 4:
			for i in range(4):
				handles[i] = Vector2(arr[i]["x"], arr[i]["y"])

func _draw() -> void:
	if not is_calibrating:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	for i in range(4):
		var p1: Vector2 = handles[i] * vp_size
		var p2: Vector2 = handles[(i + 1) % 4] * vp_size
		draw_line(p1, p2, Color.YELLOW, 2.0, true)
		draw_circle(p1, handle_radius, Color.CYAN)
		draw_circle(p1, handle_radius - 3.0, Color.BLACK)

```

---

### 4.4 High-Speed UDP / OSC Coordinate Bridge (`addons/openprojmap/nodes/osc_input_receiver.gd`)

```gdscript
class_name OSCInputReceiver
extends Node

@export var port: int = 9000
@export var surface: MappedSurface

var server: UDPServer

func _ready() -> void:
	server = UDPServer.new()
	var err = server.listen(port)
	if err != OK:
		push_error("Failed to bind UDP server on port %d" % port)

func _process(_delta: float) -> void:
	server.poll()
	if server.is_connection_available():
		var peer: PacketPeerUDP = server.take_connection()
		while peer.get_available_packet_count() > 0:
			var pkt: PackedByteArray = peer.get_packet()
			_parse_packet(pkt)

func _parse_packet(pkt: PackedByteArray) -> void:
	# Protocol: 1-byte command (0x01 = touch_down, 0x02 = touch_up, 0x03 = move)
	# Followed by 2x 32-bit floats (x, y normalized 0.0 .. 1.0)
	if pkt.size() < 9:
		return
	
	var cmd: int = pkt.decode_u8(0)
	var x: float = pkt.decode_float(1)
	var y: float = pkt.decode_float(5)
	var pos := Vector2(x, y)

	if surface:
		var is_pressed := (cmd == 1 or cmd == 3)
		surface.inject_normalized_point(pos, is_pressed)

```

---

### 4.5 Python OpenCV Tracking Service (`tracking_bridge/python/cv_touch_tracker.py`)

Run this service alongside the engine to track laser pointers or high-contrast markers from any USB camera or webcam:

```python
#!/usr/bin/env python3
import socket
import struct
import cv2
import numpy as np

GODOT_IP = "127.0.0.1"
GODOT_PORT = 9000
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

cap = cv2.VideoCapture(0)
# Laser/Bright Spot Tracker Thresholds
LOWER_HSV = np.array([0, 0, 240])
UPPER_HSV = np.array([180, 40, 255])

def send_point(cmd: int, x: float, y: float):
    # Pack 1 byte cmd + 2 x 32-bit float
    payload = struct.pack("!Bff", cmd, float(x), float(y))
    sock.sendto(payload, (GODOT_IP, GODOT_PORT))

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break

    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    mask = cv2.inRange(hsv, LOWER_HSV, UPPER_HSV)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    if contours:
        c = max(contours, key=cv2.contourArea)
        if cv2.contourArea(c) > 5.0:
            ((x, y), radius) = cv2.minEnclosingCircle(c)
            h, w = frame.shape[:2]
            norm_x = np.clip(x / w, 0.0, 1.0)
            norm_y = np.clip(y / h, 0.0, 1.0)
            send_point(1, norm_x, norm_y) # Touch down/move

    cv2.imshow("Tracking Preview", mask)
    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()

```

---

## 5. Coding Agent Implementation Tasks

### Phase 1: Core Engine & Math Verification

* [x] Implement `addons/openprojmap/core/homography.gd` with both unit-to-quad matrix derivation and analytical 3x3 Gaussian/adjoint inversion.
* [x] Add unit tests verifying identity transforms, known trapezoidal warps, and singular matrix handling under zero-determinant conditions.
* [x] Build `addons/openprojmap/shaders/projection_warp.gdshader` supporting dynamic `mat4` projection assignment without compilation stutter.
* [x] Verify fragment bounds clipping to ensure black border scan-out on fragments where $w \le 0$ or $(u, v) \notin [0, 1]$.

### Phase 2: Calibration Gizmo & Viewport Harness

* [x] Create `addons/openprojmap/nodes/mapped_surface.gd` connecting `SubViewport.get_texture()` to `ColorRect` via `ShaderMaterial`.
* [x] Add draggable calibration corner points with visual handle snapping and hotkey toggle (`Tab`).
* [x] Implement robust JSON serialization for handle positions to persist calibrations across sessions (`user://projection_calibration.json`).
* [x] Implement `_forward_interactive_input()` with boundary validation and dynamic event synthesis (`InputEventMouseButton`, `InputEventMouseMotion`).

### Phase 3: External Tracking Bridge

* [x] Implement `addons/openprojmap/nodes/osc_input_receiver.gd` using Godot's `UDPServer` for non-blocking network packet polling.
* [x] Develop `tracking_bridge/python/cv_touch_tracker.py` using OpenCV contour isolation with automatic camera FPS sync.
* [x] Add camera-to-projector calibration script computing a secondary homography between camera pixels and projector surface UVs.

### Phase 4: Quality Assurance & Testing Suite

* [x] **Unit Tests (GUT):** Write tests verifying homography numerical stability across extreme aspect ratios (16:9 to 4:3, extreme keystones).
* [x] **E2E Input Injection Tests:** Build an automated headless Godot test script that injects screen-space points and asserts that internal `Area2D` collision shapes detect clicks at identical game coordinates.
* [x] **Stress Test:** Benchmark rendering at 4K display scan-out to guarantee $60\text{ FPS}$ with zero memory leaks.

### Phase 5: Documentation & Hackathon Starter Kit

* [x] Write `HACKATHON_QUICKSTART.md` providing a 3-step setup guide (Drop scene $\to$ Build game in `SubViewport` $\to$ Hit `Tab` to map).
* [x] Build Example 01 (`01_simple_targets`): Interactive target-popping game with instant score counter.
* [x] Package the entire codebase as a drop-in Godot Engine Addon (`addons/openprojmap/`).

---

## 6. Verification and Acceptance Criteria

| Subsystem | Acceptance Criteria |
| --- | --- |
| **Perspective Warping** | Textures render without visible diagonal shear/creasing when all 4 corners are deformed into asymmetrical polygons. |
| **Input Fidelity** | Physical mouse/laser click on a target edge matches game object click detection within a $\le 3\text{px}$ tolerance. |
| **Serialization** | Pressing `Ctrl + S` during calibration saves corner coordinates; restarting the engine loads the saved layout without user interaction. |
| **Tracking Latency** | End-to-end latency from OpenCV frame capture to Godot internal viewport click remains under $33\text{ ms}$ (2 frames at $60\text{ Hz}$). |
