import 'package:flutter/services.dart';

/// 최근 앱 미리보기·스크린샷에서 화면 내용을 가리는 Android FLAG_SECURE 토글.
/// 앱 잠금을 켠 사용자에게만 적용한다 — 잠금이 꺼진 사용자는 정원 화면 녹화·공유가
/// 자유로워야 하므로(콘텐츠 제작·바이럴), 무조건 켜지 않고 잠금 상태에 연동한다. (2-6)
class SecureWindow {
  const SecureWindow._();

  static const _ch = MethodChannel('yourgarden/secure');

  static Future<void> set(bool secure) async {
    try {
      await _ch.invokeMethod('setSecure', secure);
    } catch (_) {
      // iOS·미지원 환경은 조용히 무시.
    }
  }
}
