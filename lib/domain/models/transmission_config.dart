// lib/domain/models/transmission_config.dart
// Transmission policy data model — defines speed tiers and WiFi-only mode.

import 'package:flutter/foundation.dart';

/// Enumeration of all supported transmission speed policies.
enum TransmissionSpeed {
  realTime, // Continuous push, ~100ms flush interval
  oneSecond, // 1 s batch flush
  threeSeconds, // 3 s batch flush
  fiveSeconds, // 5 s batch flush
}

extension TransmissionSpeedExtension on TransmissionSpeed {
  /// Human-readable label shown in UI dropdowns / settings.
  String get label {
    switch (this) {
      case TransmissionSpeed.realTime:
        return 'RT (Real-time)';
      case TransmissionSpeed.oneSecond:
        return '1s';
      case TransmissionSpeed.threeSeconds:
        return '3s';
      case TransmissionSpeed.fiveSeconds:
        return '5s';
    }
  }

  /// Flush interval in milliseconds used by SyncService.
  int get intervalMs {
    switch (this) {
      case TransmissionSpeed.realTime:
        return 100;
      case TransmissionSpeed.oneSecond:
        return 1000;
      case TransmissionSpeed.threeSeconds:
        return 3000;
      case TransmissionSpeed.fiveSeconds:
        return 5000;
    }
  }

  /// SharedPreferences storage key value.
  String get storageKey {
    switch (this) {
      case TransmissionSpeed.realTime:
        return 'RT';
      case TransmissionSpeed.oneSecond:
        return '1s';
      case TransmissionSpeed.threeSeconds:
        return '3s';
      case TransmissionSpeed.fiveSeconds:
        return '5s';
    }
  }

  static TransmissionSpeed fromStorageKey(String key) {
    switch (key) {
      case '1s':
        return TransmissionSpeed.oneSecond;
      case '3s':
        return TransmissionSpeed.threeSeconds;
      case '5s':
        return TransmissionSpeed.fiveSeconds;
      default:
        return TransmissionSpeed.realTime;
    }
  }
}

/// Immutable value object representing the active transmission policy.
@immutable
class TransmissionConfig {
  final TransmissionSpeed speed;
  final bool wifiOnly;

  const TransmissionConfig({
    this.speed = TransmissionSpeed.realTime,
    this.wifiOnly = false,
  });

  TransmissionConfig copyWith({
    TransmissionSpeed? speed,
    bool? wifiOnly,
  }) {
    return TransmissionConfig(
      speed: speed ?? this.speed,
      wifiOnly: wifiOnly ?? this.wifiOnly,
    );
  }

  /// Serialize to a plain map for cross-isolate SendPort messaging.
  Map<String, dynamic> toMap() => {
        'speed': speed.storageKey,
        'wifiOnly': wifiOnly,
      };

  factory TransmissionConfig.fromMap(Map<String, dynamic> map) {
    return TransmissionConfig(
      speed: TransmissionSpeedExtension.fromStorageKey(
          map['speed'] as String? ?? 'RT'),
      wifiOnly: map['wifiOnly'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'TransmissionConfig(speed: ${speed.label}, wifiOnly: $wifiOnly)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransmissionConfig &&
          runtimeType == other.runtimeType &&
          speed == other.speed &&
          wifiOnly == other.wifiOnly;

  @override
  int get hashCode => Object.hash(speed, wifiOnly);
}
