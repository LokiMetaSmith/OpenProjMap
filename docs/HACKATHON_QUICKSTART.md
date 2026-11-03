# OpenProjMap Hackathon Quickstart Guide

Get an interactive projection mapped game running in 3 steps under 5 minutes!

---

## 3-Step Setup Guide

### Step 1: Drop the Viewport Host Scene into Your Project
1. Copy `addons/openprojmap` into your Godot 4 project's `addons/` folder.
2. In Project Settings -> Plugins, enable **OpenProjMap**.
3. Instantiate `res://addons/openprojmap/scenes/default_viewport_host.tscn` as your main scene (or inside your master display scene).

### Step 2: Build Your Game Inside the SubViewport
1. Locate the `GameViewport` child under `SubViewportContainer`.
2. Add your game scene (2D or 3D) as a child of `GameViewport`.
   - Your game is rendered at a standard fixed resolution (e.g. 1920x1080).
   - Standard Godot input events (`InputEventMouseButton`, `InputEventMouseMotion`) work out of the box!
   - You **never** need to write projection or keystone correction code in your game logic.

### Step 3: Run and Hit `TAB` to Map
1. Run your project (`F5` in Godot editor).
2. Press **`TAB`** on your keyboard to enter **Calibration Mode**.
3. Drag the 4 corner cyan handles with your mouse to match the physical corners of your projection surface (wall, table, floor).
4. Press **`Ctrl + S`** to save your calibration to disk (`user://projection_calibration.json`).
5. Press **`TAB`** again to exit Calibration Mode and play!

---

## Laser / Camera Tracking (Optional)

To enable physical laser pointer or touch tracking from a webcam:
1. Launch the Python tracking bridge:
   ```bash
   pip install -r tracking_bridge/python/requirements.txt
   python tracking_bridge/python/cv_touch_tracker.py
   ```
2. In your Godot scene, add an `OSCInputReceiver` node and link it to your `MappedSurface`.
3. Point your laser pointer at the projection surface to interact!
