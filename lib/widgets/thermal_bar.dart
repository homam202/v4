import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Large animated vertical bar, Grey -> Red, value 0..1023.
class ThermalBar extends StatelessWidget {
  final int value;
  const ThermalBar({super.key, required this.value});
  @override
  Widget build(BuildContext context) {
    final t = (value / 1023).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (_, c) {
      return Container(
        width: 72,
        height: c.maxHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: Colors.white24, width: 2),
          gradient: const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [TM.grey, Color(0xFFFFC107), TM.hot],
          ),
        ),
        child: Stack(children: [
          // Dim everything above the current level.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            top: 0, left: 0, right: 0,
            height: c.maxHeight * (1 - t),
            child: Container(
              decoration: BoxDecoration(
                color: TM.navy.withOpacity(0.85),
                borderRadius: BorderRadius.circular(36),
              ),
            ),
          ),
        ]),
      );
    });
  }
}
