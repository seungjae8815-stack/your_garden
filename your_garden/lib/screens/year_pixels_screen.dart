import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/garden_service.dart';
import '../services/share_util.dart';
import '../theme.dart';

/// 올해의 마음 — 날짜마다 그날 기분을 색 한 칸으로 (Year in Pixels). 한 장으로 공유.
class YearPixelsScreen extends StatefulWidget {
  const YearPixelsScreen({super.key, required this.profile});
  final AuthResult profile;

  @override
  State<YearPixelsScreen> createState() => _YearPixelsScreenState();
}

class _YearPixelsScreenState extends State<YearPixelsScreen> {
  late final GardenService _garden = GardenService(Supabase.instance.client);
  final GlobalKey _cardKey = GlobalKey();
  // month(1..12) -> day(1..31) -> mood(1..5)
  final Map<int, Map<int, int>> _byYear = {};
  late int _year;
  bool _loading = true;
  bool _sharing = false;

  static const _months = [
    '1월','2월','3월','4월','5월','6월','7월','8월','9월','10월','11월','12월'
  ];
  static const _empty = Color(0xFFF0ECDD);

  static const Map<int, Color> _moodColor = {
    1: Color(0xFF9BB4D4),
    2: Color(0xFFB9C7CE),
    3: Color(0xFFDADFBE),
    4: Color(0xFFBFE08C),
    5: Color(0xFFF7C948),
  };

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _garden.recentEntries(limit: 1500);
      _byYear.clear();
      for (final e in list) {
        if (e.mood == null) continue;
        final l = e.createdAt.toLocal();
        final m = _byYear.putIfAbsent(l.year, () => {});
        final key = l.month * 100 + l.day;
        // 최신순이라 그날 첫 항목(가장 최근)만 채택
        m.putIfAbsent(key, () => e.mood!);
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int? _mood(int month, int day) => _byYear[_year]?[month * 100 + day];

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await captureBoundary(_cardKey, pixelRatio: 3.0);
      if (bytes != null) {
        await shareBytes(bytes, text: '$_year년의 마음 🌿 #너의정원');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('올해의 마음', style: TextStyle(color: AppColors.ink)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : Column(
              children: [
                _yearHeader(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: _card(),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sharing ? null : _share,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28)),
                        ),
                        icon: _sharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.ios_share),
                        label: const Text('공유하기',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _yearHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.sub),
              onPressed: () => setState(() => _year--),
            ),
            Text('$_year',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.sub),
              onPressed: _year >= DateTime.now().year
                  ? null
                  : () => setState(() => _year++),
            ),
          ],
        ),
      );

  Widget _card() {
    const cell = 8.5;
    const gap = 1.5;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$_year년의 마음',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 2),
          const Text('하루하루의 마음 날씨',
              style: TextStyle(fontSize: 12, color: AppColors.faint)),
          const SizedBox(height: 14),
          // 12개월 그리드 — 각 달의 실제 일수만큼만 (오른쪽이 자연스럽게 계단식).
          for (var month = 1; month <= 12; month++)
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(_months[month - 1],
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.sub)),
                  ),
                  for (var day = 1;
                      day <= DateTime(_year, month + 1, 0).day;
                      day++)
                    Container(
                      margin: const EdgeInsets.only(right: gap),
                      width: cell,
                      height: cell,
                      decoration: BoxDecoration(
                        color: _mood(month, day) != null
                            ? _moodColor[_mood(month, day)]
                            : _empty,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          _legend(),
          const SizedBox(height: 6),
          Row(
            children: const [
              Text('🌿', style: TextStyle(fontSize: 14)),
              SizedBox(width: 5),
              Text('너의 정원',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.greenDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend() => Row(
        children: [
          const Text('많이 힘듦',
              style: TextStyle(fontSize: 9, color: AppColors.faint)),
          const SizedBox(width: 4),
          for (var i = 1; i <= 5; i++)
            Container(
              margin: const EdgeInsets.only(right: 3),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _moodColor[i],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          const SizedBox(width: 1),
          const Text('좋음',
              style: TextStyle(fontSize: 9, color: AppColors.faint)),
        ],
      );
}
