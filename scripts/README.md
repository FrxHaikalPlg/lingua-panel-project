# Scripts

Utility scripts for one-time or offline tasks.

## convert_to_onnx.py

Converts the fine-tuned RF-DETR `.pth` model weights to ONNX format for production deployment.

**Run once** before deploying the backend. The output files go to `android_backend/models/`.

```bash
# Install export dependency (not needed at runtime)
pip install "rfdetr[onnxexport]"

# Run from the project root
python scripts/convert_to_onnx.py
```

Output:
- `android_backend/models/bubble_detection.onnx`
- `android_backend/models/character_detection.onnx`
