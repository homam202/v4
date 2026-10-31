# TerraMag – Offline Magnetic Gradiometer App (Flutter)

## 0. IMPORTANT: what your `best2.onnx` actually is
I inspected the uploaded file. It is NOT a [1,1,64,64] 3-class classifier:

| Property | Value |
|---|---|
| Type | Ultralytics YOLOv8 **detect** (exported with PyTorch 2.8) |
| Input | `images` float32 **[1, 3, 640, 640]** (RGB, 0..1) |
| Output | `output0` float32 **[1, 10, 8400]** = 4 box values + **6 class scores** |
| Classes | 0 soil, 1 void, 2 moisture, 3 organic, 4 rock, 5 metal |
| NMS | not included in the graph (done in Dart) |

So `OnnxService` renders the matrix as a 640x640 heat-map image, runs the detector, then decodes + applies NMS.
Class -> layer mapping: Soil=soil, Minerals=rock(+organic), Moisture=moisture, Voids=void, Metals=metal.
**Training-image colormap must match** `HeatmapRenderer.colormap` – tell me which one you used and I'll match it.

## 1. Folder structure
```
terramag/
├─ pubspec.yaml
├─ assets/models/best2.onnx            <- model goes here (declared in pubspec)
└─ lib/
   ├─ main.dart                        app shell, RTL/LTR, 4-tab NavigationBar
   ├─ core/theme/app_theme.dart        navy / cyan / gold dark theme
   ├─ services/
   │  ├─ app_state.dart                singleton wiring
   │  ├─ ble/ble_service.dart          flutter_blue_plus, parsing, auto-reconnect
   │  └─ storage/survey_db.dart        sqflite
   ├─ ai/
   │  ├─ onnx_service.dart             session, inference, decode, NMS, dispose
   │  └─ heatmap_renderer.dart         matrix -> [1,3,640,640] tensor
   ├─ features/
   │  ├─ connect/  live_scan/  file_manager/
   │  └─ analysis_3d/ (analysis_screen.dart, grid_processor.dart)
   └─ widgets/ (thermal_bar, iso_grid_painter, ai_overlay_card)
```

## 2. Wireframes
**Logo:** navy rounded square; an isometric 3x3 cyan grid; two cyan sine waves crossing it; one gold cell glowing at the intersection.

**Connect:** AppBar (logo, language toggle) -> list of BLE devices (name, RSSI) -> tap to pair; last device auto-connects at launch. Status chip: Connecting / Connected / Reconnecting.

**Live Scan:** Top row: BLE icon + status, battery %. Centre: tall rounded Thermal Bar (grey->gold->red) that fills with the 0-1023 value. Under it: huge number (96 sp). Bottom: pulsing speaker icon (louder icon + gold when value > 700). Floating "Calibrate" button.

**3D/4D Analysis:** Centre: draggable isometric voxel grid. Top-right: 5 eye toggles (Soil, Minerals, Moisture, Voids, Metals). Bottom: Depth slider + "Volumetric" switch; above them a floating AI card "Target: Metal (92%)" with a confidence bar. Brain FAB runs inference.

**File Manager:** List of surveys (name, date, grid size, spacing). Swipe to delete; actions: open, export JSON, rename.

## 3. Android/iOS setup
- Android `AndroidManifest.xml`: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` (+ `ACCESS_FINE_LOCATION` with `maxSdkVersion=30`); `minSdk 24`.
- iOS `Info.plist`: `NSBluetoothAlwaysUsageDescription`.
- Verify the `flutter_onnxruntime` calls (`createSessionFromAsset`, `OrtValue.fromList`, `run`, `asFlattenedList`, `dispose`, `close`) against the version you install; adjust names if the package changed.
- Set the BLE service/characteristic UUIDs in `ble_service.dart` to match your firmware (defaults: Nordic UART). Optional battery line: `BAT:87\r\n`.

## 4. Exporting a model for Flutter
**Your current YOLO model** (Ultralytics):
```python
from ultralytics import YOLO
YOLO("best.pt").export(format="onnx", imgsz=640, opset=12, simplify=True, dynamic=False)
```
**Custom PyTorch classifier ([1,1,64,64] -> 3 classes)**, as in your original spec:
```python
import torch
model.eval()
dummy = torch.randn(1, 1, 64, 64)
torch.onnx.export(model, dummy, "model.onnx",
    input_names=["input"], output_names=["logits"],
    opset_version=13, dynamic_axes=None)   # fixed shapes = best mobile compatibility
# apply softmax in Dart (or add nn.Softmax to the model) to get probabilities
```
Tips: use opset 12-17, avoid dynamic axes, keep float32, test with onnxruntime in Python before shipping.

## 5. Colour pipeline (matches the training images)
Colours are DATA-RELATIVE (Jet, 5 anchors): min=blue (void) -> (min+avg)/2=cyan (moisture) -> avg=green (soil)
-> (avg+max)/2=yellow -> max=red (metal). Before colouring: plane detrend + bicubic (Catmull-Rom) upsampling.
Implemented in `lib/ai/heatmap_renderer.dart` and `jetRelative()` in `grid_processor.dart`.
If detections look worse, try `HeatmapRenderer.toTensor(raw, detrend: false)`: whichever matches how the training images were made wins.
