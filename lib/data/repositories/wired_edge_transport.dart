// lib/data/repositories/wired_edge_transport.dart
// Wired (USB/Ethernet) transport — HTTP over a non-WiFi network interface.
// Falls back gracefully to same HTTP mechanism as WiFi transport.

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/sensor_packet.dart';
import '../../domain/repositories/i_edge_transport.dart';

class WiredEdgeTransport implements IEdgeTransport {
  final String edgeBaseUrl;
  final Duration timeout;

  WiredEdgeTransport({
    required this.edgeBaseUrl,
    this.timeout = const Duration(seconds: 5),
  });

  /// Returns true when the device has an ethernet/USB-tethering connection.
  Future<bool> _isWiredAvailable() async {
    try {
      final results = await Connectivity().checkConnectivity();
      // ConnectivityResult.ethernet covers USB tethering & real ethernet adapters
      return results.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false; // graceful degradation — still attempt HTTP
    }
  }

  @override
  Future<List<String>> transmit(List<SensorPacket> packets) async {
    if (packets.isEmpty) return [];
    final wired = await _isWiredAvailable();
    if (!wired) {
      debugPrint('[WiredTransport] No wired interface detected — skipping flush');
      return [];
    }
    try {
      final payload  = packets.map((p) => p.toMap()).toList();
      final response = await http
          .post(
            Uri.parse('$edgeBaseUrl/ingest'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'packets': payload}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final body  = jsonDecode(response.body) as Map<String, dynamic>;
        final acked = (body['acked'] as List?)?.cast<String>();
        return acked ?? packets.map((p) => p.id).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[WiredTransport] transmit error: $e');
      return [];
    }
  }

  @override
  Future<bool> ping() async {
    final wired = await _isWiredAvailable();
    if (!wired) return false;
    try {
      final response = await http
          .head(Uri.parse('$edgeBaseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
