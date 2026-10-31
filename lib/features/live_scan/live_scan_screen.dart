import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/app_state.dart';
import '../../services/ble/ble_service.dart';
import '../../widgets/thermal_bar.dart';

class LiveScanScreen extends StatefulWidget {
  const LiveScanScreen({super.key});
  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends State<LiveScanScreen> with SingleTickerProviderStateMixin {
  final s = AppState.I;
  int _value = 0;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    s.ble.samples.listen((x) => setState(() => _value = x.value));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: StreamBuilder<BleStatus>(
        stream: s.ble.status,
        builder: (_, st) => Row(children: [
          Icon(Icons.bluetooth, color: st.data == BleStatus.connected ? TM.cyan : TM.grey),
          const SizedBox(width: 8),
          Text('${st.data?.name ?? 'disconnected'}'),
          const Spacer(),
          const Icon(Icons.battery_full, size: 20),
          Text(s.ble.batteryPercent < 0 ? ' --' : ' ${s.ble.batteryPercent}%'),
        ]),
      )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {/* Smart Calibration: record ~2 s of samples, store mean as baseline offset */},
        icon: const Icon(Icons.tune), label: const Text('Calibrate'),
      ),
      body: Column(children: [
        Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: ThermalBar(value: _value)))),
        Text('$_value', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 16),
        FadeTransition(
          opacity: Tween(begin: 0.4, end: 1.0).animate(_pulse),
          child: Icon(_value > 700 ? Icons.volume_up : Icons.volume_mute,
              size: 40, color: _value > 700 ? TM.gold : TM.grey),
        ),
        const SizedBox(height: 90),
      ]),
    );
  }
}
