import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/my_farm_model.dart';

class MyFarmService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ حفظ برنامج جديد
  static Future<String?> saveProgram(MyFarmProgram program) async {
    try {
      final ref = await _firestore
          .collection('my_farm')
          .add(program.toFirestore());
      return ref.id;
    } catch (e) {
      debugPrint('❌ خطأ في حفظ البرنامج: $e');
      return null;
    }
  }

  // ✅ جلب كل برامج المستخدم
  static Stream<List<MyFarmProgram>> getUserPrograms(String userId) {
    return _firestore
        .collection('my_farm')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MyFarmProgram.fromFirestore(doc))
            .toList());
  }

  // ✅ جلب برنامج واحد
  static Future<MyFarmProgram?> getProgram(String id) async {
    try {
      final doc = await _firestore.collection('my_farm').doc(id).get();
      if (!doc.exists) return null;
      return MyFarmProgram.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ خطأ في جلب البرنامج: $e');
      return null;
    }
  }

  // ✅ حذف برنامج
  static Future<bool> deleteProgram(String id) async {
    try {
      await _firestore.collection('my_farm').doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في حذف البرنامج: $e');
      return false;
    }
  }

  // ✅ تعليم مهمة كمنجزة / غير منجزة
  // arrayUnion/arrayRemove ذريين: لو الشاشة مفتوحة من جهازين مفيش تعليم بيضيع
  // (قراءة القائمة كلها وإعادة كتابتها كانت هتخلي آخر كاتب يمسح الباقي).
  // [allDone] = هل كل المهام بقت منجزة بعد التعديل؟ عشان نحدّث status معاها.
  static Future<bool> setTaskDone(
    String programId,
    int taskIndex,
    bool done, {
    required bool allDone,
  }) async {
    try {
      await _firestore.collection('my_farm').doc(programId).update({
        'done_tasks': done
            ? FieldValue.arrayUnion([taskIndex])
            : FieldValue.arrayRemove([taskIndex]),
        'status': allDone ? 'completed' : 'active',
      });
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في تحديث المهمة: $e');
      return false;
    }
  }

  // ✅ تحديث حالة البرنامج
  static Future<bool> updateStatus(String id, String status) async {
    try {
      await _firestore
          .collection('my_farm')
          .doc(id)
          .update({'status': status});
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في تحديث الحالة: $e');
      return false;
    }
  }
}
