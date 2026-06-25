import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    this.placed = false,
    this.posIndex,
    this.lastGrowthAt,
    this.startedAt,
  });

  final String id;
  final int stage; // current_stage 1..5
  final bool isComplete;
  final String species; // flower / succulent / herb / tree
  final bool placed; // 정원에 배치됨
  final int? posIndex; // 배치된 자리 인덱스
  final DateTime? lastGrowthAt;
  final DateTime? startedAt;

  factory Plant.fromMap(Map<String, dynamic> m) => Plant(
        id: m['id'] as String,
        stage: m['current_stage'] as int,
        isComplete: m['is_completed'] as bool,
        species: (m['species'] as String?) ?? 'flower',
        placed: (m['placed'] as bool?) ?? false,
        posIndex: m['pos_index'] as int?,
        lastGrowthAt: m['last_growth_at'] == null
            ? null
            : DateTime.parse(m['last_growth_at'] as String),
        startedAt: m['started_at'] == null
            ? null
            : DateTime.parse(m['started_at'] as String),
      );
}

/// addEntry 결과: 갱신된 식물 + 성장 여부.
class EntryResult {
  const EntryResult(this.plant, {required this.grew});
  final Plant plant;
  final bool grew; // 이번 기록으로 단계가 올랐는지
}

/// 기록(잎) 하나 — 기록 탭에서 다시보기.
class EntryRecord {
  const EntryRecord(this.text, this.createdAt);
  final String text;
  final DateTime createdAt;
}

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
    final species = kPlantSpecies[_rng.nextInt(kPlantSpecies.length)];
    final row = await _client
        .from('plants')
        .insert({
          'owner_id': ownerId,
          'species': species,
          'current_stage': 1,
        })
        .select()
        .single();
    return Plant.fromMap(row);
  }

  /// 이 식물에 묻힌 마음(잎) 수.
  Future<int> entryCount(String plantId) async {
    final rows =
        await _client.from('entries').select('id').eq('plant_id', plantId);
    return (rows as List).length;
  }

  /// 마음 한 줄 묻기 → entry 저장 → (하루 첫 기록이면) 식물 1단계 성장.
  Future<EntryResult> addEntry({
    required Plant plant,
    required String text,
  }) async {
    // ai_empathy / ai_plant_voice 컬럼은 NOT NULL이라 빈 문자열로 채움.
    // (AI 응답 기능은 추후 도입 시 이 자리에 채워짐)
    await _client.from('entries').insert({
      'plant_id': plant.id,
      'user_text': text,
      'ai_empathy': '',
      'ai_plant_voice': '',
      'stage_when_added': plant.stage,
    });

    // 1일 1단계 성장 (연속 강요 X — 같은 날 두 번째 기록은 성장 없이 양분만)
    final now = DateTime.now();
    final grewToday = !testFastGrowth &&
        plant.lastGrowthAt != null &&
        _sameDay(plant.lastGrowthAt!, now);

    if (grewToday || plant.stage >= 5) {
      return EntryResult(plant, grew: false);
    }

    final newStage = plant.stage + 1;
    final updated = await _client
        .from('plants')
        .update({
          'current_stage': newStage,
          'last_growth_at': now.toUtc().toIso8601String(),
          'is_completed': newStage >= 5,
        })
        .eq('id', plant.id)
        .select()
        .single();
    return EntryResult(Plant.fromMap(updated), grew: true);
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
          'is_completed': newStage >= 5,
        })
        .eq('id', plant.id)
        .select()
        .single();
    return Plant.fromMap(updated);
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
        .select('user_text, created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((m) {
      final mm = m as Map<String, dynamic>;
      return EntryRecord(
        mm['user_text'] as String,
        DateTime.parse(mm['created_at'] as String),
      );
    }).toList();
  }

  /// 식물을 정원 자리에 심기.
  Future<void> place(String plantId, int posIndex) async {
    await _client
        .from('plants')
        .update({'placed': true, 'pos_index': posIndex}).eq('id', plantId);
  }

  /// 정원에서 거두기 (모종함으로).
  Future<void> unplace(String plantId) async {
    await _client
        .from('plants')
        .update({'placed': false, 'pos_index': null}).eq('id', plantId);
  }

  /// 테스트용: 현재 키우는 식물의 종류 변경 (화분류/나무 확인).
  Future<void> setActiveSpecies(String ownerId, String species) async {
    final p = await ensureActivePlant(ownerId);
    await _client
        .from('plants')
        .update({'species': species}).eq('id', p.id);
  }

  /// 정원 공개 여부 변경.
  Future<void> setPublic(String uid, bool isPublic) async {
    await _client.from('profiles').update({'is_public': isPublic}).eq('id', uid);
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
