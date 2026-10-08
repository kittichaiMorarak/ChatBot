import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/character_api.dart';
import '../theme.dart';
import 'character_profile_page.dart';

/// หน้าเลือกตัวละครที่จะคุยด้วย
class CharacterListPage extends StatefulWidget {
  final CharacterApi api;

  /// เรียกเมื่อผู้ใช้เลือกตัวละคร
  final void Function(AiCharacter character) onPick;

  /// ตัวละครที่เลือกอยู่ตอนนี้ (ไฮไลต์ไว้)
  final String? currentId;

  const CharacterListPage({
    super.key,
    required this.api,
    required this.onPick,
    this.currentId,
  });

  @override
  State<CharacterListPage> createState() => _CharacterListPageState();
}

class _CharacterListPageState extends State<CharacterListPage> {
  List<AiCharacter> _all = [];
  bool _loading = true;

  String _query = '';
  String? _activeTag;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final list = await widget.api.loadCharacters();

      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (_) {
      // CharacterApi คืน fallback มาให้อยู่แล้ว
      if (!mounted) return;
      setState(() {
        _all = const [fallbackCharacter];
        _loading = false;
      });
    }
  }

  /// รวมแท็กทั้งหมด เรียงตามจำนวนครั้งที่พบ
  List<String> get _allTags {
    final counts = <String, int>{};

    for (final c in _all) {
      for (final t in c.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.map((e) => e.key).toList();
  }

  List<AiCharacter> get _filtered {
    var list = _all;

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.tagline.toLowerCase().contains(q) ||
            c.description.toLowerCase().contains(q) ||
            c.creator.toLowerCase().contains(q) ||
            c.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    if (_activeTag != null) {
      list = list.where((c) => c.tags.contains(_activeTag)).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight,
        title: const Text(
          'เลือกตัวละคร',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  // ช่องค้นหา
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาตัวละคร',
                          hintStyle: const TextStyle(
                            color: AppColors.textSub,
                          ),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() {
                                    _query = '';
                                  }),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // แถวแท็ก
                  if (_allTags.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _tagChip(null, 'ทั้งหมด'),
                            for (final tag in _allTags)
                              _tagChip(tag, tag),
                          ],
                        ),
                      ),
                    ),

                  // ผลลัพธ์
                  if (_filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔍', style: TextStyle(fontSize: 44)),
                            const SizedBox(height: 12),
                            Text(
                              'ไม่พบตัวละคร',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ลองเปลี่ยนคำค้นหรือเลือกแท็กอื่น',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          // การ์ดกว้างไม่เกิน 220
                          maxCrossAxisExtent: 220,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _CharacterCard(
                            character: _filtered[i],
                            selected:
                                _filtered[i].id == widget.currentId,
                            onTap: () =>
                                _openProfile(_filtered[i]),
                          ),
                          childCount: _filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _tagChip(String? value, String label) {
    final active = _activeTag == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: active,
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? Colors.brown : AppColors.textMain,
        ),
        onSelected: (_) => setState(() => _activeTag = value),
      ),
    );
  }

  void _openProfile(AiCharacter character) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CharacterProfilePage(
          character: character,
          isCurrent: character.id == widget.currentId,
          onStartChat: () {
            Navigator.of(context).pop();
            widget.onPick(character);
          },
        ),
      ),
    );
  }
}

/// การ์ดตัวละครใน grid
class _CharacterCard extends StatelessWidget {
  final AiCharacter character;
  final bool selected;
  final VoidCallback onTap;

  const _CharacterCard({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(character.colorValue);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 2.5 : 1,
            ),
          ),
          // ตัดให้พื้นหลังเหลี่ยมมนบนสีของตัวละคร
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ส่วนบน = สีประจำตัวละคร + อีโมจิ (แทนรูป)
              // ใช้ Container ซึ่งมี child เสมอ (ColoredBox ไม่มี child
              // จะได้ขนาดเป็นศูนย์และไม่ paint สีเลย)
              Expanded(
                flex: 5,
                child: Container(
                  color: color,
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          character.emoji,
                          style: const TextStyle(fontSize: 46),
                        ),
                      ),
                      if (selected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ส่วนล่าง = ชื่อ + tagline + แท็กแรก
              Expanded(
                flex: 4,
                child: Container(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          character.shortName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Text(
                            character.tagline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: AppColors.textSub,
                            ),
                          ),
                        ),
                        if (character.tags.isNotEmpty)
                          Text(
                            '#${character.tags.first}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSub,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}