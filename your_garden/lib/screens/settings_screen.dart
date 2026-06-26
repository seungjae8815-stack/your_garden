import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/garden_service.dart';
import '../theme.dart';
import '../widgets/plant_painter.dart';

const _privacyUrl = 'https://seungjae8815-stack.github.io/yourgarden-policy/';

/// 설정 탭.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.profile});
  final AuthResult profile;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final GardenService _garden = GardenService(Supabase.instance.client);
  late bool _isPublic = widget.profile.isPublic;
  late bool _testFast = GardenService.testFastGrowth;
  bool _busy = false;

  Future<void> _toggleTest(bool v) async {
    setState(() => _testFast = v);
    GardenService.testFastGrowth = v;
    await AuthService(Supabase.instance.client).setTestFast(v);
  }

  Future<void> _setSpecies(String s) async {
    try {
      await _garden.setActiveSpecies(widget.profile.uid, s);
      markGardenDirty();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('현재 식물을 ${speciesLabel(s)}(으)로 바꿨어요. 정원 탭에서 확인!')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('바꾸지 못했어요.')));
    }
  }

  // 테스트: 현재 키우는 식물을 고른 종으로 바꾸기 (꽃/나무 공용).
  Future<void> _pickSpecies(List<String> list, String title) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 4),
              const Text('현재 키우는 식물을 고른 종으로 바꿔요.',
                  style: TextStyle(fontSize: 13, color: AppColors.faint)),
              const SizedBox(height: 14),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final sp = list[i];
                    return GestureDetector(
                      onTap: () => Navigator.pop(ctx, sp),
                      child: Container(
                        width: 96,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          children: [
                            Expanded(
                              child: PlantSprite(
                                  species: sp, stage: 5, inPot: false),
                            ),
                            Text(speciesLabel(sp),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.sub)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) await _setSpecies(chosen);
  }

  Future<void> _togglePublic(bool v) async {
    setState(() => _isPublic = v);
    try {
      await _garden.setPublic(widget.profile.uid, v);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPublic = !v);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('변경하지 못했어요.')));
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: const Text('내 정원을 모두 지울까요?'),
        content: const Text('지금까지 묻은 마음과 키운 식물이 모두 사라져요. 되돌릴 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('모두 삭제', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _garden.deleteAllData(widget.profile.uid);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('삭제했어요. 앱을 다시 열면 새 정원이 시작돼요.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('삭제하지 못했어요.')));
    }
  }

  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: const Text('전체 초기화할까요?'),
        content: const Text('식물·기록·온보딩이 모두 지워져요 (테스트용). 되돌릴 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('초기화', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _garden.deleteAllData(widget.profile.uid);
      await AuthService(Supabase.instance.client).resetLocal();
      // 초기화 후에도 테스트 모드 토글 상태는 그대로 유지 (재토글 불필요).
      GardenService.testFastGrowth = _testFast;
      await AuthService(Supabase.instance.client).setTestFast(_testFast);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('초기화됐어요. 앱을 완전히 종료한 뒤 다시 열어주세요.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('초기화하지 못했어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(color: AppColors.ink)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card([
            _row('내 정원 이름', widget.profile.nickname),
          ]),
          const SizedBox(height: 14),
          _card([
            SwitchListTile(
              value: _isPublic,
              onChanged: _busy ? null : _togglePublic,
              activeThumbColor: AppColors.green,
              contentPadding: EdgeInsets.zero,
              title: const Text('정원 공개',
                  style: TextStyle(fontSize: 15, color: AppColors.ink)),
              subtitle: const Text('다른 정원과 마음을 나누는 기능이 열릴 때 참여해요.',
                  style: TextStyle(fontSize: 12, color: AppColors.faint)),
            ),
          ]),
          const SizedBox(height: 14),
          _card([
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shield_outlined, color: AppColors.sub),
              title: const Text('개인정보처리방침 · 이용약관',
                  style: TextStyle(fontSize: 15, color: AppColors.ink)),
              subtitle: const Text('탭하면 주소를 복사해요',
                  style: TextStyle(fontSize: 12, color: AppColors.faint)),
              onTap: () {
                Clipboard.setData(const ClipboardData(text: _privacyUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('주소를 복사했어요.')));
              },
            ),
          ]),
          const SizedBox(height: 14),
          _card([
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
              title: Text('내 정원 데이터 삭제',
                  style: TextStyle(fontSize: 15, color: Colors.red.shade700)),
              onTap: _busy ? null : _confirmDelete,
            ),
          ]),
          const SizedBox(height: 14),
          _card([
            SwitchListTile(
              value: _testFast,
              onChanged: _toggleTest,
              activeThumbColor: AppColors.green,
              contentPadding: EdgeInsets.zero,
              title: const Text('테스트 모드',
                  style: TextStyle(fontSize: 15, color: AppColors.ink)),
              subtitle: const Text('켜면 쓸 때마다 한 단계씩 성장 (확인용). 확대 화면에 +1 버튼도 생겨요.',
                  style: TextStyle(fontSize: 12, color: AppColors.faint)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_florist_outlined, color: AppColors.sub),
              title: const Text('테스트: 꽃 종류 고르기',
                  style: TextStyle(fontSize: 15, color: AppColors.ink)),
              subtitle: const Text('코스모스·튤립·해바라기·장미·수선화',
                  style: TextStyle(fontSize: 12, color: AppColors.faint)),
              onTap: () => _pickSpecies(kFlowerSpecies, '테스트: 꽃 종류 고르기'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.park_outlined, color: AppColors.sub),
              title: const Text('테스트: 나무 종류 고르기',
                  style: TextStyle(fontSize: 15, color: AppColors.ink)),
              subtitle: const Text('벚나무·단풍나무·소나무·은행나무·감나무',
                  style: TextStyle(fontSize: 12, color: AppColors.faint)),
              onTap: () => _pickSpecies(kTreeSpecies, '테스트: 나무 종류 고르기'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.restart_alt, color: Colors.red.shade400),
              title: Text('전체 초기화 (테스트)',
                  style: TextStyle(fontSize: 15, color: Colors.red.shade700)),
              subtitle: const Text('식물·기록·온보딩 모두 삭제',
                  style: TextStyle(fontSize: 12, color: AppColors.faint)),
              onTap: _busy ? null : _resetAll,
            ),
          ]),
          const SizedBox(height: 24),
          const Center(
            child: Text('너의 정원 · 버전 1.0.0',
                style: TextStyle(fontSize: 12, color: AppColors.faint)),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 14, color: AppColors.sub)),
            const Spacer(),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 14, color: AppColors.ink),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}
