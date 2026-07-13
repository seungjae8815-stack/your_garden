import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 앱 업데이트 후 첫 실행에서 "새로워진 점"을 한 번 안내하기 위한 상태 관리.
/// 마지막으로 확인한 버전을 기기에 기록하고, 현재 버전에 노트가 있고 아직
/// 확인하지 않았다면 한 번 띄운다.
///
/// 신규 설치 사용자에겐 뜨지 않는다 — 계정을 처음 만들 때 [markSeenCurrent]로
/// 현재 버전을 미리 "본 것"으로 기록하기 때문. (기존 사용자는 이 기록이 없어
/// 새 버전으로 업데이트하면 안내가 뜬다.)
class WhatsNew {
  WhatsNew._();
  static final WhatsNew instance = WhatsNew._();

  final _store = const FlutterSecureStorage();
  static const _kSeen = 'whats_new_seen_version';

  /// 버전별 업데이트 노트. 새 버전을 낼 때마다 여기에 항목을 추가한다.
  /// key는 pubspec version(빌드번호 제외)과 정확히 같아야 한다. (예: '1.0.3')
  static const Map<String, List<String>> notes = {
    '1.0.3': [
      '🌸 거둔 꽃을 기념 카드로 남기고 공유할 수 있어요',
      '🌿 정원과 "함께한 지 N일째"가 표시돼요',
      '💬 식물의 답장이 더 다양하고, 고른 감정에 맞게 바뀌어요',
      '🏷️ 도감·돌아보기에 지어준 이름이 함께 보여요',
      '🛠️ 알림·화면 안정성을 손봤어요',
    ],
    '1.0.2': [
      '🌱 식물마다 이름을 지어줄 수 있어요',
      '✍️ 오프라인에서도 마음이 사라지지 않고 임시 저장돼요',
      '🔒 앱 잠금이 더 안전해졌어요 — 잠금 화면·화면 캡처 보호',
      '🏷️ 마음 태그와 인사이트로 나를 돌아볼 수 있어요',
      '🗑️ 설정에서 내 정원 데이터를 완전히 삭제할 수 있어요',
      '🛡️ 개인정보 보호와 안정성을 개선했어요',
    ],
  };

  Future<String> _currentVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// 현재 버전의 노트 (설정에서 "이번 업데이트 다시 보기"용). 없으면 null.
  Future<WhatsNewEntry?> currentEntry() async {
    try {
      final v = await _currentVersion();
      final n = notes[v];
      return n == null ? null : WhatsNewEntry(version: v, notes: n);
    } catch (_) {
      return null;
    }
  }

  /// 지금 자동으로 띄울 업데이트 안내가 있으면 돌려준다. 없으면 null.
  Future<WhatsNewEntry?> pending() async {
    try {
      final current = await _currentVersion();
      final seen = await _store.read(key: _kSeen);
      if (seen == current) return null; // 이미 확인함
      final entry = notes[current];
      if (entry == null) {
        // 이 버전 노트가 없으면 조용히 기록만 갱신.
        await _store.write(key: _kSeen, value: current);
        return null;
      }
      // 노트가 있고 아직 안 봄 → 띄운다. (확인 후 markSeen에서 기록)
      return WhatsNewEntry(version: current, notes: entry);
    } catch (_) {
      return null;
    }
  }

  /// 안내를 봤다고 기록.
  Future<void> markSeen(String version) async {
    try {
      await _store.write(key: _kSeen, value: version);
    } catch (_) {}
  }

  /// 새 계정 생성 시 호출 — 현재 버전을 "이미 본" 것으로 기록해 신규 설치
  /// 사용자에겐 업데이트 안내가 뜨지 않게 한다. (실패해도 무시)
  Future<void> markSeenCurrent() async {
    try {
      await _store.write(key: _kSeen, value: await _currentVersion());
    } catch (_) {}
  }
}

class WhatsNewEntry {
  const WhatsNewEntry({required this.version, required this.notes});
  final String version;
  final List<String> notes;
}
