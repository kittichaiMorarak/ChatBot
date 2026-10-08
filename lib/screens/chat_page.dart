import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/message.dart';
import '../services/chat_api.dart';
import '../services/chat_storage.dart';
import '../services/character_api.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/message_bubble.dart';
import 'character_list_page.dart';

class ChatPage extends StatefulWidget {
  final ChatApi api;
  final ChatStorage storage;
  final CharacterApi characterApi;

  const ChatPage({
    super.key,
    required this.api,
    required this.storage,
    required this.characterApi,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Conversation> _conversations = [];
  Conversation? _current;
  bool _isTyping = false;
  bool _loaded = false;

  List<AiCharacter> _characters = [];
  bool _charactersLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    try {
      final list = await widget.characterApi.loadCharacters();
      if (!mounted) return;
      setState(() {
        _characters = list;
        _charactersLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _characters = const [fallbackCharacter];
        _charactersLoading = false;
      });
    }
  }

  /// ตัวละครของแชทที่กำลังเปิดอยู่
  AiCharacter get _activeCharacter {
    final id = _current?.characterId;
    if (id == null) return fallbackCharacter;

    for (final c in _characters) {
      if (c.id == id) return c;
    }

    return fallbackCharacter;
  }

  void _openCharacterPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CharacterListPage(
          api: widget.characterApi,
          currentId: _current?.characterId,
          onPick: _pickCharacter,
        ),
      ),
    );
  }

  void _pickCharacter(AiCharacter character) {
    // แชทใหม่เสมอ เพื่อไม่ให้บริบทของตัวเดิมปนกับตัวใหม่
    final fresh = Conversation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: '',
      characterId: character.id,
      updatedAt: DateTime.now(),
      messages: const [],
    );

    setState(() {
      _current = fresh;
      _isTyping = false;
    });

    _replaceCurrent(fresh);
  }

  Future<void> _load() async {
    final saved = widget.storage.load();

    setState(() {
      _conversations = saved;
      // เปิดล่าสุดเข้าแอป
      _current = saved.isEmpty ? _newConversation() : saved.first;
      _loaded = true;
    });
  }

  Conversation _newConversation() {
    // id ต้อง unique เสมอ ถ้าใช้ id เดิมซ้ำจะไปทับแชทเก่า
    return Conversation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: '',
      updatedAt: DateTime.now(),
      messages: const [],
    );
  }

  /// เขียน state ลงเครื่อง
  ///
  /// _conversations เป็นแหล่งความจริงเสมอ (replaceCurrent อัปเดตให้แล้ว)
  Future<void> _persist() {
    return widget.storage.save(_conversations);
  }

  /// แทนที่แชทปัจจุบันในรายการ
  void _replaceCurrent(Conversation conv) {
    setState(() {
      _current = conv;

      final idx = _conversations.indexWhere((c) => c.id == conv.id);
      if (idx >= 0) {
        _conversations[idx] = conv;
      } else {
        _conversations.insert(0, conv);
      }

      // เก็บให้คนที่เลือกไว้อยู่บนสุด
      _conversations.sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );
    });

    _persist();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;

    final base = _current ?? _newConversation();
    final replyIndex = base.messages.length + 1;

    // ผู้ใช้ + placeholder สำหรับคำตอบ AI
    setState(() {
      _current = base.copyWith(
        title: base.title.isEmpty ? text : base.title,
        updatedAt: DateTime.now(),
        messages: [
          ...base.messages,
          Message(text: text, isUser: true),
          const Message(text: '', isUser: false),
        ],
      );
      _controller.clear();
      _isTyping = true;
    });

    _replaceCurrent(_current!);
    _scrollToBottom();

    final convId = _current!.id;
    var buffer = '';

    // เก็บข้อความของแชทนี้ไว้ เพื่อกันผลลัพธ์หลุดไปแชทอื่น
    // (ถ้าผู้ใช้สลับแชทหรือกดล้างระหว่างรอ)
    final convAtSend = _current!;

    final result = await widget.api.send(
      convAtSend.messages,
      characterId: convAtSend.characterId,
      onToken: (token) {
        buffer += token;

        if (!mounted) return;
        if (_current?.id != convId) return;

        final msgs = [..._current!.messages];
        if (replyIndex >= msgs.length) return;

        msgs[replyIndex] = Message(text: buffer, isUser: false);

        setState(() {
          _current = _current!.copyWith(messages: msgs);
        });

        _scrollToBottom();
      },
    );

    if (!mounted) return;

    // ผู้ใช้สลับไปแชทอื่นระหว่างรอ — ไม่ต้องแตะ state
    if (_current?.id != convId) return;

    if (result.isError) {
      final msgs = [..._current!.messages];
      if (replyIndex < msgs.length) {
        msgs[replyIndex] = Message(
          text: result.text.trim().isEmpty
              ? result.error!
              : '${result.text}\n\n⚠️ ${result.error}',
          isUser: false,
        );
      }

      setState(() {
        _current = _current!.copyWith(messages: msgs);
        _isTyping = false;
      });
    } else {
      final msgs = [..._current!.messages];
      if (replyIndex < msgs.length) {
        if (result.text.trim().isEmpty) {
          msgs[replyIndex] = const Message(
            text: 'เอ๊ะ AI ไม่ได้ส่งคำตอบกลับมา 😅',
            isUser: false,
          );
        }
      }

      setState(() {
        _current = _current!.copyWith(
          messages: msgs,
          updatedAt: DateTime.now(),
        );
        _isTyping = false;
      });
    }

    // เซฟครั้งสุดท้าย (ตัว token ระหว่างทางไม่เซฟ)
    _replaceCurrent(_current!);
    _scrollToBottom();
  }

  void _stopGenerating() {
    widget.api.dispose();

    setState(() {
      _isTyping = false;

      final msgs = [...?_current?.messages];
      // ลบ placeholder ที่ยังว่าง
      if (msgs.isNotEmpty && !msgs.last.isUser && msgs.last.text.isEmpty) {
        msgs.removeLast();
        _current = _current!.copyWith(messages: msgs);
      }
    });

    if (_current != null) _replaceCurrent(_current!);
  }

  /// ปิดเมนูข้างถ้ามันเปิดอยู่
  ///
  /// ต้องเช็คก่อน ไม่งั้นกดจากปุ่มบน AppBar (ตอนไม่มี drawer เปิด)
  /// จะไป pop route หลักของแอปจนหน้าจอว่าง
  void _closeDrawer() {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
    }
  }

  void _startNewChat() {
    _closeDrawer();

    setState(() {
      _current = _newConversation();
      _isTyping = false;
    });

    _scrollToBottom();
  }

  void _openConversation(Conversation conv) {
    _closeDrawer();

    setState(() {
      _current = conv;
      _isTyping = false;
    });

    _scrollToBottom();
  }

  Future<void> _deleteConversation(String id) async {
    final target = _conversations.firstWhere(
      (c) => c.id == id,
      orElse: () => _current!,
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบแชทนี้?'),
        content: Text('"${target.displayTitle}" จะถูกลบถาวร'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final wasCurrent = _current?.id == id;

    setState(() {
      _conversations =
          _conversations.where((c) => c.id != id).toList();

      if (wasCurrent) {
        _current = _conversations.isNotEmpty
            ? _conversations.first
            : _newConversation();
      }
    });

    await widget.storage.save(_conversations);
  }

  void _openSettings() {
    _closeDrawer();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.drawerBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ตั้งค่า',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 16),
              _infoRow('Backend', widget.api.apiUrl),
              _infoRow('แชทที่เก็บไว้', '${_conversations.length} ห้อง'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.brown,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ปิด'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSub,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final messages = _current?.messages ?? const <Message>[];
    final character = _activeCharacter;
    final isSim = character.id == fallbackCharacter.id;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Row(
          children: [
            if (isSim)
              const ShimAvatar(size: 40)
            else
              CharacterAvatar(
                emoji: character.emoji,
                color: Color(character.colorValue),
                size: 40,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _current?.title.isNotEmpty == true
                              ? _current!.displayTitle
                              : character.shortName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      if (!isSim)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.favorite,
                            size: 13,
                            color: Colors.brown,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    isSim ? character.tagline : 'กำลังคุยกับตัวละคร',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // เปิดหน้าเลือกตัวละคร
          IconButton(
            tooltip: 'เลือกตัวละคร',
            onPressed: _charactersLoading ? null : _openCharacterPicker,
            icon: const Icon(Icons.auto_awesome),
          ),
          IconButton(
            tooltip: 'แชทใหม่',
            onPressed: _startNewChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: 'ล้างแชทนี้',
            onPressed: _current?.messages.isNotEmpty == true
                ? () => _deleteConversation(_current!.id)
                : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      drawer: ChatDrawer(
        conversations: _conversations,
        currentId: _current?.id,
        onNewChat: _startNewChat,
        onOpen: _openConversation,
        onDelete: _deleteConversation,
        onSettings: _openSettings,
        onBrowseCharacters: _charactersLoading
            ? null
            : _openCharacterPicker,
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _WelcomeView(character: character)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final message = messages[i];

                      // bubble ว่าง = AI กำลังคิด
                      if (!message.isUser && message.text.isEmpty) {
                        return TypingIndicator(
                          character: _activeCharacter,
                        );
                      }

                      return MessageBubble(
                        message: message,
                        character: _activeCharacter,
                      );
                    },
                  ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !_isTyping,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'พิมพ์ข้อความหาเราสิ...',
                  hintStyle: const TextStyle(color: AppColors.textSub),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor: _isTyping
                  ? const Color(0xFFE0E0E0)
                  : AppColors.primary,
              child: IconButton(
                onPressed: _isTyping ? _stopGenerating : _sendMessage,
                icon: Icon(
                  _isTyping ? Icons.stop_rounded : Icons.send_rounded,
                  color: Colors.brown,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// หน้าจอต้อนรับตอนยังไม่มีข้อความ
class _WelcomeView extends StatelessWidget {
  final AiCharacter character;

  const _WelcomeView({required this.character});

  @override
  Widget build(BuildContext context) {
    final isSim = character.id == fallbackCharacter.id;
    final color = Color(character.colorValue);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSim)
              const ShimAvatar(size: 110)
            else
              CharacterAvatar(
                emoji: character.emoji,
                color: color,
                size: 110,
              ),
            const SizedBox(height: 20),
            Text(
              'หวัดดีค้าบบบ 😆',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSim
                  ? 'เราชื่อน้องซิม มาคุยกันเถอะ\nเขียนอะไรมาได้เลย'
                  : 'กำลังคุยกับ ${character.shortName}\n${character.tagline}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}