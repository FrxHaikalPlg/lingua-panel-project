"""
ONNX Export Script for RF-DETR Models
=====================================
One-time script to convert .pth fine-tuned RF-DETR models to ONNX format.

Usage:
    python convert_to_onnx.py

Requirements:
    pip install "rfdetr[onnxexport]"
"""

import os
from rfdetr import RFDETRMedium

OUTPUT_DIR = "models"
os.makedirs(OUTPUT_DIR, exist_ok=True)

MODELS_TO_CONVERT = [
    {
        "name": "bubble_detection",
        "weights": "../bubble_detction_model.pth",
    },
    {
        "name": "character_detection",
        "weights": "../character_detection_model.pth",
    },
]

for model_info in MODELS_TO_CONVERT:
    print(f"\n{'='*60}")
    print(f"Converting: {model_info['name']}")
    print(f"Weights:    {model_info['weights']}")
    print(f"{'='*60}")
    
    model = RFDETRMedium(pretrain_weights=model_info["weights"])
    model.export(
        output_dir=OUTPUT_DIR,
        opset_version=17,
        batch_size=1,
    )
    
    # Rename the output file to a descriptive name
    default_output = os.path.join(OUTPUT_DIR, "inference_model.onnx")
    target_output = os.path.join(OUTPUT_DIR, f"{model_info['name']}.onnx")
    
    if os.path.exists(default_output):
        if os.path.exists(target_output):
            os.remove(target_output)
        os.rename(default_output, target_output)
        file_size_mb = os.path.getsize(target_output) / (1024 * 1024)
        print(f"✅ Exported: {target_output} ({file_size_mb:.1f} MB)")
    else:
        # Check if any .onnx file was created in the output dir
        onnx_files = [f for f in os.listdir(OUTPUT_DIR) if f.endswith('.onnx')]
        print(f"⚠️  Default output not found. ONNX files in {OUTPUT_DIR}: {onnx_files}")

print(f"\n{'='*60}")
print("Done! ONNX models saved in:", OUTPUT_DIR)
print(f"{'='*60}")
