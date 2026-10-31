import 'package:flutter/material.dart';
import '../ai/onnx_service.dart';
import '../features/analysis_3d/grid_processor.dart';
import 'ble/ble_service.dart';

/// Tiny app-wide container (swap for Riverpod/Provider if you prefer).
class AppState extends ChangeNotifier {
  AppState._();
  static final I = AppState._();

  final ble = BleService();
  final grid = GridProcessor(rows: 16, cols: 16, spacingCm: 30);
  final onnx = OnnxService();

  Locale locale = const Locale('en');
  void toggleLocale() {
    locale = locale.languageCode == 'en' ? const Locale('ar') : const Locale('en');
    notifyListeners();
  }
}
