import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../features/analysis_3d/grid_processor.dart';

/// Lightweight isometric voxel view (no 3D engine needed).
/// [matrix] normalised 0..1; [depthSpacing] scales bar height;
/// [volumetric] = true -> translucent cells so deep anomalies show through.
class IsoGridPainter extends CustomPainter {
  final List<List<double>> matrix;
  final double depthSpacing; // 0.2 .. 2.0
  final bool volumetric;
  final double rotation; // radians, driven by a drag gesture
  final Color Function(double)? colorOf; // value 0..1 -> colour (defaults to magColor)
  IsoGridPainter(this.matrix,
      {this.depthSpacing = 1, this.volumetric = false, this.rotation = 0.6, this.colorOf});

  @override
  void paint(Canvas canvas, Size size) {
    final rows = matrix.length, cols = matrix.first.length;
    final cell = math.min(size.width, size.height) / (rows + cols) * 1.4;
    final origin = Offset(size.width / 2, size.height * 0.25);
    final cr = math.cos(rotation), sr = math.sin(rotation);

    Offset proj(double x, double y, double z) {
      final rx = x * cr - y * sr, ry = x * sr + y * cr; // rotate about vertical axis
      return origin + Offset((rx - ry) * cell * 0.87, (rx + ry) * cell * 0.5 - z);
    }

    // Painter's algorithm: draw far cells first.
    final order = <(int, int, double)>[
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < cols; c++)
          (r, c, (c - cols / 2) * sr + (r - rows / 2) * cr + (c - cols / 2) * cr)
    ]..sort((a, b) => a.$3.compareTo(b.$3));

    for (final (r, c, _) in order) {
      final v = matrix[r][c];
      final h = (v * cell * 4 * depthSpacing).clamp(1.0, 400.0);
      final x = c - cols / 2, y = r - rows / 2;
      final base = (colorOf ?? magColor)(v).withOpacity(volumetric ? 0.35 : 1);
      final top = [proj(x, y, h), proj(x + 1, y, h), proj(x + 1, y + 1, h), proj(x, y + 1, h)];
      final side = [proj(x + 1, y, h), proj(x + 1, y + 1, h), proj(x + 1, y + 1, 0), proj(x + 1, y, 0)];
      _poly(canvas, side, Color.lerp(base, Colors.black, 0.35)!);
      _poly(canvas, top, base);
    }
  }

  void _poly(Canvas canvas, List<Offset> p, Color color) {
    final path = Path()..addPolygon(p, true);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.black26);
  }

  @override
  bool shouldRepaint(IsoGridPainter o) => true;
}
