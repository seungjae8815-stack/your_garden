import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// 앱 잠금 — PIN(PBKDF2 해시 저장) + 선택적 생체인증. 사적인 마음 기록 보호용.
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  final _store = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  static const _kEnabled = 'lock_enabled';
  static const _kPinHash = 'lock_pin_hash';
  static const _kBio = 'lock_biometric';
  static const _kFails = 'lock_fails';
  static const _kLockUntil = 'lock_until';

  // PIN 저장 형식: pbkdf2$<iterations>$<saltB64>$<hashB64> (2-8)
  static const _iterations = 100000;
  // 레거시 형식(고정 salt + 단일 SHA-256) — 검증 성공 시 새 형식으로 자동 업그레이드.
  static const _legacySalt = 'yourgarden::v1::';

  String _legacyHash(String pin) =>
      sha256.convert(utf8.encode('$_legacySalt$pin')).toString();

  List<int> _randomSalt() {
    final r = Random.secure();
    return List<int>.generate(16, (_) => r.nextInt(256));
  }

  Future<String> _encode(String pin, List<int> salt, int iterations) async {
    final dk = await compute(_pbkdf2Job, _Pbkdf2Job(pin, salt, iterations));
    return [
      'pbkdf2',
      '$iterations',
      base64Encode(salt),
      base64Encode(dk),
    ].join('\$');
  }

  Future<bool> isEnabled() async =>
      (await _store.read(key: _kEnabled)) == 'true';

  Future<bool> biometricEnabled() async =>
      (await _store.read(key: _kBio)) == 'true';

  /// PIN 설정 + 잠금 켜기. (매번 새 랜덤 salt로 저장)
  Future<void> setPin(String pin) async {
    final encoded = await _encode(pin, _randomSalt(), _iterations);
    await _store.write(key: _kPinHash, value: encoded);
    await _store.write(key: _kEnabled, value: 'true');
    await resetFailures();
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _store.read(key: _kPinHash);
    if (stored == null) return false;

    if (stored.startsWith('pbkdf2\$')) {
      final parts = stored.split('\$');
      if (parts.length != 4) return false;
      final iterations = int.tryParse(parts[1]) ?? _iterations;
      final salt = base64Decode(parts[2]);
      final dk = await compute(_pbkdf2Job, _Pbkdf2Job(pin, salt, iterations));
      return _constEq(base64Encode(dk), parts[3]);
    }

    // 레거시 해시 — 맞으면 새 PBKDF2 형식으로 재저장(업그레이드).
    if (_constEq(stored, _legacyHash(pin))) {
      await setPin(pin);
      return true;
    }
    return false;
  }

  Future<void> disable() async {
    await _store.write(key: _kEnabled, value: 'false');
    await _store.write(key: _kBio, value: 'false');
    await _store.delete(key: _kPinHash);
    await resetFailures();
  }

  Future<void> setBiometric(bool on) async =>
      _store.write(key: _kBio, value: on ? 'true' : 'false');

  // ── 무차별 대입 방지: 실패 누적 + 백오프 잠금 (2-7) ──────────────
  Future<int> _failCount() async =>
      int.tryParse(await _store.read(key: _kFails) ?? '') ?? 0;

  /// 지금 남은 잠금 시간(초). 0이면 시도 가능.
  Future<int> lockoutRemaining() async {
    final until = int.tryParse(await _store.read(key: _kLockUntil) ?? '') ?? 0;
    final rem = until - DateTime.now().millisecondsSinceEpoch;
    return rem > 0 ? (rem / 1000).ceil() : 0;
  }

  /// PIN 실패 1회 기록 → 5회부터 백오프 잠금. 반환: 새로 걸린 잠금 초(0=아직 여유).
  Future<int> registerFailure() async {
    final fails = (await _failCount()) + 1;
    await _store.write(key: _kFails, value: '$fails');
    final secs = _backoffSeconds(fails);
    if (secs > 0) {
      final until = DateTime.now().millisecondsSinceEpoch + secs * 1000;
      await _store.write(key: _kLockUntil, value: '$until');
    }
    return secs;
  }

  int _backoffSeconds(int fails) {
    if (fails < 5) return 0;
    if (fails == 5) return 30;
    if (fails == 6) return 60;
    if (fails == 7) return 180;
    if (fails == 8) return 300;
    return 900; // 9회 이상 → 15분
  }

  /// 성공(또는 잠금 해제/재설정) 시 실패 기록 초기화.
  Future<void> resetFailures() async {
    await _store.delete(key: _kFails);
    await _store.delete(key: _kLockUntil);
  }

  /// 타이밍 공격 완화용 상수시간 비교.
  bool _constEq(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// 이 기기가 생체인증을 지원하는지.
  Future<bool> canUseBiometric() async {
    try {
      return (await _auth.isDeviceSupported()) &&
          (await _auth.canCheckBiometrics);
    } catch (_) {
      return false;
    }
  }

  /// 생체인증 시도. 성공하면 true.
  Future<bool> authenticateBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: '너의 정원을 열려면 인증해 주세요',
        options: const AuthenticationOptions(
          biometricOnly: false, // 기기 PIN/패턴도 폴백 허용
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

/// PBKDF2-HMAC-SHA256 (파생키 32바이트 = 단일 블록). 백그라운드 isolate에서 실행.
class _Pbkdf2Job {
  const _Pbkdf2Job(this.pin, this.salt, this.iterations);
  final String pin;
  final List<int> salt;
  final int iterations;
}

List<int> _pbkdf2Job(_Pbkdf2Job job) {
  final hmac = Hmac(sha256, utf8.encode(job.pin));
  // U1 = HMAC(pin, salt || INT_32_BE(1))
  final block = <int>[...job.salt, 0, 0, 0, 1];
  var u = hmac.convert(block).bytes;
  final t = List<int>.from(u);
  for (var i = 1; i < job.iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < t.length; j++) {
      t[j] ^= u[j];
    }
  }
  return t;
}
