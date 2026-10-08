import 'dart:convert';

/// ข้อความหนึ่งข้อความในแชท
class Message {
  final String text;
  final bool isUser;

  const Message({required this.text, required this.isUser});

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
      };

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
    );
  }
}

/// หนึ่งบทสนทนา (เก็บในเมนูข้าง)
class Conversation {
  final String id;
  final String title;

  /// id ของตัวละครที่คุยด้วย (null = น้องซิม)
  final String? characterId;

  /// เวลาที่แก้ไขล่าสุด
  final DateTime updatedAt;
  final List<Message> messages;

  const Conversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
    this.characterId,
  });

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    List<Message>? messages,
    String? characterId,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      characterId: characterId ?? this.characterId,
    );
  }

  bool get isEmpty => messages.isEmpty;

  /// แชทนี้เป็นของน้องซิมไหม (มีข้อความจาก AI)
  ///
  /// ใช้แสดง avatar ข้างรายการในเมนู
  bool get isFromSim =>
      messages.any((m) => !m.isUser && m.text.trim().isNotEmpty);

  /// ข้อความแรกที่ผู้ใช้พิมพ์ ใช้เป็นชื่อแชท
  String get preview {
    for (final m in messages) {
      if (m.isUser && m.text.trim().isNotEmpty) {
        return m.text.trim();
      }
    }
    return 'แชทใหม่';
  }

  /// ตัดข้อความยาวๆ ให้พอดีกับชื่อในเมนู
  String get displayTitle {
    final raw = title.trim();
    if (raw.isEmpty) return preview;
    if (raw.length <= 30) return raw;
    return '${raw.substring(0, 30)}...';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'characterId': characterId,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch
          .toString(),
      title: json['title'] as String? ?? '',
      characterId: json['characterId'] as String?,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
              DateTime.now(),
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map(
            (m) => Message.fromJson(m as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  @override
  String toString() => 'Conversation($id, "$title", '
      '${messages.length} msgs)';
}

/// ช่วยแปลงรายการ conversation เป็น JSON string
String encodeConversations(List<Conversation> list) {
  return jsonEncode(
    list.map((c) => c.toJson()).toList(),
  );
}

List<Conversation> decodeConversations(String raw) {
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map(
          (c) => Conversation.fromJson(c as Map<String, dynamic>),
        )
        .toList();
  } catch (_) {
    // ข้อมูลเสียหาย ไม่ทำให้แอปพัง
    return [];
  }
}