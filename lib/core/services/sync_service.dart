// lib/core/services/sync_service.dart
// Foreground-side flush engine + SyncServiceController implementation.
// Bridges UI config changes → Background Isolate via flutter_background_service.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../domain/entities/sensor_packet.dart';
import '../../domain/models/transmission_config.dart';
import '../../domain/repositories/i_edge_transport.dart';
import '../../domain/repositories/i_sensor_buffer_repository.dart';
import '../network/connectivity_orchestrator.dart';
import 'service_events.dart'; // ← 상수 전용 파일, 순환 없음

/// Result of a single flush cycle.
class FlushResult {
  final int sent;
  final int buffered;
  FlushResult({required this.sent, required this.buffered});
}

/// Foreground-side sync controller.
/// Registered as singleton in locator; used by ConnectivityOrchestrator.
class SyncService implements SyncServiceController {
  final ISensorBufferRepository _buffer;
  final IEdgeTransport _transport;
  final FlutterBackgroundService _bgService;

  TransmissionConfig _config;
  bool _running = false;

  // Broadcast stream consumed by AdminMonitorScreen
  final _packetCtrl = StreamController<SensorPacket>.broadcast();
  Stream<SensorPacket> get packetStream => _packetCtrl.stream;

  // Listen for packets forwarded from the background Isolate
  StreamSubscription? _isolatePacketSub;

  SyncService({
    required ISensorBufferRepository buffer,
    required IEdgeTransport transport,
    required FlutterBackgroundService bgService,
    TransmissionConfig config = const TransmissionConfig(),
  })  : _buffer = buffer,
        _transport = transport,
        _bgService = bgService,
        _config = config {
    _listenToIsolate();
  }

  // ── Listen to Isolate events ──────────────────────────────────────────────

  void _listenToIsolate() {
    _isolatePacketSub =
        _bgService.on(kEventPacketFlushed).listen((data) {
      if (data == null) return;
      try {
        final packet = SensorPacket(
          id: data['id'] as String,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
              data['timestamp'] as int),
          ax: (data['ax'] as num).toDouble(),
          ay: (data['ay'] as num).toDouble(),
          az: (data['az'] as num).toDouble(),
          transmitted: data['sent'] as bool? ?? false,
        );
        if (!_packetCtrl.isClosed) _packetCtrl.add(packet);
      } catch (e) {
        debugPrint('[SyncService] Isolate packet parse error: $e');
      }
    });
  }

  // ── SyncServiceController impl ────────────────────────────────────────────

  @override
  bool get isRunning => _running;

  @override
  Future<void> startSync() async {
    if (_running) return;
    _running = true;
    debugPrint('[SyncService] ▶ startSync — launching background service');
    await _bgService.startService();
    // Immediately push current config so Isolate uses correct flush interval
    _pushConfig(_config);
  }

  @override
  Future<void> stopSync() async {
    if (!_running) return;
    _running = false;
    debugPrint('[SyncService] ⏸ stopSync — signalling Isolate');
    _bgService.invoke(kEventStopService);
  }

  // ── Dynamic config hot-swap (called from SettingsScreen) ─────────────────

  /// Push updated policy to the running Isolate immediately.
  /// ConnectivityOrchestrator doesn't need to know about this — SettingsScreen
  /// calls it directly via locator<SyncService>().
  void updateConfig(TransmissionConfig config) {
    _config = config;
    debugPrint('[SyncService] Config updated: $config');
    if (_running) _pushConfig(config);
  }

  void _pushConfig(TransmissionConfig config) {
    _bgService.invoke(kEventUpdateConfig, config.toMap());
    debugPrint('[SyncService] → Config pushed to Isolate: $config');
  }

  // ── Foreground flush (fallback / test) ────────────────────────────────────

  Future<FlushResult> flush(List<SensorPacket> packets) async {
    if (packets.isEmpty) return FlushResult(sent: 0, buffered: 0);
    final ackedIds = await _transport.transmit(packets);
    await _buffer.markTransmitted(ackedIds);
    for (final p in packets) {
      if (!_packetCtrl.isClosed) {
        _packetCtrl.add(p.copyWith(transmitted: ackedIds.contains(p.id)));
      }
    }
    final buffered = await _buffer.pendingCount();
    return FlushResult(sent: ackedIds.length, buffered: buffered);
  }

  void dispose() {
    _isolatePacketSub?.cancel();
    _packetCtrl.close();
  }
}
