import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:simsimi_chatbot/models/character.dart';
import 'package:simsimi_chatbot/services/character_api.dart';

/// client ที่คืน JSON ตามที่กำหนด
class _StubClient extends http.BaseClient {
  final String body;
  final int status;

  _StubClient(this.body, {this.status = 200});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
    );
  }
}

void main() {
  group('AiCharacter.fromJson', () {
    test('อ่านข้อมูลครบทุกช่อง', () {
      final c = AiCharacter.fromJson({
        'id': 'shim',
        'name': 'ปาร์ค มูจิน | [Park Moojin]',
        'tagline': 'เอ๊ะ!',
        'emoji': '🩹',
        'colorValue': 0xFF37474F,
        'creator': '@Park_Jin',
        'quote': '"เอ๊ะ!"',
        'description': 'นักศึกษาแพทย์',
        'tags': ['รงเยียว', 'ชาย'],
        'stats': {
          'worlds': 1,
          'chats': 4,
          'messages': 18,
          'gifts': 0,
        },
        'persona': '',
      });

      expect(c.id, 'shim');
      expect(c.name, 'ปาร์ค มูจิน | [Park Moojin]');
      expect(c.emoji, '🩹');
      expect(c.colorValue, 0xFF37474F);
      expect(c.creator, '@Park_Jin');
      expect(c.tags, ['รงเยียว', 'ชาย']);
      expect(c.stats.chats, 4);
      expect(c.stats.messages, 18);
      expect(c.hasPersona, isFalse);
    });

    test('shortName ตัดส่วนในวงเล็บออก', () {
      final c = AiCharacter.fromJson({
        'id': 'a',
        'name': 'ปาร์ค มูจิน | [Park Moojin]',
      });

      expect(c.shortName, 'ปาร์ค มูจิน');
    });

    test('shortName ใช้ชื่อเต็มถ้าไม่มี |', () {
      final c = AiCharacter.fromJson({
        'id': 'a',
        'name': 'เมฆจันทน์',
      });

      expect(c.shortName, 'เมฆจันทน์');
    });

    test('ถ้าสีหาย ใช้สีเหลืองแบรนด์แทน', () {
      final c = AiCharacter.fromJson({'id': 'a', 'name': 'x'});

      expect(c.colorValue, 0xFFFFC107);
    });

    test('สีที่ไม่มี alpha ต้องถูกเติมให้ทึบ', () {
      // 0x00FFC107 = alpha 0 = โปร่งใส ต้องกลายเป็น 0xFFFFC107
      final c = AiCharacter.fromJson({
        'id': 'a',
        'name': 'x',
        'colorValue': 0x00FFC107,
      });

      expect(c.colorValue, 0xFFFFC107);
      expect((c.colorValue >> 24), 0xFF, reason: 'alpha ต้องไม่ใช่ 0');
    });

    test('สีที่มี alpha อยู่แล้วต้องไม่ถูกแก้', () {
      final c = AiCharacter.fromJson({
        'id': 'a',
        'name': 'x',
        'colorValue': 0xFF37474F,
      });

      expect(c.colorValue, 0xFF37474F);
    });

    test('สีที่ผิดปกติ ใช้ค่าเริ่มต้นแทน', () {
      for (final bad in [-1, 99999999999]) {
        final c = AiCharacter.fromJson({
          'id': 'a',
          'name': 'x',
          'colorValue': bad,
        });

        expect(c.colorValue, 0xFFFFC107);
      }
    });

    test('ถ้าสถิติมาเป็น string ก็แปลงได้', () {
      final c = AiCharacter.fromJson({
        'id': 'a',
        'name': 'x',
        'stats': {'chats': '9', 'messages': '100'},
      });

      expect(c.stats.chats, 9);
      expect(c.stats.messages, 100);
    });

    test('hasPersona จริงเมื่อมี persona', () {
      final c = AiCharacter.fromJson({
        'id': 'a',
        'name': 'x',
        'persona': 'คุณคือนักศึกษาแพทย์',
      });

      expect(c.hasPersona, isTrue);
    });
  });

  group('CharacterApi', () {
    test('baseUrlFrom ตัด path ออก', () {
      expect(
        CharacterApi.baseUrlFrom('http://10.0.2.2:8000/chat/stream'),
        'http://10.0.2.2:8000',
      );
      expect(
        CharacterApi.baseUrlFrom('http://192.168.1.5:8000/chat/stream'),
        'http://192.168.1.5:8000',
      );
    });

    test('โหลดตัวละครได้', () async {
      final api = CharacterApi(
        baseUrl: 'http://test.invalid/chat/stream',
        client: _StubClient(
          jsonEncode({
            'characters': [
              {'id': 'a', 'name': 'น้องซิม', 'emoji': '🤖'},
              {'id': 'b', 'name': 'อื่น', 'emoji': '🌙'},
            ],
            'total': 2,
          }),
        ),
      );

      final list = await api.loadCharacters();

      expect(list.length, 2);
      expect(list.first.name, 'น้องซิม');
      expect(list.last.emoji, '🌙');
    });

    test('server error = ใช้ตัวสำรอง', () async {
      final api = CharacterApi(
        baseUrl: 'http://test.invalid/chat/stream',
        client: _StubClient('{}', status: 500),
      );

      final list = await api.loadCharacters();

      expect(list.length, 1);
      expect(list.first.id, fallbackCharacter.id);
    });

    test('ต่อไม่ได้ = ใช้ตัวสำรอง ไม่ throw', () async {
      final api = CharacterApi(
        baseUrl: 'http://test.invalid/chat/stream',
        client: _StubClient('ไม่ใช่ JSON'),
      );

      final list = await api.loadCharacters();

      expect(list.length, 1);
      expect(list.first.id, fallbackCharacter.id);
    });

    test('รายการว่าง = ใช้ตัวสำรอง', () async {
      final api = CharacterApi(
        baseUrl: 'http://test.invalid/chat/stream',
        client: _StubClient(jsonEncode({'characters': []})),
      );

      final list = await api.loadCharacters();

      expect(list.single.id, fallbackCharacter.id);
    });

    test('ทิ้งตัวที่ไม่มี id', () async {
      final api = CharacterApi(
        baseUrl: 'http://test.invalid/chat/stream',
        client: _StubClient(
          jsonEncode({
            'characters': [
              {'name': 'ไม่มี id'},
              {'id': 'ok', 'name': 'น้องซิม'},
            ],
          }),
        ),
      );

      final list = await api.loadCharacters();

      expect(list.length, 1);
      expect(list.first.id, 'ok');
    });
  });
}