import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/garden_service.dart';
import '../theme.dart';
import '../widgets/garden_critters.dart';
import '../widgets/plant_painter.dart';
import 'plant_detail_screen.dart';

/// 정원 배치 자리 (정규화 좌표 + 종류). 나무=뒤(작게), 화분=앞.
class _Spot {
  const _Spot(this.dx, this.dy, this.type);
  final double dx; // 0..1 (가로)
  final double dy; // 0..1 (세로 — 식물 바닥이 닿는 지면선)
  final String type; // 'pot' | 'tree'
}

const List<_Spot> _spots = [
  _Spot(0.20, 0.34, 'tree'),
  _Spot(0.50, 0.30, 'tree'),
  _Spot(0.80, 0.34, 'tree'),
  _Spot(0.15, 0.86, 'pot'),
  _Spot(0.36, 0.96, 'pot'),
  _Spot(0.64, 0.96, 'pot'),
  _Spot(0.85, 0.86, 'pot'),
];

/// 정원 탭 — 일러스트 배경 + 오늘 키우는 식물 + 내가 배치한 식물들(꾸미기).
class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key, required this.profile});
  final AuthResult profile;

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> {
  late final GardenService _garden = GardenService(Supabase.instance.client);
  Plant? _plant;
  List<Plant> _completed = const [];
  bool _loading = true;
  bool _night = false; // 테스트용 밤낮 토글
  bool _precached = false;
  String? _error;

  static const _skinAsset = 'assets/gardens/cottage_spring.png';

  List<Plant> get _inventory =>
      _completed.where((p) => !p.placed).toList();
  Map<int, Plant> get _placed {
    final m = <int, Plant>{};
    for (final p in _completed) {
      if (p.placed && p.posIndex != null) m[p.posIndex!] = p;
    }
    return m;
  }

  @override
  void initState() {
    super.initState();
    _load();
    gardenDirty.addListener(_onDirty);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // 꽃·나무 그림을 미리 디코딩해 둬서 성장/전환 시 깜빡임 없이 즉시 표시.
    for (final sp in [...kFlowerSpecies, ...kTreeSpecies]) {
      for (var s = 1; s <= 5; s++) {
        precacheImage(AssetImage('assets/gardens/${sp}_$s.png'), context);
      }
    }
  }

  @override
  void dispose() {
    gardenDirty.removeListener(_onDirty);
    super.dispose();
  }

  void _onDirty() {
    if (mounted) _load(silent: true);
  }

  // silent=true 면 전체 로딩 스피너 없이 기존 화면을 유지한 채 데이터만 갱신.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final plant = await _garden.ensureActivePlant(widget.profile.uid);
      final completed = await _garden.completedPlants(widget.profile.uid);
      if (!mounted) return;
      setState(() {
        _plant = plant;
        _completed = completed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openDetail() async {
    final plant = _plant;
    if (plant == null) return;
    // 다 자란 식물은 거두기 확인 알림, 자라는 중이면 상세 화면.
    if (plant.isBloomed) {
      await _harvestConfirm(plant);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlantDetailScreen(plant: plant)),
    );
    if (mounted) _load(silent: true);
  }

  // 만개한 식물 탭 → 모종함에 넣을지 확인 알림. 넣지 않으면 받침대에 그대로 둠.
  Future<void> _harvestConfirm(Plant plant) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('활짝 다 자랐어요 🌸',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        content: const Text(
            '모종함에 넣으면 정원 꾸미기에 쓸 수 있어요.\n지금 모종함에 넣을까요?',
            style: TextStyle(fontSize: 14, color: AppColors.sub, height: 1.5)),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'detail'),
            style: TextButton.styleFrom(foregroundColor: AppColors.sub),
            child: const Text('자세히 보기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.faint),
            child: const Text('그대로 둘게요'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'harvest'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('모종함에 넣기'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'harvest') {
      await _garden.harvest(plant.id);
      markGardenDirty(); // 정원·도감 둘 다 즉시 갱신
    } else if (action == 'detail') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlantDetailScreen(plant: plant)),
      );
      if (mounted) _load(silent: true);
    }
  }

  // 빈 자리 탭 → 모종함에서 같은 종류 골라 심기
  Future<void> _placeAt(int spotIndex, String type) async {
    final isTree = type == 'tree';
    final candidates =
        _inventory.where((p) => isGroundPlant(p.species) == isTree).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('심을 ${isTree ? '나무' : '화분'}이 없어요. 식물을 더 키워보세요.')));
      return;
    }
    final chosen = await _pickFromInventory(candidates, isTree ? '심을 나무 고르기' : '심을 화분 고르기');
    if (chosen != null) {
      await _garden.place(chosen.id, spotIndex);
      if (mounted) _load(silent: true);
    }
  }

  Future<Plant?> _pickFromInventory(List<Plant> list, String title) {
    return showModalBottomSheet<Plant>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 14),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return GestureDetector(
                      onTap: () => Navigator.pop(ctx, p),
                      child: Container(
                        width: 92,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          children: [
                            Expanded(
                              child: PlantSprite(
                                  species: p.species,
                                  stage: 5,
                                  inPot: !isGroundPlant(p.species)),
                            ),
                            Text(speciesLabel(p.species),
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
          ),
        ),
      ),
    );
  }

  // 배치된 식물 탭 → 거두기
  Future<void> _tapPlaced(Plant p) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: AppColors.sub),
              title: const Text('모종함으로 거두기'),
              onTap: () => Navigator.pop(ctx, 'unplace'),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppColors.faint),
              title: const Text('닫기'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == 'unplace') {
      await _garden.unplace(p.id);
      if (mounted) _load(silent: true);
    }
  }

  void _openInventory() {
    final inv = _inventory;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('모종함',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 4),
              const Text('정원의 빈 자리(＋)를 눌러 심을 수 있어요.',
                  style: TextStyle(fontSize: 13, color: AppColors.faint)),
              const SizedBox(height: 14),
              if (inv.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: Text('아직 심을 식물이 없어요',
                          style: TextStyle(color: AppColors.faint))),
                )
              else
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: inv.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final p = inv[i];
                      return Container(
                        width: 92,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          children: [
                            Expanded(
                              child: PlantSprite(
                                  species: p.species,
                                  stage: 5,
                                  inPot: !isGroundPlant(p.species)),
                            ),
                            Text(speciesLabel(p.species),
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.sub)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(_skinAsset, fit: BoxFit.cover),
          // 낮: 흐르는 구름
          if (!_night)
            const Positioned.fill(child: IgnorePointer(child: _CloudLayer())),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 130,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.green))
                : _error != null
                    ? _errorView()
                    : _bodyScene(),
          ),
          // 밤 오버레이 — 식물까지 어둡게. 달·별은 이 위(밝게), 버튼은 더 위.
          if (_night) const IgnorePointer(child: _NightOverlay()),
          // 날아다니는 곤충: 낮=나비·벌, 밤=반딧불. 밤엔 오버레이 위라 빛이 보임.
          if (!_loading && _error == null)
            Positioned.fill(
              child: SafeArea(
                child: GardenCritters(
                    key: ValueKey(_night), night: _night),
              ),
            ),
          // 상단 바 — 맨 위 (버튼이 달보다 앞)
          SafeArea(
            child: Align(alignment: Alignment.topCenter, child: _topBar()),
          ),
        ],
      ),
    );
  }

  Widget _errorView() => Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.card, borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('정원을 불러오지 못했어요\n$_error',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
          ]),
        ),
      );

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('너의 정원',
                      style: TextStyle(
                          fontSize: 20,
                          color: _night ? Colors.white : AppColors.ink,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600)),
                  Text(widget.profile.nickname,
                      style: TextStyle(
                          fontSize: 12,
                          color: _night ? Colors.white70 : AppColors.sub)),
                ],
              ),
            ),
            _dayNightButton(),
            const SizedBox(width: 8),
            _inventoryChip(),
          ],
        ),
      );

  Widget _bodyScene() =>
      LayoutBuilder(builder: (context, c) => _garden3d(c));

  Widget _dayNightButton() {
    return GestureDetector(
      onTap: () => setState(() => _night = !_night),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 5, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(_night ? Icons.dark_mode : Icons.wb_sunny_outlined,
            size: 18, color: AppColors.sub),
      ),
    );
  }

  Widget _inventoryChip() {
    final n = _inventory.length;
    return GestureDetector(
      onTap: _openInventory,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 5, offset: Offset(0, 2)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.sub),
          const SizedBox(width: 6),
          Text('모종함 $n',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _garden3d(BoxConstraints c) {
    final w = c.maxWidth;
    final h = c.maxHeight;
    final plant = _plant!;
    final placed = _placed;

    final children = <Widget>[];

    // 배치 자리들
    for (var i = 0; i < _spots.length; i++) {
      final spot = _spots[i];
      final occupant = placed[i];
      if (occupant != null) {
        final isTree = isGroundPlant(occupant.species);
        final iw = isTree ? 104.0 : 70.0;
        final ih = isTree ? 140.0 : 92.0;
        children.add(Positioned(
          left: spot.dx * w - iw / 2,
          top: spot.dy * h - ih,
          width: iw,
          height: ih,
          child: GestureDetector(
            onTap: () => _tapPlaced(occupant),
            child: _PlacedPlant(plant: occupant, isTree: isTree),
          ),
        ));
      } else {
        // 같은 종류 모종이 있을 때만 빈 자리(＋) 표시
        final isTree = spot.type == 'tree';
        final hasMatch =
            _inventory.any((p) => isGroundPlant(p.species) == isTree);
        if (hasMatch) {
          children.add(Positioned(
            left: spot.dx * w - 23,
            top: spot.dy * h - 46,
            child: GestureDetector(
              onTap: () => _placeAt(i, spot.type),
              child: _EmptySpot(),
            ),
          ));
        }
      }
    }

    // 오늘 키우는 식물 (중앙-앞, 받침대/흙)
    const gw = 200.0;
    final groundY = h * 0.72; // 식물 바닥이 닿는 지면선
    children.add(Positioned(
      left: w * 0.5 - gw / 2,
      bottom: h - groundY,
      width: gw,
      child: GestureDetector(
        onTap: _openDetail,
        behavior: HitTestBehavior.opaque,
        child: isGroundPlant(plant.species)
            ? _treeOnSoil(plant)
            : _potOnStand(plant),
      ),
    ));

    return Stack(clipBehavior: Clip.none, children: children);
  }

  Widget _potOnStand(Plant p) => SizedBox(
        width: 130,
        height: 320,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // 받침대
            Image.asset('assets/gardens/stand.png', width: 86),
            // 화분 (받침대 윗면)
            Positioned(
              bottom: 92,
              child: Image.asset('assets/gardens/pot.png', width: 72),
            ),
            // 식물 잎/꽃 (화분 흙에서 올라옴, 화분 없이). 단계에 따라 커짐.
            Positioned(
              bottom: 158,
              child: SizedBox(
                width: 130,
                height: 150 * PlantSprite.heightFactor(p.species, p.stage),
                child: PlantSprite(
                    species: p.species, stage: p.stage, inPot: false),
              ),
            ),
          ],
        ),
      );

  Widget _treeOnSoil(Plant p) {
    final hf = PlantSprite.heightFactor(p.species, p.stage);
    return TreeOnSoil(
      species: p.species,
      stage: p.stage,
      soilW: 150 + 30 * hf, // 큰 나무일수록 흙더미도 넓게
      treeW: 200,
      treeH: 260 * hf,
    );
  }
}

/// 밤 오버레이 — 남색 틴트 + 달(이미지) + 반짝이는 별(코드).
class _NightOverlay extends StatefulWidget {
  const _NightOverlay();
  @override
  State<_NightOverlay> createState() => _NightOverlayState();
}

class _NightOverlayState extends State<_NightOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  static const _stars = [
    Offset(0.16, 0.14), Offset(0.50, 0.09), Offset(0.80, 0.18),
    Offset(0.32, 0.24), Offset(0.66, 0.28), Offset(0.88, 0.11),
    Offset(0.24, 0.33), Offset(0.58, 0.16),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      return AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0x593A4A7A)),
              Positioned(
                top: h * 0.05,
                left: w * 0.10,
                child: Container(
                  width: w * 0.22,
                  height: w * 0.22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Color(0x55FFE9A8),
                          blurRadius: 38,
                          spreadRadius: 14),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/gardens/moon.png',
                        fit: BoxFit.cover),
                  ),
                ),
              ),
              for (var i = 0; i < _stars.length; i++)
                Positioned(
                  left: _stars[i].dx * w,
                  top: _stars[i].dy * h,
                  child: Opacity(
                    opacity: 0.25 +
                        0.7 *
                            (0.5 +
                                0.5 *
                                    math.sin(2 *
                                        math.pi *
                                        (_c.value + i / _stars.length))),
                    child: const _Star(),
                  ),
                ),
            ],
          );
        },
      );
    });
  }
}

class _Star extends StatelessWidget {
  const _Star();
  @override
  Widget build(BuildContext context) => Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.white, blurRadius: 4)],
        ),
      );
}

/// 낮 하늘에 천천히 흐르는 구름.
class _CloudLayer extends StatefulWidget {
  const _CloudLayer();
  @override
  State<_CloudLayer> createState() => _CloudLayerState();
}

class _CloudLayerState extends State<_CloudLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 75),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      return AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(
          children: [
            _cloud('assets/gardens/cloud1.png', 132, h * 0.08, 0.0, 1.0, w),
            _cloud('assets/gardens/cloud2.png', 168, h * 0.17, 0.45, 0.72, w),
            _cloud('assets/gardens/cloud3.png', 112, h * 0.04, 0.78, 1.25, w),
          ],
        ),
      );
    });
  }

  Widget _cloud(String asset, double cw, double y, double phase, double speed,
      double w) {
    final p = (_c.value * speed + phase) % 1.0;
    final x = p * (w + cw) - cw;
    return Positioned(
      left: x,
      top: y,
      child: Opacity(opacity: 0.9, child: Image.asset(asset, width: cw)),
    );
  }
}

/// 정원에 배치된 식물 (작게). 나무는 흙더미 위.
class _PlacedPlant extends StatelessWidget {
  const _PlacedPlant({required this.plant, required this.isTree});
  final Plant plant;
  final bool isTree;

  @override
  Widget build(BuildContext context) {
    if (isTree) {
      return TreeOnSoil(
        species: plant.species,
        stage: 5,
        soilW: 86,
        treeW: 100,
        treeH: 130,
      );
    }
    return PlantSprite(species: plant.species, stage: 5, inPot: false);
  }
}

/// 빈 배치 자리 (＋).
class _EmptySpot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.green, width: 2),
      ),
      child: const Icon(Icons.add, color: AppColors.greenDark),
    );
  }
}

