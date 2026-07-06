import 'dart:math';

import 'package:flutter/material.dart';

/// 단계별 그림(에셋)을 가진 꽃 종류. 새로 심는 식물은 이 중에서 무작위로 정해진다.
const kFlowerSpecies = ['cosmos', 'tulip', 'sunflower', 'rose', 'daffodil'];

/// 단계별 그림(에셋)을 가진 나무 종류. 땅에 심는다.
const kTreeSpecies = ['cherry', 'maple', 'pine', 'ginkgo', 'persimmon'];

/// 식물 종류(레거시 포함). 화분류는 선반 위, 나무는 땅에 심음.
const kPlantSpecies = ['flower', 'succulent', 'herb', 'tree'];

/// 나무(땅에 심는 종)인지. 레거시 'tree' 포함.
bool isGroundPlant(String species) =>
    species == 'tree' || kTreeSpecies.contains(species);

/// 레거시 'flower'(테스트용으로 만들었던 코스모스)는 cosmos 에셋으로 표시.
String _assetPrefix(String s) => s == 'flower' ? 'cosmos' : s;

/// soil.png 높이/너비 비율 (742/2529).
const double kSoilRatio = 0.2934;

/// mound_front.png(볼록 흙더미) 높이/너비 비율.
const double kMoundRatio = 0.39;

String speciesLabel(String s) => switch (s) {
  'cosmos' || 'flower' => '코스모스',
  'tulip' => '튤립',
  'sunflower' => '해바라기',
  'rose' => '장미',
  'daffodil' => '수선화',
  'cherry' => '벚나무',
  'maple' => '단풍나무',
  'pine' => '소나무',
  'ginkgo' => '은행나무',
  'persimmon' => '감나무',
  'succulent' => '다육이',
  'herb' => '허브',
  'tree' => '나무',
  _ => '식물',
};

/// 일러스트 에셋이 있는 종은 그림으로, 없으면 PlantPainter로 그린다.
/// 꽃 5종 + 나무 5종이 단계별 그림(<종>_1..5.png)을 가짐.
class PlantSprite extends StatelessWidget {
  const PlantSprite({
    super.key,
    required this.species,
    required this.stage,
    this.inPot = false,
  });
  final String species;
  final int stage;
  final bool inPot;

  static bool hasAsset(String species) =>
      species == 'flower' ||
      kFlowerSpecies.contains(species) ||
      kTreeSpecies.contains(species);

  /// 단계별 표시 높이 비율(원본 그림의 실제 높이 비례). 새싹은 작게, 만개는 크게.
  static double heightFactor(String species, int stage) {
    if (!hasAsset(species)) return 1.0;
    final s = stage.clamp(1, 5);
    if (kTreeSpecies.contains(species)) {
      // 나무는 묘목→큰나무로 더 완만하게 커짐.
      return switch (s) {
        1 => 0.32,
        2 => 0.55,
        3 => 0.74,
        4 => 0.89,
        _ => 1.0,
      };
    }
    return switch (s) {
      1 => 0.26,
      2 => 0.58,
      3 => 0.82,
      4 => 0.92,
      _ => 1.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (hasAsset(species)) {
      final s = stage.clamp(1, 5);
      return Image.asset(
        'assets/gardens/${_assetPrefix(species)}_$s.png',
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.medium,
      );
    }
    return CustomPaint(
      size: Size.infinite,
      painter: PlantPainter(species: species, stage: stage, inPot: inPot),
    );
  }
}

/// 나무를 흙더미에 심어 보여주는 위젯.
/// 흙더미를 (뒤 받침) + 나무 + (앞 둔덕: 아래 일부) 순서로 겹쳐 그려, 줄기 밑동을
/// 흙더미 앞면 뒤로 가린다. 덕분에 나무 그림의 밑동 모양이 제각각이어도(혹은 새 나무가
/// 추가돼도) 종별 보정 없이 항상 "땅에 심긴" 모습이 된다.
class TreeOnSoil extends StatelessWidget {
  const TreeOnSoil({
    super.key,
    required this.species,
    required this.stage,
    required this.soilW,
    required this.treeW,
    required this.treeH,
    this.frontFactor = 0.60, // 앞 작은 둔덕 너비(soilW 대비). 밑동만 살짝 가림
    this.baseFactor = 0.10, // 줄기 밑동을 흙더미 높이의 이만큼 위에 둠
  });
  final String species;
  final int stage;
  final double soilW;
  final double treeW;
  final double treeH;
  final double frontFactor;
  final double baseFactor;

  @override
  Widget build(BuildContext context) {
    final soilH = soilW * kSoilRatio;
    final baseSink = soilH * baseFactor;
    final sprite = PlantSprite.hasAsset(species)
        ? PlantSprite(species: species, stage: stage, inPot: false)
        : CustomPaint(
            painter: PlantPainter(species: species, stage: stage, inPot: false),
          );
    return SizedBox(
      width: (treeW > soilW ? treeW : soilW) + 4,
      height: treeH + baseSink + 6,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Image.asset('assets/gardens/soil.png', width: soilW), // 뒤: 원본 흙더미
          Positioned(
            bottom: baseSink,
            child: SizedBox(width: treeW, height: treeH, child: sprite),
          ),
          // 앞: 작은 흙더미로 줄기 밑동만 살짝 가림(원본 흙더미는 그대로 보임)
          Image.asset(
            'assets/gardens/mound_front.png',
            width: soilW * frontFactor,
          ),
        ],
      ),
    );
  }
}

/// 코드로 그린 식물 (종류 × 성장단계 1~5). 나중에 에셋/Rive로 교체.
class PlantPainter extends CustomPainter {
  PlantPainter({required this.species, required this.stage, this.inPot = true});
  final String species;
  final int stage;
  final bool inPot; // 화분에 담아 그릴지 (tree는 무시)

  static const _pot = Color(0xFFC08E6E);
  static const _potR = Color(0xFFA9785C);
  static const _stem = Color(0xFF558B2F);
  static const _soil = Color(0xFF6D4C41);
  static const _trunk = Color(0xFF8D6E63);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final s = stage.clamp(1, 5);

    if (species == 'tree') {
      _tree(canvas, w, h, cx, s);
      return;
    }

    double soilY;
    if (inPot) {
      final potTopY = h * 0.66;
      final potBottomY = h * 0.96;
      final tH = w * 0.20;
      final bH = w * 0.15;
      final path = Path()
        ..moveTo(cx - tH, potTopY)
        ..lineTo(cx + tH, potTopY)
        ..lineTo(cx + bH, potBottomY)
        ..lineTo(cx - bH, potBottomY)
        ..close();
      canvas.drawPath(path, Paint()..color = _pot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            cx - tH - w * 0.025,
            potTopY - h * 0.045,
            cx + tH + w * 0.025,
            potTopY + h * 0.015,
          ),
          Radius.circular(w * 0.025),
        ),
        Paint()..color = _potR,
      );
      soilY = potTopY - h * 0.012;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, soilY),
          width: tH * 1.7,
          height: h * 0.03,
        ),
        Paint()..color = _soil,
      );
    } else {
      soilY = h * 0.92;
    }

    switch (species) {
      case 'succulent':
        _succulent(canvas, cx, soilY, w, s);
      case 'herb':
        _herb(canvas, cx, soilY, w, h, s);
      default:
        _flower(canvas, cx, soilY, w, h, s);
    }
  }

  void _flower(Canvas c, double cx, double soilY, double w, double h, int s) {
    final stemTop = soilY - h * (0.06 + 0.09 * s);
    c.drawLine(
      Offset(cx, soilY),
      Offset(cx, stemTop),
      Paint()
        ..color = _stem
        ..strokeWidth = w * 0.026
        ..strokeCap = StrokeCap.round,
    );
    final pairs = (s - 1).clamp(1, 3);
    for (var i = 0; i < pairs; i++) {
      final t = pairs == 1 ? 0.45 : i / (pairs - 1);
      final y = soilY + (stemTop - soilY) * (0.25 + 0.55 * t);
      _leaf(c, cx, y, w * 0.17, -1, const Color(0xFF7CB342));
      _leaf(c, cx, y, w * 0.17, 1, const Color(0xFF8BC34A));
    }
    if (s >= 3) {
      _bloom(
        c,
        Offset(cx, stemTop),
        w * (0.06 + 0.02 * s),
        s >= 5 ? const Color(0xFFF48FB1) : const Color(0xFFF6A5C0),
      );
    } else {
      _leaf(c, cx, stemTop, w * 0.15, -1, const Color(0xFF9CCC65));
      _leaf(c, cx, stemTop, w * 0.15, 1, const Color(0xFF9CCC65));
    }
  }

  void _succulent(Canvas c, double cx, double soilY, double w, int s) {
    final cy = soilY - w * 0.16;
    final layers = [
      (8, 0.40, const Color(0xFF689F38)),
      (7, 0.30, const Color(0xFF7CB342)),
      (6, 0.20, const Color(0xFF9CCC65)),
    ];
    final base = w * (0.18 + 0.06 * s);
    for (final (count, lr, color) in layers) {
      final len = base * lr * 2;
      for (var i = 0; i < count; i++) {
        final ang = (2 * pi / count) * i;
        c.save();
        c.translate(cx + cos(ang) * len * 0.5, cy + sin(ang) * len * 0.5 * 0.7);
        c.rotate(ang + pi / 2);
        c.drawOval(
          Rect.fromCenter(center: Offset.zero, width: len * 0.5, height: len),
          Paint()..color = color,
        );
        c.restore();
      }
    }
    c.drawCircle(
      Offset(cx, cy),
      base * 0.12,
      Paint()..color = const Color(0xFFC5E1A5),
    );
  }

  void _herb(Canvas c, double cx, double soilY, double w, double h, int s) {
    final sprigs = 2 + s;
    for (var i = 0; i < sprigs; i++) {
      final dir = (i.isEven ? -1 : 1);
      final spread = (i ~/ 2 + 1) * 0.18;
      final top = soilY - h * (0.10 + 0.07 * s) * (1 - spread * 0.3);
      final tipX = cx + dir * w * spread;
      c.drawLine(
        Offset(cx, soilY),
        Offset(tipX, top),
        Paint()
          ..color = _stem
          ..strokeWidth = w * 0.018
          ..strokeCap = StrokeCap.round,
      );
      c.drawCircle(
        Offset(tipX, top),
        w * 0.05,
        Paint()..color = const Color(0xFF8BC34A),
      );
    }
  }

  void _tree(Canvas c, double w, double h, double cx, int s) {
    final baseY = h * 0.95;
    final scale = 0.35 + 0.65 * (s / 5); // 새싹~큰나무
    final trunkH = h * 0.5 * scale;
    final canopyR = w * 0.42 * scale;
    c.drawRect(
      Rect.fromCenter(
        center: Offset(cx, baseY - trunkH * 0.4),
        width: w * 0.07 * (0.6 + scale),
        height: trunkH * 0.8,
      ),
      Paint()..color = _trunk,
    );
    final topY = baseY - trunkH;
    c.drawCircle(
      Offset(cx, topY),
      canopyR,
      Paint()..color = const Color(0xFF66993F),
    );
    c.drawCircle(
      Offset(cx - canopyR * 0.4, topY + canopyR * 0.2),
      canopyR * 0.7,
      Paint()..color = const Color(0xFF78AB4F),
    );
    c.drawCircle(
      Offset(cx + canopyR * 0.45, topY + canopyR * 0.15),
      canopyR * 0.6,
      Paint()..color = const Color(0xFF85B85C),
    );
  }

  void _leaf(Canvas c, double x, double y, double len, int dir, Color color) {
    c.save();
    c.translate(x, y);
    c.rotate(dir * 0.6);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(dir * len * 0.4, 0),
        width: len,
        height: len * 0.5,
      ),
      Paint()..color = color,
    );
    c.restore();
  }

  void _bloom(Canvas c, Offset center, double r, Color color) {
    final p = Paint()..color = color;
    for (var i = 0; i < 6; i++) {
      final a = i * pi * 2 / 6;
      c.drawCircle(center + Offset(r * cos(a), r * sin(a)), r * 0.62, p);
    }
    c.drawCircle(center, r * 0.6, Paint()..color = const Color(0xFFFFD54F));
  }

  @override
  bool shouldRepaint(PlantPainter old) =>
      old.stage != stage || old.species != species || old.inPot != inPot;
}
