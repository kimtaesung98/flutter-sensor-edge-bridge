// lib/presentation/app_router.dart
// 3-screen router with AnimatedSwitcher.
// Tracks Settings entry origin so onBack returns to the correct screen.

import 'package:flutter/material.dart';

import '../core/network/connectivity_orchestrator.dart';
import '../core/network/wifi_status_service.dart';
import '../core/services/bluetooth_scan_service.dart';
import '../core/services/sync_service.dart';
import '../domain/models/transmission_config.dart';
import 'screens/admin_monitor_screen.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/settings_screen.dart';

enum _Screen { gate, admin, settings }

class AppRouter extends StatefulWidget {
  final ConnectivityOrchestrator orchestrator;
  final SyncService syncService;
  final WifiStatusService wifiStatusService;
  final BluetoothScanService bluetoothScanService;
  final TransmissionConfig initialConfig;
  final String initialAdminId;
  final String initialAdminPassword;
  final String wearDeviceName;
  final String wearOsVersion;

  const AppRouter({
    super.key,
    required this.orchestrator,
    required this.syncService,
    required this.wifiStatusService,
    required this.bluetoothScanService,
    required this.initialConfig,
    required this.initialAdminId,
    required this.initialAdminPassword,
    required this.wearDeviceName,
    required this.wearOsVersion,
  });

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  _Screen _current = _Screen.gate;
  _Screen _settingsOrigin = _Screen.gate;

  late TransmissionConfig _config;
  late String _adminId;
  late String _adminPassword;

  @override
  void initState() {
    super.initState();
    _config        = widget.initialConfig;
    _adminId       = widget.initialAdminId;
    _adminPassword = widget.initialAdminPassword;
  }

  void _goSettings(BuildContext context, _Screen origin) {
    setState(() {
      _settingsOrigin = origin;
      _current = _Screen.settings;
    });
  }

  void _backFromSettings() {
    setState(() => _current = _settingsOrigin);
  }

  void _onConfigChanged(TransmissionConfig cfg) {
    setState(() => _config = cfg);
    widget.syncService.updateConfig(cfg);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: _buildCurrent(context),
    );
  }

  Widget _buildCurrent(BuildContext context) {
    switch (_current) {
      case _Screen.gate:
        return AuthGateScreen(
          key: const ValueKey('gate'),
          orchestrator: widget.orchestrator,
          getAdminPassword: () => _adminPassword,
          onAdminUnlocked: () => setState(() => _current = _Screen.admin),
          onSettingsTap: () => _goSettings(context, _Screen.gate),
        );

      case _Screen.admin:
        return AdminMonitorScreen(
          key: const ValueKey('admin'),
          orchestrator: widget.orchestrator,
          syncService: widget.syncService,
          config: _config,
          onSettingsTap: () => _goSettings(context, _Screen.admin),
          onBack: () => setState(() => _current = _Screen.gate),
        );

      case _Screen.settings:
        return SettingsScreen(
          key: const ValueKey('settings'),
          currentConfig: _config,
          adminId: _adminId,
          wearDeviceName: widget.wearDeviceName,
          wearOsVersion: widget.wearOsVersion,
          bluetoothScanService: widget.bluetoothScanService,
          wifiStatusService: widget.wifiStatusService,
          onConfigChanged: _onConfigChanged,
          onAdminIdChanged: (id) => setState(() => _adminId = id),
          onAdminPasswordChanged: (pw) => setState(() => _adminPassword = pw),
          onBack: _backFromSettings,
        );
    }
  }
}
