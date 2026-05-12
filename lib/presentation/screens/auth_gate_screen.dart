// lib/presentation/screens/auth_gate_screen.dart
// Public-facing status screen (Gatekeeper View).
// Admin access: password dialog → AdminMonitorScreen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/connectivity_orchestrator.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────
const _bg          = Color(0xFF0A0E1A);
const _panel       = Color(0xFF111827);
const _border      = Color(0xFF1E2D40);
const _neonGreen   = Color(0xFF00FF94);
const _neonBlue    = Color(0xFF00B4FF);
const _neonRed     = Color(0xFFFF3B5C);
const _textPrimary = Color(0xFFE2E8F0);
const _textSec     = Color(0xFF64748B);

class AuthGateScreen extends StatefulWidget {
  final ConnectivityOrchestrator orchestrator;
  final String Function() getAdminPassword;
  final VoidCallback onAdminUnlocked;
  final VoidCallback onSettingsTap;

  const AuthGateScreen({
    super.key,
    required this.orchestrator,
    required this.getAdminPassword,
    required this.onAdminUnlocked,
    required this.onSettingsTap,
  });

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _glow = Tween(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ── Password dialog ───────────────────────────────────────────────────────

  void _openAuthDialog() {
    final ctrl = TextEditingController();
    bool obscure = true;
    String? error;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: a, child: child),
      ),
      pageBuilder: (ctx, _, __) => StatefulBuilder(
        builder: (ctx, setDS) {
          void tryUnlock() {
            HapticFeedback.lightImpact();
            if (ctrl.text == widget.getAdminPassword()) {
              Navigator.of(ctx).pop();
              widget.onAdminUnlocked();
            } else {
              HapticFeedback.heavyImpact();
              setDS(() => error = 'ACCESS DENIED — invalid credentials');
            }
          }

          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _neonBlue.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                        color: _neonBlue.withOpacity(0.14), blurRadius: 48)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(children: [
                      const Icon(Icons.security, color: _neonBlue, size: 18),
                      const SizedBox(width: 8),
                      const Text('ADMIN AUTHENTICATION',
                          style: TextStyle(
                              color: _neonBlue, fontSize: 12,
                              letterSpacing: 2.5, fontFamily: 'monospace',
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    Divider(color: _neonBlue.withOpacity(0.2), height: 1),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter administrator password to access\nPacket Monitor & system internals.',
                      style: TextStyle(
                          color: _textSec, fontSize: 12, height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    // Field
                    StatefulBuilder(builder: (_, setSF) => TextField(
                      controller: ctrl,
                      obscureText: obscure,
                      autofocus: true,
                      onSubmitted: (_) => tryUnlock(),
                      style: const TextStyle(
                          color: _textPrimary, fontFamily: 'monospace',
                          letterSpacing: 3),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        hintStyle: const TextStyle(color: _textSec),
                        filled: true,
                        fillColor: _bg,
                        errorText: error,
                        errorStyle: const TextStyle(
                            color: _neonRed, fontFamily: 'monospace',
                            fontSize: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _neonBlue)),
                        errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _neonRed)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility,
                            color: _textSec, size: 16,
                          ),
                          onPressed: () => setSF(() => obscure = !obscure),
                        ),
                      ),
                    )),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('CANCEL',
                              style: TextStyle(color: _textSec, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _neonBlue.withOpacity(0.12),
                            foregroundColor: _neonBlue,
                            side: BorderSide(color: _neonBlue.withOpacity(0.6)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: tryUnlock,
                          child: const Text('UNLOCK ACCESS',
                              style: TextStyle(
                                  letterSpacing: 1.5, fontFamily: 'monospace',
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: StreamBuilder<DualLinkStatus>(
          stream: widget.orchestrator.statusStream,
          initialData: widget.orchestrator.currentStatus,
          builder: (_, snap) {
            final status = snap.data ?? const DualLinkStatus();
            return _GatekeeperBody(
              status: status,
              glow: _glow,
              onAdminTap: _openAuthDialog,
              onSettingsTap: widget.onSettingsTap,
            );
          },
        ),
      ),
    );
  }
}

// ─── Gatekeeper body ──────────────────────────────────────────────────────────

class _GatekeeperBody extends StatelessWidget {
  final DualLinkStatus status;
  final Animation<double> glow;
  final VoidCallback onAdminTap;
  final VoidCallback onSettingsTap;

  const _GatekeeperBody({
    required this.status, required this.glow,
    required this.onAdminTap, required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = status.allConnected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        const SizedBox(height: 48),

        // Wordmark
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SENSOR',
                  style: TextStyle(
                      color: _textSec, fontSize: 11,
                      letterSpacing: 6, fontFamily: 'monospace')),
              const Text('BRIDGE',
                  style: TextStyle(
                      color: _textPrimary, fontSize: 44,
                      fontWeight: FontWeight.w900, letterSpacing: -1.5,
                      height: 1)),
              const SizedBox(height: 4),
              const Text('autonomous relay system',
                  style: TextStyle(color: _textSec, fontSize: 12)),
            ]),
            IconButton(
              onPressed: onSettingsTap,
              icon: const Icon(Icons.settings_outlined, color: _textSec, size: 22),
            ),
          ],
        ),

        const SizedBox(height: 44),

        // Status panel (animated glow)
        AnimatedBuilder(
          animation: glow,
          builder: (_, __) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? _neonGreen.withOpacity(glow.value * 0.75)
                    : _neonRed.withOpacity(0.28),
                width: active ? 1.5 : 1,
              ),
              boxShadow: active
                  ? [BoxShadow(
                      color: _neonGreen.withOpacity(glow.value * 0.10),
                      blurRadius: 50, spreadRadius: 8)]
                  : [],
            ),
            child: Column(children: [
              Icon(
                active ? Icons.sensors : Icons.sensors_off,
                color: active ? _neonGreen : _neonRed,
                size: 68,
              ),
              const SizedBox(height: 14),
              Text(
                active ? 'SYSTEM ACTIVE' : 'STANDBY',
                style: TextStyle(
                    color: active ? _neonGreen : _neonRed,
                    fontSize: 24, fontWeight: FontWeight.w900,
                    letterSpacing: 5, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              Text(
                active
                    ? 'All links up — relaying sensor data to edge'
                    : 'Connection lost — buffering to local storage',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _textSec, fontSize: 12, height: 1.6),
              ),
            ]),
          ),
        ),

        const SizedBox(height: 16),

        // Link cards
        Row(children: [
          Expanded(
              child: _LinkCard(
                  label: 'WEAR → PHONE',
                  icon: Icons.watch_outlined,
                  state: status.wearToPhone)),
          const SizedBox(width: 12),
          Expanded(
              child: _LinkCard(
                  label: 'PHONE → EDGE',
                  icon: Icons.cloud_outlined,
                  state: status.phoneToEdge)),
        ]),

        const Spacer(),

        // Admin entry button
        GestureDetector(
          onTap: onAdminTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.terminal, color: _textSec, size: 15),
                SizedBox(width: 8),
                Text('ADMIN ACCESS',
                    style: TextStyle(
                        color: _textSec, fontSize: 12,
                        letterSpacing: 2.5, fontFamily: 'monospace')),
                SizedBox(width: 8),
                Icon(Icons.lock_outline, color: _textSec, size: 13),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ─── Link card ────────────────────────────────────────────────────────────────

class _LinkCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinkState state;
  const _LinkCard({required this.label, required this.icon, required this.state});

  Color get _color {
    switch (state) {
      case LinkState.connected:    return _neonGreen;
      case LinkState.disconnected: return _neonRed;
      case LinkState.checking:     return _neonBlue;
    }
  }

  String get _stateLabel {
    switch (state) {
      case LinkState.connected:    return 'CONNECTED';
      case LinkState.disconnected: return 'OFFLINE';
      case LinkState.checking:     return 'CHECKING';
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _color.withOpacity(0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: _color, size: 20),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(
                  color: _textSec, fontSize: 9,
                  letterSpacing: 1.5, fontFamily: 'monospace')),
          const SizedBox(height: 5),
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: _color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _color, blurRadius: 5)],
              ),
            ),
            const SizedBox(width: 6),
            Text(_stateLabel,
                style: TextStyle(
                    color: _color, fontSize: 11, fontFamily: 'monospace',
                    fontWeight: FontWeight.w700, letterSpacing: 1)),
          ]),
        ]),
      );
}
