import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/app_state.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final ble = AppState.I.ble;
  @override
  void initState() {
    super.initState();
    ble.autoConnectLast(); // silent reconnect to the last paired device
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('TerraMag'), actions: [
          IconButton(icon: const Icon(Icons.translate), onPressed: AppState.I.toggleLocale),
        ]),
        body: StreamBuilder<List<ScanResult>>(
          stream: ble.scan(),
          builder: (_, snap) => ListView(children: [
            for (final r in snap.data ?? const <ScanResult>[])
              ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(r.device.platformName.isEmpty ? r.device.remoteId.str : r.device.platformName),
                subtitle: Text('RSSI ${r.rssi}'),
                onTap: () => ble.connect(r.device),
              ),
          ]),
        ),
      );
}
