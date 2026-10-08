import 'package:flutter/material.dart';

/// สีของแอป — ยึดจากธีมเดิมของน้องซิม
class AppColors {
  AppColors._();

  /// เหลืองหลัก (ปุ่มส่ง, accent)
  static const primary = Color(0xFFFFC107);

  /// เหลืองอ่อน (AppBar)
  static const primaryLight = Color(0xFFFFD54F);

  /// เหลืองจาง (พื้นหลังแชท, ตัวเลือก)
  static const surface = Color(0xFFFFF8E7);

  /// เหลืองจางมาก (bubble ของ AI)
  static const bubbleAi = Color(0xFFFFFFFF);

  /// เหลืองเข้ม (ขอบบาง ๆ)
  static const border = Color(0xFFFFE8A3);

  /// พื้นหลังเมนูข้าง
  static const drawerBg = Color(0xFFFFFBF0);

  /// สีข้อความหลัก
  static const textMain = Color(0xFF3E3428);

  /// สีข้อความรอง
  static const textSub = Color(0xFF8D7B68);

  /// สีเส้นคั่ว
  static const divider = Color(0xFFEFE3CC);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.surface,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryLight,
      elevation: 0,
    ),
    dividerColor: AppColors.divider,
  );
}