// lib/dependency_injection/locator.dart
// Single DI registration point.
// Registration order: Domain interfaces → Data impls → Core services → Orchestrator.

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/connectivity_orchestrator.dart';
import '../core/network/wifi_status_service.dart';
import '../core/services/bluetooth_scan_service.dart';
import '../core/services/sync_service.dart';
import '../data/repositories/bluetooth_edge_transport.dart';
import '../data/repositories/http_edge_transport.dart';
import '../data/repositories/sensor_buffer_repository.dart';
import '../data/repositories/wired_edge_transport.dart';
import '../domain/models/transmission_config.dart';
import '../domain/models/transport_type.dart';
import '../domain/repositories/i_edge_transport.dart';
import '../domain/repositories/i_sensor_buffer_repository.dart';

final GetIt locator = GetIt.instance;

Future<void> setupLocator() async {
  // ── 1. SharedPreferences ──────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  locator.registerSingleton<SharedPreferences>(prefs);

  // ── 2. Persisted config ───────────────────────────────────────────────────
  final config = TransmissionConfig(
    speed: TransmissionSpeedExtension.fromStorageKey(
        prefs.getString('transmission_speed') ?? 'RT'),
    wifiOnly:      prefs.getBool('wifi_only_mode') ?? false,
    transportType: TransportTypeExtension.fromStorageKey(
        prefs.getString('transport_type') ?? 'wifi'),
    edgeServerUrl: prefs.getString('edge_url') ?? 'http://192.168.1.100:8080',
    wearDeviceId:   prefs.getString('wear_device_id'),
    wearDeviceName: prefs.getString('wear_device_name'),
    edgeDeviceId:   prefs.getString('edge_device_id'),
    edgeDeviceName: prefs.getString('edge_device_name'),
  );

  // ── 3. Buffer repository ──────────────────────────────────────────────────
  locator.registerSingleton<ISensorBufferRepository>(
    SensorBufferRepository(),
  );

  // ── 4. Edge transport (selected by config) ────────────────────────────────
  locator.registerSingleton<IEdgeTransport>(
    _buildTransport(config),
  );

  // ── 5. SyncService ────────────────────────────────────────────────────────
  final syncSvc = SyncService(
    buffer:    locator<ISensorBufferRepository>(),
    transport: locator<IEdgeTransport>(),
    bgService: FlutterBackgroundService(),
    config:    config,
  );
  locator.registerSingleton<SyncService>(syncSvc);

  // ── 6. ConnectivityOrchestrator ───────────────────────────────────────────
  locator.registerSingleton<ConnectivityOrchestrator>(
    ConnectivityOrchestrator(
      wearMonitor: WearLinkMonitor(),
      edgeMonitor: EdgeLinkMonitor(transport: locator<IEdgeTransport>()),
      syncController: syncSvc,
    ),
  );

  // ── 7. WiFi status service ────────────────────────────────────────────────
  locator.registerSingleton<WifiStatusService>(WifiStatusService());

  // ── 8. Bluetooth scan service ─────────────────────────────────────────────
  locator.registerSingleton<BluetoothScanService>(BluetoothScanService());
}

/// Build the correct IEdgeTransport implementation from the active config.
IEdgeTransport _buildTransport(TransmissionConfig config) {
  switch (config.transportType) {
    case TransportType.bluetooth:
      return BluetoothEdgeTransport(
        edgeDeviceId: config.edgeDeviceId ?? '',
      );
    case TransportType.wired:
      return WiredEdgeTransport(edgeBaseUrl: config.edgeServerUrl);
    case TransportType.wifi:
    default:
      return HttpEdgeTransport(edgeBaseUrl: config.edgeServerUrl);
  }
}

// ── Convenience accessors ─────────────────────────────────────────────────────

ConnectivityOrchestrator get orchestrator =>
    locator<ConnectivityOrchestrator>();

SyncService          get syncService      => locator<SyncService>();
WifiStatusService    get wifiStatus       => locator<WifiStatusService>();
BluetoothScanService get bluetoothScanner => locator<BluetoothScanService>();
SharedPreferences    get prefs            => locator<SharedPreferences>();
