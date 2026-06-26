import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// 앱 잠금 — PIN(해시 저장) + 선택적 생체인증. 사적인 마음 기록 보호용.
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  final _store = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  static const _kEnabled = 'lock_enabled';
  static const _kPinHash = 'lock_pin_hash';
  static const _kBio = 'lock_biometric';
  static const _salt = 'yourgarden::v1::';

  String _hash(String pin) =>
      sha256.convert(utf8.encode('$_salt$pin')).toString();

  Future<bool> isEnabled() async =>
      (await _store.read(key: _kEnabled)) == 'true';

  Future<bool> biometricEnabled() async =>
      (await _store.read(key: _kBio)) == 'true';

  /// PIN 설정 + 잠금 켜기.
  Future<void> setPin(String pin) async {
    await _store.write(key: _kPinHash, value: _hash(pin));
    await _store.write(key: _kEnabled, value: 'true');
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _store.read(key: _kPinHash);
    return stored != null && stored == _hash(pin);
  }

  Future<void> disable() async {
    await _store.write(key: _kEnabled, value: 'false');
    await _store.write(key: _kBio, value: 'false');
    await _store.delete(key: _kPinHash);
  }

  Future<void> setBiometric(bool on) async =>
      _store.write(key: _kBio, value: on ? 'true' : 'false');

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
