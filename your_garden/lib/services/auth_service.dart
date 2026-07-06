import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
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
  static const _kBackupCode = 'backup_code';
  static const _kBackupNudgedAt = 'backup_nudged_at';

  /// OAuth 리다이렉트 딥링크 (AndroidManifest·Supabase Redirect URLs와 일치해야 함).
  static const authRedirect = 'com.yourgarden.app://login-callback';

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
        .select('id, nickname, is_public, garden_name')
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
      return AuthResult(
        uid: uid,
        nickname: nickname,
        isPublic: false,
        isNew: true,
      );
    }

    return AuthResult(
      uid: uid,
      nickname: existing['nickname'] as String,
      isPublic: existing['is_public'] as bool,
      gardenName: existing['garden_name'] as String?,
      isNew: false,
    );
  }

  /// 온보딩을 이미 마쳤는지 (로컬 플래그).
  Future<bool> isOnboarded() async {
    return (await _secure.read(key: _kOnboarded)) == '1';
  }

  /// 복구로 되찾은 정원은 이미 온보딩을 마친 계정 — 로컬 완료 플래그를 세워
  /// 다음 실행에서 온보딩을 건너뛰고 바로 정원으로 들어가게 한다.
  Future<void> markOnboarded() async {
    await _secure.write(key: _kOnboarded, value: '1');
  }

  /// 온보딩 완료 — 공개 여부·정원 이름 저장 + 완료 플래그 기록.
  Future<void> completeOnboarding({
    required String uid,
    required bool isPublic,
    String? gardenName,
  }) async {
    final data = <String, dynamic>{'is_public': isPublic};
    final name = gardenName?.trim();
    if (name != null && name.isNotEmpty) data['garden_name'] = name;
    await _client.from('profiles').update(data).eq('id', uid);
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

  /// 계정 완전 삭제 (Google Play "계정 삭제" 요건).
  /// 서버의 정원 데이터(profiles→plants/기록 cascade)와 인증 계정(auth.users)을
  /// 지운 뒤, 이 기기의 로컬 흔적을 모두 비우고 세션을 정리한다.
  /// 이후 앱은 새 익명 계정으로 처음부터 시작한다.
  Future<void> deleteAccount() async {
    await _client.rpc('delete_account');
    // 기기에 남은 모든 로컬 상태 제거 (기기 ID·온보딩·백업 코드·넛지·테스트 등).
    await _secure.deleteAll();
    // 이미 서버에서 사라진 세션을 로컬에서 정리 → 다음 실행 때 새 익명 로그인.
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }

  // ── 백업·복구 (복구 코드, 이메일 없음) ───────────────────────
  // 코드의 해시를 내 프로필에 저장해 두고, 다른 기기에서는 그 코드로
  // 정원 데이터(식물·기록)를 현재 익명 계정으로 '이전'해온다. (claim_garden RPC)
  // 이메일/발송 한도와 무관하게 동작.

  String _hash(String code) =>
      sha256.convert(utf8.encode('garden:backup:$code')).toString();

  /// 사람이 적기 쉬운 코드 생성: XXXX-XXXX-XXXX (헷갈리는 글자 제외).
  String _genCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    String group() =>
        List.generate(4, (_) => alphabet[r.nextInt(alphabet.length)]).join();
    return '${group()}-${group()}-${group()}';
  }

  /// 이미 백업했는지 (로컬에 코드 보관 중인지).
  Future<bool> isBackedUp() async =>
      (await _secure.read(key: _kBackupCode)) != null;

  Future<String?> backupCode() async => _secure.read(key: _kBackupCode);

  /// 정원이 지켜지고 있는지 — Google 연결 또는 복구 코드 중 하나라도 있으면 안전.
  Future<bool> isProtected() async => isGoogleLinked || await isBackedUp();

  /// 백업 권유(넛지)를 마지막으로 띄운 시각. 없으면 null.
  Future<DateTime?> backupNudgedAt() async {
    final raw = await _secure.read(key: _kBackupNudgedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// 백업 권유를 방금 띄웠다고 기록 (며칠간 다시 묻지 않도록).
  Future<void> markBackupNudged() async {
    await _secure.write(
      key: _kBackupNudgedAt,
      value: DateTime.now().toIso8601String(),
    );
  }

  /// 백업 켜기 — 복구 코드를 만들고 그 해시를 내 프로필에 저장. 코드를 돌려준다.
  Future<String> createBackup() async {
    final existing = await _secure.read(key: _kBackupCode);
    if (existing != null) return existing;
    final code = _genCode();
    final uid = _client.auth.currentUser!.id;
    await _client
        .from('profiles')
        .update({'backup_code_hash': _hash(code)})
        .eq('id', uid);
    await _secure.write(key: _kBackupCode, value: code);
    return code;
  }

  /// 복구 — 코드로 정원 데이터를 현재 계정으로 이전(앱 재시작 권장).
  Future<void> recoverWithCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    final ok = await _client.rpc(
      'claim_garden',
      params: {'p_hash': _hash(code)},
    );
    if (ok != true) {
      throw Exception('복구 코드를 찾을 수 없어요');
    }
    await _secure.write(key: _kBackupCode, value: code);
  }

  // ── 백업·복구 (Google 계정) ──────────────────────────────
  // 익명 계정에 Google 신원을 연결(linkIdentity) → 같은 정원 유지.
  // 다른 기기에선 Google 로그인(signInWithOAuth)으로 그 정원을 되찾음.

  /// 현재 계정에 Google이 연결돼 있는지.
  bool get isGoogleLinked {
    final ids = _client.auth.currentUser?.identities;
    return ids != null && ids.any((i) => i.provider == 'google');
  }

  /// Google 백업 — 현재(익명) 정원에 Google 신원 연결. 브라우저가 열린다.
  Future<void> linkGoogle() async {
    await _client.auth.linkIdentity(
      OAuthProvider.google,
      redirectTo: authRedirect,
    );
  }

  /// Google 복구 — Google로 로그인해 그 정원으로 전환. 브라우저가 열린다.
  Future<void> signInGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: authRedirect,
    );
  }
}

class AuthResult {
  AuthResult({
    required this.uid,
    required this.nickname,
    required this.isPublic,
    required this.isNew,
    this.gardenName,
  });

  final String uid;
  final String nickname;
  final bool isPublic;
  final bool isNew;
  final String? gardenName; // 내가 지어준 정원 이름 (없으면 닉네임 사용)

  /// 화면에 보일 정원 이름 — 직접 지은 이름 우선, 없으면 자동 닉네임.
  String get displayGardenName =>
      (gardenName != null && gardenName!.trim().isNotEmpty)
      ? gardenName!.trim()
      : nickname;

  AuthResult copyWith({String? gardenName}) => AuthResult(
    uid: uid,
    nickname: nickname,
    isPublic: isPublic,
    isNew: isNew,
    gardenName: gardenName ?? this.gardenName,
  );
}
