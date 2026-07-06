import 'package:flutter/material.dart';

import '../data/daily_prompts.dart';

/// 마음 날씨 아이콘. 일러스트 에셋(mood_1..5.png)이 있으면 그것으로,
/// 없으면 이모지로 폴백. (꽃·곤충 에셋과 동일한 방식)
class MoodIcon extends StatelessWidget {
  const MoodIcon({super.key, required this.value, this.size = 24});
  final int value; // 1..5
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/gardens/mood_$value.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) =>
          Text(moodOf(value).emoji, style: TextStyle(fontSize: size * 0.92)),
    );
  }
}
