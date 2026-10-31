import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/analysis_3d/analysis_screen.dart';
import 'features/connect/connect_screen.dart';
import 'features/file_manager/file_manager_screen.dart';
import 'features/live_scan/live_scan_screen.dart';
import 'services/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TerraMagApp());
}

class TerraMagApp extends StatelessWidget {
  const TerraMagApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (_, __) => MaterialApp(
        title: 'TerraMag',
        debugShowCheckedModeBanner: false,
        theme: terraMagTheme(),
        themeMode: ThemeMode.dark, // dark by default for field visibility
        locale: AppState.I.locale, // Locale('ar') => automatic RTL
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Shell(),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String en, String arText) => ar ? arText : en;
    return Scaffold(
      body: IndexedStack(index: _i, children: const [
        ConnectScreen(),
        LiveScanScreen(),
        AnalysisScreen(),
        FileManagerScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.bluetooth), label: t('Connect', 'اتصال')),
          NavigationDestination(icon: const Icon(Icons.sensors), label: t('Live Scan', 'مسح مباشر')),
          NavigationDestination(icon: const Icon(Icons.view_in_ar), label: t('3D/4D', 'تحليل 3D/4D')),
          NavigationDestination(icon: const Icon(Icons.folder), label: t('Files', 'الملفات')),
        ],
      ),
    );
  }
}
