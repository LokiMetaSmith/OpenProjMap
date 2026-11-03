# Camera Tracking Setup & Calibration Guide

This guide covers setting up an external USB webcam, IR camera, or laser pointer tracking pipeline with OpenProjMap.

---

## 1. Prerequisites

Install the Python tracking dependencies:
```bash
pip install -r tracking_bridge/python/requirements.txt
```

---

## 2. Camera-to-Projector Alignment Calibration

Before tracking touch or laser spots, map camera pixels to projector normalized coordinates (0.0 to 1.0):

1. Project a test image or your game window onto your physical surface.
2. Run the calibration wizard:
   ```bash
   python tracking_bridge/python/camera_calibration.py --camera 0 --output camera_calib.json
   ```
3. A camera feed preview window will open. Click the 4 corners of the projected quad in clockwise order:
   - **Corner 1:** Top-Left
   - **Corner 2:** Top-Right
   - **Corner 3:** Bottom-Right
   - **Corner 4:** Bottom-Left
4. Press **ENTER** to compute and save the homography matrix to `camera_calib.json`.

---

## 3. Running the Live Touch Tracker

Once calibrated, run the tracker with the calibration file:
```bash
python tracking_bridge/python/cv_touch_tracker.py --camera 0 --calib camera_calib.json --ip 127.0.0.1 --port 9000
```

### Options:
- `--ip`: Target machine running Godot (default `127.0.0.1`).
- `--port`: UDP port listening in Godot (default `9000`).
- `--camera`: Index of video capture device (e.g. `0`, `1`).
- `--headless`: Run without visual debug OpenCV window for performance.

---

## 4. Tuning Sensitivity

Inside `cv_touch_tracker.py`:
- `LOWER_HSV` / `UPPER_HSV`: Color range to isolate laser dot or IR illumination.
  - Default is set for bright white / red laser dots: `np.array([0, 0, 240])` to `np.array([180, 40, 255])`.
- `min_contour_area`: Minimum blob pixel area (default `5.0`).
