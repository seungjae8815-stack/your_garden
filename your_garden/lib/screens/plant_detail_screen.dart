import 'package:flutter/foundation.dart' show kDebugMode;
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

  // 한 세션에서 같은 식물에 이름 프롬프트를 반복하지 않도록.
  static final Set<String> _namePrompted = {};

  @override
  void initState() {
    super.initState();
    final p = _plant;
    final unnamed = p.name == null || p.name!.trim().isEmpty;
    // 새로 시작한(이름 없는·씨앗 단계) 식물이면 이름 짓기를 한 번 부드럽게 권한다.
    // (식물 = 감정의 한 챕터 — 둘째 식물부터도 이름을 갖도록, 2-13)
    if (unnamed && p.stage <= 1 && !_namePrompted.contains(p.id)) {
      _namePrompted.add(p.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _promptName(isNew: true);
      });
    }
  }

  Future<void> _promptName({bool isNew = false}) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _NameSheet(initial: _plant.name ?? '', isNew: isNew),
      ),
    );
    if (name == null || !mounted) return; // 취소·나중에
    final trimmed = name.trim();
    await _garden.renamePlant(_plant.id, trimmed);
    if (!mounted) return;
    setState(() => _plant = _plant.withName(trimmed.isEmpty ? null : trimmed));
  }

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
        title: Text(
          (p.name != null && p.name!.trim().isNotEmpty)
              ? p.name!.trim()
              : speciesLabel(p.species),
          style: const TextStyle(color: AppColors.ink),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.sub),
            tooltip: '이름 짓기',
            onPressed: () => _promptName(),
          ),
        ],
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
                    child: PlantSprite.hasAsset(p.species)
                        ? (isGroundPlant(p.species)
                              ? TreeOnSoil(
                                  species: p.species,
                                  stage: p.stage,
                                  soilW: 200,
                                  treeW: 250,
                                  treeH:
                                      290 *
                                      PlantSprite.heightFactor(
                                        p.species,
                                        p.stage,
                                      ),
                                )
                              : Stack(
                                  alignment: Alignment.bottomCenter,
                                  clipBehavior: Clip.none,
                                  children: [
                                    Image.asset(
                                      'assets/gardens/pot.png',
                                      width: 150,
                                    ),
                                    Positioned(
                                      bottom: 138,
                                      child: SizedBox(
                                        width: 240,
                                        height:
                                            200 *
                                            PlantSprite.heightFactor(
                                              p.species,
                                              p.stage,
                                            ),
                                        child: PlantSprite(
                                          species: p.species,
                                          stage: p.stage,
                                          inPot: false,
                                        ),
                                      ),
                                    ),
                                  ],
                                ))
                        : CustomPaint(
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
                p.isBloomed
                    ? '활짝 다 자랐어요 🌸'
                    : 'Stage ${p.stage} · ${_names[p.stage.clamp(1, 5)]}',
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
                    valueColor: const AlwaysStoppedAnimation(AppColors.green),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: p.isBloomed
                        ? () => Navigator.pop(context)
                        : _write,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 3,
                      shadowColor: const Color(0x557CB342),
                    ),
                    child: Text(
                      p.isBloomed ? '정원으로 돌아가기' : '마음 한 줄 묻기',
                      style: const TextStyle(
                        fontSize: 16.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              if (kDebugMode &&
                  GardenService.testFastGrowth &&
                  !p.isBloomed) ...[
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
              const Text(
                '돌보기(벌레·흙·물)는 곧 추가돼요',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// 식물 이름 짓기/바꾸기 시트 — 텍스트 입력 + 추천 칩. 확인 시 이름 문자열을 pop.
class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial, required this.isNew});
  final String initial;
  final bool isNew;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );
  static const _suggestions = ['오늘의 마음', '쉼표', '작은 위로', '나의 계절', '새 챕터'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isNew ? '이 식물에 이름을 지어줄까요?' : '이름 바꾸기',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '이 식물은 지금 마음의 한 챕터예요. 부르고 싶은 이름을 지어주세요.',
              style: TextStyle(fontSize: 13, color: AppColors.faint),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLength: 20,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => Navigator.pop(context, v),
              decoration: InputDecoration(
                hintText: '예: 봄의 위로',
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.green),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                    onPressed: () => setState(() {
                      _ctrl.text = s;
                      _ctrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: s.length),
                      );
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (widget.isNew) ...[
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '나중에',
                        style: TextStyle(color: AppColors.sub),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _ctrl.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(widget.isNew ? '이 이름으로 시작' : '저장'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
