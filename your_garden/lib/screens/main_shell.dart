import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/update_service.dart';
import '../services/whats_new.dart';
import '../theme.dart';
import '../widgets/update_nudge_sheet.dart';
import '../widgets/whats_new_sheet.dart';
import 'collection_screen.dart';
import 'garden_screen.dart';
import 'journal_screen.dart';
import 'settings_screen.dart';

/// 하단 4탭 셸: 정원 · 도감 · 기록 · 설정.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.profile});
  final AuthResult profile;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    GardenScreen(profile: widget.profile),
    CollectionScreen(profile: widget.profile),
    JournalScreen(profile: widget.profile),
    SettingsScreen(profile: widget.profile),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterEnter());
  }

  /// 메인 진입 직후: 업데이트 안내(새로워진 점) → 선택 업데이트 넛지 순서로 1회씩.
  Future<void> _afterEnter() async {
    await _maybeWhatsNew();
    await _maybeUpdateNudge();
  }

  Future<void> _maybeWhatsNew() async {
    final entry = await WhatsNew.instance.pending();
    if (entry == null || !mounted) return;
    await showWhatsNewSheet(context, entry);
    await WhatsNew.instance.markSeen(entry.version);
  }

  /// 선택 업데이트가 있으면 부드럽게 권한다. (게이트에서 캐시된 결과 재사용, 빌드별 1회)
  Future<void> _maybeUpdateNudge() async {
    if (!mounted) return;
    final s =
        UpdateService.instance.cached ?? await UpdateService.instance.check();
    if (!mounted || s.kind != UpdateKind.optional) return;
    if (await UpdateService.instance.alreadyNudged(s.latestBuild)) return;
    if (!mounted) return;
    await showUpdateNudgeSheet(context, s);
    await UpdateService.instance.markNudged(s.latestBuild);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.card,
        indicatorColor: const Color(0xFFDCEFC4),
        height: 66,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_florist_outlined),
            selectedIcon: Icon(Icons.local_florist, color: AppColors.greenDark),
            label: '정원',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories, color: AppColors.greenDark),
            label: '도감',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_edu_outlined),
            selectedIcon: Icon(Icons.history_edu, color: AppColors.greenDark),
            label: '기록',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.greenDark),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
