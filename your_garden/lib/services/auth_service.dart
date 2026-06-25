import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'nickname.dart';

class AuthService {
  AuthService(this._client, {FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  final SupabaseClient _client;
  final FlutterSecureStorage _secure;
  static const _kDeviceId = 'device_id';
  static const _kOnboarded = 'onboarded';
  static const _kTestFast = 'test_fast';

  Future<AuthResult> signInAndUpsertProfile() async {
    final auth = _client.auth;

    // 1) 익명 로그인 (이미 세션 있으면 그대로 사용)
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    final uid = auth.currentUser!.id;

    // 2) device_id를 secure storage에 보관 (재설치 시 새 ID — MVP 감수)
    var deviceId = await _secure.read(key: _kDeviceId);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _secure.write(key: _kDeviceId, value: deviceId);
    }

    // 3) profile 존재 여부 확인 → 없으면 닉네임 생성하며 insert
    final existing = await _client
        .from('profiles')
        .select('id, nickname, is_public')
        .eq('id', uid)
        .maybeSingle();

    if (existing == null) {
      final nickname = generateNickname();
      await _client.from('profiles').insert({
        'id': uid,
        'device_id': deviceId,
        'nickname': nickname,
        'is_public': false,
      });
      return AuthResult(uid: uid, nickname: nickname, isPublic: false, isNew: true);
    }

    return AuthResult(
      uid: uid,
      nickname: existing['nickname'] as String,
      isPublic: existing['is_public'] as bool,
      isNew: false,
    );
  }

  /// 온보딩을 이미 마쳤는지 (로컬 플래그).
  Future<bool> isOnboarded() async {
    return (await _secure.read(key: _kOnboarded)) == '1';
  }

  /// 온보딩 완료 — 공개 여부 저장 + 완료 플래그 기록.
  Future<void> completeOnboarding({
    required String uid,
    required bool isPublic,
  }) async {
    await _client.from('profiles').update({'is_public': isPublic}).eq('id', uid);
    await _secure.write(key: _kOnboarded, value: '1');
  }

  /// 테스트 모드 플래그 (쓸 때마다 성장).
  Future<bool> isTestFast() async =>
      (await _secure.read(key: _kTestFast)) == '1';

  Future<void> setTestFast(bool v) async =>
      _secure.write(key: _kTestFast, value: v ? '1' : '0');

  /// 테스트용: 온보딩/테스트 플래그 초기화 (기기 ID·세션은 유지).
  Future<void> resetLocal() async {
    await _secure.delete(key: _kOnboarded);
    await _secure.delete(key: _kTestFast);
  }
}

class AuthResult {
  AuthResult({
    required this.uid,
    required this.nickname,
    required this.isPublic,
    required this.isNew,
  });

  final String uid;
  final String nickname;
  final bool isPublic;
  final bool isNew;
}
