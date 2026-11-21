import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LandscapeSatelliteAccessService {
  LandscapeSatelliteAccessService._();
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const serviceId = 'irrigation_landscape_satellite';

  static DocumentReference<Map<String,dynamic>> _ref(String uid) => _firestore.collection('service_entitlements').doc(uid).collection('services').doc(serviceId);
  static Stream<bool> watchAccess() { final uid=_auth.currentUser?.uid; if (uid == null) return Stream.value(false); return _ref(uid).snapshots().map((s) => s.data()?['status'] == 'active'); }
  static Future<bool> hasAccess(String uid) async => (await _ref(uid).get()).data()?['status'] == 'active';
  static Future<void> setAccess({required String uid, required bool enabled}) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw StateError('سجّل الدخول بحساب الأدمن.');
    await _ref(uid).set({'service':serviceId,'status':enabled ? 'active' : 'revoked','activated_at':FieldValue.serverTimestamp(),'activated_by':adminUid,'updated_at':FieldValue.serverTimestamp()}, SetOptions(merge:true));
  }
}
