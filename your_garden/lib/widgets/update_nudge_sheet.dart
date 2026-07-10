import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../theme.dart';

/// 선택 업데이트 넛지 — 새 버전이 있지만 강제는 아닐 때 부드럽게 권한다.
/// "나중에" 로 닫을 수 있다. (빌드별 1회만 표시)
Future<void> showUpdateNudgeSheet(BuildContext context, UpdateStatus status) {
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
                const Text('✨', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Text(
                  '새 버전이 있어요',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const Spacer(),
                if (status.latestVersion != null)
                  Text(
                    'v${status.latestVersion}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.faint,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '더 나아진 너의 정원으로 이어가 보세요. 지금 업데이트할까요?',
              style: TextStyle(fontSize: 14, color: AppColors.sub, height: 1.5),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      '나중에',
                      style: TextStyle(color: AppColors.sub),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      openStore(status.url);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text('업데이트', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
