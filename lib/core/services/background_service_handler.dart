// lib/core/services/background_service_handler.dart
// @pragma('vm:entry-point') Isolate — MUST use package: imports, not relative.
// Re-initialises its own SQLite + HTTP deps (Isolate has no shared memory).
// Receives config via invoke(kEventUpdateConfig), emits packets via invoke(kEventPacketFlushed).

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

// ✅ package: imports — safe in both main Isolate and background Isolate
import 'package:sensor_bridge/domain/entities/sensor_packet.dart';
import 'package:sensor_bridge/domain/models/transmission_config.dart';
import 'package:sensor_bridge/core/services/service_events.dart';

// ─── Public init — call from main() before runApp() ───────────────────────────

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false, // ConnectivityOrchestrator controls lifecycle
      notificationChannelId: 'sensor_bridge_channel',
      initialNotificationTitle: 'Sensor Bridge',
      initialNotificationContent: 'Standby — awaiting connection',
      foregroundServiceNotificationId: 1001,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: _iosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> _iosBackground(ServiceInstance service) async => true;

// ─── Isolate entry point ───────────────────────────────────────────────────────

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // ── Re-init deps in this Isolate ──────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();

  TransmissionConfig config = TransmissionConfig(
    speed: TransmissionSpeedExtension.fromStorageKey(
        prefs.getString('transmission_speed') ?? 'RT'),
    wifiOnly:      prefs.getBool('wifi_only_mode') ?? false,
    edgeServerUrl: prefs.getString('edge_url') ?? 'http://192.168.1.100:8080',
  );

  // Isolate uses edgeServerUrl from config (supports WiFi & Wired HTTP transports).
  // Bluetooth transport is handled by the foreground layer via BluetoothEdgeTransport.
  final edgeUrl = config.edgeServerUrl;

  final dbPath = p.join(await getDatabasesPath(), 'sensor_bridge.db');
  final db = await openDatabase(
    dbPath,
    version: 1,
    onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS packets (
          id          TEXT PRIMARY KEY,
          timestamp   INTEGER NOT NULL,
          ax          REAL NOT NULL,
          ay          REAL NOT NULL,
          az          REAL NOT NULL,
          transmitted INTEGER NOT NULL DEFAULT 0
        )
      ''');
    },
  );

  final rng = Random();
  Timer? flushTimer;
  int pendingCount = 0;

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<List<SensorPacket>> _getPending() async {
    final rows = await db.query(
      'packets',
      where: 'transmitted = 0',
      orderBy: 'timestamp ASC',
      limit: 200,
    );
    return rows.map(SensorPacket.fromMap).toList();
  }

  Future<List<String>> _transmit(List<SensorPacket> packets) async {
    if (packets.isEmpty) return [];
    try {
      final res = await http
          .post(
            Uri.parse('$edgeUrl/ingest'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {'packets': packets.map((p) => p.toMap()).toList()}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final acked = (body['acked'] as List?)?.cast<String>();
        return acked ?? packets.map((p) => p.id).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<int> _pendingCount() async {
    final r = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM packets WHERE transmitted = 0');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  // ── Flush timer ────────────────────────────────────────────────────────────

  void startFlushTimer() {
    flushTimer?.cancel();
    final intervalMs = config.speed.intervalMs;
    // Clamp minimum 100ms to avoid CPU spin
    final dur = Duration(milliseconds: intervalMs < 100 ? 100 : intervalMs);
    debugPrint('[BgIsolate] Flush interval: ${dur.inMilliseconds}ms');

    flushTimer = Timer.periodic(dur, (_) async {
      // Simulate sensor read — replace with real BLE/WearOS data
      final packet = SensorPacket(
        id: '${DateTime.now().millisecondsSinceEpoch}_${rng.nextInt(9999)}',
        timestamp: DateTime.now(),
        ax: (rng.nextDouble() * 4) - 2,
        ay: (rng.nextDouble() * 4) - 2,
        az: 9.8 + (rng.nextDouble() * 0.4 - 0.2),
      );

      // Write-ahead: persist before transmit
      await db.insert('packets', packet.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      // Attempt batch transmission
      final pending = await _getPending();
      final ackedIds = await _transmit(pending);
      final bool sent = ackedIds.contains(packet.id);

      if (ackedIds.isNotEmpty) {
        final ph = List.filled(ackedIds.length, '?').join(',');
        await db.rawUpdate(
            'UPDATE packets SET transmitted = 1 WHERE id IN ($ph)',
            ackedIds);
        // Prune transmitted rows to keep DB lean
        await db.delete('packets', where: 'transmitted = 1');
      }

      pendingCount = await _pendingCount();

      // ── Notify UI (foreground Isolate) via invoke ────────────────────────
      service.invoke(kEventPacketFlushed, {
        'id': packet.id,
        'timestamp': packet.timestamp.millisecondsSinceEpoch,
        'ax': packet.ax,
        'ay': packet.ay,
        'az': packet.az,
        'bufferCount': pendingCount,
        'sent': sent,
      });

      // ── Update foreground notification ───────────────────────────────────
      if (service is AndroidServiceInstance) {
        (service as AndroidServiceInstance).setForegroundNotificationInfo(
          title: 'Sensor Bridge — Active',
          content:
              'Policy: ${config.speed.label} | Buffer: $pendingCount pkts',
        );
      }
    });
  }

  // ── Event: config hot-swap from UI ────────────────────────────────────────
  service.on(kEventUpdateConfig).listen((data) {
    if (data == null) return;
    config = TransmissionConfig.fromMap(Map<String, dynamic>.from(data));
    debugPrint('[BgIsolate] Config hot-swapped → $config');
    startFlushTimer(); // restart with new interval immediately
  });

  // ── Event: graceful stop from UI ─────────────────────────────────────────
  service.on(kEventStopService).listen((_) {
    debugPrint('[BgIsolate] Stop signal received');
    flushTimer?.cancel();
    service.stopSelf();
  });

  // ── Boot ──────────────────────────────────────────────────────────────────
  startFlushTimer();
}
