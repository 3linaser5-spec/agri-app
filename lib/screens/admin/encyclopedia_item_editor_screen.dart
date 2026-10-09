import 'package:flutter/material.dart';
import '../../models/encyclopedia_model.dart';
import '../../services/encyclopedia_service.dart';

class EncyclopediaItemEditorScreen extends StatefulWidget {
  final String sectionId;
  final String sectionName;
  final Color sectionColor;
  final EncyclopediaItem? existingItem;

  const EncyclopediaItemEditorScreen({
    super.key,
    required this.sectionId,
    required this.sectionName,
    required this.sectionColor,
    this.existingItem,
  });

  @override
  State<EncyclopediaItemEditorScreen> createState() =>
      _EncyclopediaItemEditorScreenState();
}

class _EncyclopediaItemEditorScreenState
    extends State<EncyclopediaItemEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _subtitleCtrl;
  late TextEditingController _contentCtrl;

  String _selectedIcon = 'eco';
  bool _saving = false;

  // قائمة الفقرات (title + content)
  final List<Map<String, TextEditingController>> _sections = [];

  bool get isEdit => widget.existingItem != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingItem;

    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _subtitleCtrl = TextEditingController(text: existing?.subtitle ?? '');
    _contentCtrl = TextEditingController(text: existing?.content ?? '');
    _selectedIcon = existing?.icon ?? 'eco';

    // تحميل الفقرات الموجودة
    if (existing != null && existing.sections.isNotEmpty) {
      for (var sec in existing.sections) {
        _sections.add({
          'title': TextEditingController(text: sec['title'] ?? ''),
          'content': TextEditingController(text: sec['content'] ?? ''),
        });
      }
    } else {
      // فقرة افتراضية
      _addSection();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _contentCtrl.dispose();
    for (var s in _sections) {
      s['title']?.dispose();
      s['content']?.dispose();
    }
    super.dispose();
  }

  void _addSection() {
    setState(() {
      _sections.add({
        'title': TextEditingController(),
        'content': TextEditingController(),
      });
    });
  }

  void _removeSection(int index) {
    if (_sections.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ لازم يكون فيه فقرة واحدة على الأقل'),
        ),
      );
      return;
    }
    setState(() {
      _sections[index]['title']?.dispose();
      _sections[index]['content']?.dispose();
      _sections.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // نفلتر الفقرات الفاضية
    final validSections = _sections
        .where((s) =>
            (s['title']?.text.trim().isNotEmpty ?? false) ||
            (s['content']?.text.trim().isNotEmpty ?? false))
        .map((s) => {
              'title': s['title']?.text.trim() ?? '',
              'content': s['content']?.text.trim() ?? '',
            })
        .toList();

    if (validSections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ الرجاء إضافة فقرة واحدة على الأقل'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    bool ok;

    if (isEdit) {
      ok = await EncyclopediaService.updateItem(
        widget.existingItem!.id,
        {
          'title': _titleCtrl.text.trim(),
          'subtitle': _subtitleCtrl.text.trim(),
          'icon': _selectedIcon,
          'content': _contentCtrl.text.trim(),
          'sections': validSections,
        },
      );
    } else {
      final id = await EncyclopediaService.addItem(
        sectionId: widget.sectionId,
        title: _titleCtrl.text.trim(),
        subtitle: _subtitleCtrl.text.trim(),
        icon: _selectedIcon,
        content: _contentCtrl.text.trim(),
        sections: validSections,
      );
      ok = id != null;
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? '✅ تم تعديل العنصر' : '✅ تم إضافة العنصر'),
          backgroundColor: const Color(0xFF047857),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ فشل الحفظ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'تعديل عنصر' : 'إضافة عنصر جديد',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: widget.sectionColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save, color: Colors.white),
            tooltip: 'حفظ',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ============ معلومات أساسية ============
              _buildSectionHeader('📌 المعلومات الأساسية'),

              const SizedBox(height: 12),

              // عنوان العنصر
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'العنوان *',
                  hintText: 'مثال: البياض الدقيقي',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'ادخل عنوان العنصر';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // التصنيف الفرعي
              TextFormField(
                controller: _subtitleCtrl,
                decoration: InputDecoration(
                  labelText: 'التصنيف الفرعي (اختياري)',
                  hintText: 'مثال: مرض فطري',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 16),

              // اختيار الأيقونة
              const Text('الأيقونة:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: IconLibrary.availableIcons.length,
                  itemBuilder: (context, i) {
                    final entry =
                        IconLibrary.availableIcons.entries.elementAt(i);
                    final key = entry.key;
                    final emoji = entry.value;
                    final isSelected = key == _selectedIcon;

                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedIcon = key),
                      child: Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.sectionColor.withOpacity(0.2)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? widget.sectionColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ============ الوصف الرئيسي ============
              _buildSectionHeader('📝 الوصف الرئيسي (اختياري)'),

              const SizedBox(height: 12),

              TextFormField(
                controller: _contentCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'اكتب وصف عام مختصر للعنصر (مثال: مرض فطري يصيب الأوراق...)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),

              const SizedBox(height: 24),

              // ============ الفقرات التفصيلية ============
              Row(
                children: [
                  Expanded(
                    child: _buildSectionHeader('📋 الفقرات التفصيلية'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addSection,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('فقرة جديدة',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.sectionColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // الفقرات
              ...List.generate(_sections.length, (i) {
                return _buildSectionCard(i);
              }),

              const SizedBox(height: 40),

              // زر الحفظ
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _saving
                      ? 'جاري الحفظ...'
                      : (isEdit ? 'حفظ التعديل' : 'إضافة العنصر'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.sectionColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============ Header Widget ============
  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: widget.sectionColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          right: BorderSide(color: widget.sectionColor, width: 4),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: widget.sectionColor,
        ),
      ),
    );
  }

  // ============ بطاقة فقرة ============
  Widget _buildSectionCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: widget.sectionColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text('${index + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: widget.sectionColor)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('فقرة ${index + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.delete,
                    color: Colors.red, size: 20),
                tooltip: 'حذف الفقرة',
                onPressed: () => _removeSection(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sections[index]['title'],
            decoration: InputDecoration(
              labelText: 'عنوان الفقرة',
              hintText: 'مثال: الأعراض / العلاج / الوقاية',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sections[index]['content'],
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'محتوى الفقرة',
              hintText: 'اكتب المحتوى هنا...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
