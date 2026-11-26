import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_outbox.dart';

/// تخزين محلي بسيط (SharedPreferences) لنسخ البيانات وطابور المزامنة.
///
/// الهدف: تظل شاشات المزرعة تعمل بدون إنترنت، وتُرفع أي إضافة/تعديل/حذف
/// تلقائيًا عند رجوع الاتصال؛ دون الحاجة إلى خادم أو Cloud Function.
class OfflineFarmStore {
  OfflineFarmStore._();

  static const String _outboxKey = 'farm_outbox_v1';
  static const String _cachePrefix = 'farm_cache_v1_';
  static bool _flushing = false;

  static Future<bool> hasInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.isNotEmpty && !result.contains(ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  static Future<void> writeCache(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$key', jsonEncode(value));
    } catch (error) {
      debugPrint('تعذر حفظ النسخة المحلية ($key): $error');
    }
  }

  static List<dynamic>? readCache(String key) {
    // القراءة متزامنة عبر SharedPreferences.getInstance في الطبقة العليا؛
    // هنا نعيد null حتى لا نفقد التزامن داخل الواجهة.
    return _cacheMemory[key];
  }

  static final Map<String, List<dynamic>> _cacheMemory = {};

  /// تحميل بيانات مع تخزينها محليًا، والرجوع للنسخة المحلية عند فشل الشبكة.
  static Future<List<T>> cachedList<T>({
    required String key,
    required Future<List<T>> Function() fetch,
    required Map<String, dynamic> Function(T item) toJson,
    required T Function(Map<String, dynamic> item) fromJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final items = await fetch();
      final encoded =
          items.map((item) => toJson(item)).toList(growable: false);
      _cacheMemory[key] = encoded;
      await prefs.setString('$_cachePrefix$key', jsonEncode(encoded));
      return items;
    } catch (error) {
      debugPrint('تعذر تحميل $key من الشبكة، استخدام النسخة المحلية: $error');
      final raw = prefs.getString('$_cachePrefix$key');
      if (raw == null) rethrow;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) rethrow;
        return decoded
            .whereType<Map>()
            .map((item) => fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      } catch (_) {
        rethrow;
      }
    }
  }

  /// تنفيذ كتابة على Firestore، أو إضافتها للطابور لو لا يوجد إنترنت.
  ///
  /// تُعاد `true` عندما تنجح الكتابة فورًا، و`false` عندما تُؤجَّل.
  static Future<bool> write({
    required String collection,
    required String docId,
    required OfflineOperationType type,
    Map<String, dynamic>? data,
  }) async {
    if (!await hasInternet()) {
      await _enqueue(OfflineOperation(
        collection: collection,
        docId: docId,
        type: type,
        data: data,
        createdAt: DateTime.now(),
      ));
      return false;
    }
    try {
      final reference = FirebaseFirestore.instance.collection(collection).doc(docId);
      switch (type) {
        case OfflineOperationType.set:
          await reference.set(data ?? const {}, SetOptions(merge: true));
        case OfflineOperationType.update:
          await reference.update(data ?? const {});
        case OfflineOperationType.delete:
          await reference.delete();
      }
      return true;
    } on FirebaseException catch (error) {
      // خطأ صلاحيات/بيانات ليس مشكلة اتصال: لا نضعه في الطابور للأبد.
      debugPrint('فشل حفظ $collection/$docId: ${error.code}');
      rethrow;
    }
  }

  static Future<void> _enqueue(OfflineOperation operation) async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = OfflineOutbox.decode(prefs.getString(_outboxKey))
      ..add(operation);
    await prefs.setString(_outboxKey, outbox.encode());
    debugPrint('تم تأجيل عملية على ${operation.collection} حتى رجوع الإنترنت');
  }

  static Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return OfflineOutbox.decode(prefs.getString(_outboxKey)).length;
  }

  /// إرسال كل العمليات المؤجلة بالترتيب؛ تُعاد عدد العمليات الناجحة.
  static Future<int> flush() async {
    if (_flushing) return 0;
    if (!await hasInternet()) return 0;
    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final outbox = OfflineOutbox.decode(prefs.getString(_outboxKey));
      if (outbox.isEmpty) return 0;
      var success = 0;
      while (!outbox.isEmpty) {
        final operation = outbox.operations.first;
        try {
          final reference = FirebaseFirestore.instance
              .collection(operation.collection)
              .doc(operation.docId);
          switch (operation.type) {
            case OfflineOperationType.set:
              await reference.set(
                operation.data ?? const {},
                SetOptions(merge: true),
              );
            case OfflineOperationType.update:
              await reference.update(operation.data ?? const {});
            case OfflineOperationType.delete:
              await reference.delete();
          }
          outbox.removeAt(0);
          success++;
          await prefs.setString(_outboxKey, outbox.encode());
        } catch (error) {
          debugPrint('تعذر مزامنة عملية مؤجلة: $error');
          break;
        }
      }
      return success;
    } finally {
      _flushing = false;
    }
  }

  /// للاختبارات فقط.
  @visibleForTesting
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_outboxKey);
    _cacheMemory.clear();
  }
}
