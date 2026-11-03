import json
import struct
import numpy as np
import pytest
from tracking_bridge.python.cv_touch_tracker import CVTouchTracker
from tracking_bridge.python.camera_calibration import CameraCalibrator


def test_cv_touch_tracker_packet_format():
    tracker = CVTouchTracker()
    packet = tracker.build_packet(1, 0.25, 0.75, touch_id=2)
    assert len(packet) == 10
    assert packet[0] == 1
    assert packet[1] == 2
    cmd, tid, x, y = struct.unpack("!BBff", packet)
    assert cmd == 1
    assert tid == 2
    assert abs(x - 0.25) < 1e-5
    assert abs(y - 0.75) < 1e-5


def test_cv_touch_tracker_multi_detection():
    tracker = CVTouchTracker(godot_port=9999, min_contour_area=4.0)
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    import cv2
    # Two bright spots
    cv2.circle(frame, (160, 240), 10, (255, 255, 255), -1)
    cv2.circle(frame, (480, 240), 10, (255, 255, 255), -1)

    count, active_pts, mask = tracker.process_frame(frame)
    assert count == 2
    assert len(active_pts) == 2
    # Check that IDs are unique
    ids = [p[0] for p in active_pts]
    assert len(set(ids)) == 2


def test_camera_calibration_homography():
    calibrator = CameraCalibrator()
    calibrator.camera_points = [
        [100.0, 100.0],
        [500.0, 120.0],
        [520.0, 460.0],
        [80.0, 440.0]
    ]
    H = calibrator.calculate_homography()
    assert H.shape == (3, 3)

    p0 = np.array([[[100.0, 100.0]]], dtype=np.float32)
    import cv2
    mapped = cv2.perspectiveTransform(p0, H)
    assert abs(mapped[0][0][0] - 0.0) < 1e-4
    assert abs(mapped[0][0][1] - 0.0) < 1e-4
