import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 정원을 날아다니는 나비·벌 + 가끔/탭하면 말풍선.
/// 그림 에셋(butterfly_1..3.png, bee_1..3.png)이 있으면 그것으로, 없으면 이모지로 표시.
class GardenCritters extends StatefulWidget {
  const GardenCritters({super.key, this.night = false});

  /// 밤이면 반딧불(빛나며 깜빡임), 낮이면 나비·벌.
  final bool night;

  @override
  State<GardenCritters> createState() => _GardenCrittersState();
}

class _GardenCrittersState extends State<GardenCritters>
    with SingleTickerProviderStateMixin {
  // 40초 한 바퀴. 정수 주파수의 sin 합이라 끝에서 매끄럽게 반복됨.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  final math.Random _rng = math.Random();
  late final List<_Critter> _critters;

  int? _talkIdx; // 말하는 중인 곤충 인덱스
  String _talkMsg = '';
  double _frozenPhase = 0; // 말하는 동안 위치 고정
  Timer? _talkTimer;
  Timer? _autoTimer;

  static const _butterflyLines = [
    '오늘은 어떤 마음을 묻었나요?',
    '햇살이 참 포근하죠 ☀️',
    '잎사귀가 반짝여요',
    '천천히 쉬어가도 괜찮아요',
    '당신의 정원, 참 따뜻해요',
    '여기 향기가 좋아요 🌸',
  ];
  static const _beeLines = [
    '윙—! 좋은 향기예요',
    '곧 꽃이 활짝 필 거예요',
    '부지런히 날아왔어요',
    '오늘도 정원이 싱그럽네요',
    '꿀처럼 달콤한 하루 되세요',
  ];
  static const _fireflyLines = [
    '별이 예쁜 밤이에요 ✨',
    '오늘 하루도 수고했어요',
    '반짝— 여기 있어요',
    '푹 쉬어요, 좋은 꿈 꿔요',
    '어둠 속에서도 빛나고 있어요',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.night) {
      // 밤: 반딧불 2~5마리
      final n = 2 + _rng.nextInt(4);
      _critters = [for (var i = 0; i < n; i++) _make('firefly')];
    } else {
      // 낮: 나비 1~3, 벌 0~2 (최소 2마리 보장), 매번 랜덤
      var nB = 1 + _rng.nextInt(3);
      var nBee = _rng.nextInt(3);
      if (nB + nBee < 2) nBee += 1;
      _critters = [
        for (var i = 0; i < nB; i++) _make('butterfly'),
        for (var i = 0; i < nBee; i++) _make('bee'),
      ];
    }
    _scheduleAuto();
  }

  _Critter _make(String type) {
    double r(double a, double b) => a + _rng.nextDouble() * (b - a);
    final freqs = [1.0, 2.0, 3.0];
    return _Critter(
      type: type,
      cx: r(0.25, 0.75),
      cy: r(0.28, 0.58),
      ax: r(0.12, 0.20),
      ay: r(0.08, 0.14),
      bx: r(0.05, 0.10),
      by: r(0.04, 0.08),
      fx1: freqs[_rng.nextInt(3)],
      fx2: freqs[_rng.nextInt(3)],
      fy1: freqs[_rng.nextInt(3)],
      fy2: freqs[_rng.nextInt(3)],
      px1: _rng.nextDouble(),
      px2: _rng.nextDouble(),
      py1: _rng.nextDouble(),
      py2: _rng.nextDouble(),
      size: type == 'butterfly'
          ? r(34, 44)
          : type == 'bee'
              ? r(28, 34)
              : r(26, 34),
      flapHz: type == 'butterfly'
          ? 5.0
          : type == 'bee'
              ? 11.0
              : 6.0,
    );
  }

  void _scheduleAuto() {
    _autoTimer = Timer(Duration(seconds: 6 + _rng.nextInt(8)), () {
      if (mounted && _talkIdx == null && _critters.isNotEmpty) {
        _talk(_rng.nextInt(_critters.length));
      }
      _scheduleAuto();
    });
  }

  void _talk(int i) {
    final c = _critters[i];
    final pool = c.type == 'butterfly'
        ? _butterflyLines
        : c.type == 'bee'
            ? _beeLines
            : _fireflyLines;
    setState(() {
      _talkIdx = i;
      _talkMsg = pool[_rng.nextInt(pool.length)];
      _frozenPhase = _c.value;
    });
    _talkTimer?.cancel();
    _talkTimer = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) setState(() => _talkIdx = null);
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _talkTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final children = <Widget>[];
            for (var i = 0; i < _critters.length; i++) {
              final c = _critters[i];
              final talking = _talkIdx == i;
              final phase = talking ? _frozenPhase : _c.value;
              final p = c.posAt(phase);
              final pNext = c.posAt(phase + 0.004);
              final faceLeft = pNext.dx < p.dx;
              final x = p.dx * w, y = p.dy * h;
              final frame = c.frameAt(_c.value);

              final art = Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scaleByDouble(faceLeft ? -1.0 : 1.0, 1.0, 1.0, 1.0),
                child: _CritterArt(type: c.type, frame: frame, size: c.size),
              );
              // 반딧불: 꼬리 빛 번짐 + 천천히 깜빡임
              Widget inner = art;
              if (c.type == 'firefly') {
                final pulse = 0.4 +
                    0.6 * (0.5 + 0.5 * math.sin(2 * math.pi * (c.px1 + _c.value * 16)));
                inner = Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    IgnorePointer(
                      child: Container(
                        width: c.size * 0.5,
                        height: c.size * 0.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC9FF5C)
                                  .withValues(alpha: 0.85 * pulse),
                              blurRadius: c.size * 0.8,
                              spreadRadius: c.size * 0.18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    art,
                  ],
                );
              }
              children.add(Positioned(
                left: x - c.size,
                top: y - c.size,
                width: c.size * 2,
                height: c.size * 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _talk(i),
                  child: Center(child: inner),
                ),
              ));

              if (talking) {
                children.add(_bubble(x, y - c.size, w));
              }
            }
            return Stack(clipBehavior: Clip.none, children: children);
          },
        );
      },
    );
  }

  Widget _bubble(double x, double topOfCritter, double w) {
    const bw = 200.0;
    final left = (x - bw / 2).clamp(6.0, w - bw - 6);
    return Positioned(
      left: left,
      top: (topOfCritter - 52).clamp(6.0, double.infinity),
      width: bw,
      child: Align(
        alignment: Alignment.center,
        child: _SpeechBubble(text: _talkMsg),
      ),
    );
  }
}

class _Critter {
  _Critter({
    required this.type,
    required this.cx,
    required this.cy,
    required this.ax,
    required this.ay,
    required this.bx,
    required this.by,
    required this.fx1,
    required this.fx2,
    required this.fy1,
    required this.fy2,
    required this.px1,
    required this.px2,
    required this.py1,
    required this.py2,
    required this.size,
    required this.flapHz,
  });
  final String type;
  final double cx, cy, ax, ay, bx, by;
  final double fx1, fx2, fy1, fy2, px1, px2, py1, py2;
  final double size, flapHz;

  Offset posAt(double phase) {
    final x = cx +
        ax * math.sin(2 * math.pi * (fx1 * phase + px1)) +
        bx * math.sin(2 * math.pi * (fx2 * phase + px2));
    final y = cy +
        ay * math.sin(2 * math.pi * (fy1 * phase + py1)) +
        by * math.cos(2 * math.pi * (fy2 * phase + py2));
    return Offset(x.clamp(0.04, 0.96), y.clamp(0.12, 0.80));
  }

  // 0,1,2 프레임을 [열림→중간→닫힘→중간] 순으로 순환.
  int frameAt(double t) {
    const seq = [0, 1, 2, 1];
    final pos = (t * flapHz * 40) % 1.0; // 40s 한 바퀴
    return seq[(pos * seq.length).floor() % seq.length];
  }
}

/// 곤충 그림: 에셋 있으면 그림, 없으면 이모지 폴백.
class _CritterArt extends StatelessWidget {
  const _CritterArt({required this.type, required this.frame, required this.size});
  final String type;
  final int frame;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/gardens/${type}_${frame + 1}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Text(
        type == 'butterfly'
            ? '🦋'
            : type == 'bee'
                ? '🐝'
                : '✨',
        style: TextStyle(fontSize: size * 0.78),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.ink, height: 1.3),
          ),
        ),
        // 말풍선 꼬리
        CustomPaint(size: const Size(14, 7), painter: _TailPainter()),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.95);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) => false;
}
