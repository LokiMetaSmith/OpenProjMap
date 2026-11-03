#!/usr/bin/env python3
"""
OpenProjMap Camera / IR Laser Touch Tracker Service
Tracks laser pointer dots or bright markers and emits normalized coordinates to Godot via UDP.
"""

import argparse
import socket
import struct
import sys
import time
import cv2
import numpy as np


class CVTouchTracker:
    def __init__(
        self,
        godot_ip: str = "127.0.0.1",
        godot_port: int = 9000,
        camera_id: int = 0,
        homography_matrix: np.ndarray = None,
        min_contour_area: float = 5.0,
        hsv_lower=(0, 0, 240),
        hsv_upper=(180, 40, 255),
    ):
        self.godot_ip = godot_ip
        self.godot_port = godot_port
        self.camera_id = camera_id
        self.homography = homography_matrix
        self.min_contour_area = min_contour_area
        self.hsv_lower = np.array(hsv_lower, dtype=np.uint8)
        self.hsv_upper = np.array(hsv_upper, dtype=np.uint8)

        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.is_tracking = False

    def build_packet(self, cmd: int, x: float, y: float) -> bytes:
        """
        Packs 1 byte cmd + two 32-bit big-endian floats.
        cmd: 1 = touch_down, 2 = touch_up, 3 = move
        """
        return struct.pack("!Bff", cmd, float(x), float(y))

    def send_point(self, cmd: int, x: float, y: float) -> None:
        payload = self.build_packet(cmd, x, y)
        self.sock.sendto(payload, (self.godot_ip, self.godot_port))

    def process_frame(self, frame: np.ndarray):
        """
        Processes an input BGR frame, extracts the laser/touch coordinate, and sends it to Godot.
        Returns: (detected: bool, (norm_x, norm_y), mask)
        """
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        mask = cv2.inRange(hsv, self.hsv_lower, self.hsv_upper)
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        if contours:
            c = max(contours, key=cv2.contourArea)
            if cv2.contourArea(c) >= self.min_contour_area:
                ((cx, cy), radius) = cv2.minEnclosingCircle(c)
                h, w = frame.shape[:2]

                # If camera homography exists, transform pixel coords
                if self.homography is not None:
                    src_pt = np.array([[[cx, cy]]], dtype=np.float32)
                    dst_pt = cv2.perspectiveTransform(src_pt, self.homography)
                    norm_x = float(np.clip(dst_pt[0][0][0], 0.0, 1.0))
                    norm_y = float(np.clip(dst_pt[0][0][1], 0.0, 1.0))
                else:
                    norm_x = float(np.clip(cx / w, 0.0, 1.0))
                    norm_y = float(np.clip(cy / h, 0.0, 1.0))

                cmd = 3 if self.is_tracking else 1
                self.is_tracking = True
                self.send_point(cmd, norm_x, norm_y)
                return True, (norm_x, norm_y), mask

        if self.is_tracking:
            self.is_tracking = False
            # Send touch up event (cmd = 2) at last position
            self.send_point(2, 0.0, 0.0)

        return False, None, mask

    def run(self, headless: bool = False, max_frames: int = -1) -> None:
        cap = cv2.VideoCapture(self.camera_id)
        if not cap.isOpened():
            print(f"Error: Could not open camera {self.camera_id}", file=sys.stderr)
            return

        print(f"Touch tracker streaming to {self.godot_ip}:{self.godot_port}...")
        frames_processed = 0

        try:
            while cap.isOpened():
                ret, frame = cap.read()
                if not ret:
                    break

                detected, pt, mask = self.process_frame(frame)
                frames_processed += 1

                if not headless:
                    cv2.imshow("Tracking Preview", mask)
                    if cv2.waitKey(1) & 0xFF == 27:
                        break

                if max_frames > 0 and frames_processed >= max_frames:
                    break
        finally:
            cap.release()
            if not headless:
                cv2.destroyAllWindows()


def main():
    parser = argparse.ArgumentParser(description="OpenProjMap CV Touch Tracker")
    parser.add_argument("--ip", default="127.0.0.1", help="Target Godot IP")
    parser.add_argument("--port", type=int, default=9000, help="Target Godot UDP port")
    parser.add_argument("--camera", type=int, default=0, help="Camera device index")
    parser.add_argument("--calib", default="", help="Path to camera_calib.json homography matrix")
    parser.add_argument("--headless", action="store_true", help="Run without UI preview window")
    args = parser.parse_args()

    homography = None
    if args.calib:
        import json
        with open(args.calib, "r") as f:
            data = json.load(f)
            homography = np.array(data["camera_to_projector_homography"], dtype=np.float32)

    tracker = CVTouchTracker(
        godot_ip=args.ip,
        godot_port=args.port,
        camera_id=args.camera,
        homography_matrix=homography,
    )
    tracker.run(headless=args.headless)


if __name__ == "__main__":
    main()
