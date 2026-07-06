import 'package:flutter/material.dart';

/// 자해/위기 신호 키워드 (한국어). 과탐지보다 **안전 우선**.
/// 비공개 테스트 기간 중 다국어/표현 보강 예정.
const List<String> crisisKeywords = [
  '자살',
  '죽고싶',
  '죽어버',
  '없어지고싶',
  '사라지고싶',
  '목숨',
  '목매',
  '자해',
  '손목',
  '뛰어내리',
  '번개탄',
  '유서',
  '살기싫',
  '죽을래',
  '끝내고싶',
  '죽음',
  '약먹고',
];

/// 공백을 제거하고 키워드 포함 여부 검사 (띄어쓰기 회피 방지).
bool detectCrisis(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), '');
  for (final k in crisisKeywords) {
    if (normalized.contains(k)) return true;
  }
  return false;
}

/// 위기 신호 감지 시 부드러운 지원 시트.
/// 제출을 막지 않되 먼저 지원 정보를 보여줌. true=그래도 진행, false=돌아가기.
Future<bool> showCrisisSupport(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFF8E1),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '혼자 견디지 않아도 괜찮아요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5D4037),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '지금 많이 무거운 마음을 안고 계신 것 같아요.\n당신의 이야기를 들어줄 사람들이 있어요.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF6D4C41),
              ),
            ),
            const SizedBox(height: 20),
            _SupportLine(label: '자살예방상담전화', number: '1393'),
            _SupportLine(label: '정신건강상담전화', number: '1577-0199'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('다시 쓰기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7CB342),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('그래도 묻기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

class _SupportLine extends StatelessWidget {
  const _SupportLine({required this.label, required this.number});
  final String label;
  final String number;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6D4C41)),
            ),
          ),
          SelectableText(
            number,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5D4037),
            ),
          ),
        ],
      ),
    );
  }
}
