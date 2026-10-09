import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/message.dart';

/// ผลลัพธ์ของการส่งข้อความ
class ChatResult {
  final String text;

  /// true ถ้าเกิดข้อผิดพลาด
  final String? error;

  const ChatResult({required this.text, this.error});

  bool get isError => error != null;
}

/// เรียก backend และอ่านคำตอบแบบ streaming
class ChatApi {
  final String apiUrl;
  final http.Client _client;

  ChatApi({required this.apiUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// เปิด connection ใหม่ (เรียกก่อนส่ง เพื่อรองรับการกดหยุด)
  http.Client get client => _client;

  void dispose() {
    _client.close();
  }

  /// ตัดบริบทให้เหลือ 20 ข้อความล่าสุด
  static const historyLimit = 20;

  static Map<String, dynamic> buildPayload(
    List<Message> messages, {
    String? characterId,
    String? persona,
  }) {
    // เอาท้ายสุด N ข้อความ (ข้อความล่าสุดสำคัญที่สุด)
    // ต้อง skip ก่อน take ไม่งั้นจะได้ข้อความเก่าสุดแทน
    final recent = messages.length > historyLimit
        ? messages.sublist(messages.length - historyLimit)
        : messages;

    final payload = <String, dynamic>{
      'messages': recent
          .where((m) => m.text.trim().isNotEmpty)
          .map(
            (m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            },
          )
          .toList(),
    };

    // บอก backend ว่ากำลังคุยกับตัวละครไหน
    if (characterId != null && characterId.isNotEmpty) {
      payload['character_id'] = characterId;
    }

    // ตัวละครที่ผู้ใช้สร้างเอง — ส่งบุคลิกไปให้ backend ใช้เป็น system prompt
    final p = persona?.trim();
    if (p != null && p.isNotEmpty) {
      payload['persona'] = p;
    }

    return payload;
  }

  /// ส่งข้อความและเรียก onToken ทีละชิ้น
  ///
  /// ถ้า client ถูกปิดกลางทาง (กดหยุด) จะหยุดเงียบๆ ไม่ throw
  Future<ChatResult> send(
    List<Message> messages, {
    String? characterId,
    String? persona,
    required void Function(String token) onToken,
    Duration connectTimeout = const Duration(seconds: 10),
  }) async {
    final request = http.Request('POST', Uri.parse(apiUrl))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(buildPayload(
        messages,
        characterId: characterId,
        persona: persona,
      ));

    http.StreamedResponse response;

    try {
      response = await _client
          .send(request)
          .timeout(connectTimeout);
    } on TimeoutException {
      return const ChatResult(
        text: '',
        error: 'เชื่อมต่อ AI ไม่ทัน ลองใหม่อีกครั้งนะ',
      );
    } catch (e) {
      return ChatResult(text: '', error: _friendlyError(e));
    }

    if (response.statusCode != 200) {
      return ChatResult(
        text: '',
        error: 'Server Error ${response.statusCode}',
      );
    }

    final buffer = StringBuffer();

    try {
      await for (final line
          in response.stream.transform(utf8.decoder).transform(
                const LineSplitter(),
              )) {
        if (!line.startsWith('data:')) continue;

        final jsonText = line.substring(5).trim();
        if (jsonText.isEmpty) continue;

        final data = jsonDecode(jsonText);

        if (data['error'] != null) {
          return ChatResult(
            text: buffer.toString(),
            error: data['error'].toString(),
          );
        }

        if (data['done'] == true) break;

        final token = data['token']?.toString() ?? '';
        if (token.isEmpty) continue;

        buffer.write(token);
        onToken(token);
      }
    } catch (e) {
      // ถ้า client ถูกปิดกลางคัน (กดหยุด) ไม่ต้องแสดง error
      if (_isCancelled(e)) {
        return ChatResult(text: buffer.toString());
      }

      return ChatResult(
        text: buffer.toString(),
        error: _friendlyError(e),
      );
    }

    return ChatResult(text: buffer.toString());
  }

  /// กดหยุดแล้ว connection ถูกปิด ถือว่าไม่ใช่ error
  bool _isCancelled(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('client is already closed') ||
        msg.contains('connection closed') ||
        msg.contains('stream was closed') ||
        msg.contains('socketexception');
  }

  String _friendlyError(Object e) {
    final msg = e.toString();

    if (msg.contains('TimeoutException')) {
      return 'AI คิดนานเกินไปอะ 😭 ลองส่งข้อความอีกครั้งนะ';
    }

    return 'เชื่อมต่อ AI ไม่สำเร็จ 😭\n'
        'ตรวจสอบว่า Python Backend และ Ollama เปิดอยู่\n'
        'รายละเอียด: $msg';
  }
}