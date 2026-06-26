import 'package:flutter/material.dart';

import '../services/garden_service.dart';
import '../theme.dart';
import 'mood_icon.dart';

/// 한 식물에 묻은 마음들(감정의 여정)을 시간순으로 보여주는 리스트.
/// 돌아보기 의식 화면과 도감 상세에서 함께 쓴다.
class JourneyList extends StatelessWidget {
  const JourneyList({super.key, required this.entries});
  final List<EntryRecord> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
            child: Text('묻은 마음이 없어요',
                style: TextStyle(color: AppColors.faint))),
      );
    }
    return Column(
      children: [
        for (final e in entries)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (e.mood != null) ...[
                    MoodIcon(value: e.mood!, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Text(_date(e.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.faint)),
                ]),
                const SizedBox(height: 6),
                Text(
                  e.text.isEmpty ? '마음 날씨를 남긴 날' : e.text,
                  style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      fontStyle:
                          e.text.isEmpty ? FontStyle.italic : FontStyle.normal,
                      color: e.text.isEmpty ? AppColors.faint : AppColors.ink),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _date(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}.${two(l.month)}.${two(l.day)}';
  }
}
