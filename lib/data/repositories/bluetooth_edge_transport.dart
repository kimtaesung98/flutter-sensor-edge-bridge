// lib/data/repositories/bluetooth_edge_transport.dart
// BLE-based IEdgeTransport implementation.
// Sends batched sensor packets over a GATT write characteristic.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

import '../../domain/entities/sensor_packet.dart';
import '../../domain/repositories/i_edge_transport.dart';

// Custom GATT UUIDs shared with the edge-side receiver firmware/app.
const _kServiceUuid        = '0000ffe0-0000-1000-8000-00805f9b34fb';
const _kTxCharacteristicUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

class BluetoothEdgeTransport implements IEdgeTransport {
  final String edgeDeviceId;
  fbp.BluetoothDevice? _device;
  fbp.BluetoothCharacteristic? _txChar;

  BluetoothEdgeTransport({required this.edgeDeviceId});

  // ── Connection management ─────────────────────────────────────────────────

  Future<bool> _ensureConnected() async {
    // Already connected and characteristic resolved
    if (_txChar != null &&
        fbp.FlutterBluePlus.connectedDevices
            .any((d) => d.remoteId.str == edgeDeviceId)) {
      return true;
    }
    try {
      _device = fbp.BluetoothDevice.fromId(edgeDeviceId);
      await _device!.connect(
          autoConnect: false, timeout: const Duration(seconds: 6));

      final services = await _device!.discoverServices();
      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() == _kServiceUuid) {
          for (final ch in svc.characteristics) {
            if (ch.uuid.toString().toLowerCase() == _kTxCharacteristicUuid) {
              _txChar = ch;
              debugPrint('[BtTransport] GATT TX characteristic found');
              return true;
            }
          }
        }
      }
      debugPrint('[BtTransport] Service/characteristic not found on device');
      return false;
    } catch (e) {
      debugPrint('[BtTransport] Connect/discover error: $e');
      _txChar = null;
      return false;
    }
  }

  // ── IEdgeTransport impl ───────────────────────────────────────────────────

  @override
  Future<List<String>> transmit(List<SensorPacket> packets) async {
    if (packets.isEmpty) return [];
    final connected = await _ensureConnected();
    if (!connected || _txChar == null) return [];

    final ackedIds = <String>[];
    try {
      // Split into 512-byte chunks (BLE MTU safe limit)
      final payload = jsonEncode({'packets': packets.map((p) => p.toMap()).toList()});
      final bytes   = utf8.encode(payload);
      const chunkSize = 512;

      for (var i = 0; i < bytes.length; i += chunkSize) {
        final end   = (i + chunkSize).clamp(0, bytes.length);
        final chunk = bytes.sublist(i, end);
        await _txChar!.write(chunk, withoutResponse: false);
      }
      // Assume all acked on successful write (BLE is point-to-point)
      ackedIds.addAll(packets.map((p) => p.id));
    } catch (e) {
      debugPrint('[BtTransport] Write error: $e');
      _txChar = null; // force reconnect on next attempt
    }
    return ackedIds;
  }

  @override
  Future<bool> ping() async {
    if (edgeDeviceId.isEmpty) return false;
    return fbp.FlutterBluePlus.connectedDevices
        .any((d) => d.remoteId.str == edgeDeviceId);
  }
}
