import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_service.dart';
import 'services/garden_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
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
      home: const BootGate(),
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
