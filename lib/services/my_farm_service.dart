import 'package:cloud_firestore/cloud_firestore.dart';
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
      print('❌ خطأ في حفظ البرنامج: $e');
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
      print('❌ خطأ في جلب البرنامج: $e');
      return null;
    }
  }

  // ✅ حذف برنامج
  static Future<bool> deleteProgram(String id) async {
    try {
      await _firestore.collection('my_farm').doc(id).delete();
      return true;
    } catch (e) {
      print('❌ خطأ في حذف البرنامج: $e');
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
      print('❌ خطأ في تحديث الحالة: $e');
      return false;
    }
  }
}
