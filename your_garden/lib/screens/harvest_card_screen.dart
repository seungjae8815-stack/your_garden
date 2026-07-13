import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/garden_service.dart';
import '../services/share_util.dart';
import '../theme.dart';
import '../widgets/plant_painter.dart';

/// 거두기(돌아보기 완료) 직후 기념 카드 — 이 감정 챕터를 한 장으로 남기고 공유한다.
/// 만개한 식물 + 챕터 이름 + 함께한 기간·마음 수 + 마무리 한마디 + 워터마크.
class HarvestCardScreen extends StatefulWidget {
  const HarvestCardScreen({
    super.key,
    required this.plant,
    required this.entries,
    this.reflection,
  });

  final Plant plant;
  final List<EntryRecord> entries;
  final String? reflection;

  @override
  State<HarvestCardScreen> createState() => _HarvestCardScreenState();
}

class _HarvestCardScreenState extends State<HarvestCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  String get _title {
    final n = widget.plant.name?.trim();
    return (n != null && n.isNotEmpty) ? n : speciesLabel(widget.plant.species);
  }

  String get _span {
    if (widget.entries.isEmpty) return '';
    final a = widget.entries.first.createdAt.toLocal();
    final b = widget.entries.last.createdAt.toLocal();
    String d(DateTime t) => '${t.year}.${t.month}.${t.day}';
    return (a.year == b.year && a.month == b.month && a.day == b.day)
        ? d(a)
        : '${d(a)} ~ ${d(b)}';
  }

  @override
  void initState() {
    super.initState();
    _preloadFont();
  }

  Future<void> _preloadFont() async {
    try {
      await GoogleFonts.pendingFonts([GoogleFonts.gaegu()]);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await captureBoundary(_cardKey, pixelRatio: 3.0);
      if (bytes != null) {
        await shareBytes(bytes, text: "'$_title' 한 챕터를 거뒀어요 🌸 #너의정원");
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _toGarden() {
    // 돌아보기 위에 pushReplacement로 얹혀 있으므로, 닫으면 원래 정원으로 돌아가며
    // 정원이 자동으로 다시 로드된다(거둔 식물 반영).
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('한 챕터를 거뒀어요', style: TextStyle(color: AppColors.ink)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(key: _cardKey, child: _card()),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _sharing ? null : _share,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      icon: _sharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.ios_share),
                      label: const Text(
                        '기념 카드 공유',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _sharing ? null : _toGarden,
                    style: TextButton.styleFrom(foregroundColor: AppColors.sub),
                    child: const Text('정원으로 돌아가기'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 150,
            child: PlantSprite(
              species: widget.plant.species,
              stage: 5,
              inPot: false,
            ),
          ),
          const SizedBox(height: 10),
          const Text('🌸', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            _title,
            textAlign: TextAlign.center,
            style: GoogleFonts.gaegu(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4E3B2A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            speciesLabel(widget.plant.species),
            style: const TextStyle(fontSize: 12, color: AppColors.faint),
          ),
          const SizedBox(height: 12),
          if (_span.isNotEmpty)
            Text(
              '$_span · ${widget.entries.length}번의 마음',
              style: const TextStyle(fontSize: 12.5, color: AppColors.sub),
            ),
          if (widget.reflection != null &&
              widget.reflection!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F7E8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                widget.reflection!.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('🌿', style: TextStyle(fontSize: 15)),
              SizedBox(width: 5),
              Text(
                '너의 정원',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.greenDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
