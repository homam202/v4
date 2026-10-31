import 'dart:typed_data';
import '../features/analysis_3d/grid_processor.dart' show ScanStats, jetRelative;

/// Matrix (RAW sensor values, no NaN) -> YOLO tensor float32 NCHW [1,3,640,640], RGB 0..1.
/// Pipeline: optional plane detrend -> bicubic upsampling -> data-relative Jet colours
/// -> letterbox (grey 114/255), matching Ultralytics preprocessing.
class HeatmapRenderer {
  static const int size = 640;

  static Float32List toTensor(List<List<double>> raw, {bool detrend = true}) {
    var m = detrend ? removePlane(raw) : raw;
    final rows = m.length, cols = m.first.length;

    // Statistics AFTER detrending, because colours are relative to them.
    final flat = m.expand((r) => r).toList();
    final lo = flat.reduce((a, b) => a < b ? a : b);
    final hi = flat.reduce((a, b) => a > b ? a : b);
    final avg = flat.reduce((a, b) => a + b) / flat.length;
    final stats = ScanStats(lo, avg, hi);

    final scale = (size / cols) < (size / rows) ? size / cols : size / rows;
    final w = (cols * scale).round(), h = (rows * scale).round();
    final x0 = (size - w) ~/ 2, y0 = (size - h) ~/ 2;

    const pad = 114 / 255.0;
    final plane = size * size;
    final out = Float32List(3 * plane)..fillRange(0, 3 * plane, pad);

    for (var y = 0; y < h; y++) {
      final fy = ((y + 0.5) / scale - 0.5).clamp(0.0, rows - 1.0);
      for (var x = 0; x < w; x++) {
        final fx = ((x + 0.5) / scale - 0.5).clamp(0.0, cols - 1.0);
        final v = _bicubic(m, fy, fx).clamp(lo, hi); // clamp kills overshoot
        final (r, g, b) = jetRelative(v, stats);
        final p = (y0 + y) * size + (x0 + x);
        out[p] = r;
        out[plane + p] = g;
        out[2 * plane + p] = b;
      }
    }
    return out;
  }

  /// Least-squares plane z = a*x + b*y + c is subtracted (the mean is kept),
  /// removing a uniform tilt/gradient so local anomalies stand out.
  static List<List<double>> removePlane(List<List<double>> m) {
    final rows = m.length, cols = m.first.length;
    final xm = (cols - 1) / 2, ym = (rows - 1) / 2;
    double mean = 0, sxz = 0, syz = 0, sxx = 0, syy = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        mean += m[r][c];
      }
    }
    mean /= rows * cols;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final dx = c - xm, dy = r - ym, dz = m[r][c] - mean;
        sxz += dx * dz; syz += dy * dz; sxx += dx * dx; syy += dy * dy;
      }
    }
    final a = sxx == 0 ? 0.0 : sxz / sxx, b = syy == 0 ? 0.0 : syz / syy;
    return [
      for (var r = 0; r < rows; r++)
        [for (var c = 0; c < cols; c++) m[r][c] - a * (c - xm) - b * (r - ym)]
    ];
  }

  // Catmull-Rom cubic interpolation on a 4x4 neighbourhood.
  static double _cr(double t, double p0, double p1, double p2, double p3) =>
      0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
          (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t);

  static double _bicubic(List<List<double>> m, double fy, double fx) {
    final rows = m.length, cols = m.first.length;
    final iy = fy.floor(), ix = fx.floor();
    final ty = fy - iy, tx = fx - ix;
    final col = List<double>.filled(4, 0);
    for (var j = -1; j <= 2; j++) {
      final r = (iy + j).clamp(0, rows - 1);
      double g(int dx) => m[r][(ix + dx).clamp(0, cols - 1)];
      col[j + 1] = _cr(tx, g(-1), g(0), g(1), g(2));
    }
    return _cr(ty, col[0], col[1], col[2], col[3]);
  }
}
