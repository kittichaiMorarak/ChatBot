import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/character.dart';

/// ดึงรายการตัวละครจาก backend
class CharacterApi {
  /// base URL ของ backend เช่น http://10.0.2.2:8000
  final String baseUrl;
  final http.Client _client;

  CharacterApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// แปลงจาก URL ของ chat stream เป็น base URL
  /// เช่น http://10.0.2.2:8000/chat/stream -> http://10.0.2.2:8000
  static String baseUrlFrom(String chatStreamUrl) {
    final uri = Uri.tryParse(chatStreamUrl);
    if (uri == null) return '';

    return '${uri.scheme}://${uri.authority}';
  }

  void dispose() => _client.close();

  /// โหลดตัวละครทั้งหมด
  ///
  /// ถ้าเรียกไม่สำเร็จ จะคืน [fallbackCharacter] เพื่อให้แอปยังใช้ได้
  Future<List<AiCharacter>> loadCharacters() async {
    final base = baseUrlFrom(baseUrl);
    if (base.isEmpty) return const [fallbackCharacter];

    try {
      final res = await _client
          .get(Uri.parse('$base/characters'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return const [fallbackCharacter];

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final list = data['characters'] as List<dynamic>? ?? [];

      final characters = list
          .map(
            (e) => AiCharacter.fromJson(e as Map<String, dynamic>),
          )
          .where((c) => c.id.isNotEmpty)
          .toList();

      return characters.isEmpty ? const [fallbackCharacter] : characters;
    } catch (_) {
      // backend ไม่ทำงาน — ใช้ตัวสำรองไปก่อน
      return const [fallbackCharacter];
    }
  }
}