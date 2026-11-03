#!/usr/bin/env python3
"""
Camera-to-Projector 4-Point Homography Aligner
Computes perspective mapping between camera frame pixels and normalized projector coordinates (0..1).
"""

import argparse
import json
import cv2
import numpy as np


class CameraCalibrator:
    def __init__(self, camera_id: int = 0):
        self.camera_id = camera_id
        self.camera_points = []
        # Target canonical projector coordinates: TL, TR, BR, BL
        self.projector_points = np.array([
            [0.0, 0.0],
            [1.0, 0.0],
            [1.0, 1.0],
            [0.0, 1.0]
        ], dtype=np.float32)

    def _mouse_callback(self, event, x, y, flags, param):
        if event == cv2.EVENT_LBUTTONDOWN:
            if len(self.camera_points) < 4:
                self.camera_points.append([float(x), float(y)])
                print(f"Captured corner {len(self.camera_points)}: ({x}, {y})")

    def calibrate_interactive(self, output_path: str = "camera_calib.json") -> bool:
        cap = cv2.VideoCapture(self.camera_id)
        if not cap.isOpened():
            print(f"Error: Unable to open camera {self.camera_id}")
            return False

        window_name = "Camera Calibration (Click TL -> TR -> BR -> BL)"
        cv2.namedWindow(window_name)
        cv2.setMouseCallback(window_name, self._mouse_callback)

        print("\n=== Camera Calibration Wizard ===")
        print("Please click the 4 corners of the projection area in order:")
        print("1: Top-Left, 2: Top-Right, 3: Bottom-Right, 4: Bottom-Left.")
        print("Press 'r' to reset points, 'q' or 'ESC' to cancel.\n")

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            display = frame.copy()
            for idx, pt in enumerate(self.camera_points):
                cv2.circle(display, (int(pt[0]), int(pt[1])), 6, (0, 255, 0), -1)
                cv2.putText(display, f"P{idx + 1}", (int(pt[0]) + 10, int(pt[1]) - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

            if len(self.camera_points) == 4:
                pts = np.array(self.camera_points, dtype=np.int32).reshape((-1, 1, 2))
                cv2.polylines(display, [pts], True, (0, 255, 255), 2)
                cv2.putText(display, "4 Points Captured! Press ENTER to save", (20, 40),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)

            cv2.imshow(window_name, display)
            key = cv2.waitKey(20) & 0xFF
            if key == 27 or key == ord('q'):
                print("Calibration cancelled.")
                cap.release()
                cv2.destroyAllWindows()
                return False
            elif key == ord('r'):
                self.camera_points = []
                print("Points reset.")
            elif key == 13 and len(self.camera_points) == 4: # ENTER key
                break

        cap.release()
        cv2.destroyAllWindows()

        return self.save_calibration(output_path)

    def calculate_homography(self) -> np.ndarray:
        if len(self.camera_points) != 4:
            raise ValueError("Exactly 4 points required for homography calculation.")
        src = np.array(self.camera_points, dtype=np.float32)
        dst = self.projector_points
        H, _ = cv2.findHomography(src, dst)
        return H

    def save_calibration(self, output_path: str) -> bool:
        H = self.calculate_homography()
        data = {
            "camera_points": self.camera_points,
            "projector_points": self.projector_points.tolist(),
            "camera_to_projector_homography": H.tolist()
        }
        with open(output_path, "w") as f:
            json.dump(data, f, indent=2)
        print(f"Calibration homography saved successfully to: {output_path}")
        return True


def main():
    parser = argparse.ArgumentParser(description="Camera-to-Projector Calibration")
    parser.add_argument("--camera", type=int, default=0, help="Camera index")
    parser.add_argument("--output", default="camera_calib.json", help="Output calibration JSON")
    args = parser.parse_args()

    calibrator = CameraCalibrator(camera_id=args.camera)
    calibrator.calibrate_interactive(output_path=args.output)


if __name__ == "__main__":
    main()
