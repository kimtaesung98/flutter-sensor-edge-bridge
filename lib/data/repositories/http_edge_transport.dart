// lib/data/repositories/http_edge_transport.dart
// Concrete HTTP transport to the edge server.
// Replace edgeBaseUrl with your actual endpoint.

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../domain/entities/sensor_packet.dart';
import '../../domain/repositories/i_edge_transport.dart';

class HttpEdgeTransport implements IEdgeTransport {
  final String edgeBaseUrl;
  final Duration timeout;

  HttpEdgeTransport({
    required this.edgeBaseUrl,
    this.timeout = const Duration(seconds: 5),
  });

  @override
  Future<List<String>> transmit(List<SensorPacket> packets) async {
    if (packets.isEmpty) return [];
    try {
      final payload = packets.map((p) => p.toMap()).toList();
      final response = await http
          .post(
            Uri.parse('$edgeBaseUrl/ingest'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'packets': payload}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        // Edge server returns { "acked": ["id1","id2",...] }
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final acked = (body['acked'] as List?)?.cast<String>();
        // If edge doesn't return acked list, assume all sent successfully.
        return acked ?? packets.map((p) => p.id).toList();
      }
      return []; // non-200 → nothing acked, keep in buffer
    } catch (_) {
      return []; // network error → nothing acked
    }
  }

  @override
  Future<bool> ping() async {
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
