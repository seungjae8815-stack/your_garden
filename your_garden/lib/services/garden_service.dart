import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/plant_voice.dart';
import '../widgets/plant_painter.dart';

/// 정원 탭을 다시 불러오게 하는 신호 (다른 탭에서 데이터 바꿨을 때).
final ValueNotifier<int> gardenDirty = ValueNotifier<int>(0);
void markGardenDirty() => gardenDirty.value++;

/// 정원 속 현재 식물 1개.
class Plant {
  const Plant({
    required this.id,
    required this.stage,
    required this.isComplete,
    this.species = 'flower',
    this.name,
    this.placed = false,
    this.posIndex,
    this.posX,
    this.posY,
    this.reflection,
    this.lastGrowthAt,
    this.startedAt,
  });

  final String id;
  final int stage; // current_stage 1..5
  final bool isComplete;
  final String species; // flower / succulent / herb / tree
  final String? name; // 내가 지어준 이름 (감정 챕터 이름)
  final bool placed; // 정원에 배치됨
  final int? posIndex; // (구버전) 고정 자리 인덱스 — pos_x/pos_y 없을 때만 사용
  final double? posX; // 자유 배치 가로 (0..1)
  final double? posY; // 자유 배치 세로 (0..1, 식물 바닥이 닿는 지면선)
  final String? reflection; // 거둘 때 남긴 마무리 한마디
  final DateTime? lastGrowthAt;
  final DateTime? startedAt;

  /// 다 자람(만개). 거두기 전까지 받침대에 남아 있음. (isComplete=거둬서 모종함行)
  bool get isBloomed => stage >= 5;

  /// 이름만 바꾼 사본 (DB 갱신 후 화면에 바로 반영할 때).
  Plant withName(String? name) => Plant(
    id: id,
    stage: stage,
    isComplete: isComplete,
    species: species,
    name: name,
    placed: placed,
    posIndex: posIndex,
    posX: posX,
    posY: posY,
    reflection: reflection,
    lastGrowthAt: lastGrowthAt,
    startedAt: startedAt,
  );

  factory Plant.fromMap(Map<String, dynamic> m) => Plant(
    id: m['id'] as String,
    stage: m['current_stage'] as int,
    isComplete: m['is_completed'] as bool,
    species: (m['species'] as String?) ?? 'flower',
    name: m['name'] as String?,
    placed: (m['placed'] as bool?) ?? false,
    posIndex: m['pos_index'] as int?,
    posX: (m['pos_x'] as num?)?.toDouble(),
    posY: (m['pos_y'] as num?)?.toDouble(),
    reflection: m['reflection'] as String?,
    lastGrowthAt: m['last_growth_at'] == null
        ? null
        : DateTime.parse(m['last_growth_at'] as String),
    startedAt: m['started_at'] == null
        ? null
        : DateTime.parse(m['started_at'] as String),
  );
}

/// addEntry 결과: 갱신된 식물 + 성장 여부 + 식물의 답장.
class EntryResult {
  const EntryResult(this.plant, {required this.grew, this.reply = ''});
  final Plant plant;
  final bool grew; // 이번 기록으로 단계가 올랐는지
  final String reply; // 식물의 공감 한마디
}

/// 기록(잎) 하나 — 기록 탭에서 다시보기.
class EntryRecord {
  const EntryRecord(
    this.text,
    this.createdAt, {
    this.mood,
    this.reply = '',
    this.topicTags = const [],
    this.emotionTags = const [],
  });
  final String text;
  final DateTime createdAt;
  final int? mood; // 기분 1..5 (없을 수 있음)
  final String reply; // 그때 식물의 답장
  final List<String> topicTags; // 주제(양분) 태그 키
  final List<String> emotionTags; // 감정 태그 키
}

/// Postgres `text[]` (`List<dynamic>`) → `List<String>`.
List<String> _strList(dynamic v) =>
    v == null ? const [] : (v as List).map((e) => e.toString()).toList();

/// 본인 정원(식물/잎) 데이터 레이어. Supabase Postgres.
class GardenService {
  GardenService(this._client);
  final SupabaseClient _client;

  /// 진행 중(미완성) 식물 반환. 없으면 새로 심음.
  Future<Plant> ensureActivePlant(String ownerId) async {
    final existing = await _client
        .from('plants')
        .select()
        .eq('owner_id', ownerId)
        .eq('is_completed', false)
        .order('started_at')
        .limit(1)
        .maybeSingle();
    if (existing != null) return Plant.fromMap(existing);
    return _insertPlant(ownerId);
  }

  /// 만개한 식물 다음 — 새 식물 시작.
  Future<Plant> startNewPlant(String ownerId) => _insertPlant(ownerId);

  static final Random _rng = Random();

  /// 테스트 모드: 켜면 쓸 때마다 한 단계씩 성장(1일 1단계 무시). 부팅 시 로드됨.
  static bool testFastGrowth = false;

  Future<Plant> _insertPlant(String ownerId) async {
    const pool = [...kFlowerSpecies, ...kTreeSpecies];
    final species = pool[_rng.nextInt(pool.length)];
    final row = await _client
        .from('plants')
        .insert({'owner_id': ownerId, 'species': species, 'current_stage': 1})
        .select()
        .single();
    return Plant.fromMap(row);
  }

  /// 이 식물에 묻힌 마음(잎) 수.
  Future<int> entryCount(String plantId) async {
    final rows = await _client
        .from('entries')
        .select('id')
        .eq('plant_id', plantId);
    return (rows as List).length;
  }

  /// 마음 한 줄 묻기 → entry 저장 → (하루 첫 기록이면) 식물 1단계 성장.
  /// 글 없이 기분(mood)만 묻어도 됨 — 그땐 user_text가 빈 문자열.
  ///
  /// 서버 RPC `add_entry`로 원자화(연타 race·부분 실패·시계 조작 방지, 2-10/2-11).
  /// 성장 여부를 서버가 판정하므로, 답장은 성장/유지 두 후보를 넘겨 서버가 고른다.
  Future<EntryResult> addEntry({
    required Plant plant,
    required String text,
    int? mood,
    List<String> topicTags = const [],
    List<String> emotionTags = const [],
  }) async {
    // 답장 두 후보(공감 + 양분). ai_empathy는 추후 AI용으로 비워둠.
    // 감정 태그를 답장 결에 반영해 반복을 줄인다.
    final replyGrew = plant.stage < 5
        ? plantReply(
            mood: mood,
            grew: true,
            stage: plant.stage + 1,
            topicTags: topicTags,
            emotionTags: emotionTags,
          )
        : plantReply(
            mood: mood,
            grew: false,
            stage: plant.stage,
            topicTags: topicTags,
            emotionTags: emotionTags,
          );
    final replyStay = plantReply(
      mood: mood,
      grew: false,
      stage: plant.stage,
      topicTags: topicTags,
      emotionTags: emotionTags,
    );

    try {
      final res =
          await _client.rpc(
                'add_entry',
                params: {
                  'p_plant_id': plant.id,
                  'p_user_text': text,
                  'p_mood': mood,
                  'p_topic_tags': topicTags,
                  'p_emotion_tags': emotionTags,
                  'p_reply_grew': replyGrew,
                  'p_reply_stay': replyStay,
                  'p_test_fast': testFastGrowth,
                },
              )
              as Map<String, dynamic>;
      return EntryResult(
        Plant.fromMap(res['plant'] as Map<String, dynamic>),
        grew: res['grew'] as bool,
        reply: res['reply'] as String,
      );
    } on PostgrestException catch (e) {
      // add_entry RPC(마이그레이션 0012) 미적용 시 레거시 비원자 경로로 폴백.
      if (_isMissingFunction(e)) {
        return _addEntryLegacy(
          plant: plant,
          text: text,
          mood: mood,
          topicTags: topicTags,
          emotionTags: emotionTags,
          replyGrew: replyGrew,
          replyStay: replyStay,
        );
      }
      rethrow;
    }
  }

  /// PostgREST가 함수를 못 찾을 때(RPC 미배포) 판별.
  bool _isMissingFunction(PostgrestException e) =>
      e.code == 'PGRST202' ||
      e.message.contains('add_entry') ||
      e.message.contains('schema cache');

  /// 레거시 경로 — RPC 미배포 시에만 사용(클라이언트 판정, 비원자).
  Future<EntryResult> _addEntryLegacy({
    required Plant plant,
    required String text,
    int? mood,
    required List<String> topicTags,
    required List<String> emotionTags,
    required String replyGrew,
    required String replyStay,
  }) async {
    final now = DateTime.now();
    final grewToday =
        !testFastGrowth &&
        plant.lastGrowthAt != null &&
        _sameDay(plant.lastGrowthAt!, now);
    final willGrow = !grewToday && plant.stage < 5;
    final reply = willGrow ? replyGrew : replyStay;

    await _client.from('entries').insert({
      'plant_id': plant.id,
      'user_text': text,
      'ai_empathy': '',
      'ai_plant_voice': reply,
      'stage_when_added': plant.stage,
      'mood': mood,
      'topic_tags': topicTags.isEmpty ? null : topicTags,
      'emotion_tags': emotionTags.isEmpty ? null : emotionTags,
    });

    if (!willGrow) {
      return EntryResult(plant, grew: false, reply: reply);
    }

    final updated = await _client
        .from('plants')
        .update({
          'current_stage': plant.stage + 1,
          'last_growth_at': now.toUtc().toIso8601String(),
        })
        .eq('id', plant.id)
        .select()
        .single();
    return EntryResult(Plant.fromMap(updated), grew: true, reply: reply);
  }

  /// 테스트용: 글 없이 한 단계 성장시킴.
  Future<Plant> debugAdvance(Plant plant) async {
    if (plant.stage >= 5) return plant;
    final newStage = plant.stage + 1;
    final updated = await _client
        .from('plants')
        .update({
          'current_stage': newStage,
          'last_growth_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', plant.id)
        .select()
        .single();
    return Plant.fromMap(updated);
  }

  /// 다 자란 식물을 모종함으로 거둠 → 완성 처리. 거둘 때 마무리 한마디(reflection)도 남김.
  Future<void> harvest(String plantId, {String? reflection}) async {
    final data = <String, dynamic>{'is_completed': true};
    if (reflection != null) data['reflection'] = reflection;
    await _client.from('plants').update(data).eq('id', plantId);
  }

  /// 특정 식물에 묻은 마음들(오래된 순) — 감정의 여정 다시보기.
  Future<List<EntryRecord>> entriesForPlant(String plantId) async {
    final rows = await _client
        .from('entries')
        .select(
          'user_text, created_at, mood, ai_plant_voice, topic_tags, emotion_tags',
        )
        .eq('plant_id', plantId)
        .order('created_at', ascending: true);
    return (rows as List).map((m) {
      final mm = m as Map<String, dynamic>;
      return EntryRecord(
        mm['user_text'] as String,
        DateTime.parse(mm['created_at'] as String),
        mood: mm['mood'] as int?,
        reply: (mm['ai_plant_voice'] as String?) ?? '',
        topicTags: _strList(mm['topic_tags']),
        emotionTags: _strList(mm['emotion_tags']),
      );
    }).toList();
  }

  /// 완성(만개)한 식물들 — 도감/정원 장식용.
  Future<List<Plant>> completedPlants(String ownerId) async {
    final rows = await _client
        .from('plants')
        .select()
        .eq('owner_id', ownerId)
        .eq('is_completed', true)
        .order('started_at');
    return (rows as List)
        .map((m) => Plant.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// 내가 묻은 마음 기록들 (최신순). RLS가 본인 것만 반환.
  Future<List<EntryRecord>> recentEntries({int limit = 200}) async {
    final rows = await _client
        .from('entries')
        .select(
          'user_text, created_at, mood, ai_plant_voice, topic_tags, emotion_tags',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((m) {
      final mm = m as Map<String, dynamic>;
      return EntryRecord(
        mm['user_text'] as String,
        DateTime.parse(mm['created_at'] as String),
        mood: mm['mood'] as int?,
        reply: (mm['ai_plant_voice'] as String?) ?? '',
        topicTags: _strList(mm['topic_tags']),
        emotionTags: _strList(mm['emotion_tags']),
      );
    }).toList();
  }

  /// 오늘(로컬 기준) 이 식물에 이미 마음을 묻었는지.
  Future<bool> checkedInToday(String plantId) async {
    final now = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day);
    final rows = await _client
        .from('entries')
        .select('id')
        .eq('plant_id', plantId)
        .gte('created_at', startLocal.toUtc().toIso8601String())
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  /// 식물을 정원 자유 위치에 심기 (정규화 좌표 0..1).
  Future<void> place(
    String plantId, {
    required double x,
    required double y,
  }) async {
    await _client
        .from('plants')
        .update({'placed': true, 'pos_x': x, 'pos_y': y, 'pos_index': null})
        .eq('id', plantId);
  }

  /// 정원에서 거두기 (모종함으로).
  Future<void> unplace(String plantId) async {
    await _client
        .from('plants')
        .update({
          'placed': false,
          'pos_index': null,
          'pos_x': null,
          'pos_y': null,
        })
        .eq('id', plantId);
  }

  /// 테스트용: 현재 키우는 식물의 종류 변경 (화분류/나무 확인).
  Future<void> setActiveSpecies(String ownerId, String species) async {
    final p = await ensureActivePlant(ownerId);
    await _client.from('plants').update({'species': species}).eq('id', p.id);
  }

  /// 식물에 이름 붙이기 (감정 챕터 이름). 빈 문자열이면 지움.
  Future<void> renamePlant(String plantId, String name) async {
    final trimmed = name.trim();
    await _client
        .from('plants')
        .update({'name': trimmed.isEmpty ? null : trimmed})
        .eq('id', plantId);
  }

  /// 정원 공개 여부 변경.
  Future<void> setPublic(String uid, bool isPublic) async {
    await _client
        .from('profiles')
        .update({'is_public': isPublic})
        .eq('id', uid);
  }

  /// 이 계정에 식물(정원 데이터)이 하나라도 있는지 — 복구 전 '기록이 사라질 수 있어요' 경고용.
  Future<bool> hasAnyData(String ownerId) async {
    final rows = await _client
        .from('plants')
        .select('id')
        .eq('owner_id', ownerId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  /// 내 모든 식물·기록 삭제 (plants 삭제 시 entries는 cascade).
  Future<void> deleteAllData(String ownerId) async {
    await _client.from('plants').delete().eq('owner_id', ownerId);
  }

  bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}
