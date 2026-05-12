// lib/presentation/screens/admin_monitor_screen.dart
// Developer-only terminal: one-line packet summaries streamed from SyncService.
// Format: [HH:mm:ss] Accel(  x,  y,  z) | Buffer:N | ✅Sent / ⏸Buffered

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/connectivity_orchestrator.dart';
import '../../core/services/sync_service.dart';
import '../../domain/entities/sensor_packet.dart';
import '../../domain/models/transmission_config.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────
const _bg          = Color(0xFF060A10);
const _panel       = Color(0xFF0D1117);
const _border      = Color(0xFF1A2332);
const _neonGreen   = Color(0xFF00FF94);
const _neonBlue    = Color(0xFF00B4FF);
const _neonAmber   = Color(0xFFFFBB00);
const _neonRed     = Color(0xFFFF3B5C);
const _textPrimary = Color(0xFFE2E8F0);
const _textMuted   = Color(0xFF3D5068);
const _textSec     = Color(0xFF4A6080);

// ─── Log entry ────────────────────────────────────────────────────────────────

class _LogEntry {
  final DateTime ts;
  final double ax, ay, az;
  final int bufferCount;
  final bool sent;

  _LogEntry({
    required this.ts,
    required this.ax, required this.ay, required this.az,
    required this.bufferCount, required this.sent,
  });

  String get oneLiner {
    final hh = ts.hour.toString().padLeft(2, '0');
    final mm = ts.minute.toString().padLeft(2, '0');
    final ss = ts.second.toString().padLeft(2, '0');
    final x  = ax.toStringAsFixed(2).padLeft(6);
    final y  = ay.toStringAsFixed(2).padLeft(6);
    final z  = az.toStringAsFixed(2).padLeft(6);
    final status = sent ? '✅Sent' : '⏸Buffered';
    return '[$hh:$mm:$ss] Accel($x,$y,$z) | Buffer:$bufferCount | $status';
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminMonitorScreen extends StatefulWidget {
  final ConnectivityOrchestrator orchestrator;
  final SyncService syncService;
  final TransmissionConfig config;
  final VoidCallback onSettingsTap;
  final VoidCallback onBack;

  const AdminMonitorScreen({
    super.key,
    required this.orchestrator,
    required this.syncService,
    required this.config,
    required this.onSettingsTap,
    required this.onBack,
  });

  @override
  State<AdminMonitorScreen> createState() => _AdminMonitorScreenState();
}

class _AdminMonitorScreenState extends State<AdminMonitorScreen> {
  final List<_LogEntry> _log = [];
  final _scrollCtrl = ScrollController();
  static const _maxLog = 500;

  bool _autoscroll = true;
  bool _paused = false;

  int _totalPackets = 0;
  int _totalSent = 0;
  int _totalBuffered = 0;

  DualLinkStatus _links = const DualLinkStatus();
  StreamSubscription<DualLinkStatus>? _linkSub;
  StreamSubscription<SensorPacket>? _packetSub;

  @override
  void initState() {
    super.initState();
    _links = widget.orchestrator.currentStatus;

    _linkSub = widget.orchestrator.statusStream.listen((s) {
      if (mounted) setState(() => _links = s);
    });

    _packetSub = widget.syncService.packetStream.listen(_onPacket);
  }

  void _onPacket(SensorPacket p) {
    if (_paused || !mounted) return;
    final entry = _LogEntry(
      ts: p.timestamp, ax: p.ax, ay: p.ay, az: p.az,
      bufferCount: 0, // real count comes from SyncService flush result
      sent: p.transmitted,
    );
    setState(() {
      _totalPackets++;
      p.transmitted ? _totalSent++ : _totalBuffered++;
      _log.add(entry);
      if (_log.length > _maxLog) _log.removeAt(0);
    });
    if (_autoscroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _togglePause() {
    HapticFeedback.selectionClick();
    setState(() => _paused = !_paused);
  }

  void _clearLog() {
    HapticFeedback.mediumImpact();
    setState(() {
      _log.clear();
      _totalPackets = _totalSent = _totalBuffered = 0;
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _packetSub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          _buildStatsBar(),
          _buildLinkBar(),
          Expanded(child: _buildTerminal()),
          _buildActionBar(),
        ]),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() => Container(
        color: _panel,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          GestureDetector(
            onTap: widget.onBack,
            child: const Icon(Icons.arrow_back_ios, color: _textMuted, size: 16),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _neonGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _neonGreen.withOpacity(0.35)),
            ),
            child: const Text('⬡ ADMIN',
                style: TextStyle(
                    color: _neonGreen, fontSize: 9, letterSpacing: 2,
                    fontFamily: 'monospace', fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          const Text('PACKET MONITOR',
              style: TextStyle(
                  color: _textPrimary, fontSize: 13,
                  fontWeight: FontWeight.w700, letterSpacing: 2,
                  fontFamily: 'monospace')),
          const Spacer(),
          Text(widget.config.speed.label,
              style: const TextStyle(
                  color: _neonAmber, fontSize: 10,
                  fontFamily: 'monospace', letterSpacing: 1)),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: widget.onSettingsTap,
            child: const Icon(Icons.tune, color: _neonBlue, size: 20),
          ),
        ]),
      );

  // ── Stats bar ─────────────────────────────────────────────────────────────

  Widget _buildStatsBar() => Container(
        color: _panel,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(children: [
          _Stat(label: 'TOTAL', value: '$_totalPackets', color: _neonBlue),
          const SizedBox(width: 18),
          _Stat(label: 'SENT', value: '$_totalSent', color: _neonGreen),
          const SizedBox(width: 18),
          _Stat(label: 'BUFFERED', value: '$_totalBuffered', color: _neonAmber),
          const Spacer(),
          if (_paused)
            const Text('⏸ PAUSED',
                style: TextStyle(
                    color: _neonAmber, fontSize: 9,
                    fontFamily: 'monospace', letterSpacing: 1.5)),
        ]),
      );

  // ── Link bar ──────────────────────────────────────────────────────────────

  Widget _buildLinkBar() => Container(
        height: 30,
        color: const Color(0xFF080C14),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          _MiniLink(label: 'W→P', state: _links.wearToPhone),
          const SizedBox(width: 18),
          _MiniLink(label: 'P→E', state: _links.phoneToEdge),
          const Spacer(),
          Text('FLUSH: ${widget.config.speed.intervalMs}ms',
              style: const TextStyle(
                  color: _textMuted, fontSize: 9,
                  fontFamily: 'monospace', letterSpacing: 1)),
        ]),
      );

  // ── Terminal ──────────────────────────────────────────────────────────────

  Widget _buildTerminal() {
    if (_log.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.terminal, color: _textMuted, size: 36),
          const SizedBox(height: 10),
          Text(
            widget.syncService.isRunning
                ? 'Waiting for first packet...'
                : 'SyncService stopped — standby mode',
            style: const TextStyle(
                color: _textMuted, fontFamily: 'monospace', fontSize: 12),
          ),
        ]),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && _scrollCtrl.hasClients) {
          final atBottom = _scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 60;
          if (_autoscroll != atBottom) {
            setState(() => _autoscroll = atBottom);
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: _log.length,
        itemBuilder: (_, i) {
          final e = _log[i];
          final isLast = i == _log.length - 1;
          return Container(
            color: isLast ? _neonGreen.withOpacity(0.025) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              e.oneLiner,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                letterSpacing: 0.2,
                height: 1.6,
                color: e.sent ? _textPrimary : _neonAmber.withOpacity(0.72),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Action bar ────────────────────────────────────────────────────────────

  Widget _buildActionBar() => Container(
        color: _panel,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _ActionBtn(
            icon: Icons.vertical_align_bottom,
            label: 'FOLLOW',
            active: _autoscroll,
            color: _neonBlue,
            onTap: () => setState(() => _autoscroll = !_autoscroll),
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            icon: _paused ? Icons.play_arrow : Icons.pause,
            label: _paused ? 'RESUME' : 'PAUSE',
            active: _paused,
            color: _neonAmber,
            onTap: _togglePause,
          ),
          const Spacer(),
          _ActionBtn(
            icon: Icons.delete_sweep,
            label: 'CLEAR',
            active: false,
            color: _neonRed,
            onTap: _clearLog,
          ),
        ]),
      );
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: const TextStyle(
                  color: _textMuted, fontSize: 9,
                  fontFamily: 'monospace', letterSpacing: 1)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13,
                  fontFamily: 'monospace', fontWeight: FontWeight.w700)),
        ],
      );
}

class _MiniLink extends StatelessWidget {
  final String label;
  final LinkState state;
  const _MiniLink({required this.label, required this.state});

  Color get _color {
    switch (state) {
      case LinkState.connected:    return _neonGreen;
      case LinkState.disconnected: return _neonRed;
      case LinkState.checking:     return _neonBlue;
    }
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              color: _color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _color, blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: _color, fontSize: 9,
                  fontFamily: 'monospace', letterSpacing: 1.5)),
        ],
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon, required this.label,
    required this.active, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: active ? color.withOpacity(0.45) : _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: active ? color : _textMuted, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: active ? color : _textMuted,
                    fontSize: 9, fontFamily: 'monospace',
                    letterSpacing: 1.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
