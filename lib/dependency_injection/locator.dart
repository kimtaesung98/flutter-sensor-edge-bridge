// lib/dependency_injection/locator.dart
// Single DI registration point — SOP 준수.
// Registration order matters: Domain interfaces → Data impls → Core services → Orchestrator.

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/connectivity_orchestrator.dart';
import '../core/services/sync_service.dart';
import '../data/repositories/http_edge_transport.dart';
import '../data/repositories/sensor_buffer_repository.dart';
import '../domain/models/transmission_config.dart';
import '../domain/repositories/i_edge_transport.dart';
import '../domain/repositories/i_sensor_buffer_repository.dart';

final GetIt locator = GetIt.instance;

Future<void> setupLocator() async {
  // ── 1. SharedPreferences (already initialised in main) ───────────────────
  final prefs = await SharedPreferences.getInstance();
  locator.registerSingleton<SharedPreferences>(prefs);

  // ── 2. Persisted config ──────────────────────────────────────────────────
  final config = TransmissionConfig(
    speed: TransmissionSpeedExtension.fromStorageKey(
        prefs.getString('transmission_speed') ?? 'RT'),
    wifiOnly: prefs.getBool('wifi_only_mode') ?? false,
  );

  // ── 3. Data layer ─────────────────────────────────────────────────────────
  locator.registerSingleton<ISensorBufferRepository>(
    SensorBufferRepository(),
  );

  locator.registerSingleton<IEdgeTransport>(
    HttpEdgeTransport(
      edgeBaseUrl: prefs.getString('edge_url') ?? 'http://192.168.1.100:8080',
    ),
  );

  // ── 4. SyncService (registered BEFORE Orchestrator — Orchestrator needs it)
  final syncSvc = SyncService(
    buffer: locator<ISensorBufferRepository>(),
    transport: locator<IEdgeTransport>(),
    bgService: FlutterBackgroundService(),
    config: config,
  );
  locator.registerSingleton<SyncService>(syncSvc);

  // ── 5. ConnectivityOrchestrator ───────────────────────────────────────────
  locator.registerSingleton<ConnectivityOrchestrator>(
    ConnectivityOrchestrator(
      wearMonitor: WearLinkMonitor(),
      edgeMonitor: EdgeLinkMonitor(transport: locator<IEdgeTransport>()),
      syncController: syncSvc, // SyncService IS-A SyncServiceController
    ),
  );
}

// ── Convenience accessors (use sparingly outside DI) ─────────────────────────

ConnectivityOrchestrator get orchestrator =>
    locator<ConnectivityOrchestrator>();

SyncService get syncService => locator<SyncService>();

SharedPreferences get prefs => locator<SharedPreferences>();
