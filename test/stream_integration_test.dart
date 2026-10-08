import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// ทดสอบว่า client อ่าน SSE จาก server ได้ถูกต้อง
/// รันกับ backend ที่เปิดอยู่จริง (ต้องเปิด uvicorn ก่อน)
void main() {
  const url =
      'http://localhost:8000/chat/stream';

  test('อ่าน stream จาก server ได้ครบ', () async {
    final request = http.Request('POST', Uri.parse(url))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'messages': [
          {'role': 'user', 'content': 'นับ 1 ถึง 5'},
        ],
      });

    final client = http.Client();
    final response = await client.send(request);

    expect(response.statusCode, 200);

    final buffer = StringBuffer();
    var done = false;

    await for (final line
        in response.stream.transform(utf8.decoder).transform(
              const LineSplitter(),
            )) {
      if (!line.startsWith('data:')) continue;

      final jsonText = line.substring(5).trim();
      if (jsonText.isEmpty) continue;

      final data = jsonDecode(jsonText);

      if (data['error'] != null) {
        fail('server error: ${data['error']}');
      }

      if (data['done'] == true) {
        done = true;
        break;
      }

      buffer.write(data['token'] ?? '');
    }

    client.close();

    expect(done, isTrue,
        reason: 'ต้องได้ done=true สักที');
    expect(buffer.toString().trim(), isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 180)));
}