import 'package:flutter/material.dart';
import '../ai/onnx_service.dart';
import '../core/theme/app_theme.dart';

class AiOverlayCard extends StatelessWidget {
  final AiResult? result;
  final bool loading;
  final String? error;
  const AiOverlayCard({super.key, this.result, this.loading = false, this.error});

  @override
  Widget build(BuildContext context) {
    final top = result?.top;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const LinearProgressIndicator()
            : error != null
                ? Text(error!, style: const TextStyle(color: TM.hot))
                : top == null
                    ? const Text('No anomaly detected')
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          'Target: ${top.label[0].toUpperCase()}${top.label.substring(1)} '
                          '(${(top.confidence * 100).round()}%)',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: TM.gold),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: top.confidence, minHeight: 10,
                            color: TM.gold, backgroundColor: Colors.white12),
                        ),
                      ]),
      ),
    );
  }
}
