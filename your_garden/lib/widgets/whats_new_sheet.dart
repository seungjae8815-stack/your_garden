import 'package:flutter/material.dart';

import '../services/whats_new.dart';
import '../theme.dart';

/// "새로워진 점" 바텀시트.
/// 업데이트 후 첫 실행(MainShell)과 설정의 "버전 눌러 다시 보기"에서 공용 사용.
Future<void> showWhatsNewSheet(BuildContext context, WhatsNewEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🌿', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Text(
                  '새로워진 점',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  'v${entry.version}',
                  style: const TextStyle(fontSize: 13, color: AppColors.faint),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '너의 정원이 조금 더 따뜻해졌어요.',
              style: TextStyle(fontSize: 13, color: AppColors.faint),
            ),
            const SizedBox(height: 16),
            for (final line in entry.notes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  line,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.ink,
                    height: 1.4,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('좋아요', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
