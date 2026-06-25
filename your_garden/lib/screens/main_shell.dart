import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
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
