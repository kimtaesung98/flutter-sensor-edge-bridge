// lib/core/network/wifi_status_service.dart
// Real-time WiFi connectivity and SSID monitoring.
// Uses connectivity_plus + network_info_plus.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiStatus {
  final bool connected;
  final String ssid;
  final String ipAddress;

  const WifiStatus({
    this.connected = false,
    this.ssid      = '',
    this.ipAddress = '',
  });

  static const disconnected = WifiStatus();
}

class WifiStatusService {
  final _statusCtrl = StreamController<WifiStatus>.broadcast();
  StreamSubscription? _connectivitySub;
  WifiStatus _current = WifiStatus.disconnected;

  WifiStatusService() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((_) => _refresh());
    _refresh(); // initial probe
  }

  Stream<WifiStatus> get statusStream => _statusCtrl.stream;
  WifiStatus         get current      => _current;

  Future<void> _refresh() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (!results.contains(ConnectivityResult.wifi)) {
        _emit(WifiStatus.disconnected);
        return;
      }

      // SSID requires location permission on Android 8+
      final locGranted = await Permission.locationWhenInUse.isGranted;
      String ssid = '';
      String ip   = '';

      if (locGranted) {
        final info = NetworkInfo();
        ssid = (await info.getWifiName()) ?? '';
        ip   = (await info.getWifiIP())   ?? '';
        // Strip surrounding quotes that Android sometimes adds
        if (ssid.startsWith('"') && ssid.endsWith('"')) {
          ssid = ssid.substring(1, ssid.length - 1);
        }
        // Android 10+ returns '<unknown ssid>' when location services are
        // globally disabled even if the permission is granted.
        if (ssid == '<unknown ssid>' || ssid == 'unknown ssid') {
          ssid = '(위치 서비스를 활성화하면 SSID가 표시됩니다)';
        }
      } else {
        ssid = '(위치 권한 필요 — 권한 탭에서 허용하세요)';
      }

      _emit(WifiStatus(connected: true, ssid: ssid, ipAddress: ip));
    } catch (e) {
      debugPrint('[WifiStatus] refresh error: $e');
      _emit(WifiStatus.disconnected);
    }
  }

  void _emit(WifiStatus s) {
    _current = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  Future<void> refresh() => _refresh();

  void dispose() {
    _connectivitySub?.cancel();
    _statusCtrl.close();
  }
}
