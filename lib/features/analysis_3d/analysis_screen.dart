import 'package:flutter/material.dart';
import '../../ai/onnx_service.dart';
import '../../services/app_state.dart';
import 'grid_processor.dart';
import '../../widgets/ai_overlay_card.dart';
import '../../widgets/iso_grid_painter.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});
  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final s = AppState.I;
  double depth = 1, rot = 0.6;
  bool volumetric = false, loading = false;
  String? error;
  AiResult? result;
  // Layer visibility: Soil, Minerals(rock+organic), Moisture, Voids, Metals
  final layers = {'soil': true, 'rock': true, 'moisture': true, 'void': true, 'metal': true};

  Future<void> _runAi() async {
    setState(() { loading = true; error = null; });
    try {
      await s.onnx.init();
      result = await s.onnx.analyze(s.grid.filled());
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D / 4D Analysis'), actions: [
        for (final e in layers.entries)
          IconButton(
            tooltip: e.key,
            icon: Icon(e.value ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => layers[e.key] = !e.value),
          ),
      ]),
      body: Stack(children: [
        GestureDetector(
          onPanUpdate: (d) => setState(() => rot += d.delta.dx * 0.01),
          child: ListenableBuilder(
            listenable: s.grid,
            builder: (_, __) => CustomPaint(
              size: Size.infinite,
              painter: IsoGridPainter(s.grid.normalized(),
                  depthSpacing: depth, volumetric: volumetric, rotation: rot,
                  colorOf: (v) {
                    final st = s.grid.stats; // same palette as the AI heat-map
                    return jetRelativeColor(st.min + v * (st.max - st.min), st);
                  }),
            ),
          ),
        ),
        Positioned(left: 12, right: 12, bottom: 8, child: Column(mainAxisSize: MainAxisSize.min, children: [
          AiOverlayCard(result: result, loading: loading, error: error),
          Row(children: [
            const Icon(Icons.layers), 
            Expanded(child: Slider(value: depth, min: 0.2, max: 2, onChanged: (v) => setState(() => depth = v))),
            const Text('Volumetric'),
            Switch(value: volumetric, onChanged: (v) => setState(() => volumetric = v)),
          ]),
        ])),
      ]),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 150),
        child: FloatingActionButton(onPressed: _runAi, child: const Icon(Icons.psychology)),
      ),
    );
  }
}
