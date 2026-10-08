import 'package:shared_preferences/shared_preferences.dart';

import '../models/message.dart';

/// เก็บรายการบทสนทนาไว้ในเครื่อง
///
/// เก็บเป็น JSON string ใน SharedPreferences แบบง่าย
/// เหมาะกับข้อมูลไม่กี่ร้อยแชท ถ้ามากกว่านั้นควรใช้ SQLite
class ChatStorage {
  static const _key = 'conversations_v1';

  /// จำกัดจำนวนแชทที่เก็บไว้ (เก่าที่สุดจะถูกลบ)
  static const maxConversations = 50;

  final SharedPreferences? _prefs;

  /// เก็บใน memory ใช้ตอนเทสต์หรือถ้า SharedPreferences ใช้ไม่ได้
  String? _memory;

  ChatStorage([this._prefs]);

  ChatStorage.inMemory() : _prefs = null;

  static Future<ChatStorage> create() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ChatStorage(prefs);
    } catch (_) {
      // เผื่อ plugin ไม่พร้อม (เช่นเทสต์) ใช้ memory แทน
      return ChatStorage.inMemory();
    }
  }

  List<Conversation> load() {
    final raw = _prefs?.getString(_key) ?? _memory;
    if (raw == null || raw.isEmpty) return [];
    return decodeConversations(raw);
  }

  Future<void> save(List<Conversation> conversations) async {
    // เก็บใหม่สุดก่อน แล้วตัดที่เกิน
    final sorted = [...conversations]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final trimmed = sorted.take(maxConversations).toList();
    final encoded = encodeConversations(trimmed);

    if (_prefs == null) {
      _memory = encoded;
      return;
    }

    await _prefs.setString(_key, encoded);
  }

  Future<void> clear() async {
    _memory = null;
    await _prefs?.remove(_key);
  }
}