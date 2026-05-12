// lib/core/network/connectivity_orchestrator.dart
// Dual-Link monitor: Wear→Phone (BLE Companion) + Phone→Edge (HTTP ping).
// Auto-triggers SyncService — no manual button. Standby on any link drop.

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/i_edge_transport.dart';

// ─── Enums & Value Objects ────────────────────────────────────────────────────

enum LinkState { connected, disconnected, checking }

class DualLinkStatus {
  final LinkState wearToPhone;
  final LinkState phoneToEdge;

  const DualLinkStatus({
    this.wearToPhone = LinkState.checking,
    this.phoneToEdge = LinkState.checking,
  });

  bool get allConnected =>
      wearToPhone == LinkState.connected &&
      phoneToEdge == LinkState.connected;

  DualLinkStatus copyWith({
    LinkState? wearToPhone,
    LinkState? phoneToEdge,
  }) =>
      DualLinkStatus(
        wearToPhone: wearToPhone ?? this.wearToPhone,
        phoneToEdge: phoneToEdge ?? this.phoneToEdge,
      );

  @override
  String toString() =>
      'DualLinkStatus(wear→phone:$wearToPhone, phone→edge:$phoneToEdge)';
}

// ─── Abstractions ─────────────────────────────────────────────────────────────

abstract class LinkMonitor {
  Stream<LinkState> get stateStream;
  Future<void> dispose();
}

/// Implemented by SyncService in lib/core/services/sync_service.dart.
abstract class SyncServiceController {
  Future<void> startSync();
  Future<void> stopSync();
  bool get isRunning;
}

// ─── WearLinkMonitor ──────────────────────────────────────────────────────────

class WearLinkMonitor implements LinkMonitor {
  final _ctrl = StreamController<LinkState>.broadcast();
  Timer? _timer;
  LinkState _state = LinkState.disconnected;

  WearLinkMonitor() {
    _startPolling();
  }

  void _startPolling() {
    _emit(LinkState.checking);
    Future.delayed(const Duration(milliseconds: 800), () async {
      _emit(await _probe());
      _timer = Timer.periodic(const Duration(seconds: 4), (_) async {
        _emit(await _probe());
      });
    });
  }

  /// Stub — replace with MethodChannel call to WearableListenerService.
  /// e.g.: final n = await _ch.invokeMethod<int>('getWearNodeCount') ?? 0;
  ///        return n > 0 ? LinkState.connected : LinkState.disconnected;
  Future<LinkState> _probe() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return LinkState.connected; // ← replace with real probe
  }

  void injectState(LinkState s) => _emit(s);
  void _emit(LinkState s) { _state = s; _ctrl.add(s); }
  LinkState get currentState => _state;

  @override
  Stream<LinkState> get stateStream => _ctrl.stream;

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _ctrl.close();
  }
}

// ─── EdgeLinkMonitor ──────────────────────────────────────────────────────────

class EdgeLinkMonitor implements LinkMonitor {
  final IEdgeTransport transport;
  final _ctrl = StreamController<LinkState>.broadcast();
  Timer? _timer;
  LinkState _state = LinkState.disconnected;

  EdgeLinkMonitor({required this.transport}) {
    _startPinging();
  }

  void _startPinging() {
    _emit(LinkState.checking);
    Future.delayed(const Duration(milliseconds: 1200), () async {
      await _ping();
      _timer = Timer.periodic(const Duration(seconds: 6), (_) => _ping());
    });
  }

  Future<void> _ping() async {
    final ok = await transport.ping();
    _emit(ok ? LinkState.connected : LinkState.disconnected);
  }

  void injectState(LinkState s) => _emit(s);
  void _emit(LinkState s) { _state = s; _ctrl.add(s); }
  LinkState get currentState => _state;

  @override
  Stream<LinkState> get stateStream => _ctrl.stream;

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _ctrl.close();
  }
}

// ─── ConnectivityOrchestrator ─────────────────────────────────────────────────

class ConnectivityOrchestrator {
  final LinkMonitor wearMonitor;
  final LinkMonitor edgeMonitor;
  final SyncServiceController syncController;

  final _statusCtrl = StreamController<DualLinkStatus>.broadcast();
  DualLinkStatus _status = const DualLinkStatus();
  StreamSubscription<LinkState>? _wearSub;
  StreamSubscription<LinkState>? _edgeSub;

  ConnectivityOrchestrator({
    required this.wearMonitor,
    required this.edgeMonitor,
    required this.syncController,
  }) {
    _wearSub = wearMonitor.stateStream.listen((s) => _update(wearToPhone: s));
    _edgeSub = edgeMonitor.stateStream.listen((s) => _update(phoneToEdge: s));
  }

  void _update({LinkState? wearToPhone, LinkState? phoneToEdge}) {
    final prev = _status;
    _status = _status.copyWith(wearToPhone: wearToPhone, phoneToEdge: phoneToEdge);
    _statusCtrl.add(_status);
    debugPrint('[Orchestrator] $_status');

    if (!prev.allConnected && _status.allConnected) {
      syncController.startSync();
    } else if (prev.allConnected && !_status.allConnected) {
      syncController.stopSync();
    }
  }

  DualLinkStatus get currentStatus => _status;
  Stream<DualLinkStatus> get statusStream => _statusCtrl.stream;

  Future<void> dispose() async {
    await _wearSub?.cancel();
    await _edgeSub?.cancel();
    await _statusCtrl.close();
    await wearMonitor.dispose();
    await edgeMonitor.dispose();
  }
}

class NoOpSyncController implements SyncServiceController {
  bool _r = false;
  @override Future<void> startSync() async => _r = true;
  @override Future<void> stopSync() async => _r = false;
  @override bool get isRunning => _r;
}
