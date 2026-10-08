import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme.dart';
import 'avatar.dart';

/// เมนูข้าง (Drawer) เลียนแบบ UI มีเมนูซ้าย + รายการแชท
class ChatDrawer extends StatelessWidget {
  final List<Conversation> conversations;
  final String? currentId;
  final VoidCallback onNewChat;
  final void Function(Conversation) onOpen;
  final void Function(String id) onDelete;
  final VoidCallback onSettings;

  /// เปิดหน้าเลือกตัวละคร (null = ยังโหลดไม่เสร็จ)
  final VoidCallback? onBrowseCharacters;

  const ChatDrawer({
    super.key,
    required this.conversations,
    required this.currentId,
    required this.onNewChat,
    required this.onOpen,
    required this.onDelete,
    required this.onSettings,
    this.onBrowseCharacters,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.drawerBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            const Divider(height: 1),
            _sectionLabel('ประวัติแชท'),
            Expanded(
              child: conversations.isEmpty
                  ? _emptyState(context)
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: conversations.length,
                      itemBuilder: (context, i) => _ChatTile(
                        conversation: conversations[i],
                        selected: conversations[i].id == currentId,
                        onTap: () => onOpen(conversations[i]),
                        onDelete: () => onDelete(conversations[i].id),
                      ),
                    ),
            ),
            const Divider(height: 1),
            _bottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        children: [
          const ShimAvatar(size: 42),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'น้องซิม',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppColors.textMain,
                  ),
                ),
                Text(
                  'เพื่อนคุยสุดกวน',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSub,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'แชทใหม่',
            onPressed: onNewChat,
            icon: const Icon(Icons.add_comment_outlined),
            color: AppColors.textMain,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
          color: AppColors.textSub,
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💭', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีประวัติแชท',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'เริ่มคุยกับน้องซิม แล้วแชทจะถูกเก็บไว้ในนี้',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    return Column(
      children: [
        ListTile(
          dense: true,
          leading: Icon(
            Icons.auto_awesome,
            color: onBrowseCharacters == null
                ? AppColors.divider
                : AppColors.primary,
          ),
          title: Text(
            'เลือกตัวละคร',
            style: TextStyle(
              fontSize: 14,
              color: onBrowseCharacters == null
                  ? AppColors.textSub.withValues(alpha: 0.6)
                  : AppColors.textMain,
            ),
          ),
          onTap: onBrowseCharacters,
        ),
        ListTile(
          dense: true,
          leading: const Icon(
            Icons.settings_outlined,
            color: AppColors.textSub,
          ),
          title: const Text(
            'ตั้งค่า',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMain,
            ),
          ),
          onTap: onSettings,
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// รายการแชทหนึ่งอันในเมนู
class _ChatTile extends StatelessWidget {
  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChatTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      // ListTile ต้องอยู่ใน Material ตัวเอง
      // ถ้าไม่ใส่ สีพื้นหลังจะบัง ink splash ตอนแตะ (Flutter assert)
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: AppColors.primary, width: 1)
                  : null,
            ),
            child: Row(
              children: [
                // avatar ย่อของแชทนั้น (รูปน้องซิมถ้าเป็นแชทของ AI)
                conversation.isFromSim
                    ? const ShimAvatar(size: 30)
                    : const UserAvatar(size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        conversation.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: AppColors.textMain,
                        ),
                      ),
                      Text(
                        relativeTime(conversation.updatedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'ลบแชท',
                  icon: const Icon(Icons.close, size: 16),
                  color: AppColors.textSub,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// แปลงเวลาเป็นข้อความแบบ "5 นาทีที่แล้ว"
String relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);

  if (diff.inSeconds < 60) return 'เมื่อครู่';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
  if (diff.inDays == 1) return 'เมื่อวาน';
  if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';

  return '${time.day}/${time.month}/${time.year}';
}