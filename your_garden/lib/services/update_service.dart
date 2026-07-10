import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateKind { none, optional, forced }

/// 서버(app_config)와 현재 빌드번호를 비교한 결과.
class UpdateStatus {
  const UpdateStatus({
    required this.kind,
    this.latestBuild = 0,
    this.latestVersion,
    this.url = defaultStoreUrl,
    this.message,
  });

  final UpdateKind kind;
  final int latestBuild;
  final String? latestVersion;
  final String url;
  final String? message;

  static const defaultStoreUrl =
      'https://play.google.com/store/apps/details?id=com.yourgarden.app';
  static const none = UpdateStatus(kind: UpdateKind.none);
}

/// 서버(app_config)의 버전 값과 현재 빌드번호(versionCode)를 비교해
/// 강제/선택 업데이트를 판정한다.
/// 네트워크 실패·오류 시 항상 [UpdateStatus.none]으로 폴백(fail-open)해
/// 오프라인에서도 앱이 정상적으로 열리게 한다.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  final _client = Supabase.instance.client;
  final _store = const FlutterSecureStorage();
  static const _kNudgedBuild = 'update_nudged_build';

  UpdateStatus? _cached;

  /// 마지막으로 계산된 결과 (MainShell 넛지에서 재사용). 아직 없으면 null.
  UpdateStatus? get cached => _cached;

  Future<UpdateStatus> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;

      final row = await _client
          .from('app_config')
          .select(
            'min_supported_build, latest_build, latest_version, update_url, update_message',
          )
          .eq('id', 1)
          .maybeSingle();

      if (row == null) return _cache(UpdateStatus.none);

      final minBuild = (row['min_supported_build'] as int?) ?? 0;
      final latestBuild = (row['latest_build'] as int?) ?? 0;
      final version = row['latest_version'] as String?;
      final rawUrl = (row['update_url'] as String?)?.trim();
      final rawMsg = (row['update_message'] as String?)?.trim();
      final storeUrl = (rawUrl == null || rawUrl.isEmpty)
          ? UpdateStatus.defaultStoreUrl
          : rawUrl;
      final message = (rawMsg == null || rawMsg.isEmpty) ? null : rawMsg;

      if (current < minBuild) {
        return _cache(
          UpdateStatus(
            kind: UpdateKind.forced,
            latestBuild: latestBuild,
            latestVersion: version,
            url: storeUrl,
            message: message,
          ),
        );
      }
      if (current < latestBuild) {
        return _cache(
          UpdateStatus(
            kind: UpdateKind.optional,
            latestBuild: latestBuild,
            latestVersion: version,
            url: storeUrl,
          ),
        );
      }
      return _cache(UpdateStatus.none);
    } catch (_) {
      // 오프라인·오류 → 앱을 막지 않는다(fail-open).
      return _cache(UpdateStatus.none);
    }
  }

  UpdateStatus _cache(UpdateStatus s) {
    _cached = s;
    return s;
  }

  /// 이 빌드에 대한 선택 넛지를 이미 띄웠는지.
  Future<bool> alreadyNudged(int build) async {
    final seen = int.tryParse(await _store.read(key: _kNudgedBuild) ?? '') ?? 0;
    return seen >= build;
  }

  Future<void> markNudged(int build) async {
    try {
      await _store.write(key: _kNudgedBuild, value: '$build');
    } catch (_) {}
  }
}

/// 스토어(또는 지정 URL)를 외부 브라우저/Play 앱으로 연다.
Future<void> openStore(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    // 실패해도 조용히 무시 — 강제 화면은 그대로 유지되어 재시도 가능.
  }
}
