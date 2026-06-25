import 'dart:math';

import 'package:flutter/material.dart';

/// 식물 종류. 화분류(flower/succulent/herb)는 선반 위, tree는 땅에 심음.
const kPlantSpecies = ['flower', 'succulent', 'herb', 'tree'];
bool isGroundPlant(String species) => species == 'tree';

String speciesLabel(String s) => switch (s) {
      'flower' => '꽃',
      'succulent' => '다육이',
      'herb' => '허브',
      'tree' => '나무',
      _ => '식물',
    };

/// 코드로 그린 식물 (종류 × 성장단계 1~5). 나중에 에셋/Rive로 교체.
class PlantPainter extends CustomPainter {
  PlantPainter({
    required this.species,
    required this.stage,
    this.inPot = true,
  });
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
          Rect.fromLTRB(cx - tH - w * 0.025, potTopY - h * 0.045,
              cx + tH + w * 0.025, potTopY + h * 0.015),
          Radius.circular(w * 0.025),
        ),
        Paint()..color = _potR,
      );
      soilY = potTopY - h * 0.012;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, soilY), width: tH * 1.7, height: h * 0.03),
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
    c.drawLine(Offset(cx, soilY), Offset(cx, stemTop),
        Paint()
          ..color = _stem
          ..strokeWidth = w * 0.026
          ..strokeCap = StrokeCap.round);
    final pairs = (s - 1).clamp(1, 3);
    for (var i = 0; i < pairs; i++) {
      final t = pairs == 1 ? 0.45 : i / (pairs - 1);
      final y = soilY + (stemTop - soilY) * (0.25 + 0.55 * t);
      _leaf(c, cx, y, w * 0.17, -1, const Color(0xFF7CB342));
      _leaf(c, cx, y, w * 0.17, 1, const Color(0xFF8BC34A));
    }
    if (s >= 3) {
      _bloom(c, Offset(cx, stemTop), w * (0.06 + 0.02 * s),
          s >= 5 ? const Color(0xFFF48FB1) : const Color(0xFFF6A5C0));
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
            Paint()..color = color);
        c.restore();
      }
    }
    c.drawCircle(Offset(cx, cy), base * 0.12, Paint()..color = const Color(0xFFC5E1A5));
  }

  void _herb(Canvas c, double cx, double soilY, double w, double h, int s) {
    final sprigs = 2 + s;
    for (var i = 0; i < sprigs; i++) {
      final dir = (i.isEven ? -1 : 1);
      final spread = (i ~/ 2 + 1) * 0.18;
      final top = soilY - h * (0.10 + 0.07 * s) * (1 - spread * 0.3);
      final tipX = cx + dir * w * spread;
      c.drawLine(Offset(cx, soilY), Offset(tipX, top),
          Paint()
            ..color = _stem
            ..strokeWidth = w * 0.018
            ..strokeCap = StrokeCap.round);
      c.drawCircle(Offset(tipX, top), w * 0.05, Paint()..color = const Color(0xFF8BC34A));
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
          height: trunkH * 0.8),
      Paint()..color = _trunk,
    );
    final topY = baseY - trunkH;
    c.drawCircle(Offset(cx, topY), canopyR, Paint()..color = const Color(0xFF66993F));
    c.drawCircle(Offset(cx - canopyR * 0.4, topY + canopyR * 0.2), canopyR * 0.7,
        Paint()..color = const Color(0xFF78AB4F));
    c.drawCircle(Offset(cx + canopyR * 0.45, topY + canopyR * 0.15), canopyR * 0.6,
        Paint()..color = const Color(0xFF85B85C));
  }

  void _leaf(Canvas c, double x, double y, double len, int dir, Color color) {
    c.save();
    c.translate(x, y);
    c.rotate(dir * 0.6);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(dir * len * 0.4, 0), width: len, height: len * 0.5),
        Paint()..color = color);
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
