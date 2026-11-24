import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../../services/encyclopedia_service.dart';
import '../../models/encyclopedia_model.dart';
import '../../utils/color_utils.dart';


// ---------------- EncyclopediaScreen ----------------
class EncyclopediaScreen extends StatefulWidget {
  const EncyclopediaScreen({super.key});

  @override
  State<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends State<EncyclopediaScreen> {
  late final Stream<List<EncyclopediaSection>> _sectionsStream =
      EncyclopediaService.getSectionsStream();

  Color _hexToColor(String hex) => ColorUtils.fromHex(hex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموسوعة الزراعية',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<List<EncyclopediaSection>>(
          stream: _sectionsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('حدث خطأ في جلب البيانات'),
                ),
              );
            }

            final sections = snapshot.data ?? [];

            if (sections.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book, size: 100, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('الموسوعة قيد التطوير',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('سيتم إضافة المحتوى قريباً',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
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
                      borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EncyclopediaSectionView(section: section),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.1),
                            color.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(section.emoji,
                                style: const TextStyle(fontSize: 32)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(section.name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: color)),
                                const SizedBox(height: 4),
                                Text(
                                  section.description.isEmpty
                                      ? 'اضغط للاستكشاف'
                                      : section.description,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              size: 18, color: color),
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
}

// ---------------- EncyclopediaSectionView ----------------
class EncyclopediaSectionView extends StatefulWidget {
  final EncyclopediaSection section;
  const EncyclopediaSectionView({super.key, required this.section});

  @override
  State<EncyclopediaSectionView> createState() =>
      _EncyclopediaSectionViewState();
}

class _EncyclopediaSectionViewState extends State<EncyclopediaSectionView> {
  late final Stream<List<EncyclopediaItem>> _itemsStream =
      EncyclopediaService.getItemsStream(widget.section.id);

  EncyclopediaSection get section => widget.section;

  Color _hexToColor(String hex) => ColorUtils.fromHex(hex);

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(section.color);

    return Scaffold(
      appBar: AppBar(
        title: Text('${section.emoji} ${section.name}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<List<EncyclopediaItem>>(
          stream: _itemsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('لا يوجد محتوى في هذا القسم بعد',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildItemCard(context, item, color);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildItemCard(
      BuildContext context, EncyclopediaItem item, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            IconLibrary.availableIcons[item.icon] ?? '📄',
            style: const TextStyle(fontSize: 22),
          ),
        ),
        title: Text(item.title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: item.subtitle.isEmpty
            ? null
            : Text(item.subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (item.content.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(item.content,
                  style: const TextStyle(fontSize: 13, height: 1.7)),
            ),
            const SizedBox(height: 12),
          ],
          ...item.sections.map((sec) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sec['title'] ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(sec['content'] ?? '',
                      style: const TextStyle(fontSize: 13, height: 1.6)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
