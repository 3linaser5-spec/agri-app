import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/satellite_monitoring_model.dart';

class SatelliteMonitoringService {
  SatelliteMonitoringService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _fields(String uid) =>
      _firestore.collection('users').doc(uid).collection('satellite_fields');

  static CollectionReference<Map<String, dynamic>> _fieldNotes(
    String uid,
    String fieldId,
  ) =>
      _fields(uid).doc(fieldId).collection('field_notes');

  static CollectionReference<Map<String, dynamic>> _runs(
    String uid,
    String fieldId,
  ) =>
      _fields(uid).doc(fieldId).collection('analysis_runs');

  static CollectionReference<Map<String, dynamic>> _observations(
    String uid,
    String fieldId,
    String runId,
  ) =>
      _runs(uid, fieldId).doc(runId).collection('observations');

  static Stream<List<HlsField>> watchFields() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _fields(uid).snapshots().map((snapshot) {
      final fields = <HlsField>[];
      for (final document in snapshot.docs) {
        try {
          fields.add(HlsField.fromFirestore(document));
        } catch (error) {
          debugPrint('تجاوز حقل متابعة غير صالح: $error');
        }
      }
      fields.sort((a, b) => a.name.compareTo(b.name));
      return fields;
    });
  }

  static Future<String> saveField(HlsField field) async {
    final uid = _uid;
    if (uid == null) throw StateError('سجّل الدخول لحفظ الحقل.');
    _validateField(field);
    final collection = _fields(uid);
    final reference = field.id.isEmpty ? collection.doc() : collection.doc(field.id);
    final exists = field.id.isNotEmpty && (await reference.get()).exists;
    await reference.set(field.toFirestore(creating: !exists), SetOptions(merge: true));
    return reference.id;
  }

  static Future<void> addNote({
    required String fieldId,
    required String text,
    String? category,
  }) async {
    final uid = _uid;
    final trimmed = text.trim();
    if (uid == null) throw StateError('سجّل الدخول لحفظ الملاحظة.');
    if (trimmed.isEmpty || trimmed.length > 2000) {
      throw ArgumentError('اكتب ملاحظة من 1 إلى 2000 حرف.');
    }
    final normalizedCategory = category?.trim();
    if (normalizedCategory != null && normalizedCategory.length > 64) {
      throw ArgumentError('تصنيف الملاحظة يجب ألا يتجاوز 64 حرفًا.');
    }
    await _fieldNotes(uid, fieldId).add({
      'text': trimmed,
      'category': normalizedCategory?.isNotEmpty == true
          ? normalizedCategory
          : 'عام',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<HlsFieldNote>> watchNotes(String fieldId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _fieldNotes(uid, fieldId).snapshots().map((snapshot) {
      final result = snapshot.docs.map(HlsFieldNote.fromFirestore).toList();
      result.sort((a, b) =>
          (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
      return result;
    });
  }

  static Stream<List<HlsAnalysisRun>> watchRuns(String fieldId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _runs(uid, fieldId).snapshots().map((snapshot) {
      final result = snapshot.docs.map(HlsAnalysisRun.fromFirestore).toList();
      result.sort((a, b) =>
          (b.requestedAt ?? DateTime(1970)).compareTo(a.requestedAt ?? DateTime(1970)));
      return result;
    });
  }

  static Stream<List<HlsObservation>> watchObservations({
    required String fieldId,
    required String runId,
  }) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _observations(uid, fieldId, runId).snapshots().map((snapshot) {
      final result = snapshot.docs.map(HlsObservation.fromFirestore).toList();
      result.sort((a, b) => a.date.compareTo(b.date));
      return result;
    });
  }

  static Future<Map<String, dynamic>> requestAnalysis({
    required String fieldId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result = await _functions.httpsCallable('requestHlsCropAnalysis').call({
      'fieldId': fieldId,
      'startDate': _isoDate(startDate),
      'endDate': _isoDate(endDate),
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> refreshAnalysis({
    required String fieldId,
    required String runId,
  }) async {
    final result = await _functions
        .httpsCallable(
          'getHlsCropAnalysisStatus',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 540)),
        )
        .call({'fieldId': fieldId, 'runId': runId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final page = await collection.limit(350).get();
      if (page.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final document in page.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  static Future<void> deleteField(String fieldId) async {
    final uid = _uid;
    if (uid == null) throw StateError('سجّل الدخول أولاً.');
    final field = _fields(uid).doc(fieldId);
    final runs = await field.collection('analysis_runs').get();
    for (final run in runs.docs) {
      await _deleteCollection(run.reference.collection('observations'));
      await run.reference.delete();
    }
    await _deleteCollection(field.collection('field_notes'));
    await field.delete();
  }

  static void _validateField(HlsField field) {
    if (field.name.trim().isEmpty || field.name.trim().length > 100) {
      throw ArgumentError('اسم الحقل مطلوب، وبحد أقصى 100 حرف.');
    }
    if (field.crop.trim().isEmpty || field.crop.trim().length > 100) {
      throw ArgumentError('اكتب اسم المحصول.');
    }
    if (field.polygon.length < 3 || field.polygon.length > 25) {
      throw ArgumentError('ارسم حدودًا من 3 إلى 25 نقطة.');
    }
    for (final point in field.polygon) {
      if (!point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude < -90 ||
          point.latitude > 90 ||
          point.longitude < -180 ||
          point.longitude > 180) {
        throw ArgumentError('إحداثيات حدود الحقل غير صالحة.');
      }
    }
    if (field.areaSquareMeters < 100 || field.areaSquareMeters > 500000000) {
      throw ArgumentError('مساحة أو شكل الحقل غير منطقي؛ راجع حدود المضلع.');
    }
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
