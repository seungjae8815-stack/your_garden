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

  @override
  void initState() {
    super.initState();
    _maybeBio();
  }

  Future<void> _maybeBio() async {
    final on = await _lock.biometricEnabled();
    if (!mounted) return;
    setState(() => _bioOn = on);
    if (on) _tryBio();
  }

  Future<void> _tryBio() async {
    final ok = await _lock.authenticateBiometric();
    if (ok && mounted) widget.onUnlocked();
  }

  Future<void> _onDigit(String d) async {
    if (_pin.length >= kPinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == kPinLength) {
      final ok = await _lock.verifyPin(_pin);
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
      } else {
        setState(() {
          _error = '비밀번호가 맞지 않아요';
          _pin = '';
        });
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
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            const Text('🌿', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text('너의 정원',
                style: TextStyle(
                    fontSize: 20,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(_error ?? '비밀번호를 입력해 주세요',
                style: TextStyle(
                    fontSize: 13,
                    color: _error != null ? Colors.red.shade400 : AppColors.sub)),
            const SizedBox(height: 24),
            _PinDots(filled: _pin.length),
            const Spacer(flex: 1),
            _NumPad(
              onDigit: _onDigit,
              onDelete: _del,
              onBiometric: _bioOn ? _tryBio : null,
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
            Text(_confirming ? '한 번 더 입력해 주세요' : '새 비밀번호를 입력해 주세요',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(_error ?? '숫자 $kPinLength자리',
                style: TextStyle(
                    fontSize: 13,
                    color: _error != null ? Colors.red.shade400 : AppColors.faint)),
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
  const _NumPad({required this.onDigit, required this.onDelete, this.onBiometric});
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
            child: child ??
                Text(label,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink)),
          ),
        ),
      );
    }

    Widget row(List<Widget> w) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [for (final x in w) Padding(padding: const EdgeInsets.all(6), child: x)]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([key('1'), key('2'), key('3')]),
        row([key('4'), key('5'), key('6')]),
        row([key('7'), key('8'), key('9')]),
        row([
          onBiometric != null
              ? key('bio',
                  onTap: onBiometric,
                  child: const Icon(Icons.fingerprint,
                      size: 30, color: AppColors.green))
              : const SizedBox(width: 78, height: 78),
          key('0'),
          key('del',
              onTap: onDelete,
              child: const Icon(Icons.backspace_outlined,
                  size: 24, color: AppColors.sub)),
        ]),
      ],
    );
  }
}
