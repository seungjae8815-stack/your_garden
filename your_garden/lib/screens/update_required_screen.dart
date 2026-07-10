import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../theme.dart';

/// 강제 업데이트 화면 — 현재 빌드가 서버의 최소지원 빌드보다 낮을 때 앱을 덮는다.
/// 뒤로가기·닫기 불가. "지금 업데이트"만 가능.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.status});
  final UpdateStatus status;

  @override
  Widget build(BuildContext context) {
    final version = status.latestVersion;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFDF3), AppColors.cream, AppColors.creamDeep],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 20),
                    const Text(
                      '업데이트가 필요해요',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      status.message ??
                          '너의 정원을 계속 가꾸려면 새 버전으로 이어가 주세요.\n마음 기록은 그대로 안전하게 남아 있어요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color: AppColors.sub,
                      ),
                    ),
                    if (version != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        '최신 버전 v$version',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.faint,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => openStore(status.url),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 3,
                          shadowColor: const Color(0x557CB342),
                        ),
                        child: const Text(
                          '지금 업데이트',
                          style: TextStyle(fontSize: 16.5, letterSpacing: 0.5),
                        ),
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
}
