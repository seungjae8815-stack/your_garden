import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 매일 "마음 묻기" 초대 알림. 부드러운 톤, 강요 X.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _store = const FlutterSecureStorage();
  bool _ready = false;

  static const _kEnabled = 'notif_enabled';
  static const _kHour = 'notif_hour';
  static const _kMin = 'notif_min';
  static const _channelId = 'daily_checkin';

  // 기본 시각 21:00.
  Future<bool> isEnabled() async =>
      (await _store.read(key: _kEnabled)) == 'true';
  Future<int> hour() async =>
      int.tryParse(await _store.read(key: _kHour) ?? '') ?? 21;
  Future<int> minute() async =>
      int.tryParse(await _store.read(key: _kMin) ?? '') ?? 0;

  Future<void> _ensureInit() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    _ready = true;
  }

  /// 부팅 시 호출 — 켜져 있으면 예약을 다시 건다.
  Future<void> init() async {
    await _ensureInit();
    if (await isEnabled()) {
      await _schedule(await hour(), await minute());
    }
  }

  /// 권한 요청 + 예약. 성공하면 true.
  Future<bool> enable(int h, int m) async {
    await _ensureInit();
    final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        true;
    if (granted != true) return false;
    await _store.write(key: _kEnabled, value: 'true');
    await _store.write(key: _kHour, value: '$h');
    await _store.write(key: _kMin, value: '$m');
    await _schedule(h, m);
    return true;
  }

  Future<void> disable() async {
    await _ensureInit();
    await _store.write(key: _kEnabled, value: 'false');
    await _plugin.cancelAll();
  }

  /// 시간만 변경 (이미 켜져 있을 때).
  Future<void> updateTime(int h, int m) async {
    await _store.write(key: _kHour, value: '$h');
    await _store.write(key: _kMin, value: '$m');
    if (await isEnabled()) await _schedule(h, m);
  }

  Future<void> _schedule(int h, int m) async {
    await _plugin.cancelAll();
    await _plugin.zonedSchedule(
      0,
      '너의 정원 🌱',
      '오늘의 마음을 묻어볼까요?',
      _next(h, m),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          '매일 마음 묻기',
          channelDescription: '하루 한 번, 마음을 묻도록 부드럽게 초대해요.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 같은 시각
    );
  }

  tz.TZDateTime _next(int h, int m) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }
}
