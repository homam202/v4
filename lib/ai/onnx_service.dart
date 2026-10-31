import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'heatmap_renderer.dart';

/// One detected anomaly (box in 640x640 letterboxed pixel space).
class Detection {
  final int classId;
  final String label;
  final double confidence; // 0..1
  final double x1, y1, x2, y2;
  const Detection(this.classId, this.label, this.confidence, this.x1, this.y1, this.x2, this.y2);
}

class AiResult {
  final List<Detection> detections; // after NMS, sorted by confidence
  final Map<String, double> bestPerClass; // max confidence per class (for layer toggles)
  const AiResult(this.detections, this.bestPerClass);
  Detection? get top => detections.isEmpty ? null : detections.first;
}

class OnnxServiceException implements Exception {
  final String message;
  OnnxServiceException(this.message);
  @override
  String toString() => 'OnnxServiceException: $message';
}

/// Local inference for best2.onnx (Ultralytics YOLOv8 detect, 6 classes).
///   input  'images'  float32 [1,3,640,640]  RGB 0..1
///   output 'output0' float32 [1,10,8400]    rows 0-3 = cx,cy,w,h ; rows 4-9 = class scores
///   (scores are already sigmoid-ed; NMS is NOT inside the graph)
class OnnxService {
  static const modelAsset = 'assets/models/best2.onnx';
  static const inputName = 'images';
  static const outputName = 'output0';
  static const labels = ['soil', 'void', 'moisture', 'organic', 'rock', 'metal'];
  static const numAnchors = 8400;

  OrtSession? _session;
  bool _busy = false;

  bool get isReady => _session != null;

  Future<void> init() async {
    if (_session != null) return;
    try {
      _session = await OnnxRuntime().createSessionFromAsset(modelAsset);
    } catch (e) {
      throw OnnxServiceException('Failed to load model: $e');
    }
  }

  /// [raw] = 2-D matrix of RAW sensor values without NaN (use GridProcessor.filled()).
  /// Colours are computed relative to the survey's own min/avg/max inside HeatmapRenderer.
  Future<AiResult> analyze(
    List<List<double>> raw, {
    double confThreshold = 0.25,
    double iouThreshold = 0.45,
  }) async {
    if (_session == null) throw OnnxServiceException('Call init() first.');
    if (_busy) throw OnnxServiceException('Inference already running.');
    if (raw.isEmpty || raw.first.isEmpty) {
      throw OnnxServiceException('Empty matrix.');
    }
    _busy = true;

    OrtValue? input;
    Map<String, OrtValue>? outputs;
    try {
      // a+b+c) detrend + bicubic + relative-Jet heatmap -> flat Float32List, NCHW order (heavy loop: run off the UI isolate)
      final Float32List tensor = await compute(_buildTensor, raw);

      // c) shape [1,3,640,640]
      input = await OrtValue.fromList(tensor, [1, 3, HeatmapRenderer.size, HeatmapRenderer.size]);

      // d) inference
      outputs = await _session!.run({inputName: input});
      final out = outputs[outputName];
      if (out == null) throw OnnxServiceException('Missing output "$outputName".');

      // e) read probabilities: flat length must be 10 * 8400
      final raw = await out.asFlattenedList();
      if (raw.length != (4 + labels.length) * numAnchors) {
        throw OnnxServiceException('Unexpected output size ${raw.length}.');
      }
      final flat = Float32List.fromList(raw.map((e) => (e as num).toDouble()).toList());
      return _decode(flat, confThreshold, iouThreshold);
    } on OnnxServiceException {
      rethrow;
    } catch (e) {
      throw OnnxServiceException('Inference failed: $e');
    } finally {
      // Always free native memory, even on error.
      await input?.dispose();
      if (outputs != null) {
        for (final v in outputs.values) {
          await v.dispose();
        }
      }
      _busy = false;
    }
  }

  Future<void> dispose() async {
    await _session?.close();
    _session = null;
  }

  // ---- helpers ---------------------------------------------------------
  static Float32List _buildTensor(List<List<double>> m) => HeatmapRenderer.toTensor(m);

  /// Output layout is channel-major: value(c, i) = flat[c * 8400 + i].
  static AiResult _decode(Float32List f, double conf, double iou) {
    final cand = <Detection>[];
    final best = {for (final l in labels) l: 0.0};
    for (var i = 0; i < numAnchors; i++) {
      var cls = 0;
      var score = f[4 * numAnchors + i];
      for (var c = 1; c < labels.length; c++) {
        final s = f[(4 + c) * numAnchors + i];
        if (s > score) {
          score = s;
          cls = c;
        }
      }
      if (score < conf) continue;
      final cx = f[i], cy = f[numAnchors + i];
      final w = f[2 * numAnchors + i], h = f[3 * numAnchors + i];
      cand.add(Detection(cls, labels[cls], score, cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2));
      if (score > best[labels[cls]]!) best[labels[cls]] = score;
    }
    return AiResult(_nms(cand, iou), best);
  }

  static List<Detection> _nms(List<Detection> d, double iouThr) {
    d.sort((a, b) => b.confidence.compareTo(a.confidence));
    final keep = <Detection>[];
    for (final c in d) {
      if (keep.every((k) => k.classId != c.classId || _iou(k, c) < iouThr)) keep.add(c);
      if (keep.length >= 50) break;
    }
    return keep;
  }

  static double _iou(Detection a, Detection b) {
    final ix = math.max(0.0, math.min(a.x2, b.x2) - math.max(a.x1, b.x1));
    final iy = math.max(0.0, math.min(a.y2, b.y2) - math.max(a.y1, b.y1));
    final inter = ix * iy;
    final u = (a.x2 - a.x1) * (a.y2 - a.y1) + (b.x2 - b.x1) * (b.y2 - b.y1) - inter;
    return u <= 0 ? 0 : inter / u;
  }
}
