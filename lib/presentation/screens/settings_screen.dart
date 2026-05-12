// lib/presentation/screens/settings_screen.dart
// Admin Settings: device identity + transmission policy + security controls.
// Persists everything via SharedPreferences; notifies parent on change.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/transmission_config.dart';

// ─── SharedPreferences keys (single source of truth) ─────────────────────────
const kKeySpeed    = 'transmission_speed';
const kKeyWifiOnly = 'wifi_only_mode';
const kKeyAdminPw  = 'admin_password';
const kKeyAdminId  = 'admin_id';
const kKeyEdgeUrl  = 'edge_url';

// ─── Persistence helper ───────────────────────────────────────────────────────

class SettingsPersistence {
  static Future<TransmissionConfig> loadConfig() async {
    final p = await SharedPreferences.getInstance();
    return TransmissionConfig(
      speed: TransmissionSpeedExtension.fromStorageKey(p.getString(kKeySpeed) ?? 'RT'),
      wifiOnly: p.getBool(kKeyWifiOnly) ?? false,
    );
  }

  static Future<void> saveConfig(TransmissionConfig cfg) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(kKeySpeed, cfg.speed.storageKey);
    await p.setBool(kKeyWifiOnly, cfg.wifiOnly);
  }

  static Future<String> loadAdminPassword() async =>
      (await SharedPreferences.getInstance()).getString(kKeyAdminPw) ?? 'admin1234';

  static Future<void> saveAdminPassword(String pw) async =>
      (await SharedPreferences.getInstance()).setString(kKeyAdminPw, pw);

  static Future<String> loadAdminId() async =>
      (await SharedPreferences.getInstance()).getString(kKeyAdminId) ?? 'admin';

  static Future<void> saveAdminId(String id) async =>
      (await SharedPreferences.getInstance()).setString(kKeyAdminId, id);

  static Future<String> loadEdgeUrl() async =>
      (await SharedPreferences.getInstance()).getString(kKeyEdgeUrl) ??
      'http://192.168.1.100:8080';

  static Future<void> saveEdgeUrl(String url) async =>
      (await SharedPreferences.getInstance()).setString(kKeyEdgeUrl, url);
}

// ─── Theme tokens ─────────────────────────────────────────────────────────────
const _bg          = Color(0xFF0A0E1A);
const _panel       = Color(0xFF111827);
const _border      = Color(0xFF1E2D40);
const _neonGreen   = Color(0xFF00FF94);
const _neonBlue    = Color(0xFF00B4FF);
const _neonRed     = Color(0xFFFF3B5C);
const _textPrimary = Color(0xFFE2E8F0);
const _textSec     = Color(0xFF64748B);
const _textMuted   = Color(0xFF3D5068);

// ─── Screen ───────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  final TransmissionConfig currentConfig;
  final String adminId;
  final String wearDeviceName;
  final String wearOsVersion;
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

  @override
  void initState() {
    super.initState();
    _config = widget.currentConfig;
    _adminId = widget.adminId;
  }

  // ── Speed ────────────────────────────────────────────────────────────────

  Future<void> _setSpeed(TransmissionSpeed s) async {
    final next = _config.copyWith(speed: s);
    setState(() => _config = next);
    await SettingsPersistence.saveConfig(next);
    widget.onConfigChanged(next);
    HapticFeedback.selectionClick();
  }

  // ── WiFi-only toggle ─────────────────────────────────────────────────────

  Future<void> _setWifiOnly(bool v) async {
    final next = _config.copyWith(wifiOnly: v);
    setState(() => _config = next);
    await SettingsPersistence.saveConfig(next);
    widget.onConfigChanged(next);
  }

  // ── Change password dialog ────────────────────────────────────────────────

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
                  boxShadow: [
                    BoxShadow(color: _neonRed.withOpacity(0.12), blurRadius: 32)
                  ],
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
                    Text(errMsg!,
                        style: const TextStyle(
                            color: _neonRed, fontFamily: 'monospace', fontSize: 11)),
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
                      child: _NeonButton(
                        label: 'UPDATE',
                        color: _neonRed,
                        onTap: submit,
                      ),
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

  // ── Edit Admin ID ─────────────────────────────────────────────────────────

  void _showEditIdDialog() {
    final ctrl = TextEditingController(text: _adminId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _neonBlue.withOpacity(0.3)),
        ),
        title: const Text('EDIT ADMIN ID',
            style: TextStyle(
                color: _neonBlue, fontFamily: 'monospace',
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

  // ── Edge URL dialog ───────────────────────────────────────────────────────

  void _showEditEdgeUrlDialog() async {
    final current = await SettingsPersistence.loadEdgeUrl();
    final ctrl = TextEditingController(text: current);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _neonGreen.withOpacity(0.3)),
        ),
        title: const Text('EDGE SERVER URL',
            style: TextStyle(
                color: _neonGreen, fontFamily: 'monospace',
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
              await SettingsPersistence.saveEdgeUrl(ctrl.text.trim());
              if (ctx.mounted) Navigator.of(ctx).pop();
              _toast('Edge URL updated — restart to apply');
            },
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
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
                      value: widget.wearDeviceName),
                  _InfoRow(icon: Icons.system_update_alt, label: 'WEAR OS VERSION',
                      value: widget.wearOsVersion),
                  _InfoRow(icon: Icons.phone_android, label: 'HOST OS',
                      value: '${Platform.operatingSystem.toUpperCase()} ${Platform.operatingSystemVersion}'),
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

                // ── TRANSMISSION ───────────────────────────────────────────
                const _SectionLabel(text: 'TRANSMISSION', color: _neonGreen),
                const SizedBox(height: 10),
                _Card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FLUSH INTERVAL',
                        style: TextStyle(
                            color: _textSec, fontSize: 10,
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
                    const SizedBox(height: 16),
                    const Divider(color: _border, height: 1),
                    const SizedBox(height: 14),
                    // WiFi Only toggle
                    Row(children: [
                      const Icon(Icons.wifi, color: _neonBlue, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Wi-Fi Only Mode',
                                style: TextStyle(color: _textPrimary, fontSize: 13)),
                            SizedBox(height: 2),
                            Text('Transmit only when connected to Wi-Fi',
                                style: TextStyle(color: _textSec, fontSize: 11, height: 1.4)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _config.wifiOnly,
                        onChanged: _setWifiOnly,
                        activeColor: _neonBlue,
                      ),
                    ]),
                    const SizedBox(height: 14),
                    const Divider(color: _border, height: 1),
                    const SizedBox(height: 14),
                    // Edge URL
                    _TapRow(
                      icon: Icons.dns_outlined,
                      label: 'Edge Server URL',
                      subtitle: 'Configure the remote endpoint address',
                      color: _neonGreen,
                      onTap: _showEditEdgeUrlDialog,
                    ),
                  ],
                )),

                const SizedBox(height: 24),

                // ── SECURITY ───────────────────────────────────────────────
                const _SectionLabel(text: 'SECURITY', color: _neonRed),
                const SizedBox(height: 10),
                _Card(child: _TapRow(
                  icon: Icons.lock_reset,
                  label: 'Change Admin Password',
                  subtitle: 'Update the admin monitor unlock credential',
                  color: _neonRed,
                  onTap: _showChangePasswordDialog,
                )),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

InputDecoration _fieldDecoration(String hint, Color accent) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textSec, fontSize: 12),
      filled: true,
      fillColor: _bg,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
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
              style: TextStyle(
                  color: _textPrimary, fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3, fontFamily: 'monospace')),
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
        Text(text,
            style: TextStyle(
                color: color, fontSize: 10,
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
  const _InfoRow(
      {required this.icon, required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon, color: _textMuted, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: _textSec, fontSize: 9,
                      letterSpacing: 1.5, fontFamily: 'monospace')),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(color: _textPrimary, fontSize: 12, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
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
          child: Text(
            speed.label,
            style: TextStyle(
              color: selected ? _neonGreen : _textSec,
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              letterSpacing: 0.8,
            ),
          ),
        ),
      );
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _TapRow({
    required this.icon, required this.label,
    required this.subtitle, required this.color, required this.onTap,
  });

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
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _textPrimary, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(color: _textSec, fontSize: 11, height: 1.4)),
            ],
          )),
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
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12,
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
        child: Text(label,
            style: const TextStyle(
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
