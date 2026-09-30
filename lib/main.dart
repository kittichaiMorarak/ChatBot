
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'น้องซิม',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF8E7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC83D),
        ),
      ),
      home: const ChatPage(),
    );
  }
}

class Message {
  final String text;
  final bool isUser;

  Message({required this.text, required this.isUser});
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController controller =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final List<Message> messages = [
    Message(
      text: 'หวัดดีค้าบบบ 😆 เราชื่อน้องซิม '
          'มาคุยกันเถอะ วันนี้เป็นไงบ้าง?',
      isUser: false,
    ),
  ];

  bool isTyping = false;

  // Backend ของ Python ที่รันบนคอมเครื่องเดียวกัน
  static const String apiUrl =
      'http://127.0.0.1:8000/chat';

  Future<void> sendMessage() async {
    final text = controller.text.trim();

    if (text.isEmpty || isTyping) return;

    setState(() {
      messages.add(
        Message(text: text, isUser: true),
      );
      controller.clear();
      isTyping = true;
    });

    scrollToBottom();

    try {
      // ไม่ส่งข้อความต้อนรับแรกของน้องซิมไปให้ AI
      // ส่งเฉพาะประวัติการสนทนาจริง
      final chatHistory = messages.skip(1).map((m) {
        return {
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.text,
        };
      }).toList();

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'messages': chatHistory,
            }),
          )
          .timeout(const Duration(seconds: 130));

      if (response.statusCode == 200) {
        final data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        final reply = data['reply']?.toString() ??
            'เอ๊ะ AI ไม่ได้ส่งคำตอบกลับมา 😅';

        if (!mounted) return;

        setState(() {
          messages.add(
            Message(
              text: reply,
              isUser: false,
            ),
          );
        });
      } else {
        throw Exception(
          'Server Error ${response.statusCode}: '
          '${response.body}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      String errorMessage;

      if (e.toString().contains('TimeoutException')) {
        errorMessage =
            'AI คิดนานเกินไปอะ 😭 ลองส่งข้อความอีกครั้งนะ';
      } else {
        errorMessage =
            'เชื่อมต่อ AI ไม่สำเร็จ 😭\n'
            'ตรวจสอบว่า Python Backend และ Ollama เปิดอยู่\n'
            'รายละเอียด: $e';
      }

      setState(() {
        messages.add(
          Message(
            text: errorMessage,
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          isTyping = false;
        });
        scrollToBottom();
      }
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void clearChat() {
    setState(() {
      messages.clear();
      messages.add(
        Message(
          text: 'ล้างแชตแล้ววว 😆 มาเริ่มคุยกันใหม่!',
          isUser: false,
        ),
      );
    });
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFD54F),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                '🤖',
                style: TextStyle(fontSize: 25),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'น้องซิม',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                  Text(
                    'เพื่อนคุยสุดกวน • ออนไลน์',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'ล้างแชต',
            onPressed: isTyping ? null : clearChat,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount:
                  messages.length + (isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (isTyping &&
                    index == messages.length) {
                  return const TypingIndicator();
                }

                final message = messages[index];

                return MessageBubble(
                  message: message,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              12, 10, 12, 16,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Color(0xFFFFE8A3),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !isTyping,
                      textInputAction:
                          TextInputAction.send,
                      onSubmitted: (_) => sendMessage(),
                      decoration: InputDecoration(
                        hintText:
                            'พิมพ์ข้อความหาเราสิ...',
                        filled: true,
                        fillColor:
                            const Color(0xFFFFF8E7),
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        const Color(0xFFFFC107),
                    child: IconButton(
                      onPressed:
                          isTyping ? null : sendMessage,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.brown,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 290,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? const Color(0xFFFFD54F)
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(
              message.isUser ? 18 : 4,
            ),
            bottomRight: Radius.circular(
              message.isUser ? 4 : 18,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.05,
              ),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF3E3428),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(
              Radius.circular(18),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'น้องซิมกำลังพิมพ์... 💭',
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}