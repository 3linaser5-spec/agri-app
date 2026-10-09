import 'package:flutter/material.dart';
import '../../models/encyclopedia_model.dart';
import '../../services/encyclopedia_service.dart';
import 'encyclopedia_items_screen.dart';

class EncyclopediaAdminScreen extends StatelessWidget {
  const EncyclopediaAdminScreen({super.key});

  // ✅ ألوان جاهزة للاختيار
  static const List<String> availableColors = [
    '#047857', // أخضر غامق
    '#10B981', // أخضر فاتح
    '#0EA5E9', // أزرق
    '#F59E0B', // برتقالي
    '#DC2626', // أحمر
    '#8B5CF6', // بنفسجي
    '#EC4899', // وردي
    '#78350F', // بني
    '#6366F1', // أزرق غامق
    '#14B8A6', // تركواز
  ];

  Color _hexToColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (e) {
      return const Color(0xFF047857);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الموسوعة',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, null),
        backgroundColor: const Color(0xFF047857),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('قسم جديد',
            style: TextStyle(color: Colors.white)),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<List<EncyclopediaSection>>(
          stream: EncyclopediaService.getSectionsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('حدث خطأ: ${snapshot.error}'),
                ),
              );
            }

            final sections = snapshot.data ?? [];

            if (sections.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_book,
                        size: 100, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('لا توجد أقسام بعد',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('دوس "قسم جديد" لتبدأ',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                final color = _hexToColor(section.color);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EncyclopediaItemsScreen(section: section),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(section.emoji,
                                style: const TextStyle(fontSize: 28)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(section.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('#${section.order}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: color)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  section.description.isEmpty
                                      ? 'بدون وصف'
                                      : section.description,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit,
                                color: Color(0xFF047857), size: 22),
                            tooltip: 'تعديل',
                            onPressed: () =>
                                _showAddEditDialog(context, section),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 22),
                            tooltip: 'حذف',
                            onPressed: () =>
                                _confirmDelete(context, section),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ============ Dialog إضافة / تعديل قسم ============
  void _showAddEditDialog(
      BuildContext context, EncyclopediaSection? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl =
        TextEditingController(text: existing?.description ?? '');
    String emoji = existing?.emoji ?? '📚';
    String color = existing?.color ?? availableColors.first;
    bool saving = false;

    // قائمة إيموجيز للاختيار السريع
    final emojis = [
      '📚', '🐛', '🌾', '🌱', '🌿', '🌺', '🌸', '🍅', '🥕', '🍎',
      '🍊', '🌴', '🫒', '🐄', '🐔', '🐟', '🏠', '🌻', '🍄', '🐝',
      '💧', '🧪', '🛡️', '🚜', '📰', '📖', '💡', '🏆', '☀️', '❄️'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text(isEdit ? 'تعديل قسم' : 'إضافة قسم جديد',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الاسم
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم القسم',
                      hintText: 'مثال: أمراض النبات',
                      prefixIcon: const Icon(Icons.label),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // الوصف
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'الوصف (اختياري)',
                      hintText: 'مثال: كل أمراض النباتات الشائعة',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // اختيار الإيموجي
                  const Text('الإيموجي:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    height: 55,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: emojis.length,
                      itemBuilder: (context, i) {
                        final e = emojis[i];
                        final isSelected = e == emoji;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => emoji = e),
                          child: Container(
                            width: 45,
                            height: 45,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _hexToColor(color).withOpacity(0.2)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? _hexToColor(color)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(e,
                                style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // اختيار اللون
                  const Text('اللون:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableColors.map((c) {
                      final isSelected = c == color;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => color = c),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _hexToColor(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // معاينة
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _hexToColor(color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: _hexToColor(color).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            nameCtrl.text.isEmpty
                                ? 'اسم القسم'
                                : nameCtrl.text,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _hexToColor(color)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('⚠️ الرجاء إدخال اسم القسم')),
                          );
                          return;
                        }

                        setDialogState(() => saving = true);

                        bool ok;
                        if (isEdit) {
                          ok = await EncyclopediaService.updateSection(
                            existing.id,
                            {
                              'name': nameCtrl.text.trim(),
                              'emoji': emoji,
                              'color': color,
                              'description': descCtrl.text.trim(),
                            },
                          );
                        } else {
                          final id = await EncyclopediaService.addSection(
                            name: nameCtrl.text.trim(),
                            emoji: emoji,
                            color: color,
                            description: descCtrl.text.trim(),
                          );
                          ok = id != null;
                        }

                        if (!context.mounted) return;
                        setDialogState(() => saving = false);

                        if (ok) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEdit
                                  ? '✅ تم تعديل القسم'
                                  : '✅ تم إضافة القسم'),
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
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                ),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(isEdit ? 'حفظ التعديل' : 'إضافة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ تأكيد الحذف ============
  Future<void> _confirmDelete(
      BuildContext context, EncyclopediaSection section) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف القسم'),
          content: Text(
              'هل أنت متأكد من حذف قسم "${section.name}"؟\n\n⚠️ سيتم حذف كل العناصر اللي جواه.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final ok = await EncyclopediaService.deleteSection(section.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? '✅ تم حذف القسم وكل عناصره'
                : '❌ فشل الحذف'),
            backgroundColor: ok ? const Color(0xFF047857) : Colors.red,
          ),
        );
      }
    }
  }
}
