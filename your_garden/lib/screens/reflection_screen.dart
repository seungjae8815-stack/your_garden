import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/garden_service.dart';
import '../theme.dart';
import '../widgets/journey_view.dart';
import '../widgets/load_error_view.dart';
import '../widgets/plant_painter.dart';

/// 만개한 식물을 거두기 전 "돌아보기 의식".
/// 이 꽃을 키우며 묻은 마음들을 모아 보여주고, 지금 그 마음이 어떤지 확인한 뒤
/// 거두면(만개=감정의 해소) 도감에 그 여정과 마무리 한마디가 남는다.
class ReflectionScreen extends StatefulWidget {
  const ReflectionScreen({super.key, required this.plant});
  final Plant plant;

  @override
  State<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  late final GardenService _garden = GardenService(Supabase.instance.client);
  final TextEditingController _note = TextEditingController();
  List<EntryRecord> _entries = const [];
  bool _loading = true;
  bool _harvesting = false;
  bool _failed = false;
  int? _feeling; // 0 가벼워졌어요 / 1 비슷해요 / 2 아직 무거워요

  static const _feelings = ['가벼워졌어요', '그대로예요', '아직 무거워요'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _garden.entriesForPlant(widget.plant.id);
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _harvest() async {
    if (_harvesting) return;
    setState(() => _harvesting = true);
    final parts = <String>[];
    if (_feeling != null) parts.add(_feelings[_feeling!]);
    final note = _note.text.trim();
    if (note.isNotEmpty) parts.add(note);
    final reflection = parts.isEmpty ? null : parts.join(' · ');
    try {
      await _garden.harvest(widget.plant.id, reflection: reflection);
      markGardenDirty();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _harvesting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('거두지 못했어요: $e')));
    }
  }

  String _span() {
    if (_entries.isEmpty) return '';
    final a = _entries.first.createdAt.toLocal();
    final b = _entries.last.createdAt.toLocal();
    String d(DateTime t) => '${t.year}.${t.month}.${t.day}';
    return a.day == b.day && a.month == b.month && a.year == b.year
        ? d(a)
        : '${d(a)} ~ ${d(b)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plant;
    // 엣지투엣지(Android 15+)에서 하단 시스템 바(제스처 바)에 버튼이 가리지 않게 인셋만큼 더 띄움.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${speciesLabel(p.species)} 돌아보기',
          style: const TextStyle(color: AppColors.ink),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green),
            )
          : _failed
          ? LoadErrorView(onRetry: _load)
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    children: [
                      SizedBox(
                        height: 150,
                        child: PlantSprite(
                          species: p.species,
                          stage: 5,
                          inPot: false,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          '활짝 피었어요 🌸',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.greenDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          _entries.isEmpty
                              ? '이 꽃과 함께한 시간'
                              : '${_span()} · ${_entries.length}번의 마음을 묻었어요',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.sub,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        '이 꽃을 키우며 묻은 마음들',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      JourneyList(entries: _entries),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F7E8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '지금, 그때의 마음은 어떤가요?',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (var i = 0; i < _feelings.length; i++)
                                  ChoiceChip(
                                    label: Text(_feelings[i]),
                                    selected: _feeling == i,
                                    onSelected: (_) =>
                                        setState(() => _feeling = i),
                                    selectedColor: AppColors.green,
                                    backgroundColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: _feeling == i
                                          ? Colors.white
                                          : AppColors.sub,
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _note,
                              maxLines: 3,
                              maxLength: 200,
                              style: const TextStyle(fontSize: 15, height: 1.5),
                              decoration: const InputDecoration(
                                hintText: '마지막으로 그때의 나에게 한마디… (선택)',
                                hintStyle: TextStyle(color: Color(0xFFBCAAA4)),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                contentPadding: EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 스크롤 없이 항상 보이는 하단 액션 — 거두기 / 그대로 두기.
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 10 + bottomInset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _harvesting ? null : _harvest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _harvesting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '이 꽃을 거두기',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: _harvesting
                              ? null
                              : () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.faint,
                          ),
                          child: const Text('그대로 둘게요'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
