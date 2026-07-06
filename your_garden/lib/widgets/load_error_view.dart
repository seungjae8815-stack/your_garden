import 'package:flutter/material.dart';

import '../theme.dart';

/// 로딩 실패 시 공통으로 보여주는 "불러오지 못했어요 + 다시 시도" 카드.
/// 각 화면의 _load 실패 분기에서 빈 화면 대신 사용해, 실패가 '데이터 없음'처럼
/// 조용히 묻히지 않게 한다. (garden_screen의 _errorView와 같은 톤)
class LoadErrorView extends StatelessWidget {
  const LoadErrorView({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message ?? '불러오지 못했어요',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
