import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// RepaintBoundary(key)로 감싼 위젯을 PNG로 캡처한다.
Future<Uint8List?> captureBoundary(
  GlobalKey key, {
  double pixelRatio = 2.5,
}) async {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

/// 캡처한 PNG를 임시 파일로 저장해 공유 시트로 내보낸다.
Future<void> shareBytes(
  Uint8List bytes, {
  String text = '너의 정원 🌿 #너의정원',
}) async {
  final dir = await getTemporaryDirectory();
  final path =
      '${dir.path}/garden_${DateTime.now().millisecondsSinceEpoch}.png';
  final file = await File(path).writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], text: text);
}
