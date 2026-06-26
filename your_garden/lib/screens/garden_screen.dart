import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/garden_service.dart';
import '../theme.dart';
import '../services/share_util.dart';
import '../widgets/garden_critters.dart';
import '../widgets/plant_painter.dart';
import 'input_screen.dart';
import 'plant_detail_screen.dart';
import 'reflection_screen.dart';
import 'share_preview_screen.dart';

/// (구버전) 고정 자리 — pos_x/pos_y 없는 옛 데이터의 위치 폴백용.
class _Spot {
  const _Spot(this.dx, this.dy);
  final double dx; // 0..1 (가로)
  final double dy; // 0..1 (세로 — 식물 바닥이 닿는 지면선)
}

const List<_Spot> _legacySpots = [
  _Spot(0.20, 0.34),
  _Spot(0.50, 0.30),
  _Spot(0.80, 0.34),
  _Spot(0.15, 0.86),
  _Spot(0.36, 0.96),
  _Spot(0.64, 0.96),
  _Spot(0.85, 0.86),
];

// 드래그 출처: 모종함에서 새로 꺼냄 / 이미 심긴 걸 옮김.
enum _DragSrc { none, tray, placed }

// 배치 가능 영역: 이 선(정규화 y) 위로는 하늘/지붕이라 심을 수 없음(지평선).
const double _horizonDy = 0.27;
const double _bottomDy = 0.98;

// 원근 스케일: 뒤(지평선)는 작게, 앞(바닥)으로 올수록 가파르게 커짐.
double _perspScale(double dy) {
  const top = _horizonDy, bot = 0.96;
  final t = ((dy - top) / (bot - top)).clamp(0.0, 1.0);
  final e = t * (0.55 + 0.45 * t); // 앞쪽일수록 가속(원근감 강조)
  return 0.38 + 1.02 * e; // 0.38(맨 뒤) .. 1.4(맨 앞)
}

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
  bool _planting = false; // 모종함 트레이(드래그해 심기) 열림 여부
  _DragSrc _dragSource = _DragSrc.none; // 현재 드래그 중인 출처
  bool _checkedInToday = false; // 오늘 마음을 묻었는지
  String? _error;

  final GlobalKey _canvasKey = GlobalKey(); // 정원 캔버스 — 드롭 좌표 환산용
  final GlobalKey _shareKey = GlobalKey(); // 공유 카드 캡처용

  static const _skinAsset = 'assets/gardens/cottage_spring.png';

  List<Plant> get _inventory =>
      _completed.where((p) => !p.placed).toList();

  // 정원에 심긴 식물들 — 아래쪽(앞)이 위로 그려지도록 y 오름차순 정렬.
  List<Plant> get _placedPlants {
    final list = _completed.where((p) => p.placed).toList();
    list.sort((a, b) => _footOf(a).dy.compareTo(_footOf(b).dy));
    return list;
  }

  // 식물이 지면에 닿는 발(foot) 좌표(0..1). 자유 좌표 우선, 없으면 구버전 자리.
  Offset _footOf(Plant p) {
    if (p.posX != null && p.posY != null) return Offset(p.posX!, p.posY!);
    final i = p.posIndex;
    if (i != null && i >= 0 && i < _legacySpots.length) {
      return Offset(_legacySpots[i].dx, _legacySpots[i].dy);
    }
    return const Offset(0.5, 0.8);
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
      final checkedIn = await _garden.checkedInToday(plant.id);
      if (!mounted) return;
      setState(() {
        _plant = plant;
        _completed = completed;
        _checkedInToday = checkedIn;
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

  // 오늘의 마음 묻기 (매일 체크인) — 식물 상세를 거치지 않고 바로.
  Future<void> _openCheckIn() async {
    final plant = _plant;
    if (plant == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InputScreen(plant: plant)),
    );
    if (mounted) _load(silent: true);
  }

  Widget _checkInCta() {
    final done = _checkedInToday;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: GestureDetector(
          onTap: _openCheckIn,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              color: done
                  ? Colors.white.withValues(alpha: 0.92)
                  : AppColors.green,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(done ? '🌿' : '🌱', style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 8),
              Text(
                done ? '오늘의 마음을 묻었어요' : '오늘의 마음 묻기',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: done ? AppColors.green : Colors.white),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _openDetail() async {
    final plant = _plant;
    if (plant == null) return;
    // 다 자란 식물은 "돌아보기 의식"으로, 자라는 중이면 상세 화면.
    if (plant.isBloomed) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReflectionScreen(plant: plant)),
      );
      if (mounted) _load(silent: true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlantDetailScreen(plant: plant)),
    );
    if (mounted) _load(silent: true);
  }

  // 드래그 피드백 박스 크기(종류별) — 드롭 발 위치 계산에도 사용.
  Size _feedSize(Plant p) =>
      isGroundPlant(p.species) ? const Size(104, 140) : const Size(80, 104);

  // 모종을 정원 위에 떨어뜨림 → 그 위치(정규화 좌표)에 심기.
  Future<void> _onDropPlant(Plant p, Offset globalTopLeft) async {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalTopLeft);
    final w = box.size.width, h = box.size.height;
    final fs = _feedSize(p);
    // 피드백 박스의 바닥-가운데를 식물의 발 위치로 본다.
    final dx = ((local.dx + fs.width / 2) / w).clamp(0.06, 0.94);
    final dy = ((local.dy + fs.height) / h).clamp(_horizonDy, _bottomDy);
    await _garden.place(p.id, x: dx, y: dy);
    if (mounted) _load(silent: true);
  }

  // 드래그 중 따라다니는 미리보기.
  Widget _dragFeedback(Plant p) {
    final fs = _feedSize(p);
    return IgnorePointer(
      child: Opacity(
        opacity: 0.85,
        child: SizedBox(
          width: fs.width,
          height: fs.height,
          child: _PlacedPlant(plant: p),
        ),
      ),
    );
  }

  // 심긴 식물을 모종함으로 도로 거둠 (위 모종함 버튼으로 끌어다 놓을 때).
  Future<void> _returnToInventory(Plant p) async {
    await _garden.unplace(p.id);
    if (mounted) _load(silent: true);
  }

  Widget _plantingTray() {
    // 모종함에서 새로 꺼내 드래그하는 동안엔 트레이를 숨겨(투명+터치통과) 바닥까지
    // 심을 수 있게 한다. (위젯은 그대로 둬서 드래그가 끊기지 않게)
    final hideForTrayDrag = _dragSource == _DragSrc.tray;
    final inv = _inventory;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: hideForTrayDrag,
        child: AnimatedOpacity(
          opacity: hideForTrayDrag ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('모종함 — 끌어다 정원에 심어요 🌱',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _planting = false),
                          child: const Icon(Icons.close,
                              size: 20, color: AppColors.sub),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (inv.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                            child: Text('아직 심을 식물이 없어요',
                                style: TextStyle(color: AppColors.faint))),
                      )
                    else
                      SizedBox(
                        height: 116,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: inv.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (_, i) => _trayItem(inv[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _trayItem(Plant p) {
    final tile = Container(
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
              style: const TextStyle(fontSize: 11, color: AppColors.sub)),
        ],
      ),
    );
    return Draggable<Plant>(
      data: p,
      feedback: _dragFeedback(p),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      onDragStarted: () => setState(() => _dragSource = _DragSrc.tray),
      onDragEnd: (_) => setState(() => _dragSource = _DragSrc.none),
      child: tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 공유 카드로 캡처할 정원 시각 레이어 (UI 버튼은 제외).
          RepaintBoundary(
            key: _shareKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(_skinAsset, fit: BoxFit.cover),
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
                          child:
                              CircularProgressIndicator(color: AppColors.green))
                      : _error != null
                          ? _errorView()
                          : _bodyScene(),
                ),
                // 구름은 식물보다 앞 — 언덕 위 작은 식물이 구름을 뚫지 않게.
                if (!_night)
                  const Positioned.fill(
                      child: IgnorePointer(child: _CloudLayer())),
                if (_night) const IgnorePointer(child: _NightOverlay()),
                if (!_loading && _error == null)
                  Positioned.fill(
                    child: SafeArea(
                      child: GardenCritters(
                          key: ValueKey(_night), night: _night),
                    ),
                  ),
              ],
            ),
          ),
          // 매일 체크인 CTA — 하단 중앙. 심기/드래그 중엔 숨김.
          if (!_loading &&
              _error == null &&
              !_planting &&
              _dragSource == _DragSrc.none)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: _checkInCta()),
            ),
          // 모종함 트레이 (드래그해 심기) — 정원 위, 상단바 아래.
          if (_planting && !_loading && _error == null) _plantingTray(),
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
            _shareButton(),
            const SizedBox(width: 8),
            _dayNightButton(),
            const SizedBox(width: 8),
            _inventoryChip(),
          ],
        ),
      );

  Widget _shareButton() => GestureDetector(
        onTap: _shareGarden,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000), blurRadius: 5, offset: Offset(0, 2)),
            ],
          ),
          child: const Icon(Icons.ios_share, size: 18, color: AppColors.sub),
        ),
      );

  Future<void> _shareGarden() async {
    final bytes = await captureBoundary(_shareKey, pixelRatio: 2.5);
    if (bytes == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SharePreviewScreen(
            imageBytes: bytes, nickname: widget.profile.nickname),
      ),
    );
  }

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
    final dragging = _dragSource == _DragSrc.placed; // 심긴 식물 옮기는 중
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        DragTarget<Plant>(
          onWillAcceptWithDetails: (_) => _dragSource == _DragSrc.placed,
          onAcceptWithDetails: (d) => _returnToInventory(d.data),
          builder: (ctx, cand, rej) {
            final hot = cand.isNotEmpty; // 칩 위에 올라옴
            final active = _planting || dragging;
            final fg = (active || hot) ? Colors.white : AppColors.ink;
            return GestureDetector(
              onTap: () => setState(() => _planting = !_planting),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: hot
                      ? AppColors.greenDark
                      : active
                          ? AppColors.green
                          : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                  border: dragging
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 5,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 16,
                      color: (active || hot) ? Colors.white : AppColors.sub),
                  const SizedBox(width: 6),
                  Text('모종함 $n',
                      style: TextStyle(
                          fontSize: 13,
                          color: fg,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          },
        ),
        // 심긴 식물을 드래그하는 동안 칩 아래 안내 문구.
        if (dragging) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('여기로 끌어 모종함으로 넣기',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  Widget _garden3d(BoxConstraints c) {
    final w = c.maxWidth;
    final h = c.maxHeight;
    final plant = _plant!;

    final children = <Widget>[];

    // 자유 배치된 식물들 (뒤→앞 순). 길게 눌러 이동, 탭하면 거두기.
    // 뒤(언덕)로 갈수록 원근감 있게 작아짐.
    for (final p in _placedPlants) {
      final isTree = isGroundPlant(p.species);
      final foot = _footOf(p);
      final scale = _perspScale(foot.dy);
      final iw = (isTree ? 108.0 : 72.0) * scale;
      final ih = (isTree ? 140.0 : 94.0) * scale;
      children.add(Positioned(
        left: foot.dx * w - iw / 2,
        top: foot.dy * h - ih,
        width: iw,
        height: ih,
        child: LongPressDraggable<Plant>(
          data: p,
          feedback: _dragFeedback(p),
          childWhenDragging: const SizedBox.shrink(),
          onDragStarted: () => setState(() => _dragSource = _DragSrc.placed),
          onDragEnd: (_) => setState(() => _dragSource = _DragSrc.none),
          child: _PlacedPlant(plant: p),
        ),
      ));
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

    // 정원 전체가 드롭 대상 — 모종을 떨어뜨린 위치에 심긴다.
    return DragTarget<Plant>(
      onAcceptWithDetails: (d) => _onDropPlant(d.data, d.offset),
      builder: (ctx, cand, rej) => Stack(
        key: _canvasKey,
        clipBehavior: Clip.none,
        children: children,
      ),
    );
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

/// 정원에 자유 배치된 식물 (만개 모습). 나무는 흙더미 없이 땅에 바로,
/// 꽃은 흙/화분 없이 꽃송이만.
class _PlacedPlant extends StatelessWidget {
  const _PlacedPlant({required this.plant});
  final Plant plant;

  @override
  Widget build(BuildContext context) =>
      PlantSprite(species: plant.species, stage: 5, inPot: false);
}


