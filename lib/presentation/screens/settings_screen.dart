// lib/presentation/screens/settings_screen.dart
// Admin Settings — transport selection, Bluetooth pairing, WiFi status,
// transmission policy, and security controls.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/wifi_status_service.dart';
import '../../core/services/bluetooth_scan_service.dart';
import '../../domain/models/transmission_config.dart';
import '../../domain/models/transport_type.dart';

// ─── SharedPreferences keys ───────────────────────────────────────────────────
const kKeySpeed          = 'transmission_speed';
const kKeyWifiOnly       = 'wifi_only_mode';
const kKeyAdminPw        = 'admin_password';
const kKeyAdminId        = 'admin_id';
const kKeyEdgeUrl        = 'edge_url';
const kKeyTransportType  = 'transport_type';
const kKeyWearDeviceId   = 'wear_device_id';
const kKeyWearDeviceName = 'wear_device_name';
const kKeyEdgeDeviceId   = 'edge_device_id';
const kKeyEdgeDeviceName = 'edge_device_name';

// ─── Persistence helper ───────────────────────────────────────────────────────

class SettingsPersistence {
  static Future<TransmissionConfig> loadConfig() async {
    final p = await SharedPreferences.getInstance();
    return TransmissionConfig(
      speed:          TransmissionSpeedExtension.fromStorageKey(p.getString(kKeySpeed) ?? 'RT'),
      wifiOnly:       p.getBool(kKeyWifiOnly) ?? false,
      transportType:  TransportTypeExtension.fromStorageKey(p.getString(kKeyTransportType) ?? 'wifi'),
      edgeServerUrl:  p.getString(kKeyEdgeUrl) ?? 'http://192.168.1.100:8080',
      wearDeviceId:   p.getString(kKeyWearDeviceId),
      wearDeviceName: p.getString(kKeyWearDeviceName),
      edgeDeviceId:   p.getString(kKeyEdgeDeviceId),
      edgeDeviceName: p.getString(kKeyEdgeDeviceName),
    );
  }

  static Future<void> saveConfig(TransmissionConfig cfg) async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setString(kKeySpeed,         cfg.speed.storageKey),
      p.setBool(  kKeyWifiOnly,      cfg.wifiOnly),
      p.setString(kKeyTransportType, cfg.transportType.storageKey),
      p.setString(kKeyEdgeUrl,       cfg.edgeServerUrl),
      if (cfg.wearDeviceId   != null) p.setString(kKeyWearDeviceId,   cfg.wearDeviceId!),
      if (cfg.wearDeviceName != null) p.setString(kKeyWearDeviceName, cfg.wearDeviceName!),
      if (cfg.edgeDeviceId   != null) p.setString(kKeyEdgeDeviceId,   cfg.edgeDeviceId!),
      if (cfg.edgeDeviceName != null) p.setString(kKeyEdgeDeviceName, cfg.edgeDeviceName!),
    ]);
  }

  static Future<String> loadAdminPassword() async =>
      (await SharedPreferences.getInstance()).getString(kKeyAdminPw) ?? 'admin1234';

  static Future<void> saveAdminPassword(String pw) async =>
      (await SharedPreferences.getInstance()).setString(kKeyAdminPw, pw);

  static Future<String> loadAdminId() async =>
      (await SharedPreferences.getInstance()).getString(kKeyAdminId) ?? 'admin';

  static Future<void> saveAdminId(String id) async =>
      (await SharedPreferences.getInstance()).setString(kKeyAdminId, id);
}

// ─── Theme tokens ─────────────────────────────────────────────────────────────
const _bg          = Color(0xFF0A0E1A);
const _panel       = Color(0xFF111827);
const _border      = Color(0xFF1E2D40);
const _neonGreen   = Color(0xFF00FF94);
const _neonBlue    = Color(0xFF00B4FF);
const _neonRed     = Color(0xFFFF3B5C);
const _neonAmber   = Color(0xFFFFBB00);
const _textPrimary = Color(0xFFE2E8F0);
const _textSec     = Color(0xFF64748B);
const _textMuted   = Color(0xFF3D5068);

// ─── Screen ───────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  final TransmissionConfig currentConfig;
  final String adminId;
  final String wearDeviceName;
  final String wearOsVersion;
  final BluetoothScanService bluetoothScanService;
  final WifiStatusService wifiStatusService;
  final void Function(TransmissionConfig) onConfigChanged;
  final void Function(String) onAdminIdChanged;
  final void Function(String) onAdminPasswordChanged;
  final VoidCallback onBack;

  const SettingsScreen({
    super.key,
    required this.currentConfig,
    required this.adminId,
    required this.wearDeviceName,
    required this.wearOsVersion,
    required this.bluetoothScanService,
    required this.wifiStatusService,
    required this.onConfigChanged,
    required this.onAdminIdChanged,
    required this.onAdminPasswordChanged,
    required this.onBack,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TransmissionConfig _config;
  late String _adminId;

  // WiFi state
  WifiStatus _wifiStatus = WifiStatus.disconnected;

  // Bluetooth state
  List<BleDevice> _bleDevices = [];
  bool _isScanning = false;
  BluetoothAdapterState _btState = BluetoothAdapterState.unknown;

  // Connection test state
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _config   = widget.currentConfig;
    _adminId  = widget.adminId;
    _wifiStatus = widget.wifiStatusService.current;
    _btState    = widget.bluetoothScanService.adapterState;

    widget.wifiStatusService.statusStream.listen((s) {
      if (mounted) setState(() => _wifiStatus = s);
    });

    widget.bluetoothScanService.devicesStream.listen((devs) {
      if (mounted) setState(() => _bleDevices = devs);
    });

    widget.bluetoothScanService.adapterStateStream.listen((s) {
      if (mounted) setState(() => _btState = s);
    });
  }

  // ── Config change helpers ─────────────────────────────────────────────────

  Future<void> _updateConfig(TransmissionConfig next) async {
    setState(() => _config = next);
    await SettingsPersistence.saveConfig(next);
    widget.onConfigChanged(next);
  }

  // ── Transport type ────────────────────────────────────────────────────────

  Future<void> _setTransportType(TransportType t) async {
    HapticFeedback.selectionClick();
    await _updateConfig(_config.copyWith(transportType: t));
    if (t == TransportType.wifi) widget.wifiStatusService.refresh();
  }

  // ── Speed ─────────────────────────────────────────────────────────────────

  Future<void> _setSpeed(TransmissionSpeed s) async {
    HapticFeedback.selectionClick();
    await _updateConfig(_config.copyWith(speed: s));
  }

  // ── WiFi only toggle ──────────────────────────────────────────────────────

  Future<void> _setWifiOnly(bool v) async {
    await _updateConfig(_config.copyWith(wifiOnly: v));
  }

  // ── Edge URL dialog ───────────────────────────────────────────────────────

  void _showEditEdgeUrlDialog() {
    final ctrl = TextEditingController(text: _config.edgeServerUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: _dialogShape(_neonGreen),
        title: const Text('EDGE SERVER URL',
            style: TextStyle(color: _neonGreen, fontFamily: 'monospace',
                fontSize: 13, letterSpacing: 2)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: _textPrimary, fontFamily: 'monospace', fontSize: 12),
          decoration: _fieldDecoration('http://192.168.x.x:8080', _neonGreen),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: _textSec)),
          ),
          _NeonButton(
            label: 'SAVE',
            color: _neonGreen,
            onTap: () async {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) {
                await _updateConfig(_config.copyWith(edgeServerUrl: url));
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
              _toast('Edge URL saved');
            },
          ),
        ],
      ),
    );
  }

  // ── Connection test ───────────────────────────────────────────────────────

  Future<void> _testConnection() async {
    setState(() { _testing = true; _testResult = null; });
    // Simple HTTP HEAD to the configured edge server
    try {
      final uri = Uri.parse('${_config.edgeServerUrl}/health');
      final response = await Future.any([
        () async {
          final r = await _httpHead(uri);
          return r;
        }(),
        Future.delayed(const Duration(seconds: 4), () => -1),
      ]);
      setState(() {
        _testResult = (response as int) > 0 && response < 500
            ? '✅  Reachable (HTTP ${response})'
            : '❌  Unreachable';
      });
    } catch (_) {
      setState(() => _testResult = '❌  Connection failed');
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<int> _httpHead(Uri uri) async {
    try {
      // Use http package via platform channel equivalent (dart:io HttpClient)
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.headUrl(uri);
      final response = await request.close();
      client.close();
      return response.statusCode;
    } catch (_) {
      return -1;
    }
  }

  // ── Bluetooth scan ────────────────────────────────────────────────────────

  Future<void> _startBtScan() async {
    if (_isScanning) {
      await widget.bluetoothScanService.stopScan();
      setState(() => _isScanning = false);
      return;
    }
    setState(() { _isScanning = true; _bleDevices = []; });
    await widget.bluetoothScanService.startScan(
        timeout: const Duration(seconds: 12));
    if (mounted) setState(() => _isScanning = false);
  }

  void _showDevicePickerDialog({required bool forWear}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.95, end: 1.0)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, __) {
        final role   = forWear ? 'WEAR DEVICE' : 'EDGE DEVICE';
        final color  = forWear ? _neonGreen : _neonBlue;
        final devices = List<BleDevice>.from(_bleDevices);

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 340,
              constraints: const BoxConstraints(maxHeight: 480),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.4)),
                boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 32)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Icon(forWear ? Icons.watch : Icons.router, color: color, size: 16),
                  const SizedBox(width: 8),
                  Text('SELECT $role',
                      style: TextStyle(color: color, fontSize: 11,
                          letterSpacing: 2, fontFamily: 'monospace',
                          fontWeight: FontWeight.w700)),
                ]),
                Divider(color: color.withOpacity(0.2), height: 18),
                if (devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      _isScanning ? 'Scanning...' : 'No devices found.\nTap SCAN first.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _textSec,
                          fontFamily: 'monospace', fontSize: 12, height: 1.6),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      itemBuilder: (_, i) {
                        final dev = devices[i];
                        final isSel = forWear
                            ? _config.wearDeviceId == dev.id
                            : _config.edgeDeviceId == dev.id;
                        return GestureDetector(
                          onTap: () async {
                            if (forWear) {
                              await _updateConfig(_config.copyWith(
                                  wearDeviceId: dev.id, wearDeviceName: dev.displayName));
                            } else {
                              await _updateConfig(_config.copyWith(
                                  edgeDeviceId: dev.id, edgeDeviceName: dev.displayName));
                            }
                            HapticFeedback.selectionClick();
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            _toast('${dev.displayName} set as $role');
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? color.withOpacity(0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSel ? color.withOpacity(0.5) : _border),
                            ),
                            child: Row(children: [
                              Icon(Icons.bluetooth, color: isSel ? color : _textMuted, size: 14),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(dev.displayName,
                                    style: TextStyle(
                                        color: isSel ? color : _textPrimary,
                                        fontSize: 12, fontFamily: 'monospace',
                                        fontWeight: isSel ? FontWeight.w700 : FontWeight.normal)),
                                Text(dev.id, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: _textSec, fontSize: 9, fontFamily: 'monospace')),
                              ])),
                              Text('${dev.rssi} dBm',
                                  style: const TextStyle(color: _textSec, fontSize: 9, fontFamily: 'monospace')),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('CLOSE', style: TextStyle(color: _textSec)),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ── Security dialogs ──────────────────────────────────────────────────────

  void _showChangePasswordDialog() {
    final curCtrl  = TextEditingController();
    final newCtrl  = TextEditingController();
    final conCtrl  = TextEditingController();
    String? errMsg;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, __) {
        return StatefulBuilder(builder: (ctx, setDS) {
          Future<void> submit() async {
            final current = await SettingsPersistence.loadAdminPassword();
            if (curCtrl.text != current) {
              setDS(() => errMsg = 'Current password is incorrect');
              return;
            }
            if (newCtrl.text.length < 6) {
              setDS(() => errMsg = 'New password must be ≥ 6 chars');
              return;
            }
            if (newCtrl.text != conCtrl.text) {
              setDS(() => errMsg = 'Passwords do not match');
              return;
            }
            await SettingsPersistence.saveAdminPassword(newCtrl.text);
            widget.onAdminPasswordChanged(newCtrl.text);
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
              _toast('Password updated successfully');
            }
          }

          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 340,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _neonRed.withOpacity(0.45)),
                  boxShadow: [BoxShadow(color: _neonRed.withOpacity(0.12), blurRadius: 32)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _DialogHeader(label: 'CHANGE PASSWORD', color: _neonRed),
                  const SizedBox(height: 16),
                  _PwField(controller: curCtrl, hint: 'Current password'),
                  const SizedBox(height: 10),
                  _PwField(controller: newCtrl, hint: 'New password (≥ 6 chars)'),
                  const SizedBox(height: 10),
                  _PwField(controller: conCtrl, hint: 'Confirm new password'),
                  if (errMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(errMsg!, style: const TextStyle(color: _neonRed,
                        fontFamily: 'monospace', fontSize: 11)),
                  ],
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('CANCEL',
                            style: TextStyle(color: _textSec, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _NeonButton(label: 'UPDATE', color: _neonRed, onTap: submit),
                    ),
                  ]),
                ]),
              ),
            ),
          );
        });
      },
    );
  }

  void _showEditIdDialog() {
    final ctrl = TextEditingController(text: _adminId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: _dialogShape(_neonBlue),
        title: const Text('EDIT ADMIN ID',
            style: TextStyle(color: _neonBlue, fontFamily: 'monospace',
                fontSize: 13, letterSpacing: 2)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: _textPrimary, fontFamily: 'monospace'),
          decoration: _fieldDecoration('Admin ID', _neonBlue),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: _textSec)),
          ),
          _NeonButton(
            label: 'SAVE',
            color: _neonBlue,
            onTap: () async {
              final id = ctrl.text.trim();
              if (id.isNotEmpty) {
                await SettingsPersistence.saveAdminId(id);
                widget.onAdminIdChanged(id);
                setState(() => _adminId = id);
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  // ── Toast ─────────────────────────────────────────────────────────────────

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(
          color: _neonGreen, fontFamily: 'monospace', fontSize: 12)),
      backgroundColor: _panel,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _neonGreen.withOpacity(0.3)),
      ),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          _Header(onBack: widget.onBack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── IDENTITY ───────────────────────────────────────────────
                const _SectionLabel(text: 'IDENTITY', color: _neonBlue),
                const SizedBox(height: 10),
                _InfoCard(rows: [
                  _InfoRow(icon: Icons.watch_outlined, label: 'WEAR DEVICE',
                      value: _config.wearDeviceName ?? widget.wearDeviceName),
                  _InfoRow(icon: Icons.system_update_alt, label: 'WEAR OS VERSION',
                      value: widget.wearOsVersion),
                  _InfoRow(icon: Icons.phone_android, label: 'HOST OS',
                      value: '${Platform.operatingSystem.toUpperCase()} '
                             '${Platform.operatingSystemVersion}'),
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'ADMIN ID',
                    value: _adminId,
                    trailing: GestureDetector(
                      onTap: _showEditIdDialog,
                      child: const Icon(Icons.edit, color: _neonBlue, size: 15),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── TRANSPORT ──────────────────────────────────────────────
                const _SectionLabel(text: 'TRANSPORT', color: _neonAmber),
                const SizedBox(height: 10),
                _Card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CONNECTION TYPE',
                        style: TextStyle(color: _textSec, fontSize: 10,
                            letterSpacing: 2.5, fontFamily: 'monospace')),
                    const SizedBox(height: 10),
                    ...TransportType.values.map((t) => _TransportRadio(
                          type: t,
                          selected: _config.transportType == t,
                          onTap: () => _setTransportType(t),
                        )),

                    const SizedBox(height: 10),
                    const Divider(color: _border, height: 1),
                    const SizedBox(height: 14),

                    // ── WiFi section ────────────────────────────────────────
                    if (_config.transportType == TransportType.wifi) ...[
                      _WifiSection(
                        status: _wifiStatus,
                        edgeUrl: _config.edgeServerUrl,
                        wifiOnly: _config.wifiOnly,
                        testing: _testing,
                        testResult: _testResult,
                        onEditUrl: _showEditEdgeUrlDialog,
                        onTest: _testConnection,
                        onWifiOnlyChanged: _setWifiOnly,
                        onRefresh: () => widget.wifiStatusService.refresh(),
                      ),
                    ],

                    // ── Bluetooth section ───────────────────────────────────
                    if (_config.transportType == TransportType.bluetooth) ...[
                      _BluetoothSection(
                        adapterState: _btState,
                        devices: _bleDevices,
                        isScanning: _isScanning,
                        wearDeviceId:   _config.wearDeviceId,
                        wearDeviceName: _config.wearDeviceName,
                        edgeDeviceId:   _config.edgeDeviceId,
                        edgeDeviceName: _config.edgeDeviceName,
                        onScan: _startBtScan,
                        onSelectWear: () => _showDevicePickerDialog(forWear: true),
                        onSelectEdge: () => _showDevicePickerDialog(forWear: false),
                      ),
                    ],

                    // ── Wired section ───────────────────────────────────────
                    if (_config.transportType == TransportType.wired) ...[
                      _WiredSection(
                        edgeUrl: _config.edgeServerUrl,
                        testing: _testing,
                        testResult: _testResult,
                        onEditUrl: _showEditEdgeUrlDialog,
                        onTest: _testConnection,
                      ),
                    ],
                  ],
                )),

                const SizedBox(height: 24),

                // ── TRANSMISSION ───────────────────────────────────────────
                const _SectionLabel(text: 'TRANSMISSION', color: _neonGreen),
                const SizedBox(height: 10),
                _Card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FLUSH INTERVAL',
                        style: TextStyle(color: _textSec, fontSize: 10,
                            letterSpacing: 2.5, fontFamily: 'monospace')),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TransmissionSpeed.values
                          .map((s) => _SpeedChip(
                                speed: s,
                                selected: _config.speed == s,
                                onTap: () => _setSpeed(s),
                              ))
                          .toList(),
                    ),
                  ],
                )),

                const SizedBox(height: 24),

                // ── SECURITY ───────────────────────────────────────────────
                const _SectionLabel(text: 'SECURITY', color: _neonRed),
                const SizedBox(height: 10),
                _Card(child: Column(children: [
                  _TapRow(
                    icon: Icons.lock_reset,
                    label: 'Change Admin Password',
                    subtitle: 'Update the admin monitor unlock credential',
                    color: _neonRed,
                    onTap: _showChangePasswordDialog,
                  ),
                ])),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── WiFi section ─────────────────────────────────────────────────────────────

class _WifiSection extends StatelessWidget {
  final WifiStatus status;
  final String edgeUrl;
  final bool wifiOnly;
  final bool testing;
  final String? testResult;
  final VoidCallback onEditUrl;
  final VoidCallback onTest;
  final ValueChanged<bool> onWifiOnlyChanged;
  final VoidCallback onRefresh;

  const _WifiSection({
    required this.status, required this.edgeUrl,
    required this.wifiOnly, required this.testing, required this.testResult,
    required this.onEditUrl, required this.onTest,
    required this.onWifiOnlyChanged, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Network status card
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: status.connected
              ? _neonGreen.withOpacity(0.06)
              : _neonRed.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: status.connected
                ? _neonGreen.withOpacity(0.25)
                : _neonRed.withOpacity(0.25),
          ),
        ),
        child: Row(children: [
          Icon(
            status.connected ? Icons.wifi : Icons.wifi_off,
            color: status.connected ? _neonGreen : _neonRed,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              status.connected
                  ? (status.ssid.isNotEmpty ? status.ssid : 'Connected')
                  : 'Not connected',
              style: TextStyle(
                color: status.connected ? _neonGreen : _neonRed,
                fontFamily: 'monospace', fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (status.connected && status.ipAddress.isNotEmpty)
              Text(status.ipAddress,
                  style: const TextStyle(color: _textSec,
                      fontFamily: 'monospace', fontSize: 10)),
          ])),
          GestureDetector(
            onTap: onRefresh,
            child: const Icon(Icons.refresh, color: _textSec, size: 16),
          ),
        ]),
      ),

      const SizedBox(height: 12),

      // Edge URL
      _TapRow(
        icon: Icons.dns_outlined,
        label: 'Edge Server URL',
        subtitle: edgeUrl,
        color: _neonGreen,
        onTap: onEditUrl,
      ),

      const SizedBox(height: 12),

      // Test button
      SizedBox(
        width: double.infinity,
        child: _NeonButton(
          label: testing ? 'TESTING...' : 'TEST CONNECTION',
          color: _neonGreen,
          onTap: testing ? () {} : onTest,
        ),
      ),

      if (testResult != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _border),
          ),
          child: Text(testResult!,
              style: const TextStyle(color: _textPrimary,
                  fontFamily: 'monospace', fontSize: 11)),
        ),
      ],

      const SizedBox(height: 12),
      const Divider(color: _border, height: 1),
      const SizedBox(height: 12),

      // WiFi-only toggle
      Row(children: [
        const Icon(Icons.wifi_lock, color: _neonBlue, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Wi-Fi Only Mode',
              style: TextStyle(color: _textPrimary, fontSize: 13)),
          SizedBox(height: 2),
          Text('Pause sync when not on Wi-Fi',
              style: TextStyle(color: _textSec, fontSize: 11, height: 1.4)),
        ])),
        Switch.adaptive(
          value: wifiOnly,
          onChanged: onWifiOnlyChanged,
          activeColor: _neonBlue,
        ),
      ]),
    ]);
  }
}

// ─── Bluetooth section ────────────────────────────────────────────────────────

class _BluetoothSection extends StatelessWidget {
  final BluetoothAdapterState adapterState;
  final List<BleDevice> devices;
  final bool isScanning;
  final String? wearDeviceId;
  final String? wearDeviceName;
  final String? edgeDeviceId;
  final String? edgeDeviceName;
  final VoidCallback onScan;
  final VoidCallback onSelectWear;
  final VoidCallback onSelectEdge;

  const _BluetoothSection({
    required this.adapterState, required this.devices,
    required this.isScanning, required this.wearDeviceId,
    required this.wearDeviceName, required this.edgeDeviceId,
    required this.edgeDeviceName,
    required this.onScan, required this.onSelectWear, required this.onSelectEdge,
  });

  @override
  Widget build(BuildContext context) {
    final btOn = adapterState == BluetoothAdapterState.on;
    final btColor = btOn ? _neonBlue : _neonRed;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Adapter status
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: btColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: btColor.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(Icons.bluetooth, color: btColor, size: 18),
          const SizedBox(width: 10),
          Text(
            btOn ? 'Bluetooth ON' : _btStateLabel(adapterState),
            style: TextStyle(color: btColor, fontFamily: 'monospace',
                fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ]),
      ),

      const SizedBox(height: 12),

      // Paired devices
      _PairedDeviceRow(
        icon: Icons.watch,
        role: 'WEAR DEVICE',
        name: wearDeviceName ?? '(none)',
        paired: wearDeviceId != null,
        color: _neonGreen,
        onTap: onSelectWear,
      ),
      const SizedBox(height: 8),
      _PairedDeviceRow(
        icon: Icons.router,
        role: 'EDGE DEVICE',
        name: edgeDeviceName ?? '(none)',
        paired: edgeDeviceId != null,
        color: _neonBlue,
        onTap: onSelectEdge,
      ),

      const SizedBox(height: 12),

      // Scan button + device count
      Row(children: [
        Expanded(
          child: _NeonButton(
            label: isScanning
                ? 'SCANNING... (tap to stop)'
                : 'SCAN FOR DEVICES',
            color: _neonBlue,
            onTap: btOn ? onScan : () {},
          ),
        ),
        if (devices.isNotEmpty) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _neonBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _border),
            ),
            child: Text('${devices.length}',
                style: const TextStyle(color: _neonBlue,
                    fontFamily: 'monospace', fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ]),

      if (isScanning) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(
          backgroundColor: _border,
          color: _neonBlue,
          minHeight: 2,
        ),
      ],
    ]);
  }

  String _btStateLabel(BluetoothAdapterState s) {
    switch (s) {
      case BluetoothAdapterState.off:         return 'Bluetooth OFF';
      case BluetoothAdapterState.unavailable: return 'BT Unavailable';
      default:                                return 'Checking...';
    }
  }
}

class _PairedDeviceRow extends StatelessWidget {
  final IconData icon;
  final String role;
  final String name;
  final bool paired;
  final Color color;
  final VoidCallback onTap;

  const _PairedDeviceRow({
    required this.icon, required this.role, required this.name,
    required this.paired, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: paired ? color.withOpacity(0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: paired ? color.withOpacity(0.35) : _border),
          ),
          child: Row(children: [
            Icon(icon, color: paired ? color : _textMuted, size: 16),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(role, style: const TextStyle(
                  color: _textSec, fontSize: 9,
                  letterSpacing: 1.5, fontFamily: 'monospace')),
              const SizedBox(height: 2),
              Text(name, style: TextStyle(
                  color: paired ? color : _textMuted,
                  fontSize: 12, fontFamily: 'monospace',
                  fontWeight: paired ? FontWeight.w700 : FontWeight.normal),
                  overflow: TextOverflow.ellipsis),
            ])),
            Icon(Icons.edit, color: _textSec, size: 14),
          ]),
        ),
      );
}

// ─── Wired section ────────────────────────────────────────────────────────────

class _WiredSection extends StatelessWidget {
  final String edgeUrl;
  final bool testing;
  final String? testResult;
  final VoidCallback onEditUrl;
  final VoidCallback onTest;

  const _WiredSection({
    required this.edgeUrl, required this.testing,
    required this.testResult, required this.onEditUrl, required this.onTest,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _neonAmber.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _neonAmber.withOpacity(0.25)),
            ),
            child: Row(children: const [
              Icon(Icons.usb, color: _neonAmber, size: 18),
              SizedBox(width: 10),
              Text('USB / Ethernet',
                  style: TextStyle(color: _neonAmber, fontFamily: 'monospace',
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),
          _TapRow(
            icon: Icons.dns_outlined,
            label: 'Edge Server URL',
            subtitle: edgeUrl,
            color: _neonAmber,
            onTap: onEditUrl,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _NeonButton(
              label: testing ? 'TESTING...' : 'TEST CONNECTION',
              color: _neonAmber,
              onTap: testing ? () {} : onTest,
            ),
          ),
          if (testResult != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _border)),
              child: Text(testResult!, style: const TextStyle(
                  color: _textPrimary, fontFamily: 'monospace', fontSize: 11)),
            ),
          ],
        ],
      );
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

RoundedRectangleBorder _dialogShape(Color color) => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: color.withOpacity(0.3)),
    );

InputDecoration _fieldDecoration(String hint, Color accent) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textSec, fontSize: 12),
      filled: true,
      fillColor: _bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent)),
    );

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF111827),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_back_ios, color: _textSec, size: 16),
          ),
          const SizedBox(width: 12),
          const Text('SETTINGS',
              style: TextStyle(color: _textPrimary, fontSize: 15,
                  fontWeight: FontWeight.w700, letterSpacing: 3,
                  fontFamily: 'monospace')),
        ]),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 3, height: 14, color: color,
            margin: const EdgeInsets.only(right: 8)),
        Text(text, style: TextStyle(color: color, fontSize: 10,
            letterSpacing: 3, fontFamily: 'monospace',
            fontWeight: FontWeight.w700)),
      ]);
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: child,
      );
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: rows.asMap().entries.map((e) => Column(children: [
                e.value,
                if (e.key < rows.length - 1)
                  const Divider(height: 1, color: _border),
              ])).toList(),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  const _InfoRow({required this.icon, required this.label,
      required this.value, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon, color: _textMuted, size: 16),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: _textSec, fontSize: 9,
                letterSpacing: 1.5, fontFamily: 'monospace')),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: _textPrimary,
                fontSize: 12, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis),
          ])),
          if (trailing != null) trailing!,
        ]),
      );
}

class _TransportRadio extends StatelessWidget {
  final TransportType type;
  final bool selected;
  final VoidCallback onTap;
  const _TransportRadio({required this.type, required this.selected, required this.onTap});

  IconData get _icon {
    switch (type) {
      case TransportType.wifi:      return Icons.wifi;
      case TransportType.bluetooth: return Icons.bluetooth;
      case TransportType.wired:     return Icons.usb;
    }
  }

  Color get _color {
    switch (type) {
      case TransportType.wifi:      return _neonGreen;
      case TransportType.bluetooth: return _neonBlue;
      case TransportType.wired:     return _neonAmber;
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? _color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? _color.withOpacity(0.5) : _border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Icon(_icon, color: selected ? _color : _textSec, size: 16),
            const SizedBox(width: 12),
            Expanded(child: Text(type.label, style: TextStyle(
                color: selected ? _color : _textPrimary,
                fontSize: 13, fontFamily: 'monospace',
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal))),
            if (selected)
              Icon(Icons.check_circle, color: _color, size: 16),
          ]),
        ),
      );
}

class _SpeedChip extends StatelessWidget {
  final TransmissionSpeed speed;
  final bool selected;
  final VoidCallback onTap;
  const _SpeedChip({required this.speed, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _neonGreen.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? _neonGreen : _border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [BoxShadow(color: _neonGreen.withOpacity(0.18), blurRadius: 10)]
                : [],
          ),
          child: Text(speed.label, style: TextStyle(
              color: selected ? _neonGreen : _textSec,
              fontSize: 12, fontFamily: 'monospace',
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              letterSpacing: 0.8)),
        ),
      );
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _TapRow({required this.icon, required this.label,
      required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: _textPrimary, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: _textSec, fontSize: 11, height: 1.4),
                overflow: TextOverflow.ellipsis),
          ])),
          const Icon(Icons.chevron_right, color: _textSec, size: 18),
        ]),
      );
}

class _DialogHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _DialogHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Icon(Icons.lock_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12,
              letterSpacing: 2.5, fontFamily: 'monospace',
              fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Divider(color: color.withOpacity(0.2), height: 1),
      ]);
}

class _NeonButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NeonButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.12),
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(
            fontFamily: 'monospace', fontSize: 12,
            fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      );
}

class _PwField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  const _PwField({required this.controller, required this.hint});

  @override
  State<_PwField> createState() => _PwFieldState();
}

class _PwFieldState extends State<_PwField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: _obscure,
        style: const TextStyle(
            color: _textPrimary, fontFamily: 'monospace', letterSpacing: 2),
        decoration: _fieldDecoration(widget.hint, _neonRed).copyWith(
          suffixIcon: IconButton(
            icon: Icon(
              _obscure ? Icons.visibility_off : Icons.visibility,
              color: _textSec, size: 16,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      );
}
