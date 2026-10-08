import 'package:flutter_test/flutter_test.dart';

import 'package:simsimi_chatbot/models/message.dart';
import 'package:simsimi_chatbot/services/chat_api.dart';
import 'package:simsimi_chatbot/services/chat_storage.dart';

void main() {
  group('Conversation', () {
    test('preview ใช้ข้อความแรกที่ผู้ใช้พิมพ์', () {
      final conv = Conversation(
        id: '1',
        title: '',
        updatedAt: DateTime.now(),
        messages: const [
          Message(text: 'สวัสดีน้องซิม', isUser: true),
          Message(text: 'หวัดดีจ้า', isUser: false),
          Message(text: 'สนุกจัง', isUser: true),
        ],
      );

      expect(conv.preview, 'สวัสดีน้องซิม');
    });

    test('preview ถ้าไม่มีข้อความจากผู้ใช้', () {
      final conv = Conversation(
        id: '1',
        title: '',
        updatedAt: DateTime.now(),
        messages: const [Message(text: 'AI พูดเอง', isUser: false)],
      );

      expect(conv.preview, 'แชทใหม่');
    });

    test('displayTitle ตัดข้อความยาวให้พอดี', () {
      final long = 'a' * 100;
      final conv = Conversation(
        id: '1',
        title: long,
        updatedAt: DateTime.now(),
        messages: const [],
      );

      expect(conv.displayTitle.length, 33); // 30 + '...'
      expect(conv.displayTitle.endsWith('...'), isTrue);
    });

    test('round-trip ผ่าน JSON', () {
      final conv = Conversation(
        id: 'abc',
        title: 'ถามเรื่องกิน',
        updatedAt: DateTime(2026, 1, 2, 3, 4, 5),
        messages: const [
          Message(text: 'กินอะไร', isUser: true),
          Message(text: 'ข้าวผัด', isUser: false),
        ],
      );

      final decoded = Conversation.fromJson(conv.toJson());

      expect(decoded.id, 'abc');
      expect(decoded.title, 'ถามเรื่องกิน');
      expect(decoded.messages.length, 2);
      expect(decoded.messages[0].text, 'กินอะไร');
      expect(decoded.messages[0].isUser, isTrue);
      expect(decoded.messages[1].isUser, isFalse);
      expect(
        decoded.updatedAt.millisecondsSinceEpoch,
        conv.updatedAt.millisecondsSinceEpoch,
      );
    });
  });

  group('decodeConversations', () {
    test('JSON เสียหาย = คืนค่าว่าง ไม่ crash', () {
      expect(decodeConversations('ไม่ใช่ JSON'), isEmpty);
      expect(decodeConversations(''), isEmpty);
    });
  });

  group('ChatStorage', () {
    test('บันทึกและโหลดกลับได้', () async {
      final storage = ChatStorage.inMemory();

      await storage.save([
        Conversation(
          id: '1',
          title: 'แชทแรก',
          updatedAt: DateTime.now(),
          messages: const [Message(text: 'hi', isUser: true)],
        ),
      ]);

      final loaded = storage.load();

      expect(loaded.length, 1);
      expect(loaded.first.title, 'แชทแรก');
    });

    test('เก็บได้ไม่เกิน maxConversations และตัดเก่าทิ้ง', () async {
      final storage = ChatStorage.inMemory();
      final now = DateTime.now();

      await storage.save([
        for (var i = 0; i < ChatStorage.maxConversations + 10; i++)
          Conversation(
            id: '$i',
            title: 'แชท $i',
            // แชทใหม่ไว้ข้างหน้า
            updatedAt: now.subtract(Duration(minutes: i)),
            messages: const [],
          ),
      ]);

      final loaded = storage.load();

      expect(loaded.length, ChatStorage.maxConversations);
      // ต้องเก็บแชทใหม่สุด (i=0) ไว้
      expect(loaded.first.title, 'แชท 0');
    });

    test('เรียงลำดับใหม่สุดมาก่อน', () async {
      final storage = ChatStorage.inMemory();
      final now = DateTime.now();

      await storage.save([
        Conversation(
          id: 'old',
          title: 'เก่า',
          updatedAt: now.subtract(const Duration(days: 5)),
          messages: const [],
        ),
        Conversation(
          id: 'new',
          title: 'ใหม่',
          updatedAt: now,
          messages: const [],
        ),
      ]);

      expect(storage.load().first.title, 'ใหม่');
    });

    test('clear ล้างข้อมูลทั้งหมด', () async {
      final storage = ChatStorage.inMemory();

      await storage.save([
        Conversation(
          id: '1',
          title: 'x',
          updatedAt: DateTime.now(),
          messages: const [],
        ),
      ]);
      expect(storage.load(), isNotEmpty);

      await storage.clear();
      expect(storage.load(), isEmpty);
    });
  });

  group('ChatApi.buildPayload', () {
    test('ตัดบริบทเหลือ 20 ข้อความล่าสุด', () {
      final messages = [
        for (var i = 0; i < 50; i++)
          Message(text: 'ข้อความ $i', isUser: i.isEven),
      ];

      final payload = ChatApi.buildPayload(messages)['messages'] as List;

      expect(payload.length, ChatApi.historyLimit);
      // ต้องเป็น 20 ข้อความท้ายสุด
      expect(payload.last['content'], 'ข้อความ 49');
    });

    test('กรองข้อความว่างออก', () {
      final payload = ChatApi.buildPayload([
        const Message(text: '   ', isUser: true),
        const Message(text: 'สวัสดี', isUser: true),
      ])['messages'] as List;

      expect(payload.length, 1);
      expect(payload.first['content'], 'สวัสดี');
    });

    test('ใส่ character_id เมื่อระบุตัวละคร', () {
      final payload = ChatApi.buildPayload(
        const [Message(text: 'สวัสดี', isUser: true)],
        characterId: 'placeholder_shim',
      );

      expect(payload['character_id'], 'placeholder_shim');
    });

    test('ไม่ใส่ character_id ตอนคุยกับน้องซิม', () {
      final payload = ChatApi.buildPayload(
        const [Message(text: 'สวัสดี', isUser: true)],
      );

      expect(payload.containsKey('character_id'), isFalse);
    });

    test('แปลง role ถูกต้อง', () {
      final payload = ChatApi.buildPayload([
        const Message(text: 'ถาม', isUser: true),
        const Message(text: 'ตอบ', isUser: false),
      ])['messages'] as List;

      expect(payload[0]['role'], 'user');
      expect(payload[1]['role'], 'assistant');
    });
  });
}