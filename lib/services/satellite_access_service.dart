import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SatelliteAccessRequest {
  final String uid;
  final String name;
  final String phone;
  final String status;
  final DateTime? requestedAt;

  const SatelliteAccessRequest({
    required this.uid,
    required this.name,
    required this.phone,
    required this.status,
    required this.requestedAt,
  });

  factory SatelliteAccessRequest.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final timestamp = data['created_at'];
    return SatelliteAccessRequest(
      uid: data['uid']?.toString() ?? document.id,
      name: data['name']?.toString() ?? 'مستخدم',
      phone: data['phone']?.toString() ?? '',
      status: data['status']?.toString() ?? 'pending',
      requestedAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class SatelliteAccessService {
  SatelliteAccessService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>> _request(String uid) =>
      _firestore.collection('satellite_access_requests').doc(uid);

  static DocumentReference<Map<String, dynamic>> _entitlement(String uid) =>
      _firestore
          .collection('service_entitlements')
          .doc(uid)
          .collection('services')
          .doc('satellite_monitoring');

  static String _takeCharacters(String value, int limit) =>
      String.fromCharCodes(value.runes.take(limit));

  static Stream<bool> watchAccess() {
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    return _entitlement(uid).snapshots().map(
      (snapshot) => snapshot.exists && snapshot.data()?['status'] == 'active',
    );
  }

  static Stream<String?> watchRequestStatus() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _request(
      uid,
    ).snapshots().map((snapshot) => snapshot.data()?['status']?.toString());
  }

  static Stream<List<SatelliteAccessRequest>> watchPendingRequests() =>
      _firestore
          .collection('satellite_access_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(SatelliteAccessRequest.fromDocument).toList()
                  ..sort(
                    (a, b) => (a.requestedAt ?? DateTime(1970)).compareTo(
                      b.requestedAt ?? DateTime(1970),
                    ),
                  ),
          );

  static Future<void> requestAccess() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولًا لإرسال الطلب.');
    final uid = user.uid;
    final access = await _entitlement(uid).get();
    if (access.exists && access.data()?['status'] == 'active') {
      throw StateError('خدمة مراقبة الأقمار مفعّلة لحسابك بالفعل.');
    }

    final requestRef = _request(uid);
    final existing = await requestRef.get();
    final existingStatus = existing.data()?['status']?.toString();
    if (existingStatus == 'pending') {
      throw StateError('طلبك قيد المراجعة بالفعل.');
    }
    if (existingStatus == 'approved') {
      throw StateError('سبق اعتماد طلبك؛ حدّث الشاشة أو تواصل مع الأدمن.');
    }

    // Legacy accounts may not have a profile document. They can still request
    // access using Firebase Auth details, with a safe display fallback.
    final profile = await _firestore.collection('users').doc(uid).get();
    final profileData = profile.data() ?? const <String, dynamic>{};
    final rawName = profileData['name']?.toString().trim().isNotEmpty == true
        ? profileData['name'].toString().trim()
        : user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'مستخدم التطبيق';
    final rawPhone = profileData['phone']?.toString().trim().isNotEmpty == true
        ? profileData['phone'].toString().trim()
        : user.phoneNumber?.trim() ?? '';
    final name = _takeCharacters(rawName, 100);
    final phone = _takeCharacters(rawPhone, 32);

    await requestRef.set({
      'uid': uid,
      'name': name,
      'phone': phone,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> approveRequest(String uid) async {
    final adminUid = _uid;
    if (adminUid == null) throw StateError('سجّل الدخول بحساب الأدمن.');
    final requestRef = _request(uid);
    final request = await requestRef.get();
    if (!request.exists || request.data()?['status'] != 'pending') {
      throw StateError('الطلب لم يعد قيد المراجعة. حدّث القائمة.');
    }

    final batch = _firestore.batch();
    batch.update(requestRef, {
      'status': 'approved',
      'reviewed_at': FieldValue.serverTimestamp(),
      'reviewed_by': adminUid,
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.set(_entitlement(uid), {
      'service': 'satellite_monitoring',
      'status': 'active',
      'activated_at': FieldValue.serverTimestamp(),
      'activated_by': adminUid,
      'updated_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> rejectRequest(String uid) async {
    final adminUid = _uid;
    if (adminUid == null) throw StateError('سجّل الدخول بحساب الأدمن.');
    final requestRef = _request(uid);
    final request = await requestRef.get();
    if (!request.exists || request.data()?['status'] != 'pending') {
      throw StateError('الطلب لم يعد قيد المراجعة. حدّث القائمة.');
    }
    await requestRef.update({
      'status': 'rejected',
      'reviewed_at': FieldValue.serverTimestamp(),
      'reviewed_by': adminUid,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
