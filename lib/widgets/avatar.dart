import 'package:flutter/material.dart';

import '../theme.dart';

/// รูป avatar ของน้องซิม
///
/// path ชี้ไปไฟล์ใน assets/
/// ถ้าไฟล์หายจะ fallback ไปใช้อีโมจิ 🤖 แทน (ไม่ crash)
///
/// ถ้าเปลี่ยนไฟล์ใน assets ต้องรัน `flutter pub get` หรือ hot restart
class ShimAvatar extends StatelessWidget {
  final double size;

  /// ขอบสีตรงรอบ avatar
  final bool border;

  const ShimAvatar({
    super.key,
    this.size = 40,
    this.border = true,
  });

  static const _path = 'assets/images/shim_avatar.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _path,
              fit: BoxFit.cover,
              // ถ้าโหลดรูปไม่ได้ ให้ใช้อีโมจิแทน
              errorBuilder: (context, error, stack) => Center(
                child: Text(
                  '🤖',
                  style: TextStyle(fontSize: size * 0.55),
                ),
              ),
            ),

            // ขอบวางไว้บนภาพ (ไม่ใช่ clip เลย)
            if (border)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary,
                      width: size > 40 ? 2 : 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// avatar ของตัวละครทั่วไป
///
/// ถ้าตัวละครยังไม่มีรูปจริง จะแสดงอีโมจิบนพื้นสีประจำตัว
class CharacterAvatar extends StatelessWidget {
  final String emoji;
  final Color color;
  final double size;

  const CharacterAvatar({
    super.key,
    required this.emoji,
    required this.color,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(color, Colors.white, 0.55)!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: light,
        border: Border.all(color: color, width: size > 40 ? 2 : 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }
}

/// avatar ฝั่งผู้ใช้ (ไม่มีรูป ใช้ไอคอนคนแทน)
class UserAvatar extends StatelessWidget {
  final double size;

  const UserAvatar({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryLight,
        border: Border.all(
          color: AppColors.primary,
          width: size > 40 ? 2 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: size * 0.55,
        color: Colors.brown,
      ),
    );
  }
}