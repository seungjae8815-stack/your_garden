import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_lock_service.dart';
import '../theme.dart';

const int kPinLength = 4;

/// 잠금 해제 화면 — PIN 입력 + (켜져 있으면) 생체인증.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _lock = AppLockService.instance;
  String _pin = '';
  String? _error;
  bool _bioOn = false;
  int _lockRemaining = 0; // 백오프 잠금 남은 초 (0이면 시도 가능)
  bool _checking = false; // PIN 검증(PBKDF2) 진행 중
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final rem = await _lock.lockoutRemaining();
    if (!mounted) return;
    if (rem > 0) _startLockout(rem);
    _maybeBio();
  }

  void _startLockout(int secs) {
    _timer?.cancel();
    setState(() {
      _lockRemaining = secs;
      _pin = '';
      _error = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _lockRemaining -= 1);
      if (_lockRemaining <= 0) {
        t.cancel();
        setState(() => _lockRemaining = 0);
      }
    });
  }

  Future<void> _maybeBio() async {
    final on = await _lock.biometricEnabled();
    if (!mounted) return;
    setState(() => _bioOn = on);
    if (on) _tryBio();
  }

  Future<void> _tryBio() async {
    final ok = await _lock.authenticateBiometric();
    if (!ok || !mounted) return;
    await _lock.resetFailures();
    if (mounted) widget.onUnlocked();
  }

  Future<void> _onDigit(String d) async {
    if (_lockRemaining > 0 || _checking) return;
    if (_pin.length >= kPinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == kPinLength) {
      setState(() => _checking = true);
      final ok = await _lock.verifyPin(_pin);
      if (!mounted) return;
      if (ok) {
        await _lock.resetFailures();
        if (mounted) widget.onUnlocked();
        return;
      }
      final secs = await _lock.registerFailure();
      if (!mounted) return;
      setState(() => _checking = false);
      if (secs > 0) {
        _startLockout(secs);
      } else {
        setState(() {
          _error = '비밀번호가 맞지 않아요';
          _pin = '';
        });
      }
    }
  }

  void _del() {
    if (_pin.isEmpty || _lockRemaining > 0) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  String _fmt(int s) {
    if (s < 60) return '$s초';
    final m = s ~/ 60, sec = s % 60;
    return sec == 0 ? '$m분' : '$m분 $sec초';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            const Text('🌿', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text(
              '너의 정원',
              style: TextStyle(
                fontSize: 20,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _lockRemaining > 0
                  ? '너무 많이 시도했어요 · ${_fmt(_lockRemaining)} 후 다시'
                  : (_error ?? '비밀번호를 입력해 주세요'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: (_error != null || _lockRemaining > 0)
                    ? Colors.red.shade400
                    : AppColors.sub,
              ),
            ),
            const SizedBox(height: 24),
            _PinDots(filled: _pin.length),
            const Spacer(flex: 1),
            IgnorePointer(
              ignoring: _lockRemaining > 0,
              child: Opacity(
                opacity: _lockRemaining > 0 ? 0.35 : 1,
                child: _NumPad(
                  onDigit: _onDigit,
                  onDelete: _del,
                  onBiometric: _bioOn ? _tryBio : null,
                ),
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

/// PIN 설정/변경 화면 — 새 비밀번호 입력 후 한 번 더 확인. 성공 시 pin 반환.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String? _first;
  String? _error;

  bool get _confirming => _first != null;

  Future<void> _onDigit(String d) async {
    if (_pin.length >= kPinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == kPinLength) {
      if (!_confirming) {
        setState(() {
          _first = _pin;
          _pin = '';
        });
      } else {
        if (_pin == _first) {
          Navigator.pop(context, _first);
        } else {
          setState(() {
            _error = '비밀번호가 일치하지 않아요. 다시 설정해 주세요';
            _first = null;
            _pin = '';
          });
        }
      }
    }
  }

  void _del() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('앱 잠금 설정', style: TextStyle(color: AppColors.ink)),
      ),
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text(
              _confirming ? '한 번 더 입력해 주세요' : '새 비밀번호를 입력해 주세요',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '숫자 $kPinLength자리',
              style: TextStyle(
                fontSize: 13,
                color: _error != null ? Colors.red.shade400 : AppColors.faint,
              ),
            ),
            const SizedBox(height: 24),
            _PinDots(filled: _pin.length),
            const Spacer(flex: 1),
            _NumPad(onDigit: _onDigit, onDelete: _del),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled});
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < kPinLength; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? AppColors.green : Colors.transparent,
              border: Border.all(color: AppColors.green, width: 1.6),
            ),
          ),
      ],
    );
  }
}

class _NumPad extends StatelessWidget {
  const _NumPad({
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
  });
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return SizedBox(
        width: 78,
        height: 78,
        child: InkWell(
          onTap: onTap ?? () => onDigit(label),
          borderRadius: BorderRadius.circular(40),
          child: Center(
            child:
                child ??
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
          ),
        ),
      );
    }

    Widget row(List<Widget> w) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final x in w) Padding(padding: const EdgeInsets.all(6), child: x),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([key('1'), key('2'), key('3')]),
        row([key('4'), key('5'), key('6')]),
        row([key('7'), key('8'), key('9')]),
        row([
          onBiometric != null
              ? key(
                  'bio',
                  onTap: onBiometric,
                  child: const Icon(
                    Icons.fingerprint,
                    size: 30,
                    color: AppColors.green,
                  ),
                )
              : const SizedBox(width: 78, height: 78),
          key('0'),
          key(
            'del',
            onTap: onDelete,
            child: const Icon(
              Icons.backspace_outlined,
              size: 24,
              color: AppColors.sub,
            ),
          ),
        ]),
      ],
    );
  }
}
