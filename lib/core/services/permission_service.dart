// lib/core/services/permission_service.dart
// Runtime permission management for Sensor Bridge.
// Handles Location, Bluetooth, and Notification permissions.

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingComplete = 'onboarding_complete';
const _kPrivacyConsent     = 'privacy_consent_given';
const _kDataConsent        = 'data_collection_consent_given';

// ─── Permission group definitions ─────────────────────────────────────────────

enum AppPermission {
  location,
  bluetoothScan,
  bluetoothConnect,
  notification,
}

extension AppPermissionExtension on AppPermission {
  String get title {
    switch (this) {
      case AppPermission.location:         return '위치 (Location)';
      case AppPermission.bluetoothScan:    return '블루투스 검색';
      case AppPermission.bluetoothConnect: return '블루투스 연결';
      case AppPermission.notification:     return '알림 (Notification)';
    }
  }

  String get description {
    switch (this) {
      case AppPermission.location:
        return 'Wi-Fi SSID 조회 및 BLE 기기 위치 기반 검색에 필요합니다.';
      case AppPermission.bluetoothScan:
        return 'Wear OS 및 Edge 기기를 검색하는 데 필요합니다.';
      case AppPermission.bluetoothConnect:
        return '페어링된 기기와 데이터를 교환하는 데 필요합니다.';
      case AppPermission.notification:
        return '백그라운드 서비스 상태를 알림으로 표시하는 데 필요합니다.';
    }
  }

  Permission get _handler {
    switch (this) {
      case AppPermission.location:         return Permission.locationWhenInUse;
      case AppPermission.bluetoothScan:    return Permission.bluetoothScan;
      case AppPermission.bluetoothConnect: return Permission.bluetoothConnect;
      case AppPermission.notification:     return Permission.notification;
    }
  }

  Future<PermissionStatus> get status => _handler.status;
  Future<PermissionStatus> request()  => _handler.request();
}

// ─── PermissionService ────────────────────────────────────────────────────────

class PermissionService {
  static const _allPermissions = AppPermission.values;

  // ── Onboarding / consent flags ────────────────────────────────────────────

  static Future<bool> isOnboardingComplete() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kOnboardingComplete) ?? false;
  }

  static Future<void> markOnboardingComplete() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOnboardingComplete, true);
  }

  static Future<void> saveConsents({
    required bool privacy,
    required bool dataCollection,
  }) async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setBool(_kPrivacyConsent, privacy),
      p.setBool(_kDataConsent,    dataCollection),
    ]);
  }

  static Future<bool> hasPrivacyConsent() async =>
      (await SharedPreferences.getInstance()).getBool(_kPrivacyConsent) ?? false;

  static Future<bool> hasDataConsent() async =>
      (await SharedPreferences.getInstance()).getBool(_kDataConsent) ?? false;

  // ── Permission checks ─────────────────────────────────────────────────────

  /// Returns true only when every required permission is granted.
  static Future<bool> allGranted() async {
    for (final p in _allPermissions) {
      final s = await p.status;
      if (!s.isGranted) return false;
    }
    return true;
  }

  /// Returns current status map for all permissions.
  static Future<Map<AppPermission, PermissionStatus>> statusMap() async {
    final result = <AppPermission, PermissionStatus>{};
    for (final p in _allPermissions) {
      result[p] = await p.status;
    }
    return result;
  }

  /// Request a single permission and return the resulting status.
  static Future<PermissionStatus> requestOne(AppPermission perm) async {
    final status = await perm.request();
    debugPrint('[PermissionService] ${perm.title}: $status');
    return status;
  }

  /// Request all permissions sequentially and return the status map.
  static Future<Map<AppPermission, PermissionStatus>> requestAll() async {
    final result = <AppPermission, PermissionStatus>{};
    for (final p in _allPermissions) {
      result[p] = await p.request();
    }
    return result;
  }

  /// Open app settings (for permanently denied permissions).
  static Future<void> openSettings() => openAppSettings();
}
