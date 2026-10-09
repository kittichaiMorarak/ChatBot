import 'package:flutter/material.dart';

import '../models/character.dart';
import '../theme.dart';

/// ผลลัพธ์จากหน้าแก้ไขตัวละคร
sealed class CharacterEditResult {
  const CharacterEditResult();
}

/// บันทึกสำเร็จ
class CharacterSaved extends CharacterEditResult {
  final AiCharacter character;

  const CharacterSaved(this.character);
}

/// ผู้ใช้กดลบ
class CharacterDeleted extends CharacterEditResult {
  const CharacterDeleted();
}

/// หน้าสร้าง / แก้ไขตัวละคร
class CharacterEditPage extends StatefulWidget {
  /// ตัวเดิมที่จะแก้ไข (null = สร้างใหม่)
  final AiCharacter? existing;

  const CharacterEditPage({super.key, this.existing});

  @override
  State<CharacterEditPage> createState() => _CharacterEditPageState();
}

class _CharacterEditPageState extends State<CharacterEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _tagline;
  late final TextEditingController _creator;
  late final TextEditingController _quote;
  late final TextEditingController _description;
  late final TextEditingController _tags;
  late final TextEditingController _persona;

  late String _emoji;
  late int _colorValue;

  String? _error;

  @override
  void initState() {
    super.initState();

    final e = widget.existing;

    _name = TextEditingController(text: e?.name ?? '');
    _tagline = TextEditingController(text: e?.tagline ?? '');
    _creator = TextEditingController(text: e?.creator ?? '');
    _quote = TextEditingController(text: e?.quote ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _tags =
        TextEditingController(text: e?.tags.join(', ') ?? '');
    _persona = TextEditingController(text: e?.persona ?? '');

    _emoji = e?.emoji ?? '🎭';
    _colorValue = e?.colorValue ?? 0xFF7986CB;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _tagline,
      _creator,
      _quote,
      _description,
      _tags,
      _persona,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'ต้องใส่ชื่อตัวละคร');
      return;
    }

    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(8)
        .toList();

    final character = AiCharacter(
      // คง id เดิมถ้าแก้ไข ถ้าใหม่ให้สร้างใหม่
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      tagline: _tagline.text.trim(),
      emoji: _emoji,
      colorValue: _colorValue,
      creator: _creator.text.trim().isEmpty
          ? 'ผู้ใช้สร้างเอง'
          : _creator.text.trim(),
      quote: _quote.text.trim(),
      description: _description.text.trim(),
      tags: tags,
      stats: widget.existing?.stats ??
          const CharacterStats(
            worlds: 0,
            chats: 0,
            messages: 0,
            gifts: 0,
          ),
      greeting: widget.existing?.greeting,
      persona: _persona.text.trim(),
    );

    // ปิดหน้านี้พร้อมผลลัพธ์ ให้หน้าที่เปิดอยู่จัดการต่อ
    Navigator.of(context).pop(CharacterSaved(character));
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบตัวละครนี้?'),
        content: Text(
          '"${widget.existing!.name}" จะถูกลบถาวร',
        ),
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

    if (ok != true || !mounted) return;

    Navigator.of(context).pop(const CharacterDeleted());
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight,
        title: Text(
          editing ? 'แก้ไขตัวละคร' : 'สร้างตัวละคร',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ---------- ตัวอย่าง ----------
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(_colorValue),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _emoji,
                    style: const TextStyle(fontSize: 44),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _name.text.trim().isEmpty ? 'ยังไม่มีชื่อ' : _name.text.trim(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          _label('ชื่อตัวละคร *'),
          _field(_name, hint: 'เช่น น้องซิม, อาจารย์ใจดี'),

          _label('คำโปรยสั้น (แสดงใต้ชื่อ)'),
          _field(_tagline, hint: 'เช่น เพื่อนคุยสุดกวน • ออนไลน์'),

          _label('ผู้สร้าง'),
          _field(_creator, hint: 'เช่น @myhandle'),

          _label('คำคมของตัวละคร'),
          _field(_quote, hint: 'เช่น "ว่าแต่ไม่เอ่ย"'),

          _label('คำอธิบายตัวละคร'),
          _field(
            _description,
            hint: 'เล่าเรื่องย่อของตัวละครนี้',
            maxLines: 3,
          ),

          _label('แท็ก (คั่นด้วย , )'),
          _field(_tags, hint: 'เช่น ชาย, นักศึกษา, ตลก'),

          // ---------- เลือกอีโมจิ ----------
          _label('สัญลักษณ์'),
          _EmojiPicker(
            selected: _emoji,
            onChanged: (v) => setState(() => _emoji = v),
          ),

          // ---------- เลือกสี ----------
          _label('สีประจำตัวละคร'),
          _ColorPicker(
            selected: _colorValue,
            onChanged: (v) => setState(() => _colorValue = v),
          ),

          // ---------- persona ----------
          _label('บุคลิกและวิธีพูด (ไม่บังคับ)'),
          _field(
            _persona,
            hint:
                'เช่น\nคุณคือนักศึกษาแพทย์ พูดจริงจังสุภาพ\n'
                '- ตอบสั้น ๆ 2-3 ประโยค\n- ใช้ภาษาไทยเท่านั้น\n'
                '- ถ้าไม่รู้ให้บอกว่าไม่รู้',
            maxLines: 6,
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: AppColors.textMain,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ถ้าเว้นไว้ ตัวละครนี้จะใช้บุคลิกของน้องซิม\n'
                    'โมเดลเล็ก ๆ อย่าง gemma2 ทำตามกฎยาว ๆ ได้ไม่ค่อยดี\n'
                    'แนะนำเขียนสั้น ๆ 4-6 บรรทัด',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ---------- ปุ่ม ----------
          Row(
            children: [
              if (widget.existing != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('ลบ'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.brown,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _save,
                  icon: const Icon(
                    Icons.check,
                    color: Colors.brown,
                  ),
                  label: const Text(
                    'บันทึกตัวละคร',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: AppColors.textMain,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 13.5,
          color: AppColors.textSub,
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

/// ตัวเลือกอีโมจิ
class _EmojiPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _EmojiPicker({
    required this.selected,
    required this.onChanged,
  });

  static const _emojis = [
    '🎭', '🤖', '👻', '🐺', '🦊', '🐱', '🐉', '🩰',
    '⚔️', '🏹', '🔮', '💀', '👑', '🌙', '☀️', '🌸',
    '⭐', '🔥', '❄️', '🌊', '🎵', '📚', '⚗️', '🧪',
    '🚗', '✈️', '🎩', '🩹', '🦌', '🦢', '💎', '🖤',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in _emojis)
          GestureDetector(
            onTap: () => onChanged(e),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected == e
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected == e
                      ? AppColors.primary
                      : AppColors.border,
                  width: selected == e ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          ),
      ],
    );
  }
}

/// ตัวเลือกสี
class _ColorPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _ColorPicker({
    required this.selected,
    required this.onChanged,
  });

  static const _colors = [
    0xFF7986CB, 0xFF37474F, 0xFF5D4037, 0xFF8D6E63,
    0xFFAD1457, 0xFFC107, 0xFF00897B, 0xFF43A047,
    0xFF6D4C41, 0xFF7E57C2, 0xFFE53935, 0xFF1E88E5,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in _colors)
          GestureDetector(
            onTap: () => onChanged(c),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(c),
                border: selected == c
                    ? Border.all(color: AppColors.textMain, width: 3)
                    : null,
              ),
              child: selected == c
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}