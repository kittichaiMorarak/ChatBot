import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/message.dart';
import '../theme.dart';
import 'avatar.dart';

/// avatar ฝั่ง AI ถ้าเป็นน้องซิมใช้รูป ถ้าเป็นตัวละครอื่นใช้สี+อีโมจิ
Widget _aiAvatar(AiCharacter character, double size) {
  if (character.id == fallbackCharacter.id) {
    return ShimAvatar(size: size);
  }

  return CharacterAvatar(
    emoji: character.emoji,
    color: Color(character.colorValue),
    size: size,
  );
}

/// กล่องข้อความ
class MessageBubble extends StatelessWidget {
  final Message message;
  final AiCharacter character;

  const MessageBubble({
    super.key,
    required this.message,
    this.character = fallbackCharacter,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: message.isUser
            ? AppColors.primaryLight
            : AppColors.bubbleAi,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(message.isUser ? 18 : 4),
          bottomRight: Radius.circular(message.isUser ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        message.text,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textMain,
          height: 1.4,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // avatar ซ้ายเฉพาะข้อความ AI
          if (!message.isUser) ...[
            _aiAvatar(character, 32),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            const UserAvatar(size: 32),
          ],
        ],
      ),
    );
  }
}

/// จุดสามจุดเต้น ตอน AI กำลังคิด
class TypingIndicator extends StatefulWidget {
  final AiCharacter character;

  const TypingIndicator({
    super.key,
    this.character = fallbackCharacter,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _aiAvatar(widget.character, 32),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 15,
              ),
              decoration: const BoxDecoration(
                color: AppColors.bubbleAi,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      // แต่ละจุดไหวคนละเฟส
                      final t = (_controller.value + i * 0.25) % 1.0;
                      final lift = 1 - ((t - 0.5).abs() * 2);

                      return Padding(
                        padding:
                            EdgeInsets.only(right: i < 2 ? 6 : 0),
                        child: Transform.translate(
                          offset: Offset(0, -lift * 5),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.black26,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}