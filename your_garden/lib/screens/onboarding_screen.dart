import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/garden_service.dart';
import 'first_checkin_screen.dart';
import 'settings_screen.dart'
    show promptRecoveryCode, openPrivacyPolicy, kSocialEnabled;

/// 첫 진입 1회. 컨셉 → 메타포 → 정원·첫 식물 이름 짓기 + 약관 동의.
/// 끝나면 곧바로 손잡은 첫 체크인(FirstCheckInScreen)으로 이어진다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.profile});
  final AuthResult profile;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _lastPage = 2;

  final PageController _controller = PageController();
  final TextEditingController _gardenName = TextEditingController();
  final TextEditingController _plantName = TextEditingController();
  int _page = 0;
  bool _isPublic = false;
  bool _agreed = false;
  bool _finishing = false;

  // 복구(이미 정원이 있는 사용자) — 새 정원을 만들기 전에 되찾게 한다.
  StreamSubscription<AuthState>? _authSub;
  bool _recovering = false;

  @override
  void initState() {
    super.initState();
    // Google 복구는 브라우저를 다녀온 뒤 signedIn 이벤트로 완료된다.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (!mounted || !_recovering) return;
      if (s.event == AuthChangeEvent.signedIn) _onRecovered();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _controller.dispose();
    _gardenName.dispose();
    _plantName.dispose();
    super.dispose();
  }

  /// 복구가 끝나면 — 로컬 온보딩 플래그를 세우고, 재시작으로 되찾은 정원을 연다.
  Future<void> _onRecovered() async {
    _recovering = false;
    await AuthService(Supabase.instance.client).markOnboarded();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8E1),
        title: const Text('정원을 되찾았어요 🌿'),
        content: const Text('앱을 완전히 종료한 뒤 다시 열면\n되찾은 정원이 나타나요.'),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7CB342),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _openRecoverSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFF8E1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '정원 되찾기',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '전에 쓰던 정원이 있다면, 새로 만들기 전에 여기서 되찾아 주세요.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFFA1887F),
                ),
              ),
              const SizedBox(height: 18),
              _RecoverOption(
                icon: Icons.account_circle_outlined,
                label: 'Google로 되찾기',
                onTap: () => _recoverWithGoogle(sheetCtx),
              ),
              const SizedBox(height: 10),
              _RecoverOption(
                icon: Icons.vpn_key_outlined,
                label: '복구 코드로 되찾기',
                onTap: () => _recoverWithCode(sheetCtx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recoverWithGoogle(BuildContext sheetCtx) async {
    Navigator.pop(sheetCtx);
    _recovering = true;
    try {
      await AuthService(Supabase.instance.client).signInGoogle();
    } catch (e) {
      _recovering = false;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('복구를 시작하지 못했어요: $e')));
    }
  }

  Future<void> _recoverWithCode(BuildContext sheetCtx) async {
    Navigator.pop(sheetCtx);
    final code = await promptRecoveryCode(context);
    if (code == null || code.trim().isEmpty) return;
    try {
      await AuthService(Supabase.instance.client).recoverWithCode(code);
      await _onRecovered();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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
      final client = Supabase.instance.client;
      final auth = AuthService(client);
      final garden = GardenService(client);

      final gardenName = _gardenName.text.trim();
      final plantName = _plantName.text.trim();

      await auth.completeOnboarding(
        uid: widget.profile.uid,
        isPublic: _isPublic,
        gardenName: gardenName,
      );

      // 첫 식물을 마련하고 이름을 붙인다 (감정 첫 챕터).
      final plant = await garden.ensureActivePlant(widget.profile.uid);
      if (plantName.isNotEmpty) {
        await garden.renamePlant(plant.id, plantName);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FirstCheckInScreen(
            profile: widget.profile.copyWith(
              gardenName: gardenName.isEmpty ? null : gardenName,
            ),
            plant: plantName.isEmpty ? plant : plant.withName(plantName),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('시작하지 못했어요: $e')));
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
                  _NamingPage(
                    nickname: widget.profile.nickname,
                    gardenName: _gardenName,
                    plantName: _plantName,
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
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 4),
              child: _page < _lastPage
                  ? _PrimaryButton(label: '다음', onPressed: _next)
                  : _PrimaryButton(
                      label: '정원 만들기',
                      onPressed: _agreed && !_finishing ? _finish : null,
                      loading: _finishing,
                    ),
            ),
            TextButton(
              onPressed: _finishing ? null : _openRecoverSheet,
              child: const Text(
                '이미 정원이 있으신가요? 되찾기',
                style: TextStyle(fontSize: 13, color: Color(0xFF8D6E63)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RecoverOption extends StatelessWidget {
  const _RecoverOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: const Color(0xFF7CB342)),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, color: Color(0xFF5D4037)),
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: const BorderSide(color: Color(0xFFE0D7C5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerLeft,
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
          SvgPicture.asset(
            'assets/plants/succulent_stage_4.svg',
            width: 180,
            height: 180,
          ),
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
            style: TextStyle(
              fontSize: 16,
              height: 1.7,
              color: Color(0xFF8D6E63),
            ),
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
            style: TextStyle(
              fontSize: 15,
              height: 1.7,
              color: Color(0xFF8D6E63),
            ),
          ),
        ],
      ),
    );
  }
}

class _NamingPage extends StatelessWidget {
  const _NamingPage({
    required this.nickname,
    required this.gardenName,
    required this.plantName,
    required this.isPublic,
    required this.onPublicChanged,
    required this.agreed,
    required this.onAgreedChanged,
  });

  final String nickname;
  final TextEditingController gardenName;
  final TextEditingController plantName;
  final bool isPublic;
  final ValueChanged<bool> onPublicChanged;
  final bool agreed;
  final ValueChanged<bool> onAgreedChanged;

  static const List<String> _plantSuggestions = ['첫 마음', '오늘', '작은 위로', '쉼'];

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
              const Text(
                '이용약관 · 개인정보 안내',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '• 로그인 없이 익명으로 시작해요. 이름·전화번호를 받지 않아요.\n'
                '• 이메일은 받지 않지만, 원할 때 Google 백업을 직접 연결하면 그 계정의 이메일이 백업 용도로만 쓰여요.\n'
                '• 기기를 구분하기 위한 임의의 기기 식별값(device ID)을 저장해요.\n'
                '• 당신이 적은 글은 당신의 정원에 저장되며, 다른 사람에게 보이지 않아요.\n'
                '• 이 앱은 의료·상담 서비스가 아니에요. 위급할 땐 안내되는 도움 전화로 연결해 주세요.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: Color(0xFF6D4C41),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => openPrivacyPolicy(ctx),
                  icon: const Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: Color(0xFF7CB342),
                  ),
                  label: const Text(
                    '브라우저에서 전문 보기',
                    style: TextStyle(color: Color(0xFF5D4037)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFE0D7C5)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
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
          const SizedBox(height: 4),
          const Text(
            '이름을 지어주세요',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '이름을 붙이면 더 애틋해져요. 비워두면 알아서 지어둘게요.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFFA1887F),
            ),
          ),
          const SizedBox(height: 22),

          // 정원 이름
          const _FieldLabel('🪴 내 정원 이름'),
          const SizedBox(height: 8),
          _NameField(
            controller: gardenName,
            hint: '예: $nickname',
            maxLength: 16,
          ),
          const SizedBox(height: 18),

          // 첫 식물 이름
          const _FieldLabel('🌱 첫 식물 이름'),
          const SizedBox(height: 8),
          _NameField(controller: plantName, hint: '예: 첫 마음', maxLength: 16),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _plantSuggestions)
                _SuggestChip(
                  label: s,
                  onTap: () {
                    plantName.text = s;
                    plantName.selection = TextSelection.collapsed(
                      offset: s.length,
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),

          // 공개 여부 — v2 소셜이 열릴 때까지 숨김 (설정의 토글과 함께 잠금).
          // 서버도 public read 정책이 닫혀 있어(마이그레이션 0011) 지금 켜두면
          // 끌 방법이 없는 상태가 되므로, 소셜 오픈 전엔 노출하지 않는다.
          if (kSocialEnabled) ...[
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
                title: const Text(
                  '정원 공개하기',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D4037),
                  ),
                ),
                subtitle: const Text(
                  '기본은 나만의 정원이에요. 나중에 다른 정원과 마음을 나누는 기능이 열릴 때 참여할지 미리 정해둘 수 있어요. (설정에서 언제든 변경)',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFFA1887F),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 약관 동의
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
                child: const Text(
                  '내용 보기',
                  style: TextStyle(fontSize: 13, color: Color(0xFF7CB342)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF5D4037),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.hint,
    required this.maxLength,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 16, color: Color(0xFF5D4037)),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        hintStyle: const TextStyle(color: Color(0xFFBCAAA4)),
        filled: true,
        fillColor: const Color(0xFFFFFDF5),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFFE0D7C5)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFFE0D7C5)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF7CB342), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

class _SuggestChip extends StatelessWidget {
  const _SuggestChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F8E9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCFE3B8)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF558B2F)),
        ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 2,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
