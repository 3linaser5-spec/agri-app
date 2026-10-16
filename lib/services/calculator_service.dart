import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calculator_models.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class CalculatorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // تحويل المستندات واحد واحد: مستند تالف يتخطّى بدل ما يخفي كل القسم
  static List<T> _parseDocs<T>(
    List<QueryDocumentSnapshot> docs,
    T Function(DocumentSnapshot) parse,
    String what,
  ) {
    final result = <T>[];
    for (final doc in docs) {
      try {
        result.add(parse(doc));
      } catch (e) {
        debugPrint('❌ $what تالف (${doc.id}): $e');
      }
    }
    return result;
  }

  // ======== الأقسام ========
  static Future<List<CalculatorSection>> getSections() async {
    try {
      final snapshot = await _firestore
          .collection('calculator_sections')
          .orderBy('order')
          .get();
      return _parseDocs(snapshot.docs, CalculatorSection.fromFirestore, 'قسم');
    } catch (e) {
      debugPrint('❌ خطأ في جلب الأقسام: $e');
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
      return _parseDocs(
          snapshot.docs, CalculatorTemplate.fromFirestore, 'قالب');
    } catch (e) {
      debugPrint('❌ خطأ في جلب القوالب: $e');
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
      debugPrint('❌ خطأ في جلب القالب: $e');
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
      debugPrint('❌ خطأ في إضافة القالب: $e');
      return null;
    }
  }

  // ======== تعديل قالب ========
  static Future<bool> updateTemplate(
      String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('calculator_templates').doc(id).update({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في تعديل القالب: $e');
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
      debugPrint('❌ خطأ في حذف القالب: $e');
      return false;
    }
  }

  // ======== التحقق من الأدمن ========
  static const List<String> adminEmails = AppConfig.adminEmails;

  static bool isAdmin(String? email) {
    if (email == null) return false;
    return adminEmails.contains(email);
  }
}
