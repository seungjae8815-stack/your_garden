import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/tags.dart';
import '../services/auth_service.dart';
import '../services/garden_service.dart';
import '../theme.dart';

/// 인사이트 — 마음 날씨 흐름 + 양분(주제)별 마음 날씨 상관 + 감정 분포 + 주간 요약.
/// 체크인에 쌓인 mood·태그 데이터를 모아 "거리를 두고 바라보기"를 돕는다.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.profile});
  final AuthResult profile;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

// 마음 날씨 1..5 색 (힘듦→좋음). index 0은 안 씀.
const List<Color> _moodColors = [
  Color(0xFFBDBDBD),
  Color(0xFFEF9A9A),
  Color(0xFFFFCC80),
  Color(0xFFFFE082),
  Color(0xFFC5E1A5),
  Color(0xFF81C784),
];

Color _moodColor(double m) => _moodColors[m.round().clamp(1, 5)];

class _InsightsScreenState extends State<InsightsScreen> {
  late final GardenService _garden = GardenService(Supabase.instance.client);
  List<EntryRecord> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _garden.recentEntries(limit: 800);
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('마음 흐름', style: TextStyle(color: AppColors.ink)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : _entries.isEmpty
              ? _emptyState()
              : ListView(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
                  children: [
                    _summaryCard(),
                    const SizedBox(height: 18),
                    _section('지난 14일 마음 날씨', _moodTrend()),
                    const SizedBox(height: 18),
                    _section('무엇이 양분일 때 마음이 어땠나', _topicCorrelation()),
                    const SizedBox(height: 18),
                    _section('자주 묻은 감정', _emotionDistribution()),
                  ],
                ),
    );
  }

  Widget _emptyState() => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            '아직 마음이 모이는 중이에요.\n며칠 더 마음을 묻으면\n흐름이 보이기 시작해요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.7, color: AppColors.sub),
          ),
        ),
      );

  Widget _section(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ── 주간 요약 한 줄 ──────────────────────────────────────
  Widget _summaryCard() {
    final msg = _weeklySummary();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7E8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌿', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 15, height: 1.6, color: AppColors.greenDark)),
          ),
        ],
      ),
    );
  }

  String _weeklySummary() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final week = _entries.where((e) => e.createdAt.isAfter(weekAgo)).toList();
    if (week.isEmpty) {
      return '이번 주는 아직 기록이 없어요. 오늘의 마음을 한 줄 묻어볼까요?';
    }

    // 가장 자주 묻은 주제
    final topicCount = <String, int>{};
    for (final e in week) {
      for (final t in e.topicTags) {
        topicCount[t] = (topicCount[t] ?? 0) + 1;
      }
    }
    final moods = week.where((e) => e.mood != null).map((e) => e.mood!).toList();
    final n = week.length;

    if (topicCount.isEmpty) {
      if (moods.isEmpty) {
        return '이번 주 $n번 마음을 묻었어요. 태그를 달면 더 또렷한 흐름이 보여요.';
      }
      final avg = moods.reduce((a, b) => a + b) / moods.length;
      return '이번 주 $n번 마음을 묻었어요. 평균 마음 날씨는 ${_moodWord(avg)} 쪽이었어요.';
    }

    final topKey = (topicCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
    final topLabel = topicTagByKey(topKey)?.label ?? topKey;

    // 그 주제를 묻은 날의 평균 마음 vs 전체 평균 비교
    final overall = moods.isEmpty
        ? null
        : moods.reduce((a, b) => a + b) / moods.length;
    final topicMoods = week
        .where((e) => e.topicTags.contains(topKey) && e.mood != null)
        .map((e) => e.mood!)
        .toList();

    if (overall == null || topicMoods.isEmpty) {
      return "이번 주, '$topLabel'을(를) 가장 자주 마음에 묻었어요.";
    }
    final topicAvg = topicMoods.reduce((a, b) => a + b) / topicMoods.length;
    final diff = topicAvg - overall;
    final String tail;
    if (diff <= -0.4) {
      tail = '그런 날의 마음 날씨가 평소보다 흐렸어요.';
    } else if (diff >= 0.4) {
      tail = '그런 날의 마음 날씨가 평소보다 맑았어요.';
    } else {
      tail = '그런 날의 마음 날씨는 평소와 비슷했어요.';
    }
    return "이번 주, '$topLabel'을(를) 가장 자주 마음에 묻었어요. $tail";
  }

  String _moodWord(double m) {
    if (m < 1.8) return '흐림';
    if (m < 2.6) return '구름';
    if (m < 3.4) return '그저 그럼';
    if (m < 4.2) return '맑음';
    return '쾌청';
  }

  // ── 지난 14일 마음 날씨 ───────────────────────────────────
  Widget _moodTrend() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 14일치 일별 평균 mood (null = 기록 없음)
    final sums = List<double>.filled(14, 0);
    final counts = List<int>.filled(14, 0);
    for (final e in _entries) {
      if (e.mood == null) continue;
      final l = e.createdAt.toLocal();
      final d = DateTime(l.year, l.month, l.day);
      final idx = 13 - today.difference(d).inDays;
      if (idx < 0 || idx > 13) continue;
      sums[idx] += e.mood!;
      counts[idx] += 1;
    }
    final hasAny = counts.any((c) => c > 0);
    if (!hasAny) {
      return const Text('마음 날씨를 고른 기록이 아직 없어요.',
          style: TextStyle(fontSize: 13, color: AppColors.faint));
    }

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 14; i++)
            Expanded(
              child: _trendBar(
                avg: counts[i] > 0 ? sums[i] / counts[i] : null,
                day: today.subtract(Duration(days: 13 - i)),
                showLabel: i % 3 == 1, // 라벨은 띄엄띄엄
              ),
            ),
        ],
      ),
    );
  }

  Widget _trendBar({double? avg, required DateTime day, required bool showLabel}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: avg == null ? 0.05 : (avg / 5).clamp(0.12, 1.0),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: avg == null
                      ? const Color(0xFFEDE7D6)
                      : _moodColor(avg),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 13,
          child: showLabel
              ? Text('${day.day}',
                  style: const TextStyle(fontSize: 10, color: AppColors.faint))
              : null,
        ),
      ],
    );
  }

  // ── 주제(양분)별 평균 마음 날씨 ───────────────────────────
  Widget _topicCorrelation() {
    // 주제별 mood 모으기
    final byTopic = <String, List<int>>{};
    for (final e in _entries) {
      if (e.mood == null) continue;
      for (final t in e.topicTags) {
        (byTopic[t] ??= []).add(e.mood!);
      }
    }
    if (byTopic.isEmpty) {
      return const Text('주제 태그와 마음 날씨가 함께 쌓이면\n어떤 양분일 때 마음이 흐렸는지 보여요.',
          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.faint));
    }
    final rows = byTopic.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return _CorrRow(key: e.key, avg: avg, count: e.value.length);
    }).toList()
      ..sort((a, b) => a.avg.compareTo(b.avg)); // 흐린(낮은) 것부터

    return Column(
      children: [
        for (final r in rows) ...[
          _topicBar(r),
          if (r != rows.last) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _topicBar(_CorrRow r) {
    final tag = topicTagByKey(r.key);
    final label = tag?.label ?? r.key;
    final emoji = tag?.emoji ?? '·';
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.ink)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 16, color: const Color(0xFFF0EAD9)),
                FractionallySizedBox(
                  widthFactor: (r.avg / 5).clamp(0.08, 1.0),
                  child: Container(height: 16, color: _moodColor(r.avg)),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text('${r.avg.toStringAsFixed(1)} · ${r.count}번',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: AppColors.sub)),
        ),
      ],
    );
  }

  // ── 감정 태그 분포 ────────────────────────────────────────
  Widget _emotionDistribution() {
    final count = <String, int>{};
    for (final e in _entries) {
      for (final t in e.emotionTags) {
        count[t] = (count[t] ?? 0) + 1;
      }
    }
    if (count.isEmpty) {
      return const Text('감정 태그를 달면 어떤 감정을 자주 묻었는지 보여요.',
          style: TextStyle(fontSize: 13, color: AppColors.faint));
    }
    final maxCount =
        count.values.reduce((a, b) => a > b ? a : b).toDouble();
    final rows = count.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        for (final e in rows) ...[
          _emotionBar(e.key, e.value, maxCount),
          if (e != rows.last) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _emotionBar(String key, int n, double maxCount) {
    final tag = emotionTagByKey(key);
    final label = tag?.label ?? key;
    final emoji = tag?.emoji ?? '·';
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.ink)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 16, color: const Color(0xFFF0EAD9)),
                FractionallySizedBox(
                  widthFactor: (n / maxCount).clamp(0.08, 1.0),
                  child: Container(height: 16, color: const Color(0xFFAED581)),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text('$n번',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: AppColors.sub)),
        ),
      ],
    );
  }
}

class _CorrRow {
  const _CorrRow({required this.key, required this.avg, required this.count});
  final String key;
  final double avg;
  final int count;
}
