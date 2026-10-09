import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/character_api.dart';
import '../services/character_storage.dart';
import '../theme.dart';
import 'character_edit_page.dart';
import 'character_profile_page.dart';

/// หน้าซิม — หน้าแรกของแอป
///
/// โชว์น้องซิมเป็นการ์ดใหญ่ด้านบน แล้วด้านล่างเป็นตัวละครที่ผู้ใช้สร้างเอง
class SimHomePage extends StatefulWidget {
  final CharacterApi api;
  final CharacterStorage storage;

  /// เลือกตัวละครแล้วต้องการเข้าหน้าแชท
  final void Function(AiCharacter character) onPick;

  const SimHomePage({
    super.key,
    required this.api,
    required this.storage,
    required this.onPick,
  });

  @override
  State<SimHomePage> createState() => _SimHomePageState();
}

class _SimHomePageState extends State<SimHomePage> {
  /// ตัวละครจาก server (ตอนนี้มีแค่น้องซิม)
  List<AiCharacter> _serverCharacters = [];

  /// ตัวละครที่ผู้ใช้สร้างเอง
  List<AiCharacter> _myCharacters = [];

  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fromServer = await widget.api.loadCharacters();
    final mine = widget.storage.load();

    if (!mounted) return;
    setState(() {
      _serverCharacters = fromServer;
      _myCharacters = mine;
      _loading = false;
    });
  }

  /// ตัวละครหลักของแอป (น้องซิม)
  AiCharacter get _sim => _serverCharacters.isNotEmpty
      ? _serverCharacters.first
      : fallbackCharacter;

  List<AiCharacter> get _filteredMine {
    if (_query.isEmpty) return _myCharacters;

    final q = _query.toLowerCase();
    return _myCharacters.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.tagline.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          c.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _openProfile(AiCharacter character) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CharacterProfilePage(
          character: character,
          onStartChat: () {
            Navigator.of(context).pop();
            widget.onPick(character);
          },
        ),
      ),
    );
  }

  Future<void> _openEditor({AiCharacter? existing}) async {
    final result = await Navigator.of(context).push<CharacterEditResult>(
      MaterialPageRoute(
        builder: (_) => CharacterEditPage(existing: existing),
      ),
    );

    if (result == null || !mounted) return;

    switch (result) {
      case CharacterSaved(:final character):
        await widget.storage.add(character);

      case CharacterDeleted():
        if (existing != null) {
          await widget.storage.remove(existing.id);
        }
    }

    await _load();
  }

  Future<void> _deleteCharacter(AiCharacter c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบตัวละครนี้?'),
        content: Text('"${c.name}" จะถูกลบถาวร'),
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

    if (ok != true) return;

    await widget.storage.remove(c.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final sim = _sim;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primaryLight,
        title: const Text(
          'น้องซิม',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_myCharacters.isNotEmpty)
            IconButton(
              tooltip: 'ค้นหาตัวละคร',
              onPressed: _toggleSearch,
              icon: const Icon(Icons.search),
            ),
        ],
        bottom: _showSearch
            ? PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'ค้นหาตัวละครของคุณ',
                      hintStyle: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSub,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _query = ''),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // ================= หน้าซิม =================
                  _SimHeroCard(
                    character: sim,
                    onTap: () => _openProfile(sim),
                    onChat: () => widget.onPick(sim),
                  ),

                  const SizedBox(height: 28),

                  // ================= ตัวละครของฉัน =================
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ตัวละครของคุณ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                      if (_myCharacters.isNotEmpty)
                        Text(
                          '${_myCharacters.length} ตัว',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSub,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_filteredMine.isEmpty)
                    _emptyMyCharacters(hasQuery: _query.isNotEmpty)
                  else
                    ...[
                      for (final c in _filteredMine)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MyCharacterCard(
                            character: c,
                            onTap: () => _openProfile(c),
                            onEdit: () => _openEditor(existing: c),
                            onChat: () => widget.onPick(c),
                            onDelete: () => _deleteCharacter(c),
                          ),
                        ),
                    ],

                  const SizedBox(height: 4),

                  // ================= ปุ่มสร้างตัวละคร =================
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMain,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _openEditor(),
                    icon: const Icon(
                      Icons.add,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'สร้างตัวละครใหม่',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  bool _showSearch = false;

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) _query = '';
    });
  }

  Widget _emptyMyCharacters({bool hasQuery = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            hasQuery ? '🔍' : '✨',
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 10),
          Text(
            hasQuery ? 'ไม่พบตัวละคร' : 'ยังไม่มีตัวละครของคุณ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery
                ? 'ลองเปลี่ยนคำค้นหา'
                : 'กดปุ่มด้านล่างเพื่อสร้างตัวละครที่คุยด้วยโทนของตัวเอง',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSub,
            ),
          ),
        ],
      ),
    );
  }
}

/// การ์ดน้องซิมขนาดใหญ่
class _SimHeroCard extends StatelessWidget {
  final AiCharacter character;
  final VoidCallback onTap;
  final VoidCallback onChat;

  const _SimHeroCard({
    required this.character,
    required this.onTap,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(character.colorValue);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // ส่วนบนสี+อีโมจิ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 26),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(color, Colors.white, 0.25)!,
                      color,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(19),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      character.emoji,
                      style: const TextStyle(fontSize: 62),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        character.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      character.tagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // ส่วนล่าง
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (character.description.isNotEmpty)
                      Text(
                        character.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: AppColors.textMain,
                        ),
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (character.tags.isNotEmpty) ...[
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final t in character.tags.take(3))
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color
                                          .withValues(alpha: 0.14),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      t,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color.lerp(
                                          color,
                                          Colors.black,
                                          0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.brown,
                          ),
                          onPressed: onChat,
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: Colors.brown,
                          ),
                          label: const Text(
                            'เริ่มแชท',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.brown,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// การ์ดตัวละครที่ผู้ใช้สร้าง
class _MyCharacterCard extends StatelessWidget {
  final AiCharacter character;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onChat;
  final VoidCallback onDelete;

  const _MyCharacterCard({
    required this.character,
    required this.onTap,
    required this.onEdit,
    required this.onChat,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(character.colorValue);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
                alignment: Alignment.center,
                child: Text(
                  character.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            character.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                        if (character.hasPersona)
                          const Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: Icon(
                              Icons.auto_awesome,
                              size: 13,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      character.tagline.isEmpty
                          ? 'ยังไม่มีคำโปรย'
                          : character.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'แก้ไข',
                icon: const Icon(Icons.edit_outlined, size: 19),
                color: AppColors.textSub,
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'เริ่มแชท',
                icon: const Icon(Icons.chat_bubble_outline, size: 19),
                color: AppColors.primary,
                onPressed: onChat,
              ),
              IconButton(
                tooltip: 'ลบ',
                icon: const Icon(Icons.delete_outline, size: 19),
                color: AppColors.textSub,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}