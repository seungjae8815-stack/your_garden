import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/lock_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/update_required_screen.dart';
import 'services/app_lock_service.dart';
import 'services/auth_service.dart';
import 'services/garden_service.dart';
import 'services/notification_service.dart';
import 'services/secure_window.dart';
import 'services/update_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  // 알림 초기화(이미 켜둔 경우 예약 복원). 실패해도 앱 실행은 계속.
  try {
    await NotificationService.instance.init();
  } catch (_) {}
  runApp(const YourGardenApp());
}

class YourGardenApp extends StatelessWidget {
  const YourGardenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '너의 정원',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const UpdateGate(child: AppLockGate(child: BootGate())),
    );
  }
}

/// 강제/선택 업데이트 게이트 — 앱의 최상단.
/// 서버(app_config)를 확인해 현재 빌드가 최소지원 미만이면 [UpdateRequiredScreen]으로
/// 덮는다. 그 외에는 child로 통과. 확인은 최대 5초, 실패·지연 시 앱을 막지 않고
/// 통과한다(fail-open) — 오프라인에서도 앱이 열리도록.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  UpdateStatus? _status; // null = 확인 중

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final s = await UpdateService.instance.check().timeout(
      const Duration(seconds: 5),
      onTimeout: () => UpdateStatus.none,
    );
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null) {
      // 확인 중 — 짧은 스플래시(보통 1초 미만).
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }
    if (s.kind == UpdateKind.forced) {
      return UpdateRequiredScreen(status: s);
    }
    return widget.child;
  }
}

/// 앱 잠금 게이트 — 켜져 있으면 앱 시작·백그라운드 복귀 시 잠금화면을 덮는다.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _lock = AppLockService.instance;
  bool _enabled = false;
  bool? _unlocked; // null=확인 중, false=잠김, true=열림

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _check() async {
    _enabled = await _lock.isEnabled();
    // 잠금을 켠 사용자만 최근 앱 미리보기·스크린샷에서 내용을 가린다. (2-6)
    await SecureWindow.set(_enabled);
    if (!mounted) return;
    setState(() => _unlocked = !_enabled);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final en = await _lock.isEnabled(); // 설정에서 방금 켰을 수도 있음
      _enabled = en;
      await SecureWindow.set(en);
      if (en && mounted) setState(() => _unlocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_unlocked != true)
          Positioned.fill(
            child: _unlocked == null
                ? const ColoredBox(color: AppColors.cream)
                : LockScreen(
                    onUnlocked: () => setState(() => _unlocked = true),
                  ),
          ),
      ],
    );
  }
}

/// 첫 부팅 시 익명 로그인 + 프로필 자동 생성. 끝나면 HomeScreen.
class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  late final Future<_BootData> _bootFuture;

  @override
  void initState() {
    super.initState();
    _bootFuture = _boot();
  }

  Future<_BootData> _boot() async {
    final auth = AuthService(Supabase.instance.client);
    final profile = await auth.signInAndUpsertProfile();
    final onboarded = await auth.isOnboarded();
    GardenService.testFastGrowth = await auth.isTestFast();
    return _BootData(profile, onboarded);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootData>(
      future: _bootFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootSplash(message: '정원을 여는 중…');
        }
        if (snapshot.hasError) {
          return _BootSplash(
            message: '연결 실패\n${snapshot.error}',
            isError: true,
          );
        }
        final data = snapshot.data!;
        return data.onboarded
            ? MainShell(profile: data.profile)
            : OnboardingScreen(profile: data.profile);
      },
    );
  }
}

class _BootData {
  const _BootData(this.profile, this.onboarded);
  final AuthResult profile;
  final bool onboarded;
}

class _BootSplash extends StatelessWidget {
  const _BootSplash({required this.message, this.isError = false});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isError ? Colors.red.shade700 : const Color(0xFF8D6E63),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
