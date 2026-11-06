import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// بيانات استحقاق مراقبة الأقمار الصناعية؛ التفعيل والمدة يحددهما الأدمن.
class SatelliteEntitlement {
  const SatelliteEntitlement({
    required this.uid,
    required this.status,
    required this.priceEgp,
    required this.maxFields,
    required this.maxAnalysesPerMonth,
    required this.maxAreaFeddan,
    this.startsAt,
    this.expiresAt,
  });

  final String uid;
  final String status;
  final num priceEgp;
  final int maxFields;
  final int maxAnalysesPerMonth;
  final double maxAreaFeddan;
  final DateTime? startsAt;
  final DateTime? expiresAt;

  bool get isActive =>
      status == 'active' &&
      expiresAt != null &&
      expiresAt!.isAfter(DateTime.now());

  factory SatelliteEntitlement.fromMap(Map<String, dynamic> data) {
    DateTime? date(dynamic value) => value is Timestamp ? value.toDate() : null;

    return SatelliteEntitlement(
      uid: data['uid'] as String? ?? '',
      status: data['status'] as String? ?? 'inactive',
      priceEgp: data['priceEgp'] as num? ?? 0,
      maxFields: (data['maxFields'] as num?)?.toInt() ?? 1,
      maxAnalysesPerMonth: (data['maxAnalysesPerMonth'] as num?)?.toInt() ?? 0,
      maxAreaFeddan: (data['maxAreaFeddan'] as num?)?.toDouble() ?? 0,
      startsAt: date(data['startsAt']),
      expiresAt: date(data['expiresAt']),
    );
  }
}

class SatelliteField {
  const SatelliteField({
    required this.id,
    required this.name,
    required this.vertices,
    required this.areaFeddan,
    required this.lastAnalysisStatus,
    this.lastAnalysisError,
  });

  final String id;
  final String name;
  final List<Map<String, double>> vertices;
  final double areaFeddan;
  final String lastAnalysisStatus;
  final String? lastAnalysisError;

  factory SatelliteField.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawVertices = data['vertices'];
    final vertices = rawVertices is List
        ? rawVertices.whereType<Map>().map((point) {
            return <String, double>{
              'lat': (point['lat'] as num).toDouble(),
              'lng': (point['lng'] as num).toDouble(),
            };
          }).toList()
        : <Map<String, double>>[];

    return SatelliteField(
      id: doc.id,
      name: data['name'] as String? ?? 'حقل بدون اسم',
      vertices: vertices,
      areaFeddan: (data['areaFeddan'] as num?)?.toDouble() ?? 0,
      lastAnalysisStatus: data['lastAnalysisStatus'] as String? ?? 'idle',
      lastAnalysisError: data['lastAnalysisError'] as String?,
    );
  }
}

class SatelliteNdviSample {
  const SatelliteNdviSample({
    required this.mean,
    required this.from,
    required this.to,
    required this.sampleCount,
  });

  final double mean;
  final DateTime from;
  final DateTime to;
  final int sampleCount;

  factory SatelliteNdviSample.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    DateTime readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      throw const FormatException('صيغة تاريخ NDVI غير صالحة.');
    }

    return SatelliteNdviSample(
      mean: (data['mean'] as num).toDouble(),
      from: readDate(data['from']),
      to: readDate(data['to']),
      sampleCount: (data['sampleCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class SatelliteAccessService {
  SatelliteAccessService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _accessRef(String uid) =>
      _firestore.collection('satellite_access').doc(uid);

  DocumentReference<Map<String, dynamic>> _requestRef(String uid) =>
      _firestore.collection('satellite_access_requests').doc(uid);

  Stream<SatelliteEntitlement?> watchEntitlement(String uid) {
    return _accessRef(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : SatelliteEntitlement.fromMap(data);
    });
  }

  Stream<Map<String, dynamic>?> watchRequest(String uid) {
    return _requestRef(uid).snapshots().map((snapshot) => snapshot.data());
  }

  /// يسجل طلباً واحداً لكل حساب؛ لا يستطيع التطبيق تفعيل الاشتراك بنفسه.
  Future<void> requestActivation(String uid) async {
    final request = _requestRef(uid);
    final current = await request.get();
    if (current.exists) {
      final status = current.data()?['status'];
      if (status == 'pending') return;
      if (status == 'rejected' || status == 'activated') {
        if (status == 'activated') {
          final accessSnapshot = await _accessRef(uid).get();
          final expiresAt = accessSnapshot.data()?['expiresAt'];
          if (expiresAt is Timestamp &&
              expiresAt.toDate().isAfter(DateTime.now())) {
            throw StateError('اشتراكك ما زال سارياً.');
          }
        }
        await request.update({
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      throw StateError(
        'يوجد طلب سابق لهذا الحساب. تواصل مع الإدارة لتجديد الطلب.',
      );
    }

    await request.set({
      'uid': uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<SatelliteField>> watchFields(String uid) {
    return _firestore
        .collection('satellite_fields')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SatelliteField.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<List<SatelliteNdviSample>> watchNdviHistory(String fieldId) {
    return _firestore
        .collection('satellite_fields')
        .doc(fieldId)
        .collection('ndvi_history')
        .orderBy('from', descending: true)
        .limit(12)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SatelliteNdviSample.fromDocument)
              .toList(growable: false),
        );
  }

  Future<bool> requestNdviAnalysis(String fieldId) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('requestSatelliteNdvi');
    final result = await callable.call<Map<String, dynamic>>({
      'fieldId': fieldId,
    });
    return result.data['confirmationPending'] == true;
  }

  Future<double> saveField({
    required String uid,
    String? fieldId,
    required String name,
    required List<Map<String, double>> vertices,
  }) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('saveSatelliteField');
    final result = await callable.call<Map<String, dynamic>>({
      'fieldId': fieldId,
      'name': name.trim(),
      'vertices': vertices,
    });
    final data = result.data;
    return (data['areaFeddan'] as num).toDouble();
  }

  Future<void> deleteField(String fieldId) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('deleteSatelliteField');
    await callable.call<Map<String, dynamic>>({'fieldId': fieldId});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPendingRequests() {
    return _firestore
        .collection('satellite_access_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt')
        .snapshots();
  }

  /// يمنح أو يجدد الاشتراك، ويستهلك طلب التفعيل في معاملة واحدة.
  Future<void> activateUser({
    required String uid,
    required String adminUid,
    required double priceEgp,
    required int durationDays,
    required int maxFields,
    required int maxAnalysesPerMonth,
    required double maxAreaFeddan,
  }) async {
    if (priceEgp < 0 ||
        durationDays < 1 ||
        maxFields < 1 ||
        maxAnalysesPerMonth < 1 ||
        maxAreaFeddan <= 0) {
      throw ArgumentError('تحقق من السعر والمدة وحد الحقول والتحليلات.');
    }
    final accessRef = _accessRef(uid);
    final requestRef = _requestRef(uid);
    final now = DateTime.now();
    final expiresAt = Timestamp.fromDate(now.add(Duration(days: durationDays)));

    await _firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      transaction.set(accessRef, {
        'uid': uid,
        'status': 'active',
        'priceEgp': priceEgp,
        'currency': 'EGP',
        'durationDays': durationDays,
        'maxFields': maxFields,
        'maxAnalysesPerMonth': maxAnalysesPerMonth,
        'maxAreaFeddan': maxAreaFeddan,
        'analysisPeriod': '',
        'analysisCount': 0,
        'startsAt': Timestamp.fromDate(now),
        'expiresAt': expiresAt,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminUid,
      });
      if (requestSnapshot.exists) {
        transaction.update(requestRef, {
          'status': 'activated',
          'processedAt': FieldValue.serverTimestamp(),
          'processedBy': adminUid,
        });
      }
    });
  }

  Future<void> rejectRequest({
    required String uid,
    required String adminUid,
  }) async {
    await _requestRef(uid).update({
      'status': 'rejected',
      'processedAt': FieldValue.serverTimestamp(),
      'processedBy': adminUid,
    });
  }
}

/// حساب مساحة المضلع على كرة أرضية تقريبية؛ الهكتار/الفدان للعرض التخطيطي.
class SatelliteGeometry {
  SatelliteGeometry._();

  static const double _earthRadiusMeters = 6378137;
  static const double squareMetersPerFeddan = 4200.833;

  static double areaSquareMeters(List<Map<String, double>> points) {
    if (points.length < 3) return 0;
    double sum = 0;
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final lat1 = current['lat']! * math.pi / 180;
      final lat2 = next['lat']! * math.pi / 180;
      final deltaLng = (next['lng']! - current['lng']!) * math.pi / 180;
      sum += deltaLng * (2 + math.sin(lat1) + math.sin(lat2));
    }
    return (sum * _earthRadiusMeters * _earthRadiusMeters / 2).abs();
  }

  static double areaFeddan(List<Map<String, double>> points) =>
      areaSquareMeters(points) / squareMetersPerFeddan;
}
