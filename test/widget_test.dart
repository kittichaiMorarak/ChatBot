import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:simsimi_chatbot/main.dart';
import 'package:simsimi_chatbot/models/character.dart';
import 'package:simsimi_chatbot/models/message.dart';
import 'package:simsimi_chatbot/screens/chat_page.dart';
import 'package:simsimi_chatbot/services/chat_api.dart';
import 'package:simsimi_chatbot/services/chat_storage.dart';
import 'package:simsimi_chatbot/services/character_api.dart';
import 'package:simsimi_chatbot/services/character_storage.dart';
import 'package:simsimi_chatbot/widgets/chat_drawer.dart';

/// http client ปลอม ตอบกลับทันที ไม่ต้องต่อเครือข่ายจริง
class _FakeClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body =
        'data: {"token":"โอ้ สนุกดี"}\n\ndata: {"done":true}\n\n';

    return http.StreamedResponse(
      Stream.value(utf8bytes(body)),
      200,
    );
  }

  List<int> utf8bytes(String s) => s.codeUnits;
}

/// client ปลอมสำหรับ /characters
class _FakeCharacterClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final json = jsonEncode({
      'characters': [
        {
          'id': 'nongsim',
          'name': 'น้องซิม',
          'emoji': '🤖',
          'colorValue': 0xFFFFC107,
          'tagline': 'เพื่อนคุยสุดกวน',
          'tags': ['เพื่อนคุย', 'ตลก'],
        },
        {
          'id': 'shim',
          'name': 'ปาร์ค มูจิน | [Park Moojin]',
          'emoji': '🩹',
          'colorValue': 0xFF37474F,
          'tagline': '"เอ๊ะ! ..."',
          'tags': ['รงเยียว', 'ชาย'],
        },
      ],
      'total': 2,
    });

    return http.StreamedResponse(
      Stream.value(utf8.encode(json)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// สร้างแอปเต็ม (หน้าแรก = หน้าซิม)
Widget buildTestApp({
  ChatStorage? storage,
  CharacterStorage? characterStorage,
  http.Client? client,
}) {
  return ChatApp(
    api: ChatApi(
      apiUrl: 'http://test.invalid/chat/stream',
      client: client ?? _FakeClient(),
    ),
    storage: storage ?? ChatStorage.inMemory(),
    characterApi: CharacterApi(
      baseUrl: 'http://test.invalid/chat/stream',
      client: _FakeCharacterClient(),
    ),
    characterStorage:
        characterStorage ?? CharacterStorage.inMemory(),
  );
}

/// สร้างหน้าแชทโดยตรง (ข้ามหน้าซิม)
Widget buildTestChatPage({
  ChatStorage? storage,
  CharacterStorage? characterStorage,
  AiCharacter? initialCharacter,
}) {
  return MaterialApp(
    home: ChatPage(
      api: ChatApi(
        apiUrl: 'http://test.invalid/chat/stream',
        client: _FakeClient(),
      ),
      storage: storage ?? ChatStorage.inMemory(),
      characterApi: CharacterApi(
        baseUrl: 'http://test.invalid/chat/stream',
        client: _FakeCharacterClient(),
      ),
      characterStorage:
          characterStorage ?? CharacterStorage.inMemory(),
      initialCharacter: initialCharacter,
    ),
  );
}

/// เลื่อนให้ widget ที่ต้องการเห็น
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.scrollUntilVisible(
    finder,
    200, // ระยะเลื่อนต่อครั้ง
    maxScrolls: 30,
    // หน้ามีหลาย Scrollable (เช่น ใน AppBar)
    // ต้องระบุให้ชัดว่าจะเลื่อนตัวไหน
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('หน้าซิม (หน้าแรก)', () {
    testWidgets('เปิดแอปแล้วเข้าหน้าซิม', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('น้องซิม'), findsWidgets);
      expect(find.text('ตัวละครของคุณ'), findsOneWidget);

      // ปุ่มสร้างตัวละครอยู่ท้ายหน้า ต้องเลื่อนลงไปดู
      await scrollTo(tester, find.text('สร้างตัวละครใหม่'));
      expect(find.text('สร้างตัวละครใหม่'), findsOneWidget);
    });

    testWidgets('กดเริ่มแชทที่การ์ดน้องซิมเข้าหน้าแชท',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('เริ่มแชท').first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('แตะการ์ดน้องซิมเข้าหน้าโปรไฟล์ก่อน',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // แตะชื่อน้องซิมบนการ์ดใหญ่
      await tester.tap(
        find.descendant(
          of: find.byType(InkWell).first,
          matching: find.text('น้องซิม'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ข้อมูลตัวละคร'), findsOneWidget);
      expect(find.text('เริ่มแชท'), findsOneWidget);
    });

    testWidgets('ยังไม่มีตัวละครของคุณ = ขึ้น empty state',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('ยังไม่มีตัวละครของคุณ'));
      expect(find.text('ยังไม่มีตัวละครของคุณ'), findsOneWidget);
    });

    testWidgets('แสดงตัวละครที่ผู้ใช้สร้างเอง', (tester) async {
      final cs = CharacterStorage.inMemory();
      await cs.add(
        const AiCharacter(
          id: 'mine',
          name: 'หมอเก่ง',
          tagline: 'คุณหมอประจำตัว',
          emoji: '🩺',
          colorValue: 0xFF00897B,
          creator: 'ผู้ใช้สร้างเอง',
          quote: '',
          description: '',
          tags: ['หมอ'],
          stats: CharacterStats(
            worlds: 0,
            chats: 0,
            messages: 0,
            gifts: 0,
          ),
          persona: 'คุณเป็นหมอที่พูดตรงๆ',
        ),
      );

      await tester.pumpWidget(buildTestApp(characterStorage: cs));
      await tester.pumpAndSettle();

      expect(find.text('หมอเก่ง'), findsOneWidget);
      expect(find.text('1 ตัว'), findsOneWidget);
      expect(find.text('ยังไม่มีตัวละครของคุณ'), findsNothing);
    });

    testWidgets('เปิดหน้าสร้างตัวละครได้', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('สร้างตัวละครใหม่'));
      await tester.tap(find.text('สร้างตัวละครใหม่'));
      await tester.pumpAndSettle();

      expect(find.text('สร้างตัวละคร'), findsOneWidget);
      expect(find.text('ชื่อตัวละคร *'), findsOneWidget);

      await scrollTo(
        tester,
        find.text('บุคลิกและวิธีพูด (ไม่บังคับ)'),
      );
      expect(
        find.text('บุคลิกและวิธีพูด (ไม่บังคับ)'),
        findsOneWidget,
      );
    });
  });

  group('ตัวละครที่เลือกจากหน้าเข้าหน้าแรก', () {
    testWidgets('แชทเริ่มด้วยตัวละครที่เลือก', (tester) async {
      await tester.pumpWidget(
        buildTestChatPage(
          initialCharacter: const AiCharacter(
            id: 'shim',
            name: 'ปาร์ค มูจิน',
            tagline: '"เอ๊ะ!"',
            emoji: '🩹',
            colorValue: 0xFF37474F,
            creator: '@Park_Jin',
            quote: '',
            description: '',
            tags: ['ชาย'],
            stats: CharacterStats(
              worlds: 0,
              chats: 0,
              messages: 0,
              gifts: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // หน้าต้อนรับต้องบอกว่ากำลังคุยกับตัวละครที่เลือก
      expect(find.textContaining('กำลังคุยกับ ปาร์ค มูจิน'),
          findsOneWidget);
    });

    testWidgets('แชทใหม่ต้องผูกกับตัวละครที่เลือก',
        (tester) async {
      final storage = ChatStorage.inMemory();

      await tester.pumpWidget(
        buildTestChatPage(
          storage: storage,
          initialCharacter: const AiCharacter(
            id: 'shim',
            name: 'ปาร์ค มูจิน',
            tagline: '',
            emoji: '🩹',
            colorValue: 0xFF37474F,
            creator: '',
            quote: '',
            description: '',
            tags: [],
            stats: CharacterStats(
              worlds: 0,
              chats: 0,
              messages: 0,
              gifts: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'สวัสดี');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      final saved = storage.load();
      expect(saved, isNotEmpty);
      expect(saved.first.characterId, 'shim',
          reason: 'แชทต้องจำได้ว่าคุยกับตัวละครไหน');
    });
  });

  group('หน้าจอแชท', () {
    testWidgets('แสดงชื่อน้องซิม', (tester) async {
      await tester.pumpWidget(buildTestChatPage());

      expect(find.text('น้องซิม'), findsWidgets);
    });

    testWidgets('แสดงหน้าต้อนรับตอนยังไม่มีข้อความ',
        (tester) async {
      await tester.pumpWidget(buildTestChatPage());

      expect(find.text('หวัดดีค้าบบบ 😆'), findsOneWidget);
    });

    testWidgets('มีช่องพิมพ์และปุ่มส่ง', (tester) async {
      await tester.pumpWidget(buildTestChatPage());

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('มีปุ่มเปิดเมนูข้าง', (tester) async {
      await tester.pumpWidget(buildTestChatPage());

      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets(
      'แชทเก่าต้องไม่หายเมื่อสร้างแชทใหม่ (regression)',
      (tester) async {
        final storage = ChatStorage.inMemory();
        await tester.pumpWidget(buildTestChatPage(storage: storage));

        // แชทแรก
        await tester.enterText(find.byType(TextField), 'แชทแรก');
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        // สร้างแชทใหม่ผ่านปุ่มใน AppBar
        // (ใช้ first เพราะมีไอคอนเหมือนกันทั้งใน AppBar และในเมนูข้าง)
        await tester.tap(find.byTooltip('แชทใหม่').first);
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget,
            reason: 'ไม่มีช่องพิมพ์หลังสร้างแชทใหม่');

        // แชทที่สอง
        await tester.enterText(find.byType(TextField), 'แชทที่สอง');
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        // ทั้งสองแชทต้องอยู่ใน storage
        final titles =
            storage.load().map((c) => c.title).toList();

        expect(titles, contains('แชทแรก'),
            reason: 'แชทเก่าหายไปเมื่อสร้างแชทใหม่');
        expect(titles, contains('แชทที่สอง'));
      },
    );

    testWidgets('แชทที่สร้างแล้วต้องไม่หายหลังปิดแอป',
        (tester) async {
      final storage = ChatStorage.inMemory();

      await tester.pumpWidget(buildTestChatPage(storage: storage));
      await tester.enterText(find.byType(TextField), 'จำฉันไว้');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // เปิดแอปใหม่ด้วย storage เดิม
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(buildTestChatPage(storage: storage));
      await tester.pumpAndSettle();

      // โผล่ได้ทั้งใน bubble และชื่อแชทบน AppBar
      expect(
        find.text('จำฉันไว้'),
        findsWidgets,
        reason: 'แชทไม่ถูกกู้คืนหลังเปิดแอปใหม่',
      );
    });
  });

  group('เมนูข้าง', () {
    testWidgets('เปิดได้และเห็นรายการเมนู', (tester) async {
      await tester.pumpWidget(buildTestChatPage());

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('ประวัติแชท'), findsOneWidget);
      expect(find.text('ตั้งค่า'), findsOneWidget);
    });

    testWidgets('ยังไม่มีแชท = ขึ้น empty state', (tester) async {
      await tester.pumpWidget(buildTestChatPage());

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่มีประวัติแชท'), findsOneWidget);
    });

    testWidgets('แสดงรายการแชทที่บันทึกไว้', (tester) async {
      final storage = ChatStorage.inMemory();
      final now = DateTime.now();

      await storage.save([
        Conversation(
          id: 'a',
          title: 'ถามเรื่องกิน',
          updatedAt: now,
          messages: const [
            Message(text: 'ชอบกินอะไร', isUser: true),
            Message(text: 'ชาเย็น', isUser: false),
          ],
        ),
        Conversation(
          id: 'b',
          title: 'ถามเรื่องหนัง',
          // เก่ากว่าเพื่อให้ลำดับชัดเจน
          updatedAt: now.subtract(const Duration(hours: 1)),
          messages: const [
            Message(text: 'แนะนำหนังหน่อย', isUser: true),
          ],
        ),
      ]);

      await tester.pumpWidget(buildTestChatPage(storage: storage));

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // ชื่อแชทที่เลือกอยู่จะโผล่ทั้งในเมนูและใน AppBar
      expect(find.text('ถามเรื่องกิน'), findsWidgets);
      expect(find.text('ถามเรื่องหนัง'), findsOneWidget);
    });

    testWidgets('แตะแชทในเมนูแล้วเปิดแชทนั้น', (tester) async {
      final storage = ChatStorage.inMemory();
      final now = DateTime.now();

      await storage.save([
        Conversation(
          id: 'a',
          title: 'ถามเรื่องกิน',
          updatedAt: now,
          messages: const [Message(text: 'กินอะไรดี', isUser: true)],
        ),
        Conversation(
          id: 'b',
          title: 'ถามเรื่องหนัง',
          updatedAt: now.subtract(const Duration(hours: 1)),
          messages: const [Message(text: 'ดูหนังอะไรดี', isUser: true)],
        ),
      ]);

      await tester.pumpWidget(buildTestChatPage(storage: storage));

      // เปิดเมนูแล้วแตะแชทที่สอง (ยังไม่ได้เปิด)
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ถามเรื่องหนัง'));
      await tester.pumpAndSettle();

      // drawer ปิด และเห็นข้อความของแชทที่สอง
      expect(find.text('ดูหนังอะไรดี'), findsOneWidget);
      expect(find.text('กินอะไรดี'), findsNothing);
    });
  });

  group('relativeTime', () {
    test('เขียนเวลาเป็นภาษาไทย', () {
      final now = DateTime.now();

      expect(relativeTime(now), 'เมื่อครู่');
      expect(
        relativeTime(now.subtract(const Duration(minutes: 5))),
        '5 นาทีที่แล้ว',
      );
      expect(
        relativeTime(now.subtract(const Duration(hours: 3))),
        '3 ชั่วโมงที่แล้ว',
      );
      expect(
        relativeTime(now.subtract(const Duration(days: 1))),
        'เมื่อวาน',
      );
    });
  });
}