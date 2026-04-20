"""
One-time script to convert fine-tuned RF-DETR .pth weights to ONNX format.

Usage (from project root):
    python scripts/convert_to_onnx.py

Requirements:
    pip install "rfdetr[onnxexport]"
"""

import os
from rfdetr import RFDETRMedium

# Resolve paths relative to project root (parent of this script's directory)
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "android_backend", "models")
os.makedirs(OUTPUT_DIR, exist_ok=True)

MODELS_TO_CONVERT = [
    {
        "name": "bubble_detection",
        "weights": os.path.join(PROJECT_ROOT, "bubble_detction_model.pth"),
    },
    {
        "name": "character_detection",
        "weights": os.path.join(PROJECT_ROOT, "character_detection_model.pth"),
    },
]

for model_info in MODELS_TO_CONVERT:
    print(f"\n{'='*60}")
    print(f"Converting : {model_info['name']}")
    print(f"Weights    : {model_info['weights']}")
    print(f"Output dir : {OUTPUT_DIR}")
    print(f"{'='*60}")

    model = RFDETRMedium(pretrain_weights=model_info["weights"])
    model.export(output_dir=OUTPUT_DIR, opset_version=17, batch_size=1)

    default_output = os.path.join(OUTPUT_DIR, "inference_model.onnx")
    target_output = os.path.join(OUTPUT_DIR, f"{model_info['name']}.onnx")

    if os.path.exists(default_output):
        if os.path.exists(target_output):
            os.remove(target_output)
        os.rename(default_output, target_output)
        size_mb = os.path.getsize(target_output) / (1024 * 1024)
        print(f"✅ Saved: {target_output} ({size_mb:.1f} MB)")
    else:
        onnx_files = [f for f in os.listdir(OUTPUT_DIR) if f.endswith(".onnx")]
        print(f"⚠️  Expected output not found. Files in output dir: {onnx_files}")

print(f"\n{'='*60}")
print("Done. Models saved to:", OUTPUT_DIR)
print(f"{'='*60}")
