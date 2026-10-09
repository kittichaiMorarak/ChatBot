import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/character.dart';

/// เก็บตัวละครที่ผู้ใช้สร้างเอง (เก็บในเครื่อง ไม่ขึ้น server)
class CharacterStorage {
  static const _key = 'user_characters_v1';

  /// จำกัดจำนวนตัวละครที่ผู้ใช้สร้าง
  static const maxCharacters = 50;

  final SharedPreferences? _prefs;

  /// ใช้ตอนเทสต์หรือถ้า plugin ใช้ไม่ได้
  List<AiCharacter> _memory = [];

  CharacterStorage([this._prefs]);

  CharacterStorage.inMemory() : _prefs = null;

  static Future<CharacterStorage> create() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return CharacterStorage(prefs);
    } catch (_) {
      return CharacterStorage.inMemory();
    }
  }

  List<AiCharacter> load() {
    if (_prefs == null) return [..._memory];

    final items = _prefs.getStringList(_key) ?? [];
    if (items.isEmpty) return [];

    final result = <AiCharacter>[];

    for (final raw in items) {
      try {
        result.add(
          AiCharacter.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // ข้อมูลเสียหายข้ามไป ไม่ทำให้แอปพัง
        continue;
      }
    }

    return result;
  }

  Future<void> save(List<AiCharacter> characters) async {
    final trimmed = characters.take(maxCharacters).toList();
    final encoded = trimmed.map((c) => c.toJson()).toList();

    if (_prefs == null) {
      _memory = trimmed;
      return;
    }

    await _prefs.setStringList(_key, encoded);
  }

  /// เพิ่ม หรือแทนที่ถ้า id ซ้ำ
  Future<void> add(AiCharacter character) async {
    final list = load();

    final idx = list.indexWhere((c) => c.id == character.id);
    if (idx >= 0) {
      list[idx] = character;
    } else {
      list.insert(0, character);
    }

    await save(list);
  }

  Future<void> remove(String id) async {
    final list = load().where((c) => c.id != id).toList();
    await save(list);
  }

  Future<void> clear() async {
    _memory = [];
    await _prefs?.remove(_key);
  }
}