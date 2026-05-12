// lib/core/services/bluetooth_scan_service.dart
// BLE device discovery, connection management, and Wear OS pairing.
// Uses flutter_blue_plus. Registered as singleton in locator.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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

enum BluetoothAdapterState { unknown, unavailable, off, on }

class BluetoothScanService {
  final _devicesCtrl = StreamController<List<BleDevice>>.broadcast();
  final _stateCtrl   = StreamController<BluetoothAdapterState>.broadcast();

  final List<BleDevice> _discovered = [];
  StreamSubscription? _scanSub;
  StreamSubscription? _adapterSub;

  bool _isScanning = false;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  BluetoothScanService() {
    _listenAdapterState();
  }

  // ── Public streams ────────────────────────────────────────────────────────

  Stream<List<BleDevice>> get devicesStream  => _devicesCtrl.stream;
  Stream<BluetoothAdapterState> get adapterStateStream => _stateCtrl.stream;

  List<BleDevice> get discovered     => List.unmodifiable(_discovered);
  bool            get isScanning     => _isScanning;
  BluetoothAdapterState get adapterState => _adapterState;

  // ── Adapter state ─────────────────────────────────────────────────────────

  void _listenAdapterState() {
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      BluetoothAdapterState mapped;
      switch (state) {
        case BluetoothAdapterState.on:
          mapped = BluetoothAdapterState.on;
          break;
        case BluetoothAdapterState.off:
          mapped = BluetoothAdapterState.off;
          break;
        case BluetoothAdapterState.unavailable:
          mapped = BluetoothAdapterState.unavailable;
          break;
        default:
          mapped = BluetoothAdapterState.unknown;
      }
      _adapterState = mapped;
      if (!_stateCtrl.isClosed) _stateCtrl.add(mapped);
    });
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  // ── Scan ──────────────────────────────────────────────────────────────────

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isScanning) return;
    final granted = await requestPermissions();
    if (!granted) {
      debugPrint('[BtScan] Permissions denied — cannot scan');
      return;
    }
    _discovered.clear();
    _isScanning = true;

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
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
            _discovered[idx] = dev; // refresh RSSI
          }
        }
        if (!_devicesCtrl.isClosed) _devicesCtrl.add(List.from(_discovered));
      });

      // Auto-stop after timeout
      Future.delayed(timeout, stopScan);
    } catch (e) {
      debugPrint('[BtScan] startScan error: $e');
      _isScanning = false;
    }
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  // ── Connect to a specific device ──────────────────────────────────────────

  /// Returns a connected BluetoothDevice or null on failure.
  Future<BluetoothDevice?> connectById(String deviceId) async {
    try {
      final device = BluetoothDevice.fromId(deviceId);
      await device.connect(autoConnect: false,
          timeout: const Duration(seconds: 8));
      debugPrint('[BtScan] Connected to $deviceId');
      return device;
    } catch (e) {
      debugPrint('[BtScan] Connect failed for $deviceId: $e');
      return null;
    }
  }

  Future<void> disconnect(String deviceId) async {
    try {
      final device = BluetoothDevice.fromId(deviceId);
      await device.disconnect();
    } catch (_) {}
  }

  /// Check whether a device is currently connected.
  bool isConnected(String deviceId) {
    return FlutterBluePlus.connectedDevices
        .any((d) => d.remoteId.str == deviceId);
  }

  void dispose() {
    stopScan();
    _adapterSub?.cancel();
    _devicesCtrl.close();
    _stateCtrl.close();
  }
}
