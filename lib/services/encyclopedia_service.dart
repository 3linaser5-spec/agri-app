import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/encyclopedia_model.dart';

class EncyclopediaService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  //                     الأقسام (Sections)
  // ============================================================

  // جلب كل الأقسام مرتبة
  static Stream<List<EncyclopediaSection>> getSectionsStream() {
    return _firestore
        .collection('encyclopedia_sections')
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => EncyclopediaSection.fromFirestore(doc))
            .toList());
  }

  // جلب كل الأقسام (One-time)
  static Future<List<EncyclopediaSection>> getSections() async {
    try {
      final snapshot = await _firestore
          .collection('encyclopedia_sections')
          .orderBy('order')
          .get();
      return snapshot.docs
          .map((doc) => EncyclopediaSection.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ خطأ في جلب الأقسام: $e');
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
      print('❌ خطأ في جلب القسم: $e');
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
      print('❌ خطأ في إضافة القسم: $e');
      return null;
    }
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
      print('❌ خطأ في تعديل القسم: $e');
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

      for (var doc in itemsSnapshot.docs) {
        await doc.reference.delete();
      }

      // 2. نمسح القسم نفسه
      await _firestore.collection('encyclopedia_sections').doc(id).delete();
      return true;
    } catch (e) {
      print('❌ خطأ في حذف القسم: $e');
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
        .map((snap) => snap.docs
            .map((doc) => EncyclopediaItem.fromFirestore(doc))
            .toList());
  }

  // جلب عناصر قسم معين (One-time)
  static Future<List<EncyclopediaItem>> getItems(String sectionId) async {
    try {
      final snapshot = await _firestore
          .collection('encyclopedia_items')
          .where('section_id', isEqualTo: sectionId)
          .orderBy('order')
          .get();
      return snapshot.docs
          .map((doc) => EncyclopediaItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ خطأ في جلب العناصر: $e');
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
      print('❌ خطأ في جلب العنصر: $e');
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
      print('❌ خطأ في إضافة العنصر: $e');
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
      print('❌ خطأ في تعديل العنصر: $e');
      return false;
    }
  }

  // حذف عنصر
  static Future<bool> deleteItem(String id) async {
    try {
      await _firestore.collection('encyclopedia_items').doc(id).delete();
      return true;
    } catch (e) {
      print('❌ خطأ في حذف العنصر: $e');
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
