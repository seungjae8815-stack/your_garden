import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/garden_service.dart';
import '../theme.dart';
import '../widgets/plant_painter.dart';
import 'input_screen.dart';

/// 화분/나무 확대 화면 — 가까이서 보고 마음을 묻어 키운다.
/// (벌레 잡기·흙 고르기·물 주기 같은 돌보기는 다음 단계에서 추가)
class PlantDetailScreen extends StatefulWidget {
  const PlantDetailScreen({super.key, required this.plant});
  final Plant plant;

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  late Plant _plant = widget.plant;
  late final GardenService _garden = GardenService(Supabase.instance.client);
  static const _names = ['', '씨앗', '어린잎', '성장기', '만개 직전', '꽃'];

  Future<void> _write() async {
    final result = await Navigator.push<EntryResult>(
      context,
      MaterialPageRoute(builder: (_) => InputScreen(plant: _plant)),
    );
    if (result != null && mounted) setState(() => _plant = result.plant);
  }

  Future<void> _debugGrow() async {
    final p = await _garden.debugAdvance(_plant);
    if (mounted) setState(() => _plant = p);
  }

  @override
  Widget build(BuildContext context) {
    final p = _plant;
    return Scaffold(
      appBar: AppBar(
        title: Text(speciesLabel(p.species),
            style: const TextStyle(color: AppColors.ink)),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF3), AppColors.cream, Color(0xFFEFE6C6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 260,
                    height: 300,
                    child: CustomPaint(
                      painter: PlantPainter(
                        species: p.species,
                        stage: p.stage,
                        inPot: !isGroundPlant(p.species),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                p.isComplete ? '활짝 다 자랐어요 🌸' : 'Stage ${p.stage} · ${_names[p.stage]}',
                style: const TextStyle(fontSize: 16, color: AppColors.sub),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: p.stage / 5,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE6DCC6),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.green),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        p.isComplete ? () => Navigator.pop(context) : _write,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 3,
                      shadowColor: const Color(0x557CB342),
                    ),
                    child: Text(
                      p.isComplete ? '정원으로 돌아가기' : '마음 한 줄 묻기',
                      style: const TextStyle(
                          fontSize: 16.5, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
              if (GardenService.testFastGrowth && !p.isComplete) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _debugGrow,
                      child: const Text('＋1 단계 (테스트)'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Text('돌보기(벌레·흙·물)는 곧 추가돼요',
                  style: TextStyle(fontSize: 12, color: AppColors.faint)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
