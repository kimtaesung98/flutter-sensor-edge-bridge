// lib/domain/repositories/i_edge_transport.dart
// Abstraction for the Phone→Edge transmission channel.
// Concrete implementation (HTTP/MQTT) lives in lib/data/.

import '../entities/sensor_packet.dart';

abstract class IEdgeTransport {
  /// Send a batch of packets to the edge server.
  /// Returns the list of IDs that were successfully acknowledged.
  Future<List<String>> transmit(List<SensorPacket> packets);

  /// Lightweight reachability probe (used by EdgeLinkMonitor).
  Future<bool> ping();
}
