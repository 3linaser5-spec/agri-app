import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calculator_models.dart';

class CalculatorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ======== الأقسام ========
  static Future<List<CalculatorSection>> getSections() async {
    try {
      final snapshot = await _firestore
          .collection('calculator_sections')
          .orderBy('order')
          .get();
      return snapshot.docs
          .map((doc) => CalculatorSection.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ خطأ في جلب الأقسام: $e');
      return [];
    }
  }

  // ======== القوالب ========
  static Future<List<CalculatorTemplate>> getTemplatesBySection(
      String sectionId) async {
    try {
      final snapshot = await _firestore
          .collection('calculator_templates')
          .where('section_id', isEqualTo: sectionId)
          .get();
      return snapshot.docs
          .map((doc) => CalculatorTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ خطأ في جلب القوالب: $e');
      return [];
    }
  }

  static Future<CalculatorTemplate?> getTemplate(String id) async {
    try {
      final doc =
          await _firestore.collection('calculator_templates').doc(id).get();
      if (!doc.exists) return null;
      return CalculatorTemplate.fromFirestore(doc);
    } catch (e) {
      print('❌ خطأ في جلب القالب: $e');
      return null;
    }
  }

  // ======== إضافة قالب جديد ========
  static Future<String?> addTemplate({
    required String sectionId,
    required String name,
    required String emoji,
    required String description,
    required String areaUnit,
    required String areaUnitLabel,
    List<Map<String, dynamic>> fields = const [],
    List<Map<String, dynamic>> tasks = const [],
    List<Map<String, dynamic>> materials = const [],
    Map<String, dynamic> financial = const {},
  }) async {
    try {
      final docRef = await _firestore.collection('calculator_templates').add({
        'section_id': sectionId,
        'name': name,
        'emoji': emoji,
        'description': description,
        'area_unit': areaUnit,
        'area_unit_label': areaUnitLabel,
        'fields': fields,
        'tasks': tasks,
        'materials': materials,
        'financial': financial,
        'created_at': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('❌ خطأ في إضافة القالب: $e');
      return null;
    }
  }

  // ======== تعديل قالب ========
  static Future<bool> updateTemplate(
      String id, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('calculator_templates')
          .doc(id)
          .update(data);
      return true;
    } catch (e) {
      print('❌ خطأ في تعديل القالب: $e');
      return false;
    }
  }

  // ======== حذف قالب ========
  static Future<bool> deleteTemplate(String id) async {
    try {
      await _firestore
          .collection('calculator_templates')
          .doc(id)
          .delete();
      return true;
    } catch (e) {
      print('❌ خطأ في حذف القالب: $e');
      return false;
    }
  }

  // ======== التحقق من الأدمن ========
  static const List<String> adminEmails = [
    '01284172047@agri-app.local',
  ];

  static bool isAdmin(String? email) {
    if (email == null) return false;
    return adminEmails.contains(email);
  }
}
