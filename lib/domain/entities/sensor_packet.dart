// lib/domain/entities/sensor_packet.dart
// Pure domain entity — no Flutter, no third-party imports.
// Represents one timestamped accelerometer reading from Wear OS.

class SensorPacket {
  final String id;           // UUID v4
  final DateTime timestamp;
  final double ax;           // m/s²
  final double ay;
  final double az;
  final bool transmitted;    // false = buffered in SQLite

  const SensorPacket({
    required this.id,
    required this.timestamp,
    required this.ax,
    required this.ay,
    required this.az,
    this.transmitted = false,
  });

  SensorPacket copyWith({bool? transmitted}) => SensorPacket(
        id: id,
        timestamp: timestamp,
        ax: ax,
        ay: ay,
        az: az,
        transmitted: transmitted ?? this.transmitted,
      );

  /// Flat map for SQLite row insertion.
  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'ax': ax,
        'ay': ay,
        'az': az,
        'transmitted': transmitted ? 1 : 0,
      };

  factory SensorPacket.fromMap(Map<String, dynamic> m) => SensorPacket(
        id: m['id'] as String,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
        ax: (m['ax'] as num).toDouble(),
        ay: (m['ay'] as num).toDouble(),
        az: (m['az'] as num).toDouble(),
        transmitted: (m['transmitted'] as int) == 1,
      );

  @override
  String toString() =>
      'SensorPacket($id, t=${timestamp.toIso8601String()}, '
      'ax=$ax, ay=$ay, az=$az, sent=$transmitted)';
}
