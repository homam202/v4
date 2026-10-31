import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';

/// One parsed sample from the ESP32.
class SensorSample {
  final int value; // 0..1023
  final DateTime t;
  SensorSample(this.value, this.t);
}

/// BLE link to the ESP32 gradiometer.
/// Protocol: ASCII lines "0..1023\r\n". Optional "BAT:87\r\n" for battery.
class BleService {
  // Nordic UART Service defaults - change to match your ESP32 firmware.
  static final Guid serviceUuid = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
  static final Guid txCharUuid = Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E'); // notify

  final _samples = StreamController<SensorSample>.broadcast();
  final _status = StreamController<BleStatus>.broadcast();
  Stream<SensorSample> get samples => _samples.stream;
  Stream<BleStatus> get status => _status.stream;

  BluetoothDevice? _device;
  StreamSubscription? _connSub, _dataSub;
  String _buffer = '';
  bool _wantConnected = false;
  int _retry = 0;
  int batteryPercent = -1;

  // ---- scanning --------------------------------------------------------
  Stream<List<ScanResult>> scan() {
    FlutterBluePlus.startScan(
      withServices: [serviceUuid],
      timeout: const Duration(seconds: 8),
    );
    return FlutterBluePlus.scanResults;
  }

  // ---- connect / auto-reconnect ---------------------------------------
  Future<void> connect(BluetoothDevice device) async {
    _wantConnected = true;
    _device = device;
    await _saveLastDevice(device.remoteId.str);
    await _openLink();
  }

  /// Call at app start: silently reconnects to the last paired device.
  Future<void> autoConnectLast() async {
    final id = await _loadLastDevice();
    if (id == null) return;
    await connect(BluetoothDevice.fromId(id));
  }

  Future<void> _openLink() async {
    final d = _device;
    if (d == null) return;
    try {
      _status.add(BleStatus.connecting);
      await FlutterBluePlus.stopScan();
      await d.connect(timeout: const Duration(seconds: 10), autoConnect: false);

      // Watch the link; on drop -> exponential back-off reconnect.
      await _connSub?.cancel();
      _connSub = d.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected && _wantConnected) {
          _status.add(BleStatus.reconnecting);
          _scheduleReconnect();
        }
      });

      final services = await d.discoverServices();
      final svc = services.firstWhere((s) => s.uuid == serviceUuid);
      final ch = svc.characteristics.firstWhere((c) => c.uuid == txCharUuid);
      await ch.setNotifyValue(true);

      await _dataSub?.cancel();
      _dataSub = ch.onValueReceived.listen(_onBytes);
      d.cancelWhenDisconnected(_dataSub!);

      _retry = 0;
      _buffer = '';
      _status.add(BleStatus.connected);
    } catch (_) {
      _status.add(BleStatus.reconnecting);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_wantConnected) return;
    final delay = Duration(seconds: (1 << _retry.clamp(0, 5))); // 1,2,4,..32 s
    _retry++;
    Timer(delay, () {
      if (_wantConnected) _openLink();
    });
  }

  Future<void> disconnect() async {
    _wantConnected = false;
    await _dataSub?.cancel();
    await _connSub?.cancel();
    await _device?.disconnect();
    _status.add(BleStatus.disconnected);
  }

  // ---- parsing ---------------------------------------------------------
  /// BLE packets may split or merge lines, so buffer until '\n'.
  void _onBytes(List<int> bytes) {
    _buffer += utf8.decode(bytes, allowMalformed: true);
    int nl;
    while ((nl = _buffer.indexOf('\n')) >= 0) {
      final line = _buffer.substring(0, nl).trim();
      _buffer = _buffer.substring(nl + 1);
      if (line.isEmpty) continue;
      if (line.startsWith('BAT:')) {
        batteryPercent = int.tryParse(line.substring(4)) ?? batteryPercent;
        continue;
      }
      final v = int.tryParse(line);
      if (v != null && v >= 0 && v <= 1023) {
        _samples.add(SensorSample(v, DateTime.now()));
      } // anything else is silently ignored (noise / partial line)
    }
  }

  // ---- last-device persistence (plain JSON file) ----------------------
  Future<File> _cfg() async =>
      File('${(await getApplicationSupportDirectory()).path}/last_device.json');
  Future<void> _saveLastDevice(String id) async =>
      (await _cfg()).writeAsString(jsonEncode({'id': id}));
  Future<String?> _loadLastDevice() async {
    final f = await _cfg();
    if (!await f.exists()) return null;
    return (jsonDecode(await f.readAsString()) as Map)['id'] as String?;
  }

  void dispose() {
    _wantConnected = false;
    _dataSub?.cancel();
    _connSub?.cancel();
    _samples.close();
    _status.close();
  }
}

enum BleStatus { disconnected, connecting, connected, reconnecting }
