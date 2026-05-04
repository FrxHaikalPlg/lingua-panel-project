"""
ONNX inference module for RF-DETR character detection model,
and Ultralytics YOLO for bubble detection.
"""

import cv2
import numpy as np
import onnxruntime as ort
import os
from typing import List, Dict, Optional

# ImageNet normalization constants (used by DINOv2 backbone)
IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

# Class names for each model (index 0 = background in RF-DETR)
BUBBLE_CLASSES = ["__background__", "text_bubble", "text_free"]
CHARACTER_CLASSES = ["__background__", "ignore", "letters", "line-dots"]


class ONNXDetector:
    """Wrapper for ONNX object detection model inference."""

    def __init__(self, model_path: str, class_names: List[str]):
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model not found: {model_path}")

        self.class_names = class_names
        self.session = ort.InferenceSession(
            model_path,
            providers=["CPUExecutionProvider"],
        )
        self.input_name = self.session.get_inputs()[0].name
        input_info = self.session.get_inputs()[0]
        self.input_height = input_info.shape[2]
        self.input_width = input_info.shape[3]
        print(f"Loaded ONNX model: {os.path.basename(model_path)} "
              f"({len(class_names)} classes, input={self.input_width}x{self.input_height})")

    def _preprocess(self, image: np.ndarray) -> np.ndarray:
        """
        Preprocess image for RF-DETR inference.
        Follows the reference implementation: simple resize + ImageNet normalization.
        """
        # Convert BGR → RGB
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

        # Resize to model input size (simple resize, no letterbox)
        resized = cv2.resize(rgb, (self.input_width, self.input_height),
                             interpolation=cv2.INTER_LINEAR)

        # Normalize to [0, 1] then apply ImageNet normalization
        blob = resized.astype(np.float32) / 255.0
        blob = (blob - IMAGENET_MEAN) / IMAGENET_STD

        # HWC → CHW, add batch dim
        blob = np.transpose(blob, (2, 0, 1))
        blob = np.expand_dims(blob, axis=0)

        return blob

    def _postprocess(
        self,
        dets: np.ndarray,
        labels_logits: np.ndarray,
        orig_w: int,
        orig_h: int,
        confidence_threshold: float = 0.35,
    ) -> List[Dict]:
        """
        Post-process model outputs to list of detections.

        RF-DETR ONNX outputs:
        - dets: [batch, num_queries, 4] → (cx, cy, w, h) NORMALIZED (0-1)
        - labels: [batch, num_queries, num_classes] → raw logits
        """
        # Remove batch dimension, apply sigmoid
        dets = dets[0]
        labels_logits = labels_logits[0]
        scores_all = 1.0 / (1.0 + np.exp(-labels_logits))

        # Get max score per query
        max_scores = np.max(scores_all, axis=1)
        class_ids = np.argmax(scores_all, axis=1)

        # Sort by confidence (highest first)
        sorted_idx = np.argsort(max_scores)[::-1]

        # Convert boxes from normalized cxcywh → pixel xyxy
        cx = dets[:, 0]
        cy = dets[:, 1]
        w = dets[:, 2]
        h = dets[:, 3]
        x1_norm = cx - w / 2
        y1_norm = cy - h / 2
        x2_norm = cx + w / 2
        y2_norm = cy + h / 2

        predictions = []
        for idx in sorted_idx:
            score = float(max_scores[idx])
            if score < confidence_threshold:
                break  # Already sorted, all remaining are lower

            class_id = int(class_ids[idx])

            # Scale to original image dimensions
            bx1 = max(0, int(x1_norm[idx] * orig_w))
            by1 = max(0, int(y1_norm[idx] * orig_h))
            bx2 = min(orig_w, int(x2_norm[idx] * orig_w))
            by2 = min(orig_h, int(y2_norm[idx] * orig_h))

            bw = bx2 - bx1
            bh = by2 - by1

            # Skip tiny boxes
            if bw < 5 or bh < 5:
                continue

            predictions.append({
                "class": self.class_names[class_id] if class_id < len(self.class_names) else f"class_{class_id}",
                "class_id": class_id,
                "confidence": score,
                "x": int((bx1 + bx2) / 2),
                "y": int((by1 + by2) / 2),
                "width": bw,
                "height": bh,
                "x1": bx1,
                "y1": by1,
                "x2": bx2,
                "y2": by2,
            })

        return predictions

    def predict(
        self,
        image_or_path,
        confidence_threshold: float = 0.35,
    ) -> List[Dict]:
        """
        Run detection on an image.

        Args:
            image_or_path: numpy array (BGR) or path to image file
            confidence_threshold: minimum confidence to keep detection

        Returns:
            List of detection dicts with keys:
            class, class_id, confidence, x, y, width, height, x1, y1, x2, y2
        """
        if isinstance(image_or_path, str):
            image = cv2.imread(image_or_path)
            if image is None:
                raise FileNotFoundError(f"Cannot read image: {image_or_path}")
        else:
            image = image_or_path

        orig_h, orig_w = image.shape[:2]
        blob = self._preprocess(image)
        outputs = self.session.run(None, {self.input_name: blob})
        dets, labels_logits = outputs[0], outputs[1]

        return self._postprocess(
            dets, labels_logits, orig_w, orig_h,
            confidence_threshold=confidence_threshold,
        )


# Singleton model instances — loaded once on first use

_bubble_detector = None
_character_detector: Optional[ONNXDetector] = None


class YOLODetector:
    """
    Wrapper for Ultralytics YOLO model inference.
    Outputs the same dict format as ONNXDetector so the rest of the
    pipeline needs zero changes.
    """

    def __init__(self, model_path: str):
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model not found: {model_path}")
        from ultralytics import YOLO
        self.model = YOLO(model_path)
        self.class_names = self.model.names  # dict {int: str}
        print(
            f"Loaded YOLO model: {os.path.basename(model_path)} "
            f"({len(self.class_names)} classes: {list(self.class_names.values())})"
        )

    def predict(self, image_or_path, confidence_threshold: float = 0.15) -> List[Dict]:
        """
        Run detection and return list of dicts with keys:
          class, class_id, confidence, x, y, width, height, x1, y1, x2, y2
        """
        results = self.model.predict(
            source=image_or_path,
            conf=confidence_threshold,
            verbose=False,
        )
        predictions = []
        for r in results:
            for box in r.boxes:
                x1, y1, x2, y2 = (int(v) for v in box.xyxy[0].tolist())
                w  = x2 - x1
                h  = y2 - y1
                if w < 5 or h < 5:
                    continue
                cls_id = int(box.cls[0])
                predictions.append({
                    "class":      self.class_names.get(cls_id, f"class_{cls_id}"),
                    "class_id":  cls_id,
                    "confidence": float(box.conf[0]),
                    "x":         (x1 + x2) // 2,
                    "y":         (y1 + y2) // 2,
                    "width":     w,
                    "height":    h,
                    "x1":        x1,
                    "y1":        y1,
                    "x2":        x2,
                    "y2":        y2,
                })
        # Sort by confidence descending (consistent with ONNXDetector)
        predictions.sort(key=lambda p: p["confidence"], reverse=True)
        return predictions


def get_bubble_detector() -> YOLODetector:
    """Get or initialize the YOLO bubble detection model."""
    global _bubble_detector
    if _bubble_detector is None:
        model_path = os.path.join(
            os.path.dirname(__file__), "models", "best.pt"
        )
        _bubble_detector = YOLODetector(model_path)
    return _bubble_detector


def get_character_detector() -> ONNXDetector:
    """Get or initialize the RF-DETR character detection model (ONNX)."""
    global _character_detector
    if _character_detector is None:
        model_path = os.path.join(
            os.path.dirname(__file__), "models", "character_detection.onnx"
        )
        _character_detector = ONNXDetector(model_path, CHARACTER_CLASSES)
    return _character_detector
