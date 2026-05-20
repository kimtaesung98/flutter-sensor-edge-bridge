// lib/presentation/screens/onboarding_screen.dart
// First-launch onboarding: privacy consent → data collection consent → permissions.
// 4 steps with animated progress bar. Calls onComplete when all steps are done.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/permission_service.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────
const _bg          = Color(0xFF0A0E1A);
const _panel       = Color(0xFF111827);
const _border      = Color(0xFF1E2D40);
const _neonGreen   = Color(0xFF00FF94);
const _neonBlue    = Color(0xFF00B4FF);
const _neonRed     = Color(0xFFFF3B5C);
const _neonAmber   = Color(0xFFFFBB00);
const _textPrimary = Color(0xFFE2E8F0);
const _textSec     = Color(0xFF64748B);

// ─── Screen ───────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const _totalSteps = 4;
  int _step = 0;

  // Consent flags
  bool _privacyChecked    = false;
  bool _dataChecked       = false;
  bool _allConsentChecked = false; // 전체 동의

  // Permission states
  Map<AppPermission, PermissionStatus> _permStatus = {};
  bool _loadingPerms = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadPermissionStatus();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPermissionStatus() async {
    final map = await PermissionService.statusMap();
    if (mounted) setState(() => _permStatus = map);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _next() async {
    if (_step == 0) {
      // Welcome → Consent
      _animateTo(1);
    } else if (_step == 1) {
      // Consent check
      if (!_privacyChecked || !_dataChecked) {
        _showMustAgree();
        return;
      }
      await PermissionService.saveConsents(
          privacy: true, dataCollection: true);
      _animateTo(2);
    } else if (_step == 2) {
      // Permissions
      _animateTo(3);
    } else if (_step == 3) {
      // Done
      await PermissionService.markOnboardingComplete();
      HapticFeedback.mediumImpact();
      widget.onComplete();
    }
  }

  void _back() {
    if (_step > 0) _animateTo(_step - 1);
  }

  void _animateTo(int next) async {
    await _fadeCtrl.reverse();
    setState(() => _step = next);
    _fadeCtrl.forward();
  }

  void _showMustAgree() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('필수 약관에 모두 동의해 주세요.',
          style: TextStyle(color: _neonRed, fontFamily: 'monospace')),
      backgroundColor: _panel,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _neonRed.withOpacity(0.4)),
      ),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Toggle 전체 동의 ──────────────────────────────────────────────────────

  void _toggleAll(bool v) {
    setState(() {
      _allConsentChecked = v;
      _privacyChecked    = v;
      _dataChecked       = v;
    });
  }

  void _syncAllCheck() {
    setState(() => _allConsentChecked = _privacyChecked && _dataChecked);
  }

  // ── Request single permission ──────────────────────────────────────────────

  Future<void> _requestPermission(AppPermission perm) async {
    setState(() => _loadingPerms = true);
    final status = await PermissionService.requestOne(perm);
    if (status.isPermanentlyDenied) {
      _showOpenSettingsDialog(perm);
    }
    await _loadPermissionStatus();
    setState(() => _loadingPerms = false);
  }

  Future<void> _requestAll() async {
    setState(() => _loadingPerms = true);
    await PermissionService.requestAll();
    await _loadPermissionStatus();
    setState(() => _loadingPerms = false);
  }

  void _showOpenSettingsDialog(AppPermission perm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _neonAmber.withOpacity(0.4)),
        ),
        title: Text('권한 필요: ${perm.title}',
            style: const TextStyle(color: _neonAmber,
                fontFamily: 'monospace', fontSize: 13)),
        content: Text(
          '이 권한이 영구적으로 거부되었습니다.\n'
          '앱 설정에서 직접 허용해 주세요.',
          style: const TextStyle(color: _textSec, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('나중에', style: TextStyle(color: _textSec)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonAmber.withOpacity(0.12),
              foregroundColor: _neonAmber,
              side: BorderSide(color: _neonAmber.withOpacity(0.5)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              PermissionService.openSettings();
            },
            child: const Text('설정 열기',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          _buildProgressBar(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _buildStep(),
            ),
          ),
          _buildBottomBar(),
        ]),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() => Container(
        color: _panel,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          if (_step > 0)
            GestureDetector(
              onTap: _back,
              child: const Icon(Icons.arrow_back_ios,
                  color: _textSec, size: 16),
            )
          else
            const SizedBox(width: 16),
          const SizedBox(width: 10),
          const Text('SENSOR BRIDGE',
              style: TextStyle(color: _textPrimary, fontSize: 13,
                  fontWeight: FontWeight.w700, letterSpacing: 3,
                  fontFamily: 'monospace')),
          const Spacer(),
          Text('${_step + 1} / $_totalSteps',
              style: const TextStyle(color: _textSec, fontSize: 11,
                  fontFamily: 'monospace')),
        ]),
      );

  // ── Progress bar ──────────────────────────────────────────────────────────

  Widget _buildProgressBar() => Container(
        color: _panel,
        padding: const EdgeInsets.only(bottom: 1),
        child: Row(
          children: List.generate(_totalSteps, (i) => Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3,
              color: i <= _step
                  ? (i < _step ? _neonGreen : _neonBlue)
                  : _border,
              margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 2 : 0),
            ),
          )),
        ),
      );

  // ── Step router ───────────────────────────────────────────────────────────

  Widget _buildStep() {
    switch (_step) {
      case 0: return _StepWelcome();
      case 1: return _StepConsent(
        privacyChecked:    _privacyChecked,
        dataChecked:       _dataChecked,
        allChecked:        _allConsentChecked,
        onAllChanged:      _toggleAll,
        onPrivacyChanged:  (v) { setState(() => _privacyChecked = v ?? false); _syncAllCheck(); },
        onDataChanged:     (v) { setState(() => _dataChecked    = v ?? false); _syncAllCheck(); },
        onShowPrivacy:     () => _showTextDialog('개인정보 처리방침', _kPrivacyPolicyText),
        onShowDataPolicy:  () => _showTextDialog('개인정보 수집·이용 내역', _kDataCollectionText),
      );
      case 2: return _StepPermissions(
        permStatus:   _permStatus,
        loading:      _loadingPerms,
        onRequestOne: _requestPermission,
        onRequestAll: _requestAll,
      );
      case 3: return _StepDone(permStatus: _permStatus);
      default: return const SizedBox.shrink();
    }
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final bool canProceed = _step != 1 || (_privacyChecked && _dataChecked);
    final label = switch (_step) {
      0 => '시작하기',
      1 => '동의하고 계속',
      2 => '다음',
      _ => '앱 시작',
    };

    return Container(
      color: _panel,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canProceed
                  ? _neonBlue.withOpacity(0.18)
                  : _border.withOpacity(0.5),
              foregroundColor: canProceed ? _neonBlue : _textSec,
              side: BorderSide(
                  color: canProceed ? _neonBlue.withOpacity(0.6) : _border),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _next,
            child: Text(label,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14,
                    fontWeight: FontWeight.w700, letterSpacing: 2)),
          ),
        ),
      ),
    );
  }

  // ── Policy text dialog ────────────────────────────────────────────────────

  void _showTextDialog(String title, String body) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 240),
      transitionBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      pageBuilder: (ctx, _, __) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: _border)),
                ),
                child: Row(children: [
                  const Icon(Icons.description_outlined,
                      color: _neonBlue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title,
                      style: const TextStyle(color: _neonBlue,
                          fontFamily: 'monospace', fontSize: 13,
                          fontWeight: FontWeight.w700, letterSpacing: 1.5))),
                  IconButton(
                    icon: const Icon(Icons.close, color: _textSec, size: 18),
                    onPressed: () => Navigator.of(ctx).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(body,
                      style: const TextStyle(color: _textSec, fontSize: 12,
                          height: 1.8, fontFamily: 'monospace')),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonBlue.withOpacity(0.12),
                      foregroundColor: _neonBlue,
                      side: BorderSide(color: _neonBlue.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('확인',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Step 0: Welcome ──────────────────────────────────────────────────────────

class _StepWelcome extends StatelessWidget {
  const _StepWelcome();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _neonBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _neonBlue.withOpacity(0.2)),
            ),
            child: const Icon(Icons.sensors, color: _neonBlue, size: 60),
          ),
          const SizedBox(height: 36),
          const Text('Sensor Bridge',
              style: TextStyle(color: _textPrimary, fontSize: 32,
                  fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          const Text('Wear OS → Edge 자율 릴레이 시스템',
              style: TextStyle(color: _neonBlue, fontSize: 14,
                  fontFamily: 'monospace')),
          const SizedBox(height: 32),
          ..._features.map((f) => _FeatureRow(icon: f.$1, text: f.$2)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Text(
              '시작하기 전에 서비스 이용에 필요한 권한 동의와\n'
              '개인정보 처리방침 확인이 필요합니다.',
              style: TextStyle(color: _textSec, fontSize: 12, height: 1.7),
            ),
          ),
        ]),
      );

  static const _features = [
    (Icons.watch_outlined,    'Wear OS 기기에서 센서 데이터 수집'),
    (Icons.wifi,              'Wi-Fi / Bluetooth / 유선으로 Edge 전송'),
    (Icons.shield_outlined,   '로컬 SQLite 버퍼로 오프라인 안전 보장'),
    (Icons.admin_panel_settings_outlined, '관리자 전용 실시간 모니터링'),
  ];
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _neonGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _neonGreen, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text,
              style: const TextStyle(color: _textPrimary, fontSize: 14,
                  height: 1.4))),
        ]),
      );
}

// ─── Step 1: Consent ──────────────────────────────────────────────────────────

class _StepConsent extends StatelessWidget {
  final bool privacyChecked;
  final bool dataChecked;
  final bool allChecked;
  final ValueChanged<bool> onAllChanged;
  final ValueChanged<bool?> onPrivacyChanged;
  final ValueChanged<bool?> onDataChanged;
  final VoidCallback onShowPrivacy;
  final VoidCallback onShowDataPolicy;

  const _StepConsent({
    required this.privacyChecked, required this.dataChecked,
    required this.allChecked, required this.onAllChanged,
    required this.onPrivacyChanged, required this.onDataChanged,
    required this.onShowPrivacy, required this.onShowDataPolicy,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('서비스 이용 동의',
              style: TextStyle(color: _textPrimary, fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('앱 사용을 위해 아래 항목에 동의해 주세요.',
              style: TextStyle(color: _textSec, fontSize: 13, height: 1.5)),
          const SizedBox(height: 28),

          // 전체 동의
          _ConsentAllCard(checked: allChecked, onChanged: onAllChanged),

          const SizedBox(height: 16),
          const Divider(color: _border),
          const SizedBox(height: 16),

          // 개별 항목
          _ConsentItem(
            required: true,
            label: '개인정보 처리방침 동의',
            description: '서비스 제공을 위한 개인정보 수집·이용에 동의합니다.',
            checked: privacyChecked,
            onChanged: onPrivacyChanged,
            onDetail: onShowPrivacy,
          ),
          const SizedBox(height: 12),
          _ConsentItem(
            required: true,
            label: '개인정보 수집·이용 동의',
            description: '센서 데이터(가속도계) 및 기기 식별 정보 수집에 동의합니다.',
            checked: dataChecked,
            onChanged: onDataChanged,
            onDetail: onShowDataPolicy,
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _neonAmber.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _neonAmber.withOpacity(0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: _neonAmber, size: 16),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '수집된 데이터는 설정된 Edge 서버로만 전송되며,\n'
                  '제3자에게 제공되지 않습니다.',
                  style: TextStyle(color: _neonAmber, fontSize: 11, height: 1.7),
                ),
              ),
            ]),
          ),
        ]),
      );
}

class _ConsentAllCard extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool> onChanged;
  const _ConsentAllCard({required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!checked),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: checked
                ? _neonGreen.withOpacity(0.08)
                : _panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: checked ? _neonGreen.withOpacity(0.5) : _border,
              width: checked ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: checked ? _neonGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: checked ? _neonGreen : _textSec, width: 2),
              ),
              child: checked
                  ? const Icon(Icons.check, color: _bg, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('전체 동의',
                  style: TextStyle(
                      color: checked ? _neonGreen : _textPrimary,
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              const Text('아래 모든 필수 항목에 동의합니다.',
                  style: TextStyle(color: _textSec, fontSize: 12)),
            ])),
          ]),
        ),
      );
}

class _ConsentItem extends StatelessWidget {
  final bool required;
  final String label;
  final String description;
  final bool checked;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onDetail;

  const _ConsentItem({
    required this.required, required this.label,
    required this.description, required this.checked,
    required this.onChanged, required this.onDetail,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: checked ? _neonBlue.withOpacity(0.3) : _border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(
            value: checked,
            onChanged: onChanged,
            activeColor: _neonBlue,
            side: const BorderSide(color: _textSec, width: 1.5),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 2),
            Row(children: [
              if (required)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _neonRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _neonRed.withOpacity(0.4)),
                  ),
                  child: const Text('필수',
                      style: TextStyle(color: _neonRed, fontSize: 9,
                          fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                ),
              Expanded(child: Text(label,
                  style: const TextStyle(color: _textPrimary, fontSize: 13,
                      fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 4),
            Text(description,
                style: const TextStyle(color: _textSec, fontSize: 11, height: 1.5)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onDetail,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('내용 보기',
                    style: TextStyle(color: _neonBlue, fontSize: 11,
                        fontFamily: 'monospace',
                        decoration: TextDecoration.underline,
                        decorationColor: _neonBlue)),
                SizedBox(width: 2),
                Icon(Icons.chevron_right, color: _neonBlue, size: 14),
              ]),
            ),
          ])),
        ]),
      );
}

// ─── Step 2: Permissions ──────────────────────────────────────────────────────

class _StepPermissions extends StatelessWidget {
  final Map<AppPermission, PermissionStatus> permStatus;
  final bool loading;
  final Future<void> Function(AppPermission) onRequestOne;
  final Future<void> Function() onRequestAll;

  const _StepPermissions({
    required this.permStatus, required this.loading,
    required this.onRequestOne, required this.onRequestAll,
  });

  @override
  Widget build(BuildContext context) {
    final allGranted = permStatus.values.every((s) => s.isGranted);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('앱 권한 설정',
            style: TextStyle(color: _textPrimary, fontSize: 24,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('기능 사용을 위해 아래 권한을 허용해 주세요.',
            style: TextStyle(color: _textSec, fontSize: 13, height: 1.5)),
        const SizedBox(height: 28),

        // 전체 허용 버튼
        if (!allGranted) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonGreen.withOpacity(0.1),
                foregroundColor: _neonGreen,
                side: BorderSide(color: _neonGreen.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: loading ? null : onRequestAll,
              icon: loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _neonGreen))
                  : const Icon(Icons.done_all, size: 18),
              label: const Text('모든 권한 한번에 허용',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 개별 권한 카드
        ...AppPermission.values.map((perm) {
          final status = permStatus[perm];
          return _PermissionCard(
            permission: perm,
            status: status,
            onRequest: loading ? null : () => onRequestOne(perm),
          );
        }),

        if (allGranted) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _neonGreen.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _neonGreen.withOpacity(0.3)),
            ),
            child: Row(children: const [
              Icon(Icons.check_circle_outline, color: _neonGreen, size: 18),
              SizedBox(width: 10),
              Text('모든 권한이 허용되었습니다.',
                  style: TextStyle(color: _neonGreen, fontSize: 13,
                      fontFamily: 'monospace')),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final AppPermission permission;
  final PermissionStatus? status;
  final VoidCallback? onRequest;

  const _PermissionCard({
    required this.permission, required this.status, required this.onRequest,
  });

  bool get _granted => status?.isGranted ?? false;
  bool get _denied  => status?.isPermanentlyDenied ?? false;

  Color get _color {
    if (_granted) return _neonGreen;
    if (_denied)  return _neonRed;
    return _neonAmber;
  }

  IconData get _statusIcon {
    if (_granted) return Icons.check_circle;
    if (_denied)  return Icons.block;
    return Icons.radio_button_unchecked;
  }

  String get _statusLabel {
    if (_granted) return '허용됨';
    if (_denied)  return '영구 거부';
    if (status?.isDenied ?? false) return '거부됨';
    return '허용 필요';
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _granted ? _neonGreen.withOpacity(0.05) : _panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_permIcon(permission), color: _color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(permission.title,
                style: const TextStyle(color: _textPrimary, fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(permission.description,
                style: const TextStyle(color: _textSec, fontSize: 11, height: 1.4)),
          ])),
          const SizedBox(width: 10),
          if (!_granted)
            GestureDetector(
              onTap: onRequest,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _color.withOpacity(0.4)),
                ),
                child: Text('허용',
                    style: TextStyle(color: _color, fontSize: 11,
                        fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              ),
            )
          else
            Icon(_statusIcon, color: _color, size: 20),
        ]),
      );

  IconData _permIcon(AppPermission p) {
    switch (p) {
      case AppPermission.location:         return Icons.location_on_outlined;
      case AppPermission.bluetoothScan:    return Icons.bluetooth_searching;
      case AppPermission.bluetoothConnect: return Icons.bluetooth_connected;
      case AppPermission.notification:     return Icons.notifications_outlined;
    }
  }
}

// ─── Step 3: Done ─────────────────────────────────────────────────────────────

class _StepDone extends StatelessWidget {
  final Map<AppPermission, PermissionStatus> permStatus;
  const _StepDone({required this.permStatus});

  @override
  Widget build(BuildContext context) {
    final granted = permStatus.values.where((s) => s.isGranted).length;
    final total   = permStatus.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _neonGreen.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(color: _neonGreen.withOpacity(0.3), width: 2),
          ),
          child: const Icon(Icons.check, color: _neonGreen, size: 56),
        ),
        const SizedBox(height: 32),
        const Text('준비 완료!',
            style: TextStyle(color: _textPrimary, fontSize: 28,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        const Text('Sensor Bridge를 사용할 준비가 되었습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSec, fontSize: 14, height: 1.6)),
        const SizedBox(height: 36),

        // Summary cards
        _SummaryRow(
          icon: Icons.verified_user_outlined,
          label: '개인정보 처리방침',
          value: '동의 완료',
          color: _neonGreen,
        ),
        const SizedBox(height: 10),
        _SummaryRow(
          icon: Icons.security_outlined,
          label: '권한',
          value: '$granted / $total 허용됨',
          color: granted == total ? _neonGreen : _neonAmber,
        ),

        if (granted < total) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _neonAmber.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _neonAmber.withOpacity(0.25)),
            ),
            child: const Text(
              '일부 권한이 허용되지 않았습니다.\n'
              '설정 화면에서 나중에 변경할 수 있습니다.',
              style: TextStyle(color: _neonAmber, fontSize: 12, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SummaryRow({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: const TextStyle(color: _textPrimary, fontSize: 13))),
          Text(value, style: TextStyle(color: color, fontSize: 12,
              fontFamily: 'monospace', fontWeight: FontWeight.w700)),
        ]),
      );
}

// ─── Policy texts ─────────────────────────────────────────────────────────────

const _kPrivacyPolicyText = '''
개인정보 처리방침

1. 수집하는 개인정보 항목
   - 기기 가속도계 센서 데이터 (ax, ay, az)
   - 기기 식별 ID (UUID, 자동 생성)
   - 연결된 블루투스 기기 이름 및 MAC 주소
   - Wi-Fi SSID 및 IP 주소 (연결 상태 확인 목적)

2. 개인정보 수집 및 이용 목적
   - Wear OS 기기에서 수집한 센서 데이터를 Edge 서버로 중계
   - 연결 상태 모니터링 및 오프라인 버퍼 관리
   - 관리자 화면을 통한 시스템 상태 표시

3. 개인정보 보유 및 이용 기간
   - 앱 삭제 시 즉시 파기
   - 로컬 SQLite DB의 전송 완료 패킷은 즉시 삭제

4. 개인정보의 제3자 제공
   - 사용자가 직접 설정한 Edge 서버 외에는 제3자에게 제공하지 않습니다.
   - 클라우드 또는 외부 서버로 자동 전송되지 않습니다.

5. 이용자의 권리
   - 앱 내 설정에서 수집된 데이터를 삭제할 수 있습니다.
   - 앱 삭제 시 모든 로컬 데이터가 삭제됩니다.

6. 문의
   - 개인정보 관련 문의는 앱 내 관리자 설정 화면을 통해 가능합니다.
''';

const _kDataCollectionText = '''
개인정보 수집·이용 내역

■ 필수 수집 항목 및 이용 목적

항목: 가속도계 센서 데이터 (ax, ay, az)
목적: Wear OS → Edge 데이터 릴레이의 핵심 기능
보유기간: 전송 완료 즉시 삭제 (미전송 시 앱 실행 중 유지)

항목: 블루투스 기기 정보 (이름, ID)
목적: Wear OS 및 Edge 기기 페어링 및 연결 관리
보유기간: 사용자가 설정 초기화 전까지 유지

항목: 네트워크 정보 (Wi-Fi SSID, IP)
목적: 연결 상태 확인 및 전송 경로 판단
보유기간: 앱 실행 중에만 메모리 내 유지 (저장 안 함)

■ 수집하지 않는 정보
- 성명, 주민등록번호, 연락처 등 개인 식별 정보
- 위치 GPS 좌표 (SSID 조회 목적 위치 권한만 사용)
- 사진, 동영상, 파일 등 미디어

■ 데이터 처리 방식
- 모든 데이터는 기기 내 로컬 SQLite DB에만 저장됩니다.
- 사용자가 설정한 Edge 서버 외부로 자동 전송되지 않습니다.
- 암호화되지 않은 HTTP를 사용할 경우 네트워크 보안에 주의하세요.
''';
