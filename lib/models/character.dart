import 'dart:convert';

/// ตัวละคร AI ที่เลือกคุยได้
class AiCharacter {
  final String id;
  final String name;
  final String tagline;

  /// อีโมจิใช้แทนรูป (ชั่วคราว ยังไม่มีรูปจริง)
  final String emoji;

  /// สีประจำตัวละคร ใช้เป็นสีพื้นหลังการ์ด
  final int colorValue;

  final String creator;
  final String quote;
  final String description;
  final List<String> tags;
  final CharacterStats stats;

  /// ข้อความต้อนรับ (ยังไม่ได้ใช้)
  final String? greeting;

  /// system prompt ของตัวละคร (ยังว่าง = ใช้ของน้องซิม)
  final String persona;

  const AiCharacter({
    required this.id,
    required this.name,
    required this.tagline,
    required this.emoji,
    required this.colorValue,
    required this.creator,
    required this.quote,
    required this.description,
    required this.tags,
    required this.stats,
    this.greeting,
    this.persona = '',
  });

  /// ชื่อย่อสำหรับ AppBar
  String get shortName {
    // ตัดส่วนในวงเล็บ [] ออก เช่น "ปาร์ค มูจิน | [Park Moojin]"
    final bar = name.split('|').first.trim();
    return bar.isEmpty ? name : bar;
  }

  bool get hasPersona => persona.trim().isNotEmpty;

  /// ตรวจว่า int สีมี alpha เป็น FF หรือยัง
  ///
  /// Flutter อ่าน byte สูงสุดเป็น alpha ถ้าได้ 0x00xxxxxx จะโปร่งใส
  /// เช่น int("FFC107", 16) = 0x00FFC107 -> alpha = 0 -> มองไม่เห็น
  static int _withAlpha(int value) {
    const defaultColor = 0xFFFFC107;

    if (value <= 0 || value > 0xFFFFFFFF) return defaultColor;

    // alpha = 0 -> ถือว่าไม่ได้ใส่ alpha มา
    if ((value >> 24) == 0) return value | 0xFF000000;

    return value;
  }

  factory AiCharacter.fromJson(Map<String, dynamic> json) {
    final stats = (json['stats'] as Map<String, dynamic>? ?? {});

    return AiCharacter(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'ไม่ทราบชื่อ',
      tagline: json['tagline'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🤖',
      // ถ้าสีผิดหรือไม่มี alpha ใช้สีเหลืองแบรนด์แทน
      colorValue: _withAlpha((json['colorValue'] as int?) ?? 0),
      creator: json['creator'] as String? ?? '',
      quote: json['quote'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      stats: CharacterStats(
        worlds: _toInt(stats['worlds']),
        chats: _toInt(stats['chats']),
        messages: _toInt(stats['messages']),
        gifts: _toInt(stats['gifts']),
      ),
      greeting: json['greeting'] as String?,
      persona: json['persona'] as String? ?? '',
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  /// ใช้ตอนโหลดจาก cache (ยังไม่ได้ใช้ แต่เผื่อไว้)
  String toJson() => jsonEncode({
        'id': id,
        'name': name,
        'tagline': tagline,
        'emoji': emoji,
        'colorValue': colorValue,
        'creator': creator,
        'quote': quote,
        'description': description,
        'tags': tags,
        'greeting': greeting,
        'persona': persona,
      });
}

class CharacterStats {
  final int worlds;
  final int chats;
  final int messages;
  final int gifts;

  const CharacterStats({
    required this.worlds,
    required this.chats,
    required this.messages,
    required this.gifts,
  });
}

/// ตัวละครสำรอง ใช้เมื่อ backend ใช้ไม่ได้
const fallbackCharacter = AiCharacter(
  id: 'nongsim',
  name: 'น้องซิม',
  tagline: 'เพื่อนคุยสุดกวน • ออนไลน์',
  emoji: '🤖',
  colorValue: 0xFFFFC107,
  creator: 'ทีมพัฒนา',
  quote: 'หวัดดีค้าบบบ 😆 มาคุยกันเถอะ',
  description: 'น้องซิมเป็น AI เพื่อนคุยภาษาไทย ตอบเป็นกันเอง กวน ๆ เหมือนเพื่อนสนิท',
  tags: ['เพื่อนคุย', 'ภาษาไทย', 'ตลก'],
  stats: CharacterStats(worlds: 0, chats: 0, messages: 0, gifts: 0),
);