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
  late TextEditingController _imageCtrl;

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
    _imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
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
    _imageCtrl.dispose();
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
    final removed = _sections[index];
    setState(() {
      _sections.removeAt(index);
    });
    // الـ controllers بتتخلص منها بعد ما الإطار يترسم من غير الفقرة دي،
    // وإلا الـ TextField لسه ممكن يستخدمها وهي متخلص منها
    WidgetsBinding.instance.addPostFrameCallback((_) {
      removed['title']?.dispose();
      removed['content']?.dispose();
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

    // العنصر لازم يكون له محتوى: وصف رئيسي أو فقرة واحدة على الأقل
    if (validSections.isEmpty && _contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ اكتب وصف رئيسي أو أضف فقرة واحدة على الأقل'),
        ),
      );
      return;
    }

    final imageUrl = _imageCtrl.text.trim();

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
          'image_url': imageUrl.isEmpty ? null : imageUrl,
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
        imageUrl: imageUrl.isEmpty ? null : imageUrl,
      );
      ok = id != null;
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
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

              const SizedBox(height: 12),

              // رابط صورة (اختياري)
              TextFormField(
                controller: _imageCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'رابط صورة (اختياري)',
                  hintText: 'https://...',
                  prefixIcon: const Icon(Icons.image),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  final u = Uri.tryParse(t);
                  final ok = u != null &&
                      (u.scheme == 'http' || u.scheme == 'https') &&
                      u.host.isNotEmpty;
                  return ok ? null : 'الرابط لازم يبدأ بـ http أو https';
                },
              ),

              const SizedBox(height: 16),

              // اختيار الأيقونة
              const Text('الأيقونة:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              SizedBox(
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
                              ? widget.sectionColor.withValues(alpha: 0.2)
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
        color: widget.sectionColor.withValues(alpha: 0.1),
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
      key: ObjectKey(_sections[index]),
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
                  color: widget.sectionColor.withValues(alpha: 0.15),
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
