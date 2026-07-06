import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 작성 중이던 마음 한 줄을 로컬에 보관 — 오프라인·전송 실패·앱 종료로도 글이 사라지지 않게.
/// 사적인 내용이라 secure storage(암호화)에 담는다. 슬롯은 하나(현재 키우는 식물 기준).
class EntryDraft {
  const EntryDraft({
    required this.plantId,
    required this.text,
    this.mood,
    this.topics = const [],
    this.emotions = const [],
  });

  final String plantId;
  final String text;
  final int? mood;
  final List<String> topics;
  final List<String> emotions;

  /// 아무 내용도 없는(저장할 가치가 없는) 초안인지.
  bool get isEmpty =>
      text.trim().isEmpty && mood == null && topics.isEmpty && emotions.isEmpty;
}

class DraftService {
  DraftService({FlutterSecureStorage? secureStorage})
    : _secure = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;
  static const _key = 'entry_draft_v1';

  Future<void> save(EntryDraft d) async {
    final json = jsonEncode({
      'plantId': d.plantId,
      'text': d.text,
      'mood': d.mood,
      'topics': d.topics,
      'emotions': d.emotions,
    });
    await _secure.write(key: _key, value: json);
  }

  Future<EntryDraft?> load() async {
    final raw = await _secure.read(key: _key);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return EntryDraft(
        plantId: (m['plantId'] as String?) ?? '',
        text: (m['text'] as String?) ?? '',
        mood: m['mood'] as int?,
        topics:
            (m['topics'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        emotions:
            (m['emotions'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );
    } catch (_) {
      // 손상된 초안은 무시(복원 실패로 앱을 막지 않는다).
      return null;
    }
  }

  Future<void> clear() async {
    await _secure.delete(key: _key);
  }
}
