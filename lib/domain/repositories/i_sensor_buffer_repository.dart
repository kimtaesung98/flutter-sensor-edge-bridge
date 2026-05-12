// lib/domain/repositories/i_sensor_buffer_repository.dart
// Interface only — Domain layer must not know about SQLite or any library.

import '../entities/sensor_packet.dart';

/// Persistent local buffer for sensor packets that couldn't be transmitted.
abstract class ISensorBufferRepository {
  /// Persist a packet into the local buffer.
  Future<void> save(SensorPacket packet);

  /// Return all untransmitted packets in chronological order.
  Future<List<SensorPacket>> getPending();

  /// Mark a list of packet IDs as successfully transmitted.
  Future<void> markTransmitted(List<String> ids);

  /// Delete all transmitted packets (housekeeping).
  Future<void> pruneTransmitted();

  /// Current count of buffered (untransmitted) packets.
  Future<int> pendingCount();
}
