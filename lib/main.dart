// lib/main.dart
// App entry point:
//   1. Init background service (registers Android foreground service)
//   2. Setup DI locator (registers all singletons)
//   3. Load persisted config + admin credentials
//   4. Launch AppRouter

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/services/background_service_handler.dart';
import 'dependency_injection/locator.dart';
import 'domain/models/transmission_config.dart';
import 'presentation/app_router.dart';
import 'presentation/screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF060A10),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await initializeBackgroundService();
  await setupLocator();

  final config        = await SettingsPersistence.loadConfig();
  final adminId       = await SettingsPersistence.loadAdminId();
  final adminPassword = await SettingsPersistence.loadAdminPassword();

  runApp(SensorBridgeApp(
    config: config,
    adminId: adminId,
    adminPassword: adminPassword,
  ));
}

class SensorBridgeApp extends StatelessWidget {
  final TransmissionConfig config;
  final String adminId;
  final String adminPassword;

  const SensorBridgeApp({
    super.key,
    required this.config,
    required this.adminId,
    required this.adminPassword,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Bridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00B4FF),
          secondary: Color(0xFF00FF94),
          error: Color(0xFFFF3B5C),
          surface: Color(0xFF111827),
          background: Color(0xFF0A0E1A),
        ),
        fontFamily: 'monospace',
      ),
      home: AppRouter(
        orchestrator:         orchestrator,
        syncService:          syncService,
        wifiStatusService:    wifiStatus,
        bluetoothScanService: bluetoothScanner,
        initialConfig:        config,
        initialAdminId:       adminId,
        initialAdminPassword: adminPassword,
        wearDeviceName: config.wearDeviceName ?? 'Not paired',
        wearOsVersion:  'Wear OS 4.0',
      ),
    );
  }
}
