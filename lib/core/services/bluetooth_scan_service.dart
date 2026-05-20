// lib/core/services/bluetooth_scan_service.dart
// BLE device discovery, connection management, and Wear OS pairing.
// Uses flutter_blue_plus with a prefix import to avoid enum name collision.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';

class BleDevice {
  final String id;
  final String name;
  final int rssi;

  const BleDevice({required this.id, required this.name, required this.rssi});

  String get displayName => name.isEmpty ? id : name;

  @override
  String toString() => 'BleDevice($displayName, rssi: $rssi)';
}

// Our own state enum — avoids collision with fbp.BluetoothAdapterState.
enum BtAdapterState { unknown, unavailable, off, on }

// ─── Error type returned by startScan ────────────────────────────────────────
enum BtScanError { none, permissionDenied, adapterOff, unavailable }

class BluetoothScanService {
  final _devicesCtrl = StreamController<List<BleDevice>>.broadcast();
  final _stateCtrl   = StreamController<BtAdapterState>.broadcast();
  final _errorCtrl   = StreamController<BtScanError>.broadcast();

  final List<BleDevice> _discovered = [];
  StreamSubscription? _scanSub;
  StreamSubscription? _adapterSub;

  bool         _isScanning  = false;
  BtAdapterState _adapterState = BtAdapterState.unknown;

  BluetoothScanService() {
    fbp.FlutterBluePlus.setLogLevel(fbp.LogLevel.error);
    _listenAdapterState();
  }

  // ── Public streams ────────────────────────────────────────────────────────

  Stream<List<BleDevice>> get devicesStream     => _devicesCtrl.stream;
  Stream<BtAdapterState>  get adapterStateStream => _stateCtrl.stream;
  Stream<BtScanError>     get errorStream        => _errorCtrl.stream;

  List<BleDevice> get discovered    => List.unmodifiable(_discovered);
  bool            get isScanning    => _isScanning;
  BtAdapterState  get adapterState  => _adapterState;

  // ── Adapter state listener (uses fbp prefix to resolve enum collision) ────

  void _listenAdapterState() {
    _adapterSub = fbp.FlutterBluePlus.adapterState.listen(
      (fbp.BluetoothAdapterState fbpState) {
        final mapped = switch (fbpState) {
          fbp.BluetoothAdapterState.on          => BtAdapterState.on,
          fbp.BluetoothAdapterState.off         => BtAdapterState.off,
          fbp.BluetoothAdapterState.unavailable => BtAdapterState.unavailable,
          _                                     => BtAdapterState.unknown,
        };
        _adapterState = mapped;
        debugPrint('[BtScan] Adapter state → $mapped');
        if (!_stateCtrl.isClosed) _stateCtrl.add(mapped);
      },
      onError: (e) => debugPrint('[BtScan] adapterState error: $e'),
    );
  }

  // ── Turn on Bluetooth (requests system dialog on Android) ─────────────────

  Future<void> requestEnableBluetooth() async {
    try {
      await fbp.FlutterBluePlus.turnOn();
    } catch (e) {
      debugPrint('[BtScan] turnOn error: $e');
    }
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> checkAndRequestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final allGranted = statuses.values.every((s) => s.isGranted);
    debugPrint('[BtScan] Permissions granted: $allGranted — $statuses');
    return allGranted;
  }

  Future<bool> arePermissionsGranted() async {
    final scan    = await Permission.bluetoothScan.isGranted;
    final connect = await Permission.bluetoothConnect.isGranted;
    final loc     = await Permission.locationWhenInUse.isGranted;
    return scan && connect && loc;
  }

  // ── Scan ──────────────────────────────────────────────────────────────────

  Future<BtScanError> startScan({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_isScanning) return BtScanError.none;

    // 1. Check adapter
    if (_adapterState == BtAdapterState.unavailable) {
      _errorCtrl.add(BtScanError.unavailable);
      return BtScanError.unavailable;
    }
    if (_adapterState == BtAdapterState.off) {
      await requestEnableBluetooth();
      // Give the adapter a moment to come up
      await Future.delayed(const Duration(milliseconds: 800));
      if (_adapterState != BtAdapterState.on) {
        _errorCtrl.add(BtScanError.adapterOff);
        return BtScanError.adapterOff;
      }
    }

    // 2. Permissions
    final granted = await checkAndRequestPermissions();
    if (!granted) {
      _errorCtrl.add(BtScanError.permissionDenied);
      return BtScanError.permissionDenied;
    }

    _discovered.clear();
    _isScanning = true;
    if (!_devicesCtrl.isClosed) _devicesCtrl.add([]);

    try {
      // Listen to results BEFORE calling startScan so we don't miss early results
      _scanSub = fbp.FlutterBluePlus.onScanResults.listen(
        (results) {
          for (final r in results) {
            final dev = BleDevice(
              id:   r.device.remoteId.str,
              name: r.device.platformName,
              rssi: r.rssi,
            );
            final idx = _discovered.indexWhere((d) => d.id == dev.id);
            if (idx == -1) {
              _discovered.add(dev);
            } else {
              _discovered[idx] = dev;
            }
          }
          if (!_devicesCtrl.isClosed) _devicesCtrl.add(List.from(_discovered));
        },
        onError: (e) => debugPrint('[BtScan] scanResults error: $e'),
      );

      await fbp.FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      // Auto-stop
      Future.delayed(timeout, () async {
        if (_isScanning) await stopScan();
      });

      return BtScanError.none;
    } catch (e) {
      debugPrint('[BtScan] startScan error: $e');
      _isScanning = false;
      return BtScanError.permissionDenied;
    }
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await fbp.FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  // ── Connect ───────────────────────────────────────────────────────────────

  Future<fbp.BluetoothDevice?> connectById(String deviceId) async {
    try {
      final device = fbp.BluetoothDevice.fromId(deviceId);
      await device.connect(
          autoConnect: false, timeout: const Duration(seconds: 8));
      debugPrint('[BtScan] Connected to $deviceId');
      return device;
    } catch (e) {
      debugPrint('[BtScan] Connect failed for $deviceId: $e');
      return null;
    }
  }

  Future<void> disconnect(String deviceId) async {
    try {
      await fbp.BluetoothDevice.fromId(deviceId).disconnect();
    } catch (_) {}
  }

  bool isConnected(String deviceId) => fbp.FlutterBluePlus.connectedDevices
      .any((d) => d.remoteId.str == deviceId);

  void dispose() {
    stopScan();
    _adapterSub?.cancel();
    _devicesCtrl.close();
    _stateCtrl.close();
    _errorCtrl.close();
  }
}
