import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/garden_service.dart';
import '../theme.dart';
import '../widgets/journey_view.dart';
import '../widgets/plant_painter.dart';

/// 도감 상세 — 한 식물의 만개 모습 + 마무리 한마디 + 감정의 여정 다시보기.
class CollectionDetailScreen extends StatefulWidget {
  const CollectionDetailScreen({super.key, required this.plant});
  final Plant plant;

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
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
      final list = await _garden.entriesForPlant(widget.plant.id);
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
    final p = widget.plant;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          speciesLabel(p.species),
          style: const TextStyle(color: AppColors.ink),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                SizedBox(
                  height: 160,
                  child: PlantSprite(
                    species: p.species,
                    stage: 5,
                    inPot: false,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _date(p.startedAt),
                    style: const TextStyle(fontSize: 13, color: AppColors.sub),
                  ),
                ),
                if (p.reflection != null && p.reflection!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F7E8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '거둘 때 남긴 마음',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.reflection!,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const Text(
                  '이 꽃과 함께한 마음들',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                JourneyList(entries: _entries),
              ],
            ),
    );
  }

  String _date(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.year}.${l.month}.${l.day}';
  }
}
