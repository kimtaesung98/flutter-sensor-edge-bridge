// lib/domain/models/transport_type.dart
// Transport channel selection for Wear→Phone→Edge relay.

enum TransportType { wifi, bluetooth, wired }

extension TransportTypeExtension on TransportType {
  String get label {
    switch (this) {
      case TransportType.wifi:      return 'Wi-Fi';
      case TransportType.bluetooth: return 'Bluetooth';
      case TransportType.wired:     return 'Wired (USB/Ethernet)';
    }
  }

  String get storageKey {
    switch (this) {
      case TransportType.wifi:      return 'wifi';
      case TransportType.bluetooth: return 'bluetooth';
      case TransportType.wired:     return 'wired';
    }
  }

  static TransportType fromStorageKey(String key) {
    switch (key) {
      case 'bluetooth': return TransportType.bluetooth;
      case 'wired':     return TransportType.wired;
      default:          return TransportType.wifi;
    }
  }
}
