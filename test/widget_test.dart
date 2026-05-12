import 'package:flutter_test/flutter_test.dart';

import 'package:sensor_bridge/domain/entities/sensor_packet.dart';
import 'package:sensor_bridge/domain/models/transmission_config.dart';

void main() {
  group('TransmissionConfig', () {
    test('default values', () {
      const config = TransmissionConfig();
      expect(config.speed, TransmissionSpeed.realTime);
      expect(config.wifiOnly, false);
    });

    test('copyWith preserves unchanged fields', () {
      const config = TransmissionConfig(
        speed: TransmissionSpeed.fiveSeconds,
        wifiOnly: true,
      );
      final updated = config.copyWith(wifiOnly: false);
      expect(updated.speed, TransmissionSpeed.fiveSeconds);
      expect(updated.wifiOnly, false);
    });

    test('round-trips through toMap / fromMap', () {
      const original = TransmissionConfig(
        speed: TransmissionSpeed.threeSeconds,
        wifiOnly: true,
      );
      final copy = TransmissionConfig.fromMap(original.toMap());
      expect(copy, original);
    });

    test('equality and hashCode', () {
      const a = TransmissionConfig(speed: TransmissionSpeed.oneSecond);
      const b = TransmissionConfig(speed: TransmissionSpeed.oneSecond);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('SensorPacket', () {
    test('toMap / fromMap round-trip', () {
      final packet = SensorPacket(
        id: 'test-id',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1_000_000),
        ax: 1.0,
        ay: -0.5,
        az: 9.8,
        transmitted: false,
      );
      final copy = SensorPacket.fromMap(packet.toMap());
      expect(copy.id, packet.id);
      expect(copy.timestamp, packet.timestamp);
      expect(copy.ax, packet.ax);
      expect(copy.ay, packet.ay);
      expect(copy.az, packet.az);
      expect(copy.transmitted, packet.transmitted);
    });

    test('copyWith updates transmitted flag', () {
      final packet = SensorPacket(
        id: 'test-id',
        timestamp: DateTime.now(),
        ax: 0,
        ay: 0,
        az: 9.8,
      );
      final acked = packet.copyWith(transmitted: true);
      expect(acked.transmitted, true);
      expect(acked.id, packet.id);
    });
  });

  group('TransmissionSpeed', () {
    test('intervalMs values', () {
      expect(TransmissionSpeed.realTime.intervalMs, 100);
      expect(TransmissionSpeed.oneSecond.intervalMs, 1000);
      expect(TransmissionSpeed.threeSeconds.intervalMs, 3000);
      expect(TransmissionSpeed.fiveSeconds.intervalMs, 5000);
    });

    test('fromStorageKey round-trip', () {
      for (final speed in TransmissionSpeed.values) {
        expect(
          TransmissionSpeedExtension.fromStorageKey(speed.storageKey),
          speed,
        );
      }
    });
  });
}
