import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/map_alert_model.dart';

class MapAlertService {
  MapAlertService._();
  static final _db = FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static CollectionReference<Map<String, dynamic>> _alerts(String uid) => _db.collection('users').doc(uid).collection('map_alerts');

  static Stream<List<MapAlert>> watchAlerts({String? fieldId}) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    Query<Map<String, dynamic>> query = _alerts(uid);
    if (fieldId != null) query = query.where('field_id', isEqualTo: fieldId);
    return query.snapshots().map((s) => s.docs.map(MapAlert.fromDocument).where((a) => !a.resolved && a.status != 'resolved').toList()..sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970))));
  }

  static Future<void> addInspectionNote({required String alertId, required String text}) async {
    final uid = _uid;
    if (uid == null) throw StateError('سجّل الدخول أولًا.');
    if (text.trim().isEmpty) throw ArgumentError('اكتب ملاحظة الفحص.');
    await _alerts(uid).doc(alertId).collection('inspection_notes').add({'text': text.trim(), 'created_at': FieldValue.serverTimestamp()});
  }

  static Future<void> updateStatus({required String alertId, required String status}) async {
    final uid = _uid;
    if (uid == null) throw StateError('سجّل الدخول أولًا.');
    if (!{'open', 'inspected', 'resolved'}.contains(status)) {
      throw ArgumentError('حالة التنبيه غير مدعومة.');
    }
    await _alerts(uid).doc(alertId).update({
      'status': status,
      'resolved': status == 'resolved',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
