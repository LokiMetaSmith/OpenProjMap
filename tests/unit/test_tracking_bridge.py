import json
import numpy as np
import pytest
from tracking_bridge.python.cv_touch_tracker import CVTouchTracker
from tracking_bridge.python.camera_calibration import CameraCalibrator


def test_cv_touch_tracker_packet_format():
    tracker = CVTouchTracker()
    packet = tracker.build_packet(1, 0.25, 0.75)
    assert len(packet) == 9
    assert packet[0] == 1
    import struct
    cmd, x, y = struct.unpack("!Bff", packet)
    assert cmd == 1
    assert abs(x - 0.25) < 1e-5
    assert abs(y - 0.75) < 1e-5


def test_cv_touch_tracker_detection_synthetic():
    tracker = CVTouchTracker(godot_port=9999, min_contour_area=4.0)
    # Create black image with a bright spot at (320, 240) in a 640x480 frame
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    import cv2
    cv2.circle(frame, (320, 240), 10, (255, 255, 255), -1)

    detected, pt, mask = tracker.process_frame(frame)
    assert detected is True
    assert pt is not None
    assert abs(pt[0] - 0.5) < 0.05
    assert abs(pt[1] - 0.5) < 0.05


def test_camera_calibration_homography():
    calibrator = CameraCalibrator()
    # Mock camera frame points forming a trapezoid
    calibrator.camera_points = [
        [100.0, 100.0],
        [500.0, 120.0],
        [520.0, 460.0],
        [80.0, 440.0]
    ]
    H = calibrator.calculate_homography()
    assert H.shape == (3, 3)

    # Test mapping of point 0 -> (0, 0)
    p0 = np.array([[[100.0, 100.0]]], dtype=np.float32)
    import cv2
    mapped = cv2.perspectiveTransform(p0, H)
    assert abs(mapped[0][0][0] - 0.0) < 1e-4
    assert abs(mapped[0][0][1] - 0.0) < 1e-4
