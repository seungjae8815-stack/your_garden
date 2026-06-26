import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/garden_service.dart';
import '../theme.dart';
import '../widgets/plant_painter.dart';
import 'collection_detail_screen.dart';

/// 도감 탭 — 완성(만개)한 식물들을 모아 보는 수집 화면.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.profile});
  final AuthResult profile;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late final GardenService _garden = GardenService(Supabase.instance.client);
  List<Plant> _plants = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    gardenDirty.addListener(_onDirty); // 정원에서 거두면 즉시 도감 갱신
  }

  @override
  void dispose() {
    gardenDirty.removeListener(_onDirty);
    super.dispose();
  }

  void _onDirty() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    try {
      final list = await _garden.completedPlants(widget.profile.uid);
      if (!mounted) return;
      setState(() {
        _plants = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('도감', style: TextStyle(color: AppColors.ink)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.green,
              child: _plants.isEmpty ? _empty() : _grid(),
            ),
    );
  }

  Widget _empty() => ListView(
        children: const [
          SizedBox(height: 140),
          Icon(Icons.menu_book_outlined, size: 56, color: AppColors.faint),
          SizedBox(height: 16),
          Center(
            child: Text(
              '아직 완성한 식물이 없어요.\n마음을 묻으며 식물을 키워보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.faint, height: 1.6),
            ),
          ),
        ],
      );

  Widget _grid() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('모은 식물 ${_plants.length}그루',
                style: const TextStyle(color: AppColors.sub, fontSize: 14)),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            itemCount: _plants.length,
            itemBuilder: (_, i) {
              final p = _plants[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CollectionDetailScreen(plant: p)),
                ),
                child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: PlantSprite.hasAsset(p.species)
                            ? PlantSprite(
                                species: p.species, stage: 5, inPot: false)
                            : CustomPaint(
                                painter: PlantPainter(
                                    species: p.species,
                                    stage: 5,
                                    inPot: !isGroundPlant(p.species)),
                                size: Size.infinite),
                      ),
                    ),
                    Text(speciesLabel(p.species),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.faint)),
                    Text(_date(p.startedAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.sub)),
                  ],
                ),
              ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _date(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.year}.${l.month}.${l.day}';
  }
}
