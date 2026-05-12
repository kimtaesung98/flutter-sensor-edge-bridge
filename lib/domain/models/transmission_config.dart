// lib/domain/models/transmission_config.dart
// Transmission policy data model — defines speed tiers, transport type, and device pairing.

import 'package:flutter/foundation.dart';

import 'transport_type.dart';

/// Enumeration of all supported transmission speed policies.
enum TransmissionSpeed {
  realTime,    // Continuous push, ~100ms flush interval
  oneSecond,   // 1 s batch flush
  threeSeconds,// 3 s batch flush
  fiveSeconds, // 5 s batch flush
}

extension TransmissionSpeedExtension on TransmissionSpeed {
  String get label {
    switch (this) {
      case TransmissionSpeed.realTime:     return 'RT (Real-time)';
      case TransmissionSpeed.oneSecond:    return '1s';
      case TransmissionSpeed.threeSeconds: return '3s';
      case TransmissionSpeed.fiveSeconds:  return '5s';
    }
  }

  int get intervalMs {
    switch (this) {
      case TransmissionSpeed.realTime:     return 100;
      case TransmissionSpeed.oneSecond:    return 1000;
      case TransmissionSpeed.threeSeconds: return 3000;
      case TransmissionSpeed.fiveSeconds:  return 5000;
    }
  }

  String get storageKey {
    switch (this) {
      case TransmissionSpeed.realTime:     return 'RT';
      case TransmissionSpeed.oneSecond:    return '1s';
      case TransmissionSpeed.threeSeconds: return '3s';
      case TransmissionSpeed.fiveSeconds:  return '5s';
    }
  }

  static TransmissionSpeed fromStorageKey(String key) {
    switch (key) {
      case '1s': return TransmissionSpeed.oneSecond;
      case '3s': return TransmissionSpeed.threeSeconds;
      case '5s': return TransmissionSpeed.fiveSeconds;
      default:   return TransmissionSpeed.realTime;
    }
  }
}

/// Immutable value object representing the active transmission policy.
@immutable
class TransmissionConfig {
  final TransmissionSpeed speed;
  final bool wifiOnly;
  final TransportType transportType;

  /// Edge server URL (used for WiFi and Wired transports).
  final String edgeServerUrl;

  /// BLE device IDs and display names for paired Wear OS / Edge devices.
  final String? wearDeviceId;
  final String? wearDeviceName;
  final String? edgeDeviceId;
  final String? edgeDeviceName;

  const TransmissionConfig({
    this.speed         = TransmissionSpeed.realTime,
    this.wifiOnly      = false,
    this.transportType = TransportType.wifi,
    this.edgeServerUrl = 'http://192.168.1.100:8080',
    this.wearDeviceId,
    this.wearDeviceName,
    this.edgeDeviceId,
    this.edgeDeviceName,
  });

  TransmissionConfig copyWith({
    TransmissionSpeed? speed,
    bool? wifiOnly,
    TransportType? transportType,
    String? edgeServerUrl,
    String? wearDeviceId,
    String? wearDeviceName,
    String? edgeDeviceId,
    String? edgeDeviceName,
  }) {
    return TransmissionConfig(
      speed:          speed          ?? this.speed,
      wifiOnly:       wifiOnly       ?? this.wifiOnly,
      transportType:  transportType  ?? this.transportType,
      edgeServerUrl:  edgeServerUrl  ?? this.edgeServerUrl,
      wearDeviceId:   wearDeviceId   ?? this.wearDeviceId,
      wearDeviceName: wearDeviceName ?? this.wearDeviceName,
      edgeDeviceId:   edgeDeviceId   ?? this.edgeDeviceId,
      edgeDeviceName: edgeDeviceName ?? this.edgeDeviceName,
    );
  }

  /// Serialize to a plain map for cross-isolate messaging and SharedPreferences.
  Map<String, dynamic> toMap() => {
        'speed':          speed.storageKey,
        'wifiOnly':       wifiOnly,
        'transportType':  transportType.storageKey,
        'edgeServerUrl':  edgeServerUrl,
        'wearDeviceId':   wearDeviceId,
        'wearDeviceName': wearDeviceName,
        'edgeDeviceId':   edgeDeviceId,
        'edgeDeviceName': edgeDeviceName,
      };

  factory TransmissionConfig.fromMap(Map<String, dynamic> map) {
    return TransmissionConfig(
      speed: TransmissionSpeedExtension.fromStorageKey(
          map['speed'] as String? ?? 'RT'),
      wifiOnly: map['wifiOnly'] as bool? ?? false,
      transportType: TransportTypeExtension.fromStorageKey(
          map['transportType'] as String? ?? 'wifi'),
      edgeServerUrl:  map['edgeServerUrl']  as String? ?? 'http://192.168.1.100:8080',
      wearDeviceId:   map['wearDeviceId']   as String?,
      wearDeviceName: map['wearDeviceName'] as String?,
      edgeDeviceId:   map['edgeDeviceId']   as String?,
      edgeDeviceName: map['edgeDeviceName'] as String?,
    );
  }

  @override
  String toString() =>
      'TransmissionConfig(transport: ${transportType.label}, '
      'speed: ${speed.label}, wifiOnly: $wifiOnly)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransmissionConfig &&
          runtimeType == other.runtimeType &&
          speed         == other.speed &&
          wifiOnly      == other.wifiOnly &&
          transportType == other.transportType &&
          edgeServerUrl == other.edgeServerUrl &&
          wearDeviceId  == other.wearDeviceId &&
          edgeDeviceId  == other.edgeDeviceId;

  @override
  int get hashCode => Object.hash(
      speed, wifiOnly, transportType, edgeServerUrl, wearDeviceId, edgeDeviceId);
}
