import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show BootGate;
import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import '../services/garden_service.dart';
import '../services/notification_service.dart';
import '../services/secure_window.dart';
import '../theme.dart';
import '../widgets/plant_painter.dart';
import 'lock_screen.dart';

const _privacyUrl = 'https://seungjae8815-stack.github.io/yourgarden-policy/';

/// v2 소셜(공개 정원)이 열리기 전까지 공개 기능을 잠근다.
/// true로 바꾸면 '정원 공개' 토글이 다시 나타난다.
/// (그때 서버측 public read 정책도 함께 복구해야 함 — 마이그레이션 0011 참고)
const bool kSocialEnabled = false;

/// 개인정보처리방침·이용약관 페이지를 기본 브라우저로 연다.
/// 브라우저를 열 수 없으면 주소를 클립보드에 복사하는 것으로 폴백한다.
/// (설정·온보딩 공용)
Future<void> openPrivacyPolicy(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final ok = await launchUrl(
      Uri.parse(_privacyUrl),
      mode: LaunchMode.externalApplication,
    );
    if (ok) return;
  } catch (_) {
    // 아래 폴백으로 처리
  }
  await Clipboard.setData(const ClipboardData(text: _privacyUrl));
  messenger.showSnackBar(
    const SnackBar(content: Text('브라우저를 열 수 없어 주소를 복사했어요.')),
  );
}

/// 복구 코드 입력 다이얼로그 (설정·온보딩 공용). 입력값(미정리)을 돌려준다.
Future<String?> promptRecoveryCode(BuildContext context) async {
  final ctrl = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: const Text('복구 코드 입력'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontSize: 18, letterSpacing: 2),
          decoration: const InputDecoration(
            hintText: 'XXXX-XXXX-XXXX',
            helperText: '다른 기기의 설정에서 만든 복구 코드예요.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('복구'),
          ),
        ],
      ),
    );
  } finally {
    ctrl.dispose();
  }
}

/// 만들어진 복구 코드를 안내하는 다이얼로그 (설정·백업 넛지 공용).
Future<void> showBackupCodeDialog(BuildContext context, String code) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cream,
      title: const Text('복구 코드 🔑'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이 코드를 안전한 곳에 적어 두세요. '
            '기기를 바꾸거나 앱을 다시 설치할 때 이 코드로 정원을 되찾아요.',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '⚠ 이 코드를 잃어버리면 정원을 되찾을 수 없어요.',
            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('복구 코드를 복사했어요.')));
          },
          child: const Text('복사'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('저장했어요'),
        ),
      ],
    ),
  );
}

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

  final _notif = NotificationService.instance;
  bool _notifOn = false;
  TimeOfDay _notifTime = const TimeOfDay(hour: 21, minute: 0);

  final _lock = AppLockService.instance;
  bool _lockOn = false;
  bool _bioOn = false;
  bool _bioAvailable = false;

  late final AuthService _auth = AuthService(Supabase.instance.client);
  bool _googleLinked = false;
  bool _hasBackupCode = false;
  bool _pendingRecover = false;
  String _version = '';
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadNotif();
    _loadLock();
    _loadBackup();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = info.version);
    } catch (_) {
      // 표기 실패 시 앱 이름만 노출.
    }
  }

  Future<void> _loadBackup() async {
    final hasCode = await _auth.isBackedUp();
    if (!mounted) return;
    setState(() {
      _googleLinked = _auth.isGoogleLinked;
      _hasBackupCode = hasCode;
    });
    // Google 연결/로그인 완료(브라우저 복귀)를 감지.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (!mounted) return;
      setState(() => _googleLinked = _auth.isGoogleLinked);
      if (s.event == AuthChangeEvent.signedIn && _pendingRecover) {
        _pendingRecover = false;
        _showRestartDialog();
      } else if (s.event == AuthChangeEvent.userUpdated && _googleLinked) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Google 계정으로 백업됐어요 🌿')));
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _linkGoogle() async {
    try {
      await _auth.linkGoogle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google 연결을 시작하지 못했어요: $e')));
    }
  }

  Future<void> _recoverGoogle() async {
    // 이 기기에 이미 기록이 있으면, 다른 계정으로 복구 시 이 기기의 기록은
    // 되찾은 정원과 합쳐지지 않고 남겨진다 — 미리 경고하고 동의를 받는다.
    final hasData = await _garden.hasAnyData(widget.profile.uid);
    if (!mounted) return;
    if (hasData) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cream,
          title: const Text('이 기기의 기록은 어떻게 되나요?'),
          content: const Text(
            '지금 이 기기에 쓴 기록은 되찾는 정원과 합쳐지지 않아요. '
            '다른 정원을 되찾으면 이 기기에서 쓰던 정원은 더 이상 보이지 않아요.\n\n'
            '이 기기의 정원을 지키려면 먼저 백업해 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('그래도 복구'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    _pendingRecover = true;
    try {
      await _auth.signInGoogle();
    } catch (e) {
      _pendingRecover = false;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google 복구를 시작하지 못했어요: $e')));
    }
  }

  /// 익명 복구 코드 만들기(또는 보기) — Google 없이도 정원을 지키는 길.
  Future<void> _showBackupCode() async {
    setState(() => _busy = true);
    String code;
    try {
      code = await _auth.createBackup();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('복구 코드를 만들지 못했어요: $e')));
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _hasBackupCode = true;
    });
    await showBackupCodeDialog(context, code);
  }

  /// 복구 코드로 되찾기 — 다른 기기에서 만든 코드를 입력해 정원을 이 계정으로 가져온다.
  Future<void> _recoverWithCode() async {
    final code = await promptRecoveryCode(context);
    if (code == null || code.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await _auth.recoverWithCode(code);
      if (!mounted) return;
      setState(() => _busy = false);
      _showRestartDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _showRestartDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: const Text('복구됐어요 🌿'),
        content: const Text('앱을 완전히 종료한 뒤 다시 열면\n되찾은 정원이 나타나요.'),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadLock() async {
    final on = await _lock.isEnabled();
    final bio = await _lock.biometricEnabled();
    final avail = await _lock.canUseBiometric();
    if (!mounted) return;
    setState(() {
      _lockOn = on;
      _bioOn = bio;
      _bioAvailable = avail;
    });
  }

  Future<void> _toggleLock(bool v) async {
    if (v) {
      final pin = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      if (pin == null) return; // 취소
      await _lock.setPin(pin);
      await SecureWindow.set(true); // 잠금 켜면 화면 캡처 가림 (2-6)
      if (!mounted) return;
      setState(() => _lockOn = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('앱 잠금을 켰어요.')));
    } else {
      await _lock.disable();
      await SecureWindow.set(false); // 잠금 끄면 캡처 가림 해제 (녹화·공유 허용)
      if (!mounted) return;
      setState(() {
        _lockOn = false;
        _bioOn = false;
      });
    }
  }

  Future<void> _changePin() async {
    final pin = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (pin == null || !mounted) return;
    await _lock.setPin(pin);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('비밀번호를 바꿨어요.')));
  }

  Future<void> _toggleBio(bool v) async {
    await _lock.setBiometric(v);
    if (!mounted) return;
    setState(() => _bioOn = v);
  }

  Future<void> _loadNotif() async {
    final on = await _notif.isEnabled();
    final h = await _notif.hour();
    final m = await _notif.minute();
    if (!mounted) return;
    setState(() {
      _notifOn = on;
      _notifTime = TimeOfDay(hour: h, minute: m);
    });
  }

  Future<void> _toggleNotif(bool v) async {
    if (v) {
      final ok = await _notif.enable(_notifTime.hour, _notifTime.minute);
      if (!mounted) return;
      if (ok) {
        setState(() => _notifOn = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 권한이 필요해요. 설정에서 알림을 허용해 주세요.')),
        );
      }
    } else {
      await _notif.disable();
      if (!mounted) return;
      setState(() => _notifOn = false);
    }
  }

  Future<void> _pickNotifTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifTime,
    );
    if (picked == null) return;
    setState(() => _notifTime = picked);
    await _notif.updateTime(picked.hour, picked.minute);
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hour;
    final ampm = h < 12 ? '오전' : '오후';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$ampm $h12:${t.minute.toString().padLeft(2, '0')}';
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('현재 식물을 ${speciesLabel(s)}(으)로 바꿨어요. 정원 탭에서 확인!'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('바꾸지 못했어요.')));
    }
  }

  // 테스트: 현재 키우는 식물을 고른 종으로 바꾸기 (꽃/나무 공용).
  Future<void> _pickSpecies(List<String> list, String title) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '현재 키우는 식물을 고른 종으로 바꿔요.',
                style: TextStyle(fontSize: 13, color: AppColors.faint),
              ),
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
                                species: sp,
                                stage: 5,
                                inPot: false,
                              ),
                            ),
                            Text(
                              speciesLabel(sp),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.sub,
                              ),
                            ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('변경하지 못했어요.')));
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: const Text('내 정원을 완전히 삭제할까요?'),
        content: const Text(
          '지금까지 묻은 마음·키운 식물과 계정 정보가 서버에서 모두 지워져요.\n'
          '백업·복구로도 되돌릴 수 없어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('완전 삭제', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      // 서버 데이터·인증 계정·로컬 상태를 모두 삭제 (Play 계정삭제 요건).
      await _auth.deleteAccount();
      // 남아있던 매일 알림 예약도 정리.
      try {
        await NotificationService.instance.disable();
      } catch (_) {}
      if (!mounted) return;
      // 새 익명 계정으로 처음부터 다시 시작 (온보딩부터).
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BootGate()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제하지 못했어요.')));
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
            child: const Text('취소'),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초기화됐어요. 앱을 완전히 종료한 뒤 다시 열어주세요.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('초기화하지 못했어요.')));
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
          _card([_row('내 정원 이름', widget.profile.displayGardenName)]),
          // '정원 공개' 토글은 v2 소셜(공개 정원)이 열릴 때까지 숨김 — 그전까지
          // 공개 읽기 경로를 닫아 일기 노출을 막는다 (마이그레이션 0011 + kSocialEnabled).
          if (kSocialEnabled) ...[
            const SizedBox(height: 14),
            _card([
              SwitchListTile(
                value: _isPublic,
                onChanged: _busy ? null : _togglePublic,
                activeThumbColor: AppColors.green,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '정원 공개',
                  style: TextStyle(fontSize: 15, color: AppColors.ink),
                ),
                subtitle: const Text(
                  '다른 정원과 마음을 나누는 기능이 열릴 때 참여해요.',
                  style: TextStyle(fontSize: 12, color: AppColors.faint),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 14),
          _card([
            SwitchListTile(
              value: _notifOn,
              onChanged: _busy ? null : _toggleNotif,
              activeThumbColor: AppColors.green,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '매일 마음 묻기 알림',
                style: TextStyle(fontSize: 15, color: AppColors.ink),
              ),
              subtitle: const Text(
                '하루 한 번, 부드럽게 초대해요. 안 와도 괜찮아요.',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: _notifOn,
              leading: const Icon(Icons.schedule, color: AppColors.sub),
              title: const Text(
                '알림 시간',
                style: TextStyle(fontSize: 15, color: AppColors.ink),
              ),
              trailing: Text(
                _fmtTime(_notifTime),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.sub,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: _notifOn ? _pickNotifTime : null,
            ),
          ]),
          const SizedBox(height: 14),
          _card([
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shield_outlined, color: AppColors.sub),
              title: const Text(
                '개인정보처리방침 · 이용약관',
                style: TextStyle(fontSize: 15, color: AppColors.ink),
              ),
              subtitle: const Text(
                '탭하면 브라우저에서 열려요',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
              trailing: const Icon(
                Icons.open_in_new,
                size: 18,
                color: AppColors.faint,
              ),
              onTap: () => openPrivacyPolicy(context),
            ),
          ]),
          const SizedBox(height: 14),
          _card([
            // Google 계정 백업 (권장)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.account_circle_outlined,
                color: _googleLinked ? AppColors.green : AppColors.sub,
              ),
              title: Text(
                _googleLinked ? 'Google 계정으로 백업됨 ✓' : 'Google로 백업',
                style: const TextStyle(fontSize: 15, color: AppColors.ink),
              ),
              subtitle: Text(
                _googleLinked
                    ? '기기를 바꿔도 Google로 정원을 지켜요'
                    : 'Google 계정에 연결해 정원을 안전하게',
                style: const TextStyle(fontSize: 12, color: AppColors.faint),
              ),
              onTap: (_busy || _googleLinked) ? null : _linkGoogle,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restore, color: AppColors.sub),
              title: const Text(
                'Google로 복구',
                style: TextStyle(fontSize: 15, color: AppColors.ink),
              ),
              subtitle: const Text(
                '다른 기기에서 Google 로그인으로 되찾기',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
              onTap: _busy ? null : _recoverGoogle,
            ),
            const Divider(height: 1, color: AppColors.border),
            // 익명 복구 코드 (Google 없이 정원 지키기)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.vpn_key_outlined,
                color: _hasBackupCode ? AppColors.green : AppColors.sub,
              ),
              title: Text(
                _hasBackupCode ? '복구 코드 보기' : '복구 코드 만들기',
                style: const TextStyle(fontSize: 15, color: AppColors.ink),
              ),
              subtitle: const Text(
                'Google 없이 익명으로 정원을 지켜요',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
              onTap: _busy ? null : _showBackupCode,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.password_outlined,
                color: AppColors.sub,
              ),
              title: const Text(
                '복구 코드로 복구',
                style: TextStyle(fontSize: 15, color: AppColors.ink),
              ),
              subtitle: const Text(
                '다른 기기에서 만든 코드로 되찾기',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
              onTap: _busy ? null : _recoverWithCode,
            ),
          ]),
          const SizedBox(height: 14),
          _card([
            SwitchListTile(
              value: _lockOn,
              onChanged: _busy ? null : _toggleLock,
              activeThumbColor: AppColors.green,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '앱 잠금',
                style: TextStyle(fontSize: 15, color: AppColors.ink),
              ),
              subtitle: const Text(
                '앱을 열 때 비밀번호로 나만 볼 수 있게 해요.',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
            ),
            if (_lockOn) ...[
              if (_bioAvailable)
                SwitchListTile(
                  value: _bioOn,
                  onChanged: _toggleBio,
                  activeThumbColor: AppColors.green,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.fingerprint,
                    color: AppColors.sub,
                  ),
                  title: const Text(
                    '생체인증 사용',
                    style: TextStyle(fontSize: 15, color: AppColors.ink),
                  ),
                  subtitle: const Text(
                    '지문·얼굴로 빠르게 열어요.',
                    style: TextStyle(fontSize: 12, color: AppColors.faint),
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.password, color: AppColors.sub),
                title: const Text(
                  '비밀번호 변경',
                  style: TextStyle(fontSize: 15, color: AppColors.ink),
                ),
                onTap: _changePin,
              ),
            ],
          ]),
          const SizedBox(height: 14),
          _card([
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
              title: Text(
                '내 정원 데이터 삭제',
                style: TextStyle(fontSize: 15, color: Colors.red.shade700),
              ),
              onTap: _busy ? null : _confirmDelete,
            ),
          ]),
          // 테스트 전용 도구 — 릴리스 빌드에선 통째로 숨김 (심사·신뢰).
          if (kDebugMode) ...[
            const SizedBox(height: 14),
            _card([
              SwitchListTile(
                value: _testFast,
                onChanged: _toggleTest,
                activeThumbColor: AppColors.green,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '테스트 모드',
                  style: TextStyle(fontSize: 15, color: AppColors.ink),
                ),
                subtitle: const Text(
                  '켜면 쓸 때마다 한 단계씩 성장 (확인용). 확대 화면에 +1 버튼도 생겨요.',
                  style: TextStyle(fontSize: 12, color: AppColors.faint),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.local_florist_outlined,
                  color: AppColors.sub,
                ),
                title: const Text(
                  '테스트: 꽃 종류 고르기',
                  style: TextStyle(fontSize: 15, color: AppColors.ink),
                ),
                subtitle: const Text(
                  '코스모스·튤립·해바라기·장미·수선화',
                  style: TextStyle(fontSize: 12, color: AppColors.faint),
                ),
                onTap: () => _pickSpecies(kFlowerSpecies, '테스트: 꽃 종류 고르기'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.park_outlined, color: AppColors.sub),
                title: const Text(
                  '테스트: 나무 종류 고르기',
                  style: TextStyle(fontSize: 15, color: AppColors.ink),
                ),
                subtitle: const Text(
                  '벚나무·단풍나무·소나무·은행나무·감나무',
                  style: TextStyle(fontSize: 12, color: AppColors.faint),
                ),
                onTap: () => _pickSpecies(kTreeSpecies, '테스트: 나무 종류 고르기'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.restart_alt, color: Colors.red.shade400),
                title: Text(
                  '전체 초기화 (테스트)',
                  style: TextStyle(fontSize: 15, color: Colors.red.shade700),
                ),
                subtitle: const Text(
                  '식물·기록·온보딩 모두 삭제',
                  style: TextStyle(fontSize: 12, color: AppColors.faint),
                ),
                onTap: _busy ? null : _resetAll,
              ),
            ]),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
              _version.isEmpty ? '너의 정원' : '너의 정원 · 버전 $_version',
              style: const TextStyle(fontSize: 12, color: AppColors.faint),
            ),
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
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.sub)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
