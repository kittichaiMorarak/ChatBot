import 'package:flutter/material.dart';

import '../models/character.dart';
import '../theme.dart';

/// หน้าโปรไฟล์ตัวละคร
class CharacterProfilePage extends StatelessWidget {
  final AiCharacter character;
  final bool isCurrent;
  final VoidCallback onStartChat;

  const CharacterProfilePage({
    super.key,
    required this.character,
    required this.onStartChat,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(character.colorValue);

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ---------- ภาพปก ----------
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: color,
                foregroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                // ปุ่มด้านบนอยู่บนสีเข้ม ต้องมีเงาให้เห็นชัด
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black26,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    // ยังไม่มีรูปจริง ใช้สี + อีโมจิแทน
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color,
                          Color.lerp(color, Colors.black, 0.35)!,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Text(
                          character.emoji,
                          style: const TextStyle(fontSize: 96),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ---------- เนื้อหา ----------
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  transform: Matrix4.translationValues(0, -20, 0),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ชื่อ
                      Text(
                        character.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // ผู้สร้าง
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 15,
                            color: AppColors.textSub,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ผู้สร้าง ${character.creator}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSub,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // คำคม
                      if (character.quote.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            character.quote,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // แท็ก
                      if (character.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in character.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.divider,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMain,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // สถิติ
                      _StatsRow(stats: character.stats),
                      const SizedBox(height: 28),

                      // หัวข้อ + คำอธิบาย
                      const Text(
                        'ข้อมูลตัวละคร',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        character.description,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.65,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // หมายเหตุ: persona ยังว่าง
                      if (!character.hasPersona)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border,
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: AppColors.textMain,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'ตัวละครนี้ยังไม่ได้ตั้งค่าบุคลิก '
                                  'จะใช้บุคลิกของน้องซิมไปก่อน',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: AppColors.textMain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ---------- ปุ่มเริ่มแชท ----------
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.brown,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: onStartChat,
                    icon: Icon(
                      isCurrent ? Icons.chat : Icons.chat_bubble_outline,
                      color: Colors.brown,
                    ),
                    label: Text(
                      isCurrent ? 'กลับไปคุยต่อ' : 'เริ่มแชท',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// แถวสถิติ 4 ช่อง
class _StatsRow extends StatelessWidget {
  final CharacterStats stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _stat('โลก', stats.worlds),
          _divider(),
          _stat('แชท', stats.chats),
          _divider(),
          _stat('ข้อความ', stats.messages),
          _divider(),
          _stat('ของขวัญ', stats.gifts),
        ],
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 32, color: AppColors.divider);
  }
}