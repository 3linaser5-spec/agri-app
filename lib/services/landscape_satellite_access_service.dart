import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LandscapeSatelliteEntitlement {
  final bool active;
  final double maxFeddan;

  const LandscapeSatelliteEntitlement({
    required this.active,
    required this.maxFeddan,
  });

  bool allows(double feddan) => active && feddan <= maxFeddan;
}

class LandscapeSatelliteAccessService {
  LandscapeSatelliteAccessService._();
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const serviceId = 'irrigation_landscape_satellite';

  static DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _firestore
          .collection('service_entitlements')
          .doc(uid)
          .collection('services')
          .doc(serviceId);

  static LandscapeSatelliteEntitlement _parse(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final rawMax = data['max_feddan'];
    final maxFeddan = rawMax is num
        ? rawMax.toDouble()
        : double.tryParse(rawMax?.toString() ?? '') ?? 0;
    return LandscapeSatelliteEntitlement(
      active: data['status'] == 'active',
      maxFeddan: maxFeddan < 0 ? 0 : maxFeddan,
    );
  }

  static Stream<bool> watchAccess() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _ref(uid).snapshots().map((snapshot) => _parse(snapshot).active);
  }

  static Stream<LandscapeSatelliteEntitlement> watchEntitlement() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(
        const LandscapeSatelliteEntitlement(active: false, maxFeddan: 0),
      );
    }
    return _ref(uid).snapshots().map(_parse);
  }

  static Future<LandscapeSatelliteEntitlement> getEntitlement(String uid) async =>
      _parse(await _ref(uid).get());

  static Future<LandscapeSatelliteEntitlement> getCurrentEntitlement() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const LandscapeSatelliteEntitlement(active: false, maxFeddan: 0);
    }
    return getEntitlement(uid);
  }

  static Future<bool> hasAccess(String uid) async =>
      (await getEntitlement(uid)).active;

  static Future<void> setAccess({
    required String uid,
    required bool enabled,
    double maxFeddan = 0,
  }) async {
    if (uid.trim().isEmpty) throw ArgumentError.value(uid, 'uid', 'مطلوب');
    if (!maxFeddan.isFinite || maxFeddan < 0) {
      throw ArgumentError.value(maxFeddan, 'maxFeddan', 'قيمة غير صالحة');
    }
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) throw StateError('سجّل الدخول بحساب الأدمن.');
    await _ref(uid).set({
      'service': serviceId,
      'status': enabled ? 'active' : 'revoked',
      'max_feddan': maxFeddan,
      'activated_at': FieldValue.serverTimestamp(),
      'activated_by': adminUid,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
