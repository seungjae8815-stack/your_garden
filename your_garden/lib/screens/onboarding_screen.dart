import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'main_shell.dart';

/// 첫 진입 1회. 컨셉 소개 → 메타포/프라이버시 → 정원 이름 + 공개 여부 + 약관 동의.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.profile});
  final AuthResult profile;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _lastPage = 2;

  final PageController _controller = PageController();
  int _page = 0;
  bool _isPublic = false;
  bool _agreed = false;
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _lastPage) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finish() async {
    if (!_agreed || _finishing) return;
    setState(() => _finishing = true);
    try {
      await AuthService(Supabase.instance.client).completeOnboarding(
        uid: widget.profile.uid,
        isPublic: _isPublic,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainShell(profile: widget.profile)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시작하지 못했어요: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _ConceptPage(),
                  const _MetaphorPage(),
                  _IdentityPage(
                    nickname: widget.profile.nickname,
                    isPublic: _isPublic,
                    onPublicChanged: (v) => setState(() => _isPublic = v),
                    agreed: _agreed,
                    onAgreedChanged: (v) => setState(() => _agreed = v),
                  ),
                ],
              ),
            ),
            _Dots(count: _lastPage + 1, active: _page),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
              child: _page < _lastPage
                  ? _PrimaryButton(label: '다음', onPressed: _next)
                  : _PrimaryButton(
                      label: '정원 시작하기',
                      onPressed: _agreed && !_finishing ? _finish : null,
                      loading: _finishing,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptPage extends StatelessWidget {
  const _ConceptPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/plants/succulent_stage_4.svg',
              width: 180, height: 180),
          const SizedBox(height: 40),
          const Text(
            '너의 정원',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5D4037),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '마음 한 줄을 묻으면,\n그 마음이 양분이 되어\n식물이 자라요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.7, color: Color(0xFF8D6E63)),
          ),
        ],
      ),
    );
  }
}

class _MetaphorPage extends StatelessWidget {
  const _MetaphorPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 40),
          const Text(
            '비우는 게 아니라,\n묻는 거예요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5D4037),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '힘든 마음을 흙에 묻으면\n식물의 양분이 돼요.\n\n여기 적는 건 아무에게도 보이지 않아요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.7, color: Color(0xFF8D6E63)),
          ),
        ],
      ),
    );
  }
}

class _IdentityPage extends StatelessWidget {
  const _IdentityPage({
    required this.nickname,
    required this.isPublic,
    required this.onPublicChanged,
    required this.agreed,
    required this.onAgreedChanged,
  });

  final String nickname;
  final bool isPublic;
  final ValueChanged<bool> onPublicChanged;
  final bool agreed;
  final ValueChanged<bool> onAgreedChanged;

  void _showPrivacy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFF8E1),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('이용약관 · 개인정보 안내',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5D4037))),
              const SizedBox(height: 14),
              const Text(
                '• 로그인 없이 익명으로 이용해요. 이메일·이름을 받지 않아요.\n'
                '• 기기를 구분하기 위한 임의의 기기 식별값(device ID)을 저장해요.\n'
                '• 당신이 적은 글은 당신의 정원에 저장되며, 비공개일 땐 다른 사람에게 보이지 않아요.\n'
                '• 이 앱은 의료·상담 서비스가 아니에요. 위급할 땐 안내되는 도움 전화로 연결해 주세요.',
                style:
                    TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF6D4C41)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7CB342),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text(
            '당신의 정원',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0D7C5)),
            ),
            child: Row(
              children: [
                const Text('🪴', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('자동으로 지어진 이름',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFFA1887F))),
                      const SizedBox(height: 2),
                      Text(nickname,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5D4037))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0D7C5)),
            ),
            child: SwitchListTile(
              value: isPublic,
              onChanged: onPublicChanged,
              activeThumbColor: const Color(0xFF7CB342),
              title: const Text('정원 공개하기',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5D4037))),
              subtitle: const Text(
                '기본은 나만의 정원이에요. 나중에 다른 정원과 마음을 나누는 기능이 열릴 때 참여할지 미리 정해둘 수 있어요. (설정에서 언제든 변경)',
                style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFFA1887F)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: agreed,
                onChanged: (v) => onAgreedChanged(v ?? false),
                activeColor: const Color(0xFF7CB342),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onAgreedChanged(!agreed),
                  child: const Text(
                    '이용약관 및 개인정보 안내에 동의합니다.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6D4C41)),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _showPrivacy(context),
                child: const Text('내용 보기',
                    style: TextStyle(fontSize: 13, color: Color(0xFF7CB342))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active
                  ? const Color(0xFF7CB342)
                  : const Color(0xFFD7CCC8),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7CB342),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCFE3B8),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 2,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
