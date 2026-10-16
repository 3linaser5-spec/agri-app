import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/encyclopedia_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class EncyclopediaService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // تحويل الدوكيومنتس مع تجاهل التالف منها
  static List<EncyclopediaSection> _parseSections(
      List<QueryDocumentSnapshot> docs) {
    final result = <EncyclopediaSection>[];
    for (final doc in docs) {
      try {
        result.add(EncyclopediaSection.fromFirestore(doc));
      } catch (e) {
        debugPrint('❌ قسم تالف (${doc.id}): $e');
      }
    }
    return result;
  }

  static List<EncyclopediaItem> _parseItems(List<QueryDocumentSnapshot> docs) {
    final result = <EncyclopediaItem>[];
    for (final doc in docs) {
      try {
        result.add(EncyclopediaItem.fromFirestore(doc));
      } catch (e) {
        debugPrint('❌ عنصر تالف (${doc.id}): $e');
      }
    }
    return result;
  }

  // ============================================================
  //                     الأقسام (Sections)
  // ============================================================

  // جلب كل الأقسام مرتبة
  static Stream<List<EncyclopediaSection>> getSectionsStream() {
    return _firestore
        .collection('encyclopedia_sections')
        .orderBy('order')
        .snapshots()
        .map((snap) => _parseSections(snap.docs));
  }

  // جلب كل الأقسام (One-time)
  static Future<List<EncyclopediaSection>> getSections() async {
    try {
      final snapshot = await _firestore
          .collection('encyclopedia_sections')
          .orderBy('order')
          .get();
      return _parseSections(snapshot.docs);
    } catch (e) {
      debugPrint('❌ خطأ في جلب الأقسام: $e');
      return [];
    }
  }

  // جلب قسم واحد
  static Future<EncyclopediaSection?> getSection(String id) async {
    try {
      final doc = await _firestore
          .collection('encyclopedia_sections')
          .doc(id)
          .get();
      if (!doc.exists) return null;
      return EncyclopediaSection.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ خطأ في جلب القسم: $e');
      return null;
    }
  }

  // إضافة قسم جديد
  static Future<String?> addSection({
    required String name,
    required String emoji,
    required String color,
    required String description,
    int? order,
  }) async {
    try {
      // لو مفيش order، نحطه في الآخر
      int finalOrder = order ?? await _getNextSectionOrder();

      final docRef =
          await _firestore.collection('encyclopedia_sections').add({
        'name': name,
        'emoji': emoji,
        'color': color,
        'description': description,
        'order': finalOrder,
        'created_at': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('❌ خطأ في إضافة القسم: $e');
      return null;
    }
  }

  // أقصى عدد مستندات في استيراد واحد: حد Firestore للدفعة 500 عملية. أقل من
  // كده الاستيراد ذري (يا كله يتحفظ يا ولا حاجة).
  static const int maxImportDocs = 450;

  /// يستورد أقسام وعناصرها في دفعة واحدة (WriteBatch).
  /// [sections]: قائمة أقسام سبق التحقق منها وتطبيعها، كل قسم فيه
  /// name/emoji/color/description وقائمة items (title/subtitle/icon/content/
  /// sections/image_url). يرمي [ArgumentError] لو العدد أكبر من الحد.
  static Future<({int sections, int items})> importSections(
      List<Map<String, dynamic>> sections) async {
    var itemsTotal = 0;
    for (final s in sections) {
      itemsTotal += (s['items'] as List?)?.length ?? 0;
    }
    if (sections.length + itemsTotal > maxImportDocs) {
      throw ArgumentError(
          'الملف كبير (${sections.length + itemsTotal} عنصر). '
          'الحد الأقصى $maxImportDocs في المرة الواحدة، قسّمه لملفين.');
    }

    // ترتيب الأقسام بيتحسب مرة واحدة (كان بيتحسب بقراءة لكل قسم)
    var sectionOrder = await _getNextSectionOrder();
    final batch = _firestore.batch();

    for (final s in sections) {
      final sectionRef = _firestore.collection('encyclopedia_sections').doc();
      batch.set(sectionRef, {
        'name': s['name'],
        'emoji': s['emoji'],
        'color': s['color'],
        'description': s['description'],
        'order': sectionOrder++,
        'created_at': FieldValue.serverTimestamp(),
      });

      var itemOrder = 1;
      for (final it in (s['items'] as List? ?? const [])) {
        final item = it as Map<String, dynamic>;
        final itemRef = _firestore.collection('encyclopedia_items').doc();
        batch.set(itemRef, {
          'section_id': sectionRef.id,
          'title': item['title'],
          'subtitle': item['subtitle'],
          'icon': item['icon'],
          'content': item['content'],
          'sections': item['sections'],
          'image_url': item['image_url'],
          'order': itemOrder++,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    }

    // بدون نت الـ commit بيفضل معلّق، فنحط مهلة ونقول للمستخدم يراجع القائمة
    await batch.commit().timeout(const Duration(seconds: 25));
    return (sections: sections.length, items: itemsTotal);
  }

  // تعديل قسم
  static Future<bool> updateSection(
      String id, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('encyclopedia_sections')
          .doc(id)
          .update(data);
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في تعديل القسم: $e');
      return false;
    }
  }

  // حذف قسم (وكل العناصر اللي جواه)
  static Future<bool> deleteSection(String id) async {
    try {
      // 1. نمسح كل العناصر اللي جوه القسم
      final itemsSnapshot = await _firestore
          .collection('encyclopedia_items')
          .where('section_id', isEqualTo: id)
          .get();

      final docs = itemsSnapshot.docs;
      for (int i = 0; i < docs.length; i += 400) {
        final end = (i + 400 < docs.length) ? i + 400 : docs.length;
        final batch = _firestore.batch();
        for (int j = i; j < end; j++) {
          batch.delete(docs[j].reference);
        }
        await batch.commit();
      }

      // 2. نمسح القسم نفسه
      await _firestore.collection('encyclopedia_sections').doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في حذف القسم: $e');
      return false;
    }
  }

  // جلب رقم الترتيب التالي
  static Future<int> _getNextSectionOrder() async {
    try {
      final snapshot = await _firestore
          .collection('encyclopedia_sections')
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 1;
      final lastOrder = (snapshot.docs.first.data()['order'] as num?)?.toInt() ?? 0;
      return lastOrder + 1;
    } catch (e) {
      return 1;
    }
  }

  // ============================================================
  //                     العناصر (Items)
  // ============================================================

  // جلب عناصر قسم معين
  static Stream<List<EncyclopediaItem>> getItemsStream(String sectionId) {
    return _firestore
        .collection('encyclopedia_items')
        .where('section_id', isEqualTo: sectionId)
        .orderBy('order')
        .snapshots()
        .map((snap) => _parseItems(snap.docs));
  }

  // جلب عناصر قسم معين (One-time)
  static Future<List<EncyclopediaItem>> getItems(String sectionId) async {
    try {
      final snapshot = await _firestore
          .collection('encyclopedia_items')
          .where('section_id', isEqualTo: sectionId)
          .orderBy('order')
          .get();
      return _parseItems(snapshot.docs);
    } catch (e) {
      debugPrint('❌ خطأ في جلب العناصر: $e');
      return [];
    }
  }

  // جلب عنصر واحد
  static Future<EncyclopediaItem?> getItem(String id) async {
    try {
      final doc = await _firestore
          .collection('encyclopedia_items')
          .doc(id)
          .get();
      if (!doc.exists) return null;
      return EncyclopediaItem.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ خطأ في جلب العنصر: $e');
      return null;
    }
  }

  // إضافة عنصر جديد
  static Future<String?> addItem({
    required String sectionId,
    required String title,
    required String subtitle,
    required String icon,
    required String content,
    required List<Map<String, String>> sections,
    String? imageUrl,
    int? order,
  }) async {
    try {
      int finalOrder = order ?? await _getNextItemOrder(sectionId);

      final docRef = await _firestore.collection('encyclopedia_items').add({
        'section_id': sectionId,
        'title': title,
        'subtitle': subtitle,
        'icon': icon,
        'content': content,
        'sections': sections,
        'image_url': imageUrl,
        'order': finalOrder,
        'created_at': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('❌ خطأ في إضافة العنصر: $e');
      return null;
    }
  }

  // تعديل عنصر
  static Future<bool> updateItem(
      String id, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('encyclopedia_items')
          .doc(id)
          .update(data);
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في تعديل العنصر: $e');
      return false;
    }
  }

  // حذف عنصر
  static Future<bool> deleteItem(String id) async {
    try {
      await _firestore.collection('encyclopedia_items').doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في حذف العنصر: $e');
      return false;
    }
  }

  // جلب رقم ترتيب العنصر التالي في قسم
  static Future<int> _getNextItemOrder(String sectionId) async {
    try {
      final snapshot = await _firestore
          .collection('encyclopedia_items')
          .where('section_id', isEqualTo: sectionId)
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 1;
      final lastOrder = (snapshot.docs.first.data()['order'] as num?)?.toInt() ?? 0;
      return lastOrder + 1;
    } catch (e) {
      return 1;
    }
  }

  // ============================================================
  //          إحصائيات سريعة (للعرض في لوحة الأدمن)
  // ============================================================

  // عدد العناصر جوه كل قسم
  static Future<int> getItemsCount(String sectionId) async {
    try {
      final snapshot = await _firestore
          .collection('encyclopedia_items')
          .where('section_id', isEqualTo: sectionId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
