import 'package:flutter/material.dart';

/// Converts the 1-D stream of readings into a 2-D matrix.
/// The surveyor walks a grid with [spacingCm] (30 or 40) between points.
/// [snake] = true for boustrophedon walking (row 0 left->right, row 1 right->left...).
class GridProcessor extends ChangeNotifier {
  int rows, cols;
  int spacingCm;
  bool snake;
  late List<List<double>> matrix; // raw 0..1023, NaN = not yet measured
  int _cursor = 0;

  GridProcessor({required this.rows, required this.cols, this.spacingCm = 30, this.snake = true}) {
    reset();
  }

  void reset() {
    matrix = List.generate(rows, (_) => List.filled(cols, double.nan));
    _cursor = 0;
    notifyListeners();
  }

  void configure({int? rows, int? cols, int? spacingCm}) {
    this.rows = rows ?? this.rows;
    this.cols = cols ?? this.cols;
    this.spacingCm = spacingCm ?? this.spacingCm;
    reset();
  }

  double get widthMeters => (cols - 1) * spacingCm / 100;
  double get heightMeters => (rows - 1) * spacingCm / 100;
  bool get isComplete => _cursor >= rows * cols;

  /// Call when the user confirms a station (or automatically per sample).
  void addReading(int value) {
    if (isComplete) return;
    final r = _cursor ~/ cols;
    var c = _cursor % cols;
    if (snake && r.isOdd) c = cols - 1 - c;
    matrix[r][c] = value.toDouble();
    _cursor++;
    notifyListeners();
  }

  /// min / average / max over measured cells (NaN ignored).
  ScanStats get stats {
    final v = matrix.expand((r) => r).where((x) => !x.isNaN).toList();
    if (v.isEmpty) return const ScanStats(0, 511.5, 1023);
    final lo = v.reduce((a, b) => a < b ? a : b);
    final hi = v.reduce((a, b) => a > b ? a : b);
    return ScanStats(lo, v.reduce((a, b) => a + b) / v.length, hi);
  }

  /// Raw matrix with unmeasured cells replaced by the average (input for the AI).
  List<List<double>> filled() {
    final avg = stats.avg;
    return [for (final r in matrix) [for (final v in r) v.isNaN ? avg : v]];
  }

  /// Min-max normalised copy (0..1). Unmeasured cells -> 0.
  /// Use fixedRange=true to normalise against the sensor range 0..1023 instead.
  List<List<double>> normalized({bool fixedRange = false}) {
    double lo = 0, hi = 1023;
    if (!fixedRange) {
      final vals = matrix.expand((r) => r).where((v) => !v.isNaN);
      if (vals.isEmpty) return List.generate(rows, (_) => List.filled(cols, 0.0));
      lo = vals.reduce((a, b) => a < b ? a : b);
      hi = vals.reduce((a, b) => a > b ? a : b);
    }
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    return [
      for (final row in matrix)
        [for (final v in row) v.isNaN ? 0.0 : ((v - lo) / span).clamp(0.0, 1.0)]
    ];
  }
}

/// Value (0..1) -> colour. Grey -> Cyan -> Gold -> Red.
Color magColor(double t) {
  t = t.clamp(0.0, 1.0);
  const stops = [
    (0.00, Color(0xFF3A4457)),
    (0.35, Color(0xFF00E5FF)),
    (0.70, Color(0xFFFFC107)),
    (1.00, Color(0xFFFF1744)),
  ];
  for (var i = 0; i < stops.length - 1; i++) {
    final (a, ca) = stops[i];
    final (b, cb) = stops[i + 1];
    if (t <= b) return Color.lerp(ca, cb, (t - a) / (b - a))!;
  }
  return stops.last.$2;
}

/// Data-relative statistics of one survey.
class ScanStats {
  final double min, avg, max;
  const ScanStats(this.min, this.avg, this.max);
}

/// Data-relative 5-anchor "Jet" palette (same logic the training images use):
/// min=blue (void) -> (min+avg)/2=cyan (moisture) -> avg=green (soil)
/// -> (avg+max)/2=yellow -> max=red (metal). Returns r,g,b in 0..1.
(double, double, double) jetRelative(double v, ScanStats s) {
  final a = [s.min, (s.min + s.avg) / 2, s.avg, (s.avg + s.max) / 2, s.max];
  const cols = [
    (0.0, 0.0, 1.0),
    (0.0, 1.0, 1.0),
    (0.0, 1.0, 0.0),
    (1.0, 1.0, 0.0),
    (1.0, 0.0, 0.0),
  ];
  if (v <= a.first) return cols.first;
  if (v >= a.last) return cols.last;
  for (var i = 1; i < a.length; i++) {
    if (v < a[i]) {
      final span = a[i] - a[i - 1];
      final t = span <= 1e-9 ? 0.0 : (v - a[i - 1]) / span;
      final (r0, g0, b0) = cols[i - 1];
      final (r1, g1, b1) = cols[i];
      return (r0 + (r1 - r0) * t, g0 + (g1 - g0) * t, b0 + (b1 - b0) * t);
    }
  }
  return cols.last;
}

Color jetRelativeColor(double v, ScanStats s) {
  final (r, g, b) = jetRelative(v, s);
  return Color.fromRGBO((r * 255).round(), (g * 255).round(), (b * 255).round(), 1);
}
