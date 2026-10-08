import 'package:flutter/material.dart';

import 'screens/chat_page.dart';
import 'services/chat_api.dart';
import 'services/chat_storage.dart';
import 'services/character_api.dart';
import 'theme.dart';

/// Backend ของ Python ที่รันบนคอมเครื่องเดียวกัน
///
/// สำคัญเรื่อง IP:
///
/// - Android emulator : `10.0.2.2` (ทางลัดไป host เครื่องนี้)
/// - มือถือจริง      : IP ของคอม ดูด้วย `ipconfig getifaddr en1`
/// - macOS / Chrome  : IP ของคอม
///
/// `127.0.0.1` บนมือถือ = ตัวมือถือเอง ไม่ใช่คอม จะต่อไม่ได้
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.24.176.189:8000/chat/stream',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await ChatStorage.create();

  runApp(
    ChatApp(
      api: ChatApi(apiUrl: apiUrl),
      storage: storage,
      characterApi: CharacterApi(baseUrl: apiUrl),
    ),
  );
}

class ChatApp extends StatelessWidget {
  final ChatApi api;
  final ChatStorage storage;
  final CharacterApi characterApi;

  const ChatApp({
    super.key,
    required this.api,
    required this.storage,
    required this.characterApi,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'น้องซิม',
      theme: buildTheme(),
      home: ChatPage(
        api: api,
        storage: storage,
        characterApi: characterApi,
      ),
    );
  }
}