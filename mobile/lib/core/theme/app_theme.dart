import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // ── 브랜드 ──────────────────────────────────────
  static const primary      = Color(0xFFFF9A3C);
  static const primaryLight = Color(0xFFFFE0B2);
  static const primaryDark  = Color(0xFFE65100);

  // ── 배경 ────────────────────────────────────────
  static const background = Color(0xFFFFFAF5);
  static const surface    = Color(0xFFFFFFFF);
  static const cardWarm   = Color(0xFFFFFDF8);
  static const card       = Color(0xFFFFF3E8);

  // ── 텍스트 ──────────────────────────────────────
  static const textPrimary   = Color(0xFF3E2723);
  static const textSecondary = Color(0xFF8D6E63);
  static const textHint      = Color(0xFFBCAAA4);

  // ── 시맨틱 ──────────────────────────────────────
  static const error   = Color(0xFFE53935); // 삭제, 실종, 경고
  static const success = Color(0xFF43A047); // 완료, 입양
  static const warning = Color(0xFFFF8F00); // 주의, 입양원해요
  static const info    = Color(0xFF1E88E5); // 위치, 발견

  // ── 테두리 / 구분선 ─────────────────────────────
  static const divider    = Color(0xFFEDE8E3);
  static const brownLight = Color(0xFFD7CCC8);
  static const brown      = Color(0xFF8D6E63);

  // ── 기타 (하위 호환) ────────────────────────────
  static const green      = Color(0xFF81C784);
  static const greenLight = Color(0xFFE8F5E9);
  static const peach      = Color(0xFFFFAB91);
  static const peachLight = Color(0xFFFBE9E7);

  // ── 커뮤니티 카테고리 ───────────────────────────
  static const catLost     = error;
  static const catFound    = info;
  static const catRehome   = success;
  static const catLooking  = warning;
  static const catTip      = Color(0xFF8E24AA); // 꿀팁/정보
  static const catQuestion = Color(0xFF00897B); // 질문/고민

  static Color categoryColor(String category) {
    switch (category) {
      case 'lost':     return catLost;
      case 'found':    return catFound;
      case 'rehome':   return catRehome;
      case 'looking':  return catLooking;
      case 'tip':      return catTip;
      case 'question': return catQuestion;
      default:         return primary;
    }
  }
}

class AppSpacing {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 12.0;
  static const lg  = 16.0;  // 화면 기본 horizontal padding
  static const xl  = 24.0;  // 섹션 구분
  static const xxl = 32.0;
  static const screenH  = lg;   // 화면 좌우 padding
  static const screenBottom = 100.0;
  static const cardH = 14.0;
  static const cardV = 12.0;
}

class AppRadius {
  static const sm   = 8.0;
  static const md   = 12.0;
  static const lg   = 16.0;
  static const xl   = 20.0;
  static const pill = 24.0;
}

class AppTextStyles {
  static const headline = TextStyle(
    fontSize: 18, fontWeight: FontWeight.bold,
    color: AppColors.textPrimary, height: 1.3,
  );
  static const title = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.3,
  );
  static const subtitle = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.textSecondary, height: 1.4,
  );
  static const body = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, height: 1.6,
  );
  static const bodySmall = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary, height: 1.6,
  );
  static const caption = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary, height: 1.4,
  );
  static const chip = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w600,
    height: 1.0,
  );
}

class AppShadows {
  static const card = [
    BoxShadow(
      color: Color(0x178D6E63),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.peach,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      elevation: 8,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardWarm,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        padding: const EdgeInsets.symmetric(
            vertical: 14, horizontal: AppSpacing.xl),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(
          color: AppColors.textHint, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.brownLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.brownLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
  );
}
