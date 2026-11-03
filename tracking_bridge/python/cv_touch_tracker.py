#!/usr/bin/env python3
"""
OpenProjMap Camera / IR Multi-Laser & Multi-Touch Tracker Service
Tracks multiple simultaneous laser pointer dots or bright markers,
assigns persistent IDs, and emits multi-touch packets to Godot via UDP.
"""

import argparse
import socket
import struct
import sys
import time
from typing import Dict, List, Tuple
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
        max_active_touches: int = 10,
        hsv_lower=(0, 0, 240),
        hsv_upper=(180, 40, 255),
    ):
        self.godot_ip = godot_ip
        self.godot_port = godot_port
        self.camera_id = camera_id
        self.homography = homography_matrix
        self.min_contour_area = min_contour_area
        self.max_active_touches = max_active_touches
        self.hsv_lower = np.array(hsv_lower, dtype=np.uint8)
        self.hsv_upper = np.array(hsv_upper, dtype=np.uint8)

        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # Active tracks: {touch_id: (x, y, last_seen_timestamp)}
        self.active_tracks: Dict[int, Tuple[float, float, float]] = {}
        self.next_touch_id = 0

    def build_packet(self, cmd: int, x: float, y: float, touch_id: int = 0) -> bytes:
        """
        Packs 1 byte cmd + 1 byte touch_id + two 32-bit big-endian floats.
        cmd: 1 = touch_down, 2 = touch_up, 3 = move
        """
        return struct.pack("!BBff", cmd, touch_id % 256, float(x), float(y))

    def send_point(self, cmd: int, x: float, y: float, touch_id: int = 0) -> None:
        payload = self.build_packet(cmd, x, y, touch_id)
        self.sock.sendto(payload, (self.godot_ip, self.godot_port))

    def _transform_point(self, cx: float, cy: float, w: int, h: int) -> Tuple[float, float]:
        if self.homography is not None:
            src_pt = np.array([[[cx, cy]]], dtype=np.float32)
            dst_pt = cv2.perspectiveTransform(src_pt, self.homography)
            norm_x = float(np.clip(dst_pt[0][0][0], 0.0, 1.0))
            norm_y = float(np.clip(dst_pt[0][0][1], 0.0, 1.0))
        else:
            norm_x = float(np.clip(cx / w, 0.0, 1.0))
            norm_y = float(np.clip(cy / h, 0.0, 1.0))
        return norm_x, norm_y

    def process_frame(self, frame: np.ndarray):
        """
        Detects blobs in frame, associates them with persistent touch IDs, and emits UDP packets.
        Returns: (detected_count: int, active_points: List[(id, norm_x, norm_y)], mask)
        """
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        mask = cv2.inRange(hsv, self.hsv_lower, self.hsv_upper)
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        h, w = frame.shape[:2]
        current_blobs: List[Tuple[float, float]] = []

        if contours:
            for c in contours:
                if cv2.contourArea(c) >= self.min_contour_area:
                    ((cx, cy), radius) = cv2.minEnclosingCircle(c)
                    nx, ny = self._transform_point(cx, cy, w, h)
                    current_blobs.append((nx, ny))

        # Associate current blobs with existing active tracks using nearest neighbor (distance < 0.15 UV)
        now = time.time()
        matched_tracks = set()
        unmatched_blobs = []

        for bx, by in current_blobs:
            best_id = None
            best_dist = 0.15 # Max distance threshold in normalized coords
            for tid, (tx, ty, _) in self.active_tracks.items():
                if tid in matched_tracks:
                    continue
                dist = ((bx - tx) ** 2 + (by - ty) ** 2) ** 0.5
                if dist < best_dist:
                    best_dist = dist
                    best_id = tid

            if best_id is not None:
                matched_tracks.add(best_id)
                self.active_tracks[best_id] = (bx, by, now)
                self.send_point(3, bx, by, touch_id=best_id) # Move
            else:
                unmatched_blobs.append((bx, by))

        # Release stale tracks not matched in this frame
        lost_ids = [tid for tid in self.active_tracks if tid not in matched_tracks]
        for tid in lost_ids:
            tx, ty, _ = self.active_tracks[tid]
            self.send_point(2, tx, ty, touch_id=tid) # Touch Up
            del self.active_tracks[tid]

        # Allocate new IDs for unmatched blobs
        for bx, by in unmatched_blobs:
            if len(self.active_tracks) < self.max_active_touches:
                new_id = self.next_touch_id
                self.next_touch_id = (self.next_touch_id + 1) % 256
                self.active_tracks[new_id] = (bx, by, now)
                self.send_point(1, bx, by, touch_id=new_id) # Touch Down

        active_points = [(tid, pos[0], pos[1]) for tid, pos in self.active_tracks.items()]
        return len(active_points), active_points, mask

    def run(self, headless: bool = False, max_frames: int = -1) -> None:
        cap = cv2.VideoCapture(self.camera_id)
        if not cap.isOpened():
            print(f"Error: Could not open camera {self.camera_id}", file=sys.stderr)
            return

        print(f"Multi-touch tracker streaming to {self.godot_ip}:{self.godot_port}...")
        frames_processed = 0

        try:
            while cap.isOpened():
                ret, frame = cap.read()
                if not ret:
                    break

                count, pts, mask = self.process_frame(frame)
                frames_processed += 1

                if not headless:
                    display = frame.copy()
                    for tid, nx, ny in pts:
                        px, py = int(nx * frame.shape[1]), int(ny * frame.shape[0])
                        cv2.circle(display, (px, py), 12, (0, 255, 0), 2)
                        cv2.putText(display, f"ID:{tid}", (px + 10, py - 10),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
                    cv2.imshow("Tracking Preview", display)
                    if cv2.waitKey(1) & 0xFF == 27:
                        break

                if max_frames > 0 and frames_processed >= max_frames:
                    break
        finally:
            cap.release()
            if not headless:
                cv2.destroyAllWindows()


def main():
    parser = argparse.ArgumentParser(description="OpenProjMap Multi-Touch Tracker")
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
