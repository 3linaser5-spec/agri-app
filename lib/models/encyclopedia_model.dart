import 'package:cloud_firestore/cloud_firestore.dart';

// ============= قسم في الموسوعة =============
class EncyclopediaSection {
  final String id;
  final String name;
  final String emoji;
  final String color; // hex color
  final String description;
  final int order;
  final DateTime createdAt;

  EncyclopediaSection({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.description,
    required this.order,
    required this.createdAt,
  });

  factory EncyclopediaSection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EncyclopediaSection(
      id: doc.id,
      name: data['name'] ?? '',
      emoji: data['emoji'] ?? '📚',
      color: data['color'] ?? '#047857',
      description: data['description'] ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'emoji': emoji,
        'color': color,
        'description': description,
        'order': order,
        'created_at': FieldValue.serverTimestamp(),
      };
}

// ============= عنصر جوه القسم =============
class EncyclopediaItem {
  final String id;
  final String sectionId;
  final String title;
  final String subtitle; // نوع/تصنيف
  final String icon; // اسم الأيقونة كـ string
  final String content; // المحتوى الأساسي
  final List<Map<String, String>> sections; // [{title, content}]
  final String? imageUrl;
  final int order;
  final DateTime createdAt;

  EncyclopediaItem({
    required this.id,
    required this.sectionId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.content,
    required this.sections,
    this.imageUrl,
    required this.order,
    required this.createdAt,
  });

  factory EncyclopediaItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EncyclopediaItem(
      id: doc.id,
      sectionId: data['section_id'] ?? '',
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      icon: data['icon'] ?? 'eco',
      content: data['content'] ?? '',
      sections: (data['sections'] as List<dynamic>? ?? [])
          .map((e) => Map<String, String>.from(e as Map))
          .toList(),
      imageUrl: data['image_url'],
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'section_id': sectionId,
        'title': title,
        'subtitle': subtitle,
        'icon': icon,
        'content': content,
        'sections': sections,
        'image_url': imageUrl,
        'order': order,
        'created_at': FieldValue.serverTimestamp(),
      };
}

// ============= مكتبة الأيقونات المتاحة =============
class IconLibrary {
  static const Map<String, String> availableIcons = {
    'eco': '🌱',
    'bug_report': '🐛',
    'grain': '🌾',
    'pest_control': '🐜',
    'local_florist': '🌸',
    'water_drop': '💧',
    'agriculture': '🚜',
    'security': '🛡️',
    'science': '🧪',
    'landscape': '🏞️',
    'grass': '🌿',
    'flutter_dash': '🦋',
    'emoji_events': '🏆',
    'article': '📰',
    'menu_book': '📖',
    'spa': '🌺',
    'forest': '🌳',
    'sunny': '☀️',
    'cloud': '☁️',
    'ac_unit': '❄️',
    'local_dining': '🍽️',
    'medication': '💊',
    'vaccines': '💉',
    'psychology': '🧠',
    'insights': '📊',
    'tips_and_updates': '💡',
  };
}
