import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 코지 어스톤 팔레트.
class AppColors {
  static const cream = Color(0xFFFFF8E1); // 기본 배경 (위)
  static const creamDeep = Color(0xFFF4E9C8); // 배경 아래쪽 (그라데이션)
  static const card = Color(0xFFFFFDF5);
  static const border = Color(0xFFE6DCC6);
  static const ink = Color(0xFF5D4037); // 본문 텍스트
  static const sub = Color(0xFF8D6E63);
  static const faint = Color(0xFFA1887F);
  static const green = Color(0xFF7CB342);
  static const greenDark = Color(0xFF689F38);
  static const leaf = Color(0xFF9CCC65);
  static const soilShadow = Color(0x14000000);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.cream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
    ).copyWith(surface: AppColors.cream),
  );

  return base.copyWith(
    textTheme: GoogleFonts.gowunDodumTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.sub,
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      backgroundColor: AppColors.ink,
      contentTextStyle: GoogleFonts.gowunDodum(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
