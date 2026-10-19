import 'package:flutter/material.dart';
import '../../models/encyclopedia_model.dart';
import '../../services/encyclopedia_service.dart';
import 'encyclopedia_item_editor_screen.dart';
import '../../utils/color_utils.dart';

class EncyclopediaItemsScreen extends StatefulWidget {
  final EncyclopediaSection section;
  const EncyclopediaItemsScreen({super.key, required this.section});

  @override
  State<EncyclopediaItemsScreen> createState() =>
      _EncyclopediaItemsScreenState();
}

class _EncyclopediaItemsScreenState extends State<EncyclopediaItemsScreen> {
  Color _hexToColor(String hex) => ColorUtils.fromHex(hex);

  Future<void> _confirmDelete(
      BuildContext context, EncyclopediaItem item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف العنصر'),
          content: Text('هل أنت متأكد من حذف "${item.title}"؟'),
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

    if (confirm != true) return;
    if (!context.mounted) return;

    // ✅ إظهار مؤشر تحميل أثناء الحذف
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool ok = false;
    try {
      ok = await EncyclopediaService.deleteItem(item.id);
    } catch (e) {
      debugPrint('❌ فشل الحذف: $e');
    } finally {
      // ✅ نقفل الـ Loading في finally (حتى لو الشاشة اتقفلت)
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '✅ تم حذف العنصر' : '❌ فشل الحذف'),
        backgroundColor: ok ? const Color(0xFF047857) : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final color = _hexToColor(section.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${section.emoji} ${section.name}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EncyclopediaItemEditorScreen(
                sectionId: section.id,
                sectionName: section.name,
                sectionColor: color,
              ),
            ),
          );
        },
        backgroundColor: color,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('عنصر جديد', style: TextStyle(color: Colors.white)),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<List<EncyclopediaItem>>(
          // ✅ نمرر الـ Stream مباشرة، عشان يتحدث مع الـ sectionId
          stream: EncyclopediaService.getItemsStream(section.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('حدث خطأ: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87)),
                ),
              );
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              // ✅ نلفها في ListView عشان الـ Scroll يشتغل
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox,
                              size: 100, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('لا توجد عناصر في هذا القسم',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 8),
                          Text('دوس "عنصر جديد" لتبدأ',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[400] : Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                return Card(
                  color: isDark ? const Color(0xFF1E1E1E) : null,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            IconLibrary.availableIcons[item.icon] ?? '📄',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isDark ? Colors.white : Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('#${item.order}',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: color)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle.isEmpty
                                    ? 'بدون تصنيف'
                                    : item.subtitle,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.list,
                                      size: 12,
                                      color: isDark ? Colors.grey[500] : Colors.grey),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${item.sections.length} فقرة',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.grey[500] : Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Color(0xFF047857), size: 22),
                          tooltip: 'تعديل',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EncyclopediaItemEditorScreen(
                                  sectionId: section.id,
                                  sectionName: section.name,
                                  sectionColor: color,
                                  existingItem: item,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red, size: 22),
                          tooltip: 'حذف',
                          onPressed: () => _confirmDelete(context, item),
                        ),
                      ],
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
}
